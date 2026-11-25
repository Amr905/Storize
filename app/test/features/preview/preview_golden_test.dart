import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import 'preview_rig.dart';

Future<void> _golden(String name, Brightness b) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/${name}_${b.name}.png'),
);

void main() {
  setUpAll(loadTestFonts);

  for (final b in Brightness.values) {
    testWidgets('preview_loaded golden (${b.name})', (t) async {
      final rig = PreviewRig()
        ..script(
          isPrivate: true,
          posts: [
            remote('p1'),
            remote('p2', slides: 3),
            remote('p3', type: MediaType.video),
            remote('p4'),
            remote('p5'),
            remote('p6'),
          ],
        )
        ..fake.queueMedia(List<int>.filled(8, 1));
      await pumpPreview(t, rig: rig, brightness: b);
      final l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
      // One item saved (check badge), two ticked.
      await t.tap(find.byKey(const ValueKey('prv-item-story:s2')));
      await t.pump();
      await t.tap(find.text(l10n.prvSaveSelected(1)));
      await settleAsync(t);
      await t.tap(find.byKey(const ValueKey('prv-item-post:p1')));
      await t.tap(find.byKey(const ValueKey('prv-item-post:p4')));
      await t.pump();
      await _golden('preview_loaded', b);
    });

    testWidgets('preview_section_error golden (${b.name})', (t) async {
      final rig = PreviewRig();
      final user = previewUser();
      rig.fake
        ..resolveUserResults.add(Ok(user))
        ..fetchStoriesResults.add(const Err(RateLimited(null)))
        ..fetchPostPageResults.add(
          Ok(PostPage(items: [remote('p1'), remote('p2')])),
        );
      await pumpPreview(t, rig: rig, brightness: b);
      await _golden('preview_section_error', b);
    });
  }
}
