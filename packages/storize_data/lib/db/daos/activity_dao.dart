import 'package:drift/drift.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/db/tables.dart';
import 'package:storize_model/storize_model.dart';

part 'activity_dao.g.dart';

/// Raw queries for `activity_event`.
@DriftAccessor(tables: [ActivityEvents])
class ActivityDao extends DatabaseAccessor<StorizeDatabase>
    with _$ActivityDaoMixin {
  ActivityDao(super.attachedDatabase);

  /// Events at or after [since], newest first, optionally only [types].
  /// Uses `idx_activity_event_at`.
  Stream<List<ActivityEventRow>> watchRecent({
    required DateTime since,
    Set<ActivityType> types = const {},
  }) =>
      (select(activityEvents)
            ..where(
              (e) =>
                  e.at.isBiggerOrEqualValue(since.millisecondsSinceEpoch) &
                  (types.isEmpty
                      ? const Constant(true)
                      : e.type.isInValues(types)),
            )
            ..orderBy([
              (e) => OrderingTerm.desc(e.at),
              (e) => OrderingTerm.desc(e.id),
            ]))
          .watch();

  /// Inserts and returns the new id.
  Future<int> insert(ActivityEventsCompanion event) =>
      into(activityEvents).insert(event);

  Future<ActivityEventRow?> getById(int id) =>
      (select(activityEvents)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Deletes events strictly older than [cutoff]. Returns rows deleted.
  Future<int> pruneOlderThan(DateTime cutoff) => (delete(
    activityEvents,
  )..where((e) => e.at.isSmallerThanValue(cutoff.millisecondsSinceEpoch))).go();
}
