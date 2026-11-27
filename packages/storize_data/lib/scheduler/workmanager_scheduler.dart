import 'package:storize_data/scheduler/task_names.dart';
import 'package:storize_data/scheduler/workmanager_client.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';
import 'package:workmanager/workmanager.dart';

/// What the background dispatcher needs to hand work over to a new task:
/// the download roll-over of the 10-minute rule (TECH_SPEC section 1.3).
abstract interface class DownloadEnqueuer {
  /// Enqueues a one-off `download` task. A second call while one is queued or
  /// running appends, so a roll-over from inside a download task is not lost.
  Future<void> enqueueDownload({required bool wifiOnly});

  /// Enqueues a one-off `history` task that starts after [delay] (T-040).
  ///
  /// With [fromHistoryTask] the task is the next link of a running chain: it
  /// appends, so the task that is running now does not block it. Otherwise
  /// (a check starting or restarting a chain) it keeps an existing request.
  Future<void> enqueueHistory({
    required bool wifiOnly,
    required Duration delay,
    bool fromHistoryTask = false,
  });
}

/// The [Scheduler] over WorkManager (`workmanager` plugin, ADR-4).
///
/// Registration is idempotent and is repeated at every app start (WorkManager
/// itself re-creates persisted work after a reboot, so nothing else is
/// needed for that; a force-stop clears the work and the next start of the
/// app registers it again).
final class WorkmanagerScheduler
    implements Scheduler, DownloadEnqueuer, DailySummaryScheduler {
  /// Creates the scheduler.
  // ignore: prefer_initializing_formals, a private field behind a public name.
  WorkmanagerScheduler(this._client, {DiagnosticLog? log}) : _log = log;

  final WorkmanagerClient _client;
  final DiagnosticLog? _log;

  /// The shortest story interval Android allows (WorkManager minimum).
  static const int minStoryMin = 15;

  /// The shortest post interval (TECH_SPEC section 4.3).
  static const int minPostMin = 60;

  /// The longest offset of the first post run.
  static const int maxPostOffsetMin = 30;

  /// Period of `retention` and `update-check`.
  static const Duration dailyPeriod = Duration(hours: 24);

  static Constraints _network({required bool unmetered}) => Constraints(
    networkType: unmetered ? NetworkType.unmetered : NetworkType.connected,
  );

  @override
  Future<void> apply({
    required int storyMin,
    required int postMin,
    required bool wifiOnly,
  }) async {
    final story = storyMin < minStoryMin ? minStoryMin : storyMin;
    final post = postMin < minPostMin ? minPostMin : postMin;
    final net = _network(unmetered: wifiOnly);
    // The post task starts half a story period later so the two do not
    // coincide, capped so a long story interval does not delay it for hours.
    final offset = Duration(
      minutes: (story ~/ 2).clamp(5, maxPostOffsetMin),
    );
    await _client.registerPeriodic(
      TaskNames.checkStories,
      TaskNames.checkStories,
      frequency: Duration(minutes: story),
      constraints: net,
    );
    await _client.registerPeriodic(
      TaskNames.checkPosts,
      TaskNames.checkPosts,
      frequency: Duration(minutes: post),
      constraints: net,
      initialDelay: offset,
    );
    await _client.registerPeriodic(
      TaskNames.retention,
      TaskNames.retention,
      frequency: dailyPeriod,
      constraints: Constraints(networkType: NetworkType.notRequired),
      policy: ExistingPeriodicWorkPolicy.keep,
    );
    await _client.registerPeriodic(
      TaskNames.updateCheck,
      TaskNames.updateCheck,
      frequency: dailyPeriod,
      constraints: _network(unmetered: false),
      policy: ExistingPeriodicWorkPolicy.keep,
    );
    _log?.log(
      LogLevel.info,
      'scheduler',
      'applied story=${story}m post=${post}m wifiOnly=$wifiOnly',
    );
  }

  @override
  Future<void> checkNow({
    CheckScope scope = CheckScope.all,
    int? targetId,
    bool unmetered = false,
  }) async {
    final scopes = scope == CheckScope.all
        ? const [CheckScope.stories, CheckScope.posts]
        : [scope];
    for (final s in scopes) {
      await _client.registerOneOff(
        TaskNames.checkNowUnique(s, targetId),
        TaskNames.forScope(s),
        constraints: _network(unmetered: false),
        policy: ExistingWorkPolicy.keep,
        inputData: {
          TaskNames.inputManual: true,
          if (unmetered) TaskNames.inputManualUnmetered: true,
          TaskNames.inputTargetId: ?targetId,
        },
        expedited: true,
      );
    }
  }

  @override
  Future<void> enqueueDownload({required bool wifiOnly}) =>
      _client.registerOneOff(
        TaskNames.download,
        TaskNames.download,
        constraints: Constraints(
          networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresStorageNotLow: true,
        ),
        policy: ExistingWorkPolicy.append,
      );

  @override
  Future<void> enqueueHistory({
    required bool wifiOnly,
    required Duration delay,
    bool fromHistoryTask = false,
  }) => _client.registerOneOff(
    fromHistoryTask ? TaskNames.history : TaskNames.historyKick,
    TaskNames.history,
    constraints: Constraints(
      networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      requiresStorageNotLow: true,
    ),
    policy: fromHistoryTask
        ? ExistingWorkPolicy.append
        : ExistingWorkPolicy.keep,
    initialDelay: delay,
  );

  @override
  Future<void> kickHistory() => enqueueHistory(
    wifiOnly: false,
    delay: Duration.zero,
  );

  @override
  Future<void> cancelAll() => _client.cancelAll();

  @override
  Future<void> schedule({
    required NotificationMode mode,
    required SummaryTime time,
    required DateTime nowUtc,
    required Duration localOffset,
  }) async {
    if (mode != NotificationMode.daily) {
      await _client.cancelByUniqueName(TaskNames.dailySummary);
      return;
    }
    // ExistingWorkPolicy.replace: a changed time or a finished run replaces
    // the pending one, so there is never a second summary run queued.
    await _client.registerOneOff(
      TaskNames.dailySummary,
      TaskNames.dailySummary,
      constraints: Constraints(networkType: NetworkType.notRequired),
      policy: ExistingWorkPolicy.replace,
      initialDelay: SummaryWindow.delayUntilNext(time, nowUtc, localOffset),
    );
  }
}
