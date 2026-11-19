import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

import 'fake_native_media.dart';
import 'storage_info_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  storageInfoContract('PluginStorageInfo', () async {
    final native = FakeNativeMedia();
    return StorageInfoHarness(
      info: PluginStorageInfo(native.api),
      set: ({required free, required total}) {
        native
          ..freeBytes = free
          ..totalBytes = total;
      },
    );
  });
  storageInfoContract('FakeStorageInfo', () async {
    final fake = FakeStorageInfo();
    return StorageInfoHarness(
      info: fake,
      set: ({required free, required total}) {
        fake
          ..free = free
          ..total = total;
      },
    );
  });

  group('PluginStorageInfo errors', () {
    late FakeNativeMedia native;
    late PluginStorageInfo info;
    setUp(() {
      native = FakeNativeMedia();
      info = PluginStorageInfo(native.api);
    });

    test('calls storageStats on the media channel', () async {
      await info.freeBytes();
      expect(native.calls.single.method, 'storageStats');
    });

    test('a native error surfaces as StorizePlatformException', () async {
      native.failNext = PlatformException(
        code: 'IO_ERROR',
        message: 'Storage statistics unavailable',
      );
      await expectLater(
        info.totalBytes(),
        throwsA(
          isA<StorizePlatformException>().having(
            (e) => e.kind,
            'kind',
            StorizePlatformErrorKind.ioError,
          ),
        ),
      );
    });

    test('a bad answer is BAD_RESPONSE', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native.channel, (_) async => 'junk');
      await expectLater(
        info.freeBytes(),
        throwsA(
          isA<StorizePlatformException>().having(
            (e) => e.kind,
            'kind',
            StorizePlatformErrorKind.badResponse,
          ),
        ),
      );
    });
  });
}
