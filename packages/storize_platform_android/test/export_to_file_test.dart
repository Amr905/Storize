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

  test('sends uri and destPath, returns size and sha256', () async {
    mock((_) async => {'size': 3, 'sha256': 'ab'});
    final out = await api.exportToFile(
      uri: 'content://media/x/5',
      destPath: '/p/f.jpg',
    );
    expect(calls.single.method, 'exportToFile');
    expect(calls.single.arguments, {
      'uri': 'content://media/x/5',
      'destPath': '/p/f.jpg',
    });
    expect(out.size, 3);
    expect(out.sha256, 'ab');
  });

  test('a wrong-typed answer is a bad response', () async {
    mock((_) async => {'size': 'x'});
    await expectLater(
      api.exportToFile(uri: 'content://media/x/5', destPath: '/p/f.jpg'),
      throwsA(
        isA<StorizePlatformException>().having(
          (e) => e.kind,
          'kind',
          StorizePlatformErrorKind.badResponse,
        ),
      ),
    );
  });

  test('SOURCE_NOT_FOUND maps to sourceNotFound', () async {
    mock((_) async => throw PlatformException(code: 'SOURCE_NOT_FOUND'));
    await expectLater(
      api.exportToFile(uri: 'content://media/x/5', destPath: '/p/f.jpg'),
      throwsA(
        isA<StorizePlatformException>().having(
          (e) => e.kind,
          'kind',
          StorizePlatformErrorKind.sourceNotFound,
        ),
      ),
    );
  });
}
