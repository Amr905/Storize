import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:storize_data/settings/settings.dart';

void main() {
  late SharedPreferencesAsync prefs;
  late InPageBackgroundSetting setting;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    setting = InPageBackgroundSetting(prefs: prefs);
  });

  test('the key is storize.inPageInBackground', () {
    expect(SettingsKeys.inPageInBackground, 'storize.inPageInBackground');
  });

  test('never set means on', () async {
    expect(await setting.get(), isTrue);
  });

  test('an explicit false is the kill switch', () async {
    await prefs.setBool(SettingsKeys.inPageInBackground, false);
    expect(await setting.get(), isFalse);
    await setting.set(enabled: true);
    expect(await setting.get(), isTrue);
  });

  test('a value of another type counts as on', () async {
    await prefs.setString(SettingsKeys.inPageInBackground, 'no');
    expect(await setting.get(), isTrue);
  });
}
