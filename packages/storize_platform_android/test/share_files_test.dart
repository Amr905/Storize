import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mock(Future<Object?> Function(MethodCall) handler) {
    calls.clear();
    messenger.setMockMethodCallHandler(storizeMediaChannel, (call) {
      calls.add(call);
      return handler(call);
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(storizeMediaChannel, null),
    );
  }

  final api = StorizePlatformAndroid();
  const private =
      'file:///storage/emulated/0/Android/data/x/files/Pictures/Storize/a/1.jpg';

  test('one gallery item is sent as is with its mime', () async {
    mock((_) async => true);
    await api.shareFiles(
      uris: ['content://media/external/images/media/5'],
      mimes: ['image/*'],
    );
    expect(calls.single.method, 'shareFiles');
    expect(calls.single.arguments, {
      'uris': ['content://media/external/images/media/5'],
      'mimes': ['image/*'],
    });
  });

  test('several files, private and gallery, go in one call', () async {
    mock((_) async => true);
    await api.shareFiles(
      uris: ['content://media/external/video/media/6', private],
      mimes: ['video/*', 'image/*'],
    );
    final args = calls.single.arguments as Map;
    expect(args['uris'], hasLength(2));
    expect(args['uris'], contains(private));
    expect(args['mimes'], ['video/*', 'image/*']);
  });

  for (final bad in [
    'file:///data/user/0/x/databases/storize.db',
    'file:///sdcard/Pictures/Storize/../../secret.jpg',
    'file:///sdcard/Pictures/Other/a.jpg',
    'https://example.com/a.jpg',
    'content://other.app/1',
  ]) {
    test('refuses $bad without calling native', () async {
      mock((_) async => true);
      await expectLater(
        api.shareFiles(uris: [bad], mimes: ['image/*']),
        throwsA(
          isA<StorizePlatformException>().having(
            (e) => e.kind,
            'kind',
            StorizePlatformErrorKind.permissionDenied,
          ),
        ),
      );
      expect(calls, isEmpty);
    });
  }

  test('rejects empty or mismatched lists', () async {
    mock((_) async => true);
    expect(() => api.shareFiles(uris: [], mimes: []), throwsArgumentError);
    expect(
      () => api.shareFiles(uris: [private], mimes: []),
      throwsArgumentError,
    );
  });

  test('native errors surface as typed exceptions', () async {
    mock((_) async => throw PlatformException(code: 'UNAVAILABLE'));
    await expectLater(
      api.shareFiles(uris: [private], mimes: ['image/*']),
      throwsA(
        isA<StorizePlatformException>().having(
          (e) => e.kind,
          'kind',
          StorizePlatformErrorKind.unavailable,
        ),
      ),
    );
  });

  test('a wrong-typed answer is a bad response', () async {
    mock((_) async => 'x');
    await expectLater(
      api.shareFiles(uris: [private], mimes: ['image/*']),
      throwsA(isA<StorizePlatformException>()),
    );
  });
}
