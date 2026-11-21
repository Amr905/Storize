import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('storize/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final store = PluginGalleryStore(StorizePlatformAndroid());

  void mock(Future<Object?> Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  test('maps a found file to a GalleryFile', () async {
    mock(
      (_) async => {
        'uri': 'content://media/x/9',
        'size': 3,
        'displayName': 'n.jpg',
        'relativePath': 'Pictures/Storize/u/',
      },
    );
    final f = await store.findExisting(relativeDir: 'u', displayName: 'n.jpg');
    expect(f!.uri, 'content://media/x/9');
    expect(f.sizeBytes, 3);
    expect(f.displayName, 'n.jpg');
  });

  test('nothing found is null', () async {
    mock((_) async => null);
    expect(
      await store.findExisting(relativeDir: 'u', displayName: 'n.jpg'),
      isNull,
    );
  });

  test('a native error or bad answer is "not found", never thrown', () async {
    mock((_) async => throw PlatformException(code: 'IO_ERROR'));
    expect(
      await store.findExisting(relativeDir: 'u', displayName: 'n.jpg'),
      isNull,
    );
    mock((_) async => {'uri': 1});
    expect(
      await store.findExisting(relativeDir: 'u', displayName: 'n.jpg'),
      isNull,
    );
  });
}
