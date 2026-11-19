import 'package:storize_app/features/lock/biometric_auth.dart';
import 'package:storize_data/storize_data.dart';
import 'package:storize_domain/storize_domain.dart';

/// Why the lock cannot be used right now, if it cannot.
enum LockProblem {
  /// Nothing is wrong.
  none,

  /// Secure storage could not be read. Stay locked and offer a retry. Never
  /// offer a new PIN: the saved PIN may be fine.
  unreadable,

  /// The lock was set up (the setting is on) but its data is gone: secure
  /// storage was wiped (T-008 N-1). The only case that offers a new PIN.
  resetRequired,

  /// A biometric-only lock whose sensor is not usable right now. Stay locked
  /// and offer a retry. Never offer a new PIN.
  biometricUnavailable,
}

/// Which ways of unlocking work right now.
final class LockMethods {
  /// Creates the value.
  const LockMethods({
    required this.hasPin,
    required this.pinLength,
    required this.biometricAvailable,
    this.cooldown,
    this.problem = LockProblem.none,
  });

  /// Secure storage could not be read.
  const LockMethods.unreadable()
    : this(
        hasPin: false,
        pinLength: null,
        biometricAvailable: false,
        problem: LockProblem.unreadable,
      );

  /// A usable PIN is stored.
  final bool hasPin;

  /// Length of the stored PIN (4 to 6), null when there is none.
  final int? pinLength;

  /// A strong biometric can be used.
  final bool biometricAvailable;

  /// Running PIN cooldown, if any.
  final Duration? cooldown;

  /// What is wrong, if anything.
  final LockProblem problem;

  /// The lock's data was wiped: the UI forces a new PIN. It must never
  /// unlock on its own.
  bool get resetRequired => problem == LockProblem.resetRequired;
}

/// App-lock operations over the PIN store, the biometric prompt and the
/// settings flag. Plain Dart: widgets reach it through a provider.
final class AppLockService {
  /// Creates the service.
  AppLockService({
    required this.settings,
    required this.pins,
    required this.biometric,
  });

  /// Settings (holds the on/off flag).
  final SettingsRepo settings;

  /// PIN hash and cooldown.
  final PinStore pins;

  /// Biometric prompt.
  final BiometricAuth biometric;

  /// Whether the user turned the app lock on.
  Future<bool> isEnabled() async => (await settings.get()).appLockEnabled;

  /// The unlock methods that work now, and what is wrong if none does.
  ///
  /// A new PIN is offered (`resetRequired`) only when nothing of the lock
  /// survives: no usable PIN and no method marker, or a PIN marker whose
  /// hash is gone. A storage read error or a biometric sensor that is
  /// unavailable for the moment never counts as a reset.
  Future<LockMethods> methods() async {
    try {
      final hasPin = await pins.hasPin();
      final marker = await pins.method();
      final biometricOk = await biometric.isAvailable();
      var problem = LockProblem.none;
      if (!hasPin) {
        if (marker == LockMethod.biometric) {
          if (!biometricOk) problem = LockProblem.biometricUnavailable;
        } else {
          // Marker missing (wipe) or marker "pin" with no hash left.
          problem = LockProblem.resetRequired;
        }
      }
      return LockMethods(
        hasPin: hasPin,
        pinLength: hasPin ? await pins.pinLength() : null,
        biometricAvailable: biometricOk,
        cooldown: hasPin ? await pins.cooldownRemaining() : null,
        problem: problem,
      );
    } on PinStorageException {
      return const LockMethods.unreadable();
    }
  }

  /// Whether a strong biometric can be used now.
  Future<bool> biometricAvailable() => biometric.isAvailable();

  /// Checks a PIN.
  Future<PinCheck> verifyPin(String pin) => pins.verify(pin);

  /// Shows the biometric prompt.
  Future<bool> authenticateBiometric(String reason) =>
      biometric.authenticate(reason);

  /// Remaining cooldown, or null.
  Future<Duration?> cooldown() => pins.cooldownRemaining();

  /// Turns the lock on with the PIN as the unlock method.
  Future<void> enableWithPin(String pin) async {
    await pins.setPin(pin);
    await _setEnabled(enabled: true);
  }

  /// Turns the lock on with biometrics only. The caller has just confirmed a
  /// fingerprint. Any old PIN is removed so the state is unambiguous.
  Future<void> enableWithBiometric() async {
    await pins.clear();
    await pins.markBiometric();
    await _setEnabled(enabled: true);
  }

  /// Stores a new PIN while the lock is already on (reset state).
  Future<void> replacePin(String pin) => pins.setPin(pin);

  /// Turns the lock off and forgets the PIN. The caller has authenticated.
  Future<void> disable() async {
    await _setEnabled(enabled: false);
    await pins.clear();
  }

  Future<void> _setEnabled({required bool enabled}) async {
    await settings.update((s) => s.copyWith(appLockEnabled: enabled));
  }
}
