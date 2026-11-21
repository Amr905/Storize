import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/settings/settings_page.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/deep_link.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_data/update/update.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../lock/lock_fakes.dart';

/// "Now" in every settings and account test: 2026-11-21 12:00 UTC.
final DateTime rigNow = DateTime.utc(2026, 11, 21, 12);

/// Fakes for S-12 and S-13. Every port the screens touch is a fake, and the
/// lock fixture supplies the app-lock row's own fakes.
class SettingsRig {
  SettingsRig({
    AppSettings settings = const AppSettings(),
    this.updateState = UpdateState.none,
  }) : settingsRepo = FakeSettingsRepo(settings),
       lock = LockFixture(enabled: false, start: rigNow) {
    content = FakeContentRepo(targets: targets);
    activity = FakeActivityRepo(clock);
  }

  /// The settings store the screens read and write.
  final FakeSettingsRepo settingsRepo;

  /// Clock, lock fakes and the app-lock row's dependencies.
  final LockFixture lock;

  /// Targets (`@username` rows and per-account storage).
  final FakeTargetRepo targets = FakeTargetRepo();

  /// Stored content and media.
  late final FakeContentRepo content;

  /// Activity events (rate-limit count on S-13).
  late final FakeActivityRepo activity;

  /// The Instagram login(s).
  final FakeAccountRepo accounts = FakeAccountRepo();

  /// Session vault.
  final FakeSessionStore sessions = FakeSessionStore();

  /// Records `apply` and `cancelAll` calls.
  final FakeScheduler scheduler = FakeScheduler();

  /// Device space.
  final FakeStorageInfo storage = FakeStorageInfo();

  /// Run-check history (retention's clock-skew guard).
  final FakeCheckRunRepo checkRuns = FakeCheckRunRepo();

  /// Gallery files (deleted by retention).
  final FakeMediaCache cache = FakeMediaCache();
  late final FakeGalleryStore gallery = FakeGalleryStore(cache: cache);

  /// The result of the update check.
  UpdateState updateState;

  /// The fake clock.
  FakeClock get clock => lock.clock;

  /// Riverpod overrides for every port used by S-12 and S-13.
  List<Override> get overrides => [
    ...lock.overridesWith(settingsRepo: settingsRepo),
    targetRepoProvider.overrideWithValue(targets),
    contentRepoProvider.overrideWithValue(content),
    accountRepoProvider.overrideWithValue(accounts),
    sessionStoreProvider.overrideWithValue(sessions),
    activityRepoProvider.overrideWithValue(activity),
    checkRunRepoProvider.overrideWithValue(checkRuns),
    galleryStoreProvider.overrideWithValue(gallery),
    mediaCacheProvider.overrideWithValue(cache),
    storageInfoProvider.overrideWithValue(storage),
    schedulerProvider.overrideWithValue(scheduler),
    updateStateProvider.overrideWith((ref) async => updateState),
  ];

  /// Adds a target and returns it with its ID.
  Future<Target> addTarget(String username) => targets.insert(
    Target(
      id: Target.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: 'uid-$username',
      username: username,
      category: TargetCategory.ownClient,
      postsWatermarkAt: DateTime.utc(2026),
      addedAt: DateTime.utc(2026),
    ),
  );

  /// Stores one story with one downloaded slide of [sizeBytes].
  Future<int> addStory({
    required Target target,
    required String remoteId,
    required DateTime postedAt,
    required DateTime detectedAt,
    DateTime? downloadedAt,
    int? sizeBytes,
  }) async {
    final result = await content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: target.id,
        kind: ContentKind.story,
        remoteId: remoteId,
        postedAt: postedAt,
        slideCount: 1,
        detectedAt: detectedAt,
        status: ContentStatus.done,
      ),
      [
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: Content.unsavedId,
          slideIndex: 0,
          mediaType: MediaType.photo,
          sourceUrl: 'https://cdn.example.test/$remoteId',
          status: MediaFileStatus.done,
          sizeBytes: sizeBytes,
          downloadedAt: downloadedAt,
        ),
      ],
    );
    return result.contentId;
  }

  /// Adds an Instagram login connected three days before [rigNow].
  Future<LoginAccount> addAccount({
    String username = 'storize_archive',
    AccountStatus status = AccountStatus.active,
    DateTime? lastSuccessAt,
  }) => accounts.upsert(
    LoginAccount(
      id: LoginAccount.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: 'ds-$username',
      username: username,
      status: status,
      connectedAt: rigNow.subtract(const Duration(days: 3)),
      lastSuccessAt: lastSuccessAt,
    ),
  );
}

/// Pumps [SettingsPage] inside a router so navigation rows can be tapped.
/// Destinations are stand-ins that show their route in text.
Future<GoRouter> pumpSettings(
  WidgetTester tester,
  SettingsRig rig, {
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 1400),
  SettingsSection? section,
  List<Override> extra = const [],
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.settingsPath,
    routes: [
      GoRoute(
        path: Routes.settingsPath,
        builder: (_, _) => SettingsPage(section: section),
      ),
      GoRoute(
        path: Routes.accountPath,
        builder: (_, _) => const Scaffold(body: Text('S-13 account')),
      ),
      GoRoute(
        path: Routes.setupPath,
        builder: (_, _) => const Scaffold(body: Text('S-03 setup')),
      ),
      GoRoute(
        path: Routes.loginPath,
        builder: (_, _) => const Scaffold(body: Text('S-02 login')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...rig.overrides, ...extra],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: brightness == Brightness.light
            ? StorizeTheme.light()
            : StorizeTheme.dark(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The settings written by the last `apply` call, or null.
({int storyMin, int postMin, bool wifiOnly})? lastApply(SettingsRig rig) =>
    rig.scheduler.applyCalls.isEmpty ? null : rig.scheduler.applyCalls.last;
