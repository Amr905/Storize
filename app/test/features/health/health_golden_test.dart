// T-056 (FR-75): goldens of the Health screen states, light and dark.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/health/health_page.dart';
import 'package:storize_domain/testing.dart';

import '../../ui/golden_helpers.dart';
import 'health_rig.dart';

Future<void> _golden(
  WidgetTester t,
  String name,
  Brightness brightness,
  FakeHealthReadModel model,
) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(400, 1300);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    healthApp(
      home: const HealthPage(),
      brightness: brightness,
      overrides: healthOverrides(model),
    ),
  );
  await t.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/${name}_${brightness.name}.png'),
  );
  await t.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(loadTestFonts);

  for (final b in Brightness.values) {
    testWidgets('health_content golden (${b.name})', (t) async {
      await _golden(
        t,
        'health_content',
        b,
        FakeHealthReadModel(healthSnapshot(paused: false)),
      );
    });
  }

  testWidgets('health_paused golden (light)', (t) async {
    await _golden(
      t,
      'health_paused',
      Brightness.light,
      FakeHealthReadModel(healthSnapshot()),
    );
  });

  testWidgets('health_empty golden (light)', (t) async {
    await _golden(
      t,
      'health_empty',
      Brightness.light,
      FakeHealthReadModel(
        healthSnapshot(paused: false, withSession: false, targets: const []),
      ),
    );
  });

  testWidgets('health_error golden (light)', (t) async {
    await _golden(
      t,
      'health_error',
      Brightness.light,
      FakeHealthReadModel(healthSnapshot())..error = StateError('boom'),
    );
  });
}
