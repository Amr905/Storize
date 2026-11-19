import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/features/lock/lock_service.dart';
import 'package:storize_data/security/pin_vault.dart';
import 'package:storize_domain/storize_domain.dart';

import '../../helpers/app_harness.dart';
import 'app_lock_row_test.dart' show pumpRow;
import 'lock_fakes.dart';

// QA T-034 round 2: partial wiring, read errors per call, retry behaviour.

/// A PinStore whose individual calls can throw.
class _Throwing extends FakePinStore {
  _Throwing({super.pin, super.marker});

  final Set<String> failing = {};
  int setPinCalls = 0;
  int clearCalls = 0;

  void _f(String n) {
    if (failing.contains(n)) throw const PinStorageException();
  }

  @override
  Future<bool> hasPin() async {
    _f('hasPin');
    return super.hasPin();
  }

  @override
  Future<LockMethod?> method() async {
    _f('method');
    return super.method();
  }

  @override
  Future<int?> pinLength() async {
    _f('pinLength');
    return super.pinLength();
  }

  @override
  Future<Duration?> cooldownRemaining() async {
    _f('cooldown');
    return super.cooldownRemaining();
  }

  @override
  Future<void> setPin(String pin) async {
    setPinCalls++;
    return super.setPin(pin);
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    return super.clear();
  }
}

class _ThrowingBio extends FakeBiometric {
  _ThrowingBio() : super();

  @override
  Future<bool> isAvailable() async => throw StateError('plugin');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  bypassAndDisableTests();

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('every combination of wired dependencies (lock is on)', () {
    for (var mask = 0; mask < 16; mask++) {
      final settings = mask & 1 != 0;
      final pin = mask & 2 != 0;
      final bio = mask & 4 != 0;
      final clock = mask & 8 != 0;
      test('settings=$settings pin=$pin bio=$bio clock=$clock', () async {
        final f = LockFixture(pin: '1234');
        final c = ProviderContainer(
          overrides: [
            if (settings) settingsRepoProvider.overrideWithValue(f.settings),
            if (pin) pinStoreProvider.overrideWithValue(f.pins),
            if (bio) biometricAuthProvider.overrideWithValue(f.bio),
            if (clock) clockProvider.overrideWithValue(f.clock),
          ],
        );
        addTearDown(c.dispose);
        c.listen(lockControllerProvider, (_, _) {});
        await settle();
        final n = c.read(lockControllerProvider.notifier);
        // Locked at start, always.
        expect(c.read(appLockedProvider), isTrue);
        final all3 = settings && pin && bio;
        expect(
          c.read(lockControllerProvider).phase,
          all3 ? LockPhase.locked : LockPhase.failed,
        );
        // Retry many times: stays locked, no throw.
        for (var i = 0; i < 20; i++) {
          await n.refresh();
          expect(c.read(appLockedProvider), isTrue);
        }
        // unlock() without a successful check is only possible when the
        // lock screen (fully wired) calls it; unwired never opens.
        if (!all3) {
          n.unlock();
          expect(c.read(appLockedProvider), isTrue);
        }
        // Background/resume cycles never open anything.
        n
          ..onLifecycle(AppLifecycleState.hidden)
          ..onLifecycle(AppLifecycleState.resumed);
        expect(c.read(appLockedProvider), isTrue);
        // Now fully wire after the fact? (not possible; providers are
        // fixed) -- but a recovered setting read opens only via the lock
        // screen when the lock is on.
      });
    }

    test('lock OFF in settings but pin/bio/clock unwired: still locked '
        '(failed), because the service needs all three', () async {
      final f = LockFixture(enabled: false);
      final c = ProviderContainer(
        overrides: [settingsRepoProvider.overrideWithValue(f.settings)],
      );
      addTearDown(c.dispose);
      c.listen(lockControllerProvider, (_, _) {});
      await settle();
      // The service needs all three, so an unwired PIN store fails the read.
      expect(c.read(appLockedProvider), isTrue);
    });
  });

  group('Retry through the real app', () {
    testWidgets('nothing wired: Retry shown, taps loop safely, no content, '
        'no pending timers', (t) async {
      final h = await pumpApp(t, bypassLock: false);
      expect(find.text('Retry'), findsOneWidget);
      expect(h.location.startsWith('/lock'), isTrue);
      for (var i = 0; i < 5; i++) {
        await t.tap(find.text('Retry'));
        await t.pumpAndSettle();
        expect(find.text('Retry'), findsOneWidget);
        expect(h.location.startsWith('/lock'), isTrue);
      }
      // A resume cycle does not open it either.
      t.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(h.location.startsWith('/lock'), isTrue);
      // Widget tests fail on pending timers at teardown: reaching the end
      // proves Retry leaks none.
    });

    testWidgets('only the clock unwired: PIN screen works, no crash', (
      t,
    ) async {
      tall(t);
      final f = LockFixture(pin: '1234');
      final h = await pumpApp(
        t,
        bypassLock: false,
        overrides: [
          settingsRepoProvider.overrideWithValue(f.settings),
          pinStoreProvider.overrideWithValue(f.pins),
          biometricAuthProvider.overrideWithValue(f.bio),
        ],
      );
      expect(find.text('Storize is locked'), findsOneWidget);
      expect(h.location.startsWith('/lock'), isTrue);
    });
  });

  group('read error at each call inside methods()', () {
    for (final call in ['hasPin', 'method', 'pinLength', 'cooldown']) {
      test('$call throws: unreadable, never reset, nothing written', () async {
        final f = LockFixture(pin: '1234');
        final store = _Throwing(pin: '1234')..failing.add(call);
        final service = AppLockService(
          settings: f.settings,
          pins: store,
          biometric: f.bio,
        );
        final m = await service.methods();
        expect(m.problem, LockProblem.unreadable);
        expect(m.resetRequired, isFalse);
        expect(m.hasPin, isFalse);
        expect(store.setPinCalls, 0);
        expect(store.clearCalls, 0);
        expect(store.storedPin, '1234');
      });
    }

    test(
      'no PIN + biometric marker + hasPin ok + method throws: unreadable',
      () async {
        final f = LockFixture(biometric: true);
        final store = _Throwing(marker: LockMethod.biometric)
          ..failing.add('method');
        final m = await AppLockService(
          settings: f.settings,
          pins: store,
          biometric: f.bio,
        ).methods();
        expect(m.problem, LockProblem.unreadable);
      },
    );

    test('problem state suppresses the fingerprint prompt data: '
        'biometricAvailable false when unreadable', () async {
      final f = LockFixture(pin: '1234', biometric: true);
      final store = _Throwing(pin: '1234')..failing.add('hasPin');
      final m = await AppLockService(
        settings: f.settings,
        pins: store,
        biometric: f.bio,
      ).methods();
      expect(m.biometricAvailable, isFalse);
      expect(f.bio.prompts, 0);
    });

    test(
      'biometric plugin throwing propagates (the panel shows Retry)',
      () async {
        final f = LockFixture(pin: '1234');
        final service = AppLockService(
          settings: f.settings,
          pins: FakePinStore(pin: '1234'),
          biometric: _ThrowingBio(),
        );
        await expectLater(service.methods(), throwsStateError);
      },
    );
  });

  group('marker matrix', () {
    Future<LockProblem> problem({
      String? pin,
      LockMethod? marker,
      bool bio = true,
    }) async {
      final f = LockFixture();
      f.bio.available = bio;
      final store = FakePinStore(pin: pin, marker: marker);
      if (pin == null && marker == null) store.wipe();
      return (await AppLockService(
        settings: f.settings,
        pins: store,
        biometric: f.bio,
      ).methods()).problem;
    }

    test('PIN present: no problem for any marker or sensor state', () async {
      for (final m in [LockMethod.pin, LockMethod.biometric, null]) {
        for (final b in [true, false]) {
          expect(
            await problem(pin: '1234', marker: m, bio: b),
            LockProblem.none,
            reason: '$m $b',
          );
        }
      }
    });

    test(
      'no PIN, marker biometric: none when sensor ok, else unavailable',
      () async {
        expect(await problem(marker: LockMethod.biometric), LockProblem.none);
        expect(
          await problem(marker: LockMethod.biometric, bio: false),
          LockProblem.biometricUnavailable,
        );
      },
    );

    test('no PIN, no marker: reset regardless of the sensor', () async {
      expect(await problem(), LockProblem.resetRequired);
      expect(await problem(bio: false), LockProblem.resetRequired);
    });

    test(
      'no PIN, marker pin (deviation): reset, regardless of the sensor',
      () async {
        expect(
          await problem(marker: LockMethod.pin),
          LockProblem.resetRequired,
        );
        expect(
          await problem(marker: LockMethod.pin, bio: false),
          LockProblem.resetRequired,
        );
      },
    );
  });

  group('service write order (crash cases)', () {
    test('enableWithBiometric: flag is set after the marker', () async {
      final f = LockFixture(enabled: false);
      final store = FakePinStore();
      final s = AppLockService(
        settings: f.settings,
        pins: store,
        biometric: f.bio,
      );
      await s.enableWithBiometric();
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(await store.method(), LockMethod.biometric);
    });

    test('disable: flag off first, then clear (a crash between leaves the '
        'lock off, not a half-reset lock)', () async {
      final f = LockFixture(pin: '1234');
      final order = <String>[];
      final store = _OrderStore(order);
      final settings = _OrderSettings(f.settings, order);
      final s = AppLockService(
        settings: settings,
        pins: store,
        biometric: f.bio,
      );
      await s.disable();
      expect(order, ['settings', 'clear']);
    });

    test('enableWithPin: PIN first, flag after', () async {
      final f = LockFixture(enabled: false);
      final order = <String>[];
      final s = AppLockService(
        settings: _OrderSettings(f.settings, order),
        pins: _OrderStore(order),
        biometric: f.bio,
      );
      await s.enableWithPin('1234');
      expect(order, ['setPin', 'settings']);
    });

    test('enableWithBiometric: clear, marker, then flag', () async {
      final f = LockFixture(enabled: false);
      final order = <String>[];
      final s = AppLockService(
        settings: _OrderSettings(f.settings, order),
        pins: _OrderStore(order),
        biometric: f.bio,
      );
      await s.enableWithBiometric();
      expect(order, ['clear', 'markBiometric', 'settings']);
    });
  });
}

class _OrderStore extends FakePinStore {
  _OrderStore(this.order);
  final List<String> order;

  @override
  Future<void> setPin(String pin) async {
    order.add('setPin');
    return super.setPin(pin);
  }

  @override
  Future<void> clear() async {
    order.add('clear');
    return super.clear();
  }

  @override
  Future<void> markBiometric() async {
    order.add('markBiometric');
    return super.markBiometric();
  }
}

class _OrderSettings implements SettingsRepo {
  _OrderSettings(this._inner, this.order);

  final SettingsRepo _inner;
  final List<String> order;

  @override
  Future<AppSettings> get() => _inner.get();

  @override
  Stream<AppSettings> watch() => _inner.watch();

  @override
  Future<AppSettings> update(AppSettings Function(AppSettings) change) {
    order.add('settings');
    return _inner.update(change);
  }
}

void tall(WidgetTester t) {
  t.view
    ..physicalSize = const Size(800, 1800)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void bypassAndDisableTests() {
  group('bypass provider is test-only', () {
    test('lib/ never overrides it or sets it true', () {
      final hits = <String>[];
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final src = e.readAsStringSync();
        if (src.contains('appLockTestBypassProvider')) hits.add(e.path);
      }
      expect(hits, ['lib/features/lock/lock_controller.dart']);
      final src = File('lib/features/lock/lock_controller.dart')
          .readAsStringSync();
      expect(
        RegExp('appLockTestBypassProvider').allMatches(src).length,
        2,
        reason: 'one definition, one watch',
      );
      expect(src, contains('Provider<bool>((ref) => false)'));
    });
  });

  group('disable flow with a read error', () {
    testWidgets('unreadable store: turning off cannot be confirmed, nothing '
        'is cleared', (t) async {
      final store = _Throwing(pin: '1234')..failing.add('hasPin');
      final fx = _FxWith(store);
      await pumpRow(t, fx);
      final f = fx;
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(find.text('Create a PIN'), findsNothing);
      expect((await f.settings.get()).appLockEnabled, isTrue);
      expect(store.clearCalls, 0);
      expect(store.setPinCalls, 0);
      expect(store.storedPin, '1234');
      await t.pumpWidget(const SizedBox());
    });
  });
}

class _FxWith extends LockFixture {
  _FxWith(this._store) : super(pin: '1234');

  final FakePinStore _store;

  @override
  List<Override> overridesWith({SettingsRepo? settingsRepo}) => [
    settingsRepoProvider.overrideWithValue(settingsRepo ?? settings),
    clockProvider.overrideWithValue(clock),
    pinStoreProvider.overrideWithValue(_store),
    biometricAuthProvider.overrideWithValue(bio),
  ];
}
