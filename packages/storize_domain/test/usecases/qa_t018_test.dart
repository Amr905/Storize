// QA tests for T-018 (independent of the developer's suite).
import 'package:storize_domain/src/usecases/download_pending.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

final class Crash extends Error {}

String dn({
  required String username,
  required DateTime postedAt,
  required String remoteId,
  required String ext,
  int? slideIndex,
}) => '${username}_$remoteId${slideIndex == null ? '' : '_$slideIndex'}.$ext';

String relDir(String username) => 'Pictures/Storize/$username';

const int gb = 1024 * 1024 * 1024;
const int mb = 1024 * 1024;

/// Gallery with crash hooks.
final class Hooked implements GalleryStore {
  Hooked(this.inner);
  final FakeGalleryStore inner;
  Future<void> Function()? beforeSave;
  Future<void> Function()? afterSave;
  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) async {
    await beforeSave?.call();
    final f = await inner.save(
      sourcePath: sourcePath,
      relativeDir: relativeDir,
      displayName: displayName,
      mime: mime,
    );
    await afterSave?.call();
    return f;
  }

  @override
  Future<bool> delete(String u) => inner.delete(u);
  @override
  Future<bool> exists(String u) => inner.exists(u);
  @override
  Future<int?> size(String u) => inner.size(u);
}

final class CrashCache implements MediaCache {
  CrashCache(this.i);
  final FakeMediaCache i;
  bool crashDiscard = false;
  @override
  Future<void> discard(int id) async {
    if (crashDiscard) throw Crash();
    await i.discard(id);
  }

  @override
  Future<void> append(int id, Stream<List<int>> b) => i.append(id, b);
  @override
  Future<int> cleanupOrphans(Set<int> p) => i.cleanupOrphans(p);
  @override
  Future<int> cleanupOrphanThumbnails(Set<int> p) =>
      i.cleanupOrphanThumbnails(p);
  @override
  Future<String> completedPath(int id) => i.completedPath(id);
  @override
  Future<int> partialLength(int id) => i.partialLength(id);
  @override
  Future<String> writeThumbnail(int id, List<int> b) => i.writeThumbnail(id, b);
  @override
  Future<void> deleteThumbnail(int id) => i.deleteThumbnail(id);
}

final class Throwing implements StorageInfo {
  @override
  Future<int> freeBytes() async => throw StateError('x');
  @override
  Future<int> totalBytes() async => throw StateError('x');
}

void main() {
  late FakeClock clock;
  late FakeTargetRepo targets;
  late FakeContentRepo content;
  late FakeActivityRepo activity;
  late FakeContentPlatform platform;
  late FakeMediaCache cache;
  late CrashCache ccache;
  late FakeGalleryStore fgal;
  late Hooked gal;
  late FakeStorageInfo storage;
  late Target alice;

  DownloadPending build({
    StorageInfo? st,
    bool finder = true,
    DisplayNameBuilder? name,
  }) => DownloadPending(
    content: content,
    targets: targets,
    activity: activity,
    platform: platform,
    cache: ccache,
    gallery: gal,
    storage: st ?? storage,
    clock: clock,
    displayName: name ?? dn,
    relativeDir: relDir,
    findExisting: finder
        ? ({required relativeDir, required displayName}) async {
            for (final f in fgal.files) {
              if (f.relativePath == relativeDir &&
                  f.displayName == displayName) {
                return f;
              }
            }
            return null;
          }
        : null,
  );

  setUp(() async {
    clock = FakeClock(s.t0);
    targets = FakeTargetRepo();
    content = FakeContentRepo(targets: targets);
    activity = FakeActivityRepo(clock);
    platform = FakeContentPlatform();
    cache = FakeMediaCache();
    ccache = CrashCache(cache);
    fgal = FakeGalleryStore(cache: cache);
    gal = Hooked(fgal);
    storage = FakeStorageInfo();
    alice = await targets.insert(s.target());
  });

  Future<int> seed({
    String remoteId = 's1',
    ContentKind kind = ContentKind.story,
    int slides = 1,
    int attempts = 0,
    Target? t,
  }) async {
    final c = s
        .content(targetId: (t ?? alice).id, remoteId: remoteId, kind: kind)
        .copyWith(slideCount: slides);
    final r = await content.insertIfNew(c, [
      for (var i = 0; i < slides; i++)
        s.media(slideIndex: i).copyWith(attempts: attempts),
    ]);
    return r.contentId;
  }

  Future<List<MediaFile>> files(int id) async =>
      (await content.getById(id))!.media;
  Future<ContentStatus> status(int id) async =>
      (await content.getById(id))!.content.status;
  List<int> bytes(int n) => List<int>.filled(n, 7);

  RemoteContent remote(String id, {int slides = 1}) => RemoteContent(
    remoteId: id,
    kind: ContentKind.story,
    postedAt: s.t0,
    slides: [
      for (var i = 0; i < slides; i++)
        RemoteMedia(
          index: i,
          type: MediaType.photo,
          url: 'https://example.invalid/fresh/$i',
          width: 1,
          height: 1,
        ),
    ],
  );

  /// NFR-7 invariants after a clean re-run.
  Future<void> invariants(int id, {required int slides}) async {
    final fs = await files(id);
    expect(fs, hasLength(slides), reason: 'no orphan or lost rows');
    expect(fs.every((f) => f.status == MediaFileStatus.done), isTrue);
    final uris = fs.map((f) => f.contentUri).toList();
    expect(uris.toSet(), hasLength(slides), reason: 'distinct uris');
    expect(
      fgal.files.map((f) => f.uri).toSet(),
      uris.toSet(),
      reason: 'gallery == rows: no duplicate or untracked gallery files',
    );
    expect(cache.partIds, isEmpty);
    expect(await status(id), ContentStatus.done);
  }

  group('kill safety sweep (NFR-7), 2-slide post', () {
    for (final point in [
      'mid-stream',
      'before-save',
      'after-save',
      'after-done',
    ]) {
      test('crash $point then re-run ends clean', () async {
        final id = await seed(kind: ContentKind.post, slides: 2);
        platform
          ..queueMedia(bytes(10))
          ..queueMedia(bytes(10));
        switch (point) {
          case 'mid-stream':
            platform.queueMediaError(Crash(), bytesBeforeError: bytes(4));
          case 'before-save':
            gal.beforeSave = () async => throw Crash();
          case 'after-save':
            gal.afterSave = () async => throw Crash();
          case 'after-done':
            ccache.crashDiscard = true;
        }
        // mid-stream: replace the first script by the crashing one.
        if (point == 'mid-stream') {
          platform = FakeContentPlatform()
            ..queueMediaError(Crash(), bytesBeforeError: bytes(4));
        }
        await expectLater(build().run(), throwsA(isA<Crash>()));
        gal
          ..beforeSave = null
          ..afterSave = null;
        ccache.crashDiscard = false;
        platform
          ..queueMedia(bytes(10))
          ..queueMedia(bytes(10));
        final r = await build().run();
        expect(r.stopReason, DownloadStopReason.completed);
        await invariants(id, slides: 2);
        // A third run is a no-op.
        final again = await build().run();
        expect(again.totalFiles, 0);
        expect(fgal.files, hasLength(2));
      });
    }
  });

  test('adoption must not take a gallery file owned by another item', () async {
    // Two items whose display names collide (e.g. same remote id reused).
    String same({
      required String username,
      required DateTime postedAt,
      required String remoteId,
      required String ext,
      int? slideIndex,
    }) => 'collide.$ext';
    final a = await seed(remoteId: 'A');
    platform.queueMedia(bytes(10));
    await build(name: same).run();
    final aUri = (await files(a)).single.contentUri;
    expect(aUri, isNotNull);

    final b = await seed(remoteId: 'B');
    // B got killed after its .part was complete, before save.
    platform.queueMedia(bytes(10));
    gal.beforeSave = () async => throw Crash();
    await expectLater(build(name: same).run(), throwsA(isA<Crash>()));
    gal.beforeSave = null;
    platform.queueMedia(bytes(10));
    await build(name: same).run();
    final bUri = (await files(b)).single.contentUri;
    expect(
      bUri,
      isNot(aUri),
      reason: 'B adopted the file that belongs to A (shared URI)',
    );
  }, skip: 'QA-T018-F1: shared gallery URI, run with --run-skipped');

  test('adoption is skipped without a .part (fresh item, same name)', () async {
    await fgal.save(
      sourcePath: 'x',
      relativeDir: relDir('alice'),
      displayName: 'alice_s1.jpg',
      mime: 'image/jpeg',
    );
    final id = await seed();
    platform.queueMedia(bytes(10));
    await build().run();
    expect(platform.callsTo('openMedia'), hasLength(1));
    expect((await files(id)).single.status, MediaFileStatus.done);
  });

  group('expired URL refresh', () {
    test('expired twice: one refresh, no loop, one attempt charged', () async {
      final id = await seed();
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..queueMediaError(const ExpiredMediaUrl());
      platform.fetchStoriesResults.addOk({
        alice.remoteUserId: [remote('s1')],
      });
      final r = await build().run();
      expect(platform.callsTo('fetchStories'), hasLength(1));
      expect(platform.callsTo('openMedia'), hasLength(2));
      final f = (await files(id)).single;
      expect(f.attempts, 1);
      expect(f.status, MediaFileStatus.pending);
      expect(r.failures.single.code, 'url_expired');
    });

    test('refresh then success persists the new URL', () async {
      final id = await seed();
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..queueMedia(bytes(5));
      platform.fetchStoriesResults.addOk({
        alice.remoteUserId: [remote('s1')],
      });
      await build().run();
      final f = (await files(id)).single;
      expect(f.status, MediaFileStatus.done);
      expect(f.sourceUrl, 'https://example.invalid/fresh/0');
      expect(f.attempts, 0);
    });
  });

  group('attempts', () {
    test(
      '4th failure stays PENDING, 5th becomes FAILED, content PARTIAL',
      () async {
        final id = await seed(attempts: 3);
        platform.queueMediaError(const MediaStreamFailure(statusCode: 500));
        await build().run();
        var f = (await files(id)).single;
        expect((f.attempts, f.status), (4, MediaFileStatus.pending));
        platform.queueMediaError(const MediaStreamFailure(statusCode: 500));
        final r = await build().run();
        f = (await files(id)).single;
        expect((f.attempts, f.status), (5, MediaFileStatus.failed));
        expect(r.failures.single.isFinal, isTrue);
        expect(await status(id), ContentStatus.partial);
        expect(cache.partIds, isEmpty);
      },
    );

    test('post with 1 of 3 slides failing is PARTIAL, others kept', () async {
      final id = await seed(kind: ContentKind.post, slides: 3);
      final fs = await files(id);
      await content.updateMediaFile(fs[1].copyWith(attempts: 4));
      platform
        ..queueMedia(bytes(5))
        ..queueMediaError(const MediaStreamFailure(statusCode: 404))
        ..queueMedia(bytes(5));
      final r = await build().run();
      final after = await files(id);
      expect(after.map((f) => f.status), [
        MediaFileStatus.done,
        MediaFileStatus.failed,
        MediaFileStatus.done,
      ]);
      expect(await status(id), ContentStatus.partial);
      expect(r.counts.single.failed, 1);
    });
  });

  group('storage thresholds', () {
    Future<DownloadPendingResult> runWith(int free) async {
      storage.free = free;
      await seed();
      platform.queueMedia(bytes(5));
      return build().run();
    }

    Future<int> count(ActivityType t) async =>
        (await activity.watchRecent(types: {t}).first).length;

    test('exactly 1 GB: no event', () async {
      final r = await runWith(gb);
      expect(r.totalFiles, 1);
      expect(await count(ActivityType.storageLow), 0);
    });

    test('1 GB - 1: STORAGE_LOW, continues', () async {
      final r = await runWith(gb - 1);
      expect(r.totalFiles, 1);
      expect(await count(ActivityType.storageLow), 1);
      expect(await count(ActivityType.storagePaused), 0);
    });

    test('exactly 200 MB: LOW but continues', () async {
      final r = await runWith(200 * mb);
      expect(r.totalFiles, 1);
      expect(await count(ActivityType.storageLow), 1);
      expect(await count(ActivityType.storagePaused), 0);
    });

    test('200 MB - 1: paused, nothing downloaded', () async {
      final r = await runWith(200 * mb - 1);
      expect(r.stopReason, DownloadStopReason.storagePaused);
      expect(r.remaining, 1);
      expect(platform.callsTo('openMedia'), isEmpty);
      expect(await count(ActivityType.storagePaused), 1);
    });

    test('StorageInfo throwing: continues', () async {
      await seed();
      platform.queueMedia(bytes(5));
      final r = await build(st: Throwing()).run();
      expect(r.totalFiles, 1);
      expect(await count(ActivityType.storageLow), 0);
    });

    test('STORAGE_LOW recorded once per run over 3 items', () async {
      storage.free = 500 * mb;
      for (var i = 0; i < 3; i++) {
        await seed(remoteId: 's$i');
        platform.queueMedia(bytes(5));
      }
      final r = await build().run();
      expect(r.totalFiles, 3);
      expect(await count(ActivityType.storageLow), 1);
    });
  });

  group('deadline', () {
    test(
      'passing mid-item: item finishes, next is not started, remaining ok',
      () async {
        for (var i = 0; i < 3; i++) {
          await seed(remoteId: 's$i');
          platform.queueMedia(bytes(5));
        }
        gal.beforeSave = () async => clock.advance(const Duration(minutes: 9));
        final r = await build().run();
        expect(r.stopReason, DownloadStopReason.deadline);
        expect(r.totalFiles, 1);
        expect(r.remaining, 2);
        expect(platform.callsTo('openMedia'), hasLength(1));
      },
    );
  });

  test('files go to the renamed username folder, not the old one', () async {
    await seed();
    await targets.update(alice.copyWith(username: 'alice2'));
    platform.queueMedia(bytes(5));
    await build().run();
    expect(fgal.files.single.relativePath, relDir('alice2'));
    expect(fgal.files.single.displayName, startsWith('alice2_'));
  });

  test('no URL in events or result text', () async {
    await seed();
    platform
      ..queueMediaError(const ExpiredMediaUrl())
      ..queueMediaError(const ExpiredMediaUrl());
    platform.fetchStoriesResults.addOk({
      alice.remoteUserId: [remote('s1')],
    });
    final r = await build().run();
    final all = [
      r.toString(),
      ...r.failures.map((f) => f.toString()),
      ...r.counts.map((c) => c.toString()),
      for (final e in await activity.watchRecent().first)
        '${e.payload} ${e.type}',
    ].join(' ');
    expect(all, isNot(contains('example.invalid')));
    expect(all, isNot(contains('http')));
  });

  test('two DownloadPending instances never append the same .part', () async {
    await seed();
    platform
      ..queueMedia(bytes(10))
      ..queueMedia(bytes(10));
    await Future.wait([build().run(), build().run()]);
    expect(
      platform.callsTo('openMedia'),
      hasLength(1),
      reason: 'second instance re-downloaded the same media id',
    );
    expect(fgal.saved, hasLength(1), reason: 'duplicate gallery entry');
  }, skip: 'QA-T018-F2: no cross-instance lock, run with --run-skipped');
}
