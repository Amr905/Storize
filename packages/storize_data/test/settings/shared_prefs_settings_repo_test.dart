import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:storize_data/settings/settings.dart';
import 'package:storize_domain/storize_domain.dart';

/// Waits (bounded) until [items] holds [count] entries, then checks it.
Future<void> settle(List<Object?> items, int count) async {
  for (var i = 0; i < 1000 && items.length < count; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(items, hasLength(count));
}

void main() {
  late SharedPreferencesAsync prefs;
  late SharedPrefsSettingsRepo repo;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    repo = SharedPrefsSettingsRepo(prefs: prefs);
  });

  group('keys', () {
    test('are the stable storize.* keys, one per AppSettings field', () {
      expect(SettingsKeys.byField, {
        'storyIntervalMin': 'storize.storyIntervalMin',
        'postIntervalMin': 'storize.postIntervalMin',
        'wifiOnly': 'storize.wifiOnly',
        'notifyStories': 'storize.notifyStories',
        'notifyPosts': 'storize.notifyPosts',
        'notifyLogin': 'storize.notifyLogin',
        'retentionDays': 'storize.retentionDays',
        'appLockEnabled': 'storize.appLockEnabled',
        'onboardingDone': 'storize.onboardingDone',
        'riskAcknowledgedAt': 'storize.riskAcknowledgedAt',
        'pageModeInBackground': 'storize.pageModeInBackground',
        'lastUpdateCheckAt': 'storize.lastUpdateCheckAt',
        'themeMode': 'storize.themeMode',
      });
    });
  });

  group('themeMode', () {
    test('defaults to system, persists, ignores unknown values', () async {
      expect((await repo.get()).themeMode, AppThemeMode.system);
      await repo.update((s) => s.copyWith(themeMode: AppThemeMode.dark));
      expect(await prefs.getString('storize.themeMode'), 'dark');
      expect((await repo.get()).themeMode, AppThemeMode.dark);
      await prefs.setString('storize.themeMode', 'sepia');
      expect((await repo.get()).themeMode, AppThemeMode.system);
    });
  });

  group('defaults', () {
    test('match TECH_SPEC §3 when nothing is stored', () async {
      final settings = await repo.get();

      expect(settings.storyIntervalMin, 30);
      expect(settings.postIntervalMin, 180);
      expect(settings.wifiOnly, isFalse);
      expect(settings.notifyStories, isTrue);
      expect(settings.notifyPosts, isTrue);
      expect(settings.notifyLogin, isTrue);
      expect(settings.retentionDays, isNull);
      expect(settings.appLockEnabled, isFalse);
      expect(settings.onboardingDone, isFalse);
      expect(settings.riskAcknowledgedAt, isNull);
      expect(settings.pageModeInBackground, isFalse);
      expect(settings.lastUpdateCheckAt, isNull);
      expect(settings, const AppSettings());
    });

    test('nothing is written just by reading', () async {
      await repo.get();
      expect(await prefs.getKeys(), isEmpty);
    });
  });

  group('round-trip', () {
    test(
      'every field survives update and a fresh repo reads it back',
      () async {
        final riskAt = DateTime.utc(2026, 11, 19, 10, 30, 15, 250);
        final checkedAt = DateTime.utc(2026, 11, 20, 8);
        final saved = await repo.update(
          (current) => current.copyWith(
            storyIntervalMin: 360,
            postIntervalMin: 1440,
            wifiOnly: true,
            notifyStories: false,
            notifyPosts: false,
            notifyLogin: false,
            retentionDays: 30,
            appLockEnabled: true,
            onboardingDone: true,
            riskAcknowledgedAt: riskAt,
            pageModeInBackground: true,
            lastUpdateCheckAt: checkedAt,
          ),
        );

        final fresh = SharedPrefsSettingsRepo(prefs: SharedPreferencesAsync());
        final read = await fresh.get();

        expect(read, saved);
        expect(read.storyIntervalMin, 360);
        expect(read.postIntervalMin, 1440);
        expect(read.wifiOnly, isTrue);
        expect(read.notifyStories, isFalse);
        expect(read.notifyPosts, isFalse);
        expect(read.notifyLogin, isFalse);
        expect(read.retentionDays, 30);
        expect(read.appLockEnabled, isTrue);
        expect(read.onboardingDone, isTrue);
        expect(read.riskAcknowledgedAt, riskAt);
        expect(read.pageModeInBackground, isTrue);
        expect(read.lastUpdateCheckAt, checkedAt);
      },
    );

    test('instants are stored as epoch milliseconds under their key', () async {
      final at = DateTime.utc(2026, 11, 19, 10, 30);
      await repo.update((c) => c.copyWith(lastUpdateCheckAt: at));

      expect(
        await prefs.getInt(SettingsKeys.lastUpdateCheckAt),
        at.millisecondsSinceEpoch,
      );
    });

    test('clearing a nullable field removes its key', () async {
      await repo.update((c) => c.copyWith(retentionDays: 7));
      expect((await repo.get()).retentionDays, 7);

      await repo.update((c) => c.copyWith(retentionDays: null));

      expect((await repo.get()).retentionDays, isNull);
      expect(await prefs.containsKey(SettingsKeys.retentionDays), isFalse);
    });
  });

  group('validation', () {
    test('story interval 10 is rejected and nothing is written', () async {
      await expectLater(
        repo.update((c) => c.copyWith(storyIntervalMin: 10)),
        throwsA(isA<SettingsValidationException>()),
      );
      expect(await prefs.getKeys(), isEmpty);
    });

    test('post interval 30 is rejected and nothing is written', () async {
      await expectLater(
        repo.update((c) => c.copyWith(postIntervalMin: 30)),
        throwsA(isA<SettingsValidationException>()),
      );
      expect(await prefs.getKeys(), isEmpty);
    });

    test('retention 0 is rejected and nothing is written', () async {
      await expectLater(
        repo.update((c) => c.copyWith(retentionDays: 0)),
        throwsA(isA<SettingsValidationException>()),
      );
      expect(await prefs.getKeys(), isEmpty);
    });

    test('the exception carries one problem per broken rule', () async {
      final error = await repo
          .update(
            (c) => c.copyWith(storyIntervalMin: 10, retentionDays: -1),
          )
          .then<Object?>((_) => null)
          .catchError((Object e) => e);

      expect(error, isA<SettingsValidationException>());
      expect((error! as SettingsValidationException).problems, hasLength(2));
    });

    test(
      'a rejected update leaves previously stored values unchanged',
      () async {
        await repo.update((c) => c.copyWith(wifiOnly: true));

        await expectLater(
          repo.update(
            (c) => c.copyWith(wifiOnly: false, storyIntervalMin: 10),
          ),
          throwsA(isA<SettingsValidationException>()),
        );

        expect((await repo.get()).wifiOnly, isTrue);
      },
    );

    test('an update only writes the keys that changed', () async {
      await repo.update((c) => c.copyWith(wifiOnly: true));

      expect(await prefs.getKeys(), {SettingsKeys.wifiOnly});
    });
  });

  group('corrupted stored values', () {
    test(
      'negative and out-of-range timestamps read as null, never throw',
      () async {
        final raw = SharedPreferencesAsync();
        for (final bad in <int>[
          -1,
          -8640000000000000,
          8640000000000001,
          9223372036854775807,
          -9223372036854775808,
        ]) {
          await raw.setInt(SettingsKeys.riskAcknowledgedAt, bad);
          await raw.setInt(SettingsKeys.lastUpdateCheckAt, bad);

          final settings = await repo.get();

          expect(settings.riskAcknowledgedAt, isNull, reason: '$bad');
          expect(settings.lastUpdateCheckAt, isNull, reason: '$bad');
        }
      },
    );

    test('the epoch boundaries 0 and max are valid instants', () async {
      final raw = SharedPreferencesAsync();
      await raw.setInt(SettingsKeys.riskAcknowledgedAt, 0);
      await raw.setInt(SettingsKeys.lastUpdateCheckAt, 8640000000000000);

      final settings = await repo.get();

      expect(settings.riskAcknowledgedAt, DateTime.utc(1970));
      expect(
        settings.lastUpdateCheckAt,
        DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true),
      );
    });

    test('fall back to the default for each field and never throw', () async {
      final raw = SharedPreferencesAsync();
      await raw.setString(SettingsKeys.storyIntervalMin, 'thirty');
      await raw.setInt(SettingsKeys.postIntervalMin, 30);
      await raw.setInt(SettingsKeys.retentionDays, 0);
      await raw.setString(SettingsKeys.wifiOnly, 'true');
      await raw.setInt(SettingsKeys.notifyPosts, 1);
      await raw.setString(SettingsKeys.riskAcknowledgedAt, 'yesterday');
      await raw.setInt(SettingsKeys.lastUpdateCheckAt, 8640000000000001);

      expect(await repo.get(), const AppSettings());
    });

    test('a valid update replaces the corrupted value', () async {
      final raw = SharedPreferencesAsync();
      await raw.setString(SettingsKeys.storyIntervalMin, 'thirty');

      final updated = await repo.update(
        (c) => c.copyWith(storyIntervalMin: 60),
      );

      expect(updated.storyIntervalMin, 60);
      expect(await prefs.getInt(SettingsKeys.storyIntervalMin), 60);
    });
  });

  group('watch', () {
    test(
      'emits the current value first, then every successful update',
      () async {
        final seen = <AppSettings>[];
        final sub = repo.watch().listen(seen.add);

        await settle(seen, 1);
        expect(seen.single, const AppSettings());

        await repo.update((c) => c.copyWith(wifiOnly: true));
        await settle(seen, 2);
        expect(seen.last.wifiOnly, isTrue);

        await sub.cancel();
      },
    );

    test('does not emit for a rejected update', () async {
      final seen = <AppSettings>[];
      final sub = repo.watch().listen(seen.add);
      await settle(seen, 1);

      await expectLater(
        repo.update((c) => c.copyWith(postIntervalMin: 30)),
        throwsA(isA<SettingsValidationException>()),
      );
      await repo.update((c) => c.copyWith(notifyLogin: false));
      await settle(seen, 2);

      expect(seen.map((s) => s.notifyLogin), [true, false]);
      await sub.cancel();
    });

    test('each call returns a new stream', () {
      expect(identical(repo.watch(), repo.watch()), isFalse);
    });

    test('two concurrent watchers both receive updates', () async {
      final first = <AppSettings>[];
      final second = <AppSettings>[];
      final subA = repo.watch().listen(first.add);
      final subB = repo.watch().listen(second.add);
      await settle(first, 1);
      await settle(second, 1);

      await repo.update((c) => c.copyWith(appLockEnabled: true));
      await settle(first, 2);
      await settle(second, 2);
      expect(first.last.appLockEnabled, isTrue);
      expect(second.last.appLockEnabled, isTrue);

      await subA.cancel();
      await repo.update((c) => c.copyWith(appLockEnabled: false));
      await settle(second, 3);
      expect(second.last.appLockEnabled, isFalse);
      expect(first, hasLength(2));

      await subB.cancel();
    });
  });

  group('concurrent updates', () {
    test('both are applied and neither is lost', () async {
      await Future.wait([
        repo.update((c) => c.copyWith(wifiOnly: true)),
        repo.update((c) => c.copyWith(notifyPosts: false)),
      ]);

      final settings = await repo.get();
      expect(settings.wifiOnly, isTrue);
      expect(settings.notifyPosts, isFalse);
    });
  });
}
