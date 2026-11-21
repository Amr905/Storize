import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('storize/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mock(Future<Object?> Function(MethodCall) handler) {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  final api = StorizePlatformAndroid();

  test('sends the uri and the default 30 MB cap, returns the bytes', () async {
    mock((_) async => Uint8List.fromList([1, 2, 3]));
    final bytes = await api.readBytes('content://media/x/5');

    expect(calls.single.method, 'readBytes');
    expect(calls.single.arguments, {
      'uri': 'content://media/x/5',
      'maxBytes': 30 * 1024 * 1024,
    });
    expect(bytes, [1, 2, 3]);
  });

  test('passes a custom cap', () async {
    mock((_) async => null);
    await api.readBytes('content://media/x/5', maxBytes: 10);
    expect((calls.single.arguments as Map)['maxBytes'], 10);
  });

  test('null means missing, not owned or over the cap', () async {
    mock((_) async => null);
    expect(await api.readBytes('content://media/x/5'), isNull);
  });

  test('a wrong-typed answer is a bad response', () async {
    mock((_) async => 'nope');
    expect(
      api.readBytes('content://media/x/5'),
      throwsA(isA<StorizePlatformException>()),
    );
  });

  test('a native error becomes a typed exception without the uri', () async {
    mock((_) async => throw PlatformException(code: 'IO_ERROR', message: 'x'));
    await expectLater(
      api.readBytes('content://media/x/5'),
      throwsA(
        isA<StorizePlatformException>().having(
          (e) => e.toString(),
          'text',
          isNot(contains('content://')),
        ),
      ),
    );
  });

  test('a non-positive cap is rejected before any call', () {
    mock((_) async => null);
    expect(
      () => api.readBytes('content://media/x/5', maxBytes: 0),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });
}
