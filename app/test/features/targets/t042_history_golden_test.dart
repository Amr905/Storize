import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import 'target_detail_rig.dart';
import 'targets_rig.dart';

Future<void> _golden(WidgetTester t, String name, Brightness b) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/${name}_${b.name}.png'),
);

void main() {
  setUpAll(loadTestFonts);

  for (final b in Brightness.values) {
    testWidgets('t042 S-08 add with history picker golden (${b.name})', (
      t,
    ) async {
      final rig = TargetsRig();
      await pumpTargets(
        t,
        rig: rig,
        initial: '/targets/add',
        brightness: b,
        extra: [
          addTargetFormProvider.overrideWith(
            () => FixedAddForm(
              const AddTargetForm(
                username: 'nour_k',
                category: TargetCategory.consented,
                historyRange: HistoryRange.all,
                highlights: true,
              ),
            ),
          ),
        ],
      );
      await _golden(t, 't042_add_history', b);
    });

    testWidgets('t042 S-09 history progress golden (${b.name})', (t) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget(
        'nour_k',
        category: TargetCategory.consented,
      );
      await rig.targets.update(
        target.copyWith(
          historyRange: HistoryRange.all,
          highlightsEnabled: true,
          historyProgress: HistoryProgress(
            state: HistoryState.running,
            fetched: 312,
            oldestSeenAt: DateTime.utc(2026, 11, 1, 9),
            updatedAt: detailNow,
          ),
        ),
      );
      await pumpDetail(t, rig: rig, targetId: target.id, brightness: b);
      await _golden(t, 't042_target_detail_history', b);
    });
  }
}
