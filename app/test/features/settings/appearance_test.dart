// T-053: the Appearance control in S-12 saves the theme mode and the app
// follows it live, and a restart keeps it.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/settings/appearance_control.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

import '../../helpers/app_harness.dart';

ThemeMode _themeMode(WidgetTester t) =>
    t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  testWidgets('defaults to System and shows the hint', (t) async {
    final repo = FakeSettingsRepo();
    await pumpApp(
      t,
      initialLocation: '/settings',
      overrides: [settingsRepoProvider.overrideWithValue(repo)],
    );
    expect(find.byType(AppearanceControl), findsOneWidget);
    expect(_themeMode(t), ThemeMode.system);
    expect(
      find.text("System follows your phone's light or dark setting."),
      findsOneWidget,
    );
    expect(
      t.getSemantics(find.byKey(const ValueKey('appearance-system'))),
      matchesSemantics(
        label: 'System',
        isButton: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
        hasSelectedState: true,
      ),
    );
  });

  testWidgets('picking Dark and Light persists and switches the theme', (
    t,
  ) async {
    final repo = FakeSettingsRepo();
    await pumpApp(
      t,
      initialLocation: '/settings',
      overrides: [settingsRepoProvider.overrideWithValue(repo)],
    );

    await t.tap(find.byKey(const ValueKey('appearance-dark')));
    await t.pumpAndSettle();
    expect((await repo.get()).themeMode, AppThemeMode.dark);
    expect(_themeMode(t), ThemeMode.dark);
    expect(
      Theme.of(t.element(find.byType(AppearanceControl))).brightness,
      Brightness.dark,
    );

    await t.tap(find.byKey(const ValueKey('appearance-light')));
    await t.pumpAndSettle();
    expect((await repo.get()).themeMode, AppThemeMode.light);
    expect(_themeMode(t), ThemeMode.light);

    await t.tap(find.byKey(const ValueKey('appearance-system')));
    await t.pumpAndSettle();
    expect(_themeMode(t), ThemeMode.system);
  });

  testWidgets('a stored choice survives a restart', (t) async {
    final repo = FakeSettingsRepo(
      const AppSettings(themeMode: AppThemeMode.dark),
    );
    await pumpApp(
      t,
      initialLocation: '/settings',
      overrides: [settingsRepoProvider.overrideWithValue(repo)],
    );
    expect(_themeMode(t), ThemeMode.dark);
  });
}
