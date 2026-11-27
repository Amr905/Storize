import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

/// QA T-058: crash between steps and concurrent runs.
void main() {
  late FakeTargetRepo targets;
  late FakeContentRepo content;
  late FakeGalleryStore gallery;
  late FakeMoveStateStore state;
  late FakeClock clock;
  late FakeGovernorLeaseRepo leases;
  late int targetId;
  String? crashAt;

  Future<List<MediaFile>> rows() async => [
    for (final c in await content.watchLibrary(ContentFilter()).first)
      ...c.media,
  ];

  MoveLibrary newMove() => MoveLibrary(
    content: content,
    gallery: gallery,
    state: state,
    clock: clock,
    leases: leases,
    batchSize: 2,
  );

  Future<void> seed(int n) async {
    for (var i = 0; i < n; i++) {
      final f = await gallery.save(
        sourcePath: 'none',
        relativeDir: 'alice',
        displayName: 'f$i.jpg',
        mime: 'image/jpeg',
      );
      await content.insertIfNew(
        s.content(
          targetId: targetId,
          remoteId: 'r$i',
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
  }

  /// Every row points at a file that exists.
  Future<void> expectNoDanglingRows() async {
    for (final m in await rows()) {
      expect(await gallery.exists(m.contentUri!), isTrue, reason: 'dangling');
    }
  }

  setUp(() async {
    crashAt = null;
    targets = FakeTargetRepo();
    content = FakeContentRepo(targets: targets);
    state = FakeMoveStateStore();
    clock = FakeClock(s.t0);
    leases = FakeGovernorLeaseRepo(clock);
    gallery = FakeGalleryStore(
      onOperation: (op, uri) async {
        if (op == crashAt) throw _Crash();
        await Future<void>.delayed(Duration.zero);
      },
    );
    targetId = (await targets.insert(s.target())).id;
  });

  for (final op in ['copy', 'delete']) {
    test('a crash at "$op" never leaves a dangling row', () async {
      await seed(3);
      crashAt = op;
      await expectLater(
        newMove().run(StorageTarget.private),
        throwsA(isA<_Crash>()),
      );
      await expectNoDanglingRows();
      crashAt = null;
      final r = await newMove().run(StorageTarget.private);
      expect(r.end, MoveEnd.finished);
      await expectNoDanglingRows();
      expect(
        (await rows()).every(
          (m) => storageTargetOf(m.contentUri!) == StorageTarget.private,
        ),
        isTrue,
      );
    });
  }

  test(
    'two concurrent runs: no dangling row, no orphan copies',
    () async {
      await seed(6);
      final a = newMove().run(StorageTarget.private);
      final b = newMove().run(StorageTarget.private);
      await Future.wait([a, b]);
      await expectNoDanglingRows();
      final rowUris = (await rows()).map((m) => m.contentUri).toSet();
      expect(rowUris, hasLength(6), reason: 'distinct files per row');
      // Every private file must be referenced by a row (no leaked duplicates).
      expect(
        gallery.privateFiles.map((f) => f.uri).toSet(),
        rowUris,
        reason: 'orphaned copies left by the double move',
      );
      expect(gallery.galleryFiles, isEmpty);
    },
  );
}

final class _Crash extends Error {}
