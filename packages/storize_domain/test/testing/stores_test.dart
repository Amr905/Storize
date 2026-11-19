// Const literals add noise to test data.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'dart:io';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart';

void main() {
  group('FakeClock', () {
    test('starts in UTC, advances and sets', () {
      final clock = FakeClock(t0);
      expect(clock.now(), t0);
      expect(clock.now().isUtc, isTrue);
      clock.advance(const Duration(hours: 1));
      expect(clock.now(), t0.add(const Duration(hours: 1)));
      clock.set(DateTime.utc(2030));
      expect(clock.now(), DateTime.utc(2030));
    });

    test('SystemClock returns UTC', () {
      expect(const SystemClock().now().isUtc, isTrue);
    });
  });

  group('FakeContentPlatform', () {
    late FakeContentPlatform platform;
    setUp(() => platform = FakeContentPlatform());

    const user = RemoteUser(
      remoteUserId: '1',
      username: 'a',
      followedByViewer: true,
      blockedByViewer: false,
    );

    test('returns queued results in order, then the fallback', () async {
      platform.resolveUserResults
        ..addOk(user)
        ..addFailure(const TargetNotFound())
        ..fallback = const Err(NetworkFailure());
      expect(await platform.resolveUser('a'), const Ok(user));
      expect(
        await platform.resolveUser('b'),
        const Err<RemoteUser>(TargetNotFound()),
      );
      expect(
        await platform.resolveUser('c'),
        const Err<RemoteUser>(NetworkFailure()),
      );
      expect(
        await platform.resolveUser('d'),
        const Err<RemoteUser>(NetworkFailure()),
      );
      expect(platform.resolveUserResults.queued, 0);
    });

    test('an unscripted call fails loudly', () async {
      await expectLater(platform.verifySession(), throwsStateError);
    });

    test('every method is scriptable and recorded', () async {
      platform.refreshUserResults.addOk(user);
      platform.fetchStoriesResults.addOk({'1': []});
      platform.fetchNewPostsResults.addOk([]);
      platform.latestPostTimeResults.addOk(null);
      platform.verifySessionResults.addOk(user);
      await platform.refreshUser('1', 'a');
      await platform.fetchStories(['1'], policy: ExtractionPolicy.directOnly);
      await platform.fetchNewPosts(
        '1',
        t0,
        policy: ExtractionPolicy.directThenPage,
      );
      expect(await platform.latestPostTime('1'), const Ok<DateTime?>(null));
      await platform.verifySession();
      expect(platform.calls.map((c) => c.method), [
        'refreshUser',
        'fetchStories',
        'fetchNewPosts',
        'latestPostTime',
        'verifySession',
      ]);
      expect(platform.callsTo('fetchNewPosts').single.args, [
        '1',
        t0,
        ExtractionPolicy.directThenPage,
      ]);
      expect(platform.id, PlatformId.instagram);
    });

    test('openMedia streams bytes and honours fromByte', () async {
      platform
        ..queueMedia([1, 2, 3, 4, 5], chunkSize: 2)
        ..queueMedia([1, 2, 3, 4, 5]);
      final chunks = await platform.openMedia('u').toList();
      expect(chunks, [
        [1, 2],
        [3, 4],
        [5],
      ]);
      final resumed = await platform
          .openMedia('u', fromByte: 3)
          .expand((c) => c)
          .toList();
      expect(resumed, [4, 5]);
      expect(platform.callsTo('openMedia').last.args, ['u', 3]);
    });

    test('openMedia signals an expired URL as a stream error', () async {
      platform.queueMediaError(const ExpiredMediaUrl(), bytesBeforeError: [9]);
      final received = <int>[];
      Object? error;
      try {
        await platform.openMedia('u').forEach(received.addAll);
      } on ExpiredMediaUrl catch (e) {
        error = e;
      }
      expect(received, [9]);
      expect(error, isA<ExpiredMediaUrl>());
    });

    test('openMedia with nothing queued errors', () async {
      await expectLater(platform.openMedia('u'), emitsError(isStateError));
    });
  });

  group('FakeGalleryStore', () {
    late FakeGalleryStore store;
    setUp(() => store = FakeGalleryStore(defaultSizeBytes: 42));

    Future<GalleryFile> save([String name = 'a.jpg']) => store.save(
      sourcePath: '/no/such/file',
      relativeDir: 'Pictures/Storize/alice/',
      displayName: name,
      mime: 'image/jpeg',
    );

    test('save, exists, size and delete', () async {
      final f = await save();
      expect(f.sizeBytes, 42);
      expect(f.relativePath, 'Pictures/Storize/alice/');
      expect(await store.exists(f.uri), isTrue);
      expect(await store.size(f.uri), 42);
      expect(await store.delete(f.uri), isTrue);
      expect(await store.delete(f.uri), isFalse);
      expect(await store.exists(f.uri), isFalse);
      expect(await store.size(f.uri), isNull);
      expect(store.saved, [f]);
      expect(store.files, isEmpty);
    });

    test('uses the real size of an existing source file', () async {
      final dir = Directory.systemTemp.createTempSync('storize_gallery');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/x.part')..writeAsBytesSync([1, 2, 3]);
      final f = await store.save(
        sourcePath: file.path,
        relativeDir: 'd',
        displayName: 'x',
        mime: 'image/jpeg',
      );
      expect(f.sizeBytes, 3);
    });

    test('simulateMissing makes a file vanish (EC-20)', () async {
      final f = await save();
      expect(store.simulateMissing(f.uri), isTrue);
      expect(await store.exists(f.uri), isFalse);
      expect(await store.delete(f.uri), isFalse);
      expect(store.simulateMissing(f.uri), isFalse);
    });

    test('failNextSave fails once', () async {
      store.failNextSave(const FileSystemException('disk full'));
      await expectLater(save(), throwsA(isA<FileSystemException>()));
      expect(store.files, isEmpty);
      await save();
      expect(store.files, hasLength(1));
    });

    test('typed save failures fire once each', () async {
      store.failNextSaveWithPermissionDenied();
      await expectLater(save(), throwsA(isA<GalleryPermissionDenied>()));
      store.failNextSaveWithStorageFull();
      await expectLater(save(), throwsA(isA<GalleryStorageFull>()));
      store.failNextSaveWithWriteFailed('INSERT_FAILED');
      await expectLater(
        save(),
        throwsA(
          isA<GalleryWriteFailed>().having(
            (e) => e.code,
            'code',
            'INSERT_FAILED',
          ),
        ),
      );
      expect(store.files, isEmpty);
      await save();
      expect(store.files, hasLength(1));
    });

    test('failNextDelete fires once and keeps the file', () async {
      final f = await save();
      store.failNextDelete(const GalleryPermissionDenied());
      await expectLater(
        store.delete(f.uri),
        throwsA(isA<GalleryPermissionDenied>()),
      );
      expect(await store.exists(f.uri), isTrue);
      expect(await store.delete(f.uri), isTrue);
    });

    test(
      'failNextExists / failNextSize fire once for the documented set',
      () async {
        final f = await save();
        for (final error in <GalleryStoreException>[
          const GalleryPermissionDenied(),
          const GalleryStorageFull(),
          const GalleryWriteFailed('IO_ERROR'),
        ]) {
          store.failNextExists(error);
          await expectLater(
            store.exists(f.uri),
            throwsA(predicate((e) => identical(e, error))),
          );
          expect(await store.exists(f.uri), isTrue);
          store.failNextSize(error);
          await expectLater(
            store.size(f.uri),
            throwsA(predicate((e) => identical(e, error))),
          );
          expect(await store.size(f.uri), 42);
        }
      },
    );

    test('gallery exceptions are domain exceptions with a code', () {
      expect(const GalleryPermissionDenied().code, 'PERMISSION_DENIED');
      expect(const GalleryStorageFull().code, 'STORAGE_FULL');
      expect(const GalleryWriteFailed('X').toString(), 'GalleryWriteFailed(X)');
      expect(const GalleryStorageFull(), isA<DomainException>());
    });

    test('each save gets a distinct URI', () async {
      final a = await save();
      final b = await save();
      expect(a.uri, isNot(b.uri));
    });
  });

  group('FakeSessionStore', () {
    test('save, load, overwrite and clear', () async {
      final store = FakeSessionStore();
      final blob = SessionBlob(
        cookies: {'sessionid': 'x', 'ds_user_id': 'y'},
        userAgent: 'ua',
        capturedAt: t0,
      );
      expect(await store.load(1), isNull);
      await store.save(1, blob);
      expect(await store.load(1), blob);
      expect(await store.load(2), isNull);
      final other = SessionBlob(
        cookies: {'sessionid': 'x2', 'ds_user_id': 'y2'},
        userAgent: 'u2',
        capturedAt: t0,
      );
      await store.save(1, other);
      expect(await store.load(1), other);
      await store.clear(1);
      await store.clear(1);
      expect(await store.load(1), isNull);
      expect(store.accountIds, isEmpty);
    });

    test(
      'save rejects missing or empty required cookies, names only',
      () async {
        final store = FakeSessionStore();
        for (final cookies in [
          <String, String>{'ds_user_id': 'SECRETVAL'},
          {'sessionid': 'SECRETVAL', 'ds_user_id': ''},
          {'csrftoken': 'SECRETVAL'},
        ]) {
          final blob = SessionBlob(
            cookies: cookies,
            userAgent: 'ua',
            capturedAt: t0,
          );
          await expectLater(
            store.save(1, blob),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.toString(),
                'message',
                isNot(contains('SECRETVAL')),
              ),
            ),
          );
        }
        expect(store.accountIds, isEmpty);
        expect(SessionStore.requiredCookies, ['sessionid', 'ds_user_id']);
      },
    );
  });

  group('FakeScheduler', () {
    test('records apply, checkNow and cancelAll', () async {
      final s = FakeScheduler();
      await s.apply(storyMin: 30, postMin: 180, wifiOnly: true);
      await s.checkNow();
      await s.checkNow(scope: CheckScope.stories, targetId: 4);
      await s.cancelAll();
      expect(s.applyCalls.single, (storyMin: 30, postMin: 180, wifiOnly: true));
      expect(s.checkNowCalls, [
        (scope: CheckScope.all, targetId: null),
        (scope: CheckScope.stories, targetId: 4),
      ]);
      expect(s.cancelAllCalls, 1);
    });
  });

  group('FakeMediaCache.deleteThumbnail (T-019a AC1)', () {
    late FakeMediaCache cache;
    setUp(() => cache = FakeMediaCache());

    test('removes the thumbnail of that ID only', () async {
      await cache.writeThumbnail(3, [1, 2]);
      await cache.writeThumbnail(4, [9]);

      await cache.deleteThumbnail(3);

      expect(cache.thumbnailBytes(3), isNull);
      expect(cache.thumbnailBytes(4), [9]);
    });

    test('is idempotent and never throws for a missing thumbnail', () async {
      await cache.deleteThumbnail(42);
      await cache.writeThumbnail(5, [1]);
      await cache.deleteThumbnail(5);
      await cache.deleteThumbnail(5);
      expect(cache.thumbnailBytes(5), isNull);
    });

    test('leaves the part file of the same ID alone', () async {
      await cache.append(6, Stream.value([1, 2]));
      await cache.writeThumbnail(6, [3]);

      await cache.deleteThumbnail(6);

      expect(cache.partBytes(6), [1, 2]);
      expect(cache.thumbnailBytes(6), isNull);
    });

    test('cleanupOrphans removes parts only, never thumbnails', () async {
      await cache.writeThumbnail(1, [1]);
      await cache.append(3, Stream.value([3]));

      expect(await cache.cleanupOrphans({}), 1);
      expect(cache.thumbnailBytes(1), [1]);
      expect(cache.partIds, isEmpty);
    });

    test(
      'cleanupOrphanThumbnails removes thumbnails not live, keeps live',
      () async {
        await cache.writeThumbnail(1, [1]);
        await cache.writeThumbnail(2, [2]);
        await cache.append(3, Stream.value([3]));

        expect(await cache.cleanupOrphanThumbnails({2}), 1);
        expect(cache.thumbnailBytes(1), isNull);
        expect(cache.thumbnailBytes(2), [2]);
        expect(cache.partIds, {3}, reason: 'parts are not swept here');
      },
    );
  });
}
