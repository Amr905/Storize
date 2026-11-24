import 'package:shared_preferences/shared_preferences.dart';
import 'package:storize_data/settings/shared_prefs_settings_repo.dart';

/// Whether in-page fetching may run in background tasks (T-050).
///
/// Default **true**: a key that was never set means on. Only an explicit
/// `false` under [SettingsKeys.inPageInBackground] is the kill switch. A
/// value of another type, or a store that throws, counts as on (the setting
/// only limits a feature; it protects nothing).
final class InPageBackgroundSetting {
  /// Creates the reader. [prefs] is injectable for tests.
  InPageBackgroundSetting({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// Whether in-page fetching is allowed in the background.
  Future<bool> get() async {
    try {
      return await _prefs.getBool(SettingsKeys.inPageInBackground) ?? true;
    } on Object {
      return true;
    }
  }

  /// Turns the kill switch on (`false`) or off (`true`).
  Future<void> set({required bool enabled}) =>
      _prefs.setBool(SettingsKeys.inPageInBackground, enabled);
}
