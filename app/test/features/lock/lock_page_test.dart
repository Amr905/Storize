import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/app.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_page.dart';
import 'package:storize_app/features/lock/lock_page.dart';
import 'package:storize_app/features/viewer/post_viewer_page.dart';
import 'package:storize_app/features/viewer/story_viewer_page.dart';
import 'package:storize_app/router/app_router.dart';
import 'package:storize_app/router/app_shell.dart';
import 'package:storize_domain/testing.dart';

import '../../helpers/app_harness.dart';
import 'lock_fakes.dart';

/// A phone-sized view tall enough for the PIN setup screen.
void tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(800, 1800)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> enter(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.text(d));
    await t.pump();
  }
  await t.pump();
}

/// Pumps the app without pumpAndSettle (a running cooldown ticks forever).
Future<ProviderContainer> pumpLocked(
  WidgetTester t,
  LockFixture f, {
  String? initialLocation,
}) async {
  await t.pumpWidget(
    StorizeApp(
      overrides: [
        accountRepoProvider.overrideWithValue(FakeAccountRepo()),
        initialLocationProvider.overrideWithValue(initialLocation),
        ...f.overrides,
      ],
    ),
  );
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

String _location(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('cold start', () {
    testWidgets('shows only the lock screen, no app content', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(find.byType(LockPage), findsOneWidget);
      expect(find.text('Storize is locked'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(LibraryPage), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(h.location.startsWith('/lock'), isTrue);
    });

    testWidgets('lock off: straight to the Library', (t) async {
      final f = LockFixture(enabled: false);
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(find.byType(LockPage), findsNothing);
      expect(h.location, '/library');
    });

    testWidgets('correct PIN unlocks and returns to the Library', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await enter(t, '1234');
      await t.pumpAndSettle();
      expect(h.location, '/library');
      expect(find.byType(LockPage), findsNothing);
    });

    testWidgets('a 6-digit PIN needs all six digits', (t) async {
      final f = LockFixture(pin: '135790');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await enter(t, '1357');
      expect(f.pins.verifyCalls, 0);
      await enter(t, '90');
      await t.pumpAndSettle();
      expect(h.location, '/library');
    });
  });

  group('wrong PIN', () {
    testWidgets('shows "Wrong PIN", clears the dots, stays locked', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await enter(t, '9999');
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Wrong PIN'), findsOneWidget);
      expect(h.location.startsWith('/lock'), isTrue);
      // Dots are empty again: typing the right PIN works.
      await enter(t, '1234');
      await t.pumpAndSettle();
      expect(h.location, '/library');
    });

    testWidgets('the error clears on the next digit', (t) async {
      final f = LockFixture(pin: '1234');
      await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await enter(t, '9999');
      expect(find.text('Wrong PIN'), findsOneWidget);
      await t.tap(find.text('1'));
      await t.pump();
      expect(find.text('Wrong PIN'), findsNothing);
    });
  });

  group('cooldown (AC3)', () {
    testWidgets('5 wrong PINs: 30 s countdown, keys off, then it ends', (
      t,
    ) async {
      final f = LockFixture(pin: '1234');
      final c = await pumpLocked(t, f);
      for (var i = 0; i < 5; i++) {
        await enter(t, '9999');
      }
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Try again in 0:30'), findsOneWidget);
      expect(f.pins.cooldown, const Duration(seconds: 30));

      // Keys are ignored during the cooldown.
      final calls = f.pins.verifyCalls;
      await enter(t, '1234');
      expect(f.pins.verifyCalls, calls);

      await t.pump(const Duration(seconds: 1));
      expect(find.text('Try again in 0:29'), findsOneWidget);
      await t.pump(const Duration(seconds: 9));
      expect(find.text('Try again in 0:20'), findsOneWidget);

      f.pins.advance(const Duration(seconds: 30));
      await t.pump(const Duration(seconds: 20));
      await t.pump();
      expect(find.textContaining('Try again'), findsNothing);

      await enter(t, '1234');
      await t.pump(const Duration(milliseconds: 500));
      expect(_location(c), '/library');
    });

    testWidgets('a cooldown from before an app restart is shown', (t) async {
      final f = LockFixture(pin: '1234');
      f.pins.cooldown = const Duration(seconds: 20);
      final c = await pumpLocked(t, f);
      expect(find.text('Try again in 0:20'), findsOneWidget);
      await enter(t, '1234');
      expect(f.pins.verifyCalls, 0);
      expect(_location(c).startsWith('/lock'), isTrue);
    });
  });

  group('biometric', () {
    testWidgets('the prompt opens automatically; success unlocks', (t) async {
      final f = LockFixture(pin: '1234', biometric: true);
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(f.bio.prompts, 1);
      expect(f.bio.lastReason, 'Unlock Storize');
      expect(h.location, '/library');
    });

    testWidgets('cancel falls back to the PIN pad and a retry key', (t) async {
      final f = LockFixture(pin: '1234', biometric: true);
      f.bio.succeeds = false;
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(f.bio.prompts, 1);
      expect(h.location.startsWith('/lock'), isTrue);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
      f.bio.succeeds = true;
      await t.tap(find.byIcon(Icons.fingerprint_rounded));
      await t.pumpAndSettle();
      expect(f.bio.prompts, 2);
      expect(h.location, '/library');
    });

    testWidgets('biometric only: no pad, a button reopens the prompt', (
      t,
    ) async {
      final f = LockFixture(biometric: true);
      f.bio.succeeds = false;
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(find.text('5'), findsNothing);
      expect(find.text('Unlock with fingerprint'), findsOneWidget);
      f.bio.succeeds = true;
      await t.tap(find.text('Unlock with fingerprint'));
      await t.pumpAndSettle();
      expect(h.location, '/library');
    });

    testWidgets('no biometric hardware: PIN only, no prompt', (t) async {
      final f = LockFixture(pin: '1234');
      await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(f.bio.prompts, 0);
      expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);
    });
  });

  group('deep links (AC6)', () {
    testWidgets('a link at cold start waits behind the lock', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(
        t,
        bypassLock: false,
        overrides: f.overrides,
        initialLocation: 'storize://story/77',
      );
      expect(h.location.startsWith('/lock'), isTrue);
      expect(_story(77), findsNothing);
      await enter(t, '1234');
      await t.pumpAndSettle();
      expect(h.location, '/story/77');
      expect(_story(77), findsOneWidget);
    });

    testWidgets('a link that arrives while locked is kept', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await h.go('storize://post/5');
      expect(h.location.startsWith('/lock'), isTrue);
      expect(_post(5), findsNothing);
      await enter(t, '1234');
      await t.pumpAndSettle();
      expect(h.location, '/post/5');
      expect(_post(5), findsOneWidget);
    });

    testWidgets('re-lock after 60 s returns to the same page', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await enter(t, '1234');
      await t.pumpAndSettle();
      await h.go('/targets/3');
      t.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 60));
      t.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.byType(LockPage), findsOneWidget);
      expect(find.text('targetId=3'), findsNothing);
      await enter(t, '1234');
      await t.pumpAndSettle();
      expect(h.location, '/targets/3');
    });

    testWidgets('59 s in the background does not lock', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await enter(t, '1234');
      await t.pumpAndSettle();
      t.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 59));
      t.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(h.location, '/library');
    });
  });

  group('reset state (T-008 N-1)', () {
    testWidgets('lock on but no PIN and no biometric: forces a new PIN', (
      t,
    ) async {
      tall(t);
      final f = LockFixture(); // enabled, nothing stored
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(h.location.startsWith('/lock'), isTrue);
      expect(find.text('App lock was reset'), findsOneWidget);
      expect(find.textContaining('Create a new PIN'), findsOneWidget);
      expect(find.byType(LibraryPage), findsNothing);
      // Nothing unlocks it by itself.
      await t.pump(const Duration(minutes: 1));
      expect(h.location.startsWith('/lock'), isTrue);
    });

    testWidgets('a wiped PIN is noticed when it is typed', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      f.pins.wipe();
      await enter(t, '1234');
      await t.pumpAndSettle();
      expect(h.location.startsWith('/lock'), isTrue);
      expect(find.text('App lock was reset'), findsOneWidget);
    });

    testWidgets('creating a new PIN twice unlocks and keeps the lock on', (
      t,
    ) async {
      tall(t);
      final f = LockFixture();
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await enter(t, '2468');
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await enter(t, '2468');
      await t.tap(find.text('Save PIN'));
      await t.pumpAndSettle();
      expect(f.pins.storedPin, '2468');
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(h.location, '/library');
    });

    testWidgets('mismatching entries do not unlock', (t) async {
      tall(t);
      final f = LockFixture();
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      await enter(t, '2468');
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await enter(t, '1357');
      await t.tap(find.text('Save PIN'));
      await t.pumpAndSettle();
      expect(find.text("The PINs don't match. Try again."), findsOneWidget);
      expect(f.pins.storedPin, isNull);
      expect(h.location.startsWith('/lock'), isTrue);
    });

    testWidgets('biometric gone but a PIN exists: PIN still works', (t) async {
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(t, bypassLock: false, overrides: f.overrides);
      expect(find.text('App lock was reset'), findsNothing);
      await enter(t, '1234');
      await t.pumpAndSettle();
      expect(h.location, '/library');
    });
  });

  group('settings unreadable', () {
    testWidgets('shows a retry and stays locked', (t) async {
      final f = LockFixture(pin: '1234');
      final repo = FailingOnceSettings(f.settings);
      final h = await pumpApp(
        t,
        bypassLock: false,
        overrides: f.overridesWith(settingsRepo: repo),
      );
      expect(find.text("Couldn't check the app lock."), findsOneWidget);
      expect(h.location.startsWith('/lock'), isTrue);
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('Storize is locked'), findsOneWidget);
    });
  });
}

Finder _story(int id) => find.byWidgetPredicate(
  (w) => w is StoryViewerPage && w.contentId == id,
  description: 'StoryViewerPage(contentId: $id)',
);

Finder _post(int id) => find.byWidgetPredicate(
  (w) => w is PostViewerPage && w.contentId == id,
  description: 'PostViewerPage(contentId: $id)',
);
