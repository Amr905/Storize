import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import 'target_detail_rig.dart';

Future<void> _golden(WidgetTester t, String name, Brightness b) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/${name}_${b.name}.png'),
);

/// A target with every S-09 section filled in.
Future<DetailRig> _richRig() async {
  final rig = DetailRig();
  await rig.addAccount();
  final target = await rig.addTarget(
    'nour_k',
    displayName: 'Nour K.',
    note: 'consent by email 3/11',
    category: TargetCategory.consented,
    lastStoriesCheckAt: detailNow.subtract(const Duration(hours: 1)),
    lastNewStoryAt: detailNow.subtract(const Duration(hours: 2)),
    lastNewPostAt: DateTime.utc(2026, 11, 18, 9),
  );
  for (var i = 0; i < 4; i++) {
    await rig.addContent(target);
  }
  await rig.addContent(target, kind: ContentKind.post);
  await rig.addContent(target, kind: ContentKind.post);
  return rig;
}

void main() {
  setUpAll(loadTestFonts);

  for (final b in Brightness.values) {
    testWidgets('target_detail golden (${b.name})', (t) async {
      final rig = await _richRig();
      await pumpDetail(t, rig: rig, targetId: 1, brightness: b);
      await _golden(t, 'target_detail', b);
    });

    testWidgets('target_detail_not_visible golden (${b.name})', (t) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget(
        'old_acct',
        status: TargetStatus.notVisible,
        trackReels: false,
      );
      await pumpDetail(t, rig: rig, targetId: target.id, brightness: b);
      await _golden(t, 'target_detail_not_visible', b);
    });

    testWidgets('remove_target golden (${b.name})', (t) async {
      final rig = await _richRig();
      await pumpDetail(t, rig: rig, targetId: 1, brightness: b);
      final l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
      await t.tap(find.byTooltip(l10n.tdtMenuTooltip));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.tdtRemove));
      await t.pumpAndSettle();
      await _golden(t, 'remove_target', b);
    });
  }
}
