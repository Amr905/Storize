// ignore_for_file: avoid_print, document_ignores, only_throw_errors
// ignore_for_file: lines_longer_than_80_chars
// QA (T-012): adversarial and budget tests. Independent of the developer's
// tests. Numbers are printed so the review can quote them.
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_model/storize_model.dart';

import 'fake_time.dart';

const _min = Duration(minutes: 1);

final class _Env {
  _Env({this.config = const GovernorConfig(), int seed = 7}) {
    repo = FakeGovernorLeaseRepo(time.clock);
    seedValue = seed;
  }

  final GovernorConfig config;
  final FakeTime time = FakeTime();
  late final FakeGovernorLeaseRepo repo;
  late final int seedValue;
  final List<String> logs = [];

  RequestGovernor gov(String holder, {GovernorConfig? cfg}) => RequestGovernor(
    leases: repo,
    clock: time.clock,
    holder: holder,
    config: cfg ?? config,
    delay: time.delay,
    random: Random(seedValue + holder.hashCode),
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
    if (n > best) best = n;
  }
  return best;
}

void main() {
  group('budget simulation', () {
    test('a realistic day: 50 targets, stories 30 min, posts 3 h', () async {
      final e = _Env();
      final g = e.gov('ui');
      final calls = <DateTime>[];
      final start = e.time.clock.now();
      Future<void> one() => g.run(
        accountId: 1,
        cost: RequestCost.api,
        call: () async => calls.add(e.time.clock.now()),
      );
      final postRoundEnds = <Duration>[];
      for (var m = 0; m < 24 * 60; m++) {
        if (m % 30 == 0) {
          unawaited(() async {
            for (var i = 0; i < 3; i++) {
              await one();
            }
          }());
        }
        if (m % 180 == 15) {
          final t0 = e.time.clock.now();
          unawaited(() async {
            for (var i = 0; i < 50; i++) {
              await one();
            }
            postRoundEnds.add(e.time.clock.now().difference(t0));
          }());
        }
        await e.time.elapse(_min);
      }
      final w60 = _maxInWindow(calls, const Duration(hours: 1));
      print(
        'REALISTIC DAY: calls=${calls.length} (${calls.length / 24}/h) '
        'maxIn60min=$w60 postRoundDurations=$postRoundEnds '
        'span=${calls.last.difference(start)}',
      );
      expect(calls.length, greaterThan(0));
    });

    test(
      'saturation: constant demand for 6 h, max calls in any 60 min',
      () async {
        final e = _Env();
        final g = e.gov('ui');
        final calls = <DateTime>[];
        final t0 = e.time.clock.now();
        var stop = false;
        unawaited(() async {
          while (!stop) {
            await g.run(
              accountId: 1,
              cost: RequestCost.api,
              call: () async => calls.add(e.time.clock.now()),
            );
          }
        }());
        await e.time.elapse(const Duration(hours: 6));
        stop = true;
        await e.time.elapse(const Duration(minutes: 5));
        final w60 = _maxInWindow(calls, const Duration(hours: 1));
        final first6 = calls.take(6).last.difference(t0);
        print(
          'SATURATION 6h: calls=${calls.length} maxIn60min=$w60 '
          'first6At=$first6',
        );
        // Gap check: never closer than jitterMin.
        var minGap = const Duration(days: 1);
        for (var i = 1; i < calls.length; i++) {
          final d = calls[i].difference(calls[i - 1]);
          if (d < minGap) minGap = d;
        }
        print('SATURATION minGap=$minGap');
        expect(
          minGap,
          greaterThanOrEqualTo(const Duration(milliseconds: 1500)),
        );
        expect(w60, lessThanOrEqualTo(66)); // burst 6 + 60/h
      },
    );

    test('saturation with page loads (cost 3) in the 60 min window', () async {
      final e = _Env();
      final g = e.gov('ui');
      final calls = <DateTime>[];
      var stop = false;
      unawaited(() async {
        while (!stop) {
          await g.run(
            accountId: 1,
            cost: RequestCost.pageLoad,
            call: () async => calls.add(e.time.clock.now()),
          );
        }
      }());
      await e.time.elapse(const Duration(hours: 3));
      stop = true;
      await e.time.elapse(const Duration(minutes: 10));
      print(
        'PAGELOAD 3h: loads=${calls.length} maxIn60min='
        '${_maxInWindow(calls, const Duration(hours: 1))}',
      );
    });
  });

  group('concurrency attacks', () {
    test('(a) two isolates hammer one account: no overlap, shared rate', () async {
      final e = _Env();
      final a = e.gov('A');
      final b = e.gov('B');
      var inFlight = 0;
      var maxInFlight = 0;
      final calls = <DateTime>[];
      var busy = 0;
      Future<void> hammer(RequestGovernor g) async {
        for (var i = 0; i < 40; i++) {
          try {
            await g.run(
              accountId: 1,
              cost: RequestCost.api,
              call: () async {
                inFlight++;
                maxInFlight = max(maxInFlight, inFlight);
                calls.add(e.time.clock.now());
                // A real call takes time.
                await e.time.delay(const Duration(milliseconds: 800));
                inFlight--;
              },
            );
          } on GovernorBusy {
            busy++;
          }
        }
      }

      final t0 = e.time.clock.now();
      await e.time.drive(Future.wait([hammer(a), hammer(b)]));
      final elapsed = e.time.clock.now().difference(t0);
      print(
        'ATTACK a: calls=${calls.length} busy=$busy maxInFlight=$maxInFlight '
        'elapsed=$elapsed maxIn60=${_maxInWindow(calls, const Duration(hours: 1))}',
      );
      expect(maxInFlight, 1);
      // 6 burst + 1/min: n calls need at least (n-6) minutes.
      expect(
        elapsed,
        greaterThanOrEqualTo(Duration(minutes: calls.length - 6) - _min),
      );
    });

    test(
      '(b) lease expires mid-wait, other takes over: no double spend',
      () async {
        // Short ttl so it expires while A still has a long token wait.
        const cfg = GovernorConfig(
          leaseTtl: Duration(seconds: 30),
          jitterMin: Duration.zero,
          jitterMax: Duration.zero,
        );
        final e = _Env(config: cfg);
        final a = e.gov('A');
        final b = e.gov('B');
        final calls = <(String, DateTime)>[];
        // Drain the bucket with A.
        for (var i = 0; i < 6; i++) {
          await e.time.drive(
            a.run(
              accountId: 1,
              cost: RequestCost.api,
              call: () async => calls.add(('A', e.time.clock.now())),
            ),
          );
        }
        // A waits ~1 min for a token; B also wants one.
        final fa = a.run(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => calls.add(('A', e.time.clock.now())),
        );
        final fb = b.run(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => calls.add(('B', e.time.clock.now())),
        );
        await e.time.drive(Future.wait([fa, fb]));
        print('ATTACK b: ${calls.skip(6).toList()}');
        final late = calls.skip(6).toList();
        expect(late.length, 2);
        expect(
          late[1].$2.difference(late[0].$2),
          greaterThanOrEqualTo(_min - const Duration(seconds: 1)),
        );
      },
    );

    test(
      '(b2) lease TTL shorter than call: A _finish after takeover',
      () async {
        final e = _Env(
          config: const GovernorConfig(
            leaseTtl: Duration(seconds: 30),
            jitterMin: Duration.zero,
            jitterMax: Duration.zero,
            acquireTimeout: Duration(seconds: 20),
          ),
        );
        final a = e.gov('A');
        final b = e.gov('B');
        Object? err;
        final fa = a
            .run<void>(
              accountId: 1,
              cost: RequestCost.api,
              call: () async {
                await e.time.delay(const Duration(seconds: 60)); // > ttl
                throw const RateLimited(null);
              },
            )
            .catchError((Object x) => err = x);
        await e.time.pump();
        await e.time.elapse(const Duration(seconds: 40));
        // B takes over the expired lease, holds it (long call).
        final fb = b.run<void>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => e.time.delay(const Duration(seconds: 120)),
        );
        await e.time.pump();
        await e.time.drive(Future.wait([fa, fb]));
        final bucket = (await e.repo.read(1))!.bucket;
        print(
          'ATTACK b2: A error=$err backoffUntil=${bucket.backoffUntil} '
          'mult=${bucket.backoffMultiplier}',
        );
      },
    );

    test(
      '(c) exception inside call: token consumed, slot and lease freed',
      () async {
        final e = _Env();
        final g = e.gov('A');
        final before = await g.remainingTokens(1);
        Object? err;
        try {
          await e.time.drive(
            g.run<void>(
              accountId: 1,
              cost: RequestCost.api,
              call: () async => throw StateError('boom'),
            ),
          );
        } on Object catch (x) {
          err = x;
        }
        expect(err, isA<StateError>());
        expect(await g.remainingTokens(1), closeTo(before - 1, 1e-6));
        final lease = await e.repo.read(1);
        expect(lease!.isHeldAt(e.time.clock.now()), isFalse);
        // Next run proceeds (after jitter) in the same isolate and in B.
        await e.time.drive(
          e
              .gov('B')
              .run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
        await e.time.drive(
          g.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
      },
    );

    test('(c2) synchronous throw / thrown RateLimited', () async {
      final e = _Env();
      final g = e.gov('A');
      Object? err;
      try {
        await e.time.drive(
          g.run<void>(
            accountId: 1,
            cost: RequestCost.api,
            call: () => throw StateError('sync'),
          ),
        );
      } on Object catch (x) {
        err = x;
      }
      expect(err, isA<StateError>());
      expect(
        (await e.repo.read(1))!.isHeldAt(e.time.clock.now()),
        isFalse,
      );
    });

    test('(d) reportRateLimited in B while A runs a call', () async {
      final e = _Env();
      final a = e.gov('A');
      final b = e.gov('B');
      final callGate = Completer<void>();
      final fa = a.run<void>(
        accountId: 1,
        cost: RequestCost.api,
        call: () => callGate.future,
      );
      await e.time.pump();
      Object? berr;
      final fb = b
          .reportRateLimited(1, const RateLimited(null))
          .catchError((Object x) => berr = x);
      await e.time.pump();
      // A finishes after 30 s.
      await e.time.elapse(const Duration(seconds: 30));
      callGate.complete();
      await e.time.drive(Future.wait([fa, fb]));
      final paused = await a.isPaused(1);
      print('ATTACK d: B error=$berr paused=$paused');
      expect(berr, isNull);
      expect(paused, isTrue);
    });

    test(
      '(d2) reportRateLimited in B while A holds lease > acquireTimeout',
      () async {
        final e = _Env();
        final a = e.gov('A');
        final b = e.gov('B');
        final callGate = Completer<void>();
        final fa = a.run<void>(
          accountId: 1,
          cost: RequestCost.api,
          call: () => callGate.future,
        );
        await e.time.pump();
        Object? berr;
        final fb = b
            .reportRateLimited(1, const RateLimited(null))
            .catchError((Object x) => berr = x);
        await e.time.elapse(const Duration(minutes: 3));
        callGate.complete();
        await e.time.drive(Future.wait([fa, fb]));
        expect(berr, isNull, reason: 'a rate limit is never dropped');
        expect(await a.isPaused(1), isTrue);
      },
    );

    test(
      '(d3) A call finishes RateLimited while B is queued: B refused',
      () async {
        final e = _Env();
        final a = e.gov('A');
        final b = e.gov('B');
        final fa = a.run<Result<int>>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async {
            await e.time.delay(const Duration(seconds: 10));
            return const Err<int>(RateLimited(null));
          },
        );
        await e.time.pump();
        Object? berr;
        final fb = b
            .run<int>(accountId: 1, cost: RequestCost.api, call: () async => 1)
            .catchError((Object x) {
              berr = x;
              return 0;
            });
        await e.time.drive(Future.wait([fa, fb]));
        expect(berr, isA<GovernorPaused>());
      },
    );

    test(
      '(e) clock goes back 1 h after a call: waits stay bounded',
      () async {
        final e = _Env();
        final g = e.gov('A');
        await e.time.drive(
          g.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
        e.time.clock.advance(const Duration(minutes: -60));
        final t0 = e.time.clock.now();
        await e.time.drive(
          g.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
        final waited = e.time.clock.now().difference(t0);
        print('ATTACK e (back 1 h): next call waited $waited');
        expect(waited.isNegative, isFalse);
        expect(waited, lessThan(const Duration(minutes: 1)));
      },
    );

    test(
      '(e2) clock goes back 1 day, other isolate B (repo applies T-012a rule)',
      () async {
        // The repo treats an impossible expiry as expired (T-012a), so B
        // does not wait for the clock to catch up.
        final e = _Env();
        final a = RequestGovernor(
          leases: e.repo,
          clock: e.time.clock,
          holder: 'A',
          delay: e.time.delay,
          random: Random(1),
        );
        final b = RequestGovernor(
          leases: e.repo,
          clock: e.time.clock,
          holder: 'B',
          delay: e.time.delay,
          random: Random(2),
        );
        await e.time.drive(
          a.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
        e.time.clock.advance(const Duration(days: -1));
        final t0 = e.time.clock.now();
        await e.time.drive(
          b.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
        final waited = e.time.clock.now().difference(t0);
        print('ATTACK e2 (back 1 day): waited $waited');
        expect(waited, lessThan(const Duration(minutes: 1)));
      },
    );

    test('(e3) clock goes back while paused: pause length', () async {
      final e = _Env();
      final g = e.gov('A');
      await e.time.drive(
        g.run<Result<int>>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => const Err<int>(RateLimited(null)),
        ),
      );
      e.time.clock.advance(const Duration(hours: -5));
      final until = await g.pausedUntil(1);
      final left = until?.difference(e.time.clock.now());
      // (stored 15 min pause, clock moved back 5 h: the pause is not 5 h 15 m)
      print('ATTACK e3 (back 5 h while paused): pause left=$left');
    });

    test('(e4) clock jumps forward 1 week: refill capped at burst', () async {
      final e = _Env();
      final g = e.gov('A');
      for (var i = 0; i < 6; i++) {
        await e.time.drive(
          g.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
      }
      e.time.clock.advance(const Duration(days: 7));
      expect(await g.remainingTokens(1), lessThanOrEqualTo(6.0));
    });

    test('(f) retryAfter 30 days', () async {
      final e = _Env();
      final g = e.gov('A');
      await e.time.drive(
        g.run<Result<int>>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => const Err<int>(RateLimited(Duration(days: 30))),
        ),
      );
      final until = await g.pausedUntil(1);
      final m = await g.effectiveIntervalMultiplier(1);
      print(
        'ATTACK f: pause=${until!.difference(e.time.clock.now())} mult=$m',
      );
      expect(until.difference(e.time.clock.now()), const Duration(hours: 24));
    });

    test('(f2) negative retryAfter', () async {
      final e = _Env();
      final g = e.gov('A');
      await e.time.drive(
        g.run<Result<int>>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => const Err<int>(RateLimited(Duration(seconds: -5))),
        ),
      );
      final until = await g.pausedUntil(1);
      expect(
        until!.difference(e.time.clock.now()),
        const Duration(minutes: 15),
      );
    });
  });

  group('re-entrancy', () {
    test(
      'nested run for the same account is refused, not deadlocked',
      () async {
        final e = _Env();
        final g = e.gov('A');
        Object? err;
        try {
          await e.time.drive(
            g.run<int>(
              accountId: 1,
              cost: RequestCost.api,
              call: () => g.run<int>(
                accountId: 1,
                cost: RequestCost.api,
                call: () async => 1,
              ),
            ),
          );
        } on Object catch (x) {
          err = x;
        }
        expect(err, isA<StateError>());
        expect(err.toString(), contains('not re-entrant'));
      },
    );
  });

  group('starvation', () {
    test(
      'A has a long queue; B still gets a call in within a jitter gap',
      () async {
        final e = _Env();
        final a = e.gov('A');
        final b = e.gov('B');
        var aDone = 0;
        final qa = <Future<void>>[
          for (var i = 0; i < 50; i++)
            a.run(
              accountId: 1,
              cost: RequestCost.api,
              call: () async => aDone++,
            ),
        ];
        await e.time.pump();
        Object? berr;
        final t0 = e.time.clock.now();
        DateTime? bRan;
        final fb = b
            .run<int>(
              accountId: 1,
              cost: RequestCost.api,
              call: () async {
                bRan = e.time.clock.now();
                return 1;
              },
            )
            .catchError((Object x) {
              berr = x;
              return 0;
            });
        await e.time.drive(fb);
        final waited = e.time.clock.now().difference(t0);
        print(
          'STARVATION: B error=$berr waited=$waited ran=${bRan != null}; '
          'A done=$aDone of 50',
        );
        expect(berr, isNull);
        expect(bRan, isNotNull);
        expect(waited, lessThanOrEqualTo(const Duration(seconds: 6)));
        expect(aDone, lessThan(50), reason: 'B did not wait for the queue');
        await e.time.drive(Future.wait(qa));
      },
    );

    test('B arriving while A is in a long token wait between rounds', () async {
      // A has a 2-call queue, bucket drained => A waits ~1 min holding lease.
      final e = _Env();
      final a = e.gov('A');
      final b = e.gov('B');
      for (var i = 0; i < 6; i++) {
        await e.time.drive(
          a.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
      }
      final fa = a.run(
        accountId: 1,
        cost: RequestCost.api,
        call: () async => 1,
      );
      await e.time.pump();
      Object? berr;
      final fb = b
          .run<int>(accountId: 1, cost: RequestCost.api, call: () async => 1)
          .catchError((Object x) {
            berr = x;
            return 0;
          });
      await e.time.drive(Future.wait([fa, fb]));
      print('STARVATION 2: B error=$berr');
    });
  });

  group('logging', () {
    test('log lines only carry account, cost, wait, outcome', () async {
      final e = _Env();
      final g = e.gov('A');
      await e.time.drive(
        g.run<String>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => 'https://instagram.com/x?sessionid=SECRET',
        ),
      );
      try {
        await e.time.drive(
          g.run<void>(
            accountId: 1,
            cost: RequestCost.api,
            call: () async => throw StateError('cookie=SECRET url=http://x'),
          ),
        );
      } on Object {
        // expected
      }
      for (final line in e.logs) {
        expect(
          line,
          matches(
            RegExp(
              r'^governor account=\d+ cost=\S+ waited_ms=\d+ outcome=\w+$',
            ),
          ),
        );
        expect(line, isNot(contains('SECRET')));
      }
    });
  });

  group('API usability', () {
    test('GovernorPaused.toFailure maps to RateLimited', () async {
      final e = _Env();
      final g = e.gov('A');
      await e.time.drive(
        g.run<Result<int>>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => const Err<int>(RateLimited(Duration(minutes: 5))),
        ),
      );
      Object? err;
      try {
        await e.time.drive(
          g.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        );
      } on Object catch (x) {
        err = x;
      }
      expect(err, isA<GovernorPaused>());
      final f = (err! as GovernorPaused).toFailure();
      expect(f, isA<RateLimited>());
      expect(f.retryAfter, lessThanOrEqualTo(const Duration(minutes: 5)));
    });

    test(
      'feeding a handled failure back is ignored (QA-F6)',
      () async {
        // If an adapter catches GovernorPaused, maps it to Err(RateLimited) and
        // that Err flows back through a SECOND run(), the pause is re-applied.
        final e = _Env();
        final g = e.gov('A');
        await e.time.drive(
          g.run<Result<int>>(
            accountId: 1,
            cost: RequestCost.api,
            call: () async => const Err<int>(RateLimited(Duration(minutes: 5))),
          ),
        );
        final until1 = await g.pausedUntil(1);
        e.time.clock.advance(const Duration(minutes: 3));
        // Misuse: report the mapped failure again.
        await e.time.drive(
          g.reportRateLimited(1, const RateLimited(Duration(minutes: 2))),
        );
        final until2 = await g.pausedUntil(1);
        final mult = await g.effectiveIntervalMultiplier(1);
        print('MISUSE: until1=$until1 until2=$until2 mult=$mult');
        expect(mult, 2); // the double report is ignored (QA-F6)
        expect(until2, until1);
      },
    );

    test('canAfford for carry-over', () async {
      final e = _Env();
      final g = e.gov('A');
      expect(await g.canAfford(1, RequestCost.api, calls: 6), isTrue);
      expect(await g.canAfford(1, RequestCost.api, calls: 7), isFalse);
      expect(await g.canAfford(1, RequestCost.pageLoad, calls: 2), isTrue);
      expect(await g.canAfford(1, RequestCost.pageLoad, calls: 3), isFalse);
    });
  });
}
