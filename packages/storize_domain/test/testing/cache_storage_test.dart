import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FakeMediaCache', () {
    late FakeMediaCache cache;
    setUp(() => cache = FakeMediaCache());

    test('partialLength is 0 without a part file', () async {
      expect(await cache.partialLength(1), 0);
    });

    test('append accumulates across calls, enabling resume', () async {
      await cache.append(
        1,
        Stream.fromIterable([
          [1, 2],
          [3],
        ]),
      );
      expect(await cache.partialLength(1), 3);
      await cache.append(1, Stream.value([4, 5]));
      expect(await cache.partialLength(1), 5);
      expect(cache.partBytes(1), [1, 2, 3, 4, 5]);
      expect(await cache.partialLength(2), 0);
    });

    test(
      'bytes before a stream error are kept and the error rethrown',
      () async {
        Stream<List<int>> failing() async* {
          yield [1, 2];
          throw const ExpiredMediaUrl();
        }

        await expectLater(
          cache.append(1, failing()),
          throwsA(isA<ExpiredMediaUrl>()),
        );
        expect(await cache.partialLength(1), 2);
      },
    );

    test('completedPath works with FakeGalleryStore.save', () async {
      final store = FakeGalleryStore(cache: cache);
      await cache.append(7, Stream.value([1, 2, 3, 4]));
      final path = await cache.completedPath(7);
      final saved = await store.save(
        sourcePath: path,
        relativeDir: 'Pictures/Storize/a/',
        displayName: 'a.jpg',
        mime: 'image/jpeg',
      );
      expect(saved.sizeBytes, 4);
    });

    test('completedPath without a part file throws', () async {
      await expectLater(cache.completedPath(1), throwsStateError);
    });

    test('discard removes the part file and is idempotent', () async {
      await cache.append(1, Stream.value([1]));
      await cache.discard(1);
      await cache.discard(1);
      expect(await cache.partialLength(1), 0);
      expect(cache.partIds, isEmpty);
    });

    test(
      'cleanupOrphans removes parts not in keepIds and counts them',
      () async {
        for (final id in [1, 2, 3]) {
          await cache.append(id, Stream.value([id]));
        }
        expect(await cache.cleanupOrphans({2}), 2);
        expect(cache.partIds, {2});
        expect(await cache.cleanupOrphans({2}), 0);
      },
    );

    test('writeThumbnail stores bytes, returns a path, replaces', () async {
      final path = await cache.writeThumbnail(5, [1, 2]);
      expect(path, endsWith('5.webp'));
      expect(cache.thumbnailBytes(5), [1, 2]);
      await cache.writeThumbnail(5, [9]);
      expect(cache.thumbnailBytes(5), [9]);
      expect(await cache.cleanupOrphans({}), 1);
      expect(cache.thumbnailBytes(5), isNull);
    });
  });

  group('FakeStorageInfo and StoragePolicy', () {
    test('values are settable', () async {
      final info = FakeStorageInfo(free: 5, total: 10);
      expect(await info.freeBytes(), 5);
      expect(await info.totalBytes(), 10);
      info.free = 1;
      expect(await info.freeBytes(), 1);
    });

    test('NFR-13 thresholds', () {
      expect(StoragePolicy.lowSpaceBytes, 1073741824);
      expect(StoragePolicy.pauseBytes, 209715200);
      expect(StoragePolicy.pauseBytes, lessThan(StoragePolicy.lowSpaceBytes));
    });
  });

  test('TargetLimits constants', () {
    expect(TargetLimits.recommendedMax, 50);
    expect(TargetLimits.noteMaxLength, 200);
    expect(Target.maxNoteLength, TargetLimits.noteMaxLength);
  });
}
