import 'package:storize_domain/storize_domain.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// AC4: DeleteContent deletes the thumbnail of each media file, after its
/// gallery file is gone (or was missing), best effort.
void main() {
  late Harness h;
  late SpyThumbCache spy;
  late Target t;

  setUp(() async {
    h = Harness(
      wrapCache: (c) => spy = SpyThumbCache(c, () => h.gallery.files.length),
    );
    t = await h.addTarget();
  });

  Future<List<int>> mediaIdsOf(int contentId) async => [
    for (final m in (await h.content.getById(contentId))!.media) m.id,
  ];

  test('AC4: the thumbnail of every media file is deleted', () async {
    final id = await h.addContent(t, remoteId: 'a', slides: 2);
    final ids = await mediaIdsOf(id);
    for (final mid in ids) {
      await h.cache.writeThumbnail(mid, [mid]);
    }

    final result = await h.deleteContent([id]);

    expect(result.deletedContentIds, [id]);
    for (final mid in ids) {
      expect(h.cache.thumbnailBytes(mid), isNull);
    }
    expect(spy.thumbDeletes.map((d) => d.mediaFileId), unorderedEquals(ids));
  });

  test(
    'AC4: a thumbnail is deleted only after its gallery file is gone',
    () async {
      final id = await h.addContent(t, remoteId: 'a', slides: 2);
      await h.deleteContent([id]);

      expect(spy.thumbDeletes, hasLength(2));
      for (final d in spy.thumbDeletes) {
        expect(d.galleryFilesLeft, 0, reason: 'gallery files go first');
      }
    },
  );

  test('AC4: a missing gallery file still lets its thumbnail go', () async {
    final id = await h.addContent(t, remoteId: 'a');
    final mid = (await mediaIdsOf(id)).single;
    await h.cache.writeThumbnail(mid, [1]);
    h.gallery.simulateMissing(h.gallery.files.single.uri);

    final result = await h.deleteContent([id]);

    expect(result.deletedContentIds, [id]);
    expect(result.filesMissing, 1);
    expect(h.cache.thumbnailBytes(mid), isNull);
  });

  test(
    'AC4: pending content without a gallery file loses its thumbnail',
    () async {
      final id = await h.addContent(t, remoteId: 'a', withFiles: false);
      final mid = (await mediaIdsOf(id)).single;
      await h.cache.writeThumbnail(mid, [1]);

      final result = await h.deleteContent([id]);

      expect(result.deletedContentIds, [id]);
      expect(h.cache.thumbnailBytes(mid), isNull);
    },
  );

  test(
    'AC4: a failed gallery delete keeps the thumbnail and the row',
    () async {
      final id = await h.addContent(t, remoteId: 'a');
      final mid = (await mediaIdsOf(id)).single;
      await h.cache.writeThumbnail(mid, [1]);
      h.gallery.failNextDelete(const GalleryPermissionDenied());

      final result = await h.deleteContent([id]);

      expect(result.failures, hasLength(1));
      expect(spy.thumbDeletes, isEmpty);
      expect(h.cache.thumbnailBytes(mid), [1]);
      expect(await h.content.getById(id), isNotNull);
    },
  );

  test(
    'AC4: in a multi-slide item, one failing slide keeps every thumbnail',
    () async {
      final id = await h.addContent(t, remoteId: 'a', slides: 2);
      final ids = await mediaIdsOf(id);
      for (final mid in ids) {
        await h.cache.writeThumbnail(mid, [mid]);
      }
      h.gallery.failNextDelete(const GalleryWriteFailed('IO_ERROR'));

      final result = await h.deleteContent([id]);

      expect(result.failures, hasLength(1));
      expect(spy.thumbDeletes, isEmpty);
      for (final mid in ids) {
        expect(h.cache.thumbnailBytes(mid), [mid]);
      }
    },
  );

  test(
    'AC4: a throwing thumbnail delete does not block the row delete',
    () async {
      final id = await h.addContent(t, remoteId: 'a', slides: 2);
      final ids = await mediaIdsOf(id);
      spy.throwOnDeleteThumbnail = true;

      final result = await h.deleteContent([id]);

      expect(result.deletedContentIds, [id]);
      expect(result.isComplete, isTrue);
      expect(await h.content.getById(id), isNull);
      expect(spy.thumbDeletes, hasLength(ids.length), reason: 'all attempted');
    },
  );

  test(
    'AC4: a throwing thumbnail delete still lets the part file go',
    () async {
      final id = await h.addContent(t, remoteId: 'a');
      final mid = (await mediaIdsOf(id)).single;
      await h.cache.append(mid, Stream.value([1]));
      spy.throwOnDeleteThumbnail = true;

      await h.deleteContent([id]);

      expect(h.cache.partIds, isEmpty);
      expect(await h.content.getById(id), isNull);
    },
  );

  test(
    'AC4: re-running after a delete is idempotent with no thumbnail',
    () async {
      final id = await h.addContent(t, remoteId: 'a');
      await h.deleteContent([id]);

      final again = await h.deleteContent([id]);

      expect(again.deletedContentIds, isEmpty);
      expect(again.notFoundIds, [id]);
      expect(again.isComplete, isTrue);
    },
  );

  test('AC4: the thumbnail of other content is left alone', () async {
    final gone = await h.addContent(t, remoteId: 'a');
    final kept = await h.addContent(t, remoteId: 'b');
    final keptMid = (await mediaIdsOf(kept)).single;
    await h.cache.writeThumbnail(keptMid, [7]);

    await h.deleteContent([gone]);

    expect(h.cache.thumbnailBytes(keptMid), [7]);
    expect(await h.content.getById(kept), isNotNull);
  });
}
