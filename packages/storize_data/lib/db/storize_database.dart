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
import 'package:storize_data/db/tables.dart';
import 'package:storize_model/storize_model.dart';

part 'storize_database.g.dart';

/// The Storize database (TECH_SPEC §3, schema v1).
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
  /// both open this): `shareAcrossIsolates: true` makes drift_flutter host the
  /// connection in one dedicated isolate registered by name, and every other
  /// isolate in the process connects to it, so writes are serialised. As a
  /// second line of defence for the case where two processes ever open the
  /// file, the connection uses WAL and a 5 s `busy_timeout`.
  StorizeDatabase.open()
    : super(
        driftDatabase(
          name: databaseName,
          native: DriftNativeOptions(
            shareAcrossIsolates: true,
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Future versions: add `onUpgrade: stepByStep(...)` with the generated
    // steps (`dart run drift_dev schema steps`) and a test per step.
    beforeOpen: (details) async {
      // SQLite ignores FK actions unless this is on, per connection.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
