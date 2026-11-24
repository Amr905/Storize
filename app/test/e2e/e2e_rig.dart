import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/onboarding/login_web_view.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../features/library/library_rig.dart' show RecordingShare, fakeThumb;
import '../features/onboarding/onboarding_rig.dart'
    show FakeLease, FakeSetupOps, FakeWeb;
import '../features/viewer/story_rig.dart' show FakeStoryPlayer;
import '../helpers/app_harness.dart';
import '../ui/golden_helpers.dart' show fakeMedia;

/// The fixed "now" of every end-to-end flow.
final DateTime e2eNow = DateTime.utc(2026, 11, 21, 12);

/// Everything the end-to-end flows need: the real use cases over the
/// in-memory fakes of `package:storize_domain/testing.dart`.
///
/// No Android device, no network and no real WebView are involved, so the same
/// flows run under `flutter test` and under `integration_test`.
class E2eRig {
  E2eRig({bool firstRun = false})
    : settings = FakeSettingsRepo(AppSettings(onboardingDone: !firstRun)),
      firstRun = firstRun {
    content = FakeContentRepo(targets: targets);
    activity = FakeActivityRepo(clock);
    gallery = FakeGalleryStore(cache: cache);
  }

  /// True when the app starts on S-01.
  final bool firstRun;

  final FakeClock clock = FakeClock(e2eNow);
  final FakeSettingsRepo settings;
  final FakeTargetRepo targets = FakeTargetRepo();
  late final FakeContentRepo content;
  final FakeAccountRepo accounts = FakeAccountRepo();
  late final FakeActivityRepo activity;
  final FakeCheckRunRepo checkRuns = FakeCheckRunRepo();
  late final FakeGovernorLeaseRepo leases = FakeGovernorLeaseRepo(clock);
  final FakeContentPlatform platform = FakeContentPlatform();
  final FakeScheduler scheduler = FakeScheduler();
  final FakeMediaCache cache = FakeMediaCache();
  late final FakeGalleryStore gallery;
  final FakeSessionStore sessions = FakeSessionStore();
  final FakeStorageInfo storage = FakeStorageInfo();
  final RecordingShare share = RecordingShare();
  final FakeContentSignals signals = FakeContentSignals();
  final FakeWeb web = FakeWeb();
  final FakeLease lease = FakeLease();
  final FakeSetupOps ops = FakeSetupOps();
  LoginWebViewEvents? loginEvents;

  /// The session cookies the fake login WebView holds after "login".
  static const cookies = {
    'sessionid': 'FAKE-SESSION',
    'ds_user_id': '42',
    'csrftoken': 'FAKE-CSRF',
  };

  static RemoteUser remoteUser(String name, String id) => RemoteUser(
    remoteUserId: id,
    username: name,
    followedByViewer: false,
    blockedByViewer: false,
  );

  Widget _fakeWebView(BuildContext context, LoginWebViewEvents e) {
    loginEvents = e;
    web.events = e;
    e.onReady(web);
    return const SizedBox.expand(key: ValueKey('fake-web'));
  }

  /// Stores a logged-in account and its session.
  Future<LoginAccount> addAccount() async {
    final stored = await accounts.upsert(
      LoginAccount(
        id: LoginAccount.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: '42',
        username: 'loginacc',
        status: AccountStatus.active,
        connectedAt: DateTime.utc(2026),
      ),
    );
    await sessions.save(
      stored.id,
      SessionBlob(
        cookies: const {'sessionid': 'x', 'ds_user_id': '42'},
        userAgent: 'ua',
        capturedAt: e2eNow,
      ),
    );
    return stored;
  }

  /// Stores an active target.
  Future<Target> addTarget(String username) => targets.insert(
    Target(
      id: Target.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: 'uid-$username',
      username: username,
      category: TargetCategory.ownClient,
      postsWatermarkAt: DateTime.utc(2026, 11, 20),
      addedAt: DateTime.utc(2026, 11, 20),
    ),
  );

  /// One photo story and one two-slide carousel post, as the platform sees
  /// them, for [target].
  void scriptRemoteContent(Target target) {
    RemoteMedia photo(int i) => RemoteMedia(
      index: i,
      type: MediaType.photo,
      url: 'https://example.invalid/${target.username}/$i',
      width: 1080,
      height: 1920,
    );
    platform
      ..fetchStoriesResults.addOk({
        target.remoteUserId: [
          RemoteContent(
            remoteId: 'story-1',
            kind: ContentKind.story,
            postedAt: e2eNow.subtract(const Duration(hours: 1)),
            expiresAt: e2eNow.add(const Duration(hours: 23)),
            slides: [photo(0)],
          ),
        ],
      })
      ..fetchNewPostsResults.addOk([
        RemoteContent(
          remoteId: 'post-1',
          kind: ContentKind.post,
          shortcode: 'ABC123',
          postType: PostType.carousel,
          postedAt: e2eNow.subtract(const Duration(minutes: 30)),
          caption: 'fixture caption',
          slides: [photo(0), photo(1)],
        ),
      ]);
    // One queued download per file: 1 story slide + 2 post slides.
    for (var i = 0; i < 3; i++) {
      platform.queueMedia(List<int>.generate(2048, (n) => n % 251));
    }
  }

  /// A [TaskRouter] over the real [RunCheck] and [DownloadPending].
  TaskRouter get router {
    final runCheck = RunCheck(
      platform: platform,
      signals: signals,
      targets: targets,
      content: content,
      accounts: accounts,
      checkRuns: checkRuns,
      activity: activity,
      settings: settings,
      clock: clock,
    );
    final download = DownloadPending(
      content: content,
      targets: targets,
      activity: activity,
      platform: platform,
      cache: cache,
      gallery: gallery,
      storage: storage,
      clock: clock,
      leases: leases,
      displayName: ({
        required username,
        required postedAt,
        required remoteId,
        required ext,
        slideIndex,
      }) => '$username-$remoteId${slideIndex ?? ''}.$ext',
      relativeDir: (username) => 'Pictures/Storize/$username/',
    );
    return TaskRouter(
      runCheck: runCheck.call,
      download: download.run,
      retention: () async => null,
      updateCheck: () async => null,
      settings: settings,
      clock: clock,
      enqueuer: _NoEnqueuer(),
      log: FakeDiagnosticLog(),
    );
  }

  /// Runs the stories check and the posts check the way the background worker
  /// does. Call inside `tester.runAsync`.
  Future<void> runChecks() async {
    final r = router;
    expect(await r.route(TaskNames.checkStories), isTrue);
    expect(await r.route(TaskNames.checkPosts), isTrue);
  }

  List<Override> get overrides => [
    settingsRepoProvider.overrideWithValue(settings),
    targetRepoProvider.overrideWithValue(targets),
    contentRepoProvider.overrideWithValue(content),
    activityRepoProvider.overrideWithValue(activity),
    checkRunRepoProvider.overrideWithValue(checkRuns),
    governorLeaseRepoProvider.overrideWithValue(leases),
    contentPlatformProvider.overrideWithValue(platform),
    loginPlatformProvider.overrideWithValue(platform),
    schedulerProvider.overrideWithValue(scheduler),
    clockProvider.overrideWithValue(clock),
    galleryStoreProvider.overrideWithValue(gallery),
    mediaCacheProvider.overrideWithValue(cache),
    storageInfoProvider.overrideWithValue(storage),
    sessionStoreProvider.overrideWithValue(sessions),
    shareServiceProvider.overrideWithValue(share),
    loginLeaseProvider.overrideWithValue(lease),
    loginAcquireBackoffProvider.overrideWithValue(const []),
    loginWebViewBuilderProvider.overrideWithValue(_fakeWebView),
    setupOpsProvider.overrideWithValue(ops),
    libraryThumbBuilderProvider.overrideWithValue(fakeThumb),
    storyPhotoBuilderProvider.overrideWithValue(
      (context, media) =>
          fakeMedia(const Color(0xFFE0854F), const Color(0xFFB8400F)),
    ),
    storyVideoPlayerFactoryProvider.overrideWithValue(FakeStoryPlayer.new),
    // The gate the production composition uses (first run shows S-01).
    onboardingCompleteProvider.overrideWith(
      (ref) =>
          ref.watch(setupFinishedProvider) ||
          (ref.watch(onboardingDoneProvider).value ?? true),
    ),
  ];

  /// Launches the real `StorizeApp` over this rig.
  Future<AppHarness> launch(WidgetTester t, {String? initialLocation}) async {
    t.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(t.view.reset);
    return pumpApp(
      t,
      overrides: overrides,
      accounts: accounts,
      initialLocation: initialLocation,
    );
  }
}

final class _NoEnqueuer implements DownloadEnqueuer {
  @override
  Future<void> enqueueDownload({required bool wifiOnly}) async {}

  @override
  Future<void> enqueueHistory({
    required bool wifiOnly,
    required Duration delay,
    bool fromHistoryTask = false,
  }) async {}
}
