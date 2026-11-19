import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_model/storize_model.dart';

import 'fake_time.dart';

/// A [Random] whose `nextDouble` always returns [value].
final class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

/// No jitter, so token timing is exact.
const _noJitter = GovernorConfig(
  jitterMin: Duration.zero,
  jitterMax: Duration.zero,
);

const _minute = Duration(minutes: 1);
const _hour = Duration(hours: 1);

/// Two "isolates" are two governors on one repo and one clock.
final class _Harness {
  _Harness() {
    repo = FakeGovernorLeaseRepo(time.clock);
  }

  final FakeTime time = FakeTime();
  late final FakeGovernorLeaseRepo repo;
  final List<String> logs = [];

  DateTime get now => time.clock.now();

  RequestGovernor governor(
    String holder, {
    GovernorConfig config = _noJitter,
    Random? random,
  }) => RequestGovernor(
    leases: repo,
    clock: time.clock,
    holder: holder,
    config: config,
    delay: time.delay,
    random: random ?? _FixedRandom(0.5),
    log: logs.add,
  );

  Future<T> run<T>(
    RequestGovernor governor,
    Future<T> Function() call, {
    int accountId = 1,
    RequestCost cost = RequestCost.api,
  }) => time.drive(
    governor.run(accountId: accountId, cost: cost, call: call),
  );
}

Future<Object?> _errorOf(Future<Object?> future) async {
  try {
    await future;
    return null;
  } on Object catch (error) {
    return error;
  }
}

void main() {
  late _Harness h;

  setUp(() => h = _Harness());

  group('AC1 token bucket: 60/h, burst 6, page load costs 3', () {
    test('the defaults are the ADR-9 numbers', () {
      const config = GovernorConfig();
      expect(config.callsPerHour, 60);
      expect(config.burst, 6);
      expect(config.weightOf(RequestCost.api), 1);
      expect(config.weightOf(RequestCost.pageLoad), 3);
    });

    test(
      'burst of 6 passes at once, the 7th waits one minute for a token',
      () async {
        final g = h.governor('ui');
        for (var i = 0; i < 6; i++) {
          await h.run(g, () async => i);
        }
        expect(
          h.now,
          DateTime.utc(2026),
          reason: 'no waiting inside the burst',
        );
        expect(await g.remainingTokens(1), 0);

        var done = false;
        final seventh = h.run(g, () async => 7).then((_) => done = true);
        await h.time.elapse(const Duration(seconds: 59));
        expect(done, isFalse);
        await h.time.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
        await seventh;
      },
    );

    test('tokens refill continuously, never above the burst', () async {
      final g = h.governor('ui');
      for (var i = 0; i < 6; i++) {
        await h.run(g, () async => i);
      }
      h.time.clock.advance(const Duration(seconds: 30));
      expect(await g.remainingTokens(1), closeTo(0.5, 1e-9));
      h.time.clock.advance(const Duration(minutes: 3));
      expect(await g.remainingTokens(1), closeTo(3.5, 1e-9));
      h.time.clock.advance(_hour * 5);
      expect(await g.remainingTokens(1), 6);
    });

    test('a page load takes 3 tokens, so two fit a full bucket', () async {
      final g = h.governor('ui');
      await h.run(g, () async => 1, cost: RequestCost.pageLoad);
      expect(await g.remainingTokens(1), 3);
      await h.run(g, () async => 1, cost: RequestCost.pageLoad);
      expect(await g.remainingTokens(1), 0);

      var done = false;
      final third = h
          .run(g, () async => 1, cost: RequestCost.pageLoad)
          .then((_) => done = true);
      await h.time.elapse(const Duration(minutes: 2, seconds: 59));
      expect(done, isFalse);
      await h.time.elapse(const Duration(seconds: 1));
      expect(done, isTrue);
      await third;
    });

    test('accounts have separate buckets', () async {
      final g = h.governor('ui');
      for (var i = 0; i < 6; i++) {
        await h.run(g, () async => i);
      }
      expect(await g.remainingTokens(1), 0);
      expect(await g.remainingTokens(2), 6);
    });

    test('canAfford counts tokens and refuses while paused', () async {
      final g = h.governor('ui');
      expect(await g.canAfford(1, RequestCost.api), isTrue);
      expect(await g.canAfford(1, RequestCost.pageLoad, calls: 2), isTrue);
      expect(await g.canAfford(1, RequestCost.pageLoad, calls: 3), isFalse);
      for (var i = 0; i < 4; i++) {
        await h.run(g, () async => i);
      }
      expect(await g.canAfford(1, RequestCost.api, calls: 2), isTrue);
      expect(await g.canAfford(1, RequestCost.api, calls: 3), isFalse);
      expect(await g.canAfford(1, RequestCost.pageLoad), isFalse);

      await g.reportRateLimited(1, const RateLimited(null));
      expect(await g.canAfford(1, RequestCost.api), isFalse);
    });

    test('a cost above the burst is rejected up front', () {
      final g = h.governor('ui', config: const GovernorConfig(burst: 2));
      expect(
        () => g.run(
          accountId: 1,
          cost: RequestCost.pageLoad,
          call: () async => 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('AC2 jitter 1.5-6 s between calls', () {
    test('the first call of an account does not wait', () async {
      final g = h.governor('ui', config: const GovernorConfig());
      DateTime? startedAt;
      await h.run(g, () async => startedAt = h.now);
      expect(startedAt, DateTime.utc(2026));
    });

    test('the gap is jitterMin at 0.0 and jitterMax at the top', () async {
      for (final (value, expected) in [
        (0.0, const Duration(milliseconds: 1500)),
        (0.5, const Duration(milliseconds: 3750)),
        (1.0, const Duration(seconds: 6)),
      ]) {
        final fresh = _Harness();
        final g = fresh.governor(
          'ui',
          config: const GovernorConfig(),
          random: _FixedRandom(value),
        );
        final starts = <DateTime>[];
        for (var i = 0; i < 2; i++) {
          await fresh.run(g, () async => starts.add(fresh.now));
        }
        expect(starts[1].difference(starts[0]), expected, reason: '$value');
      }
    });

    test('with a real random, every gap stays inside 1.5-6 s', () async {
      final g = h.governor(
        'ui',
        config: const GovernorConfig(burst: 30),
        random: Random(42),
      );
      final starts = <DateTime>[];
      final futures = [
        for (var i = 0; i < 20; i++)
          g.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async => starts.add(h.now),
          ),
      ];
      await h.time.drive(Future.wait(futures));
      final gaps = [
        for (var i = 1; i < starts.length; i++)
          starts[i].difference(starts[i - 1]),
      ];
      expect(gaps, hasLength(19));
      for (final gap in gaps) {
        expect(gap, greaterThanOrEqualTo(const Duration(milliseconds: 1500)));
        expect(gap, lessThanOrEqualTo(const Duration(seconds: 6)));
      }
      expect(gaps.toSet().length, greaterThan(1), reason: 'gaps vary');
    });

    test('the gap also holds between two isolates', () async {
      final a = h.governor('a', config: const GovernorConfig());
      final b = h.governor('b', config: const GovernorConfig());
      final starts = <DateTime>[];
      await h.run(a, () async => starts.add(h.now));
      await h.run(b, () async => starts.add(h.now));
      expect(
        starts[1].difference(starts[0]),
        const Duration(milliseconds: 3750),
      );
    });
  });

  group('AC3 one call in flight per account, across isolates', () {
    test('10 parallel runs execute one at a time, in FIFO order', () async {
      final g = h.governor('ui', config: const GovernorConfig(burst: 20));
      final order = <int>[];
      var inFlight = 0;
      var maxInFlight = 0;
      final futures = [
        for (var i = 0; i < 10; i++)
          g.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async {
              inFlight++;
              maxInFlight = max(maxInFlight, inFlight);
              order.add(i);
              await h.time.delay(const Duration(seconds: 1));
              inFlight--;
              return i;
            },
          ),
      ];
      final results = await h.time.drive(Future.wait(futures));
      expect(maxInFlight, 1);
      expect(order, List<int>.generate(10, (i) => i));
      expect(results, order);
    });

    test('different accounts do not block each other', () async {
      final g = h.governor('ui');
      var inFlight = 0;
      var maxInFlight = 0;
      Future<int> call() async {
        inFlight++;
        maxInFlight = max(maxInFlight, inFlight);
        await h.time.delay(const Duration(seconds: 1));
        inFlight--;
        return 1;
      }

      await h.time.drive(
        Future.wait([
          g.run(accountId: 1, cost: RequestCost.api, call: call),
          g.run(accountId: 2, cost: RequestCost.api, call: call),
        ]),
      );
      expect(maxInFlight, 2);
    });

    test(
      'the lease has a 10 minute expiry and is held during the call',
      () async {
        final g = h.governor('ui');
        GovernorLease? seen;
        await h.run(g, () async {
          seen = await h.repo.read(1);
          return 1;
        });
        expect(seen!.holder, 'ui');
        expect(seen!.expiresAt, h.now.add(const Duration(minutes: 10)));
        expect(seen!.isHeldAt(h.now), isTrue);
      },
    );

    test('the lease is released when the queue runs idle', () async {
      final g = h.governor('ui');
      final futures = [
        for (var i = 0; i < 3; i++)
          g.run(accountId: 1, cost: RequestCost.api, call: () async => i),
      ];
      await h.time.drive(Future.wait(futures));
      final lease = await h.repo.read(1);
      expect(lease!.isHeldAt(h.now), isFalse);
    });

    test('two isolates never run a call at the same time', () async {
      final config = _config(acquireTimeout: _hour, burst: 20);
      final a = h.governor('a', config: config);
      final b = h.governor('b', config: config);
      var inFlight = 0;
      var maxInFlight = 0;
      final holders = <String>[];
      Future<int> Function() call(String who) => () async {
        inFlight++;
        maxInFlight = max(maxInFlight, inFlight);
        holders.add((await h.repo.read(1))!.holder);
        expect(holders.last, who);
        await h.time.delay(const Duration(seconds: 1));
        inFlight--;
        return 1;
      };
      final futures = [
        for (var i = 0; i < 3; i++) ...[
          a.run(accountId: 1, cost: RequestCost.api, call: call('a')),
          b.run(accountId: 1, cost: RequestCost.api, call: call('b')),
        ],
      ];
      await h.time.drive(Future.wait(futures));
      expect(maxInFlight, 1);
      expect(holders, hasLength(6));
    });

    test('the second isolate waits for the first, then runs', () async {
      final a = h.governor('a');
      final b = h.governor('b');
      final hang = Completer<void>();
      final aDone = a.run(
        accountId: 1,
        cost: RequestCost.api,
        call: () => hang.future,
      );
      await h.time.pump();

      DateTime? bStarted;
      final bDone = b.run(
        accountId: 1,
        cost: RequestCost.api,
        call: () async => bStarted = h.now,
      );
      await h.time.elapse(const Duration(seconds: 30));
      expect(bStarted, isNull, reason: 'a still holds the lease');
      expect((await h.repo.read(1))!.holder, 'a');

      hang.complete();
      await h.time.drive(aDone);
      await h.time.drive(bDone);
      expect(bStarted, isNotNull);
    });

    test('GovernorBusy when the lease stays taken for the timeout', () async {
      final config = _config(acquireTimeout: _minute);
      final a = h.governor('a', config: config);
      final b = h.governor('b', config: config);
      final hang = Completer<void>();
      final aDone = a.run(
        accountId: 1,
        cost: RequestCost.api,
        call: () => hang.future,
      );
      await h.time.pump();

      var bCalled = false;
      final error = await h.time.drive(
        _errorOf(
          b.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async => bCalled = true,
          ),
        ),
      );
      expect(error, isA<GovernorBusy>());
      expect((error! as GovernorBusy).accountId, 1);
      expect((error as GovernorBusy).waited, _minute);
      expect(bCalled, isFalse);
      expect((await h.repo.read(1))!.holder, 'a');

      hang.complete();
      await h.time.drive(aDone);
    });

    test('a lease that expired is taken over', () async {
      final config = _config(acquireTimeout: _hour);
      final a = h.governor('a', config: config);
      final b = h.governor('b', config: config);
      final hang = Completer<void>(); // a's call hangs and never renews
      final aDone = a.run(
        accountId: 1,
        cost: RequestCost.api,
        call: () => hang.future,
      );
      await h.time.pump();

      DateTime? bStarted;
      final bDone = b.run(
        accountId: 1,
        cost: RequestCost.api,
        call: () async => bStarted = h.now,
      );
      await h.time.elapse(const Duration(minutes: 9, seconds: 59));
      expect(bStarted, isNull);
      await h.time.elapse(const Duration(seconds: 10));
      expect(bStarted, isNotNull);
      final waited = bStarted!.difference(DateTime.utc(2026));
      expect(waited, greaterThanOrEqualTo(const Duration(minutes: 10)));
      expect(
        waited,
        lessThanOrEqualTo(const Duration(minutes: 10, seconds: 5)),
      );
      await h.time.drive(bDone);

      hang.complete(); // a finishes late and still ends cleanly
      await h.time.drive(aDone);
      expect((await h.repo.read(1))!.isHeldAt(h.now), isFalse);
    });

    test('the lease is renewed while a call waits for tokens', () async {
      // 1 token per 10 minutes: the second call waits 10 minutes.
      final config = _config(callsPerHour: 6, burst: 1);
      final g = h.governor('ui', config: config);
      await h.run(g, () async => 1);

      var done = false;
      final second = h.run(g, () async => 2).then((_) => done = true);
      await h.time.elapse(const Duration(minutes: 6));
      final lease = (await h.repo.read(1))!;
      expect(lease.isHeldAt(h.now), isTrue);
      expect(
        lease.expiresAt.isAfter(h.now.add(const Duration(minutes: 8))),
        isTrue,
      );
      expect(done, isFalse);
      await second;
    });

    test('a call that throws frees the slot and the lease', () async {
      final g = h.governor('ui');
      final failing = _errorOf(
        g.run<int>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => throw StateError('boom'),
        ),
      );
      final next = g.run(
        accountId: 1,
        cost: RequestCost.api,
        call: () async => 7,
      );
      expect(await h.time.drive(failing), isA<StateError>());
      expect(await h.time.drive(next), 7);
      expect((await h.repo.read(1))!.isHeldAt(h.now), isFalse);
      // The failed call used its token.
      expect(await g.remainingTokens(1), 4);
      // Another isolate can take over right away.
      final b = h.governor('b');
      expect(await h.run(b, () async => 8), 8);
    });

    test('the bucket survives a lease release and a new isolate', () async {
      final a = h.governor('a');
      for (var i = 0; i < 3; i++) {
        await h.run(a, () async => i);
      }
      expect((await h.repo.read(1))!.isHeldAt(h.now), isFalse);

      final b = h.governor('b');
      expect(await b.remainingTokens(1), 3);
      await h.run(b, () async => 1);
      expect(await b.remainingTokens(1), 2);
      expect(await a.remainingTokens(1), 2, reason: 'one shared budget');
    });

    test('both isolates draw from the same 6-token burst', () async {
      final a = h.governor('a');
      final b = h.governor('b');
      for (var i = 0; i < 4; i++) {
        await h.run(a, () async => i);
      }
      for (var i = 0; i < 2; i++) {
        await h.run(b, () async => i);
      }
      expect(await a.remainingTokens(1), 0);
      var done = false;
      final next = h.run(a, () async => 1).then((_) => done = true);
      await h.time.elapse(const Duration(seconds: 59));
      expect(done, isFalse);
      await h.time.elapse(const Duration(seconds: 1));
      expect(done, isTrue);
      await next;
    });
  });

  group('AC4 rate limit: pause, multiplier x2 for 2 h, x4 on a repeat', () {
    final start = DateTime.utc(2026);

    Future<void> limit(RequestGovernor g, Duration? retryAfter) => h.run(
      g,
      () async => Err<int>(RateLimited(retryAfter)),
    );

    test(
      'an Err(RateLimited) pauses for retryAfter and doubles intervals',
      () async {
        final g = h.governor('ui');
        expect(await g.effectiveIntervalMultiplier(1), 1);
        expect(await g.isPaused(1), isFalse);

        await limit(g, const Duration(minutes: 5));
        final until = start.add(const Duration(minutes: 5));
        expect(await g.isPaused(1), isTrue);
        expect(await g.pausedUntil(1), until);
        expect(await g.effectiveIntervalMultiplier(1), 2);

        // Calls are refused during the pause and cost nothing.
        final tokens = await g.remainingTokens(1);
        var called = false;
        final error = await h.time.drive(
          _errorOf(
            g.run(
              accountId: 1,
              cost: RequestCost.api,
              call: () async => called = true,
            ),
          ),
        );
        expect(called, isFalse);
        expect(error, isA<GovernorPaused>());
        final paused = error! as GovernorPaused;
        expect(paused.until, until);
        expect(paused.retryAfter, const Duration(minutes: 5));
        expect(paused.toFailure(), const RateLimited(Duration(minutes: 5)));
        expect(await g.remainingTokens(1), tokens);

        // The pause ends exactly at retryAfter.
        h.time.clock.set(until.subtract(const Duration(seconds: 1)));
        expect(await g.isPaused(1), isTrue);
        h.time.clock.set(until);
        expect(await g.isPaused(1), isFalse);
        expect(await h.run(g, () async => 'ok'), 'ok');
      },
    );

    test('no retryAfter pauses for 15 minutes', () async {
      final g = h.governor('ui');
      await limit(g, null);
      expect(await g.pausedUntil(1), start.add(const Duration(minutes: 15)));
    });

    test('a zero retryAfter counts as no hint', () async {
      final g = h.governor('ui');
      await limit(g, Duration.zero);
      expect(await g.pausedUntil(1), start.add(const Duration(minutes: 15)));
    });

    test('a thrown RateLimited is rethrown and pauses', () async {
      final g = h.governor('ui');
      final error = await h.time.drive(
        _errorOf(
          g.run<int>(
            accountId: 1,
            cost: RequestCost.api,
            // A Failure is thrown on purpose: adapters may throw it.
            // ignore: only_throw_errors
            call: () async => throw const RateLimited(Duration(minutes: 2)),
          ),
        ),
      );
      expect(error, const RateLimited(Duration(minutes: 2)));
      expect(await g.pausedUntil(1), start.add(const Duration(minutes: 2)));
      expect(await g.effectiveIntervalMultiplier(1), 2);
    });

    test('a bare returned RateLimited pauses', () async {
      final g = h.governor('ui');
      await h.run<Object>(g, () async => const RateLimited(null));
      expect(await g.isPaused(1), isTrue);
    });

    test('other failures and values do not pause', () async {
      final g = h.governor('ui');
      await h.run<Object>(g, () async => const Err<int>(NetworkFailure()));
      await h.run<Object>(g, () async => 5);
      expect(await g.isPaused(1), isFalse);
      expect(await g.effectiveIntervalMultiplier(1), 1);
    });

    test('reportRateLimited pauses like a returned limit', () async {
      final g = h.governor('ui');
      await g.reportRateLimited(1, const RateLimited(Duration(minutes: 3)));
      expect(await g.pausedUntil(1), start.add(const Duration(minutes: 3)));
      expect(await g.effectiveIntervalMultiplier(1), 2);
      expect((await h.repo.read(1))!.isHeldAt(h.now), isFalse);
    });

    test('the other isolate sees the pause and the multiplier', () async {
      final a = h.governor('a');
      final b = h.governor('b');
      await limit(a, const Duration(minutes: 10));
      expect(await b.isPaused(1), isTrue);
      expect(await b.effectiveIntervalMultiplier(1), 2);
      final error = await h.time.drive(
        _errorOf(
          b.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
        ),
      );
      expect(error, isA<GovernorPaused>());
    });

    test('other accounts are not paused', () async {
      final g = h.governor('ui');
      await limit(g, null);
      expect(await g.isPaused(2), isFalse);
      expect(await g.effectiveIntervalMultiplier(2), 1);
      expect(await h.run(g, () async => 1, accountId: 2), 1);
    });

    test('the x2 decays 2 hours after the pause ends', () async {
      final g = h.governor('ui');
      await limit(g, const Duration(minutes: 5));
      final pauseEnd = start.add(const Duration(minutes: 5));
      h.time.clock.set(pauseEnd.add(const Duration(hours: 2, seconds: -1)));
      expect(await g.effectiveIntervalMultiplier(1), 2);
      h.time.clock.set(pauseEnd.add(const Duration(hours: 2)));
      expect(await g.effectiveIntervalMultiplier(1), 1);
    });

    test('a repeat within 24 h gives x4, which decays after 2 h', () async {
      final g = h.governor('ui');
      await limit(g, const Duration(minutes: 5));
      final firstEnd = start.add(const Duration(minutes: 5));

      // Well after the x2 decayed, but inside the 24 h window.
      h.time.clock.set(firstEnd.add(const Duration(hours: 3)));
      expect(await g.effectiveIntervalMultiplier(1), 1);
      await limit(g, const Duration(minutes: 20));
      expect(await g.effectiveIntervalMultiplier(1), 4);
      final secondEnd = h.now.add(const Duration(minutes: 20));
      expect(await g.pausedUntil(1), secondEnd);

      h.time.clock.set(secondEnd.add(const Duration(hours: 2, seconds: -1)));
      expect(await g.effectiveIntervalMultiplier(1), 4);
      h.time.clock.set(secondEnd.add(const Duration(hours: 2)));
      expect(await g.effectiveIntervalMultiplier(1), 1);
    });

    test('a repeat while still paused is a repeat (x4)', () async {
      final g = h.governor('ui');
      await limit(g, const Duration(minutes: 5));
      await g.reportRateLimited(1, const RateLimited(Duration(minutes: 1)));
      expect(await g.effectiveIntervalMultiplier(1), 4);
      // The longer pause is kept.
      expect(await g.pausedUntil(1), start.add(const Duration(minutes: 5)));
    });

    test(
      'after 24 h the history is gone: the next limit is x2 again',
      () async {
        final g = h.governor('ui');
        await limit(g, const Duration(minutes: 5));
        final firstEnd = start.add(const Duration(minutes: 5));
        h.time.clock.set(firstEnd.add(const Duration(hours: 24, seconds: -1)));
        await limit(g, null);
        expect(
          await g.effectiveIntervalMultiplier(1),
          4,
          reason: 'inside 24 h',
        );

        final fresh = _Harness();
        final f = fresh.governor('ui');
        await fresh.run(
          f,
          () async => const Err<int>(RateLimited(Duration(minutes: 5))),
        );
        fresh.time.clock.set(
          DateTime.utc(2026).add(const Duration(minutes: 5, hours: 24)),
        );
        await fresh.run(
          f,
          () async => const Err<int>(RateLimited(Duration(minutes: 5))),
        );
        expect(await f.effectiveIntervalMultiplier(1), 2, reason: 'after 24 h');
      },
    );
  });

  group('AC5 limits are config values', () {
    test('a custom config changes rate, burst, cost and back-off', () async {
      const config = GovernorConfig(
        callsPerHour: 120,
        burst: 2,
        pageLoadCost: 2,
        jitterMin: Duration.zero,
        jitterMax: Duration.zero,
        defaultRetryAfter: Duration(minutes: 1),
        firstMultiplier: 3,
      );
      final g = h.governor('ui', config: config);
      await h.run(g, () async => 1);
      await h.run(g, () async => 1);
      expect(await g.remainingTokens(1), 0);

      var done = false;
      final third = h.run(g, () async => 1).then((_) => done = true);
      await h.time.elapse(const Duration(seconds: 29));
      expect(done, isFalse, reason: '120/h is one token per 30 s');
      await h.time.elapse(const Duration(seconds: 1));
      expect(done, isTrue);
      await third;

      final pageLoads = _Harness();
      final p = pageLoads.governor('ui', config: config);
      await pageLoads.run(p, () async => 1, cost: RequestCost.pageLoad);
      expect(await p.remainingTokens(1), 0, reason: 'a page load costs 2');

      await g.reportRateLimited(1, const RateLimited(null));
      expect(await g.pausedUntil(1), h.now.add(_minute));
      expect(await g.effectiveIntervalMultiplier(1), 3);
    });

    test('a custom lease ttl and jitter range are used', () async {
      final config = _config(
        leaseTtl: const Duration(minutes: 3),
        jitterMin: const Duration(seconds: 10),
        jitterMax: const Duration(seconds: 20),
      );
      final g = h.governor('ui', config: config, random: _FixedRandom(0));
      final starts = <DateTime>[];
      GovernorLease? lease;
      for (var i = 0; i < 2; i++) {
        await h.run(g, () async {
          starts.add(h.now);
          lease = await h.repo.read(1);
          return 1;
        });
      }
      expect(starts[1].difference(starts[0]), const Duration(seconds: 10));
      expect(lease!.expiresAt, h.now.add(const Duration(minutes: 3)));
    });
  });

  group('logging', () {
    test('logs account, cost, wait and outcome, nothing else', () async {
      final g = h.governor('ui');
      await h.run(g, () async => 1, accountId: 7, cost: RequestCost.pageLoad);
      await h.run(g, () async => const Err<int>(RateLimited(null)));
      expect(h.logs, [
        'governor account=7 cost=pageLoad waited_ms=0 outcome=ok',
        'governor account=1 cost=api waited_ms=0 outcome=rate_limited',
      ]);
    });
  });
}

/// A no-jitter config with some values replaced.
GovernorConfig _config({
  int callsPerHour = 60,
  int burst = 6,
  Duration leaseTtl = const Duration(minutes: 10),
  Duration acquireTimeout = const Duration(minutes: 2),
  Duration jitterMin = Duration.zero,
  Duration jitterMax = Duration.zero,
}) => GovernorConfig(
  callsPerHour: callsPerHour,
  burst: burst,
  leaseTtl: leaseTtl,
  acquireTimeout: acquireTimeout,
  jitterMin: jitterMin,
  jitterMax: jitterMax,
);
