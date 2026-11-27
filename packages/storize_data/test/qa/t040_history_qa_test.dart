import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_data/repo/repo.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../db/db_test_helpers.dart';
import '../db/generated/schema.dart';

RemoteContent _post(String id, DateTime at) => RemoteContent(
  remoteId: id,
  kind: ContentKind.post,
  shortcode: 'sc$id',
  postType: PostType.photo,
  postedAt: at,
  slides: const [
    RemoteMedia(
      index: 0,
      type: MediaType.photo,
      url: 'https://example.invalid/p',
      width: 1,
      height: 1,
    ),
  ],
);

Future<void> _insert(
  ContentRepo repo,
  Target t,
  RemoteContent c,
  DateTime at,
) => repo.insertIfNew(
  Content(
    id: Content.unsavedId,
    targetId: t.id,
    kind: c.kind,
    remoteId: c.remoteId,
    postedAt: c.postedAt,
    slideCount: 1,
    extras: c.extras,
    detectedAt: at,
  ),
  const [
    MediaFile(
      id: MediaFile.unsavedId,
      contentId: MediaFile.unsavedContentId,
      slideIndex: 0,
      mediaType: MediaType.photo,
      sourceUrl: 'https://example.invalid/p',
    ),
  ],
);

void main() {
  group('migration v1 to v2 (QA)', () {
    late SchemaVerifier verifier;
    setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

    test('keeps every target and content row; defaults apply', () async {
      final schema = await verifier.schemaAt(1);
      final raw = schema.rawDatabase;
      for (var i = 0; i < 3; i++) {
        raw
          ..execute(
            'INSERT INTO target (platform, remote_user_id, username, category, '
            'status, posts_watermark_at, added_at) '
            "VALUES ('INSTAGRAM', 'u$i', 'user$i', 'PUBLIC', 'ACTIVE', 1, 2)",
          )
          ..execute(
            'INSERT INTO content (target_id, kind, remote_id, posted_at, '
            'detected_at, status) '
            "VALUES (${i + 1}, 'STORY', 'r$i', 5, 6, 'PENDING')",
          );
      }
      final db = StorizeDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 2);

      final targets = await DriftTargetRepo(db).listActive(CheckScope.all);
      expect(targets, hasLength(3));
      for (final t in targets) {
        expect(t.historyRange, HistoryRange.none);
        expect(t.historyProgress, isNull);
        expect(t.highlightsEnabled, isFalse);
      }
      final rows = await db.select(db.contents).get();
      expect(rows, hasLength(3));
      // The new kind can be stored after the upgrade.
      final id = await addTarget(db, remoteUserId: 'zz', username: 'zz');
      await db.contentDao.insertIfNew(
        contentCompanion(
          targetId: id,
          kind: ContentKind.highlight,
          remoteId: 'h',
        ),
        const [],
      );
    });

    test('a fresh install is schema v3 with the defaults', () async {
      final db = newDb();
      addTearDown(db.close);
      expect(db.schemaVersion, 3);
      final id = await addTarget(db);
      final t = (await DriftTargetRepo(db).getById(id))!;
      expect(t.historyRange, HistoryRange.none);
      expect(t.highlightsEnabled, isFalse);
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 3);
    });
  });

  group('BackfillHistory on the real database (QA)', () {
    late StorizeDatabase db;
    late DriftTargetRepo targets;
    late DriftContentRepo content;
    late BackfillHistory backfill;
    late FakeContentPlatform platform;
    late int targetId;
    final now = DateTime.utc(2026, 11, 24, 12);

    setUp(() async {
      db = newDb();
      targets = DriftTargetRepo(db);
      content = DriftContentRepo(db);
      platform = FakeContentPlatform();
      final accounts = FakeAccountRepo();
      await accounts.upsert(
        LoginAccount(
          id: LoginAccount.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: 'me',
          username: 'me',
          status: AccountStatus.active,
          connectedAt: now,
        ),
      );
      backfill = BackfillHistory(
        platform: platform,
        targets: targets,
        content: content,
        accounts: accounts,
        settings: FakeSettingsRepo(),
        clock: FakeClock(now),
      );
      targetId = await addTarget(db);
      await backfill.start(targetId, HistoryRange.all);
    });
    tearDown(() => db.close());

    Future<int> count() async => (await content.listByTarget(targetId)).length;

    test('two steps racing on one target store each post once', () async {
      final page = PostPage(
        items: [_post('1', now), _post('2', now)],
        nextCursor: 'c1',
      );
      platform.fetchPostPageResults
        ..addOk(page)
        ..addOk(page);
      final rs = await Future.wait([
        backfill.step(targetId),
        backfill.step(targetId),
      ]);
      expect(rs.every((r) => r.outcome == BackfillOutcome.progressed), isTrue);
      expect(await count(), 2);
      final t = (await targets.getById(targetId))!;
      expect(t.historyProgress?.cursor, 'c1');
      expect(t.historyProgress?.state, HistoryState.running);
    });

    test(
      'a regular check that queued the post first causes no duplicate',
      () async {
        final t = (await targets.getById(targetId))!;
        await _insert(content, t, _post('1', now), now);
        platform.fetchPostPageResults.addOk(
          PostPage(items: [_post('1', now), _post('2', now)]),
        );
        final r = await backfill.step(targetId);
        expect(r.newContentIds, hasLength(1));
        expect(await count(), 2);
        expect(r.outcome, BackfillOutcome.done);
      },
    );

    test('a crash after queuing but before saving progress resumes the same '
        'page without loss or duplicates', () async {
      final page = PostPage(
        items: [_post('1', now), _post('2', now)],
        nextCursor: 'c1',
      );
      platform.fetchPostPageResults.addOk(page);
      await backfill.step(targetId);
      // Simulate the lost progress write: roll the progress back.
      final t = (await targets.getById(targetId))!;
      await targets.update(
        t.copyWith(
          historyProgress: HistoryProgress(
            state: HistoryState.running,
            fetched: 0,
            updatedAt: now,
          ),
        ),
      );
      platform.fetchPostPageResults
        ..addOk(page)
        ..addOk(PostPage(items: [_post('3', now)]));
      final again = await backfill.step(targetId);
      expect(again.newContentIds, isEmpty);
      expect(
        platform.callsTo('fetchPostPage').map((c) => c.args[1]),
        [null, null],
      );
      await backfill.step(targetId);
      expect(await count(), 3);
      expect(
        (await targets.getById(targetId))!.historyProgress?.state,
        HistoryState.done,
      );
    });
  });

  group('highlight items: deletion and folder safety (QA)', () {
    test('RemoveTarget with media deletes highlight rows and files', () async {
      final db = newDb();
      addTearDown(db.close);
      final targets = DriftTargetRepo(db);
      final content = DriftContentRepo(db);
      final cache = FakeMediaCache();
      final gallery = FakeGalleryStore(cache: cache);
      final id = await addTarget(db, remoteUserId: 'u-9', username: 'bob');
      final t = (await targets.getById(id))!;
      await _insert(
        content,
        t,
        RemoteContent(
          remoteId: 'hi1',
          kind: ContentKind.highlight,
          postedAt: DateTime.utc(2026),
          slides: const [
            RemoteMedia(
              index: 0,
              type: MediaType.photo,
              url: 'https://example.invalid/h',
              width: 1,
              height: 1,
            ),
          ],
          extras: const {
            HighlightExtras.id: 'h',
            HighlightExtras.title: 'Trip',
          },
        ),
        DateTime.utc(2026),
      );
      final remove = RemoveTarget(
        targets: targets,
        content: content,
        deleteContent: DeleteContent(
          content: content,
          gallery: gallery,
          cache: cache,
        ),
      );
      final r = await remove(id, deleteMedia: true);
      expect(r.targetRemoved, isTrue);
      expect(await targets.getById(id), isNull);
      expect(await db.select(db.contents).get(), isEmpty);
    });

    test('titles with path characters stay one safe segment', () {
      final titles = [
        '../',
        '..',
        '../../etc',
        r'a/b\c',
        '',
        '   ',
        '.',
        '~root',
        '\u{1F3D6}\u{FE0F} Trip',
        'x' * 400,
        'a\u0000b',
      ];
      for (final title in titles) {
        final seg = relativeDirFor(title);
        expect(seg, isNotEmpty, reason: 'title "$title"');
        expect(seg, isNot(contains('/')), reason: title);
        expect(seg, isNot(contains(r'\')), reason: title);
        expect(seg, isNot(contains('..')), reason: title);
        expect(seg.startsWith('.'), isFalse, reason: title);
        expect(seg.startsWith('~'), isFalse, reason: title);
        expect(seg.length, lessThan(256), reason: title);
      }
      expect(relativeDirFor(''), 'unknown');
    });
  });
}
