import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// A [GalleryStore] that runs [onDelete] once, before the first delete.
final class HookGallery implements GalleryStore {
  HookGallery(this.inner, this.onDelete);

  final GalleryStore inner;
  Future<void> Function()? onDelete;

  @override
  Future<bool> delete(String contentUri) async {
    final hook = onDelete;
    onDelete = null;
    if (hook != null) await hook();
    return inner.delete(contentUri);
  }

  @override
  Future<bool> exists(String u) => inner.exists(u);

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
    StorageTarget target = StorageTarget.gallery,
  }) => inner.save(
    sourcePath: sourcePath,
    relativeDir: relativeDir,
    displayName: displayName,
    mime: mime,
  );

  @override
  Future<int?> size(String u) => inner.size(u);

  @override
  Future<GalleryFile> copyTo(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => throw UnimplementedError();

  @override
  Future<GalleryFile> move(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => throw UnimplementedError();
}

/// A [ContentRepo] whose `deleteByIds` throws once (the process "dies" after
/// the files were deleted but before the rows were).
final class CrashingContentRepo implements ContentRepo {
  CrashingContentRepo(this.inner);

  final ContentRepo inner;

  @override
  Future<SavedCounts> savedSince(DateTime since) => inner.savedSince(since);
  bool crashNext = true;

  @override
  Stream<List<ContentWithMedia>> watchLibrarySearch(
    ContentFilter filter,
    String query,
  ) => inner.watchLibrarySearch(filter, query);

  @override
  Future<void> deleteByIds(Iterable<int> ids) async {
    if (crashNext) {
      crashNext = false;
      throw StateError('process died');
    }
    return inner.deleteByIds(ids);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<List<ContentWithMedia>> getByIds(Iterable<int> ids) =>
      inner.getByIds(ids);

  @override
  Future<List<ContentWithMedia>> listByTarget(int targetId) =>
      inner.listByTarget(targetId);

  @override
  Future<List<ContentWithMedia>> olderThan(DateTime cutoff) =>
      inner.olderThan(cutoff);
}

void main() {
  late Harness h;
  late Target t;
  late DateTime now;

  setUp(() async {
    h = Harness();
    now = h.clock.now();
    t = await h.addTarget();
  });

  group('retention age basis (finding F1)', () {
    test('F1 fixed: item posted 10d ago but downloaded just now is kept with '
        'N=7 (age = how long Storize has had it)', () async {
      await h.settings.update((s) => s.copyWith(retentionDays: 7));
      final id = await h.addContent(
        t,
        remoteId: 'late',
        kind: ContentKind.post,
        postedAt: now.subtract(const Duration(days: 10)),
        detectedAt: now,
        downloadedAt: now,
      );
      final r = await h.retention();
      expect(r.deletion!.deletedContentIds, isEmpty);
      expect(await h.content.getById(id), isNotNull);
      expect(h.gallery.files, hasLength(1));
    });
  });

  group('skew guard liveness (findings F2, F3)', () {
    test('F2 fixed: a stale future-dated candidate is excluded and counted, '
        'other expired items are deleted', () async {
      await h.settings.update((s) => s.copyWith(retentionDays: 7));
      final fine = await h.addContent(
        t,
        remoteId: 'fine',
        postedAt: now.subtract(const Duration(days: 30)),
      );
      await h.addContent(
        t,
        remoteId: 'stale-future',
        postedAt: now.subtract(const Duration(days: 20)),
        detectedAt: now.add(const Duration(days: 400)),
      );
      final r = await h.retention();
      expect(r.skipped, isNull);
      expect(r.skippedFutureDated, 1);
      expect(await h.content.getById(fine), isNull);
      // Still excluded a day later, and still not blocking anything.
      h.clock.advance(const Duration(days: 1));
      final again = await h.retention();
      expect(again.skipped, isNull);
      expect(again.skippedFutureDated, 1);
    });

    test('CHARACTERIZATION: all targets paused for >30 days disables '
        'retention until a check run finishes', () async {
      await h.settings.update((s) => s.copyWith(retentionDays: 7));
      final run = await h.checkRuns.start(
        scope: CheckScope.posts,
        trigger: CheckTrigger.periodic,
        startedAt: now.subtract(const Duration(days: 31)),
      );
      await h.checkRuns.finish(
        run.id,
        finishedAt: now.subtract(const Duration(days: 31)),
        result: CheckResult.ok,
      );
      final id = await h.addContent(
        t,
        remoteId: 'x',
        postedAt: now.subtract(const Duration(days: 60)),
      );
      expect((await h.retention()).skipped, RetentionSkip.clockSkew);
      expect(await h.content.getById(id), isNotNull);
    });

    test('LIMIT: a forward clock jump followed by a finished run defeats the '
        'guard (reference refreshed with the wrong clock)', () async {
      await h.settings.update((s) => s.copyWith(retentionDays: 30));
      final id = await h.addContent(
        t,
        remoteId: 'recent',
        postedAt: now.subtract(const Duration(days: 1)),
      );
      h.clock.advance(const Duration(days: 400)); // bogus jump
      final jumped = h.clock.now();
      final run = await h.checkRuns.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: jumped,
      );
      await h.checkRuns.finish(
        run.id,
        finishedAt: jumped,
        result: CheckResult.ok,
      );
      final r = await h.retention();
      expect(r.deletion?.deletedContentIds, [id]);
    });
  });

  group('crash points and ordering', () {
    test('file deleted, process dies before rows: re-run removes the row and '
        'counts the file as missing', () async {
      await h.settings.update((s) => s.copyWith(retentionDays: 7));
      final id = await h.addContent(
        t,
        remoteId: 'a',
        slides: 2,
        postedAt: now.subtract(const Duration(days: 30)),
      );
      final crashing = CrashingContentRepo(h.content);
      final dc = DeleteContent(
        content: crashing,
        gallery: h.gallery,
        cache: h.cache,
      );
      await expectLater(dc([id]), throwsStateError);
      expect(h.gallery.files, isEmpty);
      expect(await h.content.getById(id), isNotNull);

      final r = await h.deleteContent([id]);
      expect(r.deletedContentIds, [id]);
      expect(r.filesMissing, 2);
      expect(await h.content.getById(id), isNull);
    });

    test('multi-slide: slide 0 already gone, slide 1 present: deleted, one '
        'missing', () async {
      final id = await h.addContent(t, remoteId: 'm', slides: 2);
      final item = (await h.content.getById(id))!;
      h.gallery.simulateMissing(item.media.first.contentUri!);
      final r = await h.deleteContent([id]);
      expect(r.deletedContentIds, [id]);
      expect(r.filesDeleted, 1);
      expect(r.filesMissing, 1);
      expect(h.gallery.files, isEmpty);
    });

    test('multi-slide: slide 0 deleted then slide 1 fails: row kept; retry '
        'finishes', () async {
      final id = await h.addContent(t, remoteId: 'm', slides: 3);
      final item = (await h.content.getById(id))!;
      final dc = DeleteContent(
        content: h.content,
        gallery: _FailSecond(h.gallery, item.media[1].contentUri!),
        cache: h.cache,
      );
      final r1 = await dc([id]);
      expect(r1.failures, hasLength(1));
      expect(await h.content.getById(id), isNotNull);
      // slides 0 and 2 were still attempted
      expect(h.gallery.files, hasLength(1));
      final r2 = await h.deleteContent([id]);
      expect(r2.deletedContentIds, [id]);
      expect(h.gallery.files, isEmpty);
    });

    test(
      'GalleryStorageFull on delete is reported and keeps the row',
      () async {
        final id = await h.addContent(t, remoteId: 's');
        h.gallery.failNextDelete(const GalleryStorageFull());
        final r = await h.deleteContent([id]);
        expect(r.failures.single.error, isA<GalleryStorageFull>());
        expect(await h.content.getById(id), isNotNull);
      },
    );
  });

  group('RemoveTarget races (finding F4)', () {
    test('F4 fixed: content added while delete-media runs is deleted too, '
        'then the target goes', () async {
      final a = await h.addContent(t, remoteId: 'a');
      final hook = HookGallery(h.spy, () async {
        await h.addContent(t, remoteId: 'late-arrival');
      });
      final rt = RemoveTarget(
        targets: h.targets,
        content: h.content,
        deleteContent: DeleteContent(
          content: h.content,
          gallery: hook,
          cache: h.cache,
        ),
      );
      final r = await rt(t.id, deleteMedia: true);
      expect(r.targetRemoved, isTrue);
      expect(await h.content.getById(a), isNull);
      expect(h.gallery.files, isEmpty);
      expect(await h.targets.getById(t.id), isNull);
    });

    test('F4: a target that keeps receiving content stops after maxPasses '
        'and is kept', () async {
      await h.addContent(t, remoteId: 'a');
      var n = 0;
      late final HookGallery hook;
      Future<void> arrive() async {
        await h.addContent(t, remoteId: 'late-${n++}');
        hook.onDelete = arrive;
      }

      hook = HookGallery(h.spy, arrive);
      final rt = RemoveTarget(
        targets: h.targets,
        content: h.content,
        deleteContent: DeleteContent(
          content: h.content,
          gallery: hook,
          cache: h.cache,
        ),
      );
      final r = await rt(t.id, deleteMedia: true);
      expect(r.targetRemoved, isFalse);
      expect(r.isComplete, isFalse);
      expect(await h.targets.getById(t.id), isNotNull);
      expect(n, RemoveTarget.maxPasses);
      // A re-run once the stream of new content stops finishes the job.
      hook.onDelete = null;
      final again = await rt(t.id, deleteMedia: true);
      expect(again.targetRemoved, isTrue);
      expect(h.gallery.files, isEmpty);
    });

    test('F4: a failed item is not retried within one call', () async {
      await h.addContent(t, remoteId: 'bad');
      await h.addContent(t, remoteId: 'ok');
      h.gallery.failNextDelete(const GalleryPermissionDenied());
      final r = await h.removeTarget(t.id, deleteMedia: true);
      expect(r.targetRemoved, isFalse);
      expect(r.deletion!.failures, hasLength(1));
      expect(
        await h.content.getById(r.deletion!.failures.single.contentId),
        isNotNull,
      );
      expect(r.deletion!.deletedContentIds, hasLength(1));
    });

    test('keep media: activity-less cascade removes rows, files stay, other '
        'targets untouched', () async {
      final other = await h.addTarget(remoteUserId: '200', name: 'b');
      await h.addContent(t, remoteId: 'a');
      final o = await h.addContent(other, remoteId: 'b');
      await h.removeTarget(t.id, deleteMedia: false);
      expect(h.gallery.files, hasLength(2));
      expect(await h.content.getById(o), isNotNull);
      expect(await h.content.listByTarget(t.id), isEmpty);
    });
  });

  group('retention extras', () {
    test('CHARACTERIZATION: a pending (not yet downloaded) old item is '
        'deleted without a file', () async {
      await h.settings.update((s) => s.copyWith(retentionDays: 7));
      final id = await h.addContent(
        t,
        remoteId: 'p',
        withFiles: false,
        postedAt: now.subtract(const Duration(days: 30)),
      );
      final r = await h.retention();
      expect(r.deletion!.deletedContentIds, [id]);
    });

    test(
      'expiresAt in the past or future never affects retention (BR-4)',
      () async {
        await h.settings.update((s) => s.copyWith(retentionDays: 7));
        final keep = await h.addContent(
          t,
          remoteId: 'k',
          postedAt: now.subtract(const Duration(days: 1)),
          expiresAt: now.subtract(const Duration(days: 100)),
        );
        await h.retention();
        expect(await h.content.getById(keep), isNotNull);
      },
    );
  });

  group('results leak nothing (finding F6)', () {
    test(
      'toString of every result has no URI, file name or username',
      () async {
        await h.settings.update((s) => s.copyWith(retentionDays: 7));
        final tt = await h.addTarget(remoteUserId: '777', name: 'zorblax');
        final id = await h.addContent(
          tt,
          remoteId: 'secretname',
          postedAt: now.subtract(const Duration(days: 30)),
        );
        final uri = (await h.content.getById(id))!.media.single.contentUri!;
        h.gallery.failNextDelete(const GalleryPermissionDenied());
        final d = await h.deleteContent([id, 999]);
        final rt = await h.removeTarget(tt.id, deleteMedia: true);
        final ret = await h.retention();
        for (final s in [
          d.toString(),
          d.failures.single.toString(),
          rt.toString(),
          ret.toString(),
        ]) {
          expect(s, isNot(contains(uri)));
          expect(s, isNot(contains('content://')));
          expect(s, isNot(contains('secretname')));
          expect(s, isNot(contains('zorblax')));
          expect(s, isNot(contains('Pictures')));
        }
      },
    );
  });
}

final class _FailSecond implements GalleryStore {
  _FailSecond(this.inner, this.failUri);

  final FakeGalleryStore inner;
  final String failUri;
  bool failed = false;

  @override
  Future<bool> delete(String contentUri) async {
    if (contentUri == failUri && !failed) {
      failed = true;
      throw const GalleryWriteFailed('IO_ERROR');
    }
    return inner.delete(contentUri);
  }

  @override
  Future<bool> exists(String u) => inner.exists(u);

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
    StorageTarget target = StorageTarget.gallery,
  }) => inner.save(
    sourcePath: sourcePath,
    relativeDir: relativeDir,
    displayName: displayName,
    mime: mime,
  );

  @override
  Future<int?> size(String u) => inner.size(u);

  @override
  Future<GalleryFile> copyTo(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => throw UnimplementedError();

  @override
  Future<GalleryFile> move(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => throw UnimplementedError();
}
