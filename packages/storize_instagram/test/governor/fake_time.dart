import 'dart:async';

import 'package:storize_domain/testing.dart';

/// Fake time for governor tests: a [FakeClock] plus a controllable `delay`.
///
/// `delay` never sleeps. Timers fire only when the test moves time with
/// [elapse] or [drive], so concurrency is deterministic.
final class FakeTime {
  /// The shared clock (also given to the fake lease repo).
  final FakeClock clock = FakeClock();

  final List<_Timer> _timers = [];

  /// Number of delays waiting for time to pass.
  int get pendingTimers => _timers.length;

  /// A `Delay` for the governor.
  Future<void> delay(Duration duration) {
    final completer = Completer<void>();
    _timers.add(_Timer(clock.now().add(duration), completer));
    return completer.future;
  }

  /// Lets queued microtasks and zero-delay events run.
  Future<void> pump() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Moves time forward by [duration], firing due timers in order.
  Future<void> elapse(Duration duration) async {
    final target = clock.now().add(duration);
    await pump();
    while (true) {
      final next = _earliest();
      if (next == null || next.wakeAt.isAfter(target)) break;
      await _fire(next);
    }
    clock.set(target);
    await pump();
  }

  /// Moves time forward only as far as needed for [future] to complete.
  Future<T> drive<T>(Future<T> future) async {
    var done = false;
    T? value;
    Object? error;
    StackTrace? trace;
    unawaited(
      future.then<void>(
        (v) {
          done = true;
          value = v;
        },
        onError: (Object e, StackTrace s) {
          done = true;
          error = e;
          trace = s;
        },
      ),
    );
    for (var i = 0; i < 100000; i++) {
      await pump();
      if (done) {
        if (error != null) Error.throwWithStackTrace(error!, trace!);
        return value as T;
      }
      final next = _earliest();
      if (next == null) throw StateError('deadlock: no timer is pending');
      await _fire(next);
    }
    throw StateError('drive did not finish');
  }

  _Timer? _earliest() {
    _Timer? best;
    for (final timer in _timers) {
      if (best == null || timer.wakeAt.isBefore(best.wakeAt)) best = timer;
    }
    return best;
  }

  Future<void> _fire(_Timer timer) async {
    _timers.remove(timer);
    if (timer.wakeAt.isAfter(clock.now())) clock.set(timer.wakeAt);
    timer.completer.complete();
    await pump();
  }
}

final class _Timer {
  _Timer(this.wakeAt, this.completer);

  final DateTime wakeAt;
  final Completer<void> completer;
}
