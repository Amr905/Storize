import 'package:meta/meta.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/repos/account_repo.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/settings_repo.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_domain/src/usecases/history_support.dart';
import 'package:storize_model/storize_model.dart';

/// What one [SyncHighlights.run] did.
enum HighlightsOutcome {
  /// The tray was read (and new items stored, if any).
  synced,

  /// Highlights are off for the target, or it is gone or not active: no call.
  skipped,

  /// The session is not active (BR-7): no call.
  sessionInactive,

  /// Instagram asked us to slow down.
  rateLimited,

  /// The session was rejected; the account was flagged.
  sessionInvalid,

  /// A network problem; the next run retries.
  network,

  /// Another failure (schema change, target not visible, ...).
  failed,
}

/// The result of [SyncHighlights.run].
@immutable
final class HighlightsResult {
  /// Creates a result.
  const HighlightsResult(
    this.outcome, {
    this.newContentIds = const [],
    this.sessionStatus,
  });

  /// What happened.
  final HighlightsOutcome outcome;

  /// IDs of the content rows this run stored.
  final List<int> newContentIds;

  /// The new account status for [HighlightsOutcome.sessionInvalid].
  final AccountStatus? sessionStatus;

  @override
  String toString() =>
      'HighlightsResult(${outcome.name}, new: ${newContentIds.length})';
}

/// Saves the highlights of a target (FR-71, TECH_SPEC §17.3).
///
/// It reads the tray, then fetches the items of the highlights that are new or
/// whose `latestItemAt` is newer than the newest stored item of that
/// highlight, and queues the items it does not have yet (deduped by the UNIQUE
/// key `(target, kind, remote_id)`). Items are stored with
/// [ContentKind.highlight] and the [HighlightExtras] keys. The gallery folder
/// is `<username>/Highlights/<title>` (see `DownloadPending`).
final class SyncHighlights {
  /// Creates the use case.
  SyncHighlights({
    required this._platform,
    required this._targets,
    required this._content,
    required this._accounts,
    required this._settings,
    required this._clock,
  });

  final ContentPlatform _platform;
  final TargetRepo _targets;
  final ContentRepo _content;
  final AccountRepo _accounts;
  final SettingsRepo _settings;
  final Clock _clock;

  /// The most highlights fetched in one call.
  static const int itemBatchSize = 10;

  /// Syncs every active target that has highlights on, one after the other.
  /// It stops at a rate limit or a session problem. With [targetId] only that
  /// target is synced.
  Future<HighlightsResult> runDue({
    int? targetId,
    ExtractionPolicy? policy,
    DateTime? deadline,
  }) async {
    final fresh = <int>[];
    for (final t in await _targets.listActive(CheckScope.all)) {
      if (!t.highlightsEnabled ||
          t.platform != _platform.id ||
          (targetId != null && t.id != targetId)) {
        continue;
      }
      if (deadline != null && !_clock.now().isBefore(deadline)) break;
      final r = await run(t.id, policy: policy);
      fresh.addAll(r.newContentIds);
      switch (r.outcome) {
        case HighlightsOutcome.rateLimited ||
            HighlightsOutcome.sessionInvalid ||
            HighlightsOutcome.sessionInactive:
          return HighlightsResult(
            r.outcome,
            newContentIds: fresh,
            sessionStatus: r.sessionStatus,
          );
        case _:
      }
    }
    return HighlightsResult(HighlightsOutcome.synced, newContentIds: fresh);
  }

  /// Syncs the highlights of [targetId]. Never throws for expected failures.
  Future<HighlightsResult> run(int targetId, {ExtractionPolicy? policy}) async {
    final target = await _targets.getById(targetId);
    if (target == null ||
        !target.highlightsEnabled ||
        target.status != TargetStatus.active) {
      return const HighlightsResult(HighlightsOutcome.skipped);
    }
    final account = await _accounts.getActive();
    if (account == null || account.status != AccountStatus.active) {
      return const HighlightsResult(HighlightsOutcome.sessionInactive);
    }
    final effective =
        policy ??
        ((await _settings.get()).pageModeInBackground
            ? ExtractionPolicy.directThenPage
            : ExtractionPolicy.directOnly);

    final tray = await _call(
      () => _platform.fetchHighlights(target.remoteUserId, policy: effective),
    );
    final List<RemoteHighlight> highlights;
    switch (tray) {
      case Ok(:final value):
        highlights = value;
      case Err(:final failure):
        return _onFailure(account.id, failure);
    }

    final latestStored = await _latestStored(target.id);
    final order = <String, int>{};
    final changed = <RemoteHighlight>[];
    for (var i = 0; i < highlights.length; i++) {
      final h = highlights[i];
      order[h.id] = i;
      final stored = latestStored[h.id];
      final latest = h.latestItemAt;
      if (stored == null ||
          (latest != null && latest.toUtc().isAfter(stored))) {
        changed.add(h);
      }
    }

    final fresh = <int>[];
    final now = _clock.now();
    for (var i = 0; i < changed.length; i += itemBatchSize) {
      final chunk = changed.sublist(
        i,
        i + itemBatchSize > changed.length ? changed.length : i + itemBatchSize,
      );
      final res = await _call(
        () => _platform.fetchHighlightItems([
          for (final h in chunk) h.id,
        ], policy: effective),
      );
      switch (res) {
        case Ok(:final value):
          for (final h in chunk) {
            final items = value[h.id] ?? const <RemoteContent>[];
            final known = await _content.existingRemoteIds(
              target.id,
              ContentKind.highlight,
              [for (final c in items) c.remoteId],
            );
            for (final c in items) {
              if (known.contains(c.remoteId)) continue;
              final id = await insertRemote(
                _content,
                target,
                _asHighlightItem(c, h, order[h.id] ?? 0),
                now,
              );
              if (id != null) fresh.add(id);
            }
          }
        case Err(:final failure):
          // Items stored so far stay; the next run asks again for the rest.
          final r = await _onFailure(account.id, failure);
          return HighlightsResult(
            r.outcome,
            newContentIds: fresh,
            sessionStatus: r.sessionStatus,
          );
      }
    }
    return HighlightsResult(HighlightsOutcome.synced, newContentIds: fresh);
  }

  /// The newest `postedAt` stored for each highlight ID of [targetId].
  Future<Map<String, DateTime>> _latestStored(int targetId) async {
    final out = <String, DateTime>{};
    for (final item in await _content.listByTarget(targetId)) {
      final c = item.content;
      if (c.kind != ContentKind.highlight) continue;
      final id = c.extras[HighlightExtras.id];
      if (id is! String) continue;
      final at = c.postedAt.toUtc();
      final old = out[id];
      if (old == null || at.isAfter(old)) out[id] = at;
    }
    return out;
  }

  /// Marks [c] as an item of [h]: kind, id, title and tray position.
  RemoteContent _asHighlightItem(
    RemoteContent c,
    RemoteHighlight h,
    int order,
  ) => RemoteContent(
    remoteId: c.remoteId,
    kind: ContentKind.highlight,
    postedAt: c.postedAt,
    slides: c.slides,
    caption: c.caption,
    locationName: c.locationName,
    taggedUsernames: c.taggedUsernames,
    closeFriends: c.closeFriends,
    extras: {
      ...c.extras,
      HighlightExtras.id: h.id,
      HighlightExtras.title: h.title,
      HighlightExtras.order: order,
    },
  );

  Future<Result<T>> _call<T>(Future<Result<T>> Function() call) async {
    try {
      return await call();
    } on Object catch (_) {
      return const Err(UnknownFailure(null, 'platform_threw'));
    }
  }

  Future<HighlightsResult> _onFailure(int accountId, Failure failure) async {
    switch (failure) {
      case RateLimited():
        return const HighlightsResult(HighlightsOutcome.rateLimited);
      case NetworkFailure():
        return const HighlightsResult(HighlightsOutcome.network);
      case SessionInvalid(:final reason):
        await _accounts.setStatus(
          accountId,
          AccountStatus.needsRelogin,
          reason: reason == SessionReason.challenge
              ? 'challenge'
              : 'login_required',
        );
        return const HighlightsResult(
          HighlightsOutcome.sessionInvalid,
          sessionStatus: AccountStatus.needsRelogin,
        );
      case AccountRestricted():
        await _accounts.setStatus(
          accountId,
          AccountStatus.restricted,
          reason: 'restricted',
        );
        return const HighlightsResult(
          HighlightsOutcome.sessionInvalid,
          sessionStatus: AccountStatus.restricted,
        );
      case TargetNotVisible() ||
          TargetNotFound() ||
          SchemaChanged() ||
          UnknownFailure():
        return const HighlightsResult(HighlightsOutcome.failed);
    }
  }
}
