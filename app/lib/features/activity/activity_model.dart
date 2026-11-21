import 'package:flutter/foundation.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The S-11 filter chips.
enum ActivityFilter {
  /// Every entry.
  all,

  /// Stories and posts downloaded.
  downloads,

  /// Problems: rate limits, login, platform, storage, missing files, crashes.
  errors,

  /// Gaps in checks.
  gaps,
}

/// Types shown under the Errors chip.
const Set<ActivityType> activityErrorTypes = {
  ActivityType.rateLimited,
  ActivityType.sessionProblem,
  ActivityType.platformChanged,
  ActivityType.storageLow,
  ActivityType.storagePaused,
  ActivityType.fileMissing,
  ActivityType.appCrash,
};

/// Whether [filter] shows an entry of [type].
bool activityMatches(ActivityFilter filter, ActivityType type) =>
    switch (filter) {
      ActivityFilter.all => true,
      ActivityFilter.downloads =>
        type == ActivityType.downloadedStories ||
            type == ActivityType.downloadedPosts,
      ActivityFilter.errors => activityErrorTypes.contains(type),
      ActivityFilter.gaps => type == ActivityType.gap,
    };

/// The entries of one local calendar day, newest first.
@immutable
class ActivityDayGroup {
  /// Creates a group. [day] is the local midnight of the day.
  const ActivityDayGroup({required this.day, required this.events});

  /// Local midnight of the day.
  final DateTime day;

  /// Entries of the day, newest first.
  final List<ActivityEvent> events;
}

/// What S-11 renders.
@immutable
class ActivityView {
  /// Creates a view.
  const ActivityView({
    required this.groups,
    required this.inWindow,
    required this.filter,
    required this.targetsById,
    required this.now,
  });

  /// The clock reading the view was built with (day labels use it).
  final DateTime now;

  /// Day groups after the filter, newest day first.
  final List<ActivityDayGroup> groups;

  /// Entries in the 7-day window before the filter.
  final int inWindow;

  /// The active filter.
  final ActivityFilter filter;

  /// Known targets by ID, for `@username` labels.
  final Map<int, Target> targetsById;

  /// Number of entries shown after the filter.
  int get itemCount => groups.fold(0, (n, g) => n + g.events.length);
}

/// Builds the view. Keeps only entries from the last
/// [ActivityEvent.retention] (7 days, FR-52), sorts them newest first and
/// groups them by local day.
ActivityView buildActivityView({
  required List<ActivityEvent> events,
  required ActivityFilter filter,
  required DateTime now,
  required Map<int, Target> targetsById,
}) {
  final since = now.subtract(ActivityEvent.retention);
  final windowed =
      [
        for (final e in events)
          if (!e.at.isBefore(since)) e,
      ]..sort((a, b) {
        final byTime = b.at.compareTo(a.at);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
  final shown = [
    for (final e in windowed)
      if (activityMatches(filter, e.type)) e,
  ];
  final groups = <ActivityDayGroup>[];
  for (final e in shown) {
    final local = e.at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (groups.isEmpty || groups.last.day != day) {
      groups.add(ActivityDayGroup(day: day, events: [e]));
    } else {
      groups.last.events.add(e);
    }
  }
  return ActivityView(
    groups: groups,
    inWindow: windowed.length,
    filter: filter,
    targetsById: targetsById,
    now: now,
  );
}
