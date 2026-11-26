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

  /// Keep everything.
  Future<void> keepForever() =>
      _settings.update((s) => s.copyWith(retentionDays: null));

  /// Keeps [days] days and deletes what is now older (FR-54). Returns what
  /// the run did.
  Future<RetentionResult> keepAfterDays(int days) async {
    await _settings.update((s) => s.copyWith(retentionDays: days));
    return _ref.read(applyRetentionProvider).call();
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
