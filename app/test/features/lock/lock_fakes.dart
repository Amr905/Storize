import 'package:flutter_riverpod/misc.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/lock/biometric_auth.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_data/security/pin_vault.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

/// In-memory [PinStore] with the real rules of [PinVault] reduced to what the
/// UI needs: 5 wrong PINs start a 30 s cooldown that only [advance] ends.
class FakePinStore implements PinStore {
  FakePinStore({String? pin}) : _pin = pin; // ignore: prefer_initializing_formals, the field is private and mutable.

  String? _pin;
  int failures = 0;
  Duration? cooldown;
  int verifyCalls = 0;
  bool cleared = false;

  /// Pretends time passed.
  void advance(Duration d) {
    final c = cooldown;
    if (c == null) return;
    final left = c - d;
    cooldown = left > Duration.zero ? left : null;
  }

  @override
  Future<bool> hasPin() async => _pin != null;

  @override
  Future<int?> pinLength() async => _pin?.length;

  @override
  Future<void> setPin(String pin) async {
    _pin = pin;
    failures = 0;
    cooldown = null;
  }

  @override
  Future<PinCheck> verify(String pin) async {
    verifyCalls++;
    if (_pin == null) return const PinNotSet();
    if (cooldown != null) return PinCoolingDown(cooldown!);
    if (pin == _pin) {
      failures = 0;
      return const PinAccepted();
    }
    failures++;
    if (failures >= PinVault.maxFailures) {
      failures = 0;
      cooldown = PinVault.cooldownDuration;
      return PinRejected(attemptsLeft: 0, cooldown: cooldown);
    }
    return PinRejected(attemptsLeft: PinVault.maxFailures - failures);
  }

  @override
  Future<Duration?> cooldownRemaining() async => cooldown;

  @override
  Future<void> clear() async {
    _pin = null;
    cleared = true;
  }

  /// Simulates a secure-storage reset.
  void wipe() => _pin = null;

  String? get storedPin => _pin;
}

class FakeBiometric implements BiometricAuth {
  FakeBiometric({this.available = true, this.succeeds = true});

  bool available;
  bool succeeds;
  int prompts = 0;
  String? lastReason;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    lastReason = reason;
    return succeeds;
  }
}

/// Everything a lock test needs.
class LockFixture {
  LockFixture({
    bool enabled = true,
    String? pin,
    bool biometric = false,
    DateTime? start,
  }) : settings = FakeSettingsRepo(AppSettings(appLockEnabled: enabled)),
       pins = FakePinStore(pin: pin),
       bio = FakeBiometric(available: biometric),
       clock = FakeClock(start);

  final FakeSettingsRepo settings;
  final FakePinStore pins;
  final FakeBiometric bio;
  final FakeClock clock;

  List<Override> overridesWith({SettingsRepo? settingsRepo}) => [
    appLockWiredProvider.overrideWithValue(true),
    settingsRepoProvider.overrideWithValue(settingsRepo ?? settings),
    clockProvider.overrideWithValue(clock),
    pinStoreProvider.overrideWithValue(pins),
    biometricAuthProvider.overrideWithValue(bio),
  ];

  List<Override> get overrides => overridesWith();
}

/// Fails the first read, then delegates.
class FailingOnceSettings implements SettingsRepo {
  FailingOnceSettings(this._inner);

  final SettingsRepo _inner;
  bool _failed = false;

  @override
  Future<AppSettings> get() async {
    if (!_failed) {
      _failed = true;
      throw StateError('prefs');
    }
    return _inner.get();
  }

  @override
  Stream<AppSettings> watch() => _inner.watch();

  @override
  Future<AppSettings> update(AppSettings Function(AppSettings) change) =>
      _inner.update(change);
}
