import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import '../settings/settings_rig.dart';
import 'account_rig.dart';

void main() {
  setUpAll(loadTestFonts);

  final states = <String, AccountStatus>{
    's13_active': AccountStatus.active,
    's13_relogin': AccountStatus.needsRelogin,
  };
  for (final entry in states.entries) {
    for (final b in Brightness.values) {
      testWidgets('${entry.key} golden (${b.name})', (t) async {
        final rig = SettingsRig();
        await rig.addAccount(status: entry.value, lastSuccessAt: rigNow);
        await pumpAccount(t, rig, brightness: b);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${entry.key}_${b.name}.png'),
        );
      });
    }
  }
}
