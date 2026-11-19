// QA (T-009): wrong-typed channel results, unknown outcome strings and error
// mapping edge cases. Complements storize_platform_android_test.dart.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final api = StorizePlatformAndroid();

  void media(Future<Object?> Function(MethodCall) h) =>
      messenger.setMockMethodCallHandler(storizeMediaChannel, h);
  void system(Future<Object?> Function(MethodCall) h) =>
      messenger.setMockMethodCallHandler(storizeSystemChannel, h);

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(storizeMediaChannel, null)
      ..setMockMethodCallHandler(storizeSystemChannel, null);
  });

  group('BatterySettingsOutcome.parse', () {
    for (final bad in <String?>[
      null,
      '',
      ' none',
      'NONE',
      'OEM_xiaomi',
      'request_ignore ',
      'app-details',
      'unknown',
    ]) {
      test('rejects ${bad == null ? 'null' : "'$bad'"}', () {
        expect(
          () => BatterySettingsOutcome.parse(bad),
          throwsA(
            isA<StorizePlatformException>().having(
              (e) => e.kind,
              'kind',
              StorizePlatformErrorKind.badResponse,
            ),
          ),
        );
      });
    }

    test('an empty oem_ suffix still counts as an OEM screen', () {
      final o = BatterySettingsOutcome.parse('oem_');
      expect(o.target, BatterySettingsTarget.oemScreen);
      expect(o.opened, isTrue);
    });

    test('none is not opened', () {
      expect(BatterySettingsOutcome.parse('none').opened, isFalse);
    });
  });

  group('wrong-typed results', () {
    test('insert: size as string is badResponse', () async {
      media((_) async => {'uri': 'content://media/x', 'size': '12'});
      await expectLater(
        api.insert(
          sourcePath: '/a',
          relativeDir: 'd',
          displayName: 'n.jpg',
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

    test('insert: null result is badResponse', () async {
      media((_) async => null);
      await expectLater(
        api.insert(
          sourcePath: '/a',
          relativeDir: 'd',
          displayName: 'n.jpg',
          mime: 'image/jpeg',
        ),
        throwsA(isA<StorizePlatformException>()),
      );
    });

    test('insert: non-String relativePath is ignored, not fatal', () async {
      media(
        (_) async => {'uri': 'content://media/x', 'size': 1, 'relativePath': 5},
      );
      final r = await api.insert(
        sourcePath: '/a',
        relativeDir: 'd',
        displayName: 'n.jpg',
        mime: 'image/jpeg',
      );
      expect(r.relativePath, isNull);
    });

    test('lastStopReasons: null list is badResponse', () async {
      system((_) async => null);
      await expectLater(
        api.lastStopReasons(),
        throwsA(isA<StorizePlatformException>()),
      );
    });

    test('lastStopReasons: timestamp of wrong type becomes null', () async {
      system(
        (_) async => [
          {'workName': 'process', 'reason': 'CRASH', 'timestampMs': 'x'},
        ],
      );
      final list = await api.lastStopReasons();
      expect(list.single.timestampMs, isNull);
    });

    test('manufacturer: null is badResponse', () async {
      system((_) async => null);
      await expectLater(
        api.manufacturer(),
        throwsA(isA<StorizePlatformException>()),
      );
    });

    test('videoThumbnail: null is badResponse', () async {
      media((_) async => null);
      await expectLater(
        api.videoThumbnail(path: '/v.mp4'),
        throwsA(isA<StorizePlatformException>()),
      );
    });

    // Documents a gap: invokeMethod<T> casts the result, so a wrong runtime
    // type escapes as a TypeError instead of a StorizePlatformException.
    test('size: a String result escapes as a non-plugin error (gap)', () async {
      media((_) async => 'oops');
      await expectLater(
        api.size('content://media/x'),
        throwsA(isNot(isA<StorizePlatformException>())),
      );
    });

    test(
      'delete: a String result escapes as a non-plugin error (gap)',
      () async {
        media((_) async => 'oops');
        await expectLater(
          api.delete('content://media/x'),
          throwsA(isNot(isA<StorizePlatformException>())),
        );
      },
    );
  });

  group('errors', () {
    test('a null message is preserved as null', () async {
      media((_) async => throw PlatformException(code: 'IO_ERROR'));
      await expectLater(
        api.exists('content://media/x'),
        throwsA(
          isA<StorizePlatformException>()
              .having((e) => e.kind, 'kind', StorizePlatformErrorKind.ioError)
              .having((e) => e.message, 'message', isNull),
        ),
      );
    });

    test('codes are case sensitive', () {
      expect(
        StorizePlatformErrorKind.fromCode('io_error'),
        StorizePlatformErrorKind.unknown,
      );
    });

    test('every kind round-trips through its code', () {
      for (final k in StorizePlatformErrorKind.values) {
        expect(StorizePlatformErrorKind.fromCode(k.code), k);
      }
    });
  });
}
