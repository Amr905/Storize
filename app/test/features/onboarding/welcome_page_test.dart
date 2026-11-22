import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'onboarding_rig.dart';

void main() {
  testWidgets('Continue is disabled until the box is ticked', (t) async {
    final rig = OnbRig();
    await rig.pump(t);
    FilledButton button() => t.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('onb-continue')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button().onPressed, isNull);
    await t.ensureVisible(find.byKey(const ValueKey('onb-risk-checkbox')));
    await t.tap(find.byKey(const ValueKey('onb-risk-checkbox')));
    await t.pump();
    expect(button().onPressed, isNotNull);
    await t.ensureVisible(find.byKey(const ValueKey('onb-risk-checkbox')));
    await t.tap(find.byKey(const ValueKey('onb-risk-checkbox')));
    await t.pump();
    expect(button().onPressed, isNull);
  });

  testWidgets('Continue stores riskAcknowledgedAt and opens S-02', (t) async {
    final rig = OnbRig();
    await rig.pump(t);
    expect((await rig.settings.get()).riskAcknowledgedAt, isNull);
    await t.ensureVisible(find.byKey(const ValueKey('onb-risk-checkbox')));
    await t.tap(find.byKey(const ValueKey('onb-risk-checkbox')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('onb-continue')));
    await t.pumpAndSettle();
    expect(
      (await rig.settings.get()).riskAcknowledgedAt,
      DateTime.utc(2026, 11, 21, 10),
    );
    expect(rig.router.state.uri.path, '/login');
  });
}
