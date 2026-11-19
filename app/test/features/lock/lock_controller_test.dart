import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_domain/storize_domain.dart';

import 'lock_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer make(LockFixture f) {
    final c = ProviderContainer(overrides: f.overrides);
    addTearDown(c.dispose);
    c.listen(lockControllerProvider, (_, _) {});
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  LockController ctl(ProviderContainer c) =>
      c.read(lockControllerProvider.notifier);

  test('unwired app is never locked (other screens need no fakes)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(appLockedProvider), isFalse);
  });

  group('cold start', () {
    test('lock on: locked at once, still locked after the read', () async {
      final f = LockFixture(pin: '1234');
      final c = make(f);
      expect(c.read(appLockedProvider), isTrue);
      expect(c.read(lockControllerProvider).phase, LockPhase.checking);
      await settle();
      expect(c.read(lockControllerProvider).phase, LockPhase.locked);
      expect(c.read(appLockedProvider), isTrue);
    });

    test('lock off: unlocked after the read', () async {
      final c = make(LockFixture(enabled: false));
      expect(c.read(appLockedProvider), isTrue, reason: 'unknown = locked');
      await settle();
      expect(c.read(appLockedProvider), isFalse);
    });

    test('unreadable setting stays locked and Retry recovers', () async {
      final f = LockFixture(pin: '1234');
      final c = ProviderContainer(
        overrides: f.overridesWith(settingsRepo: _FailingSettings(f.settings)),
      );
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      await settle();
      expect(c.read(lockControllerProvider).phase, LockPhase.failed);
      expect(c.read(appLockedProvider), isTrue);
      ctl(c).unlock();
      expect(
        c.read(appLockedProvider),
        isTrue,
        reason: 'no unlock from failed',
      );
      _FailingSettings.fail = false;
      await ctl(c).refresh();
      expect(c.read(lockControllerProvider).phase, LockPhase.locked);
    });
  });

  group('unlock', () {
    test('unlock opens the gate', () async {
      final c = make(LockFixture(pin: '1234'));
      await settle();
      ctl(c).unlock();
      expect(c.read(appLockedProvider), isFalse);
    });

    test('unlock before the settings are read does nothing', () {
      final c = make(LockFixture(pin: '1234'));
      ctl(c).unlock();
      expect(c.read(appLockedProvider), isTrue);
    });
  });

  group('re-lock after the background (AC4)', () {
    Future<(ProviderContainer, LockFixture)> unlocked({
      bool enabled = true,
    }) async {
      final f = LockFixture(enabled: enabled, pin: '1234');
      final c = make(f);
      await settle();
      ctl(c).unlock();
      return (c, f);
    }

    test('59 s away: still unlocked', () async {
      final (c, f) = await unlocked();
      ctl(c).onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 59));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isFalse);
    });

    test('60 s away: locked', () async {
      final (c, f) = await unlocked();
      ctl(c).onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 60));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isTrue);
      expect(c.read(lockControllerProvider).phase, LockPhase.locked);
    });

    test('hidden then paused counts from the first one', () async {
      final (c, f) = await unlocked();
      ctl(c).onLifecycle(AppLifecycleState.hidden);
      f.clock.advance(const Duration(seconds: 40));
      ctl(c).onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 20));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isTrue);
    });

    test('inactive (system dialogs) does not start the timer', () async {
      final (c, f) = await unlocked();
      ctl(c).onLifecycle(AppLifecycleState.inactive);
      f.clock.advance(const Duration(minutes: 10));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isFalse);
    });

    test('clock moved backwards while away: locks', () async {
      final (c, f) = await unlocked();
      ctl(c).onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: -30));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isTrue);
    });

    test('short trips reset the timer each time', () async {
      final (c, f) = await unlocked();
      for (var i = 0; i < 3; i++) {
        ctl(c).onLifecycle(AppLifecycleState.paused);
        f.clock.advance(const Duration(seconds: 40));
        ctl(c).onLifecycle(AppLifecycleState.resumed);
      }
      expect(c.read(appLockedProvider), isFalse);
    });

    test('lock off: never re-locks', () async {
      final (c, f) = await unlocked(enabled: false);
      ctl(c).onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(hours: 5));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isFalse);
    });

    test('a real lifecycle event from the binding re-locks', () async {
      final (c, f) = await unlocked();
      final b = TestWidgetsFlutterBinding.instance
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 61));
      b
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isTrue);
    });
  });

  group('turning the lock on and off', () {
    test('enableWithPin stores the PIN, sets the flag, stays open', () async {
      final f = LockFixture(enabled: false);
      final c = make(f);
      await settle();
      await ctl(c).enableWithPin('2468');
      expect(f.pins.storedPin, '2468');
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(c.read(appLockedProvider), isFalse);
      // And the re-lock now applies.
      ctl(c).onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(seconds: 60));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isTrue);
    });

    test('enableWithBiometric sets the flag and keeps no PIN', () async {
      final f = LockFixture(enabled: false, pin: '9999', biometric: true);
      final c = make(f);
      await settle();
      await ctl(c).enableWithBiometric();
      expect(f.pins.storedPin, isNull);
      expect((await f.settings.get()).appLockEnabled, isTrue);
    });

    test('disable clears the flag and the PIN', () async {
      final f = LockFixture(pin: '2468');
      final c = make(f);
      await settle();
      ctl(c).unlock();
      await ctl(c).disable();
      expect(f.pins.storedPin, isNull);
      expect((await f.settings.get()).appLockEnabled, isFalse);
      ctl(c).onLifecycle(AppLifecycleState.paused);
      f.clock.advance(const Duration(minutes: 5));
      ctl(c).onLifecycle(AppLifecycleState.resumed);
      expect(c.read(appLockedProvider), isFalse);
    });
  });
}

class _FailingSettings implements SettingsRepo {
  _FailingSettings(this._inner) {
    fail = true;
  }

  static bool fail = true;
  final SettingsRepo _inner;

  @override
  Future<AppSettings> get() async {
    if (fail) throw StateError('prefs');
    return _inner.get();
  }

  @override
  Stream<AppSettings> watch() => _inner.watch();

  @override
  Future<AppSettings> update(AppSettings Function(AppSettings) change) =>
      _inner.update(change);
}
