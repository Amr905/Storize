import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo_support.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// [CheckRunRepo] over [CheckRunDao].
final class DriftCheckRunRepo implements CheckRunRepo {
  /// Creates the repo over [db].
  DriftCheckRunRepo(StorizeDatabase db) : _dao = db.checkRunDao;

  final CheckRunDao _dao;

  static void _requireConcrete(CheckScope scope) {
    if (scope == CheckScope.all) {
      throw ArgumentError.value(scope, 'scope', 'must be stories or posts');
    }
  }

  @override
  Future<CheckRun> start({
    required CheckScope scope,
    required CheckTrigger trigger,
    required DateTime startedAt,
  }) async {
    _requireConcrete(scope);
    final id = await _dao.start(
      scope: scope,
      trigger: trigger,
      startedAt: startedAt,
    );
    return CheckRun(
      id: id,
      scope: scope,
      trigger: trigger,
      startedAt: startedAt,
    );
  }

  @override
  Future<CheckRun> finish(
    int id, {
    required DateTime finishedAt,
    required CheckResult result,
    ExtractionMode? mode,
    int targetsChecked = 0,
    int newItems = 0,
    String? errorCode,
  }) async {
    final rows = await _dao.finish(
      id,
      finishedAt: finishedAt,
      result: result,
      mode: mode,
      targetsChecked: targetsChecked,
      newItems: newItems,
      errorCode: errorCode,
    );
    requireRowChanged(rows, 'check run', id);
    return _toRun((await _dao.getById(id))!);
  }

  @override
  Future<CheckRun?> lastFinished(CheckScope scope) async {
    _requireConcrete(scope);
    final row = await _dao.lastFinished(scope);
    return row == null ? null : _toRun(row);
  }
}

CheckRun _toRun(CheckRunRow r) => CheckRun(
  id: r.id,
  scope: r.scope,
  trigger: r.trigger,
  startedAt: r.startedAt,
  finishedAt: r.finishedAt,
  result: r.result,
  mode: r.mode,
  targetsChecked: r.targetsChecked,
  newItems: r.newItems,
  errorCode: r.errorCode,
);
