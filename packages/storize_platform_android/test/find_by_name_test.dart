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

  test('sends the folder and name and maps the answer', () async {
    mock(
      (_) async => {
        'uri': 'content://media/x/5',
        'size': 12,
        'displayName': 'a.jpg',
        'relativePath': 'Pictures/Storize/u/',
      },
    );
    final found = await api.findByName(relativeDir: 'u', displayName: 'a.jpg');

    expect(calls.single.method, 'findByName');
    expect(calls.single.arguments, {
      'relativeDir': 'u',
      'displayName': 'a.jpg',
    });
    expect(found!.uri, 'content://media/x/5');
    expect(found.size, 12);
    expect(found.relativePath, 'Pictures/Storize/u/');
  });

  test('null means nothing found', () async {
    mock((_) async => null);
    expect(
      await api.findByName(relativeDir: 'u', displayName: 'a.jpg'),
      isNull,
    );
  });

  test('a wrong-typed answer is a bad response', () async {
    mock((_) async => {'uri': 5, 'size': 'x'});
    expect(
      api.findByName(relativeDir: 'u', displayName: 'a.jpg'),
      throwsA(isA<StorizePlatformException>()),
    );
  });

  test('a native error carries no path', () async {
    mock(
      (_) async =>
          throw PlatformException(code: 'INVALID_ARGUMENT', message: 'bad'),
    );
    await expectLater(
      api.findByName(relativeDir: '../x', displayName: 'a.jpg'),
      throwsA(isA<StorizePlatformException>()),
    );
  });
}
