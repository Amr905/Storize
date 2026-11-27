import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/viewer/post_providers.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../library/library_rig.dart' show testNow;
import 'post_rig.dart';
import 'story_rig.dart';

Finder _fullImage() =>
    find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage);

void main() {
  late StoryRig rig;
  late Target brand;

  setUp(() async {
    rig = StoryRig();
    brand = await rig.addTarget('brandx');
  });

  group('A: per-slide removal (EC-20)', () {
    testWidgets('Remove slide deletes the file and the row; post stays', (
      t,
    ) async {
      final id = await addPost(
        rig,
        brand,
        slides: const [
          SlideSpec(MediaType.photo),
          SlideSpec(MediaType.photo, inGallery: false),
        ],
      );
      await pumpPostViewer(t, rig, contentId: id);
      await t.drag(find.byType(PageView), const Offset(-500, 0));
      await t.pumpAndSettle();

      await t.tap(find.text('Remove slide'));
      await t.pumpAndSettle();

      final left = (await rig.content.getById(id))!.media;
      expect(left, hasLength(1));
      expect(left.single.slideIndex, 0);
      expect(find.text("This slide couldn't be removed."), findsNothing);
      expect(find.text("This slide's file is missing"), findsNothing);
    });

    testWidgets('removing the last slide removes the post', (t) async {
      final id = await addPost(
        rig,
        brand,
        slides: const [SlideSpec(MediaType.photo, inGallery: false)],
      );
      await pumpPostViewer(t, rig, contentId: id);

      await t.tap(find.text('Remove slide'));
      await t.pumpAndSettle();

      expect(await rig.content.getById(id), isNull);
    });

    testWidgets('a failed gallery delete keeps the row and says so', (t) async {
      final id = await addPost(
        rig,
        brand,
        slides: const [
          SlideSpec(MediaType.photo, inGallery: false),
          SlideSpec(MediaType.photo),
        ],
      );
      await pumpPostViewer(
        t,
        rig,
        contentId: id,
        extra: [
          removeMediaFileProvider.overrideWithValue(
            RemoveMediaFile(
              content: rig.content,
              gallery: _FailingGallery(),
              cache: rig.cache,
            ),
          ),
        ],
      );

      await t.tap(find.text('Remove slide'));
      await t.pumpAndSettle();

      expect((await rig.content.getById(id))!.media, hasLength(2));
      expect(find.text("This slide couldn't be removed."), findsOneWidget);
    });
  });

  group('B: full-size photos', () {
    final bytes = Uint8List.fromList(List.filled(16, 7));

    testWidgets('S-15 shows the full-size bytes inside the zoom view', (
      t,
    ) async {
      final read = <String>[];
      final id = await addPost(
        rig,
        brand,
        slides: const [SlideSpec(MediaType.photo)],
      );
      await pumpPostViewer(
        t,
        rig,
        contentId: id,
        extra: [
          fullPhotoReaderProvider.overrideWithValue((uri) async {
            read.add(uri);
            return bytes;
          }),
        ],
      );
      await t.pump();

      expect(read, hasLength(1));
      expect(_fullImage(), findsOneWidget);
      expect(
        find.ancestor(
          of: _fullImage(),
          matching: find.byType(InteractiveViewer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('S-15 keeps the thumbnail when the reader returns null', (
      t,
    ) async {
      final id = await addPost(
        rig,
        brand,
        slides: const [SlideSpec(MediaType.photo)],
      );
      await pumpPostViewer(
        t,
        rig,
        contentId: id,
        extra: [fullPhotoReaderProvider.overrideWithValue((_) async => null)],
      );
      expect(_fullImage(), findsNothing);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('S-15 keeps the thumbnail when the reader throws', (t) async {
      final id = await addPost(
        rig,
        brand,
        slides: const [SlideSpec(MediaType.photo)],
      );
      await pumpPostViewer(
        t,
        rig,
        contentId: id,
        extra: [
          fullPhotoReaderProvider.overrideWithValue(
            (_) async => throw StateError('boom'),
          ),
        ],
      );
      expect(_fullImage(), findsNothing);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('S-06 shows the full-size bytes of a story photo', (t) async {
      final story = await rig.addStory(brand, postedAt: testNow);
      await pumpStoryViewer(
        t,
        rig,
        contentId: story,
        extra: [fullPhotoReaderProvider.overrideWithValue((_) async => bytes)],
      );
      await t.pump();
      expect(_fullImage(), findsOneWidget);
    });

    testWidgets('S-06 shows the thumbnail when nothing is read', (t) async {
      final story = await rig.addStory(brand, postedAt: testNow);
      await pumpStoryViewer(t, rig, contentId: story);
      expect(_fullImage(), findsNothing);
    });
  });
}

/// A gallery whose delete always fails.
final class _FailingGallery implements GalleryStore {
  @override
  Future<bool> delete(String contentUri) async =>
      throw const GalleryWriteFailed('IO_ERROR');

  @override
  Future<bool> exists(String contentUri) async => true;

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
    StorageTarget target = StorageTarget.gallery,
  }) => throw UnimplementedError();

  @override
  Future<int?> size(String contentUri) async => 1;

  @override
  Future<GalleryFile> copyTo(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => throw UnimplementedError();

  @override
  Future<GalleryFile> move(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => throw UnimplementedError();

}
