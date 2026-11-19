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

  test('cleanupOrphans counts parts plus thumbnails, keeps keepIds', () async {
    await cache.append(1, Stream.value([1]));
    await cache.writeThumbnail(1, [1]);
    await cache.append(2, Stream.value([1]));
    await cache.writeThumbnail(2, [1]);
    await cache.writeThumbnail(3, [1]);
    expect(await cache.cleanupOrphans({2}), 3);
    expect(await cache.cleanupOrphans({2}), 0);
    expect(cache.thumbnailBytes(2), isNotNull);
    expect(await cache.partialLength(2), 1);
  });
}
