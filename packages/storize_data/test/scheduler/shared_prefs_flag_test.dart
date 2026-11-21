import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:storize_data/scheduler/scheduler.dart';

void main() {
  late SharedPreferencesAsync prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  test('is false until set, then true, then false after clear', () async {
    final flag = SharedPrefsFlag('k', prefs: prefs);
    expect(await flag.get(), isFalse);
    await flag.set();
    expect(await flag.get(), isTrue);
    await flag.clear();
    expect(await flag.get(), isFalse);
  });

  test('a second instance (another isolate) sees the value', () async {
    await SharedPrefsFlag('k', prefs: prefs).set();
    expect(
      await SharedPrefsFlag('k', prefs: SharedPreferencesAsync()).get(),
      isTrue,
    );
  });

  test('a value of another type counts as set (fail safe)', () async {
    await prefs.setString('k', 'oops');
    expect(await SharedPrefsFlag('k', prefs: prefs).get(), isTrue);
  });

  test('keys are independent', () async {
    await SharedPrefsFlag('a', prefs: prefs).set();
    expect(await SharedPrefsFlag('b', prefs: prefs).get(), isFalse);
  });
}
