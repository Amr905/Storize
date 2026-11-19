import 'package:storize_domain/testing.dart';
import 'package:test/test.dart';

/// QA (T-019a): the fake follows the same contract as the real cache.
void main() {
  late FakeMediaCache cache;
  setUp(() => cache = FakeMediaCache());

  test(
    'deleteThumbnail is idempotent and never throws for a missing id',
    () async {
      await cache.deleteThumbnail(1);
      await cache.deleteThumbnail(1);
      await cache.writeThumbnail(1, [1]);
      await cache.deleteThumbnail(1);
      await cache.deleteThumbnail(1);
      expect(cache.thumbnailBytes(1), isNull);
    },
  );

  test('deleteThumbnail leaves the part file and other thumbnails', () async {
    await cache.append(1, Stream.value([1]));
    await cache.writeThumbnail(1, [1]);
    await cache.writeThumbnail(2, [2]);
    await cache.deleteThumbnail(1);
    expect(await cache.partialLength(1), 1);
    expect(cache.thumbnailBytes(2), [2]);
  });

  test(
    'cleanupOrphans removes parts only and leaves thumbnails alone',
    () async {
      await cache.append(1, Stream.value([1]));
      await cache.writeThumbnail(1, [1]);
      await cache.append(2, Stream.value([1]));
      await cache.writeThumbnail(2, [1]);
      await cache.writeThumbnail(3, [1]);
      expect(await cache.cleanupOrphans({2}), 1);
      expect(await cache.cleanupOrphans({2}), 0);
      expect(cache.thumbnailBytes(1), isNotNull, reason: 'thumb of 1 survives');
      expect(cache.thumbnailBytes(3), isNotNull, reason: 'thumb of 3 survives');
      expect(await cache.partialLength(2), 1);
    },
  );

  test('cleanupOrphanThumbnails keeps every live media id (F1)', () async {
    // Item 1 is downloaded (no part), item 2 is pending (part and thumb).
    await cache.writeThumbnail(1, [1]);
    await cache.append(2, Stream.value([1]));
    await cache.writeThumbnail(2, [1]);
    await cache.writeThumbnail(3, [1]);
    expect(await cache.cleanupOrphanThumbnails({1, 2}), 1);
    expect(cache.thumbnailBytes(1), isNotNull);
    expect(cache.thumbnailBytes(2), isNotNull);
    expect(cache.thumbnailBytes(3), isNull);
  });
}
