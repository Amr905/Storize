import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/golden_helpers.dart';
import 'link_rig.dart';

Future<void> _golden(String name, Brightness b) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/${name}_${b.name}.png'),
);

void main() {
  setUpAll(loadTestFonts);

  for (final b in Brightness.values) {
    testWidgets('link_preview_sheet golden (${b.name})', (t) async {
      final rig = LinkRig()..scriptStory();
      await pumpLink(t, rig: rig, brightness: b, size: const Size(400, 800));
      await lookUp(t, storyLinkText);
      await _golden('link_preview_sheet', b);
    });

    testWidgets('link_preview_sheet highlight golden (${b.name})', (t) async {
      final rig = LinkRig()..scriptHighlight();
      await pumpLink(t, rig: rig, brightness: b, size: const Size(400, 800));
      await lookUp(t, '$highlightLinkText?story_media_id=3002_42');
      await _golden('link_preview_sheet_highlight', b);
    });
  }
}
