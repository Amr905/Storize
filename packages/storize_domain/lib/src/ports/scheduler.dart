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
  /// only that target is checked.
  Future<void> checkNow({CheckScope scope = CheckScope.all, int? targetId});

  /// Enqueues the one-off `history` task now (post-history backfill). It
  /// keeps an existing request, so calling it twice does not duplicate.
  Future<void> kickHistory();

  /// Cancels every registered task.
  Future<void> cancelAll();
}
