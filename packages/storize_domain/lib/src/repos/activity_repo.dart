import 'package:storize_domain/src/entities/activity_event.dart';
import 'package:storize_model/storize_model.dart';

/// Access to the activity log (table `activity_event`).
abstract interface class ActivityRepo {
  /// Emits events from the last [ActivityEvent.retention] (7 days) now and
  /// after every change, newest first (then ID descending).
  ///
  /// With a non-empty [types], only those types are included.
  Stream<List<ActivityEvent>> watchRecent({Set<ActivityType> types = const {}});

  /// Stores [event] and returns it with its assigned ID.
  Future<ActivityEvent> add(ActivityEvent event);

  /// Deletes events with `at` before [cutoff] and returns how many (FR-52).
  Future<int> pruneOlderThan(DateTime cutoff);
}
