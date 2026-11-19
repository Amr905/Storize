import 'package:storize_app/features/lock/biometric_auth.dart';
import 'package:storize_data/security/pin_vault.dart';
import 'package:storize_domain/storize_domain.dart';

/// Which ways of unlocking work right now.
final class LockMethods {
  /// Creates the value.
  const LockMethods({
    required this.hasPin,
    required this.pinLength,
    required this.biometricAvailable,
    this.cooldown,
  });

  /// A usable PIN is stored.
  final bool hasPin;

  /// Length of the stored PIN (4 to 6), null when there is none.
  final int? pinLength;

  /// A strong biometric can be used.
  final bool biometricAvailable;

  /// Running PIN cooldown, if any.
  final Duration? cooldown;

  /// The lock is on but nothing can unlock it: the saved PIN is gone (for
  /// example a secure-storage reset, T-008 N-1) and no biometric works. The
  /// UI must force a new PIN. It must never unlock on its own.
  bool get resetRequired => !hasPin && !biometricAvailable;
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

  /// The unlock methods that work now.
  Future<LockMethods> methods() async {
    final hasPin = await pins.hasPin();
    return LockMethods(
      hasPin: hasPin,
      pinLength: hasPin ? await pins.pinLength() : null,
      biometricAvailable: await biometric.isAvailable(),
      cooldown: hasPin ? await pins.cooldownRemaining() : null,
    );
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
