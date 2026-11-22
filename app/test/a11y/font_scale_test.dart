// T-038 AC4: at 200% font scale no status text on S-04 (Library), S-07
// (Targets) or S-09 (Target detail) overflows or gets clipped. Flutter reports
// RenderFlex overflows as exceptions, so each pump must leave none behind.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_model/storize_model.dart';

import '../features/library/library_rig.dart';
import '../features/targets/target_detail_rig.dart';
import '../features/targets/targets_rig.dart';
import '../ui/golden_helpers.dart';

const _scale = 2.0;
const _phone = Size(360, 640);

/// Sets the platform text scale to 200% for the duration of the test and
/// checks that the scaler the widgets see is really linear(2).
void _setScale200(WidgetTester t) {
  t.platformDispatcher.textScaleFactorTestValue = _scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

void _expectScaled(WidgetTester t) {
  final scaler = MediaQuery.textScalerOf(
    t.element(find.byType(Scaffold).first),
  );
  expect(scaler.scale(10), closeTo(10 * _scale, 0.01));
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('S-04 Library at 200%: no overflow, status text intact', (
    t,
  ) async {
    _setScale200(t);
    final rig = LibraryRig();
    await seedStandard(rig);
    await pumpLibrary(t, rig, size: _phone);
    _expectScaled(t);
    expect(t.takeException(), isNull);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('S-07 Targets at 200%: no overflow with long status text', (
    t,
  ) async {
    _setScale200(t);
    final rig = TargetsRig();
    await rig.addAccount();
    await rig.addTarget(
      'a_very_long_account_name_for_scale',
      category: TargetCategory.consented,
      lastStoriesCheckAt: targetsNow.subtract(const Duration(hours: 2)),
      lastNewStoryAt: targetsNow.subtract(const Duration(minutes: 20)),
    );
    await rig.addTarget('client_co', status: TargetStatus.paused);
    await rig.addTarget('old_acct', status: TargetStatus.notVisible);
    await pumpTargets(t, rig: rig, size: _phone);
    _expectScaled(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('S-09 Target detail at 200%: no overflow with status text', (
    t,
  ) async {
    _setScale200(t);
    final rig = DetailRig();
    await rig.addAccount();
    final target = await rig.addTarget(
      'old_acct',
      status: TargetStatus.notVisible,
      trackReels: false,
    );
    await pumpDetail(t, rig: rig, targetId: target.id, size: _phone);
    _expectScaled(t);
    expect(t.takeException(), isNull);
  });
}
