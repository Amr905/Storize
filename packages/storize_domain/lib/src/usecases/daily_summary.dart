import 'package:storize_domain/src/entities/app_settings.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/scheduler.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/settings_repo.dart';

/// The device's current UTC offset (the default local clock).
Duration _deviceOffset() => DateTime.now().timeZoneOffset;

/// Local-time arithmetic of the daily summary (FR-78). Pure functions: the
/// local clock is passed in as `localOffset` (UTC plus offset = local wall
/// time), so tests can use any offset.
abstract final class SummaryWindow {
  /// The UTC instant of local midnight on the local day of [nowUtc].
  static DateTime localMidnightUtc(DateTime nowUtc, Duration localOffset) {
    final local = nowUtc.toUtc().add(localOffset);
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).subtract(localOffset);
  }

  /// How long from [nowUtc] until the next local [time]. A time that is
  /// already reached today (or now) gives tomorrow's run. The offset is
  /// fixed for the call, so a DST change may move a run by up to an hour.
  static Duration delayUntilNext(
    SummaryTime time,
    DateTime nowUtc,
    Duration localOffset,
  ) {
    final local = nowUtc.toUtc().add(localOffset);
    var next = DateTime.utc(
      local.year,
      local.month,
      local.day,
      time.hour,
      time.minute,
    );
    if (!next.isAfter(local)) {
      next = next.add(const Duration(days: 1));
    }
    return next.difference(local);
  }
}

/// Counts what was saved since local midnight (FR-78). Makes no Instagram
/// call.
final class CountSavedToday {
  /// Creates the use case. [localOffset] defaults to the device offset.
  CountSavedToday({
    required this._content,
    required this._clock,
    Duration Function()? localOffset,
  }) : _localOffset = localOffset ?? _deviceOffset;

  final ContentRepo _content;
  final Clock _clock;
  final Duration Function() _localOffset;

  /// The counts since the local midnight of now.
  Future<SavedCounts> call() {
    final now = _clock.now();
    final since = SummaryWindow.localMidnightUtc(now, _localOffset());
    return _content.savedSince(since);
  }
}

/// The work of one `daily-summary` run (FR-78). The caller shows the summary
/// from [countToday] first and calls [reschedule] last: the re-schedule uses
/// ExistingWorkPolicy.replace under the running task's own name, so it may
/// stop this run, and nothing must be left to do after it.
final class DailySummaryTask {
  /// Creates the task. [localOffset] defaults to the device offset.
  DailySummaryTask({
    required this._settings,
    required this._clock,
    required this._scheduler,
    required ContentRepo content,
    Duration Function()? localOffset,
  }) : _localOffset = localOffset ?? _deviceOffset,
       _count = CountSavedToday(
         content: content,
         clock: _clock,
         localOffset: localOffset,
       );

  final SettingsRepo _settings;
  final Clock _clock;
  final DailySummaryScheduler _scheduler;
  final Duration Function() _localOffset;
  final CountSavedToday _count;

  /// What to show today, or null: nothing when the mode is not daily or when
  /// nothing was saved since local midnight.
  Future<SavedCounts?> countToday() async {
    final s = await _settings.get();
    if (s.notificationMode != NotificationMode.daily) return null;
    final counts = await _count();
    return counts.total == 0 ? null : counts;
  }

  /// Schedules the next run at the summary time, or cancels the pending one
  /// when the mode is not daily.
  Future<void> reschedule() async {
    final s = await _settings.get();
    await _scheduler.schedule(
      mode: s.notificationMode,
      time: s.summaryTime,
      nowUtc: _clock.now(),
      localOffset: _localOffset(),
    );
  }
}
