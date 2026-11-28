import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> pushText(Object? text) => messenger.handlePlatformMessage(
    storizeShareInChannelName,
    const StandardMethodCodec().encodeMethodCall(MethodCall('onText', text)),
    (_) {},
  );

  test('initialText returns the launch text once the plugin answers', () async {
    messenger.setMockMethodCallHandler(storizeShareInChannel, (call) async {
      expect(call.method, 'initialText');
      return 'https://www.instagram.com/p/ZZFAKE_c1/';
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(storizeShareInChannel, null),
    );
    expect(
      await ShareIntentSource().initialText(),
      'https://www.instagram.com/p/ZZFAKE_c1/',
    );
  });

  test('no text, blank text, no plugin and a native error are null', () async {
    final source = ShareIntentSource();
    expect(await source.initialText(), isNull, reason: 'no plugin');
    for (final answer in <Object?>[null, '   ']) {
      messenger.setMockMethodCallHandler(
        storizeShareInChannel,
        (_) async => answer,
      );
      expect(await source.initialText(), isNull);
    }
    messenger.setMockMethodCallHandler(
      storizeShareInChannel,
      (_) async => throw PlatformException(code: 'x'),
    );
    expect(await source.initialText(), isNull);
    addTearDown(
      () => messenger.setMockMethodCallHandler(storizeShareInChannel, null),
    );
  });

  test('texts emits what the platform pushes and ignores junk', () async {
    final source = ShareIntentSource();
    final seen = <String>[];
    final sub = source.texts.listen(seen.add);
    addTearDown(sub.cancel);
    await pushText('https://www.instagram.com/p/ZZFAKE_c2/');
    await pushText('  ');
    await pushText(42);
    await pushText(null);
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['https://www.instagram.com/p/ZZFAKE_c2/']);
  });
}
