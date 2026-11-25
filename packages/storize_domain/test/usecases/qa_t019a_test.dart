import 'package:storize_domain/storize_domain.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// QA (T-019a): ordering and partial failure of thumbnail deletion.
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

  Future<int> mid(int contentId) async =>
      (await h.content.getById(contentId))!.media.first.id;

  test('two items in one chunk: only the item whose delete failed keeps its '
      'thumbnail and row', () async {
    final a = await h.addContent(t, remoteId: 'a');
    final b = await h.addContent(t, remoteId: 'b');
    final ma = await mid(a);
    final mb = await mid(b);
    await h.cache.writeThumbnail(ma, [1]);
    await h.cache.writeThumbnail(mb, [2]);
    h.gallery.failNextDelete(const GalleryWriteFailed('IO_ERROR'));

    final result = await h.deleteContent([a, b]);

    expect(result.failures, hasLength(1));
    final failedId = result.failures.single.contentId;
    final okId = failedId == a ? b : a;
    final failedMid = failedId == a ? ma : mb;
    final okMid = failedId == a ? mb : ma;
    expect(h.cache.thumbnailBytes(failedMid), isNotNull);
    expect(h.cache.thumbnailBytes(okMid), isNull);
    expect(await h.content.getById(failedId), isNotNull);
    expect(await h.content.getById(okId), isNull);
  });

  test('a thumbnail delete that throws for one slide does not stop the '
      'others being attempted nor the row delete', () async {
    final id = await h.addContent(t, remoteId: 'a', slides: 3);
    spy.throwOnDeleteThumbnail = true;
    final result = await h.deleteContent([id]);
    expect(result.deletedContentIds, [id]);
    expect(spy.thumbDeletes, hasLength(3));
    expect(await h.content.getById(id), isNull);
  });

  test(
    'thumbnails of a missing-file slide and a deleted slide both go',
    () async {
      final id = await h.addContent(t, remoteId: 'a', slides: 2);
      final ids = [for (final m in (await h.content.getById(id))!.media) m.id];
      for (final m in ids) {
        await h.cache.writeThumbnail(m, [m]);
      }
      h.gallery.simulateMissing(h.gallery.files.first.uri);
      final result = await h.deleteContent([id]);
      expect(result.filesMissing, 1);
      expect(result.filesDeleted, 1);
      for (final m in ids) {
        expect(h.cache.thumbnailBytes(m), isNull);
      }
    },
  );
}
