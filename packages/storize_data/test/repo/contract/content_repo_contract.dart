import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../support/builders.dart';
import '../support/harness.dart';

/// Behaviour every [ContentRepo] must show. Runs against the fake and drift.
///
/// Every content row belongs to a real target: drift enforces the foreign key,
/// the fake does not (see the documented differences in the test file).
void runContentRepoContract(RepoHarness Function() create) {
  late RepoHarness h;
  late ContentRepo repo;
  late int t1;
  late int t2;
  setUp(() async {
    h = create();
    repo = h.content;
    t1 = (await h.targets.insert(aTarget())).id;
    t2 = (await h.targets.insert(aTarget(remoteUserId: 'u-2', username: 'b')))
        .id;
  });
  tearDown(() => h.dispose());

  Future<int> add(Content c, [List<MediaFile>? media]) async =>
      (await repo.insertIfNew(c, media ?? [aMedia()])).contentId;

  group('insertIfNew', () {
    test('stores content and media; ids are assigned and linked', () async {
      final result = await repo.insertIfNew(aFullContent(t1), [
        aMedia(status: MediaFileStatus.done, sizeBytes: 5),
        aFullMedia(),
      ]);
      expect(result.isNew, isTrue);
      final read = (await repo.getById(result.contentId))!;
      expect(read.content.id, result.contentId);
      expect(read.content.copyWith(id: 0), aFullContent(t1));
      expect(read.media.map((m) => m.slideIndex), [0, 3]);
      expect(read.media.every((m) => m.contentId == result.contentId), isTrue);
      expect(read.media.map((m) => m.id).toSet().length, 2);
      expect(read.media.every((m) => m.id != MediaFile.unsavedId), isTrue);
      expect(
        read.media.last.copyWith(id: 0, contentId: 0),
        aFullMedia(),
        reason: 'every media field round-trips',
      );
    });

    test('ignores ids on the entities passed in', () async {
      final result = await repo.insertIfNew(
        aContent(t1).copyWith(id: 500),
        [aMedia().copyWith(id: 600, contentId: 700)],
      );
      expect(result.contentId, isNot(500));
      final read = (await repo.getById(result.contentId))!;
      expect(read.media.single.id, isNot(600));
      expect(read.media.single.contentId, result.contentId);
    });

    test('UNIQUE (target, kind, remoteId): second insert is "not new" and '
        'changes nothing', () async {
      final first = await repo.insertIfNew(aContent(t1), [aMedia()]);
      final again = await repo.insertIfNew(
        aContent(t1).copyWith(caption: 'changed'),
        [aMedia(), aMedia(slideIndex: 1)],
      );
      expect(first.isNew, isTrue);
      expect(
        again,
        ContentInsertResult(contentId: first.contentId, isNew: false),
      );
      final read = (await repo.getById(first.contentId))!;
      expect(read.content.caption, isNull);
      expect(read.media.length, 1);
    });

    test('same remoteId under another kind or target is new', () async {
      final story = await repo.insertIfNew(aContent(t1), [aMedia()]);
      final post = await repo.insertIfNew(
        aContent(t1, kind: ContentKind.post),
        [aMedia()],
      );
      final other = await repo.insertIfNew(aContent(t2), [aMedia()]);
      expect([story.isNew, post.isNew, other.isNew], [true, true, true]);
      expect({story.contentId, post.contentId, other.contentId}.length, 3);
    });

    test('is atomic: duplicate slide indexes are an ArgumentError and nothing '
        'is stored', () async {
      await expectLater(
        repo.insertIfNew(aContent(t1), [aMedia(), aMedia()]),
        throwsArgumentError,
      );
      expect(
        await repo.existingRemoteIds(t1, ContentKind.story, ['r-1']),
        isEmpty,
      );
      expect(await repo.pendingMedia(), isEmpty);
      expect(await repo.listByTarget(t1), isEmpty);
      // The same content can still be inserted afterwards.
      expect((await repo.insertIfNew(aContent(t1), [aMedia()])).isNew, isTrue);
    });

    test(
      'is atomic under concurrency: exactly one of two racing inserts wins',
      () async {
        final results = await Future.wait([
          repo.insertIfNew(aContent(t1), [aMedia()]),
          repo.insertIfNew(aContent(t1), [aMedia()]),
        ]);
        expect(results.where((r) => r.isNew).length, 1);
        expect(results[0].contentId, results[1].contentId);
        expect((await repo.listByTarget(t1)).single.media.length, 1);
      },
    );

    test('content without media is allowed', () async {
      final result = await repo.insertIfNew(aContent(t1), const []);
      expect((await repo.getById(result.contentId))!.media, isEmpty);
    });
  });

  group('reads', () {
    test('getById of an unknown id is null', () async {
      expect(await repo.getById(999), isNull);
    });

    test(
      'getByIds follows the order asked for and skips unknown ids',
      () async {
        final a = await add(aContent(t1, remoteId: 'a'));
        final b = await add(aContent(t1, remoteId: 'b'));
        final c = await add(aContent(t1, remoteId: 'c'));
        final read = await repo.getByIds([c, 999, a]);
        expect(read.map((r) => r.content.id), [c, a]);
        expect(await repo.getByIds(const []), isEmpty);
        expect((await repo.getByIds([b])).single.content.id, b);
      },
    );

    test(
      'listByTarget is newest first, then higher id first, and scoped',
      () async {
        final old = await add(aContent(t1, remoteId: 'old', postedAt: at(1)));
        final newA = await add(aContent(t1, remoteId: 'newA', postedAt: at(5)));
        final newB = await add(aContent(t1, remoteId: 'newB', postedAt: at(5)));
        await add(aContent(t2, remoteId: 'x', postedAt: at(9)));
        final list = await repo.listByTarget(t1);
        expect(list.map((r) => r.content.id), [newB, newA, old]);
      },
    );

    test('media come back ordered by slide index', () async {
      final id = await add(
        aContent(t1, kind: ContentKind.post),
        [aMedia(slideIndex: 2), aMedia(), aMedia(slideIndex: 1)],
      );
      expect(
        (await repo.getById(id))!.media.map((m) => m.slideIndex),
        [0, 1, 2],
      );
    });

    test('existingRemoteIds is scoped to target and kind and returns only '
        'the asked-for ids', () async {
      await add(aContent(t1, remoteId: 'a'));
      await add(aContent(t1, remoteId: 'b', kind: ContentKind.post));
      await add(aContent(t2, remoteId: 'c'));
      expect(
        await repo.existingRemoteIds(t1, ContentKind.story, [
          'a',
          'b',
          'c',
          'd',
        ]),
        {'a'},
      );
      expect(
        await repo.existingRemoteIds(t1, ContentKind.story, const []),
        isEmpty,
      );
    });

    test('olderThan is exclusive of the cutoff and oldest first', () async {
      final a = await add(aContent(t1, remoteId: 'a', postedAt: at(1)));
      final b = await add(aContent(t1, remoteId: 'b', postedAt: at(2)));
      await add(aContent(t1, remoteId: 'at', postedAt: at(3)));
      await add(aContent(t1, remoteId: 'later', postedAt: at(4)));
      final list = await repo.olderThan(at(3));
      expect(list.map((r) => r.content.id), [a, b]);
      expect(await repo.olderThan(at(1)), isEmpty);
    });
  });

  group('pendingMedia', () {
    test('orders stories first, then oldest detectedAt, content id, slide '
        'index; only PENDING files', () async {
      final postA = await add(
        aContent(
          t1,
          remoteId: 'postA',
          kind: ContentKind.post,
          detectedAt: at(1),
        ),
        // Inserted out of order on purpose.
        [
          aMedia(slideIndex: 1),
          aMedia(),
          aMedia(slideIndex: 2, status: MediaFileStatus.done),
        ],
      );
      final storyB = await add(
        aContent(t1, remoteId: 'storyB', detectedAt: at(5)),
      );
      final storyC = await add(
        aContent(t1, remoteId: 'storyC', detectedAt: at(2)),
      );
      final storyD = await add(
        aContent(t2, remoteId: 'storyD', detectedAt: at(2)),
      );
      final postE = await add(
        aContent(
          t2,
          remoteId: 'postE',
          kind: ContentKind.post,
          detectedAt: at(0),
        ),
      );

      final order = [
        for (final p in await repo.pendingMedia())
          (p.content.id, p.file.slideIndex),
      ];
      expect(order, [
        (storyC, 0),
        (storyD, 0),
        (storyB, 0),
        (postE, 0),
        (postA, 0),
        (postA, 1),
      ]);
    });

    test('pairs each file with its content and honours limit', () async {
      final a = await add(aContent(t1, remoteId: 'a', detectedAt: at(1)));
      await add(aContent(t1, remoteId: 'b', detectedAt: at(2)));
      final limited = await repo.pendingMedia(limit: 1);
      expect(limited.length, 1);
      expect(limited.single.content.id, a);
      expect(limited.single.file.contentId, a);
      expect(limited.single.content.remoteId, 'a');
      expect(await repo.pendingMedia(limit: 0), isEmpty);
      expect((await repo.pendingMedia(limit: 50)).length, 2);
    });
  });

  group('updates', () {
    test('resetInterruptedDownloads moves DOWNLOADING back to PENDING and '
        'counts them', () async {
      final id = await add(
        aContent(t1, kind: ContentKind.post),
        [
          aMedia(status: MediaFileStatus.downloading),
          aMedia(slideIndex: 1, status: MediaFileStatus.downloading),
          aMedia(slideIndex: 2, status: MediaFileStatus.done),
          aMedia(slideIndex: 3, status: MediaFileStatus.failed),
        ],
      );
      expect(await repo.resetInterruptedDownloads(), 2);
      final statuses = (await repo.getById(id))!.media.map((m) => m.status);
      expect(statuses, [
        MediaFileStatus.pending,
        MediaFileStatus.pending,
        MediaFileStatus.done,
        MediaFileStatus.failed,
      ]);
      expect(await repo.resetInterruptedDownloads(), 0);
    });

    test(
      'updateMediaFile replaces the row, including clearing fields',
      () async {
        final id = await add(aContent(t1), [aFullMedia()]);
        final stored = (await repo.getById(id))!.media.single;
        final changed = stored.copyWith(
          status: MediaFileStatus.failed,
          attempts: 5,
          contentUri: null,
          sizeBytes: null,
        );
        await repo.updateMediaFile(changed);
        expect((await repo.getById(id))!.media.single, changed);
      },
    );

    test('updateMediaFile of an unknown id is a StateError', () async {
      await expectLater(
        repo.updateMediaFile(aMedia().copyWith(id: 4321)),
        throwsA(isA<StateError>()),
      );
    });

    test('updateContent replaces the row, including extras', () async {
      final id = await add(aFullContent(t1));
      final stored = (await repo.getById(id))!.content;
      final changed = stored.copyWith(
        status: ContentStatus.done,
        caption: null,
        extras: {'only': 'this'},
        viewed: false,
      );
      await repo.updateContent(changed);
      expect((await repo.getById(id))!.content, changed);
    });

    test("updateContent onto another row's (target, kind, remoteId) is a "
        'DuplicateEntityException and changes nothing', () async {
      final a = await add(aContent(t1, remoteId: 'a'));
      await add(aContent(t1, remoteId: 'b'));
      final clash = Content(
        id: a,
        targetId: t1,
        kind: ContentKind.story,
        remoteId: 'b',
        postedAt: t0,
        slideCount: 1,
        detectedAt: t0,
      );
      await expectLater(
        repo.updateContent(clash),
        throwsA(isA<DuplicateEntityException>()),
      );
      expect((await repo.getById(a))!.content.remoteId, 'a');
    });

    test('updateContent of an unknown id is a StateError', () async {
      await expectLater(
        repo.updateContent(aContent(t1).copyWith(id: 4321)),
        throwsA(isA<StateError>()),
      );
    });

    test('markViewed flips only the given rows, ignores unknown ids', () async {
      final a = await add(aContent(t1, remoteId: 'a'));
      final b = await add(aContent(t1, remoteId: 'b'));
      await repo.markViewed([a, 999]);
      await repo.markViewed(const []);
      await repo.markViewed([a]);
      expect((await repo.getById(a))!.content.viewed, isTrue);
      expect((await repo.getById(b))!.content.viewed, isFalse);
    });

    test(
      'deleteByIds removes content and its media; unknown ids are ignored',
      () async {
        final a = await add(aContent(t1, remoteId: 'a'));
        final b = await add(aContent(t1, remoteId: 'b'));
        await repo.deleteByIds([a, 999]);
        await repo.deleteByIds(const []);
        expect(await repo.getById(a), isNull);
        expect(await repo.getById(b), isNotNull);
        expect((await repo.pendingMedia()).map((p) => p.content.id), [b]);
      },
    );

    test(
      'deleteMediaFile removes one slide; the last one removes the item',
      () async {
        final id = await add(aContent(t1, remoteId: 'a'), [
          aMedia(),
          aMedia(slideIndex: 1),
        ]);
        final other = await add(aContent(t1, remoteId: 'b'));
        final slides = (await repo.getById(id))!.media;

        await repo.deleteMediaFile(slides.first.id);
        await repo.deleteMediaFile(999);
        expect((await repo.getById(id))!.media.map((m) => m.id), [
          slides.last.id,
        ]);

        await repo.deleteMediaFile(slides.last.id);
        expect(await repo.getById(id), isNull);
        expect(await repo.getById(other), isNotNull);
      },
    );

    test('deleting a target cascades to its content and media only', () async {
      await add(aContent(t1, remoteId: 'a'), [
        aMedia(status: MediaFileStatus.done, sizeBytes: 10),
      ]);
      final keep = await add(
        aContent(t2, remoteId: 'b'),
        [aMedia(status: MediaFileStatus.done, sizeBytes: 7)],
      );
      await h.targets.delete(t1);
      expect(await repo.listByTarget(t1), isEmpty);
      expect(
        await repo.existingRemoteIds(t1, ContentKind.story, ['a']),
        isEmpty,
      );
      expect((await repo.listByTarget(t2)).single.content.id, keep);
      expect(await repo.storageBytesByTarget(), {t2: 7});
      expect(await repo.pendingMedia(), isEmpty);
    });
  });

  group('storageBytesByTarget', () {
    test(
      'sums DONE files with a size per target; others are excluded',
      () async {
        await add(aContent(t1, remoteId: 'a', kind: ContentKind.post), [
          aMedia(status: MediaFileStatus.done, sizeBytes: 100),
          aMedia(slideIndex: 1, status: MediaFileStatus.done, sizeBytes: 50),
          aMedia(slideIndex: 2, status: MediaFileStatus.done),
          aMedia(slideIndex: 3, sizeBytes: 999),
          aMedia(slideIndex: 4, status: MediaFileStatus.failed, sizeBytes: 999),
        ]);
        await add(aContent(t1, remoteId: 'b'), [
          aMedia(status: MediaFileStatus.done, sizeBytes: 5),
        ]);
        await add(aContent(t2, remoteId: 'c'), [aMedia(sizeBytes: 77)]);
        expect(await repo.storageBytesByTarget(), {t1: 155});
      },
    );

    test('follows updates and deletes', () async {
      final id = await add(aContent(t1), [aMedia(sizeBytes: 40)]);
      expect(await repo.storageBytesByTarget(), isEmpty);
      final file = (await repo.getById(id))!.media.single;
      await repo.updateMediaFile(file.copyWith(status: MediaFileStatus.done));
      expect(await repo.storageBytesByTarget(), {t1: 40});
      await repo.deleteByIds([id]);
      expect(await repo.storageBytesByTarget(), isEmpty);
    });
  });

  group('watchLibrary', () {
    test('emits on subscribe and after insert, media update, markViewed and '
        'delete (related-table changes re-emit)', () async {
      final w = Watch(repo.watchLibrary(ContentFilter()));
      addTearDown(w.cancel);
      await w.until((l) => l.isEmpty);

      w.mark();
      final id = await add(aContent(t1));
      await w.until((l) => l.length == 1);

      w.mark();
      final file = (await repo.getById(id))!.media.single;
      await repo.updateMediaFile(file.copyWith(status: MediaFileStatus.done));
      await w.until(
        (l) => l.single.media.single.status == MediaFileStatus.done,
      );

      w.mark();
      await repo.markViewed([id]);
      await w.until((l) => l.single.content.viewed);

      w.mark();
      await repo.deleteByIds([id]);
      await w.until((l) => l.isEmpty);
    });

    test('re-emits when a target delete cascades', () async {
      await add(aContent(t1));
      final w = Watch(repo.watchLibrary(ContentFilter()));
      addTearDown(w.cancel);
      await w.until((l) => l.length == 1);
      w.mark();
      await h.targets.delete(t1);
      await w.until((l) => l.isEmpty);
    });

    test('every watch call returns a new stream', () {
      expect(
        identical(
          repo.watchLibrary(ContentFilter()),
          repo.watchLibrary(ContentFilter()),
        ),
        isFalse,
      );
    });

    group('filter', () {
      late int storyA;
      late int storyB;
      late int postVideo;
      late int postPhoto;

      setUp(() async {
        storyA = await add(
          aContent(t1, remoteId: 'sa', postedAt: at(10)),
          [aMedia(type: MediaType.video)],
        );
        storyB = await add(
          aContent(
            t2,
            remoteId: 'sb',
            postedAt: at(20),
            status: ContentStatus.done,
          ),
          [aMedia()],
        );
        postVideo = await add(
          aContent(
            t1,
            remoteId: 'pv',
            kind: ContentKind.post,
            postedAt: at(30),
          ),
          [aMedia(), aMedia(slideIndex: 1, type: MediaType.video)],
        );
        postPhoto = await add(
          aContent(
            t2,
            remoteId: 'pp',
            kind: ContentKind.post,
            postedAt: at(30),
            status: ContentStatus.partial,
          ),
          [aMedia()],
        );
      });

      Future<List<int>> ids(ContentFilter f) async {
        final w = Watch(repo.watchLibrary(f));
        addTearDown(w.cancel);
        final list = await w.until((_) => true);
        return list.map((r) => r.content.id).toList();
      }

      test(
        'empty filter returns everything newest first (ties: higher id first)',
        () async {
          expect(await ids(ContentFilter()), [
            postPhoto,
            postVideo,
            storyB,
            storyA,
          ]);
        },
      );

      test('kind', () async {
        expect(await ids(ContentFilter(kind: ContentKind.story)), [
          storyB,
          storyA,
        ]);
        expect(await ids(ContentFilter(kind: ContentKind.post)), [
          postPhoto,
          postVideo,
        ]);
      });

      test('target ids', () async {
        expect(await ids(ContentFilter(targetIds: {t1})), [postVideo, storyA]);
        expect(await ids(ContentFilter(targetIds: {t1, t2})), hasLength(4));
        expect(await ids(ContentFilter(targetIds: const {9999})), isEmpty);
      });

      test('from is inclusive and to is exclusive', () async {
        expect(await ids(ContentFilter(from: at(20), to: at(30))), [storyB]);
        expect(await ids(ContentFilter(from: at(30))), [postPhoto, postVideo]);
        expect(await ids(ContentFilter(to: at(10))), isEmpty);
        expect(await ids(ContentFilter(to: at(11))), [storyA]);
      });

      test('media type matches content with any file of that type', () async {
        expect(
          await ids(ContentFilter(mediaType: MediaType.video)),
          [postVideo, storyA],
        );
        expect(
          await ids(ContentFilter(mediaType: MediaType.photo)),
          [postPhoto, postVideo, storyB],
        );
      });

      test('a media-type filter still returns all media of a match', () async {
        final w = Watch(
          repo.watchLibrary(ContentFilter(mediaType: MediaType.video)),
        );
        addTearDown(w.cancel);
        final list = await w.until((_) => true);
        expect(
          list.firstWhere((r) => r.content.id == postVideo).media.length,
          2,
        );
      });

      test('statuses', () async {
        expect(
          await ids(ContentFilter(statuses: const {ContentStatus.done})),
          [storyB],
        );
        expect(
          await ids(
            ContentFilter(
              statuses: const {ContentStatus.done, ContentStatus.partial},
            ),
          ),
          [postPhoto, storyB],
        );
      });

      test('combined filters are ANDed', () async {
        expect(
          await ids(
            ContentFilter(
              kind: ContentKind.post,
              targetIds: {t1},
              mediaType: MediaType.video,
              from: at(30),
              statuses: const {ContentStatus.pending},
            ),
          ),
          [postVideo],
        );
        expect(
          await ids(
            ContentFilter(
              kind: ContentKind.story,
              mediaType: MediaType.video,
              targetIds: {t2},
            ),
          ),
          isEmpty,
        );
      });
    });
  });
}
