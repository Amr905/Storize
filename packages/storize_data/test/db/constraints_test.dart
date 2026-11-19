// Behavioural proof of the §3 constraints and FK actions (AC2).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_model/storize_model.dart';

import 'db_test_helpers.dart';

void main() {
  late StorizeDatabase db;

  setUp(() => db = newDb());
  tearDown(() => db.close());

  group('UNIQUE', () {
    test('a duplicate target is rejected (EC-16)', () async {
      await addTarget(db, remoteUserId: 'same', username: 'first');
      await expectLater(
        addTarget(db, remoteUserId: 'same', username: 'renamed'),
        failsWith('UNIQUE constraint failed: target.platform'),
      );
      expect(await count(db, 'target'), 1);
    });

    test('a duplicate content is rejected by the table (BR-3)', () async {
      final target = await addTarget(db);
      await db.into(db.contents).insert(contentCompanion(targetId: target));
      await expectLater(
        db.into(db.contents).insert(contentCompanion(targetId: target)),
        failsWith('UNIQUE constraint failed: content.target_id'),
      );
    });

    test('the same remote id is allowed for another kind or target', () async {
      final a = await addTarget(db, remoteUserId: 'a');
      final b = await addTarget(db, remoteUserId: 'b');
      await addContent(db, targetId: a, remoteId: 'x');
      await addContent(db, targetId: a, remoteId: 'x', kind: ContentKind.post);
      await addContent(db, targetId: b, remoteId: 'x');
      expect(await count(db, 'content'), 3);
    });

    test('a duplicate slide index is rejected (media_file)', () async {
      final target = await addTarget(db);
      final content = await addContent(db, targetId: target);
      await expectLater(
        db
            .into(db.mediaFiles)
            .insert(mediaCompanion().copyWith(contentId: Value(content))),
        failsWith('UNIQUE constraint failed: media_file.content_id'),
      );
    });

    test('a duplicate login account remote_user_id is rejected', () async {
      await addAccount(db);
      await expectLater(
        db
            .into(db.loginAccounts)
            .insert(
              LoginAccountsCompanion.insert(
                platform: PlatformId.instagram,
                remoteUserId: 'acct-1',
                username: 'x',
                status: AccountStatus.active,
                connectedAt: t0,
              ),
            ),
        failsWith('UNIQUE constraint failed: login_account.remote_user_id'),
      );
    });
  });

  group('CHECK', () {
    test('all three track flags off is rejected', () async {
      await expectLater(
        db
            .into(db.targets)
            .insert(
              targetCompanion(
                trackStories: false,
                trackPosts: false,
                trackReels: false,
              ),
            ),
        failsWith('CHECK constraint failed'),
      );
    });

    test('every non-empty flag combination is accepted', () async {
      var n = 0;
      for (final s in [false, true]) {
        for (final p in [false, true]) {
          for (final r in [false, true]) {
            if (!s && !p && !r) continue;
            await db
                .into(db.targets)
                .insert(
                  targetCompanion(
                    remoteUserId: 'u${n++}',
                    trackStories: s,
                    trackPosts: p,
                    trackReels: r,
                  ),
                );
          }
        }
      }
      expect(await count(db, 'target'), 7);
    });

    test('updating the last flag off is rejected too', () async {
      final id = await db
          .into(db.targets)
          .insert(targetCompanion(trackPosts: false, trackReels: false));
      await expectLater(
        db.targetsDao.updatePartial(
          id,
          const TargetsCompanion(trackStories: Value(false)),
        ),
        failsWith('CHECK constraint failed'),
      );
    });

    test('posts_watermark_at is NOT NULL', () async {
      await expectLater(
        db.customInsert(
          'INSERT INTO target (platform, remote_user_id, username, category, '
          "status, added_at) VALUES ('INSTAGRAM', 'x', 'x', 'PUBLIC', "
          "'ACTIVE', 0)",
        ),
        failsWith('NOT NULL constraint failed: target.posts_watermark_at'),
      );
    });

    test("check_run.scope 'ALL' is rejected by the CHECK constraint", () async {
      await expectLater(
        db.customInsert(
          'INSERT INTO check_run (scope, "trigger", started_at) '
          "VALUES ('ALL', 'PERIODIC', 0)",
        ),
        failsWith('CHECK constraint failed'),
      );
    });

    test('the scope converter refuses CheckScope.all before SQL runs', () {
      expect(
        () => db.checkRunDao.start(
          scope: CheckScope.all,
          trigger: CheckTrigger.periodic,
          startedAt: t0,
        ),
        throwsArgumentError,
      );
    });

    test('STORIES and POSTS are accepted', () async {
      for (final scope in [CheckScope.stories, CheckScope.posts]) {
        await db.checkRunDao.start(
          scope: scope,
          trigger: CheckTrigger.periodic,
          startedAt: t0,
        );
      }
      expect(await count(db, 'check_run'), 2);
    });
  });

  group('FK actions', () {
    test('deleting a target cascades to content and media_file', () async {
      final target = await addTarget(db);
      final other = await addTarget(db, remoteUserId: 'keep');
      final content = await addContent(
        db,
        targetId: target,
        kind: ContentKind.post,
        media: [mediaCompanion(), mediaCompanion(slideIndex: 1)],
      );
      await addContent(db, targetId: other);
      expect(await count(db, 'media_file'), 3);

      await db.targetsDao.deleteById(target);

      expect(await db.contentDao.getById(content), isNull);
      expect(await count(db, 'content'), 1);
      expect(await count(db, 'media_file'), 1);
    });

    test('deleting content cascades to its media_file rows', () async {
      final target = await addTarget(db);
      final content = await addContent(db, targetId: target);
      await db.contentDao.deleteByIds([content]);
      expect(await count(db, 'media_file'), 0);
    });

    test('deleting a login account nulls target.login_account_id', () async {
      final account = await addAccount(db);
      final target = await addTarget(db, loginAccountId: account);
      expect((await db.targetsDao.getById(target))!.loginAccountId, account);

      await db.accountDao.deleteById(account);

      final row = await db.targetsDao.getById(target);
      expect(row, isNotNull);
      expect(row!.loginAccountId, isNull);
    });

    test('deleting a target nulls activity_event.target_id', () async {
      final target = await addTarget(db);
      final event = await db.activityDao.insert(
        ActivityEventsCompanion.insert(
          at: t0,
          type: ActivityType.targetStatus,
          severity: Severity.info,
          targetId: Value(target),
        ),
      );
      await db.targetsDao.deleteById(target);
      final row = await db.activityDao.getById(event);
      expect(row, isNotNull);
      expect(row!.targetId, isNull);
    });

    test('deleting a check_run nulls activity_event.check_run_id', () async {
      final run = await db.checkRunDao.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.manualAll,
        startedAt: t0,
      );
      final event = await db.activityDao.insert(
        ActivityEventsCompanion.insert(
          at: t0,
          type: ActivityType.checkDone,
          severity: Severity.info,
          checkRunId: Value(run),
        ),
      );
      await db.customStatement('DELETE FROM check_run WHERE id = $run');
      expect((await db.activityDao.getById(event))!.checkRunId, isNull);
    });

    test('a dangling foreign key is rejected (FKs are enforced)', () async {
      await expectLater(
        db.into(db.contents).insert(contentCompanion(targetId: 999)),
        failsWith('FOREIGN KEY constraint failed'),
      );
    });
  });
}
