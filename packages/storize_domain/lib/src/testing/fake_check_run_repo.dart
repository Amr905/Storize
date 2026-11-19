import 'package:storize_domain/src/entities/check_run.dart';
import 'package:storize_domain/src/repos/check_run_repo.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [CheckRunRepo].
final class FakeCheckRunRepo implements CheckRunRepo {
  final Map<int, CheckRun> _rows = {};
  int _nextId = 1;

  /// All runs, oldest first. For assertions in tests.
  List<CheckRun> get runs => List.unmodifiable(_rows.values);

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
    final run = CheckRun(
      id: _nextId++,
      scope: scope,
      trigger: trigger,
      startedAt: startedAt,
    );
    _rows[run.id] = run;
    return run;
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
    final run = _rows[id];
    if (run == null) throw StateError('No check run with id $id');
    final done = run.copyWith(
      finishedAt: finishedAt,
      result: result,
      mode: mode,
      targetsChecked: targetsChecked,
      newItems: newItems,
      errorCode: errorCode,
    );
    _rows[id] = done;
    return done;
  }

  @override
  Future<CheckRun?> lastFinished(CheckScope scope) async {
    _requireConcrete(scope);
    CheckRun? best;
    for (final r in _rows.values) {
      if (r.scope != scope || !r.isFinished) continue;
      if (best == null || r.startedAt.isAfter(best.startedAt)) best = r;
    }
    return best;
  }
}
