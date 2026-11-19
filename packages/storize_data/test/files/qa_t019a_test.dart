import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';

/// QA (T-019a): adversarial filesystem checks for `deleteThumbnail` and the
/// orphan-thumbnail sweep.
void main() {
  late Directory root;
  late Directory cacheDir;
  late Directory filesDir;
  late Directory thumbs;
  late Directory outside;
  late FileMediaCache cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storize_qa19a_');
    addTearDown(() => root.deleteSync(recursive: true));
    cacheDir = Directory('${root.path}/cache')..createSync();
    filesDir = Directory('${root.path}/files')..createSync();
    thumbs = Directory('${filesDir.path}/thumbs')..createSync();
    outside = Directory('${root.path}/outside')..createSync();
    cache = FileMediaCache(
      cacheDir: () async => cacheDir,
      filesDir: () async => filesDir,
    );
  });

  File t(String name) => File('${thumbs.path}/$name');

  group('cleanupOrphans name matching', () {
    test('only exact <int>.webp names are swept', () async {
      const swept = ['5.webp', '0.webp', '123456.webp', '-5.webp'];
      const kept = [
        '05.webp',
        '+5.webp',
        '5.WEBP',
        '5.webp.tmp',
        '5.webp.bak',
        'a.webp',
        '.webp',
        '5 .webp',
        '5.5.webp',
        '0x5.webp',
        '5.webp.webp',
        '99999999999999999999.webp', // beyond int64: tryParse is null
        '9223372036854775808.webp', // int64 max + 1
        'notes.txt',
      ];
      for (final n in [...swept, ...kept]) {
        t(n).writeAsBytesSync([1]);
      }
      final removed = await cache.cleanupOrphans(<int>{});
      expect(removed, swept.length);
      for (final n in swept) {
        expect(t(n).existsSync(), isFalse, reason: n);
      }
      for (final n in kept) {
        expect(t(n).existsSync(), isTrue, reason: n);
      }
    });

    test('keepIds protects exactly the listed ids', () async {
      for (final id in [1, 2, 3]) {
        t('$id.webp').writeAsBytesSync([1]);
      }
      expect(await cache.cleanupOrphans({1, 3}), 1);
      expect(t('1.webp').existsSync(), isTrue);
      expect(t('2.webp').existsSync(), isFalse);
      expect(t('3.webp').existsSync(), isTrue);
    });

    test('a directory named 5.webp is left alone, with its content', () async {
      final d = Directory('${thumbs.path}/5.webp')..createSync();
      File('${d.path}/inner.webp').writeAsBytesSync([1]);
      expect(await cache.cleanupOrphans(<int>{}), 0);
      expect(d.existsSync(), isTrue);
      expect(File('${d.path}/inner.webp').existsSync(), isTrue);
    });

    test('a symlink named 5.webp is not followed or deleted', () async {
      final target = File('${outside.path}/precious.webp')
        ..writeAsBytesSync([9]);
      Link('${thumbs.path}/5.webp').createSync(target.path);
      expect(await cache.cleanupOrphans(<int>{}), 0);
      expect(target.existsSync(), isTrue);
      expect(
        FileSystemEntity.typeSync(
          '${thumbs.path}/5.webp',
          followLinks: false,
        ),
        FileSystemEntityType.link,
      );
    });

    test('a symlink to a directory is not traversed', () async {
      File('${outside.path}/7.webp').writeAsBytesSync([9]);
      Link('${thumbs.path}/dir.webp').createSync(outside.path);
      expect(await cache.cleanupOrphans(<int>{}), 0);
      expect(File('${outside.path}/7.webp').existsSync(), isTrue);
    });

    test('a thumbs directory that is a symlink: only <int>.webp inside the '
        'link target can be touched, nothing else', () async {
      // Documented behaviour probe: the support dir is app-private, so the
      // link itself is trusted; we only make sure other files survive.
      thumbs.deleteSync();
      File('${outside.path}/keep.txt').writeAsBytesSync([1]);
      File('${outside.path}/9.webp').writeAsBytesSync([1]);
      Link(thumbs.path).createSync(outside.path);
      final removed = await cache.cleanupOrphans(<int>{});
      expect(File('${outside.path}/keep.txt').existsSync(), isTrue);
      expect(removed, 1);
      expect(File('${outside.path}/9.webp').existsSync(), isFalse);
    });

    test('part files and thumbs share keepIds (same id space)', () async {
      await cache.append(4, Stream.value([1]));
      await cache.writeThumbnail(4, [1]);
      await cache.append(5, Stream.value([1]));
      await cache.writeThumbnail(5, [1]);
      expect(await cache.cleanupOrphans({4}), 2);
      expect(await cache.partialLength(4), 1);
      expect(t('4.webp').existsSync(), isTrue);
      expect(await cache.partialLength(5), 0);
      expect(t('5.webp').existsSync(), isFalse);
    });

    test('BLOCKER probe: a startup call with only pending ids wipes the '
        'thumbnails of downloaded content', () async {
      // Downloaded media 1 (thumbnail only, part already discarded) and
      // pending media 2 (part file + thumbnail).
      await cache.writeThumbnail(1, [1]);
      await cache.append(2, Stream.value([1]));
      await cache.writeThumbnail(2, [1]);
      // part-file semantics: keep only ids with a pending download.
      await cache.cleanupOrphans({2});
      expect(
        t('1.webp').existsSync(),
        isFalse,
        reason:
            'documents the hazard: the caller MUST pass every live media id',
      );
    });
  });

  group('deleteThumbnail', () {
    test('removes the thumbnail and its .tmp, nothing else', () async {
      await cache.writeThumbnail(5, [1]);
      await cache.writeThumbnail(6, [1]);
      t('5.webp.tmp').writeAsBytesSync([1]);
      t('6.webp.tmp').writeAsBytesSync([1]);
      await cache.deleteThumbnail(5);
      expect(t('5.webp').existsSync(), isFalse);
      expect(t('5.webp.tmp').existsSync(), isFalse);
      expect(t('6.webp').existsSync(), isTrue);
      expect(t('6.webp.tmp').existsSync(), isTrue);
    });

    test('idempotent, also with no thumbs directory at all', () async {
      await cache.deleteThumbnail(1);
      await cache.deleteThumbnail(1);
      thumbs.deleteSync();
      await cache.deleteThumbnail(1);
      expect(thumbs.existsSync(), isFalse, reason: 'does not create it');
    });

    test('a leftover .tmp alone is removed', () async {
      t('3.webp.tmp').writeAsBytesSync([1]);
      await cache.deleteThumbnail(3);
      expect(t('3.webp.tmp').existsSync(), isFalse);
    });

    test(
      'a directory at the thumbnail path is not touched, no throw',
      () async {
        final d = Directory('${thumbs.path}/5.webp')..createSync();
        File('${d.path}/x').writeAsBytesSync([1]);
        await cache.deleteThumbnail(5);
        expect(File('${d.path}/x').existsSync(), isTrue);
      },
    );

    test('a symlink at the thumbnail path is not followed', () async {
      final target = File('${outside.path}/precious')..writeAsBytesSync([9]);
      Link('${thumbs.path}/5.webp').createSync(target.path);
      Link('${thumbs.path}/5.webp.tmp').createSync(target.path);
      await cache.deleteThumbnail(5);
      expect(target.existsSync(), isTrue);
    });

    test('a dangling symlink at the path does not throw', () async {
      Link('${thumbs.path}/5.webp').createSync('${outside.path}/nope');
      await cache.deleteThumbnail(5);
    });

    test('does not touch the part file of the same id', () async {
      await cache.append(5, Stream.value([1, 2]));
      await cache.writeThumbnail(5, [1]);
      await cache.deleteThumbnail(5);
      expect(await cache.partialLength(5), 2);
    });

    test('negative id maps to a name that is never an orphan match', () async {
      await cache.deleteThumbnail(-1);
      t('-1.webp').writeAsBytesSync([1]);
      // "-1" round-trips, so the sweep treats it as id -1 (documented).
      expect(await cache.cleanupOrphans(<int>{-1}), 0);
    });
  });
}
