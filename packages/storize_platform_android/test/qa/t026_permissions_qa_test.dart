// QA (T-026): permission methods, wrong-typed answers and error text.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final api = StorizePlatformAndroid();
  void system(Future<Object?> Function(MethodCall) h) =>
      messenger.setMockMethodCallHandler(storizeSystemChannel, h);
  tearDown(
    () => messenger.setMockMethodCallHandler(storizeSystemChannel, null),
  );

  for (final bad in <Object?>[null, 'true', 1, 'granted']) {
    test('checkPermission rejects non-bool $bad', () async {
      system((_) async => bad);
      await expectLater(
        api.checkPermission('POST_NOTIFICATIONS'),
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

  for (final bad in <Object?>[null, true, 0, 'GRANTED', 'permanently_denied']) {
    test('requestPermission rejects answer $bad', () async {
      system((_) async => bad);
      await expectLater(
        api.requestPermission('WRITE_EXTERNAL_STORAGE'),
        throwsA(isA<StorizePlatformException>()),
      );
    });
  }

  test('openAppSettings passes false through and rejects non-bool', () async {
    system((_) async => false);
    expect(await api.openAppSettings(), isFalse);
    system((_) async => 'ok');
    await expectLater(
      api.openAppSettings(),
      throwsA(isA<StorizePlatformException>()),
    );
  });

  test('rejected permission name: typed error, no detail in text', () async {
    system(
      (_) async => throw PlatformException(
        code: 'INVALID_ARGUMENT',
        message: 'Unsupported permission',
        details: 'sessionid=SECRET',
      ),
    );
    try {
      await api.checkPermission('CAMERA');
      fail('should throw');
    } on StorizePlatformException catch (e) {
      expect(e.kind, StorizePlatformErrorKind.invalidArgument);
      expect(e.toString(), isNot(contains('SECRET')));
      expect(e.toString(), isNot(contains('CAMERA')));
    }
  });

  test(
    'missing native side is "unavailable", never an uncaught throw',
    () async {
      await expectLater(
        api.requestPermission('POST_NOTIFICATIONS'),
        throwsA(
          isA<StorizePlatformException>().having(
            (e) => e.kind,
            'kind',
            StorizePlatformErrorKind.unavailable,
          ),
        ),
      );
    },
  );
}
