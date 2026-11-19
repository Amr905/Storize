import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';

void main() {
  late Directory root;
  late Directory cacheDir;
  late Directory filesDir;
  late FileMediaCache cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storize_cache_');
    addTearDown(() => root.deleteSync(recursive: true));
    cacheDir = Directory('${root.path}/cache')..createSync();
    filesDir = Directory('${root.path}/files')..createSync();
    cache = FileMediaCache(
      cacheDir: () async => cacheDir,
      filesDir: () async => filesDir,
    );
  });

  test('part files live in <cache>/part/<id>.part', () async {
    await cache.append(12, Stream.value([1, 2, 3]));
    final path = await cache.completedPath(12);
    expect(path, '${cacheDir.path}/part/12.part');
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
    expect(
      Directory('${filesDir.path}/part').existsSync(),
      isFalse,
      reason: 'nothing in the files dir',
    );
  });

  test('chunks reach the file before the stream ends (kill safety)', () async {
    final controller = StreamController<List<int>>();
    final done = cache.append(3, controller.stream);
    controller.add([1, 2, 3, 4]);
    // Give the write a moment; the stream is still open, so there was no
    // close yet.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      File('${cacheDir.path}/part/3.part').lengthSync(),
      4,
      reason: 'a kill now would keep these bytes',
    );
    expect(await cache.partialLength(3), 4);
    controller.add([5]);
    await controller.close();
    await done;
    expect(await cache.partialLength(3), 5);
  });

  test('cleanupOrphans on start: only part files go', () async {
    final partDir = Directory('${cacheDir.path}/part')..createSync();
    File('${partDir.path}/1.part').writeAsBytesSync([1]);
    File('${partDir.path}/2.part').writeAsBytesSync([2]);
    File('${partDir.path}/junk.part').writeAsBytesSync([3]);
    File('${partDir.path}/note.txt').writeAsBytesSync([4]);
    await cache.writeThumbnail(1, [5]);

    expect(await cache.cleanupOrphans({2}), 2);

    expect(File('${partDir.path}/1.part').existsSync(), isFalse);
    expect(File('${partDir.path}/junk.part').existsSync(), isFalse);
    expect(File('${partDir.path}/2.part').existsSync(), isTrue);
    expect(File('${partDir.path}/note.txt').existsSync(), isTrue);
    expect(File('${filesDir.path}/thumbs/1.webp').existsSync(), isTrue);
  });

  test('thumbnails go to <files>/thumbs/<id>.webp', () async {
    final path = await cache.writeThumbnail(9, [1, 2, 3]);
    expect(path, '${filesDir.path}/thumbs/9.webp');
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
    expect(
      Directory('${cacheDir.path}/thumbs').existsSync(),
      isFalse,
      reason: 'nothing in the cache dir',
    );
  });

  test('thumbnail write is atomic: no temp file is left', () async {
    await cache.writeThumbnail(9, List.filled(1000, 1));
    await cache.writeThumbnail(9, [2]);
    final names = Directory(
      '${filesDir.path}/thumbs',
    ).listSync().map((e) => e.uri.pathSegments.last).toList();
    expect(names, ['9.webp']);
  });

  test(
    'a failed thumbnail write keeps the old one and cleans the temp',
    () async {
      await cache.writeThumbnail(9, [1, 1]);
      // A directory in the way of the temp file makes the write fail.
      Directory('${filesDir.path}/thumbs/9.webp.tmp').createSync();
      await expectLater(
        cache.writeThumbnail(9, [2, 2]),
        throwsA(isA<FileSystemException>()),
      );
      expect(File('${filesDir.path}/thumbs/9.webp').readAsBytesSync(), [1, 1]);
    },
  );

  test('the injected directory functions are called lazily per call', () async {
    var calls = 0;
    final lazy = FileMediaCache(
      cacheDir: () async {
        calls++;
        return cacheDir;
      },
      filesDir: () async => filesDir,
    );
    expect(calls, 0);
    await lazy.partialLength(1);
    expect(calls, 1);
  });

  test('append works when the cache dir was wiped in between', () async {
    await cache.append(1, Stream.value([1]));
    Directory('${cacheDir.path}/part').deleteSync(recursive: true);
    expect(await cache.partialLength(1), 0);
    expect(await cache.cleanupOrphans(<int>{}), 0);
    await cache.append(1, Stream.value([2]));
    expect(await cache.partialLength(1), 1);
  });
}
