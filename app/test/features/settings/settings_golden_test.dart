import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/golden_helpers.dart';
import 'settings_rig.dart';

Future<void> _seed(SettingsRig rig) async {
  final nour = await rig.addTarget('nour_k');
  final client = await rig.addTarget('client_co');
  await rig.addAccount(lastSuccessAt: rigNow);
  await rig.addStory(
    target: nour,
    remoteId: 's1',
    postedAt: rigNow.subtract(const Duration(days: 1)),
    detectedAt: rigNow.subtract(const Duration(days: 1)),
    downloadedAt: rigNow,
    sizeBytes: 3 * 1024 * 1024 * 1024,
  );
  await rig.addStory(
    target: client,
    remoteId: 's2',
    postedAt: rigNow.subtract(const Duration(days: 1)),
    detectedAt: rigNow.subtract(const Duration(days: 1)),
    downloadedAt: rigNow,
    sizeBytes: 512 * 1024 * 1024,
  );
}

void main() {
  setUpAll(loadTestFonts);

  for (final b in Brightness.values) {
    testWidgets('settings_s12 golden (${b.name})', (t) async {
      final rig = SettingsRig();
      await _seed(rig);
      await pumpSettings(t, rig, brightness: b);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_s12_${b.name}.png'),
      );
    });
  }
}
