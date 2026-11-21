import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final api = StorizePlatformAndroid();
  late List<MethodCall> calls;

  void mock(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(storizeSystemChannel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(() => calls = []);
  tearDown(
    () => messenger.setMockMethodCallHandler(storizeSystemChannel, null),
  );

  test('sdkInt returns the level', () async {
    mock((_) async => 34);
    expect(await api.sdkInt(), 34);
    expect(calls.single.method, 'sdkInt');
  });

  for (final bad in <Object?>[null, 'x', 0, -1]) {
    test('sdkInt rejects $bad', () async {
      mock((_) async => bad);
      await expectLater(
        api.sdkInt(),
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

  for (final entry in {
    'granted': PermissionStatus.granted,
    'denied': PermissionStatus.denied,
    'permanentlyDenied': PermissionStatus.permanentlyDenied,
  }.entries) {
    test('requestPermission maps ${entry.key}', () async {
      mock((_) async => entry.key);
      expect(await api.requestPermission('POST_NOTIFICATIONS'), entry.value);
      expect(calls.single.method, 'requestPermission');
      expect(calls.single.arguments, {'name': 'POST_NOTIFICATIONS'});
    });
  }

  test('requestPermission rejects an unknown answer', () async {
    mock((_) async => 'maybe');
    await expectLater(
      api.requestPermission('POST_NOTIFICATIONS'),
      throwsA(isA<StorizePlatformException>()),
    );
  });

  test('native error for a name outside the allowlist is typed', () async {
    mock((_) async => throw PlatformException(code: 'INVALID_ARGUMENT'));
    await expectLater(
      api.requestPermission('CAMERA'),
      throwsA(
        isA<StorizePlatformException>().having(
          (e) => e.kind,
          'kind',
          StorizePlatformErrorKind.invalidArgument,
        ),
      ),
    );
  });

  test('a missing plugin is unavailable, not a crash', () async {
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
  });

  test('checkPermission sends the name and needs a bool', () async {
    mock((_) async => true);
    expect(await api.checkPermission('WRITE_EXTERNAL_STORAGE'), isTrue);
    expect(calls.single.arguments, {'name': 'WRITE_EXTERNAL_STORAGE'});
    mock((_) async => 'yes');
    await expectLater(
      api.checkPermission('POST_NOTIFICATIONS'),
      throwsA(isA<StorizePlatformException>()),
    );
  });

  test('openAppSettings returns the native answer', () async {
    mock((_) async => false);
    expect(await api.openAppSettings(), isFalse);
    expect(calls.single.method, 'openAppSettings');
  });
}
