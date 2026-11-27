import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

import 'fake_native_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late Directory pictures;
  late FakeNativeMedia native;
  late PrivateFiles priv;
  late PluginGalleryStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storize_private_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    pictures = Directory('${tmp.path}/ext/Pictures')
      ..createSync(recursive: true);
    native = FakeNativeMedia();
    priv = PrivateFiles(pictures: () async => pictures);
    store = PluginGalleryStore(native.api, private: priv);
  });

  List<int> data(int n, [int v = 7]) => List.filled(n, v);

  String source(List<int> bytes, [String name = 'a.part']) {
    final f = File('${tmp.path}/$name')..writeAsBytesSync(bytes);
    return f.path;
  }

  Future<GalleryFile> savePrivate({
    List<int>? bytes,
    String dir = 'nour_k',
    String name = 'p.jpg',
  }) => store.save(
    sourcePath: source(bytes ?? data(10)),
    relativeDir: dir,
    displayName: name,
    mime: 'image/jpeg',
    target: StorageTarget.private,
  );

  Future<GalleryFile> saveGallery(List<int> bytes, {String name = 'g.jpg'}) =>
      store.save(
        sourcePath: source(bytes, 'g-$name.part'),
        relativeDir: 'nour_k',
        displayName: name,
        mime: 'image/jpeg',
      );

  Future<void> expectCode(Future<Object?> f, String code) => expectLater(
    f,
    throwsA(isA<GalleryStoreException>().having((e) => e.code, 'code', code)),
  );

  List<String> leftovers() => [
    for (final e in pictures.listSync(recursive: true))
      if (e is File && e.path.endsWith('.part')) e.path,
  ];

  group('private save', () {
    test(
      'lands in app-specific storage with .nomedia, never in MediaStore',
      () async {
        final src = source(data(42));
        final file = await store.save(
          sourcePath: src,
          relativeDir: 'nour_k',
          displayName: 'p.jpg',
          mime: 'image/jpeg',
          target: StorageTarget.private,
        );
        expect(file.uri, startsWith('file://'));
        expect(storageTargetOf(file.uri), StorageTarget.private);
        expect(file.sizeBytes, 42);
        expect(file.relativePath, 'Pictures/Storize/nour_k/');
        expect(file.displayName, 'p.jpg');
        expect(
          File('${pictures.path}/Storize/nour_k/p.jpg').readAsBytesSync(),
          data(42),
        );
        expect(File('${pictures.path}/Storize/.nomedia').existsSync(), isTrue);
        expect(File(src).existsSync(), isTrue, reason: 'source is kept');
        expect(native.calls, isEmpty, reason: 'MediaStore was not touched');
        expect(leftovers(), isEmpty);
      },
    );

    test('lifecycle: exists, size, delete (and delete twice)', () async {
      final f = await savePrivate(bytes: data(33));
      expect(await store.exists(f.uri), isTrue);
      expect(await store.size(f.uri), 33);
      expect(await store.delete(f.uri), isTrue);
      expect(await store.exists(f.uri), isFalse);
      expect(await store.size(f.uri), isNull);
      expect(await store.delete(f.uri), isFalse);
    });

    test('a taken name becomes name (1).ext', () async {
      final a = await savePrivate();
      final b = await savePrivate();
      expect(a.displayName, 'p.jpg');
      expect(b.displayName, 'p (1).jpg');
      expect(a.uri, isNot(b.uri));
    });

    test('a highlight folder with sub folders works', () async {
      final f = await savePrivate(dir: 'nour_k/Highlights/Trip');
      expect(f.relativePath, 'Pictures/Storize/nour_k/Highlights/Trip/');
      expect(await store.exists(f.uri), isTrue);
    });

    test('a missing source is SOURCE_NOT_FOUND and leaves nothing', () async {
      await expectCode(
        store.save(
          sourcePath: '${tmp.path}/nope.part',
          relativeDir: 'x',
          displayName: 'p.jpg',
          mime: 'image/jpeg',
          target: StorageTarget.private,
        ),
        'SOURCE_NOT_FOUND',
      );
      expect(leftovers(), isEmpty);
    });

    for (final (dir, name) in <(String, String)>[
      ('../escape', 'p.jpg'),
      ('..', 'p.jpg'),
      ('a//b', 'p.jpg'),
      (r'a\b', 'p.jpg'),
      ('ok', '../p.jpg'),
      ('ok', 'a/b.jpg'),
      ('ok', '..'),
    ]) {
      test('rejects the path "$dir" + "$name"', () async {
        await expectCode(
          store.save(
            sourcePath: source(data(3)),
            relativeDir: dir,
            displayName: name,
            mime: 'image/jpeg',
            target: StorageTarget.private,
          ),
          'INVALID_ARGUMENT',
        );
        expect(File('${tmp.path}/ext/escape').existsSync(), isFalse);
        expect(File('${pictures.path}/p.jpg').existsSync(), isFalse);
      });
    }

    test(
      'a full disk is GalleryStorageFull and removes the partial file',
      () async {
        await expectLater(
          priv.writeNew(
            relativeDir: 'a',
            displayName: 'x.jpg',
            fill: (tmp) async {
              tmp.writeAsBytesSync(data(5));
              throw FileSystemException(
                'write',
                tmp.path,
                const OSError('No space left on device', 28),
              );
            },
          ),
          throwsA(isA<GalleryStorageFull>()),
        );
        expect(leftovers(), isEmpty);
        expect(File('${pictures.path}/Storize/a/x.jpg').existsSync(), isFalse);
      },
    );

    test('another write failure carries a code and no path', () async {
      Object? caught;
      try {
        await priv.writeNew(
          relativeDir: 'a',
          displayName: 'x.jpg',
          fill: (tmp) async => throw FileSystemException(
            'boom',
            tmp.path,
            const OSError('denied', 13),
          ),
        );
      } on GalleryStoreException catch (e) {
        caught = e;
      }
      expect(caught, isA<GalleryWriteFailed>());
      expect(caught.toString(), isNot(contains(tmp.path)));
      expect((caught! as GalleryStoreException).code, 'IO_ERROR');
    });
  });

  group('addresses outside the private folder are never touched', () {
    test('exists/size/delete ignore them', () async {
      final outside = File('${tmp.path}/ext/Pictures/other.jpg')
        ..writeAsBytesSync(data(4));
      final viaDots = File('${tmp.path}/important.txt')
        ..writeAsBytesSync(data(4));
      final uris = [
        Uri.file(outside.path).toString(),
        '${Uri.file('${pictures.path}/Storize')}/../../../important.txt',
        Uri.file('${pictures.path}/Storize').toString(),
        'file://${viaDots.path}?x=1',
        'file://evil.example${viaDots.path}',
      ];
      for (final u in uris) {
        expect(await store.exists(u), isFalse, reason: u);
        expect(await store.size(u), isNull, reason: u);
        expect(await store.delete(u), isFalse, reason: u);
      }
      expect(outside.existsSync(), isTrue);
      expect(viaDots.existsSync(), isTrue);
    });

    test('a private store without PrivateFiles fails loudly', () async {
      final bare = PluginGalleryStore(native.api);
      await expectCode(
        bare.exists('file:///x/y.jpg'),
        'PRIVATE_UNAVAILABLE',
      );
      await expectCode(
        bare.save(
          sourcePath: source(data(2)),
          relativeDir: 'a',
          displayName: 'b.jpg',
          mime: 'image/jpeg',
          target: StorageTarget.private,
        ),
        'PRIVATE_UNAVAILABLE',
      );
    });
  });

  group('copyTo gallery -> private', () {
    test('copies the bytes, verifies, and leaves the original alone', () async {
      final g = await saveGallery(data(2000, 9));

      final copy = await store.copyTo(
        g.uri,
        to: StorageTarget.private,
        relativeDir: 'nour_k',
        displayName: 'g.jpg',
        mime: 'image/jpeg',
      );

      expect(storageTargetOf(copy.uri), StorageTarget.private);
      expect(copy.sizeBytes, 2000);
      expect(
        File('${pictures.path}/Storize/nour_k/g.jpg').readAsBytesSync(),
        data(2000, 9),
      );
      expect(native.rows, contains(g.uri), reason: 'original untouched');
      expect(
        native.calls.where((c) => c.method == 'delete'),
        isEmpty,
        reason: 'copyTo never deletes',
      );
      expect(leftovers(), isEmpty);
    });

    test(
      'a corrupted copy is VERIFY_FAILED, removed; original stays',
      () async {
        final g = await saveGallery(data(300, 5));
        native.corruptExport = true;
        await expectCode(
          store.copyTo(
            g.uri,
            to: StorageTarget.private,
            relativeDir: 'nour_k',
            displayName: 'g.jpg',
            mime: 'image/jpeg',
          ),
          'VERIFY_FAILED',
        );
        expect(
          File('${pictures.path}/Storize/nour_k/g.jpg').existsSync(),
          isFalse,
        );
        expect(leftovers(), isEmpty);
        expect(native.rows, contains(g.uri));
      },
    );

    test('a missing original is SOURCE_NOT_FOUND and leaves nothing', () async {
      await expectCode(
        store.copyTo(
          'content://media/external/images/media/999',
          to: StorageTarget.private,
          relativeDir: 'nour_k',
          displayName: 'g.jpg',
          mime: 'image/jpeg',
        ),
        'SOURCE_NOT_FOUND',
      );
      expect(leftovers(), isEmpty);
    });

    test('storage full during the export is GalleryStorageFull', () async {
      final g = await saveGallery(data(300));
      native.failMethod['exportToFile'] = PlatformException(
        code: 'STORAGE_FULL',
        message: '/data/x',
      );
      await expectLater(
        store.copyTo(
          g.uri,
          to: StorageTarget.private,
          relativeDir: 'nour_k',
          displayName: 'g.jpg',
          mime: 'image/jpeg',
        ),
        throwsA(isA<GalleryStorageFull>()),
      );
      expect(leftovers(), isEmpty);
      expect(native.rows, contains(g.uri));
    });

    test('the same target is refused', () async {
      final g = await saveGallery(data(3));
      await expectCode(
        store.copyTo(
          g.uri,
          to: StorageTarget.gallery,
          relativeDir: 'nour_k',
          displayName: 'g.jpg',
          mime: 'image/jpeg',
        ),
        'INVALID_ARGUMENT',
      );
    });
  });

  group('copyTo private -> gallery', () {
    test(
      'inserts, verifies size and hash, keeps the private original',
      () async {
        final p = await savePrivate(bytes: data(500, 3), name: 'x.jpg');

        final copy = await store.copyTo(
          p.uri,
          to: StorageTarget.gallery,
          relativeDir: 'nour_k',
          displayName: 'x.jpg',
          mime: 'image/jpeg',
        );

        expect(copy.uri, startsWith('content://media/'));
        expect(copy.sizeBytes, 500);
        expect(copy.relativePath, 'Pictures/Storize/nour_k/');
        expect(native.rows[copy.uri]?.bytes, data(500, 3));
        expect(await store.exists(p.uri), isTrue, reason: 'original untouched');
      },
    );

    test(
      'a bad gallery copy is deleted again and the original stays',
      () async {
        final p = await savePrivate(bytes: data(500, 3), name: 'x.jpg');
        native.corruptInsert = true;
        await expectCode(
          store.copyTo(
            p.uri,
            to: StorageTarget.gallery,
            relativeDir: 'nour_k',
            displayName: 'x.jpg',
            mime: 'image/jpeg',
          ),
          'VERIFY_FAILED',
        );
        expect(native.rows, isEmpty, reason: 'the bad copy was removed');
        expect(await store.exists(p.uri), isTrue);
      },
    );

    test('a refused insert keeps the original and maps the error', () async {
      final p = await savePrivate(name: 'x.jpg');
      native.failMethod['insert'] = PlatformException(
        code: 'STORAGE_FULL',
        message: '/data/x',
      );
      await expectLater(
        store.copyTo(
          p.uri,
          to: StorageTarget.gallery,
          relativeDir: 'nour_k',
          displayName: 'x.jpg',
          mime: 'image/jpeg',
        ),
        throwsA(isA<GalleryStorageFull>()),
      );
      expect(await store.exists(p.uri), isTrue);
    });

    test('a missing private original is SOURCE_NOT_FOUND', () async {
      final p = await savePrivate(name: 'x.jpg');
      await store.delete(p.uri);
      await expectCode(
        store.copyTo(
          p.uri,
          to: StorageTarget.gallery,
          relativeDir: 'nour_k',
          displayName: 'x.jpg',
          mime: 'image/jpeg',
        ),
        'SOURCE_NOT_FOUND',
      );
      expect(native.rows, isEmpty);
    });
  });

  group('move', () {
    test('copies, verifies, then deletes the original', () async {
      final g = await saveGallery(data(64, 2));
      native.calls.clear();

      final moved = await store.move(
        g.uri,
        to: StorageTarget.private,
        relativeDir: 'nour_k',
        displayName: 'g.jpg',
        mime: 'image/jpeg',
      );

      expect(native.calls.map((c) => c.method), ['exportToFile', 'delete']);
      expect(native.rows, isEmpty);
      expect(await store.exists(moved.uri), isTrue);
      expect(await store.exists(g.uri), isFalse);
    });

    test('a failed copy deletes nothing', () async {
      final g = await saveGallery(data(64, 2));
      native.corruptExport = true;
      native.calls.clear();
      await expectCode(
        store.move(
          g.uri,
          to: StorageTarget.private,
          relativeDir: 'nour_k',
          displayName: 'g.jpg',
          mime: 'image/jpeg',
        ),
        'VERIFY_FAILED',
      );
      expect(native.calls.map((c) => c.method), ['exportToFile']);
      expect(native.rows, contains(g.uri));
    });

    test('a failed delete of the original keeps the verified copy', () async {
      final g = await saveGallery(data(64, 2));
      native.failMethod['delete'] = PlatformException(code: 'IO_ERROR');

      final moved = await store.move(
        g.uri,
        to: StorageTarget.private,
        relativeDir: 'nour_k',
        displayName: 'g.jpg',
        mime: 'image/jpeg',
      );

      expect(await store.exists(moved.uri), isTrue);
      expect(native.rows, contains(g.uri), reason: 'leftover, not lost');
    });

    test('private -> gallery and back preserves the content', () async {
      final p = await savePrivate(bytes: data(80, 4), name: 'r.jpg');
      final g = await store.move(
        p.uri,
        to: StorageTarget.gallery,
        relativeDir: 'nour_k',
        displayName: 'r.jpg',
        mime: 'image/jpeg',
      );
      expect(await store.exists(p.uri), isFalse);
      final back = await store.move(
        g.uri,
        to: StorageTarget.private,
        relativeDir: 'nour_k',
        displayName: 'r.jpg',
        mime: 'image/jpeg',
      );
      expect(await store.readBytes(back.uri), data(80, 4));
      expect(native.rows, isEmpty);
    });
  });

  group('readBytes', () {
    test(
      'reads private and gallery files, null when missing or too big',
      () async {
        final p = await savePrivate(bytes: data(10, 6));
        final g = await saveGallery(data(12, 8));
        expect(await store.readBytes(p.uri), data(10, 6));
        expect(await store.readBytes(g.uri), data(12, 8));
        expect(await store.readBytes(p.uri, maxBytes: 5), isNull);
        await store.delete(p.uri);
        expect(await store.readBytes(p.uri), isNull);
        expect(await store.readBytes('file:///etc/passwd'), isNull);
      },
    );
  });

  test('PlatformException from export carries no path out', () async {
    final g = await saveGallery(data(9));
    native.failMethod['exportToFile'] = PlatformException(
      code: 'IO_ERROR',
      message: '/storage/emulated/0/Android/data/x/secret.jpg',
    );
    Object? caught;
    try {
      await store.copyTo(
        g.uri,
        to: StorageTarget.private,
        relativeDir: 'nour_k',
        displayName: 'g.jpg',
        mime: 'image/jpeg',
      );
    } on GalleryStoreException catch (e) {
      caught = e;
    }
    expect(caught, isA<GalleryWriteFailed>());
    expect(caught.toString(), isNot(contains('secret')));
    expect(StorizePlatformErrorKind.ioError.code, 'IO_ERROR');
  });

  group('QA symlinks', () {
    test(
      'a symlinked folder inside the root cannot reach outside files',
      () async {
        final outsideDir = Directory('${tmp.path}/outside')..createSync();
        final victim = File('${outsideDir.path}/victim.jpg')
          ..writeAsBytesSync(data(4));
        final root = await priv.root();
        Link('${root.path}/evil').createSync(outsideDir.path);
        final uri = Uri.file('${root.path}/evil/victim.jpg').toString();
        await store.delete(uri);
        expect(victim.existsSync(), isTrue, reason: 'symlink escape');
      },
    );

    test('a symlinked file is only unlinked, target survives', () async {
      final victim = File('${tmp.path}/victim2.jpg')..writeAsBytesSync(data(4));
      final root = await priv.root();
      Link('${root.path}/l.jpg').createSync(victim.path);
      await store.delete(Uri.file('${root.path}/l.jpg').toString());
      expect(victim.existsSync(), isTrue);
    });
  });

  test(
    'QA: .nomedia exists at the root and content:// never hits disk',
    () async {
      await savePrivate();
      expect(File('${pictures.path}/Storize/.nomedia').existsSync(), isTrue);
      for (final u in [
        'content://media/external/images/media/5',
        'garbage',
        '',
      ]) {
        expect(await store.exists(u), isFalse);
      }
    },
  );
}
