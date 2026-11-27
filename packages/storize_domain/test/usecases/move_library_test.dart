import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

/// Records, at every gallery operation, which reference the row holds.
void main() {
  late FakeTargetRepo targets;
  late FakeContentRepo content;
  late FakeGalleryStore gallery;
  late FakeMoveStateStore state;
  late FakeClock clock;
  late FakeDiagnosticLog log;
  late MoveLibrary move;
  late int targetId;
  final events = <String>[];
  final rowUriAtDelete = <String, String?>{};
  void Function()? onCopy;

  Future<List<MediaFile>> rows() async => [
    for (final c in await content.watchLibrary(ContentFilter()).first)
      ...c.media,
  ];

  /// Saves [n] files into [from] and stores rows pointing at them.
  Future<List<String>> seed(
    int n, {
    StorageTarget from = StorageTarget.gallery,
  }) async {
    final uris = <String>[];
    for (var i = 0; i < n; i++) {
      final f = await gallery.save(
        sourcePath: 'none',
        relativeDir: 'alice',
        displayName: 'f$i.jpg',
        mime: 'image/jpeg',
        target: from,
      );
      uris.add(f.uri);
      await content.insertIfNew(
        s.content(
          targetId: targetId,
          remoteId: 'r$i',
          // Newest first, like the Library: the run handles them in seed order.
          postedAt: s.t0.subtract(Duration(minutes: i)),
          status: ContentStatus.done,
        ),
        [
          MediaFile(
            id: MediaFile.unsavedId,
            contentId: MediaFile.unsavedContentId,
            slideIndex: 0,
            mediaType: MediaType.photo,
            sourceUrl: 'https://example.invalid/$i',
            status: MediaFileStatus.done,
            contentUri: f.uri,
            relativePath: 'Pictures/Storize/alice/',
            displayName: 'f$i.jpg',
            sizeBytes: f.sizeBytes,
          ),
        ],
      );
    }
    return uris;
  }

  setUp(() async {
    events.clear();
    rowUriAtDelete.clear();
    onCopy = null;
    targets = FakeTargetRepo();
    content = FakeContentRepo(targets: targets);
    state = FakeMoveStateStore();
    clock = FakeClock(s.t0);
    log = FakeDiagnosticLog();
    gallery = FakeGalleryStore(
      onOperation: (op, uri) async {
        events.add(op);
        if (op == 'copy') onCopy?.call();
        if (op == 'delete' && uri != null) {
          final all = await rows();
          rowUriAtDelete[uri] = all.map((m) => m.contentUri).contains(uri)
              ? 'old'
              : 'new';
        }
      },
    );
    move = MoveLibrary(
      content: content,
      gallery: gallery,
      state: state,
      clock: clock,
      log: log,
      batchSize: 2,
    );
    targetId = (await targets.insert(s.target())).id;
  });

  test('moves every file to private; rows point at the new refs', () async {
    await seed(5);
    expect(await move.countToMove(StorageTarget.private), 5);

    final r = await move.run(StorageTarget.private);

    expect(r.end, MoveEnd.finished);
    expect(r.progress.moved, 5);
    expect(r.progress.status, MoveStatus.done);
    final all = await rows();
    expect(
      all.every((m) => storageTargetOf(m.contentUri!) == StorageTarget.private),
      isTrue,
    );
    expect(gallery.galleryFiles, isEmpty);
    expect(gallery.privateFiles, hasLength(5));
    expect(await move.countToMove(StorageTarget.private), 0);
  });

  test('moves back to the gallery', () async {
    await seed(3, from: StorageTarget.private);
    final r = await move.run(StorageTarget.gallery);
    expect(r.progress.moved, 3);
    expect(gallery.privateFiles, isEmpty);
    expect(gallery.galleryFiles, hasLength(3));
  });

  test('order: copy, then row update, then delete of the original', () async {
    final uris = await seed(1);
    await move.run(StorageTarget.private);
    expect(events.where((e) => e != 'save'), ['copy', 'delete']);
    // When the original was deleted the row already held the new reference.
    expect(rowUriAtDelete[uris.single], 'new');
  });

  test('a failed copy keeps the original and the row', () async {
    final uris = await seed(2);
    gallery.failNextCopy(const GalleryWriteFailed('IO_ERROR'));

    final r = await move.run(StorageTarget.private);

    expect(r.progress.failed, 1);
    expect(r.progress.moved, 1);
    final all = await rows();
    expect(all.first.contentUri, uris.first);
    expect(await gallery.exists(uris.first), isTrue);
    expect(gallery.privateFiles, hasLength(1));
  });

  test('a failed verification keeps the original', () async {
    final uris = await seed(1);
    gallery.failNextCopy(const GalleryWriteFailed('VERIFY_FAILED'));
    final r = await move.run(StorageTarget.private);
    expect(r.progress.failed, 1);
    expect((await rows()).single.contentUri, uris.single);
    expect(await gallery.exists(uris.single), isTrue);
  });

  test('a failed delete of the original keeps both and counts moved', () async {
    final uris = await seed(1);
    gallery.failNextDelete(const GalleryWriteFailed('IO_ERROR'));

    final r = await move.run(StorageTarget.private);

    expect(r.progress.moved, 1);
    final row = (await rows()).single;
    expect(storageTargetOf(row.contentUri!), StorageTarget.private);
    expect(await gallery.exists(uris.single), isTrue); // leftover, not lost
    expect(await gallery.exists(row.contentUri!), isTrue);
  });

  test('a failed row update removes the copy and keeps the original', () async {
    final uris = await seed(1);
    final broken = MoveLibrary(
      content: _FailingUpdateRepo(content),
      gallery: gallery,
      state: state,
      clock: clock,
    );
    final r = await broken.run(StorageTarget.private);
    expect(r.progress.failed, 1);
    expect(gallery.privateFiles, isEmpty);
    expect(await gallery.exists(uris.single), isTrue);
    expect((await rows()).single.contentUri, uris.single);
  });

  test('a missing original is reported, not failed', () async {
    final uris = await seed(3);
    gallery.simulateMissing(uris[1]);

    final r = await move.run(StorageTarget.private);

    expect(r.progress.missing, 1);
    expect(r.progress.failed, 0);
    expect(r.progress.moved, 2);
    expect(r.end, MoveEnd.finished);
  });

  test('storage full stops cleanly, then a new run continues', () async {
    await seed(5);
    gallery.failNextCopy(const GalleryStorageFull(), after: 2);

    final r = await move.run(StorageTarget.private);

    expect(r.end, MoveEnd.storageFull);
    expect(r.progress.status, MoveStatus.storageFull);
    expect(r.progress.moved, 2);
    expect(gallery.galleryFiles, hasLength(3));
    expect(gallery.privateFiles, hasLength(2));

    final again = await move.run(StorageTarget.private);
    expect(again.end, MoveEnd.finished);
    expect(again.progress.moved, 5);
    expect(again.progress.total, 5);
    expect(gallery.privateFiles, hasLength(5));
  });

  test('resume after a kill never moves a file twice', () async {
    final uris = await seed(4);
    var copies = 0;
    onCopy = () {
      // The process dies while the third file is about to be copied.
      if (++copies == 3) throw _Crash();
    };
    await expectLater(
      move.run(StorageTarget.private),
      throwsA(isA<_Crash>()),
    );
    // The state still says running; two rows moved, two originals untouched.
    expect(state.progress.status, MoveStatus.running);
    final mid = await rows();
    expect(
      mid.where((m) => storageTargetOf(m.contentUri!) == StorageTarget.private),
      hasLength(2),
    );
    expect(await gallery.exists(uris[2]), isTrue);
    expect(await gallery.exists(uris[3]), isTrue);
    onCopy = null;
    events.clear();

    final r = await move.run(StorageTarget.private);

    expect(r.end, MoveEnd.finished);
    expect(r.progress.moved, 4);
    expect(r.progress.total, 4);
    // Only the two that were left are copied.
    expect(events.where((e) => e == 'copy'), hasLength(2));
    events.clear();
    await move.run(StorageTarget.private);
    expect(events, isEmpty);
    expect(gallery.privateFiles, hasLength(4));
    expect(gallery.galleryFiles, isEmpty);
  });

  test(
    'a file that failed is retried by the next run and counted once',
    () async {
      await seed(3);
      gallery.failNextCopy(const GalleryWriteFailed('IO_ERROR'), after: 1);
      final first = await move.run(StorageTarget.private);
      expect(first.progress.failed, 1);
      expect(first.progress.moved, 2);

      final second = await move.run(StorageTarget.private);
      expect(second.progress.moved, 3);
      expect(second.progress.failed, 0);
      expect(second.progress.total, 3);
    },
  );

  test('cancel stops before the next file; files moved stay moved', () async {
    await seed(5);
    var copies = 0;
    onCopy = () {
      if (++copies == 2) unawaited(state.setCancelRequested(value: true));
    };

    final r = await move.run(StorageTarget.private);

    expect(r.end, MoveEnd.cancelled);
    expect(r.progress.status, MoveStatus.cancelled);
    expect(r.progress.moved, 2);
    expect(await state.cancelRequested(), isFalse);
    expect(gallery.galleryFiles, hasLength(3));
    // Resumable afterwards.
    onCopy = null;
    final again = await move.run(StorageTarget.private);
    expect(again.progress.moved, 5);
    expect(gallery.galleryFiles, isEmpty);
  });

  test('cancel() shows cancelled at once and asks the run to stop', () async {
    await state.write(
      MoveProgress(
        status: MoveStatus.running,
        target: StorageTarget.private,
        total: 9,
        updatedAt: clock.now(),
      ),
    );
    await move.cancel();
    expect(state.progress.status, MoveStatus.cancelled);
    expect(await state.cancelRequested(), isTrue);
  });

  test('the deadline stops the run so the task can roll over', () async {
    await seed(3);
    final r = await move.run(
      StorageTarget.private,
      deadline: clock.now(),
    );
    expect(r.end, MoveEnd.deadline);
    expect(r.progress.moved, 0);
    expect(r.progress.status, MoveStatus.running);
  });

  test('an item deleted during the move leaves no copy behind', () async {
    final uris = await seed(1);
    final racing = MoveLibrary(
      content: _DeletingRepo(content),
      gallery: gallery,
      state: state,
      clock: clock,
    );
    final r = await racing.run(StorageTarget.private);
    expect(r.progress.moved, 0);
    expect(gallery.privateFiles, isEmpty);
    expect(uris, isNotEmpty);
  });

  test('a row without a path is counted failed, nothing is touched', () async {
    final f = await gallery.save(
      sourcePath: 'none',
      relativeDir: 'alice',
      displayName: 'x.jpg',
      mime: 'image/jpeg',
    );
    await content.insertIfNew(
      s.content(targetId: targetId, status: ContentStatus.done),
      [
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: 0,
          mediaType: MediaType.photo,
          sourceUrl: 'https://example.invalid/x',
          status: MediaFileStatus.done,
          contentUri: f.uri,
        ),
      ],
    );
    final r = await move.run(StorageTarget.private);
    expect(r.progress.failed, 1);
    expect(await gallery.exists(f.uri), isTrue);
  });

  test('the log has counts and codes only: no uri, path or username', () async {
    await seed(2);
    gallery.failNextCopy(const GalleryWriteFailed('IO_ERROR'));
    await move.run(StorageTarget.private);
    final text = log.entries.map((e) => '${e.tag} ${e.message}').join('\n');
    expect(text, contains('moved='));
    expect(text, isNot(contains('content://')));
    expect(text, isNot(contains('file://')));
    expect(text, isNot(contains('alice')));
    expect(text, isNot(contains('Pictures')));
  });

  test('relativeDirOf', () {
    expect(MoveLibrary.relativeDirOf('Pictures/Storize/bob/'), 'bob');
    expect(
      MoveLibrary.relativeDirOf('Movies/Storize/bob/Highlights/Trip/'),
      'bob/Highlights/Trip',
    );
    expect(MoveLibrary.relativeDirOf('Pictures/Other/'), isNull);
    expect(MoveLibrary.relativeDirOf(null), isNull);
    expect(MoveLibrary.relativeDirOf('Pictures/Storize/'), isNull);
  });

  test('storageTargetOf tells the two kinds of reference apart', () {
    expect(storageTargetOf('file:///x/y.jpg'), StorageTarget.private);
    expect(
      storageTargetOf('content://media/external/images/media/1'),
      StorageTarget.gallery,
    );
  });
}

/// A repo whose `updateMediaFile` always fails.
final class _FailingUpdateRepo extends _Delegating {
  _FailingUpdateRepo(super.inner);

  @override
  Future<void> updateMediaFile(MediaFile file) async => throw Exception('disk');
}

/// A repo that deletes the item right before the row is updated.
final class _DeletingRepo extends _Delegating {
  _DeletingRepo(super.inner);

  @override
  Future<void> updateMediaFile(MediaFile file) async {
    await inner.deleteByIds([file.contentId]);
    return inner.updateMediaFile(file);
  }
}

base class _Delegating implements ContentRepo {
  _Delegating(this.inner);

  final FakeContentRepo inner;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());

  @override
  Stream<List<ContentWithMedia>> watchLibrary(ContentFilter filter) =>
      inner.watchLibrary(filter);

  @override
  Future<void> updateMediaFile(MediaFile file) => inner.updateMediaFile(file);
}

/// Stands for the process being killed: not an `Exception`, so nothing in the
/// use case catches it.
final class _Crash extends Error {}
