import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import 'targets_rig.dart';

Future<void> _golden(WidgetTester t, String name, Brightness b) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/${name}_${b.name}.png'),
);

void main() {
  setUpAll(loadTestFonts);

  for (final b in Brightness.values) {
    testWidgets('targets_list golden (${b.name})', (t) async {
      final rig = TargetsRig();
      await rig.addAccount();
      await rig.addTarget(
        'nour_k',
        category: TargetCategory.consented,
        lastStoriesCheckAt: DateTime(2026, 11, 21, 10, 42),
        lastNewStoryAt: DateTime(2026, 11, 21, 10, 15),
      );
      await rig.addTarget(
        'brandx',
        category: TargetCategory.public,
        lastStoriesCheckAt: DateTime(2026, 11, 21, 9),
      );
      await rig.addTarget('client_co', status: TargetStatus.paused);
      await rig.addTarget('old_acct', status: TargetStatus.notVisible);
      await pumpTargets(t, rig: rig, brightness: b);
      await _golden(t, 'targets_list', b);
    });

    testWidgets('add_target_error golden (${b.name})', (t) async {
      final rig = TargetsRig();
      await rig.addAccount();
      await pumpTargets(
        t,
        rig: rig,
        brightness: b,
        initial: '/targets/add',
        extra: [
          addTargetFormProvider.overrideWith(
            () => FixedAddForm(
              const AddTargetForm(
                username: 'a..b',
                submitted: true,
                trackRejected: true,
              ),
            ),
          ),
        ],
      );
      await _golden(t, 'add_target_error', b);
    });

    testWidgets('add_target_verifying golden (${b.name})', (t) async {
      final rig = TargetsRig();
      await rig.addAccount();
      await pumpTargets(
        t,
        rig: rig,
        brightness: b,
        initial: '/targets/add',
        settle: false,
        extra: [
          addTargetFormProvider.overrideWith(
            () => FixedAddForm(
              const AddTargetForm(
                username: 'nour_k',
                category: TargetCategory.consented,
                verifying: true,
              ),
            ),
          ),
        ],
      );
      await _golden(t, 'add_target_verifying', b);
    });
  }
}
