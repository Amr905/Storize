import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/lock/lock_flows.dart';
import 'package:storize_app/features/lock/lock_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

import '../../ui/golden_helpers.dart';
import 'lock_fakes.dart';

Future<void> _enter(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.text(d));
    await t.pump();
  }
}

void _golden(
  String name,
  Widget page, {
  required LockFixture Function() fixture,
  Future<void> Function(WidgetTester t, LockFixture f)? act,
}) {
  for (final brightness in Brightness.values) {
    testWidgets('$name golden (${brightness.name})', (t) async {
      t.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(360, 780);
      addTearDown(t.view.reset);
      final f = fixture();
      final key = GlobalKey();
      await t.pumpWidget(
        ProviderScope(
          overrides: f.overrides,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: brightness == Brightness.light
                ? StorizeTheme.light()
                : StorizeTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(key: key, child: page),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await act?.call(t, f);
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/${name}_${brightness.name}.png'),
      );
    });
  }
}

void main() {
  setUpAll(loadTestFonts);

  group('S-14 goldens', () {
    _golden(
      's14_pin_partial',
      const LockPage(),
      fixture: () => LockFixture(pin: '1234'),
      act: (t, f) async {
        await _enter(t, '12');
        await t.pump(const Duration(milliseconds: 50));
      },
    );
    _golden(
      's14_pin_with_biometric_key',
      const LockPage(),
      fixture: () {
        final f = LockFixture(pin: '123456', biometric: true)
          ..bio.succeeds = false;
        return f;
      },
    );
    _golden(
      's14_wrong_pin',
      const LockPage(),
      fixture: () => LockFixture(pin: '1234'),
      act: (t, f) async {
        await _enter(t, '9999');
        await t.pump(const Duration(milliseconds: 600));
      },
    );
    _golden(
      's14_cooldown',
      const LockPage(),
      fixture: () {
        final f = LockFixture(pin: '1234');
        f.pins.cooldown = const Duration(seconds: 22);
        return f;
      },
    );
    _golden(
      's14_biometric_only',
      const LockPage(),
      fixture: () {
        final f = LockFixture(biometric: true)..bio.succeeds = false;
        return f;
      },
    );
    _golden('s14_reset_state', const LockPage(), fixture: LockFixture.new);
  });

  group('PIN setup goldens (S-12 flow)', () {
    _golden(
      'pin_setup_entering',
      const PinSetupPage(),
      fixture: () => LockFixture(enabled: false),
      act: (t, f) async {
        await _enter(t, '24681');
        await t.pump(const Duration(milliseconds: 50));
      },
    );
    _golden(
      'pin_setup_mismatch',
      const PinSetupPage(),
      fixture: () => LockFixture(enabled: false),
      act: (t, f) async {
        await _enter(t, '2468');
        await t.tap(find.text('Continue'));
        await t.pump();
        await _enter(t, '1357');
        await t.tap(find.text('Save PIN'));
        await t.pump(const Duration(milliseconds: 600));
      },
    );
    _golden(
      'confirm_identity',
      const ConfirmIdentityPage(),
      fixture: () => LockFixture(pin: '1234'),
    );
  });
}
