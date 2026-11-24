import 'package:storize_model/storize_model.dart';

/// The routing names of the background tasks (TECH_SPEC section 4.3).
///
/// A task name is what the dispatcher routes on. A *unique name* is what
/// WorkManager uses to replace or keep a registration. For the periodic tasks
/// the two are the same string.
abstract final class TaskNames {
  /// Periodic story check.
  static const String checkStories = 'check-stories';

  /// Periodic post check.
  static const String checkPosts = 'check-posts';

  /// One-off download roll-over.
  static const String download = 'download';

  /// One-off post-history step: one page per running backfill (T-040).
  static const String history = 'history';

  /// Unique name of the one-off `history` task that a check enqueues, so a
  /// check never queues it twice (the task itself uses [history]).
  static const String historyKick = 'history-kick';

  /// Periodic retention (24 h).
  static const String retention = 'retention';

  /// Periodic update check (24 h).
  static const String updateCheck = 'update-check';

  /// Every task name the dispatcher knows.
  static const Set<String> all = {
    checkStories,
    checkPosts,
    download,
    history,
    retention,
    updateCheck,
  };

  /// Input-data key: the target ID of a one-target manual check.
  static const String inputTargetId = 'targetId';

  /// Input-data key: `true` when the check was started by the user.
  static const String inputManual = 'manual';

  /// Input-data key: `true` for the dev-only debug check that skips the
  /// hourly request limit (T-050).
  static const String inputManualUnmetered = 'manualUnmetered';

  /// The task name of a check for [scope]. [CheckScope.all] has none: it is
  /// two tasks.
  static String forScope(CheckScope scope) => switch (scope) {
    CheckScope.stories => checkStories,
    CheckScope.posts => checkPosts,
    CheckScope.all => throw ArgumentError.value(
      scope,
      'scope',
      'use stories or posts',
    ),
  };

  /// The unique name of a one-off manual check (`check-now-{scope}-{target?}`).
  static String checkNowUnique(CheckScope scope, int? targetId) =>
      'check-now-${scope.name}${targetId == null ? '' : '-$targetId'}';
}
