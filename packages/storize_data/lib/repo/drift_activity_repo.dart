import 'package:drift/drift.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo_support.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// [ActivityRepo] over [ActivityDao]. The 7-day window follows the [Clock].
final class DriftActivityRepo implements ActivityRepo {
  /// Creates the repo over [db]; [clock] decides what "last 7 days" means.
  DriftActivityRepo(StorizeDatabase db, Clock clock)
    : _dao = db.activityDao,
      _clock = clock;

  final ActivityDao _dao;
  final Clock _clock;

  /// Events of the last [ActivityEvent.retention], newest first.
  ///
  /// The window start is derived from the clock on every emission (T-004
  /// F-4), not frozen at subscribe time. The query itself starts at the
  /// subscribe-time window start, which only ever includes more rows than any
  /// later emission needs because the clock moves forward.
  @override
  Stream<List<ActivityEvent>> watchRecent({
    Set<ActivityType> types = const {},
  }) async* {
    final queryStart = _clock.now().subtract(ActivityEvent.retention);
    yield* _dao
        .watchRecent(since: queryStart, types: types)
        .map(
          (rows) => [
            for (final row in rows)
              if (!row.at.isBefore(
                _clock.now().subtract(ActivityEvent.retention),
              ))
                _toEvent(row),
          ],
        );
  }

  @override
  Future<ActivityEvent> add(ActivityEvent event) async {
    final id = await _dao.insert(
      ActivityEventsCompanion(
        at: Value(event.at),
        type: Value(event.type),
        severity: Value(event.severity),
        targetId: Value(event.targetId),
        checkRunId: Value(event.checkRunId),
        count: Value(event.count),
        payloadJson: Value(encodeJsonMap(event.payload)),
      ),
    );
    return event.copyWith(id: id);
  }

  @override
  Future<int> pruneOlderThan(DateTime cutoff) => _dao.pruneOlderThan(cutoff);

  /// Deletes events older than [ActivityEvent.retention] (7 days, FR-52),
  /// measured from the clock. Returns how many were deleted.
  Future<int> pruneExpired() =>
      pruneOlderThan(_clock.now().subtract(ActivityEvent.retention));
}

ActivityEvent _toEvent(ActivityEventRow r) => ActivityEvent(
  id: r.id,
  at: r.at,
  type: r.type,
  severity: r.severity,
  targetId: r.targetId,
  checkRunId: r.checkRunId,
  count: r.count,
  payload: decodeJsonMap(r.payloadJson),
);
