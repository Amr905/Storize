import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/golden_helpers.dart';
import 'activity_rig.dart';

Future<void> _golden(WidgetTester t, String name, Brightness b) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/${name}_${b.name}.png'),
);

void _both(
  String name,
  Future<void> Function(WidgetTester t, ActivityRig rig, Brightness b) body, {
  Future<void> Function(ActivityRig rig)? seed,
}) {
  for (final b in Brightness.values) {
    testWidgets('$name golden (${b.name})', (t) async {
      final rig = ActivityRig();
      await (seed ?? seedActivity)(rig);
      await body(t, rig, b);
      await _golden(t, name, b);
    });
  }
}

void main() {
  setUpAll(loadTestFonts);

  _both('activity_list', (t, rig, b) async {
    await pumpActivity(t, rig, brightness: b, size: const Size(400, 900));
  });

  _both('activity_filtered', (t, rig, b) async {
    await pumpActivity(t, rig, brightness: b, size: const Size(400, 900));
    await t.tap(find.widgetWithText(FilterChip, 'Errors'));
    await t.pumpAndSettle();
  });

  _both(
    'activity_empty',
    (t, rig, b) async {
      await pumpActivity(t, rig, brightness: b, size: const Size(400, 900));
    },
    seed: (_) async {},
  );
}
