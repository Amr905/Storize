import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storize_data/db/converters.dart';
import 'package:storize_data/db/daos/account_dao.dart';
import 'package:storize_data/db/daos/activity_dao.dart';
import 'package:storize_data/db/daos/check_run_dao.dart';
import 'package:storize_data/db/daos/content_dao.dart';
import 'package:storize_data/db/daos/governor_lease_dao.dart';
import 'package:storize_data/db/daos/targets_dao.dart';
import 'package:storize_data/db/schema_versions.dart';
import 'package:storize_data/db/tables.dart';
import 'package:storize_model/storize_model.dart';

part 'storize_database.g.dart';

/// Thrown when the database file was written by a newer build than this one
/// (its `user_version` is above [StorizeDatabase.schemaVersion]).
///
/// Running against a schema this build does not know could corrupt data, so
/// opening stops here. The migration runs in a transaction, so the file is
/// left untouched.
class DatabaseTooNew implements Exception {
  /// Creates the error for a file at [found] opened by a build that knows
  /// [supported].
  const DatabaseTooNew({required this.found, required this.supported});

  /// The `user_version` of the file.
  final int found;

  /// The newest schema version this build knows.
  final int supported;

  @override
  String toString() =>
      'DatabaseTooNew(found: $found, supported: $supported): the database '
      'was created by a newer version of the app';
}

/// The Storize database (TECH_SPEC §3 and §17, schema v3).
@DriftDatabase(
  tables: [
    LoginAccounts,
    Targets,
    Contents,
    MediaFiles,
    CheckRuns,
    ActivityEvents,
    GovernorLeases,
  ],
  daos: [
    AccountDao,
    TargetsDao,
    ContentDao,
    CheckRunDao,
    ActivityDao,
    GovernorLeaseDao,
  ],
)
class StorizeDatabase extends _$StorizeDatabase {
  /// Opens the database on [executor].
  StorizeDatabase(super.e);

  /// An in-memory (or otherwise throwaway) database for tests, for example
  /// `StorizeDatabase.forTesting(NativeDatabase.memory())`.
  StorizeDatabase.forTesting(super.e);

  /// Opens the production database `storize.sqlite` in the app's private
  /// files directory (`getApplicationSupportDirectory()`, which is `files/`
  /// on Android, matching TECH_SPEC §3 "Files"). drift_flutter always appends
  /// `.sqlite` to the name.
  ///
  /// Isolate safety (the workmanager background isolate and the UI isolate
  /// both open this): every isolate opens its **own** connection to the same
  /// file. SQLite serialises writers across connections; WAL lets readers run
  /// beside a writer, and the 5 s `busy_timeout` makes a writer wait instead
  /// of failing.
  ///
  /// `shareAcrossIsolates: true` is NOT used: drift_flutter then hosts the
  /// connection in an isolate owned by whichever engine opened the database
  /// first. When that is the workmanager engine, Android tears it down after
  /// the task and every other isolate's queries hang (seen on device: the
  /// first login could never take its lease). Cross-isolate change
  /// notifications are lost instead; the app re-runs its queries on resume
  /// and while in the foreground (`ForegroundDbRefresher`).
  StorizeDatabase.open()
    : super(
        driftDatabase(
          name: databaseName,
          native: DriftNativeOptions(
            // shareAcrossIsolates stays false (default): see the doc above.
            databaseDirectory: getApplicationSupportDirectory,
            setup: (db) {
              db
                ..execute('PRAGMA journal_mode = WAL;')
                ..execute('PRAGMA busy_timeout = 5000;')
                ..execute('PRAGMA synchronous = NORMAL;');
            },
          ),
        ),
      );

  /// Base name of the database file (`storize` becomes `storize.sqlite`).
  static const String databaseName = 'storize';

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Each step is generated (`dart run drift_dev schema steps`) and has a
    // test in test/db/migration_test.dart.
    onUpgrade: (m, from, to) async {
      // drift calls onUpgrade for a downgrade too (from > to).
      if (from > to) throw DatabaseTooNew(found: from, supported: to);
      await _upgrade(m, from, to);
    },
    beforeOpen: (details) async {
      // SQLite ignores FK actions unless this is on, per connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  late final OnUpgrade _upgrade = stepByStep(
    from1To2: (m, schema) async {
      // v2 (T-040): post history and highlights on `target`.
      final t = schema.target;
      await m.addColumn(t, t.historyRange);
      await m.addColumn(t, t.historySince);
      await m.addColumn(t, t.historyState);
      await m.addColumn(t, t.historyCursor);
      await m.addColumn(t, t.historyFetched);
      await m.addColumn(t, t.historyOldestSeenAt);
      await m.addColumn(t, t.historyUpdatedAt);
      await m.addColumn(t, t.highlightsEnabled);
    },
    from2To3: (m, schema) async {
      // v3 (T-054, FR-77): location and tagged usernames on `content`.
      final c = schema.content;
      await m.addColumn(c, c.locationName);
      await m.addColumn(c, c.taggedUsernames);
    },
  );

  /// Re-runs every watch query of this connection. Writes from another
  /// isolate's connection do not notify this one, so the foreground calls this
  /// on resume and periodically.
  void refreshFromDisk() => markTablesUpdated(allTables);
}
