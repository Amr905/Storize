import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_model/storize_model.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

import 'fake_native_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late FakeNativeMedia native;
  late PluginGalleryStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('storize_gallery_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    native = FakeNativeMedia();
    store = PluginGalleryStore(native.api);
  });

  String source([int bytes = 10, String name = 'a.part']) {
    final f = File('${tmp.path}/$name')
      ..writeAsBytesSync(List.filled(bytes, 7));
    return f.path;
  }

  Future<GalleryFile> save({
    String? path,
    String dir = 'nour_k',
    String name = 'nour_k_20260307_040509_1.jpg',
    String mime = 'image/jpeg',
  }) => store.save(
    sourcePath: path ?? source(),
    relativeDir: dir,
    displayName: name,
    mime: mime,
  );

  group('save', () {
    test('passes the arguments through and maps the result', () async {
      final path = source(42);
      final file = await store.save(
        sourcePath: path,
        relativeDir: 'nour_k',
        displayName: 'nour_k_20260307_040509_1.jpg',
        mime: 'image/jpeg',
      );
      expect(native.calls.single.method, 'insert');
      expect(native.calls.single.arguments, {
        'sourcePath': path,
        'relativeDir': 'nour_k',
        'displayName': 'nour_k_20260307_040509_1.jpg',
        'mime': 'image/jpeg',
      });
      expect(file.uri, startsWith('content://media/'));
      expect(file.sizeBytes, 42);
      expect(file.relativePath, 'Pictures/Storize/nour_k/');
      expect(file.displayName, 'nour_k_20260307_040509_1.jpg');
      expect(File(path).existsSync(), isTrue, reason: 'source is kept');
    });

    test('reports the Movies fallback folder for a video', () async {
      native.videoFallsBackToMovies = true;
      final file = await save(name: 'v.mp4', mime: 'video/mp4');
      expect(file.relativePath, 'Movies/Storize/nour_k/');
    });

    test('reports the renamed display name on a collision', () async {
      final a = await save(name: 'dup.jpg');
      final b = await save(name: 'dup.jpg');
      final c = await save(name: 'dup.jpg');
      expect(a.displayName, 'dup.jpg');
      expect(b.displayName, 'dup (1).jpg');
      expect(c.displayName, 'dup (2).jpg');
      expect({a.uri, b.uri, c.uri}, hasLength(3));
    });

    test(
      'falls back to the requested folder when the plugin omits it',
      () async {
        native.omitRelativePath = true;
        final file = await save();
        expect(file.relativePath, 'Pictures/Storize/nour_k/');
      },
    );

    test('names built by the helpers are accepted end to end', () async {
      final file = await store.save(
        sourcePath: source(),
        relativeDir: relativeDirFor('..weird/\u202Euser:'),
        displayName: displayNameFor(
          username: '..weird/\u202Euser:',
          postedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
          remoteId: '99',
          slideIndex: 2,
          ext: 'jpg',
        ),
        mime: 'image/jpeg',
      );
      expect(file.displayName, endsWith('_20260102_030405_99_2.jpg'));
    });
  });

  group('save errors', () {
    Future<Object> failWith(String code, [String? message]) async {
      native.failNext = PlatformException(code: code, message: message);
      try {
        await save();
      } on Object catch (e) {
        return e;
      }
      fail('save did not throw for $code');
    }

    test('PERMISSION_DENIED -> GalleryPermissionDenied', () async {
      expect(
        await failWith('PERMISSION_DENIED'),
        isA<GalleryPermissionDenied>(),
      );
    });

    test('STORAGE_FULL -> GalleryStorageFull', () async {
      expect(await failWith('STORAGE_FULL'), isA<GalleryStorageFull>());
    });

    test('other codes -> GalleryWriteFailed with the code only', () async {
      for (final code in [
        'INVALID_ARGUMENT',
        'UNSUPPORTED_MIME',
        'SOURCE_NOT_FOUND',
        'IO_ERROR',
        'INSERT_FAILED',
        'SOMETHING_NEW',
      ]) {
        final e = await failWith(code, '/data/user/0/app/cache/part/1.part');
        expect(e, isA<GalleryWriteFailed>(), reason: code);
        expect((e as GalleryWriteFailed).code, code);
        expect(e.toString(), isNot(contains('/data')));
        expect(e.toString(), isNot(contains('.part')));
      }
    });

    test('a missing plugin -> GalleryWriteFailed(UNAVAILABLE)', () async {
      final bare = PluginGalleryStore(
        StorizePlatformAndroid(media: const MethodChannel('storize/nobody')),
      );
      await expectLater(
        bare.save(
          sourcePath: source(),
          relativeDir: 'x',
          displayName: 'x.jpg',
          mime: 'image/jpeg',
        ),
        throwsA(
          isA<GalleryWriteFailed>().having(
            (e) => e.code,
            'code',
            'UNAVAILABLE',
          ),
        ),
      );
    });

    test('an invalid name from the caller is rejected by the plugin', () async {
      await expectLater(
        save(name: 'a/b.jpg'),
        throwsA(
          isA<GalleryWriteFailed>().having(
            (e) => e.code,
            'code',
            'INVALID_ARGUMENT',
          ),
        ),
      );
      expect(native.rows, isEmpty);
    });
  });

  group('delete, exists, size', () {
    test('lifecycle with the URI returned by save', () async {
      final file = await save(path: source(5));
      expect(await store.exists(file.uri), isTrue);
      expect(await store.size(file.uri), 5);
      expect(await store.delete(file.uri), isTrue);
      expect(await store.exists(file.uri), isFalse);
      expect(await store.size(file.uri), isNull);
      expect(await store.delete(file.uri), isFalse);
    });

    test('SOURCE_NOT_FOUND is false/null, not an error', () async {
      for (final run in <Future<Object?> Function()>[
        () => store.delete('content://media/external/images/media/9'),
        () => store.exists('content://media/external/images/media/9'),
        () => store.size('content://media/external/images/media/9'),
      ]) {
        native.failNext = PlatformException(code: 'SOURCE_NOT_FOUND');
        final r = await run();
        expect(r == false || r == null, isTrue);
      }
    });

    test('delete PERMISSION_DENIED -> GalleryPermissionDenied', () async {
      native.failNext = PlatformException(code: 'PERMISSION_DENIED');
      await expectLater(
        store.delete('content://media/external/images/media/1'),
        throwsA(isA<GalleryPermissionDenied>()),
      );
    });

    test('other failures -> GalleryWriteFailed(code)', () async {
      native.failNext = PlatformException(code: 'INVALID_ARGUMENT');
      await expectLater(
        store.exists('content://media/0'),
        throwsA(isA<GalleryWriteFailed>()),
      );
      native.failNext = PlatformException(code: 'IO_ERROR');
      await expectLater(
        store.size('content://media/external/images/media/1'),
        throwsA(isA<GalleryWriteFailed>()),
      );
    });
  });
}
