import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;
import '../usecases/harness.dart';

/// Cache that runs [onAppend] once the first chunk of a download is written.
final class MidStreamCache implements MediaCache {
  MidStreamCache(this.inner);
  final FakeMediaCache inner;
  Future<void> Function()? onAppend;

  @override
  Future<void> append(int id, Stream<List<int>> bytes) => inner.append(
    id,
    bytes.asyncMap((c) async {
      final f = onAppend;
      onAppend = null;
      if (f != null) await f();
      return c;
    }),
  );
  @override
  Future<void> discard(int id) => inner.discard(id);
  @override
  Future<int> cleanupOrphans(Set<int> ids) => inner.cleanupOrphans(ids);
  @override
  Future<int> cleanupOrphanThumbnails(Set<int> ids) =>
      inner.cleanupOrphanThumbnails(ids);
  @override
  Future<String> completedPath(int id) => inner.completedPath(id);
  @override
  Future<int> partialLength(int id) => inner.partialLength(id);
  @override
  Future<String> writeThumbnail(int id, List<int> b) =>
      inner.writeThumbnail(id, b);
  @override
  Future<void> deleteThumbnail(int id) => inner.deleteThumbnail(id);
}

void main() {
  group('RemoveMediaFile (QA)', () {
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

    test('carousel: only that file and thumbnail go; others stay', () async {
      final id = await h.addContent(t, remoteId: 'c', slides: 3);
      final m = (await h.content.getById(id))!.media;
      for (final f in m) {
        await h.cache.writeThumbnail(f.id, [1]);
      }
      final r = await remove(id, m[1].id);
      expect(r.removed, isTrue);
      expect(r.contentDeleted, isFalse);
      final left = (await h.content.getById(id))!.media;
      expect(left.map((e) => e.id), [m[0].id, m[2].id]);
      expect(h.gallery.files.map((f) => f.uri), [
        m[0].contentUri,
        m[2].contentUri,
      ]);
      expect(h.cache.thumbnailBytes(m[1].id), isNull);
      expect(h.cache.thumbnailBytes(m[0].id), isNotNull);
      expect(h.cache.thumbnailBytes(m[2].id), isNotNull);
    });

    test('removing slides one by one ends with the content row gone', () async {
      final id = await h.addContent(t, remoteId: 'c', slides: 2);
      final m = (await h.content.getById(id))!.media;
      expect((await remove(id, m[0].id)).contentDeleted, isFalse);
      expect((await remove(id, m[1].id)).contentDeleted, isTrue);
      expect(await h.content.getById(id), isNull);
      expect(h.gallery.files, isEmpty);
    });

    test('failed gallery delete keeps row AND thumbnail, no path', () async {
      final id = await h.addContent(t, remoteId: 'c', slides: 2);
      final f = (await h.content.getById(id))!.media.first;
      await h.cache.writeThumbnail(f.id, [1]);
      h.gallery.failNextDelete(const GalleryWriteFailed('io'));
      final r = await remove(id, f.id);
      expect(r.removed, isFalse);
      expect(r.error, isNotNull);
      expect(r.toString(), isNot(contains('content://')));
      expect(h.cache.thumbnailBytes(f.id), isNotNull);
      expect((await h.content.getById(id))!.media, hasLength(2));
      // Retry after the failure succeeds.
      expect((await remove(id, f.id)).removed, isTrue);
    });

    test('removing twice: second is notFound, no throw', () async {
      final id = await h.addContent(t, remoteId: 'c', slides: 2);
      final f = (await h.content.getById(id))!.media.first;
      expect((await remove(id, f.id)).removed, isTrue);
      expect((await remove(id, f.id)).notFound, isTrue);
    });

    test('a media id of another content is not removed', () async {
      final a = await h.addContent(t, remoteId: 'a');
      final b = await h.addContent(t, remoteId: 'b');
      final fb = (await h.content.getById(b))!.media.single;
      final r = await remove(a, fb.id);
      expect(r.notFound, isTrue);
      expect(await h.content.getById(b), isNotNull);
      expect(h.gallery.files, hasLength(2));
    });

    test(
      'pending slide: removed without gallery call, never downloaded',
      () async {
        final id = await h.addContent(
          t,
          remoteId: 'p',
          slides: 2,
          withFiles: false,
        );
        final m = (await h.content.getById(id))!.media;
        expect(m.first.contentUri, isNull);
        expect((await remove(id, m.first.id)).removed, isTrue);
        expect(h.spy.deletes, isEmpty);
        final pending = await h.content.pendingMedia();
        expect(pending.map((p) => p.file.id), [m.last.id]);
      },
    );
  });

  group('removal racing the downloader (QA)', () {
    late FakeClock clock;
    late FakeContentRepo content;
    late FakeTargetRepo targets;
    late FakeContentPlatform platform;
    late FakeMediaCache cache;
    late MidStreamCache mid;
    late FakeGalleryStore gallery;
    late RemoveMediaFile remove;
    late Target alice;

    DownloadPending build() => DownloadPending(
      content: content,
      targets: targets,
      activity: FakeActivityRepo(clock),
      platform: platform,
      cache: mid,
      gallery: gallery,
      storage: FakeStorageInfo(),
      clock: clock,
      leases: FakeGovernorLeaseRepo(clock),
      displayName: ({
        required username,
        required postedAt,
        required remoteId,
        required ext,
        slideIndex,
      }) => '${username}_$remoteId${slideIndex ?? ''}.$ext',
      relativeDir: (u) => 'Pictures/Storize/$u',
    );

    setUp(() async {
      clock = FakeClock(s.t0);
      targets = FakeTargetRepo();
      content = FakeContentRepo(targets: targets);
      platform = FakeContentPlatform();
      cache = FakeMediaCache();
      mid = MidStreamCache(cache);
      gallery = FakeGalleryStore(cache: cache);
      alice = await targets.insert(s.target());
      remove = RemoveMediaFile(content: content, gallery: gallery, cache: mid);
    });

    Future<int> seed() async {
      final c = s.content(targetId: alice.id, remoteId: 'r1');
      return (await content.insertIfNew(c, [
        s.media(),
        s.media(slideIndex: 1),
      ])).contentId;
    }

    test(
      'removed while DOWNLOADING: no crash, no gallery file, no .part',
      () async {
        final id = await seed();
        final victim = (await content.getById(id))!.media.first;
        platform
          ..queueMedia(List.filled(40, 1), chunkSize: 10)
          ..queueMedia(List.filled(40, 1), chunkSize: 10);
        mid.onAppend = () async {
          final r = await remove(id, victim.id);
          expect(r.removed, isTrue);
        };
        final result = await build().run();
        expect(result.stopReason, DownloadStopReason.completed);
        final left = (await content.getById(id))!.media;
        expect(left, hasLength(1));
        expect(left.single.status, MediaFileStatus.done);
        expect(gallery.files, hasLength(1));
        expect(
          await cache.partialLength(victim.id),
          0,
          reason: 'orphan .part of the removed slide',
        );
      },
    );

    test('removed while DOWNLOADING (last slide): content row gone, '
        'nothing left in gallery or cache', () async {
      final c = s.content(targetId: alice.id, remoteId: 'one');
      final id = (await content.insertIfNew(c, [s.media()])).contentId;
      final victim = (await content.getById(id))!.media.single;
      platform.queueMedia(List.filled(40, 1), chunkSize: 10);
      mid.onAppend = () async => remove(id, victim.id);
      await build().run();
      expect(await content.getById(id), isNull);
      expect(gallery.files, isEmpty);
      expect(await cache.partialLength(victim.id), 0);
    });

    test('removed while PENDING (before the run): never fetched', () async {
      final id = await seed();
      final m = (await content.getById(id))!.media;
      await remove(id, m.first.id);
      platform.queueMedia(List.filled(10, 1));
      await build().run();
      expect(platform.callsTo('openMedia'), hasLength(1));
      expect(gallery.files, hasLength(1));
      expect(await cache.partialLength(m.first.id), 0);
    });
  });
}
