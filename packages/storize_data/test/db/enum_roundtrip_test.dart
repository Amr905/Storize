// Every stored enum round-trips through the database via its dbValue.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_model/storize_model.dart';

import 'db_test_helpers.dart';

void main() {
  late StorizeDatabase db;

  setUp(() => db = newDb());
  tearDown(() => db.close());

  Future<String> rawText(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<String>('v');

  test('PlatformId and AccountStatus (login_account)', () async {
    for (final status in AccountStatus.values) {
      final id = await addAccount(
        db,
        remoteUserId: 'a-${status.name}',
        status: status,
      );
      final row = (await db.accountDao.getActive())!;
      expect(row.id, id);
      expect(row.status, status);
      expect(row.platform, PlatformId.instagram);
      expect(
        await rawText('SELECT status AS v FROM login_account WHERE id = $id'),
        status.dbValue,
      );
      // Newest connected row wins; make the next one newer.
      await db.accountDao.deleteById(id);
    }
  });

  test('PlatformId, TargetCategory, TargetStatus (target)', () async {
    var n = 0;
    for (final category in TargetCategory.values) {
      for (final status in TargetStatus.values) {
        final id = await db
            .into(db.targets)
            .insert(
              targetCompanion(
                remoteUserId: 'u${n++}',
                status: status,
              ).copyWith(category: Value(category)),
            );
        final row = (await db.targetsDao.getById(id))!;
        expect(row.category, category);
        expect(row.status, status);
        expect(row.platform, PlatformId.instagram);
        expect(
          await rawText('SELECT category AS v FROM target WHERE id = $id'),
          category.dbValue,
        );
        expect(
          await rawText('SELECT status AS v FROM target WHERE id = $id'),
          status.dbValue,
        );
        expect(
          await rawText('SELECT platform AS v FROM target WHERE id = $id'),
          'INSTAGRAM',
        );
      }
    }
  });

  test('ContentKind, PostType, ContentStatus (content)', () async {
    final target = await addTarget(db);
    var n = 0;
    for (final kind in ContentKind.values) {
      for (final status in ContentStatus.values) {
        for (final postType in [null, ...PostType.values]) {
          final id = await db
              .into(db.contents)
              .insert(
                contentCompanion(
                  targetId: target,
                  remoteId: 'r${n++}',
                  kind: kind,
                  status: status,
                ).copyWith(postType: Value(postType)),
              );
          final row = (await db.contentDao.getById(id))!.content;
          expect(row.kind, kind);
          expect(row.status, status);
          expect(row.postType, postType);
          final raw = await db
              .customSelect(
                'SELECT kind, status, post_type FROM content WHERE id = $id',
              )
              .getSingle();
          expect(raw.read<String>('kind'), kind.dbValue);
          expect(raw.read<String>('status'), status.dbValue);
          expect(raw.read<String?>('post_type'), postType?.dbValue);
        }
      }
    }
  });

  test('MediaType and MediaFileStatus (media_file)', () async {
    final target = await addTarget(db);
    var n = 0;
    for (final type in MediaType.values) {
      for (final status in MediaFileStatus.values) {
        final content = await addContent(
          db,
          targetId: target,
          remoteId: 'r${n++}',
          media: [mediaCompanion(type: type, status: status)],
        );
        final row = (await db.contentDao.getById(content))!.media.single;
        expect(row.mediaType, type);
        expect(row.status, status);
        final raw = await db
            .customSelect(
              'SELECT media_type, status FROM media_file '
              'WHERE content_id = $content',
            )
            .getSingle();
        expect(raw.read<String>('media_type'), type.dbValue);
        expect(raw.read<String>('status'), status.dbValue);
      }
    }
  });

  test('CheckScope, CheckTrigger, CheckResult, ExtractionMode', () async {
    for (final scope in [CheckScope.stories, CheckScope.posts]) {
      for (final trigger in CheckTrigger.values) {
        final id = await db.checkRunDao.start(
          scope: scope,
          trigger: trigger,
          startedAt: t0,
        );
        for (final result in CheckResult.values) {
          for (final mode in [null, ...ExtractionMode.values]) {
            await db.checkRunDao.finish(
              id,
              finishedAt: minutesAfter(1),
              result: result,
              mode: mode,
            );
            final row = (await db.checkRunDao.getById(id))!;
            expect(row.scope, scope);
            expect(row.trigger, trigger);
            expect(row.result, result);
            expect(row.mode, mode);
            final raw = await db
                .customSelect(
                  'SELECT scope, "trigger", result, mode FROM check_run '
                  'WHERE id = $id',
                )
                .getSingle();
            expect(raw.read<String>('scope'), scope.dbValue);
            expect(raw.read<String>('trigger'), trigger.dbValue);
            expect(raw.read<String>('result'), result.dbValue);
            expect(raw.read<String?>('mode'), mode?.dbValue);
          }
        }
      }
    }
  });

  test('ActivityType and Severity (activity_event)', () async {
    for (final type in ActivityType.values) {
      for (final severity in Severity.values) {
        final id = await db.activityDao.insert(
          ActivityEventsCompanion.insert(
            at: t0,
            type: type,
            severity: severity,
          ),
        );
        final row = (await db.activityDao.getById(id))!;
        expect(row.type, type);
        expect(row.severity, severity);
        final raw = await db
            .customSelect(
              'SELECT type, severity FROM activity_event '
              'WHERE id = $id',
            )
            .getSingle();
        expect(raw.read<String>('type'), type.dbValue);
        expect(raw.read<String>('severity'), severity.dbValue);
      }
    }
  });

  test('timestamps are stored as epoch milliseconds (UTC)', () async {
    final at = DateTime.utc(2026, 11, 19, 10, 15, 3, 456);
    final id = await db.activityDao.insert(
      ActivityEventsCompanion.insert(
        at: at,
        type: ActivityType.checkDone,
        severity: Severity.info,
      ),
    );
    final raw = await db
        .customSelect('SELECT at FROM activity_event WHERE id = $id')
        .getSingle();
    expect(raw.read<int>('at'), at.millisecondsSinceEpoch);
    final row = (await db.activityDao.getById(id))!;
    expect(row.at, at);
    expect(row.at.isUtc, isTrue);
  });

  test('an unknown stored value fails loudly on read', () async {
    final id = await addTarget(db);
    await db.customStatement(
      "UPDATE target SET status = 'BOGUS' WHERE id = $id",
    );
    await expectLater(db.targetsDao.getById(id), throwsArgumentError);
  });
}
