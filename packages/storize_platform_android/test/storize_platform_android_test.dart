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

  test('media channel is a method channel with the standard codec', () {
    expect(storizeMediaChannel.codec, isA<StandardMethodCodec>());
    expect(storizeMediaChannelName, 'storize/media');
  });
}
