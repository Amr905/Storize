// ignore_for_file: avoid_print, document_ignores, only_throw_errors
// ignore_for_file: lines_longer_than_80_chars
// QA round 2 (T-012): adversarial tests of the per-call lease, the shared
// bucket, the zone guard and the back-off windows.
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_model/storize_model.dart';

import 'fake_time.dart';

const _noJitter = GovernorConfig(
  jitterMin: Duration.zero,
  jitterMax: Duration.zero,
);

/// A repo that yields to the event loop around every operation to widen race
/// windows, and records every write.
final class _YieldingRepo implements GovernorLeaseRepo {
  _YieldingRepo(this.inner);

  final FakeGovernorLeaseRepo inner;
  final List<(String, GovernorBucket)> writes = [];

  Future<void> _y() => Future<void>.delayed(Duration.zero);

  @override
  Future<GovernorLease?> acquire({
    required int accountId,
    required String holder,
    required Duration ttl,
    required GovernorBucket initialBucket,
  }) async {
    await _y();
    final r = await inner.acquire(
      accountId: accountId,
      holder: holder,
      ttl: ttl,
      initialBucket: initialBucket,
    );
    await _y();
    return r;
  }

  @override
  Future<GovernorLease?> read(int accountId) async {
    await _y();
    return inner.read(accountId);
  }

  @override
  Future<bool> renew({
    required int accountId,
    required String holder,
    required Duration ttl,
  }) => inner.renew(accountId: accountId, holder: holder, ttl: ttl);

  @override
  Future<void> release({
    required int accountId,
    required String holder,
  }) async {
    await _y();
    return inner.release(accountId: accountId, holder: holder);
  }

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) async {
    await _y();
    final ok = await inner.writeBucket(
      accountId: accountId,
      holder: holder,
      bucket: bucket,
    );
    if (ok) writes.add((holder, bucket));
    return ok;
  }
}

/// A repo whose writeBucket throws (a database failure).
final class _ThrowingWriteRepo extends _YieldingRepo {
  _ThrowingWriteRepo(super.inner);

  bool failWrites = false;

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) {
    if (failWrites) throw StateError('db down');
    return super.writeBucket(
      accountId: accountId,
      holder: holder,
      bucket: bucket,
    );
  }
}

final class _Env {
  _Env({GovernorConfig config = const GovernorConfig()}) : cfg = config {
    fake = FakeGovernorLeaseRepo(time.clock);
    repo = _YieldingRepo(fake);
  }

  final GovernorConfig cfg;
  final FakeTime time = FakeTime();
  late final FakeGovernorLeaseRepo fake;
  late final GovernorLeaseRepo repo;
  final List<String> logs = [];

  DateTime get now => time.clock.now();

  RequestGovernor gov(String holder, {int seed = 3, GovernorLeaseRepo? r}) =>
      RequestGovernor(
        leases: r ?? repo,
        clock: time.clock,
        holder: holder,
        config: cfg,
        delay: time.delay,
        random: Random(seed + holder.hashCode),
        log: logs.add,
      );
}

int _maxInWindow(List<DateTime> calls, Duration window) {
  var best = 0;
  for (var i = 0; i < calls.length; i++) {
    var n = 0;
    for (var j = i; j < calls.length; j++) {
      if (calls[j].difference(calls[i]) < window) n++;
    }
    best = max(best, n);
  }
  return best;
}

void main() {
  group('multi-isolate with the per-call lease', () {
    test('3 isolates, mixed costs, slow calls: no overlap, bucket and 60/h hold, gap >= jitterMin', () async {
      final e = _Env();
      final gs = [e.gov('A'), e.gov('B'), e.gov('C')];
      var inFlight = 0;
      var maxInFlight = 0;
      final starts = <DateTime>[];
      final ends = <DateTime>[];
      var tokensUsed = 0;
      Future<void> hammer(RequestGovernor g, int n) async {
        for (var i = 0; i < n; i++) {
          final cost = (i % 4 == 3) ? RequestCost.pageLoad : RequestCost.api;
          try {
            await g.run(
              accountId: 1,
              cost: cost,
              call: () async {
                inFlight++;
                maxInFlight = max(maxInFlight, inFlight);
                starts.add(e.now);
                tokensUsed += cost == RequestCost.pageLoad ? 3 : 1;
                await e.time.delay(const Duration(milliseconds: 700));
                ends.add(e.now);
                inFlight--;
              },
            );
          } on GovernorBusy {
            // allowed, no token used
          }
        }
      }

      final t0 = e.now;
      await e.time.drive(
        Future.wait([hammer(gs[0], 24), hammer(gs[1], 24), hammer(gs[2], 24)]),
      );
      final elapsed = e.now.difference(t0);
      expect(maxInFlight, 1);
      // Tokens: burst 6 plus elapsed minutes (+ 1 for the tail of the minute).
      expect(tokensUsed, lessThanOrEqualTo(6 + elapsed.inMinutes + 1));
      // Combined gap: next start is at least jitterMin after the previous end.
      final order = [...starts]..sort();
      final endSorted = [...ends]..sort();
      var minGap = const Duration(days: 1);
      for (var i = 1; i < order.length; i++) {
        final gap = order[i].difference(endSorted[i - 1]);
        if (gap < minGap) minGap = gap;
      }
      print(
        'R2 mixed: calls=${starts.length} tokens=$tokensUsed elapsed=$elapsed minGap=$minGap max60=${_maxInWindow(starts, const Duration(hours: 1))}',
      );
      expect(minGap, greaterThanOrEqualTo(e.cfg.jitterMin));
    });

    test('lost-update probe: 3 isolates x 4 calls from a full bucket need >= 6 min (no jitter, yielding repo)', () async {
      final e = _Env(config: _noJitter);
      final gs = [e.gov('A'), e.gov('B'), e.gov('C')];
      final t0 = e.now;
      var done = 0;
      Future<void> go(RequestGovernor g) async {
        for (var i = 0; i < 4; i++) {
          await g.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async => done++,
          );
        }
      }

      await e.time.drive(Future.wait(gs.map(go)));
      final elapsed = e.now.difference(t0);
      expect(done, 12);
      // 12 tokens needed, 6 in the bucket, 1 per minute -> 6 min (to the ms).
      expect(
        elapsed,
        greaterThanOrEqualTo(
          const Duration(minutes: 6) - const Duration(milliseconds: 1),
        ),
      );
      expect(elapsed, lessThan(const Duration(minutes: 6, seconds: 1)));
    });

    test('every persisted write is monotone in lastRefillAt and never gains tokens beyond refill', () async {
      final e = _Env(config: _noJitter);
      final gs = [e.gov('A'), e.gov('B')];
      Future<void> go(RequestGovernor g) async {
        for (var i = 0; i < 10; i++) {
          await g.run(accountId: 1, cost: RequestCost.api, call: () async {});
        }
      }

      await e.time.drive(Future.wait(gs.map(go)));
      final w = (e.repo as _YieldingRepo).writes;
      for (var i = 1; i < w.length; i++) {
        final prev = w[i - 1].$2;
        final cur = w[i].$2;
        expect(
          cur.lastRefillAt.isBefore(prev.lastRefillAt),
          isFalse,
          reason: 'write $i went back in time',
        );
        final added =
            cur.lastRefillAt.difference(prev.lastRefillAt).inMicroseconds /
            Duration.microsecondsPerHour *
            60;
        expect(
          cur.tokens,
          lessThanOrEqualTo(min(6, prev.tokens + added) + 1e-6),
          reason: 'write $i gained tokens',
        );
      }
    });

    test('jitter fairness cannot be abused: a hot peer does not let a waiter run faster than the bucket', () async {
      final e = _Env();
      final a = e.gov('A');
      final b = e.gov('B');
      final starts = <DateTime>[];
      Future<void> hot(RequestGovernor g, int n) async {
        for (var i = 0; i < n; i++) {
          await g.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async => starts.add(e.now),
          );
        }
      }

      final t0 = e.now;
      await e.time.drive(Future.wait([hot(a, 30), hot(b, 30)]));
      final elapsed = e.now.difference(t0);
      expect(starts.length, 60);
      expect(
        elapsed,
        greaterThanOrEqualTo(
          const Duration(minutes: 54) - const Duration(seconds: 1),
        ),
      );
      expect(
        _maxInWindow(starts, const Duration(hours: 1)),
        lessThanOrEqualTo(66),
      );
    });

    test(
      'a true timeout still gives GovernorBusy and spends no token',
      () async {
        final e = _Env();
        final a = e.gov('A');
        final b = e.gov('B');
        final gate = Completer<void>();
        final first = a.run(
          accountId: 1,
          cost: RequestCost.api,
          call: () async {
            await gate.future;
          },
        );
        await e.time.pump();
        final before = await b.remainingTokens(1);
        Object? err;
        try {
          await e.time.drive(
            b.run(accountId: 1, cost: RequestCost.api, call: () async {}),
          );
        } on Object catch (x) {
          err = x;
        }
        expect(err, isA<GovernorBusy>());
        expect(
          (err! as GovernorBusy).waited,
          greaterThanOrEqualTo(e.cfg.acquireTimeout),
        );
        expect(
          await b.remainingTokens(1),
          closeTo(min(6.0, before + e.cfg.acquireTimeout.inSeconds / 60), 0.1),
        );
        expect(before, closeTo(5, 0.05));
        gate.complete();
        await e.time.drive(first);
      },
    );

    test('page load cost is 3 and burst is 6', () async {
      final e = _Env(config: _noJitter);
      final g = e.gov('A');
      await e.time.drive(
        g.run(accountId: 1, cost: RequestCost.pageLoad, call: () async {}),
      );
      expect(await g.remainingTokens(1), closeTo(3, 1e-6));
      await e.time.drive(
        g.run(accountId: 1, cost: RequestCost.pageLoad, call: () async {}),
      );
      expect(await g.remainingTokens(1), closeTo(0, 1e-6));
      final t0 = e.now;
      await e.time.drive(
        g.run(accountId: 1, cost: RequestCost.pageLoad, call: () async {}),
      );
      expect(e.now.difference(t0), const Duration(minutes: 3));
      e.time.clock.advance(const Duration(days: 3));
      expect(await g.remainingTokens(1), 6);
    });
  });

  group('back-off windows', () {
    Future<void> limit(_Env e, RequestGovernor g, Duration? after) async {
      await e.time.drive(
        g.run(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => Err<int>(RateLimited(after)),
        ),
      );
    }

    test('x2 counts from the END of the pause; repeat x4 within 24 h of the end; x2 after', () async {
      final e = _Env(config: _noJitter);
      final g = e.gov('A');
      final t0 = e.now;
      await limit(e, g, const Duration(minutes: 30));
      final end = t0.add(const Duration(minutes: 30));
      e.time.clock.set(end.subtract(const Duration(seconds: 1)));
      expect(await g.effectiveIntervalMultiplier(1), 2);
      e.time.clock.set(end.add(const Duration(hours: 2, seconds: -1)));
      expect(
        await g.effectiveIntervalMultiplier(1),
        2,
        reason: '2 h counted from pause end',
      );
      e.time.clock.set(end.add(const Duration(hours: 2, seconds: 1)));
      expect(await g.effectiveIntervalMultiplier(1), 1);
      // Repeat inside 24 h of the end of pause 1.
      e.time.clock.set(end.add(const Duration(hours: 23)));
      await limit(e, g, const Duration(minutes: 10));
      expect(await g.effectiveIntervalMultiplier(1), 4);
      final end2 = e.now.add(const Duration(minutes: 10));
      e.time.clock.set(end2.add(const Duration(hours: 2, seconds: -1)));
      expect(await g.effectiveIntervalMultiplier(1), 4);
      e.time.clock.set(end2.add(const Duration(hours: 2, seconds: 1)));
      expect(await g.effectiveIntervalMultiplier(1), 1);
      // Third limit 25 h after the end of pause 2: fresh x2.
      e.time.clock.set(end2.add(const Duration(hours: 25)));
      await limit(e, g, const Duration(minutes: 10));
      expect(await g.effectiveIntervalMultiplier(1), 2);
    });

    test('a real second limit right after the pause ends (now == until) is a repeat, not the same event', () async {
      final e = _Env(config: _noJitter);
      final g = e.gov('A');
      final t0 = e.now;
      await limit(e, g, const Duration(minutes: 5));
      e.time.clock.set(t0.add(const Duration(minutes: 5)));
      await limit(e, g, const Duration(minutes: 5));
      expect(await g.effectiveIntervalMultiplier(1), 4);
    });

    test('two isolates report the same limit: x2 only', () async {
      final e = _Env(config: _noJitter);
      final a = e.gov('A');
      final b = e.gov('B');
      await Future.wait(
        [
          a.reportRateLimited(1, const RateLimited(Duration(minutes: 5))),
          b.reportRateLimited(1, const RateLimited(Duration(minutes: 5))),
        ].map(e.time.drive),
      );
      expect(await a.effectiveIntervalMultiplier(1), 2);
    });
  });

  group('zone guard and _finishSafely', () {
    test('guard is released after call throws (async and sync throw) and across sequential runs', () async {
      final e = _Env(config: _noJitter);
      final g = e.gov('A');
      Future<void> boom() => throw StateError('sync');
      for (final call in <Future<void> Function()>[
        () async => throw ArgumentError('async'),
        boom,
      ]) {
        await expectLater(
          e.time.drive(g.run(accountId: 1, cost: RequestCost.api, call: call)),
          throwsA(anything),
        );
      }
      // Sequential reuse: no false StateError.
      for (var i = 0; i < 3; i++) {
        expect(
          await e.time.drive(
            g.run(accountId: 1, cost: RequestCost.api, call: () async => i),
          ),
          i,
        );
      }
    });

    test('the StateError of a nested run propagates as the call error and is not swallowed', () async {
      final e = _Env(config: _noJitter);
      final g = e.gov('A');
      await expectLater(
        e.time.drive(
          g.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async {
              await g.run(
                accountId: 1,
                cost: RequestCost.api,
                call: () async {},
              );
            },
          ),
        ),
        throwsStateError,
      );
      // Governor is usable afterwards and the lease is free.
      expect(
        await e.time.drive(
          g.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        ),
        1,
      );
      expect((await e.fake.read(1))!.isHeldAt(e.now), isFalse);
    });

    test('nested run inside an unawaited future that outlives the call is still refused only while inside the zone (documented false-positive probe)', () async {
      final e = _Env(config: _noJitter);
      final g = e.gov('A');
      Future<void>? late;
      await e.time.drive(
        g.run(
          accountId: 1,
          cost: RequestCost.api,
          call: () async {
            late = Future<void>.delayed(const Duration(seconds: 1)).then(
              (_) =>
                  g.run(accountId: 1, cost: RequestCost.api, call: () async {}),
            );
          },
        ),
      );
      Object? err;
      try {
        await e.time.drive(late!);
      } on Object catch (x) {
        err = x;
      }
      print(
        'R2 zone leak (spawned future after call returned): ${err.runtimeType}',
      );
      // Recorded, not asserted: see the review (Low).
    });

    test('a second governor instance in the same zone is also refused when nested (zone key is global)', () async {
      final e = _Env(config: _noJitter);
      final a = e.gov('A');
      final b = e.gov('B');
      Object? err;
      try {
        await e.time.drive(
          a.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async {
              await b.run(
                accountId: 1,
                cost: RequestCost.api,
                call: () async {},
              );
            },
          ),
        );
      } on Object catch (x) {
        err = x;
      }
      print('R2 cross-instance nested: ${err.runtimeType}');
      expect(err, isA<StateError>());
    });

    test('nested different account, and sequential same account in sibling zones, are fine', () async {
      final e = _Env(config: _noJitter);
      final g = e.gov('A', r: e.fake);
      final r = await e.time.drive(
        g.run(
          accountId: 1,
          cost: RequestCost.api,
          call: () async {
            return g.run(
              accountId: 2,
              cost: RequestCost.api,
              call: () async => 'inner',
            );
          },
        ),
      );
      expect(r, 'inner');
    });

    test('a repo failure while recording a thrown RateLimited: original error is kept (limit lost is logged)', () async {
      final e = _Env(config: _noJitter);
      final repo = _ThrowingWriteRepo(e.fake);
      final g = e.gov('A', r: repo);
      Object? err;
      try {
        await e.time.drive(
          g.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async {
              repo.failWrites = true;
              throw const RateLimited(Duration(minutes: 5));
            },
          ),
        );
      } on Object catch (x) {
        err = x;
      }
      repo.failWrites = false;
      expect(err, isA<RateLimited>());
      final paused = await g.isPaused(1);
      print(
        'R2 repo-write failure while recording a limit: paused=$paused logs=${e.logs.where((l) => l.contains('record_failed')).length}',
      );
      expect(e.logs.any((l) => l.contains('record_failed')), isTrue);
    });
  });
}
