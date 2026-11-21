import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Shows the notifications of a finished task (T-022). Implemented by
/// `NotificationService`; tests use a recording fake. Never throws.
abstract interface class TaskNotifier {
  /// The items a run saved, per target and kind (EC-8). [check] is the check
  /// whose stored items the downloads came from, when there was one.
  Future<void> newItemsSaved(
    DownloadPendingResult downloads, {
    CheckRunResult? check,
  });

  /// The session of the active account changed to [status].
  Future<void> sessionChanged(AccountStatus status);

  /// The downloads stopped for lack of space.
  Future<void> storageFull();
}

/// Runs [RunCheck] (the use case, or a fake in tests).
typedef CheckRunner = Future<CheckRunResult> Function({
  required CheckScope scope,
  required CheckTrigger trigger,
  int? targetId,
  DateTime? deadline,
});

/// Runs [DownloadPending.run].
typedef DownloadRunner = Future<DownloadPendingResult> Function({
  DateTime? deadline,
  ExtractionPolicy policy,
});

/// Routes a background task name to its use case (TECH_SPEC section 2,
/// `callbackDispatcher`).
///
/// It returns what the WorkManager worker should report: `true` for done
/// (also for "nothing to do" and for expected failures such as a rate limit
/// or a lost session, which change state and retry on the next period) and
/// `false` only for "retry with back-off" (a network failure, TECH_SPEC
/// section 7, or an unexpected error).
///
/// **The 10-minute rule.** Every task works until `now + budget` (8 minutes).
/// A check task runs [RunCheck] and then the downloads in the same task; when
/// the deadline stops the downloads with files left, a one-off `download` task
/// takes over (never a foreground service).
final class TaskRouter {
  /// Creates the router.
  TaskRouter({
    required this._runCheck,
    required this._download,
    required this._retention,
    required this._updateCheck,
    required this._settings,
    required this._clock,
    required this._enqueuer,
    this._log,
    this._notifier,
    this.budget = const Duration(minutes: 8),
  });

  /// The time one task may use (about 8 of the 10 minutes WorkManager gives).
  final Duration budget;

  final CheckRunner _runCheck;
  final DownloadRunner _download;
  final Future<Object?> Function() _retention;
  final Future<Object?> Function() _updateCheck;
  final SettingsRepo _settings;
  final Clock _clock;
  final DownloadEnqueuer _enqueuer;
  final DiagnosticLog? _log;
  final TaskNotifier? _notifier;

  /// Runs the task [name] with [input] (the WorkManager input data).
  ///
  /// Never throws. An unknown name is logged and reported as done, so it is
  /// not retried forever (a task left over from an older version).
  Future<bool> route(String name, [Map<String, dynamic>? input]) async {
    try {
      switch (name) {
        case TaskNames.checkStories:
          return await _check(CheckScope.stories, input);
        case TaskNames.checkPosts:
          return await _check(CheckScope.posts, input);
        case TaskNames.download:
          return await _downloadTask();
        case TaskNames.retention:
          await _retention();
          return true;
        case TaskNames.updateCheck:
          await _updateCheck();
          return true;
        default:
          _log?.log(LogLevel.warn, 'background', 'unknown_task');
          return true;
      }
    } on Object catch (error) {
      // Only the type: the message can carry paths or URLs.
      _log?.log(
        LogLevel.error,
        'background',
        'task_failed task=$name type=${error.runtimeType}',
      );
      return false;
    }
  }

  Future<bool> _check(CheckScope scope, Map<String, dynamic>? input) async {
    final manual = input?[TaskNames.inputManual] == true;
    final rawTarget = input?[TaskNames.inputTargetId];
    final targetId = rawTarget is int ? rawTarget : null;
    final trigger = !manual
        ? CheckTrigger.periodic
        : (targetId == null ? CheckTrigger.manualAll : CheckTrigger.manualOne);
    final deadline = _clock.now().add(budget);

    final checked = await _runCheck(
      scope: scope,
      trigger: trigger,
      targetId: targetId,
      deadline: deadline,
    );
    await _downloads(deadline, manual: manual, check: checked);
    await _notifySession(checked);

    final retry =
        checked.result == CheckResult.failed &&
        checked.run.errorCode == 'network';
    return !retry;
  }

  Future<bool> _downloadTask() async {
    await _downloads(_clock.now().add(budget), manual: false);
    return true;
  }

  /// Downloads until [deadline]; hands the rest to a new `download` task when
  /// the deadline stopped the run with files left.
  Future<DownloadPendingResult> _downloads(
    DateTime deadline, {
    required bool manual,
    CheckRunResult? check,
  }) async {
    final settings = await _settings.get();
    final policy = (manual || settings.pageModeInBackground)
        ? ExtractionPolicy.directThenPage
        : ExtractionPolicy.directOnly;
    final result = await _download(deadline: deadline, policy: policy);
    await _notifyDownloads(result, check);
    if (result.stopReason == DownloadStopReason.deadline &&
        result.remaining > 0) {
      await _enqueuer.enqueueDownload(wifiOnly: settings.wifiOnly);
      _log?.log(
        LogLevel.info,
        'background',
        'download_rollover remaining=${result.remaining}',
      );
    }
    return result;
  }

  /// Sends the item and storage alerts of a download run. Never throws.
  Future<void> _notifyDownloads(
    DownloadPendingResult result,
    CheckRunResult? check,
  ) async {
    final notifier = _notifier;
    if (notifier == null) return;
    try {
      await notifier.newItemsSaved(result, check: check);
      if (result.stopReason == DownloadStopReason.storagePaused ||
          result.stopReason == DownloadStopReason.galleryStorageFull) {
        await notifier.storageFull();
      }
    } on Object catch (error) {
      _logNotifyFailure(error);
    }
  }

  /// Sends the login alert when this check ended the session (a status
  /// change only: a later run finds the account inactive and says nothing).
  Future<void> _notifySession(CheckRunResult check) async {
    final notifier = _notifier;
    if (notifier == null) return;
    final status = switch (check.run.errorCode) {
      'session_needs_relogin' => AccountStatus.needsRelogin,
      'session_restricted' => AccountStatus.restricted,
      _ => null,
    };
    if (status == null) return;
    try {
      await notifier.sessionChanged(status);
    } on Object catch (error) {
      _logNotifyFailure(error);
    }
  }

  void _logNotifyFailure(Object error) {
    // The type only.
    _log?.log(
      LogLevel.warn,
      'background',
      'notify_failed type=${error.runtimeType}',
    );
  }
}
