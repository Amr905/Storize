import 'package:shared_preferences/shared_preferences.dart';

/// One boolean in shared preferences that several isolates read and write.
///
/// It uses `SharedPreferencesAsync`, which reads the platform store on every
/// call, so a value written by the UI isolate is seen by a background isolate
/// and the other way round. The app adapts it to the Instagram package's
/// seen-breaker store (this package does not depend on `storize_instagram`).
final class SharedPrefsFlag {
  /// Creates a flag stored under [key]. [prefs] is injectable for tests.
  SharedPrefsFlag(this.key, {SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  /// The preference key.
  final String key;

  final SharedPreferencesAsync _prefs;

  /// The stored value, `false` when unset or of another type.
  Future<bool> get() async {
    try {
      return await _prefs.getBool(key) ?? false;
    } on Object {
      // A value of another type under this key: treat it as set, so a
      // circuit breaker stays closed (fail safe).
      return true;
    }
  }

  /// Sets the flag.
  Future<void> set() => _prefs.setBool(key, true);

  /// Clears the flag.
  Future<void> clear() => _prefs.remove(key);
}
