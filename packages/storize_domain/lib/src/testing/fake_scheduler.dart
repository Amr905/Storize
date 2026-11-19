import 'package:storize_domain/src/ports/scheduler.dart';
import 'package:storize_model/storize_model.dart';

/// A [Scheduler] that records its calls and runs nothing.
final class FakeScheduler implements Scheduler {
  final List<({int storyMin, int postMin, bool wifiOnly})> _applyCalls = [];
  final List<({CheckScope scope, int? targetId})> _checkNowCalls = [];
  int _cancelAllCalls = 0;

  /// Every `apply` call, in order.
  List<({int storyMin, int postMin, bool wifiOnly})> get applyCalls =>
      List.unmodifiable(_applyCalls);

  /// Every `checkNow` call, in order.
  List<({CheckScope scope, int? targetId})> get checkNowCalls =>
      List.unmodifiable(_checkNowCalls);

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

  @override
  Future<void> checkNow({
    CheckScope scope = CheckScope.all,
    int? targetId,
  }) async {
    _checkNowCalls.add((scope: scope, targetId: targetId));
  }

  @override
  Future<void> cancelAll() async {
    _cancelAllCalls++;
  }
}
