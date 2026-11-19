import 'package:storize_domain/storize_domain.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  late Target t;
  setUp(() async {
    h = Harness();
    t = await h.addTarget();
  });

  test('AC1: deletes the gallery file BEFORE the row, then the row', () async {
    final id = await h.addContent(t, remoteId: 'a', slides: 2);
    final result = await h.deleteContent([id]);

    expect(h.spy.deletes, hasLength(2));
    expect(h.spy.deletes.every((d) => d.rowStillThere), isTrue);
    expect(h.gallery.files, isEmpty);
    expect(await h.content.getById(id), isNull);
    expect(result.deletedContentIds, [id]);
    expect(result.filesDeleted, 2);
    expect(result.isComplete, isTrue);
  });

  test(
    'AC1: a missing file is ignored and the rows are still removed',
    () async {
      final id = await h.addContent(t, remoteId: 'a');
      h.gallery.simulateMissing(h.gallery.files.single.uri);

      final result = await h.deleteContent([id]);

      expect(result.deletedContentIds, [id]);
      expect(result.filesMissing, 1);
      expect(result.filesDeleted, 0);
      expect(await h.content.getById(id), isNull);
    },
  );

  test('AC1: content without a gallery file (pending) is deleted', () async {
    final id = await h.addContent(t, remoteId: 'a', withFiles: false);
    final result = await h.deleteContent([id]);
    expect(result.deletedContentIds, [id]);
    expect(h.spy.deletes, isEmpty);
  });

  for (final (name, error) in <(String, GalleryStoreException)>[
    ('permission denied', const GalleryPermissionDenied()),
    ('write failed', const GalleryWriteFailed('IO_ERROR')),
    ('storage full', const GalleryStorageFull()),
  ]) {
    test('AC1 failure matrix: $name keeps the row and reports it', () async {
      final id = await h.addContent(t, remoteId: 'a');
      h.gallery.failNextDelete(error);

      final result = await h.deleteContent([id]);

      expect(result.deletedContentIds, isEmpty);
      expect(result.failures, [DeleteFailure(id, error)]);
      expect(result.isComplete, isFalse);
      expect(await h.content.getById(id), isNotNull);
      expect(h.gallery.files, hasLength(1));
    });
  }

  test('AC1: a failure does not abort the rest of the batch', () async {
    final a = await h.addContent(t, remoteId: 'a');
    final b = await h.addContent(t, remoteId: 'b');
    final c = await h.addContent(t, remoteId: 'c');
    // chunkSize is 2, so b and c sit in different chunks.
    h.gallery.failNextDelete(const GalleryWriteFailed('IO_ERROR'));

    final result = await h.deleteContent([a, b, c]);

    expect(result.failures.map((f) => f.contentId), [a]);
    expect(result.deletedContentIds, [b, c]);
    expect(await h.content.getById(a), isNotNull);
    expect(await h.content.getById(b), isNull);
    expect(await h.content.getById(c), isNull);
  });

  test(
    'AC1: a multi-slide item with one failing slide keeps its rows',
    () async {
      final id = await h.addContent(t, remoteId: 'a', slides: 3);
      h.gallery.failNextDelete(const GalleryPermissionDenied());

      final first = await h.deleteContent([id]);
      expect(first.failures, hasLength(1));
      expect(first.filesDeleted, 2);
      expect(await h.content.getById(id), isNotNull);

      // Idempotent re-run: the two gone files count as missing, the rest goes.
      final second = await h.deleteContent([id]);
      expect(second.isComplete, isTrue);
      expect(second.filesMissing, 2);
      expect(second.filesDeleted, 1);
      expect(await h.content.getById(id), isNull);
    },
  );

  test('AC1: the part file is discarded through MediaCache', () async {
    final id = await h.addContent(t, remoteId: 'a');
    final mediaId = (await h.content.getById(id))!.media.single.id;
    await h.cache.append(mediaId, Stream.value([1, 2, 3]));
    expect(h.cache.partIds, {mediaId});

    await h.deleteContent([id]);

    expect(h.cache.partIds, isEmpty);
  });

  test('AC1: a failing cache discard does not block the delete', () async {
    final hh = Harness(wrapCache: ThrowingCache.new);
    final tt = await hh.addTarget();
    final id = await hh.addContent(tt, remoteId: 'a');

    final result = await hh.deleteContent([id]);

    expect(result.deletedContentIds, [id]);
    expect(await hh.content.getById(id), isNull);
  });

  test('AC1: the part file is kept when the gallery delete failed', () async {
    final id = await h.addContent(t, remoteId: 'a');
    final mediaId = (await h.content.getById(id))!.media.single.id;
    await h.cache.append(mediaId, Stream.value([1]));
    h.gallery.failNextDelete(const GalleryPermissionDenied());

    await h.deleteContent([id]);

    expect(h.cache.partIds, {mediaId});
  });

  test('re-run and unknown IDs are idempotent', () async {
    final id = await h.addContent(t, remoteId: 'a');
    await h.deleteContent([id]);

    final again = await h.deleteContent([id, 999, id]);

    expect(again.deletedContentIds, isEmpty);
    expect(again.notFoundIds, [id, 999]);
    expect(again.isComplete, isTrue);
  });

  test('an empty input does nothing', () async {
    final result = await h.deleteContent(const []);
    expect(result.deletedContentIds, isEmpty);
    expect(result.isComplete, isTrue);
  });

  test('chunkSize must be positive', () {
    expect(
      () => DeleteContent(
        content: h.content,
        gallery: h.gallery,
        cache: h.cache,
        chunkSize: 0,
      ),
      throwsArgumentError,
    );
  });

  test(
    'BR-4: expired stories are only deleted when asked, never on their own',
    () async {
      final id = await h.addContent(
        t,
        remoteId: 'a',
        expiresAt: h.clock.now().subtract(const Duration(days: 3)),
      );
      final other = await h.addContent(t, remoteId: 'b');

      await h.deleteContent([other]);

      expect(await h.content.getById(id), isNotNull);
      expect(h.gallery.files, hasLength(1));
    },
  );
}
