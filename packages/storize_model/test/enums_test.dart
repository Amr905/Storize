import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

/// Checks that every value round-trips through its database string and that
/// the strings match TECH_SPEC §3 exactly.
void expectDbContract<T extends Enum>({
  required List<T> values,
  required T Function(String) fromDb,
  required String Function(T) dbValueOf,
  required List<String> expectedDbValues,
}) {
  expect(values.map(dbValueOf).toList(), expectedDbValues);
  for (final value in values) {
    expect(fromDb(dbValueOf(value)), value);
  }
  expect(() => fromDb('NOT_A_REAL_VALUE'), throwsArgumentError);
  expect(() => fromDb(''), throwsArgumentError);
}

void main() {
  group('database enums', () {
    test('PlatformId', () {
      expectDbContract(
        values: PlatformId.values,
        fromDb: PlatformId.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: ['INSTAGRAM'],
      );
    });

    test('ContentKind', () {
      expectDbContract(
        values: ContentKind.values,
        fromDb: ContentKind.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: ['STORY', 'POST'],
      );
    });

    test('PostType', () {
      expectDbContract(
        values: PostType.values,
        fromDb: PostType.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: ['PHOTO', 'VIDEO', 'CAROUSEL', 'REEL'],
      );
    });

    test('MediaType', () {
      expectDbContract(
        values: MediaType.values,
        fromDb: MediaType.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: ['PHOTO', 'VIDEO'],
      );
    });

    test('TargetCategory', () {
      expectDbContract(
        values: TargetCategory.values,
        fromDb: TargetCategory.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: ['OWN_CLIENT', 'CONSENTED', 'PUBLIC'],
      );
    });

    test('TargetStatus', () {
      expectDbContract(
        values: TargetStatus.values,
        fromDb: TargetStatus.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: [
          'ACTIVE',
          'PAUSED',
          'NOT_VISIBLE',
          'UNAVAILABLE',
          'ERROR',
        ],
      );
    });

    test('AccountStatus', () {
      expectDbContract(
        values: AccountStatus.values,
        fromDb: AccountStatus.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: [
          'ACTIVE',
          'NEEDS_RELOGIN',
          'RESTRICTED',
          'LOGGED_OUT',
        ],
      );
    });

    test('ContentStatus', () {
      expectDbContract(
        values: ContentStatus.values,
        fromDb: ContentStatus.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: [
          'PENDING',
          'PARTIAL',
          'DONE',
          'REMOVED_BEFORE_DOWNLOAD',
        ],
      );
    });

    test('MediaFileStatus', () {
      expectDbContract(
        values: MediaFileStatus.values,
        fromDb: MediaFileStatus.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: [
          'PENDING',
          'DOWNLOADING',
          'DONE',
          'FAILED',
          'FILE_MISSING',
        ],
      );
    });

    test('CheckScope', () {
      expectDbContract(
        values: CheckScope.values,
        fromDb: CheckScope.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: ['STORIES', 'POSTS', 'ALL'],
      );
    });

    test('CheckTrigger', () {
      expectDbContract(
        values: CheckTrigger.values,
        fromDb: CheckTrigger.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: [
          'PERIODIC',
          'MANUAL_ALL',
          'MANUAL_ONE',
          'FIRST_CHECK',
        ],
      );
    });

    test('CheckResult', () {
      expectDbContract(
        values: CheckResult.values,
        fromDb: CheckResult.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: [
          'OK',
          'PARTIAL',
          'SKIPPED_SESSION',
          'RATE_LIMITED',
          'FAILED',
        ],
      );
    });

    test('ExtractionMode', () {
      expectDbContract(
        values: ExtractionMode.values,
        fromDb: ExtractionMode.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: ['DIRECT', 'PAGE'],
      );
    });

    test('ActivityType lists every type from TECH_SPEC §3', () {
      expectDbContract(
        values: ActivityType.values,
        fromDb: ActivityType.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: [
          'CHECK_DONE',
          'DOWNLOADED_STORIES',
          'DOWNLOADED_POSTS',
          'REMOVED_BEFORE_DOWNLOAD',
          'GAP',
          'RATE_LIMITED',
          'SESSION_PROBLEM',
          'PLATFORM_CHANGED',
          'PAGE_MODE_USED',
          'STORAGE_LOW',
          'STORAGE_PAUSED',
          'TARGET_STATUS',
          'FILE_MISSING',
          'APP_CRASH',
        ],
      );
    });

    test('Severity', () {
      expectDbContract(
        values: Severity.values,
        fromDb: Severity.fromDb,
        dbValueOf: (e) => e.dbValue,
        expectedDbValues: ['INFO', 'WARN', 'ERROR'],
      );
    });
  });

  group('unknown database values', () {
    test('error names the rejected value', () {
      expect(
        () => TargetCategory.fromDb('FRIENDS'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.invalidValue,
            'invalidValue',
            'FRIENDS',
          ),
        ),
      );
    });

    test('lookup is case sensitive', () {
      expect(() => PostType.fromDb('photo'), throwsArgumentError);
    });
  });

  group('non-database enums', () {
    test('SessionReason, ExtractionPolicy and the Dart-only values exist', () {
      expect(SessionReason.values, hasLength(2));
      expect(ExtractionPolicy.values, hasLength(2));
    });
  });
}
