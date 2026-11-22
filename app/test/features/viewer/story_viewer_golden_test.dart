import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/viewer/story_info_sheet.dart';
import 'package:storize_app/features/viewer/story_viewer_page.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import '../library/library_rig.dart' show testNow;
import 'story_rig.dart';

Future<void> _golden(WidgetTester t, String name, Brightness b, {Finder? of}) =>
    expectLater(
      of ?? find.byType(StoryViewerPage),
      matchesGoldenFile('goldens/story_${name}_${b.name}.png'),
    );

void _both(
  String name,
  Future<void> Function(WidgetTester t, StoryRig rig, Brightness b) body,
) {
  for (final b in Brightness.values) {
    testWidgets('story $name golden (${b.name})', (t) async {
      final rig = StoryRig();
      await body(t, rig, b);
      await _golden(t, name, b);
    });
  }
}

void main() {
  setUpAll(loadTestFonts);

  _both('photo', (t, rig, b) async {
    final target = await rig.addTarget('nour_k');
    final older = await rig.addStory(
      target,
      postedAt: testNow.subtract(const Duration(hours: 5)),
    );
    await rig.addStory(
      target,
      postedAt: testNow.subtract(const Duration(hours: 2, minutes: 15)),
      extras: const {
        'link_stickers': [
          {'url': 'shop.example.com/new'},
        ],
      },
    );
    await pumpStoryViewer(t, rig, contentId: older, brightness: b);
  });

  _both('video', (t, rig, b) async {
    final id = await rig.addStory(
      await rig.addTarget('nour_k'),
      postedAt: testNow.subtract(const Duration(minutes: 20)),
      type: MediaType.video,
      durationMs: 12000,
    );
    await pumpStoryViewer(t, rig, contentId: id, brightness: b);
  });

  _both('missing', (t, rig, b) async {
    final id = await rig.addStory(
      await rig.addTarget('nour_k'),
      postedAt: testNow.subtract(const Duration(hours: 2)),
      inGallery: false,
    );
    await pumpStoryViewer(t, rig, contentId: id, brightness: b);
  });

  for (final b in Brightness.values) {
    testWidgets('story info sheet golden (${b.name})', (t) async {
      final rig = StoryRig();
      final id = await rig.addStory(
        await rig.addTarget('nour_k'),
        postedAt: testNow.subtract(const Duration(hours: 2)),
      );
      await pumpStoryViewer(t, rig, contentId: id, brightness: b);
      await t.tap(find.text('Info'));
      await t.pumpAndSettle();
      await _golden(t, 'info', b, of: find.byType(StoryInfoSheet));
    });
  }
}
