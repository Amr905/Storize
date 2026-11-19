import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/app.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_domain/testing.dart';

void main() {
  testWidgets('root widget pumps and shows the Library tab', (tester) async {
    await tester.pumpWidget(
      StorizeApp(
        overrides: [
          accountRepoProvider.overrideWithValue(FakeAccountRepo()),
          appLockTestBypassProvider.overrideWithValue(true),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsWidgets);
  });

  testWidgets('starts without wiring: fail-closed, locked with a retry '
      '(T-034 F-1)', (tester) async {
    await tester.pumpWidget(const StorizeApp());
    await tester.pumpAndSettle();
    expect(find.text("Couldn't check the app lock."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('every port provider throws until it is overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    for (final p in [
      targetRepoProvider,
      contentRepoProvider,
      accountRepoProvider,
      activityRepoProvider,
      checkRunRepoProvider,
      settingsRepoProvider,
      governorLeaseRepoProvider,
      contentPlatformProvider,
      schedulerProvider,
      clockProvider,
      galleryStoreProvider,
      mediaCacheProvider,
      storageInfoProvider,
      sessionStoreProvider,
    ]) {
      expect(
        () => container.read(p),
        throwsA(
          predicate<Object>((e) => e.toString().contains('is not wired yet')),
        ),
        reason: p.name ?? '$p',
      );
    }
  });
}
