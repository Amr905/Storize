import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/app.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/router/app_router.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../helpers/app_harness.dart';
import '../ui/golden_helpers.dart';

void main() {
  setUpAll(loadTestFonts);

  for (final brightness in Brightness.values) {
    for (final scenario in ['healthy', 'relogin', 'restricted']) {
      testWidgets('shell_library_${scenario}_${brightness.name}', (t) async {
        t.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(t.platformDispatcher.clearAllTestValues);
        t.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(400, 700);
        addTearDown(t.view.reset);
        final repo = FakeAccountRepo();
        await t.pumpWidget(
          StorizeApp(
            overrides: [
              accountRepoProvider.overrideWithValue(repo),
              initialLocationProvider.overrideWithValue('/library'),
              appLockTestBypassProvider.overrideWithValue(true),
            ],
          ),
        );
        if (scenario != 'healthy') {
          await repo.upsert(
            account(
              scenario == 'relogin'
                  ? AccountStatus.needsRelogin
                  : AccountStatus.restricted,
            ),
          );
        }
        await t.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/shell_library_${scenario}_${brightness.name}.png',
          ),
        );
      });
    }
  }
}
