import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_model/storize_model.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(storizeMediaChannel, (call) async {
      calls.add(call);
      return true;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(storizeMediaChannel, null));

  const service = PlatformShareService.new;

  test('maps photo and video to image/* and video/*', () async {
    await service(StorizePlatformAndroid()).share(const [
      ShareFile(
        contentUri: 'content://media/external/images/media/1',
        mediaType: MediaType.photo,
      ),
      ShareFile(
        contentUri: 'content://media/external/video/media/2',
        mediaType: MediaType.video,
      ),
    ]);
    expect((calls.single.arguments as Map)['mimes'], ['image/*', 'video/*']);
  });

  test('nothing to share does not call native', () async {
    await service(StorizePlatformAndroid()).share(const []);
    expect(calls, isEmpty);
  });

  test('a private path outside the root fails', () async {
    await expectLater(
      service(StorizePlatformAndroid()).share(const [
        ShareFile(
          contentUri: 'file:///data/user/0/x/files/a.jpg',
          mediaType: MediaType.photo,
        ),
      ]),
      throwsA(isA<StorizePlatformException>()),
    );
    expect(calls, isEmpty);
  });
}
