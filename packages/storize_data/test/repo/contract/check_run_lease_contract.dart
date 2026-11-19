import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../support/builders.dart';
import '../support/harness.dart';

/// Behaviour every [CheckRunRepo] must show.
void runCheckRunRepoContract(RepoHarness Function() create) {
  late RepoHarness h;
  late CheckRunRepo repo;
  setUp(() {
    h = create();
    repo = h.checkRuns;
  });
  tearDown(() => h.dispose());

  Future<CheckRun> start(CheckScope scope, DateTime at) => repo.start(
    scope: scope,
    trigger: CheckTrigger.periodic,
    startedAt: at,
  );

  test('start returns an unfinished run with an id', () async {
    final a = await start(CheckScope.stories, at(1));
    final b = await start(CheckScope.posts, at(2));
    expect(a.id, isNot(CheckRun.unsavedId));
    expect(b.id, isNot(a.id));
    expect(a.isFinished, isFalse);
    expect(a.scope, CheckScope.stories);
    expect(a.trigger, CheckTrigger.periodic);
    expect(a.startedAt, at(1));
    expect(a.result, isNull);
    expect(a.targetsChecked, 0);
  });

  test('start rejects scope ALL', () async {
    await expectLater(start(CheckScope.all, at(1)), throwsArgumentError);
  });

  test('finish records the outcome and returns the updated run', () async {
    final run = await start(CheckScope.posts, at(1));
    final done = await repo.finish(
      run.id,
      finishedAt: at(3),
      result: CheckResult.partial,
      mode: ExtractionMode.page,
      targetsChecked: 4,
      newItems: 2,
      errorCode: 'E_X',
    );
    expect(done.isFinished, isTrue);
    expect(done.finishedAt, at(3));
    expect(done.result, CheckResult.partial);
    expect(done.mode, ExtractionMode.page);
    expect(done.targetsChecked, 4);
    expect(done.newItems, 2);
    expect(done.errorCode, 'E_X');
    expect(done.scope, CheckScope.posts);
    expect(done.startedAt, at(1));
    expect(await repo.lastFinished(CheckScope.posts), done);
  });

  test('finish with defaults leaves mode and errorCode null', () async {
    final run = await start(CheckScope.stories, at(1));
    final done = await repo.finish(
      run.id,
      finishedAt: at(2),
      result: CheckResult.ok,
    );
    expect(done.mode, isNull);
    expect(done.errorCode, isNull);
    expect(done.targetsChecked, 0);
    expect(done.newItems, 0);
  });

  test('finish of an unknown id is a StateError', () async {
    await expectLater(
      repo.finish(99, finishedAt: at(1), result: CheckResult.ok),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'lastFinished: null with none finished; unfinished runs are ignored',
    () async {
      expect(await repo.lastFinished(CheckScope.stories), isNull);
      await start(CheckScope.stories, at(5));
      expect(await repo.lastFinished(CheckScope.stories), isNull);
    },
  );

  test('lastFinished is per scope and picks the newest startedAt', () async {
    final old = await start(CheckScope.stories, at(1));
    final newer = await start(CheckScope.stories, at(5));
    final posts = await start(CheckScope.posts, at(9));
    final unfinishedNewest = await start(CheckScope.stories, at(20));
    // Finish the older run last: it must still not win.
    for (final r in [newer, posts, old]) {
      await repo.finish(r.id, finishedAt: at(30), result: CheckResult.ok);
    }
    expect((await repo.lastFinished(CheckScope.stories))!.id, newer.id);
    expect((await repo.lastFinished(CheckScope.posts))!.id, posts.id);
    expect(unfinishedNewest.isFinished, isFalse);
  });

  test('lastFinished rejects scope ALL', () async {
    await expectLater(repo.lastFinished(CheckScope.all), throwsArgumentError);
  });
}

GovernorBucket aBucket({
  double tokens = 5,
  DateTime? lastRefillAt,
  DateTime? backoffUntil,
  double backoffMultiplier = 1,
}) => GovernorBucket(
  tokens: tokens,
  lastRefillAt: lastRefillAt ?? t0,
  backoffUntil: backoffUntil,
  backoffMultiplier: backoffMultiplier,
);

/// Behaviour every [GovernorLeaseRepo] must show. The clock is the harness
/// `FakeClock`; expiry is `expiresAt` exactly (held while `expiresAt > now`).
void runGovernorLeaseRepoContract(RepoHarness Function() create) {
  late RepoHarness h;
  late GovernorLeaseRepo repo;
  const ttl = Duration(seconds: 30);
  setUp(() {
    h = create();
    repo = h.leases;
  });
  tearDown(() => h.dispose());

  Future<GovernorLease?> take(
    String holder, {
    int account = 1,
    GovernorBucket? bucket,
  }) => repo.acquire(
    accountId: account,
    holder: holder,
    ttl: ttl,
    initialBucket: bucket ?? aBucket(),
  );

  test('read of an unknown account is null', () async {
    expect(await repo.read(1), isNull);
  });

  test(
    'first acquire stores holder, now + ttl and the initial bucket',
    () async {
      final bucket = aBucket(
        tokens: 2.5,
        backoffUntil: at(3),
        backoffMultiplier: 1.5,
      );
      final lease = await take('A', bucket: bucket);
      expect(lease, isNotNull);
      expect(lease!.holder, 'A');
      expect(lease.loginAccountId, 1);
      expect(lease.expiresAt, h.clock.now().add(ttl));
      expect(lease.bucket, bucket);
      expect(await repo.read(1), lease);
    },
  );

  test('another holder is refused while the lease is held, accepted exactly at '
      'expiry', () async {
    await take('A');
    h.clock.advance(ttl - const Duration(milliseconds: 1));
    expect(await take('B'), isNull);
    h.clock.advance(const Duration(milliseconds: 1));
    final b = await take('B');
    expect(b, isNotNull);
    expect(b!.holder, 'B');
    expect(b.expiresAt, h.clock.now().add(ttl));
  });

  test(
    'the same holder can acquire again and keeps the stored bucket',
    () async {
      await take('A');
      final bucket = aBucket(
        tokens: 1.25,
        backoffUntil: at(9),
        backoffMultiplier: 2,
      );
      expect(
        await repo.writeBucket(accountId: 1, holder: 'A', bucket: bucket),
        isTrue,
      );
      h.clock.advance(const Duration(seconds: 10));
      final again = await take('A', bucket: aBucket(tokens: 99));
      expect(again!.bucket, bucket);
      expect(again.expiresAt, h.clock.now().add(ttl));
    },
  );

  test('a new holder after expiry inherits the stored bucket', () async {
    await take('A');
    final bucket = aBucket(tokens: 0.5);
    await repo.writeBucket(accountId: 1, holder: 'A', bucket: bucket);
    h.clock.advance(ttl);
    final b = await take('B', bucket: aBucket(tokens: 99));
    expect(b!.bucket, bucket);
  });

  test(
    'renew: only the holder, only while held, extends to now + ttl',
    () async {
      await take('A');
      h.clock.advance(const Duration(seconds: 10));
      expect(await repo.renew(accountId: 1, holder: 'B', ttl: ttl), isFalse);
      expect(await repo.renew(accountId: 1, holder: 'A', ttl: ttl), isTrue);
      expect((await repo.read(1))!.expiresAt, h.clock.now().add(ttl));
      expect(await repo.renew(accountId: 2, holder: 'A', ttl: ttl), isFalse);
    },
  );

  test('renew fails exactly at expiresAt and leaves the row alone', () async {
    final lease = (await take('A'))!;
    h.clock.advance(ttl - const Duration(milliseconds: 1));
    expect(await repo.renew(accountId: 1, holder: 'A', ttl: ttl), isTrue);
    h.clock.advance(ttl);
    expect(await repo.renew(accountId: 1, holder: 'A', ttl: ttl), isFalse);
    // The failed renew did not extend the lease.
    expect(
      (await repo.read(1))!.expiresAt,
      lease.expiresAt.add(ttl - const Duration(milliseconds: 1)),
    );
  });

  test('release ends the lease at once, keeps the bucket; non-holders are '
      'ignored', () async {
    await take('A');
    final bucket = aBucket(tokens: 3);
    await repo.writeBucket(accountId: 1, holder: 'A', bucket: bucket);

    await repo.release(accountId: 1, holder: 'B');
    expect((await repo.read(1))!.expiresAt, h.clock.now().add(ttl));
    expect(await take('B'), isNull);

    await repo.release(accountId: 1, holder: 'A');
    final released = (await repo.read(1))!;
    expect(released.expiresAt, h.clock.now());
    expect(released.isHeldAt(h.clock.now()), isFalse);
    expect(released.bucket, bucket);
    expect((await take('B'))!.bucket, bucket);
    await repo.release(accountId: 77, holder: 'A');
  });

  test('read returns an expired row', () async {
    final lease = (await take('A'))!;
    h.clock.advance(const Duration(hours: 1));
    expect(await repo.read(1), lease);
  });

  test('writeBucket needs a held lease and round-trips every field', () async {
    await take('A');
    final bucket = aBucket(
      tokens: 0.1,
      lastRefillAt: at(4),
      backoffUntil: at(8),
      backoffMultiplier: 4.5,
    );
    expect(
      await repo.writeBucket(accountId: 1, holder: 'B', bucket: bucket),
      isFalse,
    );
    expect(
      await repo.writeBucket(accountId: 1, holder: 'A', bucket: bucket),
      isTrue,
    );
    expect((await repo.read(1))!.bucket, bucket);

    final cleared = aBucket(tokens: 7);
    await repo.writeBucket(accountId: 1, holder: 'A', bucket: cleared);
    expect((await repo.read(1))!.bucket.backoffUntil, isNull);

    h.clock.advance(ttl);
    expect(
      await repo.writeBucket(accountId: 1, holder: 'A', bucket: bucket),
      isFalse,
    );
    expect((await repo.read(1))!.bucket, cleared);
    expect(
      await repo.writeBucket(accountId: 5, holder: 'A', bucket: bucket),
      isFalse,
    );
  });

  test('accounts have independent leases', () async {
    expect(await take('A'), isNotNull);
    expect(await take('B', account: 2), isNotNull);
    expect(await take('B'), isNull);
  });
}
