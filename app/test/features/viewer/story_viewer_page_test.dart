import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/viewer/story_media.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../library/library_rig.dart' show testNow;
import 'story_rig.dart';

/// Finds [text] inside the open dialog only.
Finder inDialog(String text) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

void main() {
  late StoryRig rig;
  late Target nour;
  late int newest;
  late int middle;
  late int oldest;

  /// Three photo stories of @nour_k: newest first in the viewer.
  Future<void> seedThree() async {
    nour = await rig.addTarget('nour_k');
    newest = await rig.addStory(
      nour,
      postedAt: testNow.subtract(const Duration(hours: 1)),
    );
    middle = await rig.addStory(
      nour,
      postedAt: testNow.subtract(const Duration(hours: 2)),
    );
    oldest = await rig.addStory(
      nour,
      postedAt: testNow.subtract(const Duration(hours: 3)),
    );
  }

  Future<bool> viewed(int id) async =>
      (await rig.content.getById(id))!.content.viewed;

  setUp(() {
    rig = StoryRig();
  });

  group('AC1 swipe and position bars', () {
    testWidgets('one position bar per story of the account', (t) async {
      await seedThree();
      await pumpStoryViewer(t, rig, contentId: middle);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('swipe left moves to the next story and marks it viewed', (
      t,
    ) async {
      await seedThree();
      await pumpStoryViewer(t, rig, contentId: middle);
      expect(await viewed(middle), isTrue);
      expect(await viewed(oldest), isFalse);

      await t.drag(find.byType(PageView), const Offset(-500, 0));
      await t.pumpAndSettle();
      expect(await viewed(oldest), isTrue);
    });

    testWidgets('swipe right moves to the previous story', (t) async {
      await seedThree();
      await pumpStoryViewer(t, rig, contentId: middle);
      await t.drag(find.byType(PageView), const Offset(500, 0));
      await t.pumpAndSettle();
      expect(await viewed(newest), isTrue);
    });

    testWidgets('a tap on the end edge goes to the next story', (t) async {
      await seedThree();
      await pumpStoryViewer(t, rig, contentId: middle);
      final origin = t.getTopLeft(find.byType(StoryMediaView).first);
      final size = t.getSize(find.byType(StoryMediaView).first);
      await t.tapAt(origin + Offset(size.width * 0.9, size.height * 0.5));
      await t.pumpAndSettle();
      expect(await viewed(oldest), isTrue);
    });
  });

  group('AC2 video', () {
    testWidgets('plays when shown, pauses, mutes and seeks', (t) async {
      final id = await rig.addStory(
        (await rig.addTarget('clip')),
        postedAt: testNow.subtract(const Duration(minutes: 20)),
        type: MediaType.video,
        durationMs: 12000,
      );
      await pumpStoryViewer(t, rig, contentId: id);

      expect(rig.players, hasLength(1));
      final player = rig.players.single;
      expect(player.contentUri, startsWith('content://viewer/'));
      expect(player.plays, 1);

      await t.tap(find.byTooltip('Pause'));
      await t.pumpAndSettle();
      expect(player.pauses, 1);

      await t.tap(find.byTooltip('Play'));
      await t.pumpAndSettle();
      expect(player.plays, 2);

      await t.tap(find.byTooltip('Mute'));
      await t.pumpAndSettle();
      expect(player.muted, isTrue);
      expect(find.byTooltip('Unmute'), findsOneWidget);

      await t.tap(find.byType(Slider));
      await t.pumpAndSettle();
      expect(player.seeked, isNotNull);
    });

    testWidgets('a video that cannot open shows the broken state', (t) async {
      rig.failVideoInit = true;
      final id = await rig.addStory(
        await rig.addTarget('clip'),
        postedAt: testNow,
        type: MediaType.video,
      );
      await pumpStoryViewer(t, rig, contentId: id);
      expect(find.text("This file can't be played."), findsOneWidget);
      expect(find.text('Remove from library'), findsOneWidget);
    });
  });

  group('AC3 link stickers and Info sheet', () {
    testWidgets('shows link stickers from the metadata', (t) async {
      final id = await rig.addStory(
        await rig.addTarget('nour_k'),
        postedAt: testNow,
        extras: const {
          'link_stickers': [
            {'url': 'shop.example.com/new'},
          ],
        },
      );
      await pumpStoryViewer(t, rig, contentId: id);
      expect(
        find.text('Link sticker: shop.example.com/new'),
        findsOneWidget,
      );
    });

    testWidgets('Info sheet shows the gallery folder and item details', (
      t,
    ) async {
      final id = await rig.addStory(
        await rig.addTarget('nour_k'),
        postedAt: testNow,
      );
      await pumpStoryViewer(t, rig, contentId: id);
      await t.tap(find.text('Info'));
      await t.pumpAndSettle();

      expect(find.text('Gallery folder'), findsOneWidget);
      expect(find.text('Pictures/Storize/nour_k/'), findsOneWidget);
      expect(find.text('item-1'), findsOneWidget);
      expect(find.text('512 KB'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
    });
  });

  group('AC4 share and delete', () {
    testWidgets('Share sends the saved file and there is no Save button', (
      t,
    ) async {
      final id = await rig.addStory(
        await rig.addTarget('nour_k'),
        postedAt: testNow,
      );
      await pumpStoryViewer(t, rig, contentId: id);
      expect(find.text('Save'), findsNothing);

      await t.tap(find.text('Share'));
      await t.pumpAndSettle();
      expect(rig.share.calls, hasLength(1));
      expect(rig.share.calls.single.single.contentUri, 'content://viewer/1');
    });

    testWidgets('Delete asks with the Library wording, then removes it', (
      t,
    ) async {
      await seedThree();
      await pumpStoryViewer(t, rig, contentId: middle);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();

      expect(inDialog('Delete 1 item?'), findsOneWidget);
      expect(
        inDialog(
          "They'll also be removed from your gallery. This can't be undone.",
        ),
        findsOneWidget,
      );

      await t.tap(inDialog('Delete'));
      await t.pumpAndSettle();

      expect(await rig.content.getById(middle), isNull);
      expect(find.text('1 item deleted'), findsOneWidget);
      expect(find.text('LIBRARY'), findsNothing);
    });

    testWidgets('Cancel in the confirm dialog keeps the story', (t) async {
      await seedThree();
      await pumpStoryViewer(t, rig, contentId: middle);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(inDialog('Cancel'));
      await t.pumpAndSettle();
      expect(await rig.content.getById(middle), isNotNull);
    });

    testWidgets('a failed delete says so and keeps the story', (t) async {
      await seedThree();
      rig.gallery.deleteFails = true;
      await pumpStoryViewer(t, rig, contentId: middle);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(inDialog('Delete'));
      await t.pumpAndSettle();

      expect(find.text("This item couldn't be deleted."), findsOneWidget);
      expect(await rig.content.getById(middle), isNotNull);
    });
  });

  group('AC5 missing file', () {
    testWidgets('shows the missing state with Remove from library', (t) async {
      final id = await rig.addStory(
        await rig.addTarget('nour_k'),
        postedAt: testNow,
        inGallery: false,
      );
      await pumpStoryViewer(t, rig, contentId: id);
      expect(find.text('This file is missing'), findsOneWidget);
      expect(find.text('Remove from library'), findsOneWidget);
    });

    testWidgets('Remove from library confirms, then drops the row', (t) async {
      final id = await rig.addStory(
        await rig.addTarget('nour_k'),
        postedAt: testNow,
        inGallery: false,
      );
      await pumpStoryViewer(t, rig, contentId: id);
      await t.tap(find.text('Remove from library'));
      await t.pumpAndSettle();
      expect(inDialog('Remove it from your library?'), findsOneWidget);

      await t.tap(inDialog('Remove from library'));
      await t.pumpAndSettle();
      expect(await rig.content.getById(id), isNull);
      expect(find.text('LIBRARY'), findsOneWidget);
    });
  });

  group('AC6 viewed', () {
    testWidgets('opening a story marks it viewed', (t) async {
      final id = await rig.addStory(
        await rig.addTarget('nour_k'),
        postedAt: testNow,
      );
      expect(await viewed(id), isFalse);
      await pumpStoryViewer(t, rig, contentId: id);
      expect(await viewed(id), isTrue);
    });
  });

  testWidgets('header shows the account and the posted age', (t) async {
    final id = await rig.addStory(
      await rig.addTarget('nour_k'),
      postedAt: testNow.subtract(const Duration(hours: 2)),
    );
    await pumpStoryViewer(t, rig, contentId: id);
    expect(find.text('@nour_k'), findsOneWidget);
    expect(find.textContaining('2 h ago'), findsOneWidget);
  });

  testWidgets('close returns to the Library', (t) async {
    final id = await rig.addStory(
      await rig.addTarget('nour_k'),
      postedAt: testNow,
    );
    await pumpStoryViewer(t, rig, contentId: id);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.text('LIBRARY'), findsOneWidget);
  });
}
