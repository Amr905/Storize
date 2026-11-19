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

  test('AC2 keep media: target and rows go, gallery files stay', () async {
    final a = await h.addContent(t, remoteId: 'a');
    await h.addContent(t, remoteId: 'b', slides: 2);

    final result = await h.removeTarget(t.id, deleteMedia: false);

    expect(result.targetRemoved, isTrue);
    expect(result.deletion, isNull);
    expect(await h.targets.getById(t.id), isNull);
    expect(await h.content.getById(a), isNull); // cascade
    expect(await h.content.listByTarget(t.id), isEmpty);
    expect(h.gallery.files, hasLength(3));
    expect(h.spy.deletes, isEmpty);
  });

  test('AC2 delete media: files first, then the target', () async {
    await h.addContent(t, remoteId: 'a');
    await h.addContent(t, remoteId: 'b');
    await h.addContent(t, remoteId: 'c');

    final result = await h.removeTarget(t.id, deleteMedia: true);

    expect(result.targetRemoved, isTrue);
    expect(result.deletion!.deletedContentIds, hasLength(3));
    expect(h.spy.deletes.every((d) => d.rowStillThere), isTrue);
    expect(h.gallery.files, isEmpty);
    expect(await h.targets.getById(t.id), isNull);
  });

  test('AC2 delete media: a missing file does not block the removal', () async {
    await h.addContent(t, remoteId: 'a');
    h.gallery.simulateMissing(h.gallery.files.single.uri);

    final result = await h.removeTarget(t.id, deleteMedia: true);

    expect(result.targetRemoved, isTrue);
    expect(result.deletion!.filesMissing, 1);
  });

  test(
    'AC2 delete media: a failed file keeps the target and its rows',
    () async {
      final a = await h.addContent(t, remoteId: 'a');
      final b = await h.addContent(t, remoteId: 'b');
      final c = await h.addContent(t, remoteId: 'c');
      // listByTarget is newest first (equal postedAt: ID descending): c, b, a.
      h.gallery.failNextDelete(const GalleryPermissionDenied());

      final result = await h.removeTarget(t.id, deleteMedia: true);

      expect(result.targetRemoved, isFalse);
      expect(result.isComplete, isFalse);
      expect(result.deletion!.failures.map((f) => f.contentId), [c]);
      expect(await h.targets.getById(t.id), isNotNull);
      expect(await h.content.getById(c), isNotNull);
      expect(await h.content.getById(a), isNull);
      expect(await h.content.getById(b), isNull);
      expect(h.gallery.files, hasLength(1));
    },
  );

  test('AC2: re-running after a failure or a crash finishes the job', () async {
    await h.addContent(t, remoteId: 'a');
    await h.addContent(t, remoteId: 'b');
    h.gallery.failNextDelete(const GalleryWriteFailed('IO_ERROR'));
    final first = await h.removeTarget(t.id, deleteMedia: true);
    expect(first.targetRemoved, isFalse);

    final second = await h.removeTarget(t.id, deleteMedia: true);

    expect(second.targetRemoved, isTrue);
    expect(h.gallery.files, isEmpty);
    expect(await h.targets.getById(t.id), isNull);
  });

  test('AC2: a missing target is a no-op, repeat calls are safe', () async {
    await h.removeTarget(t.id, deleteMedia: true);
    for (final deleteMedia in [true, false]) {
      final r = await h.removeTarget(t.id, deleteMedia: deleteMedia);
      expect(r.targetFound, isFalse);
      expect(r.isComplete, isTrue);
    }
  });

  test('AC2: other targets are untouched', () async {
    final other = await h.addTarget(remoteUserId: '200', name: 'b');
    final keep = await h.addContent(other, remoteId: 'x');
    await h.addContent(t, remoteId: 'a');

    await h.removeTarget(t.id, deleteMedia: true);

    expect(await h.content.getById(keep), isNotNull);
    expect(h.gallery.files, hasLength(1));
  });

  test('BR-4: removing media never looks at expiry of other content', () async {
    final expired = await h.addContent(
      t,
      remoteId: 'e',
      expiresAt: h.clock.now().subtract(const Duration(days: 1)),
    );
    final other = await h.addTarget(remoteUserId: '200', name: 'b');
    final theirs = await h.addContent(
      other,
      remoteId: 'x',
      expiresAt: h.clock.now().subtract(const Duration(days: 9)),
    );

    await h.removeTarget(t.id, deleteMedia: true);

    expect(await h.content.getById(expired), isNull); // deleted on request
    expect(await h.content.getById(theirs), isNotNull);
  });
}
