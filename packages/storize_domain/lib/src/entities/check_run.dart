import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/internal.dart';
import 'package:storize_model/storize_model.dart';

/// One execution of the check use case (table `check_run`).
@immutable
final class CheckRun {
  /// Creates a check run. Use [unsavedId] for [id] before it is stored.
  ///
  /// [scope] must be [CheckScope.stories] or [CheckScope.posts]: the table
  /// has no `ALL` value, so a combined run is stored as two runs.
  const CheckRun({
    required this.id,
    required this.scope,
    required this.trigger,
    required this.startedAt,
    this.finishedAt,
    this.result,
    this.mode,
    this.targetsChecked = 0,
    this.newItems = 0,
    this.errorCode,
  }) : assert(
         scope != CheckScope.all,
         'A check run has scope STORIES or POSTS, never ALL',
       );

  /// The [id] of an entity that has not been stored yet.
  static const int unsavedId = 0;

  /// The database ID.
  final int id;

  /// Stories or posts.
  final CheckScope scope;

  /// What started the run.
  final CheckTrigger trigger;

  /// When the run started (UTC).
  final DateTime startedAt;

  /// When the run ended (UTC). Null while it runs, or if the process died.
  final DateTime? finishedAt;

  /// The outcome. Null until the run finishes.
  final CheckResult? result;

  /// How data was obtained. Null if no request was made.
  final ExtractionMode? mode;

  /// How many targets were checked.
  final int targetsChecked;

  /// How many new items were found.
  final int newItems;

  /// A short error code, when the run failed.
  final String? errorCode;

  /// Whether the run has finished.
  bool get isFinished => finishedAt != null;

  /// Returns a copy with the given fields replaced. Pass null to clear a
  /// nullable field.
  CheckRun copyWith({
    int? id,
    Object? finishedAt = unset,
    Object? result = unset,
    Object? mode = unset,
    int? targetsChecked,
    int? newItems,
    Object? errorCode = unset,
  }) => CheckRun(
    id: id ?? this.id,
    scope: scope,
    trigger: trigger,
    startedAt: startedAt,
    finishedAt: pick<DateTime>(finishedAt, this.finishedAt),
    result: pick<CheckResult>(result, this.result),
    mode: pick<ExtractionMode>(mode, this.mode),
    targetsChecked: targetsChecked ?? this.targetsChecked,
    newItems: newItems ?? this.newItems,
    errorCode: pick<String>(errorCode, this.errorCode),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckRun &&
          other.id == id &&
          other.scope == scope &&
          other.trigger == trigger &&
          other.startedAt == startedAt &&
          other.finishedAt == finishedAt &&
          other.result == result &&
          other.mode == mode &&
          other.targetsChecked == targetsChecked &&
          other.newItems == newItems &&
          other.errorCode == errorCode);

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    trigger,
    startedAt,
    finishedAt,
    result,
    mode,
    targetsChecked,
    newItems,
    errorCode,
  );

  @override
  String toString() =>
      'CheckRun(id: $id, scope: ${scope.name}, trigger: ${trigger.name}, '
      'result: ${result?.name}, targetsChecked: $targetsChecked, '
      'newItems: $newItems)';
}
