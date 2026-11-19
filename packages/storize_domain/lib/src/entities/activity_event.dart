import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/internal.dart';
import 'package:storize_model/storize_model.dart';

/// A user-visible entry of the activity log (table `activity_event`).
@immutable
final class ActivityEvent {
  /// Creates an event. Use [unsavedId] for [id] before it is stored.
  ActivityEvent({
    required this.id,
    required this.at,
    required this.type,
    this.severity = Severity.info,
    this.targetId,
    this.checkRunId,
    this.count = 1,
    Map<String, Object?> payload = const {},
  }) : payload = freezeMap(payload);

  /// The [id] of an entity that has not been stored yet.
  static const int unsavedId = 0;

  /// How long events are kept (FR-52).
  static const Duration retention = Duration(days: 7);

  /// The database ID.
  final int id;

  /// When it happened (UTC).
  final DateTime at;

  /// What happened.
  final ActivityType type;

  /// How serious it is.
  final Severity severity;

  /// The related target, if any.
  final int? targetId;

  /// The related check run, if any.
  final int? checkRunId;

  /// How many items it covers, for example the number of new stories.
  final int count;

  /// Extra details (`payload_json`). Must not contain secrets.
  final Map<String, Object?> payload;

  /// Returns a copy with the given fields replaced. Pass null to clear a
  /// nullable field.
  ActivityEvent copyWith({
    int? id,
    DateTime? at,
    ActivityType? type,
    Severity? severity,
    Object? targetId = unset,
    Object? checkRunId = unset,
    int? count,
    Map<String, Object?>? payload,
  }) => ActivityEvent(
    id: id ?? this.id,
    at: at ?? this.at,
    type: type ?? this.type,
    severity: severity ?? this.severity,
    targetId: pick<int>(targetId, this.targetId),
    checkRunId: pick<int>(checkRunId, this.checkRunId),
    count: count ?? this.count,
    payload: payload ?? this.payload,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityEvent &&
          other.id == id &&
          other.at == at &&
          other.type == type &&
          other.severity == severity &&
          other.targetId == targetId &&
          other.checkRunId == checkRunId &&
          other.count == count &&
          deepEquals(other.payload, payload));

  @override
  int get hashCode => Object.hash(
    id,
    at,
    type,
    severity,
    targetId,
    checkRunId,
    count,
    deepHash(payload),
  );

  @override
  String toString() =>
      'ActivityEvent(id: $id, at: $at, type: ${type.name}, '
      'severity: ${severity.name}, targetId: $targetId, count: $count)';
}
