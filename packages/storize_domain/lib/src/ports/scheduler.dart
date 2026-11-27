import 'package:storize_domain/src/entities/app_settings.dart';
import 'package:storize_model/storize_model.dart';

/// Registers background work (workmanager, TECH_SPEC §4.3).
abstract interface class Scheduler {
  /// Registers or replaces the periodic tasks using the given intervals in
  /// minutes. [wifiOnly] requires an unmetered network.
  Future<void> apply({
    required int storyMin,
    required int postMin,
    required bool wifiOnly,
  });

  /// Enqueues an expedited one-off check for [scope]. When [targetId] is set,
  /// only that target is checked. [unmetered] is the dev-only debug check that
  /// skips the hourly request limit (T-050); production governors ignore it.
  Future<void> checkNow({
    CheckScope scope = CheckScope.all,
    int? targetId,
    bool unmetered = false,
  });

  /// Enqueues the one-off `history` task now (post-history backfill). It
  /// keeps an existing request, so calling it twice does not duplicate.
  Future<void> kickHistory();

  /// Cancels every registered task.
  Future<void> cancelAll();
}

/// Keeps the one-off daily summary run (FR-78) registered at the right time.
///
/// Separate from [Scheduler] so the existing port does not change. The
/// production implementation is `WorkmanagerScheduler`.
// Kept as its own port: one method is enough here.
// ignore: one_member_abstracts
abstract interface class DailySummaryScheduler {
  /// Replaces the pending `daily-summary` run with the next run at [time]
  /// (local time), or cancels it unless [mode] is [NotificationMode.daily].
  /// [nowUtc] and [localOffset] give the local clock.
  Future<void> schedule({
    required NotificationMode mode,
    required SummaryTime time,
    required DateTime nowUtc,
    required Duration localOffset,
  });
}
