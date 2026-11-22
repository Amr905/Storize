import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:storize_app/core/composition.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/lock/biometric_auth.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_app/features/onboarding/setup_ops.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_app/notifications/flutter_local_notifications_port.dart';
import 'package:storize_app/notifications/notification_lookups.dart';
import 'package:storize_app/notifications/notification_service.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/files/files.dart';
import 'package:storize_data/log/log.dart';
import 'package:storize_data/repo/repo.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_data/security/security.dart';
import 'package:storize_data/settings/settings.dart';
import 'package:storize_data/update/update.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/webview.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

/// The running app version, for the update check. Set with
/// `--dart-define=STORIZE_VERSION=x.y.z` in release builds; the default
/// matches `app/pubspec.yaml` (no package-info dependency is added).
const String appVersion = String.fromEnvironment(
  'STORIZE_VERSION',
  defaultValue: '0.1.0',
);

/// The [SeenBreakerStore] in shared preferences, so the foreground and the
/// background isolate (and later processes) see one breaker. The value is a
/// bool only: no id, URL or name.
final class SharedPrefsSeenBreakerStore implements SeenBreakerStore {
  /// Creates the store over [flag].
  SharedPrefsSeenBreakerStore([SharedPrefsFlag? flag])
    : _flag = flag ?? SharedPrefsFlag(key);

  /// The preference key.
  static const String key = 'storize.seenBreakerTripped';

  final SharedPrefsFlag _flag;

  @override
  Future<bool> isTripped() => _flag.get();

  @override
  Future<void> markTripped() => _flag.set();

  @override
  Future<void> clear() => _flag.clear();
}

/// Builds the real parts and the composition of one isolate.
///
/// Call it after the Flutter binding is initialised and, in a background
/// isolate, after `DartPluginRegistrant.ensureInitialized()`.
Future<AppComposition> composeProduction({
  required bool background,
  required StorizeDiagnostics diagnostics,
}) async {
  final db = StorizeDatabase.open();
  final plugin = StorizePlatformAndroid();
  final updateChecker = UpdateChecker();
  final scheduler = WorkmanagerScheduler(
    PluginWorkmanagerClient(),
    log: diagnostics.log,
  );
  final accounts = DriftAccountRepo(db);
  final gallery = PluginGalleryStore(plugin);
  final settings = SharedPrefsSettingsRepo();
  final notifications = NotificationService(
    port: FlutterLocalNotificationsPort(),
    settings: settings,
    lookups: RepoNotificationLookups(
      targets: DriftTargetRepo(db),
      content: DriftContentRepo(db),
    ),
    log: diagnostics.log,
  );
  // Never throws; channels exist before the first notification.
  await notifications.initialize();
  final parts = CompositionParts(
    db: db,
    settings: settings,
    sessions: SecureStorageSessionStore(
      SecureStorageSessionStore.defaultStorage(),
      onUnreadable: markLoggedOutOnUnreadable(accounts),
    ),
    gallery: gallery,
    findExisting: gallery.findExisting,
    fullPhotoReader: plugin.readBytes,
    cache: FileMediaCache.pathProvider(),
    storage: PluginStorageInfo(plugin),
    igHttp: DartIoHttp(),
    cdnHttp: DartIoCdnHttp(),
    pageDriver: const InAppPageDriver(),
    hookSource: loadHookSource,
    seenStore: SharedPrefsSeenBreakerStore(),
    log: diagnostics.log,
    crashMarker: diagnostics.marker,
    notifications: notifications,
    setupOps: productionSetupOps(plugin),
    scheduler: scheduler,
    enqueuer: scheduler,
    updateChecker: updateChecker,
    currentVersion: appVersion,
    pins: PinVault(SecureStorageSessionStore.defaultStorage()),
    biometric: LocalAuthBiometric(),
    closers: [db.close, () async => updateChecker.close()],
  );
  return AppComposition.assemble(parts, background: background);
}

/// Maps the plugin's answer to the onboarding outcome.
PermissionOutcome _outcome(PermissionStatus status) => switch (status) {
  PermissionStatus.granted => PermissionOutcome.granted,
  PermissionStatus.denied => PermissionOutcome.denied,
  PermissionStatus.permanentlyDenied => PermissionOutcome.permanentlyDenied,
};

/// The onboarding device operations over [plugin]. Only the two permissions
/// the plugin allowlists are ever asked about.
SetupOps productionSetupOps(StorizePlatformAndroid plugin) => PlatformSetupOps(
  platform: plugin,
  notificationsAllowed: () => plugin.checkPermission('POST_NOTIFICATIONS'),
  requestNotifications: () async =>
      _outcome(await plugin.requestPermission('POST_NOTIFICATIONS')),
  sdkInt: plugin.sdkInt,
  storageGranted: () => plugin.checkPermission('WRITE_EXTERNAL_STORAGE'),
  requestStorage: () async =>
      _outcome(await plugin.requestPermission('WRITE_EXTERNAL_STORAGE')),
  openAppSettings: () async {
    await plugin.openAppSettings();
  },
);

/// "Check now" over the real scheduler: enqueues an expedited one-off task
/// for every scope (FR-21). The result only says whether it was enqueued;
/// the outcome shows in the Activity screen when the task has run.
final class SchedulerCheckNowAction implements CheckNowAction {
  /// Creates the action.
  const SchedulerCheckNowAction(this._scheduler);

  final Scheduler _scheduler;

  @override
  Future<CheckNowResult> call({int? targetId}) async {
    try {
      await _scheduler.checkNow(targetId: targetId);
      return const CheckNowResult();
    } on Object {
      return const CheckNowResult(failed: true);
    }
  }
}

/// The provider overrides that connect the app to [c].
///
/// The app-lock test bypass is deliberately not overridden: it stays at its
/// default (`false`), so the lock gate always applies.
List<Override> appOverrides(AppComposition c) => [
  targetRepoProvider.overrideWithValue(c.targets),
  contentRepoProvider.overrideWithValue(c.content),
  accountRepoProvider.overrideWithValue(c.accounts),
  activityRepoProvider.overrideWithValue(c.activity),
  checkRunRepoProvider.overrideWithValue(c.checkRuns),
  settingsRepoProvider.overrideWithValue(c.settings),
  governorLeaseRepoProvider.overrideWithValue(c.leases),
  contentPlatformProvider.overrideWithValue(c.platform),
  schedulerProvider.overrideWithValue(c.scheduler),
  clockProvider.overrideWithValue(c.clock),
  galleryStoreProvider.overrideWithValue(c.parts.gallery),
  mediaCacheProvider.overrideWithValue(c.parts.cache),
  storageInfoProvider.overrideWithValue(c.parts.storage),
  sessionStoreProvider.overrideWithValue(c.parts.sessions),
  pinStoreProvider.overrideWithValue(c.parts.pins),
  biometricAuthProvider.overrideWithValue(c.parts.biometric),
  checkNowActionProvider.overrideWithValue(
    SchedulerCheckNowAction(c.scheduler),
  ),
  if (c.parts.fullPhotoReader case final read?)
    fullPhotoReaderProvider.overrideWithValue(read),
  appVersionProvider.overrideWithValue(c.parts.currentVersion),
  loginLeaseProvider.overrideWithValue(c.loginLease),
  loginPlatformProvider.overrideWithValue(c.loginPlatform),
  if (c.parts.setupOps case final ops?) setupOpsProvider.overrideWithValue(ops),
  // Until the setting is read the gate stays open: a returning user never
  // sees S-01, and a first-run user is redirected as soon as it loads.
  onboardingCompleteProvider.overrideWith(
    (ref) =>
        ref.watch(setupFinishedProvider) ||
        (ref.watch(onboardingDoneProvider).value ?? true),
  ),
];
