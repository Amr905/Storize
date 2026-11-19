import 'package:storize_domain/src/entities/check_run.dart';
import 'package:storize_model/storize_model.dart';

/// Access to check history (table `check_run`).
abstract interface class CheckRunRepo {
  /// Stores a new, unfinished run and returns it with its ID.
  ///
  /// [scope] must be [CheckScope.stories] or [CheckScope.posts]; otherwise
  /// this throws [ArgumentError].
  Future<CheckRun> start({
    required CheckScope scope,
    required CheckTrigger trigger,
    required DateTime startedAt,
  });

  /// Completes the run [id] and returns the stored row.
  ///
  /// Throws [StateError] when the run does not exist.
  Future<CheckRun> finish(
    int id, {
    required DateTime finishedAt,
    required CheckResult result,
    ExtractionMode? mode,
    int targetsChecked = 0,
    int newItems = 0,
    String? errorCode,
  });

  /// The most recent finished run of [scope] (by `startedAt`), or null.
  /// [scope] must be stories or posts, or this throws [ArgumentError]. Gap
  /// detection uses it (EC-10, EC-11).
  Future<CheckRun?> lastFinished(CheckScope scope);
}
