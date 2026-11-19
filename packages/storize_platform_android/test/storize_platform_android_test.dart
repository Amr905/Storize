import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

typedef Handler = Future<Object?> Function(MethodCall call);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> mediaCalls;
  late List<MethodCall> systemCalls;
  late StorizePlatformAndroid api;

  void mockMedia(Handler handler) {
    messenger.setMockMethodCallHandler(storizeMediaChannel, (call) {
      mediaCalls.add(call);
      return handler(call);
    });
  }

  void mockSystem(Handler handler) {
    messenger.setMockMethodCallHandler(storizeSystemChannel, (call) {
      systemCalls.add(call);
      return handler(call);
    });
  }

  setUp(() {
    mediaCalls = [];
    systemCalls = [];
    api = StorizePlatformAndroid();
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(storizeMediaChannel, null)
      ..setMockMethodCallHandler(storizeSystemChannel, null);
  });

  group('channels', () {
    test('use the agreed names and the standard codec', () {
      expect(storizeMediaChannel.name, 'storize/media');
      expect(storizeSystemChannel.name, 'storize/system');
      expect(storizeMediaChannel.codec, isA<StandardMethodCodec>());
      expect(storizePlatformAndroidVersion, isNotEmpty);
    });
  });

  group('insert', () {
    test('encodes arguments and decodes the result', () async {
      mockMedia(
        (_) async => {
          'uri': 'content://media/external/images/media/42',
          'size': 1234,
          'relativePath': 'Pictures/Storize/nour_k/',
        },
      );
      final result = await api.insert(
        sourcePath: '/cache/a.part',
        relativeDir: 'nour_k',
        displayName: 'nour_k_1.jpg',
        mime: 'image/jpeg',
      );
      expect(mediaCalls.single.method, 'insert');
      expect(mediaCalls.single.arguments, {
        'sourcePath': '/cache/a.part',
        'relativeDir': 'nour_k',
        'displayName': 'nour_k_1.jpg',
        'mime': 'image/jpeg',
      });
      expect(result.uri, 'content://media/external/images/media/42');
      expect(result.size, 1234);
      expect(result.relativePath, 'Pictures/Storize/nour_k/');
    });

    test('relativePath is optional', () async {
      mockMedia((_) async => {'uri': 'file:///x.jpg', 'size': 1});
      final result = await api.insert(
        sourcePath: '/a',
        relativeDir: 'd',
        displayName: 'x.jpg',
        mime: 'image/jpeg',
      );
      expect(result.relativePath, isNull);
    });

    test('a malformed result is a badResponse error', () async {
      mockMedia((_) async => {'uri': 5});
      await expectLater(
        api.insert(
          sourcePath: '/a',
          relativeDir: 'd',
          displayName: 'x.jpg',
          mime: 'image/jpeg',
        ),
        throwsA(
          isA<StorizePlatformException>().having(
            (e) => e.kind,
            'kind',
            StorizePlatformErrorKind.badResponse,
          ),
        ),
      );
    });
  });

  group('delete / exists / size', () {
    test('delete sends the uri and returns the bool', () async {
      mockMedia((_) async => true);
      expect(await api.delete('content://media/x/1'), isTrue);
      expect(mediaCalls.single.method, 'delete');
      expect(mediaCalls.single.arguments, {'uri': 'content://media/x/1'});
    });

    test('delete returns false for a missing file', () async {
      mockMedia((_) async => false);
      expect(await api.delete('content://media/x/1'), isFalse);
    });

    test('exists sends the uri and returns the bool', () async {
      mockMedia((_) async => false);
      expect(await api.exists('content://media/x/2'), isFalse);
      expect(mediaCalls.single.method, 'exists');
      expect(mediaCalls.single.arguments, {'uri': 'content://media/x/2'});
    });

    test('size returns bytes, or null when missing', () async {
      mockMedia((_) async => 99);
      expect(await api.size('content://media/x/3'), 99);
      mockMedia((_) async => null);
      expect(await api.size('content://media/x/3'), isNull);
      expect(mediaCalls.first.method, 'size');
    });

    test('a null bool is a badResponse error', () async {
      mockMedia((_) async => null);
      await expectLater(
        api.exists('content://media/x/2'),
        throwsA(isA<StorizePlatformException>()),
      );
    });
  });

  group('videoThumbnail', () {
    test('sends the path and default maxSize, returns bytes', () async {
      final webp = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]);
      mockMedia((_) async => webp);
      final bytes = await api.videoThumbnail(path: '/cache/v.mp4');
      expect(bytes, webp);
      expect(mediaCalls.single.method, 'videoThumbnail');
      expect(mediaCalls.single.arguments, {
        'path': '/cache/v.mp4',
        'maxSize': 512,
      });
    });

    test('sends the uri and a custom maxSize', () async {
      mockMedia((_) async => Uint8List(1));
      await api.videoThumbnail(uri: 'content://media/v/1', maxSize: 256);
      expect(mediaCalls.single.arguments, {
        'uri': 'content://media/v/1',
        'maxSize': 256,
      });
    });

    test('needs exactly one of uri or path', () async {
      await expectLater(api.videoThumbnail(), throwsArgumentError);
      await expectLater(
        api.videoThumbnail(uri: 'a', path: 'b'),
        throwsArgumentError,
      );
      expect(mediaCalls, isEmpty);
    });
  });

  group('system channel', () {
    test('isIgnoringBatteryOptimizations', () async {
      mockSystem((_) async => true);
      expect(await api.isIgnoringBatteryOptimizations(), isTrue);
      expect(systemCalls.single.method, 'isIgnoringBatteryOptimizations');
    });

    test('openBatterySettings passes oem and decodes each target', () async {
      final answers = <String, BatterySettingsTarget>{
        'request_ignore': BatterySettingsTarget.requestIgnore,
        'oem_xiaomi': BatterySettingsTarget.oemScreen,
        'app_details': BatterySettingsTarget.appDetails,
        'none': BatterySettingsTarget.none,
      };
      for (final entry in answers.entries) {
        systemCalls.clear();
        mockSystem((_) async => entry.key);
        final outcome = await api.openBatterySettings(oem: 'xiaomi');
        expect(systemCalls.single.method, 'openBatterySettings');
        expect(systemCalls.single.arguments, {'oem': 'xiaomi'});
        expect(outcome.target, entry.value);
        expect(outcome.raw, entry.key);
        expect(outcome.opened, entry.value != BatterySettingsTarget.none);
      }
    });

    test('openBatterySettings without oem sends no oem key', () async {
      mockSystem((_) async => 'app_details');
      await api.openBatterySettings();
      expect(systemCalls.single.arguments, <String, Object?>{});
    });

    test('an unknown openBatterySettings answer is badResponse', () async {
      mockSystem((_) async => 'weird');
      await expectLater(
        api.openBatterySettings(),
        throwsA(
          isA<StorizePlatformException>().having(
            (e) => e.kind,
            'kind',
            StorizePlatformErrorKind.badResponse,
          ),
        ),
      );
    });

    test('manufacturer', () async {
      mockSystem((_) async => 'samsung');
      expect(await api.manufacturer(), 'samsung');
    });

    test('lastStopReasons decodes entries and sends the limit', () async {
      mockSystem(
        (_) async => [
          {'workName': 'process', 'reason': 'LOW_MEMORY', 'timestampMs': 5},
          {'workName': 'process', 'reason': 'USER_REQUESTED'},
        ],
      );
      final reasons = await api.lastStopReasons(limit: 3);
      expect(systemCalls.single.arguments, {'limit': 3});
      expect(reasons, hasLength(2));
      expect(reasons.first.reason, 'LOW_MEMORY');
      expect(reasons.first.timestampMs, 5);
      expect(reasons.last.workName, 'process');
      expect(reasons.last.timestampMs, isNull);
    });

    test('lastStopReasons returns an empty list below API 30', () async {
      mockSystem((_) async => <Object?>[]);
      expect(await api.lastStopReasons(), isEmpty);
    });

    test('lastStopReasons rejects a malformed entry', () async {
      mockSystem((_) async => ['nope']);
      await expectLater(
        api.lastStopReasons(),
        throwsA(isA<StorizePlatformException>()),
      );
    });
  });

  group('error mapping', () {
    const codes = {
      'INVALID_ARGUMENT': StorizePlatformErrorKind.invalidArgument,
      'UNSUPPORTED_MIME': StorizePlatformErrorKind.unsupportedMime,
      'SOURCE_NOT_FOUND': StorizePlatformErrorKind.sourceNotFound,
      'PERMISSION_DENIED': StorizePlatformErrorKind.permissionDenied,
      'STORAGE_FULL': StorizePlatformErrorKind.storageFull,
      'IO_ERROR': StorizePlatformErrorKind.ioError,
      'INSERT_FAILED': StorizePlatformErrorKind.insertFailed,
      'THUMBNAIL_FAILED': StorizePlatformErrorKind.thumbnailFailed,
      'UNAVAILABLE': StorizePlatformErrorKind.unavailable,
      'UNKNOWN': StorizePlatformErrorKind.unknown,
    };

    for (final entry in codes.entries) {
      test('${entry.key} maps to ${entry.value.name}', () async {
        mockMedia(
          (_) async =>
              throw PlatformException(code: entry.key, message: 'boom'),
        );
        await expectLater(
          api.exists('content://media/x/1'),
          throwsA(
            isA<StorizePlatformException>()
                .having((e) => e.code, 'code', entry.key)
                .having((e) => e.message, 'message', 'boom')
                .having((e) => e.kind, 'kind', entry.value),
          ),
        );
      });
    }

    test('an unrecognised code maps to unknown but keeps the raw code', () {
      const e = StorizePlatformException('SOMETHING_NEW', 'x');
      expect(e.kind, StorizePlatformErrorKind.unknown);
      expect(e.code, 'SOMETHING_NEW');
      expect(e.toString(), contains('SOMETHING_NEW'));
    });

    test('errors also map on the system channel', () async {
      mockSystem(
        (_) async => throw PlatformException(code: 'UNKNOWN', message: 'x'),
      );
      await expectLater(
        api.manufacturer(),
        throwsA(isA<StorizePlatformException>()),
      );
    });

    test('a missing native side maps to unavailable', () async {
      // No handler registered: the binding answers with MissingPluginException.
      await expectLater(
        api.exists('content://media/x/1'),
        throwsA(
          isA<StorizePlatformException>().having(
            (e) => e.kind,
            'kind',
            StorizePlatformErrorKind.unavailable,
          ),
        ),
      );
    });
  });

  group('plugin manifest (AC 7)', () {
    late String manifest;
    setUp(() {
      manifest = File('android/src/main/AndroidManifest.xml')
          .readAsStringSync();
    });

    test('exports no components', () {
      for (final tag in ['activity', 'service', 'receiver', 'provider']) {
        expect(manifest, isNot(contains('<$tag')), reason: tag);
      }
      expect(manifest, isNot(contains('android:exported="true"')));
    });

    test('declares the battery permission', () {
      expect(
        manifest,
        contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
      );
    });

    test('limits WRITE_EXTERNAL_STORAGE to API 28', () {
      final match = RegExp(
        r'WRITE_EXTERNAL_STORAGE"\s+android:maxSdkVersion="28"',
      );
      expect(match.hasMatch(manifest), isTrue);
    });
  });
}
