import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'db_test_helpers.dart';

void main() {
  late StorizeDatabase db;
  late int targetA;
  late int targetB;

  setUp(() async {
    db = newDb();
    targetA = await addTarget(db, remoteUserId: 'a', username: 'a_user');
    targetB = await addTarget(db, remoteUserId: 'b', username: 'b_user');
  });
  tearDown(() => db.close());

  group('insertIfNew (BR-3, transaction)', () {
    test('stores content and all slides, returning isNew', () async {
      final result = await db.contentDao.insertIfNew(
        contentCompanion(targetId: targetA, kind: ContentKind.post),
        [
          mediaCompanion(),
          mediaCompanion(slideIndex: 1, type: MediaType.video),
        ],
      );
      expect(result.isNew, isTrue);
      final stored = (await db.contentDao.getById(result.contentId))!;
      expect(stored.media.map((m) => m.slideIndex), [0, 1]);
      expect(stored.media.map((m) => m.contentId).toSet(), {result.contentId});
    });

    test('a known (target, kind, remote id) is not inserted again', () async {
      final first = await db.contentDao.insertIfNew(
        contentCompanion(targetId: targetA),
        [mediaCompanion()],
      );
      final second = await db.contentDao.insertIfNew(
        contentCompanion(targetId: targetA),
        [mediaCompanion()],
      );
      expect(second.isNew, isFalse);
      expect(second.contentId, first.contentId);
      expect(await count(db, 'content'), 1);
      expect(await count(db, 'media_file'), 1);
    });

    test('a failing media insert rolls back the content row', () async {
      await expectLater(
        db.contentDao.insertIfNew(
          contentCompanion(targetId: targetA, kind: ContentKind.post),
          // Same slide index twice: the second insert violates UNIQUE.
          [mediaCompanion(), mediaCompanion()],
        ),
        failsWith('UNIQUE constraint failed: media_file.content_id'),
      );
      expect(await count(db, 'content'), 0);
      expect(await count(db, 'media_file'), 0);
    });

    test('a failure leaves earlier committed rows alone', () async {
      await addContent(db, targetId: targetA, remoteId: 'ok');
      await expectLater(
        db.contentDao.insertIfNew(
          contentCompanion(targetId: targetA, remoteId: 'bad'),
          [mediaCompanion(), mediaCompanion()],
        ),
        throwsA(anything),
      );
      expect(await count(db, 'content'), 1);
      expect(await count(db, 'media_file'), 1);
    });
  });

  test(
    'existingRemoteIds returns only stored ids of that target/kind',
    () async {
      await addContent(db, targetId: targetA, remoteId: '1');
      await addContent(db, targetId: targetA, remoteId: '2');
      await addContent(
        db,
        targetId: targetA,
        remoteId: '3',
        kind: ContentKind.post,
      );
      await addContent(db, targetId: targetB, remoteId: '4');
      expect(
        await db.contentDao.existingRemoteIds(targetA, ContentKind.story, [
          '1',
          '3',
          '4',
          '9',
        ]),
        {'1'},
      );
      expect(
        await db.contentDao.existingRemoteIds(targetA, ContentKind.story, []),
        isEmpty,
      );
    },
  );

  group('library query', () {
    late int story1;
    late int story2;
    late int post1;
    late int post2;

    setUp(() async {
      story1 = await addContent(
        db,
        targetId: targetA,
        remoteId: 's1',
        postedAt: minutesAfter(10),
      );
      story2 = await addContent(
        db,
        targetId: targetB,
        remoteId: 's2',
        postedAt: minutesAfter(30),
        media: [mediaCompanion(type: MediaType.video)],
      );
      post1 = await addContent(
        db,
        targetId: targetA,
        remoteId: 'p1',
        kind: ContentKind.post,
        postedAt: minutesAfter(20),
        media: [
          mediaCompanion(),
          mediaCompanion(slideIndex: 1, type: MediaType.video),
        ],
      );
      post2 = await addContent(
        db,
        targetId: targetB,
        remoteId: 'p2',
        kind: ContentKind.post,
        postedAt: minutesAfter(40),
      );
    });

    Future<List<int>> ids(ContentFilter f) async => [
      for (final r in await db.contentDao.getLibrary(f)) r.content.id,
    ];

    test('newest first, each content once with ordered slides', () async {
      final rows = await db.contentDao.getLibrary(ContentFilter());
      expect(rows.map((r) => r.content.id), [post2, story2, post1, story1]);
      expect(rows[2].media.map((m) => m.slideIndex), [0, 1]);
    });

    test('kind', () async {
      expect(await ids(ContentFilter(kind: ContentKind.story)), [
        story2,
        story1,
      ]);
    });

    test('target set', () async {
      expect(await ids(ContentFilter(targetIds: {targetA})), [post1, story1]);
      expect(
        await ids(ContentFilter(targetIds: {targetA, targetB})),
        hasLength(4),
      );
    });

    test('date range is [from, to)', () async {
      expect(
        await ids(
          ContentFilter(from: minutesAfter(20), to: minutesAfter(40)),
        ),
        [story2, post1],
      );
    });

    test('media type matches any slide, and keeps every slide', () async {
      final rows = await db.contentDao.getLibrary(
        ContentFilter(mediaType: MediaType.video),
      );
      expect(rows.map((r) => r.content.id), [story2, post1]);
      expect(rows.last.media, hasLength(2));
    });

    test('statuses', () async {
      await db.contentDao.updateContentPartial(
        story1,
        const ContentsCompanion(status: Value(ContentStatus.done)),
      );
      expect(
        await ids(ContentFilter(statuses: const {ContentStatus.done})),
        [story1],
      );
    });

    test('combined filters agree with ContentFilter.matches', () async {
      final filter = ContentFilter(
        kind: ContentKind.post,
        targetIds: {targetA, targetB},
        from: minutesAfter(15),
        mediaType: MediaType.video,
      );
      expect(await ids(filter), [post1]);
    });

    test('watchLibrary emits again after content or media changes', () async {
      final emissions = <List<int>>[];
      final sub = db.contentDao
          .watchLibrary(ContentFilter(kind: ContentKind.story))
          .listen(
            (rows) => emissions.add([for (final r in rows) r.content.id]),
          );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(emissions.last, [story2, story1]);

      final story3 = await addContent(
        db,
        targetId: targetA,
        remoteId: 's3',
        postedAt: minutesAfter(50),
      );
      await pumpEventQueue();
      expect(emissions.last, [story3, story2, story1]);

      final before = emissions.length;
      final media = (await db.contentDao.getById(story3))!.media.single;
      await db.contentDao.updateMediaFilePartial(
        media.id,
        const MediaFilesCompanion(status: Value(MediaFileStatus.done)),
      );
      await pumpEventQueue();
      expect(emissions.length, greaterThan(before));
    });
  });

  group('pending media', () {
    test('stories first, then oldest detected, content id, slide', () async {
      final post = await addContent(
        db,
        targetId: targetA,
        remoteId: 'p',
        kind: ContentKind.post,
        detectedAt: minutesAfter(1),
        media: [mediaCompanion(), mediaCompanion(slideIndex: 1)],
      );
      final lateStory = await addContent(
        db,
        targetId: targetA,
        remoteId: 'late',
        detectedAt: minutesAfter(9),
      );
      final earlyStory = await addContent(
        db,
        targetId: targetB,
        remoteId: 'early',
        detectedAt: minutesAfter(2),
      );
      await addContent(
        db,
        targetId: targetB,
        remoteId: 'done',
        media: [mediaCompanion(status: MediaFileStatus.done)],
      );

      final pending = await db.contentDao.pendingMedia();
      expect(
        [for (final p in pending) (p.content.id, p.file.slideIndex)],
        [(earlyStory, 0), (lateStory, 0), (post, 0), (post, 1)],
      );
      expect(await db.contentDao.pendingMedia(limit: 2), hasLength(2));
    });

    test(
      'resetInterruptedDownloads moves DOWNLOADING back to PENDING',
      () async {
        await addContent(
          db,
          targetId: targetA,
          remoteId: 'x',
          media: [mediaCompanion(status: MediaFileStatus.downloading)],
        );
        await addContent(
          db,
          targetId: targetA,
          remoteId: 'y',
          media: [mediaCompanion(status: MediaFileStatus.failed)],
        );
        expect(await db.contentDao.resetInterruptedDownloads(), 1);
        expect(await db.contentDao.pendingMedia(), hasLength(1));
        expect(await db.contentDao.resetInterruptedDownloads(), 0);
      },
    );
  });

  group('updates and deletes', () {
    test('updateContent / updateMediaFile write full rows', () async {
      final id = await addContent(db, targetId: targetA);
      final row = (await db.contentDao.getById(id))!;
      await db.contentDao.updateContent(
        row.content.copyWith(caption: const Value('hi'), viewed: true),
      );
      final file = row.media.single.copyWith(
        status: MediaFileStatus.done,
        sizeBytes: const Value(42),
        contentUri: const Value('content://media/1'),
      );
      await db.contentDao.updateMediaFile(file);
      final after = (await db.contentDao.getById(id))!;
      expect(after.content.caption, 'hi');
      expect(after.content.viewed, isTrue);
      expect(after.media.single.sizeBytes, 42);
      expect(after.media.single.status, MediaFileStatus.done);
    });

    test('markViewed only touches the given rows', () async {
      final a = await addContent(db, targetId: targetA, remoteId: '1');
      final b = await addContent(db, targetId: targetA, remoteId: '2');
      await db.contentDao.markViewed([a]);
      expect((await db.contentDao.getById(a))!.content.viewed, isTrue);
      expect((await db.contentDao.getById(b))!.content.viewed, isFalse);
      await db.contentDao.markViewed([]);
    });

    test(
      'deleteByIds removes content and media; empty list is a no-op',
      () async {
        final a = await addContent(db, targetId: targetA, remoteId: '1');
        await addContent(db, targetId: targetA, remoteId: '2');
        expect(await db.contentDao.deleteByIds([]), 0);
        expect(await db.contentDao.deleteByIds([a, 999]), 1);
        expect(await count(db, 'content'), 1);
        expect(await count(db, 'media_file'), 1);
      },
    );

    test('getByIds keeps the requested order and skips unknown ids', () async {
      final a = await addContent(db, targetId: targetA, remoteId: '1');
      final b = await addContent(db, targetId: targetA, remoteId: '2');
      final rows = await db.contentDao.getByIds([b, 999, a]);
      expect(rows.map((r) => r.content.id), [b, a]);
      expect(await db.contentDao.getById(999), isNull);
    });

    test('listByTarget is newest first and scoped to the target', () async {
      final old = await addContent(db, targetId: targetA, remoteId: '1');
      final recent = await addContent(
        db,
        targetId: targetA,
        remoteId: '2',
        postedAt: minutesAfter(5),
      );
      await addContent(db, targetId: targetB, remoteId: '3');
      final rows = await db.contentDao.listByTarget(targetA);
      expect(rows.map((r) => r.content.id), [recent, old]);
    });
  });

  group('retention and storage', () {
    test('olderThan is strictly before the cutoff, oldest first', () async {
      final oldest = await addContent(
        db,
        targetId: targetA,
        remoteId: '1',
        postedAt: minutesAfter(1),
      );
      final old = await addContent(
        db,
        targetId: targetA,
        remoteId: '2',
        postedAt: minutesAfter(5),
      );
      await addContent(
        db,
        targetId: targetA,
        remoteId: '3',
        postedAt: minutesAfter(10),
      );
      final rows = await db.contentDao.olderThan(minutesAfter(10));
      expect(rows.map((r) => r.content.id), [oldest, old]);
      expect(rows.first.media, hasLength(1));
    });

    test(
      'storageBytesByTarget sums DONE media with a size per target',
      () async {
        await addContent(
          db,
          targetId: targetA,
          remoteId: '1',
          kind: ContentKind.post,
          media: [
            mediaCompanion(status: MediaFileStatus.done, sizeBytes: 100),
            mediaCompanion(
              slideIndex: 1,
              status: MediaFileStatus.done,
              sizeBytes: 50,
            ),
          ],
        );
        await addContent(
          db,
          targetId: targetA,
          remoteId: '2',
          media: [
            mediaCompanion(sizeBytes: 999),
          ],
        );
        await addContent(
          db,
          targetId: targetB,
          remoteId: '3',
          media: [mediaCompanion(status: MediaFileStatus.done)],
        );
        expect(await db.contentDao.storageBytesByTarget(), {targetA: 150});
      },
    );
  });
}
