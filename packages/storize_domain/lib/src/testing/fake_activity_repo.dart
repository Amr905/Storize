import 'package:storize_domain/src/entities/activity_event.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/repos/activity_repo.dart';
import 'package:storize_domain/src/testing/change_feed.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [ActivityRepo]. The 7-day window follows the given [Clock].
final class FakeActivityRepo implements ActivityRepo {
  /// Creates the repo. The clock decides what "last 7 days" means.
  FakeActivityRepo(this._clock);

  final Clock _clock;
  final Map<int, ActivityEvent> _rows = {};
  final ChangeFeed _feed = ChangeFeed();
  int _nextId = 1;

  @override
  Stream<List<ActivityEvent>> watchRecent({
    Set<ActivityType> types = const {},
  }) => _feed.watch(() {
    final since = _clock.now().subtract(ActivityEvent.retention);
    final list =
        _rows.values
            .where(
              (e) =>
                  !e.at.isBefore(since) &&
                  (types.isEmpty || types.contains(e.type)),
            )
            .toList()
          ..sort((a, b) {
            final byTime = b.at.compareTo(a.at);
            return byTime != 0 ? byTime : b.id.compareTo(a.id);
          });
    return list;
  });

  @override
  Future<ActivityEvent> add(ActivityEvent event) async {
    final stored = event.copyWith(id: _nextId++);
    _rows[stored.id] = stored;
    _feed.notify();
    return stored;
  }

  @override
  Future<int> pruneOlderThan(DateTime cutoff) async {
    final old = _rows.values.where((e) => e.at.isBefore(cutoff)).toList();
    for (final e in old) {
      _rows.remove(e.id);
    }
    if (old.isNotEmpty) _feed.notify();
    return old.length;
  }
}
