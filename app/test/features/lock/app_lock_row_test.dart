import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/features/settings/app_lock_row.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

import 'lock_fakes.dart';

Future<ProviderContainer> pumpRow(WidgetTester t, LockFixture f) async {
  t.view
    ..physicalSize = const Size(800, 1800)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: f.overrides,
      child: MaterialApp(
        theme: StorizeTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AppLockRow()),
      ),
    ),
  );
  await t.pumpAndSettle();
  return ProviderScope.containerOf(t.element(find.byType(AppLockRow)));
}

Future<void> enter(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.text(d));
    await t.pump();
  }
}

bool _switchOn(WidgetTester t) => t.widget<Switch>(find.byType(Switch)).value;

void main() {
  testWidgets('shows the row, the switch and the gallery note', (t) async {
    await pumpRow(t, LockFixture(enabled: false));
    expect(find.text('App lock'), findsOneWidget);
    expect(
      find.text(
        'Files saved to your gallery are not protected by the app lock.',
      ),
      findsOneWidget,
    );
    expect(_switchOn(t), isFalse);
  });

  group('turning on with a PIN (AC1)', () {
    testWidgets('PIN entered twice and matching: lock turns on', (t) async {
      final f = LockFixture(enabled: false);
      final c = await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(find.text('Create a PIN'), findsOneWidget);
      await enter(t, '2468');
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(find.text('Enter the PIN again'), findsOneWidget);
      await enter(t, '2468');
      await t.tap(find.text('Save PIN'));
      await t.pumpAndSettle();
      expect(f.pins.storedPin, '2468');
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(_switchOn(t), isTrue);
      expect(find.text('App lock is on'), findsOneWidget);
      expect(c.read(lockControllerProvider).locked, isFalse);
    });

    testWidgets('a mismatch shows an error and starts over', (t) async {
      final f = LockFixture(enabled: false);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await enter(t, '2468');
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await enter(t, '1357');
      await t.tap(find.text('Save PIN'));
      await t.pumpAndSettle();
      expect(find.text("The PINs don't match. Try again."), findsOneWidget);
      expect(find.text('Create a PIN'), findsOneWidget);
      expect(f.pins.storedPin, isNull);
      expect((await f.settings.get()).appLockEnabled, isFalse);
    });

    testWidgets('fewer than 4 digits cannot continue; 6 is the maximum', (
      t,
    ) async {
      final f = LockFixture(enabled: false);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      Finder button() => find.widgetWithText(FilledButton, 'Continue');
      await enter(t, '123');
      expect(t.widget<FilledButton>(button()).onPressed, isNull);
      await enter(t, '4');
      expect(t.widget<FilledButton>(button()).onPressed, isNotNull);
      await enter(t, '56789');
      await t.tap(button());
      await t.pumpAndSettle();
      await enter(t, '123456');
      await t.tap(find.text('Save PIN'));
      await t.pumpAndSettle();
      expect(f.pins.storedPin, '123456', reason: 'the 7th digit is ignored');
    });

    testWidgets('backspace removes a digit', (t) async {
      final f = LockFixture(enabled: false);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await enter(t, '1234');
      await t.tap(find.byIcon(Icons.backspace_outlined));
      await t.pump();
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('closing the setup leaves the lock off', (t) async {
      final f = LockFixture(enabled: false);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.close_rounded));
      await t.pumpAndSettle();
      expect(_switchOn(t), isFalse);
      expect(find.text('App lock was not turned on'), findsOneWidget);
    });
  });

  group('turning on with a fingerprint (AC1)', () {
    testWidgets('confirmed fingerprint turns the lock on, no PIN', (t) async {
      final f = LockFixture(enabled: false, biometric: true);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('Use fingerprint'));
      await t.pumpAndSettle();
      expect(f.bio.lastReason, 'Confirm your fingerprint to turn on app lock');
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(f.pins.storedPin, isNull);
      expect(_switchOn(t), isTrue);
    });

    testWidgets('a failed fingerprint leaves the lock off', (t) async {
      final f = LockFixture(enabled: false, biometric: true);
      f.bio.succeeds = false;
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('Use fingerprint'));
      await t.pumpAndSettle();
      expect((await f.settings.get()).appLockEnabled, isFalse);
      expect(_switchOn(t), isFalse);
      expect(find.text('App lock was not turned on'), findsOneWidget);
    });

    testWidgets('the sheet also offers a PIN', (t) async {
      final f = LockFixture(enabled: false, biometric: true);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('Use a PIN'));
      await t.pumpAndSettle();
      expect(find.text('Create a PIN'), findsOneWidget);
      expect(f.bio.prompts, 0);
    });

    testWidgets('dismissing the sheet changes nothing', (t) async {
      final f = LockFixture(enabled: false, biometric: true);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(_switchOn(t), isFalse);
      expect((await f.settings.get()).appLockEnabled, isFalse);
    });
  });

  group('turning off needs authentication (AC5)', () {
    testWidgets('wrong PIN keeps the lock on', (t) async {
      final f = LockFixture(pin: '1234');
      await pumpRow(t, f);
      expect(_switchOn(t), isTrue);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(find.text("Confirm it's you"), findsOneWidget);
      await enter(t, '9999');
      await t.pumpAndSettle();
      expect(find.text('Wrong PIN'), findsOneWidget);
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(f.pins.storedPin, '1234');
    });

    testWidgets('correct PIN turns it off and forgets the PIN', (t) async {
      final f = LockFixture(pin: '1234');
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await enter(t, '1234');
      await t.pumpAndSettle();
      expect((await f.settings.get()).appLockEnabled, isFalse);
      expect(f.pins.storedPin, isNull);
      expect(_switchOn(t), isFalse);
      expect(find.text('App lock is off'), findsOneWidget);
    });

    testWidgets('closing the confirmation keeps the lock on', (t) async {
      final f = LockFixture(pin: '1234');
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.close_rounded));
      await t.pumpAndSettle();
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(_switchOn(t), isTrue);
    });

    testWidgets('a fingerprint can confirm it', (t) async {
      final f = LockFixture(pin: '1234', biometric: true);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(f.bio.lastReason, 'Confirm to turn off app lock');
      expect((await f.settings.get()).appLockEnabled, isFalse);
    });

    testWidgets('a failed fingerprint (biometric-only) keeps it on', (t) async {
      final f = LockFixture(biometric: true);
      f.bio.succeeds = false;
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(find.text('Unlock with fingerprint'), findsOneWidget);
    });
  });
}
