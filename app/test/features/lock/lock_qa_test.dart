import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_page.dart';
import 'package:storize_app/features/lock/biometric_auth.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/features/lock/lock_flows.dart';
import 'package:storize_app/features/lock/lock_page.dart';
import 'package:storize_app/features/settings/app_lock_row.dart';
import 'package:storize_app/features/targets/target_detail_page.dart';
import 'package:storize_app/features/viewer/story_viewer_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_data/security/pin_vault.dart';

import '../../helpers/app_harness.dart';
import 'lock_fakes.dart';

// QA tests for T-034 (independent of the developer's tests).

Future<void> _enter(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.text(d));
    await t.pump();
  }
  await t.pump();
}

void _background(WidgetTester t) => t.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

void _foreground(WidgetTester t) => t.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

class _FakeLocalAuth implements LocalAuthentication {
  _FakeLocalAuth({
    this.canCheck = true,
    this.types = const [],
    this.result = true,
    this.throws = false,
  });

  final bool canCheck;
  final List<BiometricType> types;
  final bool result;
  final bool throws;
  bool? lastBiometricOnly;

  @override
  Future<bool> get canCheckBiometrics async {
    if (throws) throw PlatformException(code: 'x');
    return canCheck;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (throws) throw PlatformException(code: 'x');
    return types;
  }

  // `authenticate` is routed through noSuchMethod so the test does not need
  // the platform-interface types.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      lastBiometricOnly =
          invocation.namedArguments[#biometricOnly] as bool? ?? false;
      if (throws) return Future<bool>.error(PlatformException(code: 'x'));
      return Future<bool>.value(result);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('QA fail-closed default and unwired providers (F-1)', () {
    test('lock enabled in settings but nothing opted out: locked', () async {
      final f = LockFixture(pin: '1234');
      final c = ProviderContainer(
        overrides: [
          settingsRepoProvider.overrideWithValue(f.settings),
          pinStoreProvider.overrideWithValue(f.pins),
          biometricAuthProvider.overrideWithValue(f.bio),
          clockProvider.overrideWithValue(f.clock),
        ],
      );
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      await settle();
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(c.read(appLockedProvider), isTrue);
    });

    test('every provider unwired: locked (failed), no crash, unlock() is a '
        'no-op', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      await settle();
      expect(c.read(lockControllerProvider).phase, LockPhase.failed);
      expect(c.read(appLockedProvider), isTrue);
      c.read(lockControllerProvider.notifier).unlock();
      expect(c.read(appLockedProvider), isTrue);
    });

    test('settings fine, PIN store unwired: locked, no crash', () async {
      final f = LockFixture(pin: '1234');
      final c = ProviderContainer(
        overrides: [settingsRepoProvider.overrideWithValue(f.settings)],
      );
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      await settle();
      expect(c.read(appLockedProvider), isTrue);
    });

    test('clock unwired: a background event locks and never throws', () async {
      final f = LockFixture(pin: '1234');
      final c = ProviderContainer(
        overrides: [
          settingsRepoProvider.overrideWithValue(f.settings),
          pinStoreProvider.overrideWithValue(f.pins),
          biometricAuthProvider.overrideWithValue(f.bio),
        ],
      );
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      await settle();
      final n = c.read(lockControllerProvider.notifier)..unlock();
      expect(c.read(appLockedProvider), isFalse);
      n.onLifecycle(AppLifecycleState.hidden);
      expect(c.read(appLockedProvider), isTrue);
    });

    test('only the explicit test opt-out unlocks the app', () {
      final c = ProviderContainer(
        overrides: [appLockTestBypassProvider.overrideWithValue(true)],
      );
      addTearDown(c.dispose);
      expect(c.read(appLockedProvider), isFalse);
    });
  });

  group('QA lifecycle boundaries (AC4)', () {
    ProviderContainer make(LockFixture f) {
      final c = ProviderContainer(overrides: f.overrides);
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      return c;
    }

    Future<ProviderContainer> unlocked(LockFixture f) async {
      final c = make(f);
      await settle();
      c.read(lockControllerProvider.notifier).unlock();
      return c;
    }

    Future<bool> lockedAfterAway(Duration away) async {
      final f = LockFixture(pin: '1234');
      final c = await unlocked(f);
      final n = c.read(lockControllerProvider.notifier)
        ..onLifecycle(AppLifecycleState.inactive)
        ..onLifecycle(AppLifecycleState.hidden)
        ..onLifecycle(AppLifecycleState.paused);
      f.clock.advance(away);
      n
        ..onLifecycle(AppLifecycleState.hidden)
        ..onLifecycle(AppLifecycleState.inactive)
        ..onLifecycle(AppLifecycleState.resumed);
      return c.read(appLockedProvider);
    }

    test('0 s, 59.999 s: open', () async {
      expect(await lockedAfterAway(Duration.zero), isFalse);
      expect(
        await lockedAfterAway(const Duration(seconds: 59, milliseconds: 999)),
        isFalse,
      );
    });

    test('60.000 s, 61 s, 1 day: locked', () async {
      expect(await lockedAfterAway(const Duration(seconds: 60)), isTrue);
      expect(await lockedAfterAway(const Duration(seconds: 61)), isTrue);
      expect(await lockedAfterAway(const Duration(days: 1)), isTrue);
    });

    test('clock moved back 1 ms while away: locked', () async {
      expect(await lockedAfterAway(const Duration(milliseconds: -1)), isTrue);
    });

    test('inactive only (system biometric prompt), however long: '
        'no re-lock and no loop', () async {
      final f = LockFixture(pin: '1234');
      final c = await unlocked(f);
      final n = c.read(lockControllerProvider.notifier)
        ..onLifecycle(AppLifecycleState.inactive);
      f.clock.advance(const Duration(minutes: 10));
      n.onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isFalse);
    });

    test('while locked, resume keeps it locked and unlock still needs '
        'unlock()', () async {
      final f = LockFixture(pin: '1234');
      final c = make(f);
      await settle();
      final n = c.read(lockControllerProvider.notifier)
        ..onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 5));
      n.onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isTrue);
    });

    test('after a re-lock and unlock, a resume without a new background '
        'does not lock again', () async {
      final f = LockFixture(pin: '1234');
      final c = await unlocked(f);
      final n = c.read(lockControllerProvider.notifier)
        ..onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 90));
      n
        ..onLifecycle(AppLifecycleState.resumed)
        ..unlock()
        ..onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isFalse);
    });

    test(
      'lock off after disable(): never re-locks, flag and PIN gone',
      () async {
        final f = LockFixture(pin: '1234');
        final c = await unlocked(f);
        final n = c.read(lockControllerProvider.notifier);
        await n.disable();
        n.onLifecycle(AppLifecycleState.paused);
        f.clock.advance(const Duration(hours: 1));
        n.onLifecycle(AppLifecycleState.resumed);
        expect(c.read(appLockedProvider), isFalse);
        expect((await f.settings.get()).appLockEnabled, isFalse);
        expect(f.pins.storedPin, isNull);
      },
    );
  });

  group('QA gate coverage (AC6)', () {
    testWidgets('pages pushed before the re-lock are dropped; the lock '
        'screen shows no app content', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await _enter(t, '1234');
      await t.pumpAndSettle();
      await h.go('/targets/3');
      await h.push('/story/9');
      expect(_story(9), findsOneWidget);
      _background(t);
      f.clock.advance(const Duration(seconds: 61));
      _foreground(t);
      await t.pumpAndSettle();
      expect(find.byType(LockPage), findsOneWidget);
      expect(_story(9), findsNothing);
      expect(_target(3), findsNothing);
      expect(find.byType(LibraryPage), findsNothing);
    });

    testWidgets('a plain Navigator route (e.g. the S-12 PIN confirmation) '
        'does not survive the re-lock', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await _enter(t, '1234');
      await t.pumpAndSettle();
      expect(h.location, '/library');
      unawaited(
        Navigator.of(
          t.element(find.byType(LibraryPage)),
          rootNavigator: true,
        ).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('SECRET-PAGE')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('SECRET-PAGE'), findsOneWidget);
      _background(t);
      f.clock.advance(const Duration(seconds: 61));
      _foreground(t);
      await t.pumpAndSettle();
      expect(find.text('SECRET-PAGE'), findsNothing);
      expect(find.byType(LockPage), findsOneWidget);
    });

    testWidgets('re-lock during the "turn off" confirmation: the lock '
        'stays on and nothing is disabled', (t) async {
      t.view
        ..physicalSize = const Size(800, 1800)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final f = LockFixture(pin: '1234');
      await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await _enter(t, '1234');
      await t.pumpAndSettle();
      // The S-12 row pushes ConfirmIdentityPage on the root navigator.
      unawaited(
        Navigator.of(
          t.element(find.byType(LibraryPage)),
          rootNavigator: true,
        ).push<bool>(
          MaterialPageRoute(builder: (_) => const ConfirmIdentityPage()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text("Confirm it's you"), findsOneWidget);
      _background(t);
      f.clock.advance(const Duration(seconds: 61));
      _foreground(t);
      await t.pumpAndSettle();
      expect(find.text("Confirm it's you"), findsNothing);
      expect(find.byType(LockPage), findsOneWidget);
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(f.pins.storedPin, '1234');
    });

    testWidgets('the lock screen shows only the logo, title and keypad', (
      t,
    ) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await h.go('storize://story/77');
      final texts = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
          .toSet();
      expect(
        texts.difference({
          'Storize is locked',
          'Use your fingerprint or PIN',
          '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', //
        }),
        isEmpty,
        reason: 'unexpected text on the lock screen: $texts',
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('redirect fuzz while locked: always settles on /lock, '
        'never throws', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      for (final loc in [
        '/lock',
        '/lock?from=/lock',
        '/lock?from=%2Flock%3Ffrom%3D%2Flock',
        '/lock?from=//evil.example',
        '/lock?from=storize://story/1',
        '/lock?from=https://evil.example',
        '/library',
        '/story/1',
        '/story/abc',
        '/targets/add',
        '/settings',
        '/account',
        '/unknown',
        '/',
        '',
        'storize://lock',
        'storize://story/5',
        'storize://settings/storage',
        'storize://account',
        'http://evil.example/x',
        '/welcome',
        '/login',
        '/setup',
      ]) {
        await h.go(loc);
        expect(
          h.location.startsWith('/lock'),
          isTrue,
          reason: '"$loc" ended at ${h.location}',
        );
        expect(find.byType(LibraryPage), findsNothing, reason: loc);
        expect(t.takeException(), isNull, reason: loc);
      }
    });

    testWidgets('after unlock a hostile "from" cannot leave the app or '
        'land on /lock', (t) async {
      for (final from in [
        '//evil.example',
        'https://evil.example',
        'storize://story/1',
        '/lock',
        '/lock?from=/lock',
        'javascript:alert(1)',
        '',
      ]) {
        final f = LockFixture(pin: '1234');
        final h = await pumpApp(
          t,
          bypassLock: false,
          overrides: f.overrides,
          initialLocation: Uri(
            path: '/lock',
            queryParameters: {'from': from},
          ).toString(),
        );
        await _enter(t, '1234');
        await t.pumpAndSettle();
        expect(h.location, '/library', reason: 'from="$from"');
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('lock on, onboarding incomplete: the lock comes first', (
      t,
    ) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(
        t,
        bypassLock: false,
        overrides: [
          ...f.overrides,
          onboardingCompleteProvider.overrideWithValue(false),
        ],
      );
      expect(h.location.startsWith('/lock'), isTrue);
      expect(find.byType(LockPage), findsOneWidget);
    });
  });

  group('QA enable / disable', () {
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

    testWidgets('no strong biometric: no method sheet, no prompt, straight '
        'to the PIN setup', (t) async {
      final f = LockFixture(enabled: false);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(find.text('Use fingerprint'), findsNothing);
      expect(find.text('Create a PIN'), findsOneWidget);
      expect(f.bio.prompts, 0);
    });

    testWidgets('mismatched PIN confirmation stores nothing and leaves the '
        'lock off', (t) async {
      final f = LockFixture(enabled: false);
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await _enter(t, '2468');
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await _enter(t, '2469');
      await t.tap(find.text('Save PIN'));
      await t.pumpAndSettle();
      expect(f.pins.storedPin, isNull);
      expect((await f.settings.get()).appLockEnabled, isFalse);
    });

    testWidgets('turning off with a failing PIN 5 times starts the cooldown '
        'and never disables', (t) async {
      final f = LockFixture(pin: '1234');
      await pumpRow(t, f);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await _enter(t, '9999');
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(f.pins.cooldown, isNotNull);
      await _enter(t, '1234');
      await t.pump(const Duration(milliseconds: 400));
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(f.pins.storedPin, '1234');
      // Stop the countdown timer.
      await t.pumpWidget(const SizedBox());
    });
  });

  group('QA reset state (F-3)', () {
    testWidgets('biometric-only lock, sensor unavailable: stays locked with a '
        'retry and never offers a new PIN', (t) async {
      tall(t);
      final f = LockFixture(marker: LockMethod.biometric);
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(find.text('App lock was reset'), findsNothing);
      expect(find.text('Create a PIN'), findsNothing);
      expect(
        find.text('Fingerprint is not available right now. Try again.'),
        findsOneWidget,
      );
      expect(h.location.startsWith('/lock'), isTrue);
      // The sensor comes back: Retry prompts and unlocks.
      f.bio.available = true;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(h.location, '/library');
    });

    testWidgets('a secure-storage read error stays locked with a retry and '
        'keeps the saved PIN', (t) async {
      tall(t);
      final f = LockFixture(pin: '1234');
      f.pins.unreadable = true;
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(
        find.text("Couldn't read the saved lock. Try again."),
        findsOneWidget,
      );
      expect(find.text('Create a PIN'), findsNothing);
      expect(find.text('App lock was reset'), findsNothing);
      f.pins.unreadable = false;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('Storize is locked'), findsOneWidget);
      expect(f.pins.storedPin, '1234');
      expect(h.location.startsWith('/lock'), isTrue);
    });

    testWidgets('a real wipe (setting on, marker and PIN gone) offers a new '
        'PIN', (t) async {
      tall(t);
      final f = LockFixture(marker: LockMethod.pin);
      f.pins.wipe();
      await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(find.text('App lock was reset'), findsOneWidget);
    });

    testWidgets('a wipe with a working sensor does not unlock by biometric', (
      t,
    ) async {
      tall(t);
      final f = LockFixture(biometric: true);
      f.pins.wipe();
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(f.bio.prompts, 0);
      expect(find.text('App lock was reset'), findsOneWidget);
      expect(h.location.startsWith('/lock'), isTrue);
    });

    testWidgets('reset state never unlocks by itself, not even after '
        'resume cycles', (t) async {
      final f = LockFixture();
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      _background(t);
      f.clock.advance(const Duration(minutes: 5));
      _foreground(t);
      await t.pump(const Duration(seconds: 2));
      expect(h.location.startsWith('/lock'), isTrue);
    });
  });

  group('QA LocalAuthBiometric wrapper', () {
    test('available only with a strong biometric', () async {
      expect(
        await LocalAuthBiometric(_FakeLocalAuth(types: [BiometricType.strong]))
            .isAvailable(),
        isTrue,
      );
      expect(
        await LocalAuthBiometric(_FakeLocalAuth(types: [BiometricType.weak]))
            .isAvailable(),
        isFalse,
      );
      expect(await LocalAuthBiometric(_FakeLocalAuth()).isAvailable(), isFalse);
      expect(
        await LocalAuthBiometric(
          _FakeLocalAuth(canCheck: false, types: [BiometricType.strong]),
        ).isAvailable(),
        isFalse,
      );
    });

    test('platform errors mean unavailable / failed, never a throw', () async {
      final b = LocalAuthBiometric(_FakeLocalAuth(throws: true));
      expect(await b.isAvailable(), isFalse);
      expect(await b.authenticate('r'), isFalse);
    });

    test('authenticate asks for biometricOnly and passes the result', () async {
      final ok = _FakeLocalAuth();
      expect(await LocalAuthBiometric(ok).authenticate('r'), isTrue);
      expect(ok.lastBiometricOnly, isTrue);
      expect(
        await LocalAuthBiometric(_FakeLocalAuth(result: false))
            .authenticate('r'),
        isFalse,
      );
    });
  });
}

void tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(800, 1800)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Finder _story(int id) => find.byWidgetPredicate(
  (w) => w is StoryViewerPage && w.contentId == id,
  description: 'StoryViewerPage(contentId: $id)',
);

Finder _target(int id) => find.byWidgetPredicate(
  (w) => w is TargetDetailPage && w.targetId == id,
  description: 'TargetDetailPage(targetId: $id)',
);
