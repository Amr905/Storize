import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/viewer/post_info_sheet.dart';
import 'package:storize_app/features/viewer/post_providers.dart';
import 'package:storize_app/features/viewer/post_slide.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'post_rig.dart';
import 'story_rig.dart';

/// Finds [text] inside the open dialog only.
Finder inDialog(String text) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

const _photos = [
  SlideSpec(MediaType.photo),
  SlideSpec(MediaType.photo),
  SlideSpec(MediaType.video),
];

void main() {
  late StoryRig rig;
  late Target brand;

  setUp(() async {
    rig = StoryRig();
    brand = await rig.addTarget('brandx');
  });

  group('AC1 pager, counter, zoom and video controls', () {
    testWidgets('the counter starts at 1 of N and follows a swipe', (t) async {
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      expect(find.text('1 / 3'), findsOneWidget);

      await t.drag(find.byType(PageView), const Offset(-500, 0));
      await t.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('a photo slide is wrapped in an InteractiveViewer', (
      t,
    ) async {
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      expect(
        find.descendant(
          of: find.byType(PostSlideView).first,
          matching: find.byType(InteractiveViewer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a video slide shows play, a scrubber and the duration', (
      t,
    ) async {
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      await t.drag(find.byType(PageView), const Offset(-1000, 0));
      await t.pumpAndSettle();

      expect(find.byTooltip('Play'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      await t.tap(find.byTooltip('Play'));
      await t.pump();
      expect(rig.players.single.plays, 1);
    });

    testWidgets('the dots are one per slide', (t) async {
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      final dots = find.descendant(
        of: find.byKey(const ValueKey('post-dots')),
        matching: find.byType(Container),
      );
      expect(dots, findsNWidgets(3));
    });
  });

  group('AC2 type label', () {
    for (final (type, label) in [
      (PostType.photo, 'Photo'),
      (PostType.video, 'Video'),
      (PostType.carousel, 'Carousel'),
      (PostType.reel, 'Reel'),
    ]) {
      testWidgets('shows $label for ${type.name}', (t) async {
        final id = await addPost(
          rig,
          brand,
          slides: const [SlideSpec(MediaType.photo)],
          postType: type,
        );
        await pumpPostViewer(t, rig, contentId: id);
        expect(find.textContaining('· $label'), findsOneWidget);
      });
    }
  });

  group('AC3 expandable caption', () {
    testWidgets('a long caption collapses and expands with More and Less', (
      t,
    ) async {
      const long =
          'New drop is live! Limited pieces at the store, come early. '
          'Every size is on the shelf until Sunday evening.';
      final id = await addPost(
        rig,
        brand,
        slides: const [SlideSpec(MediaType.photo)],
        caption: long,
      );
      await pumpPostViewer(t, rig, contentId: id);
      final text = t.widget<Text>(find.text(long));
      expect(text.maxLines, 3);

      await t.tap(find.text('More'));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.text(long)).maxLines, isNull);
      expect(find.text('Less'), findsOneWidget);
    });

    testWidgets('no caption means no caption toggle', (t) async {
      final id = await addPost(
        rig,
        brand,
        slides: const [SlideSpec(MediaType.photo)],
      );
      await pumpPostViewer(t, rig, contentId: id);
      expect(find.text('More'), findsNothing);
    });
  });

  group('AC4 info and copyable link', () {
    testWidgets('Info shows the post link; Copy puts it on the clipboard', (
      t,
    ) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      await t.tap(find.text('Info'));
      await t.pumpAndSettle();

      expect(find.byType(PostInfoSheet), findsOneWidget);
      expect(find.text('https://www.instagram.com/p/ABC123/'), findsOneWidget);
      await t.tap(find.byTooltip('Copy link'));
      await t.pumpAndSettle();
      expect(copied, 'https://www.instagram.com/p/ABC123/');
      expect(find.text('Link copied'), findsOneWidget);
    });
  });

  group('AC5 share', () {
    testWidgets('the share button shares the current slide only', (t) async {
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      await t.tap(find.text('Share'));
      await t.pumpAndSettle();
      expect(rig.share.calls.single.length, 1);
    });

    testWidgets('More > Share all slides shares every saved slide', (t) async {
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      await t.tap(find.byTooltip('More'));
      await t.pumpAndSettle();
      await t.tap(find.text('Share all slides'));
      await t.pumpAndSettle();
      expect(rig.share.calls.single.length, 3);
    });
  });

  group('AC6 delete the whole post', () {
    testWidgets('the dialog uses gallery wording and deletes every file', (
      t,
    ) async {
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();

      expect(inDialog('Delete this post (3 files)?'), findsOneWidget);
      expect(
        inDialog("Also removes them from your gallery. This can't be undone."),
        findsOneWidget,
      );

      await t.tap(inDialog('Delete'));
      await t.pumpAndSettle();
      expect(rig.gallery.files, isEmpty);
      expect(await rig.content.getById(id), isNull);
      expect(find.text('LIBRARY'), findsOneWidget);
    });

    testWidgets('Cancel keeps the post', (t) async {
      final id = await addPost(rig, brand, slides: _photos);
      await pumpPostViewer(t, rig, contentId: id);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(inDialog('Cancel'));
      await t.pumpAndSettle();
      expect(await rig.content.getById(id), isNotNull);
      expect(rig.gallery.files, hasLength(3));
    });
  });

  group('AC7 per-slide states', () {
    testWidgets('a missing file shows its message on that slide only', (
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
      expect(find.text("This slide's file is missing"), findsNothing);

      await t.drag(find.byType(PageView), const Offset(-500, 0));
      await t.pumpAndSettle();
      expect(find.text("This slide's file is missing"), findsOneWidget);
      // The real remover is wired (T-029a): the action is visible.
      expect(find.text('Remove slide'), findsOneWidget);
    });

    testWidgets('a slide that never downloaded shows Not downloaded', (
      t,
    ) async {
      final id = await addPost(
        rig,
        brand,
        slides: const [
          SlideSpec(MediaType.photo),
          SlideSpec(MediaType.photo, status: MediaFileStatus.failed),
        ],
      );
      await pumpPostViewer(t, rig, contentId: id);
      await t.drag(find.byType(PageView), const Offset(-500, 0));
      await t.pumpAndSettle();
      expect(find.text('Not downloaded'), findsOneWidget);
      expect(find.text("This slide's file is missing"), findsNothing);
    });

    testWidgets('Remove slide calls the remover for that slide index', (
      t,
    ) async {
      final calls = <(int, int)>[];
      final id = await addPost(
        rig,
        brand,
        slides: const [
          SlideSpec(MediaType.photo),
          SlideSpec(MediaType.photo, inGallery: false),
        ],
      );
      await pumpPostViewer(
        t,
        rig,
        contentId: id,
        extra: [
          postSlideRemoverProvider.overrideWithValue((contentId, index) async {
            calls.add((contentId, index));
            return false;
          }),
        ],
      );
      await t.drag(find.byType(PageView), const Offset(-500, 0));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove slide'));
      await t.pumpAndSettle();
      expect(calls, [(id, 1)]);
      expect(find.text("This slide couldn't be removed."), findsOneWidget);
    });
  });

  test('the post link is built from the shortcode only', () async {
    final id = await addPost(
      rig,
      brand,
      slides: const [SlideSpec(MediaType.photo)],
      shortcode: null,
    );
    final c = (await rig.content.getById(id))!.content;
    expect(postLinkFor(c), isNull);
  });
}
