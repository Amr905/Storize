import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'db_test_helpers.dart';

void main() {
  late StorizeDatabase db;

  setUp(() => db = newDb());
  tearDown(() => db.close());

  group('TargetsDao', () {
    test(
      'watchAll orders by username case-insensitively and re-emits',
      () async {
        final seen = <List<String>>[];
        final sub = db.targetsDao.watchAll().listen(
          (rows) => seen.add([for (final r in rows) r.username]),
        );
        addTearDown(sub.cancel);
        await addTarget(db, remoteUserId: '1', username: 'bob');
        await addTarget(db, remoteUserId: '2', username: 'Alice');
        await pumpEventQueue();
        expect(seen.last, ['Alice', 'bob']);
      },
    );

    test('getByRemoteUserId and watchById', () async {
      final id = await addTarget(db, remoteUserId: 'zz');
      expect(
        (await db.targetsDao.getByRemoteUserId(PlatformId.instagram, 'zz'))!.id,
        id,
      );
      expect(
        await db.targetsDao.getByRemoteUserId(PlatformId.instagram, 'nope'),
        isNull,
      );
      expect((await db.targetsDao.watchById(id).first)!.id, id);
      expect(await db.targetsDao.watchById(999).first, isNull);
    });

    test(
      'updatePartial leaves other columns alone; updateRow replaces',
      () async {
        final id = await addTarget(db);
        await db.targetsDao.updatePartial(
          id,
          TargetsCompanion(lastStoriesCheckAt: Value(minutesAfter(3))),
        );
        var row = (await db.targetsDao.getById(id))!;
        expect(row.lastStoriesCheckAt, minutesAfter(3));
        expect(row.username, 'user_one');
        await db.targetsDao.updateRow(row.copyWith(note: const Value('n')));
        row = (await db.targetsDao.getById(id))!;
        expect(row.note, 'n');
      },
    );

    test(
      'listActive filters by status and scope, least recently checked first',
      () async {
        final never = await db.targetsDao.insert(
          targetCompanion(remoteUserId: 'never'),
        );
        final old = await db.targetsDao.insert(
          targetCompanion(remoteUserId: 'old'),
        );
        final recent = await db.targetsDao.insert(
          targetCompanion(remoteUserId: 'recent'),
        );
        await db.targetsDao.insert(
          targetCompanion(remoteUserId: 'paused', status: TargetStatus.paused),
        );
        final onlyPosts = await db.targetsDao.insert(
          targetCompanion(remoteUserId: 'posts', trackStories: false),
        );
        await db.targetsDao.insert(
          targetCompanion(
            remoteUserId: 'stories',
            trackPosts: false,
            trackReels: false,
          ),
        );
        await db.targetsDao.updatePartial(
          old,
          TargetsCompanion(lastStoriesCheckAt: Value(minutesAfter(1))),
        );
        await db.targetsDao.updatePartial(
          recent,
          TargetsCompanion(lastStoriesCheckAt: Value(minutesAfter(9))),
        );

        final stories = await db.targetsDao.listActive(CheckScope.stories);
        expect(stories.map((t) => t.remoteUserId), [
          'never',
          'stories',
          'old',
          'recent',
        ]);
        final posts = await db.targetsDao.listActive(CheckScope.posts);
        expect(posts.map((t) => t.id).toSet(), {never, old, recent, onlyPosts});
        expect(await db.targetsDao.listActive(CheckScope.all), hasLength(5));
      },
    );
  });

  group('AccountDao', () {
    test('upsert keeps the id for the same remote_user_id', () async {
      final first = await addAccount(db);
      final row = await db.accountDao.upsert(
        LoginAccountsCompanion.insert(
          platform: PlatformId.instagram,
          remoteUserId: 'acct-1',
          username: 'renamed',
          status: AccountStatus.active,
          connectedAt: minutesAfter(5),
        ),
      );
      expect(row.id, first);
      expect(row.username, 'renamed');
      expect(await count(db, 'login_account'), 1);
    });

    test('getActive is the most recently connected row', () async {
      expect(await db.accountDao.getActive(), isNull);
      await addAccount(db, remoteUserId: 'old');
      final newer = await db.accountDao.upsert(
        LoginAccountsCompanion.insert(
          platform: PlatformId.instagram,
          remoteUserId: 'new',
          username: 'n',
          status: AccountStatus.active,
          connectedAt: minutesAfter(5),
        ),
      );
      expect((await db.accountDao.getActive())!.id, newer.id);
      expect((await db.accountDao.watchActive().first)!.id, newer.id);
    });

    test(
      'setStatus writes status and reason; lastSuccessAt only when given',
      () async {
        final id = await addAccount(db);
        await db.accountDao.setStatus(
          id,
          AccountStatus.active,
          lastSuccessAt: minutesAfter(2),
        );
        await db.accountDao.setStatus(
          id,
          AccountStatus.needsRelogin,
          reason: 'login_required',
        );
        final row = (await db.accountDao.getActive())!;
        expect(row.status, AccountStatus.needsRelogin);
        expect(row.statusReason, 'login_required');
        expect(row.lastSuccessAt, minutesAfter(2));
        await db.accountDao.setStatus(id, AccountStatus.active);
        expect((await db.accountDao.getActive())!.statusReason, isNull);
      },
    );
  });

  group('ActivityDao', () {
    Future<int> add(DateTime at, ActivityType type) => db.activityDao.insert(
      ActivityEventsCompanion.insert(
        at: at,
        type: type,
        severity: Severity.info,
      ),
    );

    test('watchRecent: since, types, newest first', () async {
      final old = await add(minutesAfter(-100), ActivityType.checkDone);
      final a = await add(minutesAfter(1), ActivityType.checkDone);
      final b = await add(minutesAfter(2), ActivityType.gap);
      final c = await add(minutesAfter(2), ActivityType.checkDone);
      List<int> idsOf(List<ActivityEventRow> r) => [for (final e in r) e.id];
      expect(
        idsOf(await db.activityDao.watchRecent(since: minutesAfter(0)).first),
        [c, b, a],
      );
      expect(
        idsOf(
          await db.activityDao
              .watchRecent(since: minutesAfter(0), types: {ActivityType.gap})
              .first,
        ),
        [b],
      );
      expect(
        idsOf(
          await db.activityDao.watchRecent(since: minutesAfter(-200)).first,
        ),
        contains(old),
      );
    });

    test(
      'pruneOlderThan deletes strictly older rows and returns the count',
      () async {
        await add(minutesAfter(-10), ActivityType.checkDone);
        await add(minutesAfter(-5), ActivityType.checkDone);
        final keep = await add(minutesAfter(0), ActivityType.checkDone);
        expect(await db.activityDao.pruneOlderThan(minutesAfter(0)), 2);
        expect(await count(db, 'activity_event'), 1);
        expect(await db.activityDao.getById(keep), isNotNull);
        expect(await db.activityDao.pruneOlderThan(minutesAfter(0)), 0);
      },
    );
  });

  group('CheckRunDao', () {
    test('start, finish and lastFinished by scope', () async {
      final unfinished = await db.checkRunDao.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: minutesAfter(9),
      );
      final first = await db.checkRunDao.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: minutesAfter(1),
      );
      final second = await db.checkRunDao.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.manualAll,
        startedAt: minutesAfter(5),
      );
      final posts = await db.checkRunDao.start(
        scope: CheckScope.posts,
        trigger: CheckTrigger.periodic,
        startedAt: minutesAfter(6),
      );
      expect(await db.checkRunDao.lastFinished(CheckScope.stories), isNull);
      for (final id in [first, second, posts]) {
        expect(
          await db.checkRunDao.finish(
            id,
            finishedAt: minutesAfter(20),
            result: CheckResult.ok,
            mode: ExtractionMode.direct,
            targetsChecked: 3,
            newItems: 2,
            errorCode: id == second ? 'e1' : null,
          ),
          1,
        );
      }
      final last = (await db.checkRunDao.lastFinished(CheckScope.stories))!;
      expect(last.id, second);
      expect(last.targetsChecked, 3);
      expect(last.newItems, 2);
      expect(last.errorCode, 'e1');
      expect(last.id, isNot(unfinished));
      expect(
        (await db.checkRunDao.lastFinished(CheckScope.posts))!.id,
        posts,
      );
      expect(
        await db.checkRunDao.finish(
          999,
          finishedAt: t0,
          result: CheckResult.failed,
        ),
        0,
      );
    });
  });

  group('GovernorLeaseDao', () {
    final bucket = GovernorBucket(tokens: 5, lastRefillAt: t0);
    const ttl = Duration(minutes: 2);

    Future<GovernorLeaseRow?> acquire(String holder, DateTime now) =>
        db.governorLeaseDao.acquire(
          accountId: 1,
          holder: holder,
          now: now,
          ttl: ttl,
          initialBucket: bucket,
        );

    test('first acquire stores the initial bucket and expiry', () async {
      final row = (await acquire('ui', t0))!;
      expect(row.holder, 'ui');
      expect(row.expiresAt, t0.add(ttl));
      expect(row.tokens, 5);
      expect(row.lastRefillAt, t0);
      expect(row.backoffUntil, isNull);
      expect(row.backoffMultiplier, 1);
    });

    test('another holder is refused until the lease expires', () async {
      await acquire('ui', t0);
      expect(await acquire('bg', minutesAfter(1)), isNull);
      final taken = await acquire('bg', minutesAfter(3));
      expect(taken!.holder, 'bg');
    });

    test('the same holder can re-acquire, and the bucket survives', () async {
      await acquire('ui', t0);
      await db.governorLeaseDao.writeBucket(
        accountId: 1,
        holder: 'ui',
        now: minutesAfter(1),
        bucket: GovernorBucket(
          tokens: 1.5,
          lastRefillAt: minutesAfter(1),
          backoffUntil: minutesAfter(30),
          backoffMultiplier: 4,
        ),
      );
      await db.governorLeaseDao.release(
        accountId: 1,
        holder: 'ui',
        now: minutesAfter(1),
      );
      final row = (await acquire('bg', minutesAfter(1)))!;
      expect(row.holder, 'bg');
      expect(row.tokens, 1.5);
      expect(row.backoffUntil, minutesAfter(30));
      expect(row.backoffMultiplier, 4);
    });

    test('renew extends only for the holder of an unexpired lease', () async {
      await acquire('ui', t0);
      expect(
        await db.governorLeaseDao.renew(
          accountId: 1,
          holder: 'bg',
          now: minutesAfter(1),
          ttl: ttl,
        ),
        isFalse,
      );
      expect(
        await db.governorLeaseDao.renew(
          accountId: 1,
          holder: 'ui',
          now: minutesAfter(1),
          ttl: ttl,
        ),
        isTrue,
      );
      expect((await db.governorLeaseDao.read(1))!.expiresAt, minutesAfter(3));
      expect(
        await db.governorLeaseDao.renew(
          accountId: 1,
          holder: 'ui',
          now: minutesAfter(10),
          ttl: ttl,
        ),
        isFalse,
      );
      expect(
        await db.governorLeaseDao.renew(
          accountId: 2,
          holder: 'ui',
          now: t0,
          ttl: ttl,
        ),
        isFalse,
      );
    });

    test(
      'release by a non-holder does nothing; by the holder ends the lease',
      () async {
        await acquire('ui', t0);
        await db.governorLeaseDao.release(
          accountId: 1,
          holder: 'bg',
          now: minutesAfter(1),
        );
        expect((await db.governorLeaseDao.read(1))!.expiresAt, t0.add(ttl));
        await db.governorLeaseDao.release(
          accountId: 1,
          holder: 'ui',
          now: minutesAfter(1),
        );
        expect((await db.governorLeaseDao.read(1))!.expiresAt, minutesAfter(1));
        expect(await acquire('bg', minutesAfter(1)), isNotNull);
      },
    );

    test('writeBucket is refused without a live lease', () async {
      expect(
        await db.governorLeaseDao.writeBucket(
          accountId: 1,
          holder: 'ui',
          now: t0,
          bucket: bucket,
        ),
        isFalse,
      );
      await acquire('ui', t0);
      expect(
        await db.governorLeaseDao.writeBucket(
          accountId: 1,
          holder: 'ui',
          now: minutesAfter(5),
          bucket: bucket,
        ),
        isFalse,
      );
      expect(await db.governorLeaseDao.read(99), isNull);
    });
  });
}
