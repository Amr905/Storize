// ignore_for_file: document_ignores, only_throw_errors
// QA T-012a: adversarial checks of the limit-record retry and skew takeover.
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

/// The write lands in the inner repo, then throws (reply lost).
final class _LandThenThrow implements GovernorLeaseRepo {
  _LandThenThrow(this.inner);

  final FakeGovernorLeaseRepo inner;
  int throwAfterWrite = 0;
  int writes = 0;
  final List<GovernorBucket> landed = [];

  @override
  Future<GovernorLease?> acquire({
    required int accountId,
    required String holder,
    required Duration ttl,
    required GovernorBucket initialBucket,
  }) => inner.acquire(
    accountId: accountId,
    holder: holder,
    ttl: ttl,
    initialBucket: initialBucket,
  );

  @override
  Future<GovernorLease?> read(int accountId) => inner.read(accountId);

  @override
  Future<bool> renew({
    required int accountId,
    required String holder,
    required Duration ttl,
  }) => inner.renew(accountId: accountId, holder: holder, ttl: ttl);

  @override
  Future<void> release({required int accountId, required String holder}) =>
      inner.release(accountId: accountId, holder: holder);

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) async {
    final ok = await inner.writeBucket(
      accountId: accountId,
      holder: holder,
      bucket: bucket,
    );
    writes++;
    landed.add(bucket);
    if (throwAfterWrite > 0) {
      throwAfterWrite--;
      throw StateError('reply lost');
    }
    return ok;
  }
}

void main() {
  late FakeTime time;
  late _LandThenThrow repo;
  late RequestGovernor gov;

  RequestGovernor make(String holder, [GovernorLeaseRepo? r]) =>
      RequestGovernor(
        leases: r ?? repo,
        clock: time.clock,
        holder: holder,
        config: _noJitter,
        delay: time.delay,
        random: Random(1),
      );

  setUp(() {
    time = FakeTime();
    repo = _LandThenThrow(FakeGovernorLeaseRepo(time.clock));
    gov = make('A');
  });

  Future<void> limit(Duration? retryAfter, {required int landThrow}) async {
    try {
      await time.drive(
        gov.run<int>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async {
            repo.throwAfterWrite = landThrow;
            throw RateLimited(retryAfter);
          },
        ),
      );
    } on RateLimited {
      // expected
    }
  }

  test(
    'write landed then threw (5 min pause): retry does not escalate to x4',
    () async {
      await limit(const Duration(minutes: 5), landThrow: 1);
      final stored = (await repo.read(1))!.bucket;
      expect(stored.backoffMultiplier, 2);
      expect(repo.writes, 3); // 1 gate write + 2 record attempts
    },
  );

  test(
    'write landed then threw twice: still x2 (retries are idempotent)',
    () async {
      await limit(const Duration(minutes: 5), landThrow: 2);
      expect((await repo.read(1))!.bucket.backoffMultiplier, 2);
    },
  );

  test('default retry-after (15 min), landed then threw: x2', () async {
    await limit(null, landThrow: 2);
    expect((await repo.read(1))!.bucket.backoffMultiplier, 2);
  });

  test('1 s pause, landed then threw twice: still x2', () async {
    await limit(const Duration(seconds: 1), landThrow: 2);
    expect((await repo.read(1))!.bucket.backoffMultiplier, 2);
  });

  // The pause (100 ms) ends before the 200 ms retry delay: the retry sees
  // an expired pause with multiplier 2 and counts the SAME limit again.
  test(
    'KNOWN EDGE: sub-second pause + landed-then-threw escalates to x4',
    () async {
      await limit(const Duration(milliseconds: 100), landThrow: 1);
      final m = (await repo.read(1))!.bucket.backoffMultiplier;
      // Documented as observed; a correct implementation would keep 2.
      expect(m, 4, reason: 'observed spurious escalation; see review F-1');
    },
  );

  test('the lease stays held by this holder during the retry waits', () async {
    final seen = <String?>[];
    final g = RequestGovernor(
      leases: repo,
      clock: time.clock,
      holder: 'A',
      config: _noJitter,
      delay: (d) async {
        seen.add((await repo.read(1))?.holder);
        final lease = await repo.read(1);
        seen.add(
          lease!.isHeldAt(time.clock.now()) ? 'held' : 'free',
        );
        await time.delay(d);
      },
      random: Random(1),
    );
    try {
      await time.drive(
        g.run<int>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async {
            repo.throwAfterWrite = 2;
            throw const RateLimited(Duration(minutes: 5));
          },
        ),
      );
    } on RateLimited {
      // expected
    }
    expect(seen, ['A', 'held', 'A', 'held']);
  });

  test('another governor is refused while the recorded pause lasts '
      '(no bypass after a retried record)', () async {
    final other = make('B');
    await limit(const Duration(minutes: 5), landThrow: 1);
    await expectLater(
      time.drive(
        other.run<int>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => 1,
        ),
      ),
      throwsA(isA<GovernorPaused>()),
    );
  });

  test('no real sleeping: three failed attempts finish instantly', () async {
    final sw = Stopwatch()..start();
    await limit(const Duration(minutes: 5), landThrow: 99);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(500));
    expect(time.pendingTimers, 0);
  });

  test('delay that throws during retry stops retrying, logs, rethrows '
      'original', () async {
    final logs = <String>[];
    final g = RequestGovernor(
      leases: repo,
      clock: time.clock,
      holder: 'A',
      config: _noJitter,
      delay: (d) => throw StateError('delay broke'),
      random: Random(1),
      log: logs.add,
    );
    Object? err;
    try {
      await g.run<int>(
        accountId: 1,
        cost: RequestCost.api,
        call: () async {
          repo.throwAfterWrite = 5;
          throw const RateLimited(Duration(minutes: 5));
        },
      );
    } on Object catch (e) {
      err = e;
    }
    expect(err, isA<RateLimited>());
    expect(logs.where((l) => l.contains('record_failed')), hasLength(1));
  });

  test('skewed takeover with a far-future backoff: governor clamps the wait '
      'to maxPause', () async {
    final a = make('A');
    // A leaves a 30-day pause behind (as after a clock that ran ahead).
    await time.drive(
      a.run<int>(accountId: 1, cost: RequestCost.api, call: () async => 1),
    );
    final lease = (await repo.read(1))!;
    await repo.inner.acquire(
      accountId: 1,
      holder: 'A',
      ttl: const Duration(minutes: 10),
      initialBucket: lease.bucket,
    );
    await repo.writeBucket(
      accountId: 1,
      holder: 'A',
      bucket: GovernorBucket(
        tokens: 5,
        lastRefillAt: time.clock.now(),
        backoffUntil: time.clock.now().add(const Duration(days: 30)),
        backoffMultiplier: 4,
      ),
    );
    // Clock goes back 1 day while A still holds: B takes over.
    time.clock.advance(const Duration(days: -1));
    final b = make('B');
    // B takes over the skewed lease, inherits the 30-day pause and is
    // refused with a retryAfter clamped to maxPause (24 h), not 30 days.
    await expectLater(
      time.drive(
        b.run<int>(accountId: 1, cost: RequestCost.api, call: () async => 9),
      ),
      throwsA(
        isA<GovernorPaused>().having(
          (e) => e.retryAfter <= const Duration(hours: 24),
          'retryAfter clamped',
          isTrue,
        ),
      ),
    );
    expect((await repo.read(1))!.holder, anyOf('A', 'B'));
  });
}
