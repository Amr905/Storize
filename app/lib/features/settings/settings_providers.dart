import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:storize_app/core/providers.dart';
import 'package:storize_data/update/update.dart';
import 'package:storize_domain/storize_domain.dart';

/// The user settings. One repo subscription.
final StreamProvider<AppSettings> settingsStreamProvider =
    StreamProvider<AppSettings>(
      (ref) => ref.watch(settingsRepoProvider).watch(),
    );

/// The appearance as a Flutter [ThemeMode]. [ThemeMode.system] until the
/// stored setting loads, so the first frame follows the phone.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(settingsStreamProvider).value?.themeMode;
  return switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system || null => ThemeMode.system,
  };
});

/// All targets, for the per-account storage list. One repo subscription.
final settingsTargetsProvider = StreamProvider<List<Target>>(
  (ref) => ref.watch(targetRepoProvider).watchAll(),
);

/// Stored bytes per target and device space (FR-53). Recomputed each time
/// S-12 opens.
final settingsStorageProvider = FutureProvider<StorageReport>(
  (ref) => ComputeStorage(
    content: ref.watch(contentRepoProvider),
    storage: ref.watch(storageInfoProvider),
  ).call(),
);

/// The progress of moving the saved files (FR-79), re-read every second while
/// a move runs and once otherwise. Call `ref.invalidate` after starting or
/// stopping a move. [MoveProgress.none] when moving is not wired.
final StreamProvider<MoveProgress> moveProgressProvider =
    StreamProvider.autoDispose<MoveProgress>((
      ref,
    ) async* {
      final store = ref.watch(moveStateStoreProvider);
      if (store == null) {
        yield MoveProgress.none;
        return;
      }
      while (true) {
        final progress = await store.read();
        yield progress;
        if (progress.status != MoveStatus.running) return;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    });

/// The installed version shown in S-12 and compared by the update check.
///
/// The default matches `pubspec.yaml`. Production should override it with
/// `CompositionParts.currentVersion` so the two never drift.
final appVersionProvider = Provider<String>((ref) => '0.1.0');

/// The GitHub release checker (T-023). The default uses the real client and
/// closes it with the provider.
final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  final checker = UpdateChecker();
  ref.onDispose(checker.close);
  return checker;
});

/// Whether a newer release exists. Never fails: every error is
/// [UpdateState.none] (the check is silent, NFR-9).
final updateStateProvider = FutureProvider<UpdateState>((ref) async {
  try {
    return await ref
        .watch(updateCheckerProvider)
        .checkForUpdate(currentVersion: ref.watch(appVersionProvider));
  } on Object {
    return UpdateState.none;
  }
});

/// The retention use case (FR-54), built from the ports.
final applyRetentionProvider = Provider<ApplyRetention>(
  (ref) => ApplyRetention(
    settings: ref.watch(settingsRepoProvider),
    content: ref.watch(contentRepoProvider),
    checkRuns: ref.watch(checkRunRepoProvider),
    deleteContent: ref.watch(deleteContentProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// What "Keep downloads: After N days" would delete now.
@immutable
final class RetentionPreview {
  /// Creates a preview.
  const RetentionPreview({required this.items, required this.bytes});

  /// Items that retention would delete.
  final int items;

  /// Stored media bytes of those items.
  final int bytes;
}

/// The preview for `days`, computed with [isRetentionEligible] so it matches
/// what [ApplyRetention] deletes.
final FutureProviderFamily<RetentionPreview, int> retentionPreviewProvider =
    FutureProvider.family<RetentionPreview, int>((ref, days) async {
      final cutoff = ref
          .watch(clockProvider)
          .now()
          .subtract(Duration(days: days));
      final candidates = await ref.watch(contentRepoProvider).olderThan(cutoff);
      var items = 0;
      var bytes = 0;
      for (final item in candidates) {
        if (!isRetentionEligible(item, cutoff)) continue;
        items++;
        for (final media in item.media) {
          bytes += media.sizeBytes ?? 0;
        }
      }
      return RetentionPreview(items: items, bytes: bytes);
    });

/// The S-12 write actions. Widgets call these; they never touch the repo.
final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);

/// Writes settings and keeps the scheduler in step with them.
class SettingsActions {
  /// Creates the actions on [_ref].
  SettingsActions(this._ref);

  final Ref _ref;

  SettingsRepo get _settings => _ref.read(settingsRepoProvider);

  /// Story check interval. Re-applies the background schedule.
  Future<void> setStoryInterval(int minutes) =>
      _reschedule((s) => s.copyWith(storyIntervalMin: minutes));

  /// Post check interval. Re-applies the background schedule.
  Future<void> setPostInterval(int minutes) =>
      _reschedule((s) => s.copyWith(postIntervalMin: minutes));

  /// Wi-Fi only. Re-applies the background schedule.
  Future<void> setWifiOnly({required bool on}) =>
      _reschedule((s) => s.copyWith(wifiOnly: on));

  /// Notification for new stories.
  Future<void> setNotifyStories({required bool on}) =>
      _settings.update((s) => s.copyWith(notifyStories: on));

  /// Notification for new posts.
  Future<void> setNotifyPosts({required bool on}) =>
      _settings.update((s) => s.copyWith(notifyPosts: on));

  /// Notification for login problems.
  Future<void> setNotifyLogin({required bool on}) =>
      _settings.update((s) => s.copyWith(notifyLogin: on));

  /// Appearance: system, light or dark. Takes effect live.
  Future<void> setThemeMode(AppThemeMode mode) =>
      _settings.update((s) => s.copyWith(themeMode: mode));

  /// Notify me: per item, daily summary or off (FR-78). Re-schedules the
  /// daily summary run.
  Future<void> setNotificationMode(NotificationMode mode) =>
      _rescheduleSummary((s) => s.copyWith(notificationMode: mode));

  /// The daily summary time (FR-78). Re-schedules the daily summary run.
  Future<void> setSummaryTime(SummaryTime time) =>
      _rescheduleSummary((s) => s.copyWith(summaryTime: time));

  /// Hide from phone gallery (FR-79): new downloads go to private storage
  /// (`on`) or back to the gallery. Files already saved stay where they are.
  /// Returns how many saved files are not yet where the setting now says
  /// (what "Move N saved files now?" offers to move).
  Future<int> setHideFromGallery({required bool on}) async {
    await _settings.update((s) => s.copyWith(hideFromGallery: on));
    final move = _ref.read(moveLibraryProvider);
    if (move == null) return 0;
    try {
      return await move.countToMove(
        on ? StorageTarget.private : StorageTarget.gallery,
      );
    } on Object {
      return 0;
    }
  }

  /// Starts (or resumes) moving the saved files to [target] in the
  /// background. [total] is shown until the task reports its own count.
  Future<void> startMove(StorageTarget target, {required int total}) async {
    final store = _ref.read(moveStateStoreProvider);
    final scheduler = _ref.read(moveSchedulerProvider);
    if (store == null || scheduler == null) return;
    await store.write(
      MoveProgress(
        status: MoveStatus.running,
        target: target,
        total: total,
        updatedAt: _ref.read(clockProvider).now(),
      ),
    );
    _ref.invalidate(moveProgressProvider);
    await scheduler.enqueueMove(target);
  }

  /// Stops the move after the file it is working on. Files moved so far stay
  /// moved and a later start continues.
  Future<void> cancelMove() async {
    await _ref.read(moveLibraryProvider)?.cancel();
    await _ref.read(moveSchedulerProvider)?.cancelMove();
    _ref.invalidate(moveProgressProvider);
  }

  /// Clears the message of a finished or stopped move.
  Future<void> dismissMove() async {
    await _ref.read(moveStateStoreProvider)?.write(MoveProgress.none);
    _ref.invalidate(moveProgressProvider);
  }

  /// Keep everything.
  Future<void> keepForever() =>
      _settings.update((s) => s.copyWith(retentionDays: null));

  /// Keeps [days] days and deletes what is now older (FR-54). Returns what
  /// the run did.
  Future<RetentionResult> keepAfterDays(int days) async {
    await _settings.update((s) => s.copyWith(retentionDays: days));
    return _ref.read(applyRetentionProvider).call();
  }

  Future<void> _rescheduleSummary(
    AppSettings Function(AppSettings) change,
  ) async {
    final s = await _settings.update(change);
    // Only the WorkManager scheduler can register the daily run.
    switch (_ref.read(schedulerProvider)) {
      case final DailySummaryScheduler scheduler:
        await scheduler.schedule(
          mode: s.notificationMode,
          time: s.summaryTime,
          nowUtc: _ref.read(clockProvider).now(),
          localOffset: DateTime.now().timeZoneOffset,
        );
      case _:
    }
  }

  Future<void> _reschedule(AppSettings Function(AppSettings) change) async {
    final s = await _settings.update(change);
    await _ref
        .read(schedulerProvider)
        .apply(
          storyMin: s.storyIntervalMin,
          postMin: s.postIntervalMin,
          wifiOnly: s.wifiOnly,
        );
  }
}
