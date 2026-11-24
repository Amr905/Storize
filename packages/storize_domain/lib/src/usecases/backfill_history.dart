import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/repos/account_repo.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/settings_repo.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_domain/src/usecases/history_support.dart';
import 'package:storize_model/storize_model.dart';

/// What one [BackfillHistory.step] did.
enum BackfillOutcome {
  /// A page was fetched and the backfill goes on.
  progressed,

  /// The backfill reached its end (state `done`).
  done,

  /// The target is not `running` (or is gone, or is not active): no call.
  skipped,

  /// The session is not active (BR-7). No call; state unchanged.
  sessionInactive,

  /// Instagram asked us to slow down. State stays `running`.
  rateLimited,

  /// The session was rejected. The account was flagged; state stays
  /// `running`.
  sessionInvalid,

  /// A network problem. State stays `running`; the next run retries.
  network,

  /// The backfill cannot go on (state `failed`); the user can resume it.
  failed,
}

/// The result of one [BackfillHistory.step].
@immutable
final class BackfillStepResult {
  /// Creates a result.
  const BackfillStepResult(
    this.outcome, {
    this.newContentIds = const [],
    this.retryAfter,
    this.sessionStatus,
  });

  /// What happened.
  final BackfillOutcome outcome;

  /// IDs of the content rows this step stored.
  final List<int> newContentIds;

  /// How long Instagram asked us to wait, for [BackfillOutcome.rateLimited].
  final Duration? retryAfter;

  /// The new account status, for [BackfillOutcome.sessionInvalid].
  final AccountStatus? sessionStatus;

  /// Whether the target still has pages to fetch.
  bool get stillRunning =>
      outcome == BackfillOutcome.progressed ||
      outcome == BackfillOutcome.rateLimited ||
      outcome == BackfillOutcome.network ||
      outcome == BackfillOutcome.sessionInvalid ||
      outcome == BackfillOutcome.sessionInactive;

  @override
  String toString() =>
      'BackfillStepResult(${outcome.name}, new: ${newContentIds.length})';
}

/// The result of [BackfillHistory.runDue]: one page per running target.
@immutable
final class BackfillPassResult {
  /// Creates a result.
  const BackfillPassResult({
    required this.running,
    required this.newContentIds,
    this.rateLimited = false,
    this.sessionStatus,
    this.sessionInactive = false,
    this.network = false,
  });

  /// How many targets are still `running` after the pass.
  final int running;

  /// Content stored in the pass.
  final List<int> newContentIds;

  /// A step was rate limited (the pass stopped there).
  final bool rateLimited;

  /// Set when the pass ended the session.
  final AccountStatus? sessionStatus;

  /// The session was not active, so nothing was fetched.
  final bool sessionInactive;

  /// A step hit a network problem.
  final bool network;

  @override
  String toString() =>
      'BackfillPassResult(running: $running, new: ${newContentIds.length})';
}

/// Fetches the post history of a target, one page per [step] (FR-68, FR-69,
/// TECH_SPEC §17.3).
///
/// New posts are queued like `RunCheck` queues them (PENDING media, deduped by
/// the UNIQUE key), respecting the Posts and Reels toggles, and posts older
/// than the range start are not queued. The cursor is saved only after the
/// page is stored, so a rate limit, a session failure or a kill resumes at the
/// same page, and a repeat stores nothing twice.
final class BackfillHistory {
  /// Creates the use case.
  BackfillHistory({
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

  /// The oldest instant a backfill of [target] still wants, or null for no
  /// lower bound (`all`).
  ///
  /// `today` is the start of today in device local time (like the watermark
  /// of a new target); `days7` and `days30` count back from [now].
  static DateTime? rangeStart(Target target, DateTime now) =>
      switch (target.historyRange) {
        HistoryRange.none => now,
        HistoryRange.today => () {
          final l = now.toLocal();
          return DateTime(l.year, l.month, l.day).toUtc();
        }(),
        HistoryRange.days7 => now.subtract(const Duration(days: 7)),
        HistoryRange.days30 => now.subtract(const Duration(days: 30)),
        HistoryRange.since => target.historySince?.toUtc(),
        HistoryRange.all => null,
      };

  /// Starts (or restarts) a backfill of [range] (FR-68). [since] is needed for
  /// [HistoryRange.since]. [HistoryRange.none] cancels.
  ///
  /// Throws [ArgumentError] when `since` is missing or in the future.
  Future<void> start(
    int targetId,
    HistoryRange range, {
    DateTime? since,
  }) async {
    final t = await _targets.getById(targetId);
    if (t == null) return;
    if (range == HistoryRange.none) {
      await cancel(targetId);
      return;
    }
    if (range == HistoryRange.since &&
        (since == null || since.isAfter(_clock.now()))) {
      throw ArgumentError.value(since, 'since', 'needs a date in the past');
    }
    final now = _clock.now();
    await _targets.update(
      t.copyWith(
        historyRange: range,
        historySince: range == HistoryRange.since ? since!.toUtc() : null,
        historyProgress: HistoryProgress(
          state: HistoryState.running,
          fetched: 0,
          updatedAt: now,
        ),
      ),
    );
  }

  /// Pauses a running backfill. The cursor is kept.
  Future<void> pause(int targetId) =>
      _setState(targetId, HistoryState.paused, from: {HistoryState.running});

  /// Resumes a paused or failed backfill from its saved cursor.
  Future<void> resume(int targetId) => _setState(
    targetId,
    HistoryState.running,
    from: {HistoryState.paused, HistoryState.failed},
  );

  /// Stops the backfill for good (FR-69). Posts already stored stay. The range
  /// goes back to `none`.
  Future<void> cancel(int targetId) async {
    final t = await _targets.getById(targetId);
    if (t == null) return;
    final old = t.historyProgress;
    await _targets.update(
      t.copyWith(
        historyRange: HistoryRange.none,
        historySince: null,
        historyProgress: old == null
            ? null
            : HistoryProgress(
                state: HistoryState.idle,
                fetched: old.fetched,
                oldestSeenAt: old.oldestSeenAt,
                updatedAt: _clock.now(),
              ),
      ),
    );
  }

  Future<void> _setState(
    int targetId,
    HistoryState to, {
    required Set<HistoryState> from,
  }) async {
    final t = await _targets.getById(targetId);
    final p = t?.historyProgress;
    if (t == null || p == null || !from.contains(p.state)) return;
    await _targets.update(
      t.copyWith(
        historyProgress: p.copyWith(state: to, updatedAt: _clock.now()),
      ),
    );
  }

  /// Runs one page for every `running` active target, one after the other.
  /// It stops at a rate limit or a session problem.
  Future<BackfillPassResult> runDue({
    ExtractionPolicy? policy,
    DateTime? deadline,
  }) async {
    final ids = [
      for (final t in await _targets.listActive(CheckScope.all))
        if (t.platform == _platform.id &&
            t.historyProgress?.state == HistoryState.running)
          t.id,
    ];
    final fresh = <int>[];
    var rateLimited = false;
    var network = false;
    var inactive = false;
    AccountStatus? session;
    for (final id in ids) {
      if (deadline != null && !_clock.now().isBefore(deadline)) break;
      final r = await step(id, policy: policy);
      fresh.addAll(r.newContentIds);
      if (r.outcome == BackfillOutcome.network) network = true;
      if (r.outcome == BackfillOutcome.rateLimited) {
        rateLimited = true;
        break;
      }
      if (r.outcome == BackfillOutcome.sessionInvalid) {
        session = r.sessionStatus;
        break;
      }
      if (r.outcome == BackfillOutcome.sessionInactive) {
        inactive = true;
        break;
      }
    }
    var running = 0;
    for (final t in await _targets.listActive(CheckScope.all)) {
      if (t.platform == _platform.id &&
          t.historyProgress?.state == HistoryState.running) {
        running++;
      }
    }
    return BackfillPassResult(
      running: running,
      newContentIds: fresh,
      rateLimited: rateLimited,
      sessionStatus: session,
      sessionInactive: inactive,
      network: network,
    );
  }

  /// Fetches one page for [targetId] and stores it. Never throws for expected
  /// failures.
  Future<BackfillStepResult> step(
    int targetId, {
    ExtractionPolicy? policy,
  }) async {
    final target = await _targets.getById(targetId);
    final progress = target?.historyProgress;
    if (target == null ||
        progress == null ||
        progress.state != HistoryState.running ||
        target.status != TargetStatus.active) {
      return const BackfillStepResult(BackfillOutcome.skipped);
    }
    final account = await _accounts.getActive();
    if (account == null || account.status != AccountStatus.active) {
      return const BackfillStepResult(BackfillOutcome.sessionInactive);
    }
    final effective =
        policy ??
        ((await _settings.get()).pageModeInBackground
            ? ExtractionPolicy.directThenPage
            : ExtractionPolicy.directOnly);

    final Result<PostPage> res;
    try {
      res = await _platform.fetchPostPage(
        target.remoteUserId,
        cursor: progress.cursor,
        policy: effective,
      );
    } on Object catch (_) {
      return const BackfillStepResult(BackfillOutcome.network);
    }
    switch (res) {
      case Ok(:final value):
        return _store(target, progress, value);
      case Err(:final failure):
        return _onFailure(target, progress, account.id, failure);
    }
  }

  Future<BackfillStepResult> _store(
    Target target,
    HistoryProgress progress,
    PostPage page,
  ) async {
    final now = _clock.now();
    final start = rangeStart(target, now);
    final ids = <int>[];
    var oldest = progress.oldestSeenAt;
    var reachedStart = false;
    for (final c in page.items) {
      if (c.kind != ContentKind.post) continue;
      // A pinned post sits at the top whatever its age: it must not end the
      // backfill early, and it is only stored if it is inside the range.
      final pinned = c.extras['pinned'] == true;
      final at = c.postedAt.toUtc();
      final before = start != null && at.isBefore(start);
      if (!pinned) {
        if (oldest == null || at.isBefore(oldest)) oldest = at;
        if (before) reachedStart = true;
      }
      if (before) continue;
      final wanted = c.postType == PostType.reel
          ? target.trackReels
          : target.trackPosts;
      if (!wanted) continue;
      final id = await insertRemote(_content, target, c, now);
      if (id != null) ids.add(id);
    }
    final done = page.nextCursor == null || reachedStart;
    // Re-read: the user may have paused or cancelled during the call.
    final current = await _targets.getById(target.id);
    final cp = current?.historyProgress;
    if (current == null || cp == null) {
      return BackfillStepResult(BackfillOutcome.progressed, newContentIds: ids);
    }
    final userChanged = cp.state != HistoryState.running;
    final next = HistoryProgress(
      state: userChanged
          ? cp.state
          : (done ? HistoryState.done : HistoryState.running),
      cursor: done ? null : page.nextCursor,
      fetched: progress.fetched + page.items.length,
      oldestSeenAt: oldest,
      updatedAt: now,
    );
    // A cancel (range none) keeps its idle state; the page is stored anyway.
    await _targets.update(
      current.copyWith(
        historyProgress: current.historyRange == HistoryRange.none ? cp : next,
        lastNewPostAt: ids.isNotEmpty ? now : current.lastNewPostAt,
      ),
    );
    return BackfillStepResult(
      done && !userChanged ? BackfillOutcome.done : BackfillOutcome.progressed,
      newContentIds: ids,
    );
  }

  Future<BackfillStepResult> _onFailure(
    Target target,
    HistoryProgress progress,
    int accountId,
    Failure failure,
  ) async {
    switch (failure) {
      case RateLimited(:final retryAfter):
        return BackfillStepResult(
          BackfillOutcome.rateLimited,
          retryAfter: retryAfter,
        );
      case NetworkFailure():
        return const BackfillStepResult(BackfillOutcome.network);
      case SessionInvalid(:final reason):
        const status = AccountStatus.needsRelogin;
        await _accounts.setStatus(
          accountId,
          status,
          reason: reason == SessionReason.challenge
              ? 'challenge'
              : 'login_required',
        );
        return BackfillStepResult(
          BackfillOutcome.sessionInvalid,
          sessionStatus: status,
        );
      case AccountRestricted():
        await _accounts.setStatus(
          accountId,
          AccountStatus.restricted,
          reason: 'restricted',
        );
        return const BackfillStepResult(
          BackfillOutcome.sessionInvalid,
          sessionStatus: AccountStatus.restricted,
        );
      case TargetNotVisible() ||
          TargetNotFound() ||
          SchemaChanged() ||
          UnknownFailure():
        final current = await _targets.getById(target.id);
        final cp = current?.historyProgress;
        if (current != null && cp != null && cp.state == HistoryState.running) {
          await _targets.update(
            current.copyWith(
              historyProgress: cp.copyWith(
                state: HistoryState.failed,
                updatedAt: _clock.now(),
              ),
            ),
          );
        }
        return const BackfillStepResult(BackfillOutcome.failed);
    }
  }
}
