import 'package:drift/drift.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/db/tables.dart';
import 'package:storize_model/storize_model.dart';

part 'check_run_dao.g.dart';

/// Raw queries for `check_run`.
@DriftAccessor(tables: [CheckRuns])
class CheckRunDao extends DatabaseAccessor<StorizeDatabase>
    with _$CheckRunDaoMixin {
  CheckRunDao(super.attachedDatabase);

  /// Starts a run and returns its id. [scope] must be stories or posts
  /// (`CheckScope.all` throws [ArgumentError]).
  Future<int> start({
    required CheckScope scope,
    required CheckTrigger trigger,
    required DateTime startedAt,
  }) => into(checkRuns).insert(
    CheckRunsCompanion.insert(
      scope: scope,
      trigger: trigger,
      startedAt: startedAt,
    ),
  );

  Future<CheckRunRow?> getById(int id) =>
      (select(checkRuns)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Records the outcome. Returns rows changed (0 if the id is unknown).
  Future<int> finish(
    int id, {
    required DateTime finishedAt,
    required CheckResult result,
    ExtractionMode? mode,
    int targetsChecked = 0,
    int newItems = 0,
    String? errorCode,
  }) => (update(checkRuns)..where((r) => r.id.equals(id))).write(
    CheckRunsCompanion(
      finishedAt: Value(finishedAt),
      result: Value(result),
      mode: Value(mode),
      targetsChecked: Value(targetsChecked),
      newItems: Value(newItems),
      errorCode: Value(errorCode),
    ),
  );

  /// The newest finished run of [scope] by `started_at` (uses
  /// `idx_check_run_scope_started_at`).
  Future<CheckRunRow?> lastFinished(CheckScope scope) =>
      (select(checkRuns)
            ..where(
              (r) => r.scope.equalsValue(scope) & r.finishedAt.isNotNull(),
            )
            ..orderBy([
              (r) => OrderingTerm.desc(r.startedAt),
              (r) => OrderingTerm.desc(r.id),
            ])
            ..limit(1))
          .getSingleOrNull();
}
