import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exposes a version constant', () {
    expect(storizePlatformAndroidVersion, isNotEmpty);
  });

  test('media channel uses the agreed name', () {
    expect(storizeMediaChannel.name, 'storize/media');
  });

  test('placeholder channel reports notImplemented', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storizeMediaChannel,
          (call) async => throw MissingPluginException(),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storizeMediaChannel, null),
    );
    await expectLater(
      storizeMediaChannel.invokeMethod<void>('anything'),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
