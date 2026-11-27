import 'package:storize_domain/src/entities/app_settings.dart';
import 'package:storize_domain/src/ports/scheduler.dart';
import 'package:storize_model/storize_model.dart';

/// A [Scheduler] that records its calls and runs nothing.
final class FakeScheduler implements Scheduler, DailySummaryScheduler {
  /// The daily-summary calls (the same record a [FakeDailySummaryScheduler]
  /// keeps).
  final FakeDailySummaryScheduler summary = FakeDailySummaryScheduler();

  @override
  Future<void> schedule({
    required NotificationMode mode,
    required SummaryTime time,
    required DateTime nowUtc,
    required Duration localOffset,
  }) => summary.schedule(
    mode: mode,
    time: time,
    nowUtc: nowUtc,
    localOffset: localOffset,
  );

  final List<({int storyMin, int postMin, bool wifiOnly})> _applyCalls = [];
  final List<({CheckScope scope, int? targetId})> _checkNowCalls = [];
  int _cancelAllCalls = 0;
  int _kickHistoryCalls = 0;

  /// Every `apply` call, in order.
  List<({int storyMin, int postMin, bool wifiOnly})> get applyCalls =>
      List.unmodifiable(_applyCalls);

  /// Every `checkNow` call, in order.
  List<({CheckScope scope, int? targetId})> get checkNowCalls =>
      List.unmodifiable(_checkNowCalls);

  /// How many times `kickHistory` was called.
  int get kickHistoryCalls => _kickHistoryCalls;

  /// How many times `cancelAll` was called.
  int get cancelAllCalls => _cancelAllCalls;

  @override
  Future<void> apply({
    required int storyMin,
    required int postMin,
    required bool wifiOnly,
  }) async {
    _applyCalls.add((storyMin: storyMin, postMin: postMin, wifiOnly: wifiOnly));
  }

  int _unmeteredCalls = 0;

  /// How many `checkNow` calls had `unmetered: true`.
  int get unmeteredCheckNowCount => _unmeteredCalls;

  @override
  Future<void> checkNow({
    CheckScope scope = CheckScope.all,
    int? targetId,
    bool unmetered = false,
  }) async {
    _checkNowCalls.add((scope: scope, targetId: targetId));
    if (unmetered) _unmeteredCalls++;
  }

  @override
  Future<void> kickHistory() async {
    _kickHistoryCalls++;
  }

  @override
  Future<void> cancelAll() async {
    _cancelAllCalls++;
  }
}

/// Records every [DailySummaryScheduler.schedule] call, in order.
final class FakeDailySummaryScheduler implements DailySummaryScheduler {
  /// Every call, in order.
  final List<
    ({
      NotificationMode mode,
      SummaryTime time,
      DateTime nowUtc,
      Duration localOffset,
    })
  >
  calls = [];

  @override
  Future<void> schedule({
    required NotificationMode mode,
    required SummaryTime time,
    required DateTime nowUtc,
    required Duration localOffset,
  }) async {
    calls.add((
      mode: mode,
      time: time,
      nowUtc: nowUtc,
      localOffset: localOffset,
    ));
  }
}
