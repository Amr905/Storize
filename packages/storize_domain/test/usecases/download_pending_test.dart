import 'package:storize_domain/src/usecases/download_pending.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

/// Models a process kill: an `Error`, so the use case does not catch it.
final class Crash extends Error {}

String dn({
  required String username,
  required DateTime postedAt,
  required String remoteId,
  required String ext,
  int? slideIndex,
}) => '${username}_$remoteId${slideIndex == null ? '' : '_$slideIndex'}.$ext';

String relDir(String username) => 'Pictures/Storize/$username';

/// A gallery with hooks around `save`.
final class HookGallery implements GalleryStore {
  HookGallery(this.inner);

  final FakeGalleryStore inner;
  Future<void> Function()? beforeSave;
  Future<void> Function()? afterSave;
  int saveCalls = 0;

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) async {
    saveCalls++;
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
  Future<bool> delete(String contentUri) => inner.delete(contentUri);

  @override
  Future<bool> exists(String contentUri) => inner.exists(contentUri);

  @override
  Future<int?> size(String contentUri) => inner.size(contentUri);
}

/// A cache whose `discard` can crash.
final class HookCache implements MediaCache {
  HookCache(this.inner);

  final FakeMediaCache inner;
  bool crashOnDiscard = false;

  @override
  Future<void> discard(int mediaFileId) async {
    if (crashOnDiscard) throw Crash();
    await inner.discard(mediaFileId);
  }

  @override
  Future<void> append(int mediaFileId, Stream<List<int>> bytes) =>
      inner.append(mediaFileId, bytes);

  @override
  Future<int> cleanupOrphans(Set<int> pendingIds) =>
      inner.cleanupOrphans(pendingIds);

  @override
  Future<int> cleanupOrphanThumbnails(Set<int> liveMediaIds) =>
      inner.cleanupOrphanThumbnails(liveMediaIds);

  @override
  Future<String> completedPath(int mediaFileId) =>
      inner.completedPath(mediaFileId);

  @override
  Future<int> partialLength(int mediaFileId) =>
      inner.partialLength(mediaFileId);

  @override
  Future<String> writeThumbnail(int mediaFileId, List<int> webpBytes) =>
      inner.writeThumbnail(mediaFileId, webpBytes);

  @override
  Future<void> deleteThumbnail(int mediaFileId) =>
      inner.deleteThumbnail(mediaFileId);
}

final class ThrowingStorage implements StorageInfo {
  @override
  Future<int> freeBytes() async => throw StateError('unknown');

  @override
  Future<int> totalBytes() async => throw StateError('unknown');
}

void main() {
  late FakeClock clock;
  late FakeTargetRepo targets;
  late FakeContentRepo content;
  late FakeActivityRepo activity;
  late FakeContentPlatform platform;
  late FakeMediaCache cache;
  late FakeGalleryStore fakeGallery;
  late HookGallery gallery;
  late HookCache hookCache;
  late FakeStorageInfo storage;
  late Target alice;

  DownloadPending build({
    StorageInfo? storageInfo,
    bool withFinder = false,
    Duration budget = const Duration(minutes: 8),
  }) => DownloadPending(
    content: content,
    targets: targets,
    activity: activity,
    platform: platform,
    cache: hookCache,
    gallery: gallery,
    storage: storageInfo ?? storage,
    clock: clock,
    displayName: dn,
    relativeDir: relDir,
    budget: budget,
    findExisting: withFinder
        ? ({required relativeDir, required displayName}) async {
            for (final f in fakeGallery.files) {
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
    hookCache = HookCache(cache);
    fakeGallery = FakeGalleryStore(cache: cache);
    gallery = HookGallery(fakeGallery);
    storage = FakeStorageInfo();
    alice = await targets.insert(s.target());
  });

  Future<int> seed(
    Target t, {
    String remoteId = 's1',
    ContentKind kind = ContentKind.story,
    int slides = 1,
    Map<String, Object?> extras = const {},
    int attempts = 0,
    MediaFileStatus status = MediaFileStatus.pending,
  }) async {
    final c = s
        .content(targetId: t.id, remoteId: remoteId, kind: kind)
        .copyWith(slideCount: slides, extras: extras);
    final r = await content.insertIfNew(c, [
      for (var i = 0; i < slides; i++)
        s.media(slideIndex: i, status: status).copyWith(attempts: attempts),
    ]);
    return r.contentId;
  }

  Future<List<MediaFile>> filesOf(int id) async =>
      (await content.getById(id))!.media;
  Future<ContentStatus> statusOf(int id) async =>
      (await content.getById(id))!.content.status;
  Future<List<ActivityEvent>> events(ActivityType type) =>
      activity.watchRecent(types: {type}).first;

  List<int> bytes(int n) => List<int>.filled(n, 7);

  RemoteContent remoteStory(String id, {int slides = 1, String u = 'new'}) =>
      RemoteContent(
        remoteId: id,
        kind: ContentKind.story,
        postedAt: s.t0,
        slides: [
          for (var i = 0; i < slides; i++)
            RemoteMedia(
              index: i,
              type: MediaType.photo,
              url: 'https://example.invalid/$u/$i',
              width: 1,
              height: 1,
            ),
        ],
      );

  group('AC1 batch loop', () {
    test('processes every PENDING file, stories before posts', () async {
      final post = await seed(alice, remoteId: 'p1', kind: ContentKind.post);
      final st = await seed(alice);
      platform
        ..queueMedia(bytes(5))
        ..queueMedia(bytes(5));
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.completed);
      expect(r.remaining, 0);
      expect(r.totalFiles, 2);
      expect(platform.callsTo('openMedia'), hasLength(2));
      expect((await filesOf(st)).single.status, MediaFileStatus.done);
      expect((await filesOf(post)).single.status, MediaFileStatus.done);
      expect(fakeGallery.files.first.displayName, startsWith('alice_s1'));
    });

    test('returns remaining at the deadline', () async {
      for (var i = 0; i < 3; i++) {
        await seed(alice, remoteId: 's$i');
        platform.queueMedia(bytes(3));
      }
      gallery.afterSave = () async => clock.advance(const Duration(minutes: 5));
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.deadline);
      expect(r.totalFiles, 2);
      expect(r.remaining, 1);
    });

    test('an explicit deadline overrides the budget', () async {
      await seed(alice);
      final r = await build().run(deadline: s.t0);
      expect(r.stopReason, DownloadStopReason.deadline);
      expect(r.remaining, 1);
      expect(platform.callsTo('openMedia'), isEmpty);
    });

    test('nothing to do is completed with no events', () async {
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.completed);
      expect(r.remaining, 0);
      expect(await activity.watchRecent().first, isEmpty);
    });

    test('a second concurrent run does nothing', () async {
      await seed(alice);
      platform.queueMedia(bytes(5));
      final uc = build();
      final first = uc.run();
      final second = await uc.run();
      expect(second.stopReason, DownloadStopReason.alreadyRunning);
      expect((await first).totalFiles, 1);
      expect(platform.callsTo('openMedia'), hasLength(1));
    });
  });

  group('AC2 stream and save', () {
    test('saves bytes and records uri, size and display name', () async {
      final id = await seed(alice);
      platform.queueMedia(bytes(10), chunkSize: 3);
      await build().run();
      final f = (await filesOf(id)).single;
      expect(f.status, MediaFileStatus.done);
      expect(f.contentUri, startsWith('content://'));
      expect(f.sizeBytes, 10);
      expect(f.displayName, 'alice_s1.jpg');
      expect(f.relativePath, 'Pictures/Storize/alice');
      expect(f.downloadedAt, s.t0);
      expect(await statusOf(id), ContentStatus.done);
      expect(cache.partIds, isEmpty);
    });

    test('resumes with Range from the bytes already cached', () async {
      final id = await seed(alice);
      final fileId = (await filesOf(id)).single.id;
      await cache.append(fileId, Stream.value(bytes(4)));
      platform.queueMedia(bytes(10));
      await build().run();
      expect(platform.callsTo('openMedia').single.args[1], 4);
      expect((await filesOf(id)).single.sizeBytes, 10);
    });

    test('saves under the CURRENT username', () async {
      await seed(alice);
      await targets.update(alice.copyWith(username: 'alice_new'));
      platform.queueMedia(bytes(5));
      await build().run();
      expect(
        fakeGallery.files.single.relativePath,
        'Pictures/Storize/alice_new',
      );
      expect(fakeGallery.files.single.displayName, startsWith('alice_new_'));
    });

    test('post slides carry the slide index; video is mp4', () async {
      final c = s
          .content(targetId: alice.id, remoteId: 'p', kind: ContentKind.post)
          .copyWith(slideCount: 2);
      await content.insertIfNew(c, [
        s.media(),
        s.media(slideIndex: 1, type: MediaType.video),
      ]);
      platform
        ..queueMedia(bytes(2))
        ..queueMedia(bytes(2));
      await build().run();
      expect(
        fakeGallery.files.map((f) => f.displayName),
        ['alice_p_0.jpg', 'alice_p_1.mp4'],
      );
    });

    test('an empty download is a failed attempt, not a saved file', () async {
      final id = await seed(alice);
      platform.queueMedia(const []);
      final r = await build().run();
      expect(fakeGallery.files, isEmpty);
      expect(r.failures.single.code, 'empty_file');
      expect((await filesOf(id)).single.attempts, 1);
    });

    test('a 416 on a resume means the .part is already complete', () async {
      final id = await seed(alice);
      final fileId = (await filesOf(id)).single.id;
      await cache.append(fileId, Stream.value(bytes(6)));
      platform.queueMediaError(const MediaStreamFailure(statusCode: 416));
      await build().run();
      expect((await filesOf(id)).single.status, MediaFileStatus.done);
      expect(fakeGallery.files.single.sizeBytes, 6);
    });
  });

  group('AC3 expired URL', () {
    test('refreshes once through the platform, then resumes', () async {
      final id = await seed(alice);
      platform
        ..queueMediaError(
          const ExpiredMediaUrl(),
          bytesBeforeError: bytes(3),
        )
        ..queueMedia(bytes(10))
        ..fetchStoriesResults.addOk({
          alice.remoteUserId: [remoteStory('s1')],
        });
      final r = await build().run();
      expect(platform.callsTo('fetchStories'), hasLength(1));
      expect(platform.callsTo('openMedia').map((c) => c.args[1]), [0, 3]);
      expect(platform.callsTo('openMedia').last.args[0], contains('/new/0'));
      final f = (await filesOf(id)).single;
      expect(f.status, MediaFileStatus.done);
      expect(f.sourceUrl, contains('/new/0'));
      expect(f.attempts, 0);
      expect(r.failures, isEmpty);
    });

    test('a post is refreshed with fetchNewPosts', () async {
      await seed(alice, remoteId: 'p1', kind: ContentKind.post);
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..queueMedia(bytes(4))
        ..fetchNewPostsResults.addOk([
          RemoteContent(
            remoteId: 'p1',
            kind: ContentKind.post,
            postedAt: s.t0,
            slides: const [
              RemoteMedia(
                index: 0,
                type: MediaType.photo,
                url: 'https://example.invalid/fresh',
                width: 1,
                height: 1,
              ),
            ],
          ),
        ]);
      await build().run();
      expect(platform.callsTo('fetchNewPosts'), hasLength(1));
      expect(platform.callsTo('fetchStories'), isEmpty);
      expect(fakeGallery.files, hasLength(1));
    });

    test('a second expiry is a failed attempt', () async {
      final id = await seed(alice);
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchStoriesResults.addOk({
          alice.remoteUserId: [remoteStory('s1')],
        });
      final r = await build().run();
      expect(platform.callsTo('fetchStories'), hasLength(1));
      final f = (await filesOf(id)).single;
      expect(f.status, MediaFileStatus.pending);
      expect(f.attempts, 1);
      expect(r.failures.single.code, 'url_expired');
      expect(r.remaining, 1);
      // The failed item is not retried inside the same run.
      expect(platform.callsTo('openMedia'), hasLength(2));
    });

    test('a failed refresh costs an attempt', () async {
      final id = await seed(alice);
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchStoriesResults.addFailure(const NetworkFailure());
      final r = await build().run();
      expect(r.failures.single.code, 'refresh_network');
      expect((await filesOf(id)).single.attempts, 1);
    });

    test('a session problem during refresh stops without charging', () async {
      final a = await seed(alice);
      await seed(alice, remoteId: 's2');
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchStoriesResults.addFailure(
          const SessionInvalid(SessionReason.loginRequired),
        );
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.sessionProblem);
      expect(r.remaining, 2);
      final f = (await filesOf(a)).single;
      expect(f.status, MediaFileStatus.pending);
      expect(f.attempts, 0);
      expect(platform.callsTo('openMedia'), hasLength(1));
    });

    test('a rate limit during refresh stops the run', () async {
      await seed(alice);
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchStoriesResults.addFailure(const RateLimited(null));
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.rateLimited);
    });
  });

  group('AC4 attempts and partial posts', () {
    test('a failed attempt is recorded and the .part is kept', () async {
      final id = await seed(alice);
      platform.queueMediaError(
        const MediaStreamFailure(statusCode: 500),
        bytesBeforeError: bytes(2),
      );
      final r = await build().run();
      final f = (await filesOf(id)).single;
      expect(f.attempts, 1);
      expect(f.status, MediaFileStatus.pending);
      expect(r.failures.single.code, 'http_500');
      expect(r.failures.single.isFinal, isFalse);
      expect(cache.partBytes(f.id), hasLength(2));
    });

    test('a network error without a status is coded network', () async {
      await seed(alice);
      platform.queueMediaError(const MediaStreamFailure());
      expect((await build().run()).failures.single.code, 'network');
    });

    test('the 5th failed attempt makes the file FAILED', () async {
      final id = await seed(alice, attempts: 4);
      platform.queueMediaError(const MediaStreamFailure(statusCode: 500));
      final r = await build().run();
      final f = (await filesOf(id)).single;
      expect(f.status, MediaFileStatus.failed);
      expect(f.attempts, 5);
      expect(r.failures.single.isFinal, isTrue);
      expect(r.remaining, 0);
      expect(cache.partIds, isEmpty);
      expect(r.counts.single.failed, 1);
    });

    test('a carousel with a FAILED slide becomes PARTIAL (EC-21)', () async {
      final id = await seed(
        alice,
        remoteId: 'p1',
        kind: ContentKind.post,
        slides: 2,
      );
      final slide1 = (await filesOf(id))[1];
      await content.updateMediaFile(slide1.copyWith(attempts: 4));
      platform
        ..queueMedia(bytes(3))
        ..queueMediaError(const MediaStreamFailure(statusCode: 500));
      await build().run();
      final files = await filesOf(id);
      expect(files[0].status, MediaFileStatus.done);
      expect(files[1].status, MediaFileStatus.failed);
      expect(await statusOf(id), ContentStatus.partial);
      expect(fakeGallery.files, hasLength(1));
    });

    test('content stays pending while a slide is still open', () async {
      final id = await seed(
        alice,
        remoteId: 'p1',
        kind: ContentKind.post,
        slides: 2,
      );
      platform
        ..queueMedia(bytes(3))
        ..queueMediaError(const MediaStreamFailure(statusCode: 500));
      await build().run();
      expect(await statusOf(id), ContentStatus.pending);
    });

    test('a retry in a later run succeeds and completes the post', () async {
      final id = await seed(
        alice,
        remoteId: 'p1',
        kind: ContentKind.post,
        slides: 2,
      );
      platform
        ..queueMedia(bytes(3))
        ..queueMediaError(const MediaStreamFailure(statusCode: 500))
        ..queueMedia(bytes(3));
      await build().run();
      await build().run();
      expect(await statusOf(id), ContentStatus.done);
      expect((await filesOf(id))[1].attempts, 1);
    });

    test(
      'extras[unsupported_stream] keeps the post from becoming DONE',
      () async {
        final id = await seed(
          alice,
          remoteId: 'p1',
          kind: ContentKind.post,
          extras: {
            DownloadPending.unsupportedStreamKey: [1],
          },
        );
        platform.queueMedia(bytes(3));
        await build().run();
        expect(await statusOf(id), ContentStatus.partial);
      },
    );

    test('an empty unsupported_stream list does not matter', () async {
      final id = await seed(
        alice,
        extras: {DownloadPending.unsupportedStreamKey: <int>[]},
      );
      platform.queueMedia(bytes(3));
      await build().run();
      expect(await statusOf(id), ContentStatus.done);
    });
  });

  group('AC5 gone remotely', () {
    test('a story missing at refresh is REMOVED_BEFORE_DOWNLOAD', () async {
      final id = await seed(alice);
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchStoriesResults.addOk({alice.remoteUserId: <RemoteContent>[]});
      final r = await build().run();
      expect(await statusOf(id), ContentStatus.removedBeforeDownload);
      expect((await filesOf(id)).single.status, MediaFileStatus.failed);
      expect(r.remaining, 0);
      expect(r.counts.single.removed, 1);
      expect(r.failures, isEmpty);
      final ev = await events(ActivityType.removedBeforeDownload);
      expect(ev.single.targetId, alice.id);
      expect(ev.single.severity, Severity.info);
      expect(ev.single.payload.values.join(), isNot(contains('http')));
    });

    test('a user with no entry in the map counts as gone', () async {
      final id = await seed(alice);
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchStoriesResults.addOk(<String, List<RemoteContent>>{});
      await build().run();
      expect(await statusOf(id), ContentStatus.removedBeforeDownload);
    });

    test('a removed post keeps slides that were saved (PARTIAL)', () async {
      final id = await seed(
        alice,
        remoteId: 'p1',
        kind: ContentKind.post,
        slides: 2,
      );
      platform
        ..queueMedia(bytes(3))
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchNewPostsResults.addOk(const <RemoteContent>[]);
      await build().run();
      final files = await filesOf(id);
      expect(files[0].status, MediaFileStatus.done);
      expect(files[1].status, MediaFileStatus.failed);
      expect(await statusOf(id), ContentStatus.partial);
    });

    test('a missing slide of a live post fails only that slide', () async {
      final id = await seed(
        alice,
        remoteId: 'p1',
        kind: ContentKind.post,
        slides: 2,
      );
      platform
        ..queueMedia(bytes(3))
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchNewPostsResults.addOk([
          RemoteContent(
            remoteId: 'p1',
            kind: ContentKind.post,
            postedAt: s.t0,
            slides: const [
              RemoteMedia(
                index: 0,
                type: MediaType.photo,
                url: 'https://example.invalid/x',
                width: 1,
                height: 1,
              ),
            ],
          ),
        ]);
      final r = await build().run();
      expect((await filesOf(id))[1].status, MediaFileStatus.failed);
      expect(await statusOf(id), ContentStatus.partial);
      expect(r.failures.single.code, 'removed');
      expect(await events(ActivityType.removedBeforeDownload), isEmpty);
    });
  });

  group('AC6 storage', () {
    test('under 1 GiB writes STORAGE_LOW once per run', () async {
      for (var i = 0; i < 3; i++) {
        await seed(alice, remoteId: 's$i');
        platform.queueMedia(bytes(3));
      }
      storage.free = 500 * 1024 * 1024;
      final r = await build().run();
      expect(r.totalFiles, 3);
      final ev = await events(ActivityType.storageLow);
      expect(ev, hasLength(1));
      expect(ev.single.severity, Severity.warn);
      expect(await events(ActivityType.storagePaused), isEmpty);
      // A new run writes it again.
      await seed(alice, remoteId: 'later');
      platform.queueMedia(bytes(3));
      await build().run();
      expect(await events(ActivityType.storageLow), hasLength(2));
    });

    test('exactly 1 GiB is not low', () async {
      await seed(alice);
      platform.queueMedia(bytes(3));
      storage.free = StoragePolicy.lowSpaceBytes;
      await build().run();
      expect(await events(ActivityType.storageLow), isEmpty);
    });

    test('under 200 MiB stops and writes STORAGE_PAUSED', () async {
      await seed(alice);
      storage.free = StoragePolicy.pauseBytes - 1;
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.storagePaused);
      expect(r.remaining, 1);
      expect(r.totalFiles, 0);
      expect(platform.callsTo('openMedia'), isEmpty);
      final ev = await events(ActivityType.storagePaused);
      expect(ev.single.severity, Severity.error);
      expect(ev.single.payload['reason'], 'low_space');
    });

    test('exactly 200 MiB continues (low only)', () async {
      await seed(alice);
      platform.queueMedia(bytes(3));
      storage.free = StoragePolicy.pauseBytes;
      final r = await build().run();
      expect(r.totalFiles, 1);
      expect(await events(ActivityType.storageLow), hasLength(1));
    });

    test('space dropping during the run stops it', () async {
      await seed(alice);
      await seed(alice, remoteId: 's2');
      platform.queueMedia(bytes(3));
      gallery.afterSave = () async => storage.free = 10;
      final r = await build().run();
      expect(r.totalFiles, 1);
      expect(r.stopReason, DownloadStopReason.storagePaused);
      expect(r.remaining, 1);
    });

    test('unknown free space (it throws) means continue', () async {
      await seed(alice);
      platform.queueMedia(bytes(3));
      final r = await build(storageInfo: ThrowingStorage()).run();
      expect(r.totalFiles, 1);
      expect(await events(ActivityType.storageLow), isEmpty);
      expect(await events(ActivityType.storagePaused), isEmpty);
    });

    test('a negative free value is treated as unknown', () async {
      await seed(alice);
      platform.queueMedia(bytes(3));
      storage.free = -1;
      expect((await build().run()).totalFiles, 1);
    });
  });

  group('AC7 counts', () {
    test('per target and kind, with one event each', () async {
      final bob = await targets.insert(
        s.target(remoteUserId: '200', username: 'bob'),
      );
      await seed(alice, remoteId: 'a1');
      await seed(alice, remoteId: 'a2');
      await seed(
        alice,
        remoteId: 'ap',
        kind: ContentKind.post,
        slides: 3,
      );
      await seed(bob, remoteId: 'b1');
      for (var i = 0; i < 6; i++) {
        platform.queueMedia(bytes(2));
      }
      final r = await build().run();
      DownloadCounts of(int t, ContentKind k) =>
          r.counts.singleWhere((c) => c.targetId == t && c.kind == k);
      expect(of(alice.id, ContentKind.story).files, 2);
      expect(of(alice.id, ContentKind.story).contents, 2);
      expect(of(alice.id, ContentKind.post).files, 3);
      expect(of(alice.id, ContentKind.post).contents, 1);
      expect(of(bob.id, ContentKind.story).files, 1);
      expect(r.counts, hasLength(3));
      final stories = await events(ActivityType.downloadedStories);
      expect(stories.map((e) => (e.targetId, e.count)).toSet(), {
        (alice.id, 2),
        (bob.id, 1),
      });
      final posts = await events(ActivityType.downloadedPosts);
      expect(posts.single.count, 1);
      expect(posts.single.payload['files'], 3);
    });

    test('a failure-only run writes no DOWNLOADED event', () async {
      await seed(alice);
      platform.queueMediaError(const MediaStreamFailure(statusCode: 500));
      await build().run();
      expect(await events(ActivityType.downloadedStories), isEmpty);
    });

    test('failures show up in the event payload', () async {
      await seed(alice, remoteId: 'p', kind: ContentKind.post, slides: 2);
      platform
        ..queueMedia(bytes(2))
        ..queueMediaError(const MediaStreamFailure(statusCode: 500));
      await build().run();
      final ev = (await events(ActivityType.downloadedPosts)).single;
      expect(ev.payload['failed'], 0);
      expect(ev.severity, Severity.info);
    });
  });

  group('AC8 kill safety (NFR-7)', () {
    late int id;
    late int fileId;
    const total = 20;

    setUp(() async {
      id = await seed(alice);
      fileId = (await filesOf(id)).single.id;
    });

    Future<void> expectClean({required int savedCalls}) async {
      final files = await filesOf(id);
      expect(files, hasLength(1), reason: 'no orphan or duplicate rows');
      expect(files.single.status, MediaFileStatus.done);
      expect(files.single.sizeBytes, total);
      expect(await statusOf(id), ContentStatus.done);
      expect(
        await content.listByTarget(alice.id),
        hasLength(1),
      );
      expect(fakeGallery.files, hasLength(1), reason: 'no duplicate gallery');
      expect(fakeGallery.files.single.uri, files.single.contentUri);
      expect(fakeGallery.saved, hasLength(savedCalls));
      expect(cache.partIds, isEmpty, reason: 'no leftover .part');
      expect(await content.pendingMedia(), isEmpty);
    }

    test('killed mid-stream: resumes from the partial bytes', () async {
      platform.queueMediaError(Crash(), bytesBeforeError: bytes(8));
      await expectLater(build().run(), throwsA(isA<Crash>()));
      expect(
        (await filesOf(id)).single.status,
        MediaFileStatus.downloading,
      );
      expect(cache.partBytes(fileId), hasLength(8));
      expect(fakeGallery.files, isEmpty);

      platform.queueMedia(bytes(total));
      final r = await build().run();
      expect(platform.callsTo('openMedia').last.args[1], 8);
      expect(r.totalFiles, 1);
      await expectClean(savedCalls: 1);
      expect((await filesOf(id)).single.attempts, 0, reason: 'kill is free');
    });

    test('killed after .part completed, before the save', () async {
      platform.queueMedia(bytes(total));
      gallery.beforeSave = () async => throw Crash();
      await expectLater(build().run(), throwsA(isA<Crash>()));
      expect(cache.partBytes(fileId), hasLength(total));
      expect(fakeGallery.files, isEmpty);

      gallery.beforeSave = null;
      platform.queueMedia(bytes(total)); // the resume asks from byte 20
      await build().run();
      expect(platform.callsTo('openMedia').last.args[1], total);
      await expectClean(savedCalls: 1);
    });

    test(
      'killed after the gallery save, before the row update: adopts',
      () async {
        platform.queueMedia(bytes(total));
        gallery.afterSave = () async => throw Crash();
        await expectLater(build().run(), throwsA(isA<Crash>()));
        expect(fakeGallery.files, hasLength(1));
        expect((await filesOf(id)).single.contentUri, isNull);

        gallery.afterSave = null;
        final r = await build(withFinder: true).run();
        expect(r.totalFiles, 1);
        expect(gallery.saveCalls, 1, reason: 'not saved a second time');
        expect(platform.callsTo('openMedia'), hasLength(1));
        await expectClean(savedCalls: 1);
      },
    );

    test('killed after the row update: nothing repeats', () async {
      platform.queueMedia(bytes(total));
      hookCache.crashOnDiscard = true;
      await expectLater(build().run(), throwsA(isA<Crash>()));
      expect((await filesOf(id)).single.status, MediaFileStatus.done);
      expect(cache.partIds, {fileId}, reason: 'stray .part before the re-run');

      hookCache.crashOnDiscard = false;
      final r = await build(withFinder: true).run();
      expect(r.totalFiles, 0);
      expect(gallery.saveCalls, 1);
      expect(platform.callsTo('openMedia'), hasLength(1));
      await expectClean(savedCalls: 1);
    });

    test('adopts an already recorded URI that still exists', () async {
      final saved = await fakeGallery.save(
        sourcePath: 'none',
        relativeDir: 'Pictures/Storize/alice',
        displayName: 'alice_s1.jpg',
        mime: 'image/jpeg',
      );
      final f = (await filesOf(id)).single;
      await content.updateMediaFile(f.copyWith(contentUri: saved.uri));
      final r = await build().run();
      expect(r.totalFiles, 1);
      expect(platform.callsTo('openMedia'), isEmpty);
      expect(fakeGallery.saved, hasLength(1));
      expect((await filesOf(id)).single.status, MediaFileStatus.done);
    });

    test('a recorded URI whose file is gone is downloaded again', () async {
      final f = (await filesOf(id)).single;
      await content.updateMediaFile(f.copyWith(contentUri: 'content://gone/1'));
      platform.queueMedia(bytes(total));
      await build().run();
      await expectClean(savedCalls: 1);
    });

    test('killed twice in a row still ends clean', () async {
      platform.queueMediaError(Crash(), bytesBeforeError: bytes(5));
      await expectLater(build().run(), throwsA(isA<Crash>()));
      platform.queueMediaError(Crash(), bytesBeforeError: bytes(10));
      await expectLater(build().run(), throwsA(isA<Crash>()));
      expect(cache.partBytes(fileId), hasLength(10));
      platform.queueMedia(bytes(total));
      await build().run();
      await expectClean(savedCalls: 1);
    });

    test('stray .part files of finished items are removed at start', () async {
      await cache.append(9999, Stream.value(bytes(3)));
      platform.queueMedia(bytes(total));
      await build().run();
      expect(cache.partIds, isNot(contains(9999)));
    });

    test('a content left PENDING after a kill is settled at start', () async {
      platform.queueMedia(bytes(total));
      await build().run();
      final c = (await content.getById(id))!.content;
      await content.updateContent(c.copyWith(status: ContentStatus.pending));
      await build().run();
      expect(await statusOf(id), ContentStatus.done);
    });

    test(
      'content with no slide rows and an unsupported marker is PARTIAL',
      () async {
        final r = await content.insertIfNew(
          s
              .content(
                targetId: alice.id,
                remoteId: 'dash',
                kind: ContentKind.post,
              )
              .copyWith(
                slideCount: 0,
                extras: {
                  DownloadPending.unsupportedStreamKey: [0],
                },
              ),
          const [],
        );
        platform.queueMedia(bytes(total));
        await build().run();
        expect(await statusOf(r.contentId), ContentStatus.partial);
      },
    );

    test('the user deleting the item while it saves leaves no file', () async {
      platform.queueMedia(bytes(total));
      gallery.afterSave = () async => content.deleteByIds([id]);
      final r = await build().run();
      expect(r.totalFiles, 0);
      expect(fakeGallery.files, isEmpty);
      expect(cache.partIds, isEmpty);
    });
  });

  group('AC9 gallery exceptions', () {
    test('permission denied stops the run and raises an event', () async {
      final a = await seed(alice);
      await seed(alice, remoteId: 's2');
      platform.queueMedia(bytes(3));
      fakeGallery.failNextSaveWithPermissionDenied();
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.permissionDenied);
      expect(r.remaining, 2);
      final f = (await filesOf(a)).single;
      expect(f.status, MediaFileStatus.pending);
      expect(f.attempts, 0);
      expect(platform.callsTo('openMedia'), hasLength(1));
      final ev = await events(ActivityType.storagePaused);
      expect(ev.single.payload['reason'], 'gallery_permission_denied');
      expect(ev.single.severity, Severity.error);
    });

    test('storage full writes STORAGE_PAUSED and stops', () async {
      await seed(alice);
      await seed(alice, remoteId: 's2');
      platform.queueMedia(bytes(3));
      fakeGallery.failNextSaveWithStorageFull();
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.galleryStorageFull);
      expect(r.remaining, 2);
      final ev = await events(ActivityType.storagePaused);
      expect(ev.single.payload['reason'], 'gallery_storage_full');
    });

    test('a write failure costs an attempt; the run goes on', () async {
      final a = await seed(alice);
      final b = await seed(alice, remoteId: 's2');
      platform
        ..queueMedia(bytes(3))
        ..queueMedia(bytes(3));
      fakeGallery.failNextSaveWithWriteFailed();
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.completed);
      expect(r.failures.single.code, 'gallery_IO_ERROR');
      final fa = (await filesOf(a)).single;
      expect(fa.status, MediaFileStatus.pending);
      expect(fa.attempts, 1);
      expect((await filesOf(b)).single.status, MediaFileStatus.done);
      expect(cache.partBytes(fa.id), isNull, reason: 'redownload next time');
    });

    test('five write failures end FAILED', () async {
      final a = await seed(alice, attempts: 4);
      platform.queueMedia(bytes(3));
      fakeGallery.failNextSaveWithWriteFailed();
      await build().run();
      expect((await filesOf(a)).single.status, MediaFileStatus.failed);
    });

    test('a gallery error while adopting also stops the run', () async {
      final id = await seed(alice);
      final f = (await filesOf(id)).single;
      await content.updateMediaFile(f.copyWith(contentUri: 'content://x/1'));
      fakeGallery.failNextExists(const GalleryPermissionDenied());
      final r = await build().run();
      expect(r.stopReason, DownloadStopReason.permissionDenied);
      expect((await filesOf(id)).single.status, MediaFileStatus.pending);
    });
  });

  group('safety', () {
    test('events and results never contain URLs', () async {
      await seed(alice);
      platform
        ..queueMediaError(const ExpiredMediaUrl())
        ..fetchStoriesResults.addOk({alice.remoteUserId: <RemoteContent>[]});
      final r = await build().run();
      final all = [
        r.toString(),
        r.failures.join(),
        ...(await activity.watchRecent().first).map(
          (e) => '$e${e.payload}',
        ),
      ].join();
      expect(all, isNot(contains('example.invalid')));
    });
  });
}
