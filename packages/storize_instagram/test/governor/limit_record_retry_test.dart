// ignore_for_file: document_ignores, only_throw_errors
// T-012a (T-012 QA N2): a failed repo write while recording a rate limit is
// retried a bounded number of times on the governor's injected delay.
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

/// Delegates to [FakeGovernorLeaseRepo]; while armed, the next [failures]
/// writeBucket calls throw.
final class _FlakyRepo implements GovernorLeaseRepo {
  _FlakyRepo(this._inner);

  final FakeGovernorLeaseRepo _inner;
  int failures = 0;
  int failedWrites = 0;

  @override
  Future<GovernorLease?> acquire({
    required int accountId,
    required String holder,
    required Duration ttl,
    required GovernorBucket initialBucket,
  }) => _inner.acquire(
    accountId: accountId,
    holder: holder,
    ttl: ttl,
    initialBucket: initialBucket,
  );

  @override
  Future<GovernorLease?> read(int accountId) => _inner.read(accountId);

  @override
  Future<bool> renew({
    required int accountId,
    required String holder,
    required Duration ttl,
  }) => _inner.renew(accountId: accountId, holder: holder, ttl: ttl);

  @override
  Future<void> release({required int accountId, required String holder}) =>
      _inner.release(accountId: accountId, holder: holder);

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) {
    if (failures > 0) {
      failures--;
      failedWrites++;
      throw StateError('db down');
    }
    return _inner.writeBucket(
      accountId: accountId,
      holder: holder,
      bucket: bucket,
    );
  }
}

void main() {
  late FakeTime time;
  late _FlakyRepo repo;
  late List<String> logs;
  late RequestGovernor gov;

  setUp(() {
    time = FakeTime();
    repo = _FlakyRepo(FakeGovernorLeaseRepo(time.clock));
    logs = [];
    gov = RequestGovernor(
      leases: repo,
      clock: time.clock,
      holder: 'A',
      config: _noJitter,
      delay: time.delay,
      random: Random(1),
      log: logs.add,
    );
  });

  int recordFailed() => logs.where((l) => l.contains('record_failed')).length;

  Future<Object?> runThrowingLimit(int failWrites) async {
    Object? error;
    try {
      await time.drive(
        gov.run<int>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async {
            repo.failures = failWrites; // Fails the record, not the gate.
            throw const RateLimited(Duration(minutes: 5));
          },
        ),
      );
    } on Object catch (e) {
      error = e;
    }
    return error;
  }

  test(
    'a transient write failure is retried and the limit is recorded',
    () async {
      final error = await runThrowingLimit(2);
      expect(error, isA<RateLimited>());
      expect(repo.failedWrites, 2);
      expect(await gov.isPaused(1), isTrue);
      expect(recordFailed(), 0);
    },
  );

  test('retries wait 200 ms then 400 ms on the injected delay', () async {
    final start = time.clock.now();
    await runThrowingLimit(2);
    expect(
      time.clock.now().difference(start),
      const Duration(milliseconds: 600),
    );
  });

  test('gives up after 3 attempts: record_failed once, original error '
      'rethrown', () async {
    final error = await runThrowingLimit(99);
    expect(error, isA<RateLimited>());
    expect(repo.failedWrites, 3);
    expect(recordFailed(), 1);
    expect(await gov.isPaused(1), isFalse);
  });

  test('a limit returned as Err is retried too, result unchanged', () async {
    final result = await time.drive(
      gov.run<Result<int>>(
        accountId: 1,
        cost: RequestCost.api,
        call: () async {
          repo.failures = 1;
          return const Err<int>(RateLimited(null));
        },
      ),
    );
    expect(result, isA<Err<int>>());
    expect(repo.failedWrites, 1);
    expect(await gov.isPaused(1), isTrue);
    expect(recordFailed(), 0);
  });

  test('without a limit the record is not retried', () async {
    Object? error;
    try {
      await time.drive(
        gov.run<int>(
          accountId: 1,
          cost: RequestCost.api,
          call: () async {
            repo.failures = 99;
            throw StateError('boom');
          },
        ),
      );
    } on Object catch (e) {
      error = e;
    }
    expect(error, isA<StateError>());
    expect(repo.failedWrites, 1);
    expect(recordFailed(), 1);
  });

  test('the lease is free after a failed record', () async {
    await runThrowingLimit(99);
    repo.failures = 0;
    final other = RequestGovernor(
      leases: repo,
      clock: time.clock,
      holder: 'B',
      config: _noJitter,
      delay: time.delay,
      random: Random(2),
    );
    // B is not blocked by A (A released); no pause was recorded.
    expect(
      await time.drive(
        other.run(accountId: 1, cost: RequestCost.api, call: () async => 7),
      ),
      7,
    );
  });
}
