import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/repos/account_repo.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_domain/src/usecases/backfill_history.dart';
import 'package:storize_model/storize_model.dart';

/// Why a [ResolvePendingTargets] run stopped before the end of its list.
enum ResolveStop {
  /// It went through every pending target.
  none,

  /// Instagram asked us to slow down (or the governor is paused).
  rateLimited,

  /// The network failed.
  network,

  /// No usable session (BR-7), or Instagram rejected it.
  session,

  /// Another failure (Instagram changed shape, unknown); the rest waits.
  other,

  /// The deadline passed.
  deadline,
}

/// The result of [ResolvePendingTargets.run].
@immutable
final class ResolvePendingResult {
  /// Creates a result.
  const ResolvePendingResult({
    this.resolved = 0,
    this.merged = 0,
    this.unavailable = 0,
    this.notVisible = 0,
    this.remaining = 0,
    this.stop = ResolveStop.none,
  });

  /// Targets that became active.
  final int resolved;

  /// Pending rows dropped because the account was already tracked.
  final int merged;

  /// Targets whose account does not exist.
  final int unavailable;

  /// Targets whose account cannot be seen.
  final int notVisible;

  /// Targets still pending after the run.
  final int remaining;

  /// Why the run stopped early, or [ResolveStop.none].
  final ResolveStop stop;
}

/// Looks up the targets that were added while Instagram was limited or
/// unreachable (FR-73), one by one, oldest first.
///
/// A lookup that hits a rate limit or a network failure stops the run and
/// leaves the rest pending. A pending row is re-read before each write, so a
/// target the user removed or changed meanwhile is not overwritten. Never
/// throws for expected failures.
final class ResolvePendingTargets {
  /// Creates the use case.
  ResolvePendingTargets({
    required this._platform,
    required this._targets,
    required this._accounts,
    required this._history,
    required this._clock,
  });

  final ContentPlatform _platform;
  final TargetRepo _targets;
  final AccountRepo _accounts;
  final BackfillHistory _history;
  final Clock _clock;

  /// Resolves the pending targets until [deadline], if given.
  Future<ResolvePendingResult> run({DateTime? deadline}) async {
    final ids = await _pendingIds();
    if (ids.isEmpty) return const ResolvePendingResult();
    final account = await _accounts.getActive();
    if (account == null || account.status != AccountStatus.active) {
      return ResolvePendingResult(
        remaining: ids.length,
        stop: ResolveStop.session,
      );
    }

    var resolved = 0;
    var merged = 0;
    var unavailable = 0;
    var notVisible = 0;
    var stop = ResolveStop.none;
    for (final id in ids) {
      if (deadline != null && !_clock.now().isBefore(deadline)) {
        stop = ResolveStop.deadline;
        break;
      }
      final pending = await _targets.getById(id);
      if (pending == null || pending.status != TargetStatus.pendingLookup) {
        continue;
      }
      final res = await _platform.resolveUser(pending.username);
      switch (res) {
        case Ok(:final value):
          switch (await _apply(id, value)) {
            case _Applied.active:
              resolved++;
            case _Applied.notVisible:
              notVisible++;
            case _Applied.merged:
              merged++;
            case _Applied.gone:
              break;
          }
        case Err(:final failure):
          switch (failure) {
            case TargetNotFound():
              if (await _finish(id, TargetStatus.unavailable, 'not_found')) {
                unavailable++;
              }
            case TargetNotVisible():
              if (await _finish(id, TargetStatus.notVisible, 'not_visible')) {
                notVisible++;
              }
            case RateLimited():
              stop = ResolveStop.rateLimited;
            case NetworkFailure():
              stop = ResolveStop.network;
            case SessionInvalid() || AccountRestricted():
              stop = ResolveStop.session;
            case SchemaChanged() || UnknownFailure():
              stop = ResolveStop.other;
          }
      }
      if (stop != ResolveStop.none) break;
    }
    return ResolvePendingResult(
      resolved: resolved,
      merged: merged,
      unavailable: unavailable,
      notVisible: notVisible,
      remaining: (await _pendingIds()).length,
      stop: stop,
    );
  }

  Future<List<int>> _pendingIds() async {
    final all = await _targets.watchAll().first;
    final ids = [
      for (final t in all)
        if (t.status == TargetStatus.pendingLookup &&
            t.platform == _platform.id)
          t.id,
    ]..sort();
    return ids;
  }

  /// Sets a final status on a still-pending target. False if it changed.
  Future<bool> _finish(int id, TargetStatus status, String reason) async {
    final t = await _targets.getById(id);
    if (t == null || t.status != TargetStatus.pendingLookup) return false;
    await _targets.update(t.copyWith(status: status, statusReason: reason));
    return true;
  }

  Future<_Applied> _apply(int id, RemoteUser user) async {
    final t = await _targets.getById(id);
    if (t == null || t.status != TargetStatus.pendingLookup) {
      return _Applied.gone;
    }
    // The same account is already tracked: keep that row, drop this one. A
    // pending row never has content (checks skip it), so no file is lost.
    final existing = await _targets.getByRemoteUserId(
      t.platform,
      user.remoteUserId,
    );
    if (existing != null && existing.id != t.id) {
      await _targets.delete(t.id);
      return _Applied.merged;
    }

    final hidden =
        user.blockedByViewer || (user.isPrivate && !user.followedByViewer);
    final next = t.copyWith(
      remoteUserId: user.remoteUserId,
      username: user.username,
      displayName: user.displayName ?? t.displayName,
      isPrivate: user.isPrivate,
      status: hidden ? TargetStatus.notVisible : TargetStatus.active,
      statusReason: hidden
          ? (user.blockedByViewer ? 'blocked' : 'private')
          : null,
    );
    try {
      await _targets.update(next);
    } on DuplicateEntityException {
      // Lost a race with another run or an add: the other row wins.
      await _targets.delete(t.id);
      return _Applied.merged;
    }
    if (hidden) return _Applied.notVisible;

    if (t.historyRange != HistoryRange.none) {
      try {
        await _history.start(t.id, t.historyRange, since: t.historySince);
      } on ArgumentError {
        // A bad "since" date: the account is added without history.
      }
    }
    return _Applied.active;
  }
}

enum _Applied { active, notVisible, merged, gone }
