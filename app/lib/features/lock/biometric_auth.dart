import 'package:local_auth/local_auth.dart';

/// What the app lock needs from the platform's biometric prompt. The real
/// implementation wraps `local_auth`; tests use a fake.
abstract interface class BiometricAuth {
  /// Whether a strong biometric (Android Class 3) is enrolled and usable.
  /// Never throws: any error means "not available".
  Future<bool> isAvailable();

  /// Shows the system prompt. True only on success. Cancel, failure and
  /// errors all give false: the caller falls back to the PIN pad.
  Future<bool> authenticate(String reason);
}

/// [BiometricAuth] over `local_auth`, strong biometrics only (no device
/// PIN or pattern: Storize has its own PIN).
final class LocalAuthBiometric implements BiometricAuth {
  /// Creates the wrapper. [auth] is injectable for tests.
  LocalAuthBiometric([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.contains(BiometricType.strong);
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Object {
      return false;
    }
  }
}
