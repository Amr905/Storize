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
    // Poll (bounded) for the write; the stream is still open, so there was
    // no close yet (CHECKPOINT-3 F-1: a fixed 100 ms wait flaked under load).
    final file = File('${cacheDir.path}/part/3.part');
    for (var i = 0; i < 200; i++) {
      if (file.existsSync() && file.lengthSync() >= 4) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
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

  test('cleanupOrphans on start: orphan parts go, thumbs stay', () async {
    final partDir = Directory('${cacheDir.path}/part')..createSync();
    File('${partDir.path}/1.part').writeAsBytesSync([1]);
    File('${partDir.path}/2.part').writeAsBytesSync([2]);
    File('${partDir.path}/junk.part').writeAsBytesSync([3]);
    File('${partDir.path}/note.txt').writeAsBytesSync([4]);
    await cache.writeThumbnail(1, [5]);
    await cache.writeThumbnail(2, [6]);

    // 1.part and junk.part are removed; 2.part is kept. Thumbnails are not
    // part files, so both stay.
    expect(await cache.cleanupOrphans({2}), 2);

    expect(File('${partDir.path}/1.part').existsSync(), isFalse);
    expect(File('${partDir.path}/junk.part').existsSync(), isFalse);
    expect(File('${partDir.path}/2.part').existsSync(), isTrue);
    expect(File('${partDir.path}/note.txt').existsSync(), isTrue);
    expect(File('${filesDir.path}/thumbs/1.webp').existsSync(), isTrue);
    expect(File('${filesDir.path}/thumbs/2.webp').existsSync(), isTrue);
  });

  test(
    'cleanupOrphanThumbnails removes only exact <int>.webp and .webp.tmp files',
    () async {
      final thumbs = Directory('${filesDir.path}/thumbs')..createSync();
      File('${thumbs.path}/3.webp').writeAsBytesSync([1]);
      File('${thumbs.path}/3.webp.tmp').writeAsBytesSync([1]);
      File('${thumbs.path}/+4.webp').writeAsBytesSync([1]);
      File('${thumbs.path}/05.webp').writeAsBytesSync([1]);
      File('${thumbs.path}/x.webp').writeAsBytesSync([1]);
      File('${thumbs.path}/7.png').writeAsBytesSync([1]);
      Directory('${thumbs.path}/8.webp').createSync();

      expect(await cache.cleanupOrphanThumbnails(<int>{}), 2);

      expect(File('${thumbs.path}/3.webp').existsSync(), isFalse);
      expect(File('${thumbs.path}/3.webp.tmp').existsSync(), isFalse);
      for (final name in ['+4.webp', '05.webp', 'x.webp', '7.png']) {
        expect(File('${thumbs.path}/$name').existsSync(), isTrue, reason: name);
      }
      expect(Directory('${thumbs.path}/8.webp').existsSync(), isTrue);
    },
  );

  test('cleanupOrphanThumbnails keeps a live id and its .tmp', () async {
    final thumbs = Directory('${filesDir.path}/thumbs')..createSync();
    File('${thumbs.path}/3.webp').writeAsBytesSync([1]);
    File('${thumbs.path}/3.webp.tmp').writeAsBytesSync([1]);
    expect(await cache.cleanupOrphanThumbnails({3}), 0);
    expect(File('${thumbs.path}/3.webp.tmp').existsSync(), isTrue);
  });

  test(
    'cleanupOrphanThumbnails never deletes through a thumbnail symlink',
    () async {
      final outside = Directory('${root.path}/outside')..createSync();
      final victim = File('${outside.path}/victim.jpg')..writeAsBytesSync([1]);
      final thumbs = Directory('${filesDir.path}/thumbs')..createSync();
      Link('${thumbs.path}/9.webp').createSync(victim.path);

      expect(await cache.cleanupOrphanThumbnails(<int>{}), 0);

      expect(victim.existsSync(), isTrue, reason: 'link target deleted');
      expect(Link('${thumbs.path}/9.webp').existsSync(), isTrue);
    },
  );

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
