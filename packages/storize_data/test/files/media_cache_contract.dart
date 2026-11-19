import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';

/// What the contract needs besides the cache itself.
class CacheHarness {
  CacheHarness({
    required this.cache,
    required this.partBytes,
    required this.thumbBytes,
  });
  final MediaCache cache;
  final Future<List<int>?> Function(int id) partBytes;
  final Future<List<int>?> Function(int id) thumbBytes;
}

Stream<List<int>> failingStream(List<List<int>> good) async* {
  for (final c in good) {
    yield c;
  }
  throw const FormatException('boom');
}

/// Shared behaviour of every `MediaCache`: real and fake.
void mediaCacheContract(String label, Future<CacheHarness> Function() create) {
  group('MediaCache contract: $label', () {
    late CacheHarness h;
    late MediaCache cache;

    setUp(() async {
      h = await create();
      cache = h.cache;
    });

    test('partialLength is 0 when there is no part', () async {
      expect(await cache.partialLength(1), 0);
    });

    test('append creates the part and counts the bytes', () async {
      await cache.append(
        1,
        Stream.fromIterable([
          [1, 2, 3],
          [4, 5],
        ]),
      );
      expect(await cache.partialLength(1), 5);
      expect(await h.partBytes(1), [1, 2, 3, 4, 5]);
    });

    test('a second append resumes after the first', () async {
      await cache.append(1, Stream.value([1, 2]));
      await cache.append(1, Stream.value([3]));
      expect(await h.partBytes(1), [1, 2, 3]);
      expect(await cache.partialLength(1), 3);
    });

    test('append of an empty stream still creates the part', () async {
      await cache.append(1, const Stream<List<int>>.empty());
      expect(await cache.partialLength(1), 0);
      expect(await cache.completedPath(1), isNotEmpty);
    });

    test('bytes before a stream error are kept, then it rethrows', () async {
      await expectLater(
        cache.append(
          1,
          failingStream([
            [9, 8],
            [7],
          ]),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await cache.partialLength(1), 3);
      await cache.append(1, Stream.value([6]));
      expect(await h.partBytes(1), [9, 8, 7, 6]);
    });

    test('parts of different ids are separate', () async {
      await cache.append(1, Stream.value([1]));
      await cache.append(2, Stream.value([2, 2]));
      expect(await cache.partialLength(1), 1);
      expect(await cache.partialLength(2), 2);
    });

    test('completedPath throws StateError without a part', () async {
      await expectLater(cache.completedPath(5), throwsStateError);
      await cache.append(5, Stream.value([1]));
      await cache.discard(5);
      await expectLater(cache.completedPath(5), throwsStateError);
    });

    test('discard is idempotent', () async {
      await cache.discard(1);
      await cache.append(1, Stream.value([1]));
      await cache.discard(1);
      await cache.discard(1);
      expect(await cache.partialLength(1), 0);
    });

    test(
      'cleanupOrphans removes parts not in keepIds and counts them',
      () async {
        for (final id in [1, 2, 3]) {
          await cache.append(id, Stream.value([id]));
        }
        expect(await cache.cleanupOrphans({2}), 2);
        expect(await cache.partialLength(1), 0);
        expect(await cache.partialLength(2), 1);
        expect(await cache.partialLength(3), 0);
        expect(await cache.cleanupOrphans({2}), 0);
      },
    );

    test(
      'cleanupOrphans works with nothing stored and leaves thumbs',
      () async {
        expect(await cache.cleanupOrphans(<int>{}), 0);
        await cache.writeThumbnail(7, [1, 2, 3]);
        await cache.append(8, Stream.value([1]));
        expect(await cache.cleanupOrphans(<int>{}), 1);
        expect(await h.thumbBytes(7), [1, 2, 3]);
      },
    );

    test('writeThumbnail stores and replaces', () async {
      final path = await cache.writeThumbnail(4, [1, 2]);
      expect(path, isNotEmpty);
      expect(await h.thumbBytes(4), [1, 2]);
      await cache.writeThumbnail(4, [9]);
      expect(await h.thumbBytes(4), [9]);
    });
  });
}
