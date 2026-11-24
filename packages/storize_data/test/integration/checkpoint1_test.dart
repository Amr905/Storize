// Checkpoint 1 cross-task integration checks (QA).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:storize_data/storize_data.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

void main() {
  group('(a) SharedPrefsSettingsRepo vs FakeSettingsRepo defaults', () {
    late AppSettings real;
    late AppSettings fake;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      real = await SharedPrefsSettingsRepo(prefs: SharedPreferencesAsync())
          .get();
      fake = await FakeSettingsRepo().get();
    });

    test('whole objects are equal', () {
      expect(real, fake);
      expect(real, const AppSettings());
    });

    test('every field agrees', () {
      expect(real.storyIntervalMin, fake.storyIntervalMin);
      expect(real.postIntervalMin, fake.postIntervalMin);
      expect(real.wifiOnly, fake.wifiOnly);
      expect(real.notifyStories, fake.notifyStories);
      expect(real.notifyPosts, fake.notifyPosts);
      expect(real.notifyLogin, fake.notifyLogin);
      expect(real.retentionDays, fake.retentionDays);
      expect(real.appLockEnabled, fake.appLockEnabled);
      expect(real.onboardingDone, fake.onboardingDone);
      expect(real.riskAcknowledgedAt, fake.riskAcknowledgedAt);
      expect(real.pageModeInBackground, fake.pageModeInBackground);
      expect(real.lastUpdateCheckAt, fake.lastUpdateCheckAt);
    });

    test('spec default values', () {
      expect(real.storyIntervalMin, 30);
      expect(real.postIntervalMin, 180);
      expect(real.wifiOnly, isFalse);
      expect(real.notifyStories, isTrue);
      expect(real.notifyPosts, isTrue);
      expect(real.notifyLogin, isTrue);
      expect(real.retentionDays, isNull);
      expect(real.appLockEnabled, isFalse);
      expect(real.onboardingDone, isFalse);
      expect(real.pageModeInBackground, isFalse);
    });

    test(
      'both reject the same invalid update with the same messages',
      () async {
        final realRepo = SharedPrefsSettingsRepo(
          prefs: SharedPreferencesAsync(),
        );
        final fakeRepo = FakeSettingsRepo();
        Object? realErr;
        Object? fakeErr;
        try {
          await realRepo.update((s) => s.copyWith(storyIntervalMin: 10));
        } on SettingsValidationException catch (e) {
          realErr = e;
        }
        try {
          await fakeRepo.update((s) => s.copyWith(storyIntervalMin: 10));
        } on SettingsValidationException catch (e) {
          fakeErr = e;
        }
        expect(realErr, isA<SettingsValidationException>());
        expect(fakeErr, isA<SettingsValidationException>());
        expect(
          (realErr! as SettingsValidationException).problems,
          (fakeErr! as SettingsValidationException).problems,
        );
        expect(await realRepo.get(), await fakeRepo.get());
      },
    );
  });

  group('(b) model enums used by domain entities', () {
    // ExtractionPolicy is Dart-only (never stored) and has no dbValue.
    void roundTrip<T extends Enum>(
      List<T> values,
      String Function(T) db,
      T Function(String) from,
    ) {
      final seen = <String>{};
      for (final v in values) {
        final raw = db(v);
        expect(raw, isNotEmpty, reason: '$v');
        expect(raw, matches(RegExp(r'^[A-Z][A-Z0-9_]*$')), reason: '$v');
        expect(seen.add(raw), isTrue, reason: 'duplicate dbValue $raw');
        expect(from(raw), v);
      }
      expect(() => from('nope'), throwsArgumentError);
      expect(() => from(''), throwsArgumentError);
    }

    test('PlatformId', () {
      roundTrip(PlatformId.values, (e) => e.dbValue, PlatformId.fromDb);
    });
    test('ContentKind', () {
      roundTrip(ContentKind.values, (e) => e.dbValue, ContentKind.fromDb);
    });
    test('PostType', () {
      roundTrip(PostType.values, (e) => e.dbValue, PostType.fromDb);
    });
    test('MediaType', () {
      roundTrip(MediaType.values, (e) => e.dbValue, MediaType.fromDb);
    });
    test('TargetCategory', () {
      roundTrip(TargetCategory.values, (e) => e.dbValue, TargetCategory.fromDb);
    });
    test('TargetStatus', () {
      roundTrip(TargetStatus.values, (e) => e.dbValue, TargetStatus.fromDb);
    });
    test('AccountStatus', () {
      roundTrip(AccountStatus.values, (e) => e.dbValue, AccountStatus.fromDb);
    });
    test('ContentStatus', () {
      roundTrip(ContentStatus.values, (e) => e.dbValue, ContentStatus.fromDb);
    });
    test('MediaFileStatus', () {
      roundTrip(
        MediaFileStatus.values,
        (e) => e.dbValue,
        MediaFileStatus.fromDb,
      );
    });
    test('CheckScope', () {
      roundTrip(CheckScope.values, (e) => e.dbValue, CheckScope.fromDb);
    });
    test('CheckTrigger', () {
      roundTrip(CheckTrigger.values, (e) => e.dbValue, CheckTrigger.fromDb);
    });
    test('CheckResult', () {
      roundTrip(CheckResult.values, (e) => e.dbValue, CheckResult.fromDb);
    });
    test('ExtractionMode', () {
      roundTrip(ExtractionMode.values, (e) => e.dbValue, ExtractionMode.fromDb);
    });
    test('ActivityType', () {
      roundTrip(ActivityType.values, (e) => e.dbValue, ActivityType.fromDb);
    });
    test('Severity', () {
      roundTrip(Severity.values, (e) => e.dbValue, Severity.fromDb);
    });
  });

  group('(c) barrel exports and clean co-import', () {
    test('storize_data barrel exposes the settings repo and keys', () {
      expect(storizeDataVersion, isNotEmpty);
      expect(SettingsKeys.byField, hasLength(12));
      final SettingsRepo repo = SharedPrefsSettingsRepo();
      expect(repo, isA<SettingsRepo>());
    });

    test('data barrel + domain + testing + model import without clashes', () {
      // This file compiling with all four unprefixed imports is the check;
      // use one symbol from each to prove they resolve unambiguously.
      expect(FakeSettingsRepo(), isA<SettingsRepo>());
      expect(const AppSettings(), isA<AppSettings>());
      expect(PlatformId.instagram.dbValue, 'INSTAGRAM');
      expect(storizeDataVersion, isNotNull);
    });
  });
}
