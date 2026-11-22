import 'package:storize_domain/storize_domain.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  late Target t;
  late RemoveMediaFile remove;
  setUp(() async {
    h = Harness();
    t = await h.addTarget();
    remove = RemoveMediaFile(
      content: h.content,
      gallery: h.gallery,
      cache: h.cache,
    );
  });

  test('removes the gallery file, thumbnail and row; keeps the post', () async {
    final id = await h.addContent(t, remoteId: 'a', slides: 2);
    final first = (await h.content.getById(id))!.media.first;
    await h.cache.writeThumbnail(first.id, [1, 2]);

    final r = await remove(id, first.id);

    expect(r.removed, isTrue);
    expect(r.contentDeleted, isFalse);
    expect(h.gallery.files, hasLength(1));
    expect(h.cache.thumbnailBytes(first.id), isNull);
    expect((await h.content.getById(id))!.media, hasLength(1));
  });

  test('removing the last slide deletes the content row', () async {
    final id = await h.addContent(t, remoteId: 'a');
    final only = (await h.content.getById(id))!.media.single;

    final r = await remove(id, only.id);

    expect(r.contentDeleted, isTrue);
    expect(await h.content.getById(id), isNull);
  });

  test('a missing gallery file is ignored and the row is removed', () async {
    final id = await h.addContent(t, remoteId: 'a', slides: 2);
    final first = (await h.content.getById(id))!.media.first;
    h.gallery.simulateMissing(first.contentUri!);

    expect((await remove(id, first.id)).removed, isTrue);
    expect((await h.content.getById(id))!.media, hasLength(1));
  });

  test('a failed gallery delete keeps the row', () async {
    final id = await h.addContent(t, remoteId: 'a', slides: 2);
    final first = (await h.content.getById(id))!.media.first;
    h.gallery.failNextDelete(const GalleryPermissionDenied());

    final r = await remove(id, first.id);

    expect(r.removed, isFalse);
    expect(r.error, isA<GalleryPermissionDenied>());
    expect((await h.content.getById(id))!.media, hasLength(2));
  });

  test('unknown media or content id reports notFound', () async {
    final id = await h.addContent(t, remoteId: 'a');
    expect((await remove(id, 999)).notFound, isTrue);
    expect((await remove(999, 1)).notFound, isTrue);
  });
}
