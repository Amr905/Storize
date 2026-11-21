import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/viewer/post_viewer_page.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import '../library/library_rig.dart' show testNow;
import 'post_rig.dart';
import 'story_rig.dart';

Future<void> _golden(WidgetTester t, String name, Brightness b) => expectLater(
  find.byType(PostViewerPage),
  matchesGoldenFile('goldens/post_${name}_${b.name}.png'),
);

void _both(
  String name,
  Future<void> Function(WidgetTester t, StoryRig rig, Brightness b) body,
) {
  for (final b in Brightness.values) {
    testWidgets('post $name golden (${b.name})', (t) async {
      final rig = StoryRig();
      await body(t, rig, b);
      await _golden(t, name, b);
    });
  }
}

void main() {
  setUpAll(loadTestFonts);

  _both('carousel', (t, rig, b) async {
    final target = await rig.addTarget('brandx');
    final id = await addPost(
      rig,
      target,
      postType: PostType.carousel,
      caption:
          'New drop is live! Limited pieces at the store, come early. '
          'Every size is on the shelf until Sunday evening.',
      postedAt: testNow.subtract(const Duration(hours: 3)),
      slides: const [
        SlideSpec(MediaType.photo),
        SlideSpec(MediaType.photo),
        SlideSpec(MediaType.video),
      ],
    );
    await pumpPostViewer(t, rig, contentId: id, brightness: b);
  });

  _both('missing', (t, rig, b) async {
    final target = await rig.addTarget('brandx');
    final id = await addPost(
      rig,
      target,
      postType: PostType.carousel,
      caption: 'Two slides, one file removed from the gallery.',
      slides: const [
        SlideSpec(MediaType.photo),
        SlideSpec(MediaType.photo, inGallery: false),
      ],
    );
    await pumpPostViewer(t, rig, contentId: id, brightness: b);
    await t.drag(find.byType(PageView), const Offset(-500, 0));
    await t.pumpAndSettle();
  });
}
