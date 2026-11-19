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
    messenger.setMockMethodCallHandler(storizeMediaChannel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(() => calls = []);
  tearDown(() => messenger.setMockMethodCallHandler(storizeMediaChannel, null));

  test('storageStats returns typed free and total bytes', () async {
    mock((_) async => {'freeBytes': 5, 'totalBytes': 10});
    final stats = await api.storageStats();
    expect(stats.freeBytes, 5);
    expect(stats.totalBytes, 10);
    expect(calls.single.method, 'storageStats');
  });

  test('accepts values above 32 bits', () async {
    const big = 512 * 1024 * 1024 * 1024;
    mock((_) async => {'freeBytes': big ~/ 2, 'totalBytes': big});
    final stats = await api.storageStats();
    expect(stats.totalBytes, big);
  });

  for (final entry in {
    'null': null,
    'string': 'junk',
    'missing key': {'freeBytes': 1},
    'wrong type': {'freeBytes': '1', 'totalBytes': 2},
    'negative free': {'freeBytes': -1, 'totalBytes': 2},
    'zero total': {'freeBytes': 0, 'totalBytes': 0},
  }.entries) {
    test('bad answer (${entry.key}) is BAD_RESPONSE', () async {
      mock((_) async => entry.value);
      await expectLater(
        api.storageStats(),
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

  test('native error code is kept', () async {
    mock((_) async => throw PlatformException(code: 'IO_ERROR', message: 'x'));
    await expectLater(
      api.storageStats(),
      throwsA(
        isA<StorizePlatformException>().having(
          (e) => e.kind,
          'kind',
          StorizePlatformErrorKind.ioError,
        ),
      ),
    );
  });

  test('missing plugin is UNAVAILABLE', () async {
    await expectLater(
      api.storageStats(),
      throwsA(
        isA<StorizePlatformException>().having(
          (e) => e.kind,
          'kind',
          StorizePlatformErrorKind.unavailable,
        ),
      ),
    );
  });
}
