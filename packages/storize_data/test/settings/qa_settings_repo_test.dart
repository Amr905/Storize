// QA (independent) tests for T-007. Complements the developer's tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:storize_data/settings/settings.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

Future<void> pump([int n = 50]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late SharedPreferencesAsync prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  SharedPrefsSettingsRepo newRepo() => SharedPrefsSettingsRepo(prefs: prefs);

  group('QA boundaries', () {
    for (final entry in {
      14: false,
      15: true,
      45: false,
      360: true,
      361: false,
    }.entries) {
      test('story interval ${entry.key} valid=${entry.value}', () async {
        final repo = newRepo();
        final future = repo.update(
          (c) => c.copyWith(storyIntervalMin: entry.key),
        );
        if (entry.value) {
          expect((await future).storyIntervalMin, entry.key);
        } else {
          await expectLater(
            future,
            throwsA(isA<SettingsValidationException>()),
          );
          expect(await prefs.getKeys(), isEmpty);
        }
      });
    }
    for (final entry in {
      59: false,
      60: true,
      1440: true,
      1441: false,
    }.entries) {
      test('post interval ${entry.key} valid=${entry.value}', () async {
        final repo = newRepo();
        final future = repo.update(
          (c) => c.copyWith(postIntervalMin: entry.key),
        );
        if (entry.value) {
          expect((await future).postIntervalMin, entry.key);
        } else {
          await expectLater(
            future,
            throwsA(isA<SettingsValidationException>()),
          );
          expect(await prefs.getKeys(), isEmpty);
        }
      });
    }
    for (final entry in {0: false, -1: false, 1: true}.entries) {
      test('retention ${entry.key} valid=${entry.value}', () async {
        final repo = newRepo();
        final future = repo.update((c) => c.copyWith(retentionDays: entry.key));
        if (entry.value) {
          expect((await future).retentionDays, entry.key);
        } else {
          await expectLater(
            future,
            throwsA(isA<SettingsValidationException>()),
          );
          expect(await prefs.getKeys(), isEmpty);
        }
      });
    }
    test('retention null is valid and stores nothing', () async {
      final s = await newRepo().update((c) => c.copyWith(retentionDays: null));
      expect(s.retentionDays, isNull);
      expect(await prefs.getKeys(), isEmpty);
    });
    test('valid change to A + invalid change to B writes nothing', () async {
      final repo = newRepo();
      await expectLater(
        repo.update((c) => c.copyWith(wifiOnly: true, storyIntervalMin: 14)),
        throwsA(isA<SettingsValidationException>()),
      );
      expect(await prefs.getKeys(), isEmpty);
      expect((await repo.get()).wifiOnly, isFalse);
    });
    test(
      'throwing change callback writes nothing and queue survives',
      () async {
        final repo = newRepo();
        await expectLater(
          repo.update((c) => throw StateError('boom')),
          throwsA(isA<StateError>()),
        );
        expect(await prefs.getKeys(), isEmpty);
        expect(
          (await repo.update((c) => c.copyWith(wifiOnly: true))).wifiOnly,
          isTrue,
        );
      },
    );
  });

  group('QA corruption', () {
    Future<void> expectDefaults() async {
      final s = await newRepo().get();
      expect(s, const AppSettings());
    }

    for (final key in SettingsKeys.byField.values) {
      test('string stored under $key falls back', () async {
        await prefs.setString(key, 'garbage');
        await expectDefaults();
      });
      test('double stored under $key falls back', () async {
        await prefs.setDouble(key, 1.5);
        await expectDefaults();
      });
      test('string list stored under $key falls back', () async {
        await prefs.setStringList(key, ['a']);
        await expectDefaults();
      });
    }
    for (final key in [
      SettingsKeys.wifiOnly,
      SettingsKeys.notifyStories,
      SettingsKeys.notifyPosts,
      SettingsKeys.notifyLogin,
      SettingsKeys.appLockEnabled,
      SettingsKeys.onboardingDone,
      SettingsKeys.pageModeInBackground,
    ]) {
      test('int stored under bool key $key falls back', () async {
        await prefs.setInt(key, 1);
        await expectDefaults();
      });
    }
    test('invalid intervals / retention fall back per field', () async {
      await prefs.setInt(SettingsKeys.storyIntervalMin, 10);
      await prefs.setInt(SettingsKeys.postIntervalMin, 30);
      await prefs.setInt(SettingsKeys.retentionDays, -5);
      await prefs.setBool(SettingsKeys.wifiOnly, true); // valid neighbour kept
      final s = await newRepo().get();
      expect(s.storyIntervalMin, 30);
      expect(s.postIntervalMin, 180);
      expect(s.retentionDays, isNull);
      expect(s.wifiOnly, isTrue);
    });
    test('negative and huge timestamps never throw', () async {
      await prefs.setInt(SettingsKeys.riskAcknowledgedAt, -1);
      await prefs.setInt(SettingsKeys.lastUpdateCheckAt, 9223372036854775807);
      final s = await newRepo().get();
      expect(s.lastUpdateCheckAt, isNull);
      // -1 is a legal instant (1969); must not throw. Report value only.
      expect(s.riskAcknowledgedAt, anyOf(isNull, isA<DateTime>()));
      await prefs.setInt(SettingsKeys.riskAcknowledgedAt, -9223372036854775808);
      expect((await newRepo().get()).riskAcknowledgedAt, isNull);
    });
    test(
      'corrupt value does not break unrelated update; stream works',
      () async {
        await prefs.setString(SettingsKeys.storyIntervalMin, 'x');
        final repo = newRepo();
        final seen = <AppSettings>[];
        final sub = repo.watch().listen(seen.add);
        await pump();
        expect(seen.single, const AppSettings());
        await repo.update((c) => c.copyWith(wifiOnly: true));
        await pump();
        expect(seen.last.wifiOnly, isTrue);
        await sub.cancel();
      },
    );
  });

  group('QA watch', () {
    test('initial + update emissions, rejected emits nothing', () async {
      final repo = newRepo();
      final seen = <AppSettings>[];
      final sub = repo.watch().listen(seen.add);
      await pump();
      expect(seen, [const AppSettings()]);
      await repo.update((c) => c.copyWith(wifiOnly: true));
      await pump();
      expect(seen, hasLength(2));
      await expectLater(
        repo.update((c) => c.copyWith(postIntervalMin: 59)),
        throwsA(isA<SettingsValidationException>()),
      );
      await pump();
      expect(seen, hasLength(2));
      await sub.cancel();
    });
    test('two watchers both get initial and updates', () async {
      final repo = newRepo();
      final a = <AppSettings>[];
      final b = <AppSettings>[];
      final s1 = repo.watch().listen(a.add);
      final s2 = repo.watch().listen(b.add);
      await repo.update((c) => c.copyWith(notifyPosts: false));
      await pump();
      expect(a.last.notifyPosts, isFalse);
      expect(b.last.notifyPosts, isFalse);
      expect(a.first, const AppSettings());
      expect(b.first, const AppSettings());
      await s1.cancel();
      await s2.cancel();
    });
    test(
      'subscribe racing an update: last event is always the final value',
      () async {
        for (var i = 0; i < 20; i++) {
          SharedPreferencesAsyncPlatform.instance =
              InMemorySharedPreferencesAsync.empty();
          final repo = SharedPrefsSettingsRepo(prefs: SharedPreferencesAsync());
          final seen = <AppSettings>[];
          final sub = repo.watch().listen(seen.add);
          final f = repo.update((c) => c.copyWith(wifiOnly: true));
          await f;
          await pump();
          expect(seen.last.wifiOnly, isTrue, reason: 'iteration $i');
          // no value is skipped backwards: once true, never false again
          final firstTrue = seen.indexWhere((s) => s.wifiOnly);
          expect(seen.skip(firstTrue).every((s) => s.wifiOnly), isTrue);
          await sub.cancel();
        }
      },
    );
    test('update before listen is reflected in initial emission', () async {
      final repo = newRepo();
      final stream = repo.watch(); // not listened yet
      await repo.update((c) => c.copyWith(wifiOnly: true));
      final first = await stream.first;
      expect(first.wifiOnly, isTrue);
    });
    test('cancel then update does not throw or leak', () async {
      final repo = newRepo();
      final sub = repo.watch().listen((_) {});
      await pump();
      await sub.cancel();
      await repo.update((c) => c.copyWith(wifiOnly: true));
    });
    test(
      'cancel immediately after listen (before initial read) is safe',
      () async {
        final repo = newRepo();
        final seen = <AppSettings>[];
        final sub = repo.watch().listen(seen.add);
        await sub.cancel();
        await repo.update((c) => c.copyWith(wifiOnly: true));
        await pump();
        expect(seen, isEmpty);
      },
    );
  });

  group('QA concurrency + persistence', () {
    test('50 parallel updates lose nothing', () async {
      final repo = newRepo();
      // Counter encoded in retentionDays increments; each update reads current.
      await Future.wait([
        for (var i = 0; i < 50; i++)
          repo.update(
            (c) => c.copyWith(retentionDays: (c.retentionDays ?? 0) + 1),
          ),
      ]);
      expect((await repo.get()).retentionDays, 50);
    });
    test('50 parallel updates of different fields all land', () async {
      final repo = newRepo();
      final at = DateTime.utc(2026);
      await Future.wait([
        for (var i = 0; i < 25; i++) ...[
          repo.update((c) => c.copyWith(wifiOnly: true)),
          repo.update((c) => c.copyWith(lastUpdateCheckAt: at)),
        ],
        repo.update((c) => c.copyWith(storyIntervalMin: 60)),
      ]);
      final s = await repo.get();
      expect(s.wifiOnly, isTrue);
      expect(s.lastUpdateCheckAt, at);
      expect(s.storyIntervalMin, 60);
    });
    test('a new instance reads back what the old one wrote', () async {
      final at = DateTime.utc(2026, 5, 6, 7, 8, 9, 10);
      final wrote = await newRepo().update(
        (c) => c.copyWith(
          storyIntervalMin: 15,
          postIntervalMin: 60,
          wifiOnly: true,
          notifyStories: false,
          notifyPosts: false,
          notifyLogin: false,
          retentionDays: 7,
          appLockEnabled: true,
          onboardingDone: true,
          riskAcknowledgedAt: at,
          pageModeInBackground: true,
          lastUpdateCheckAt: at,
        ),
      );
      final read = await SharedPrefsSettingsRepo(
        prefs: SharedPreferencesAsync(),
      ).get();
      expect(read, wrote);
      expect(read.riskAcknowledgedAt!.isUtc, isTrue);
    });
    test('non-UTC instants round-trip as the same instant', () async {
      final local = DateTime(2026, 3, 4, 5, 6, 7);
      final s = await newRepo().update(
        (c) => c.copyWith(riskAcknowledgedAt: local),
      );
      final read = await newRepo().get();
      expect(read.riskAcknowledgedAt!.isAtSameMomentAs(local), isTrue);
      expect(s.riskAcknowledgedAt, local);
    });
  });

  group('QA parity with FakeSettingsRepo', () {
    // Each scenario returns a transcript of observable outcomes.
    final scenarios = <String, Future<List<Object?>> Function(SettingsRepo)>{
      'defaults': (r) async => [await r.get()],
      'valid update returns and persists': (r) async {
        final u = await r.update(
          (c) => c.copyWith(storyIntervalMin: 60, retentionDays: 3),
        );
        return [u, await r.get()];
      },
      'invalid rejected, state unchanged': (r) async {
        Object? err;
        try {
          await r.update(
            (c) => c.copyWith(wifiOnly: true, postIntervalMin: 61),
          );
        } on SettingsValidationException catch (e) {
          err = e.problems;
        }
        return [err, await r.get()];
      },
      'multiple problems': (r) async {
        Object? err;
        try {
          await r.update(
            (c) => c.copyWith(
              storyIntervalMin: 1,
              postIntervalMin: 2,
              retentionDays: 0,
            ),
          );
        } on SettingsValidationException catch (e) {
          err = e.problems;
        }
        return [err];
      },
      'clear nullable fields': (r) async {
        await r.update((c) => c.copyWith(retentionDays: 5));
        final u = await r.update((c) => c.copyWith(retentionDays: null));
        return [u, await r.get()];
      },
      'sequential updates build on each other': (r) async {
        await r.update((c) => c.copyWith(wifiOnly: true));
        await r.update((c) => c.copyWith(notifyLogin: false));
        return [await r.get()];
      },
      'watch transcript': (r) async {
        final seen = <AppSettings>[];
        final sub = r.watch().listen(seen.add);
        await pump();
        await r.update((c) => c.copyWith(wifiOnly: true));
        await pump();
        try {
          await r.update((c) => c.copyWith(storyIntervalMin: 5));
        } on SettingsValidationException {
          // expected
        }
        await pump();
        await r.update((c) => c.copyWith(retentionDays: 9));
        await pump();
        await sub.cancel();
        return seen;
      },
    };

    for (final entry in scenarios.entries) {
      test(entry.key, () async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        final real = await entry.value(newRepo());
        final fake = await entry.value(FakeSettingsRepo());
        expect(real, fake);
      });
    }

    test('exception types match for a validation failure', () async {
      final fake = FakeSettingsRepo();
      final real = newRepo();
      Future<Object?> run(SettingsRepo r) => r
          .update((c) => c.copyWith(storyIntervalMin: 10))
          .then<Object?>((_) => null, onError: (Object e) => e);
      final a = await run(real);
      final b = await run(fake);
      expect(a.runtimeType, b.runtimeType);
    });
  });
}
