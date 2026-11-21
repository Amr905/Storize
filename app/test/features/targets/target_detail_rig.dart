import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/targets/target_detail_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../library/library_rig.dart' show fakeThumb;
import 'targets_rig.dart' show FakeCheckNow;

/// "Now" in every S-09 test: 2026-11-21 12:00 UTC.
final DateTime detailNow = DateTime.utc(2026, 11, 21, 12);

/// Fakes and seed helpers for S-09 and S-10 tests.
class DetailRig {
  DetailRig() {
    cache = FakeMediaCache();
    gallery = FakeGalleryStore(cache: cache);
    content = FakeContentRepo(targets: targets);
  }

  final FakeTargetRepo targets = FakeTargetRepo();
  late final FakeContentRepo content;
  late final FakeMediaCache cache;
  late final FakeGalleryStore gallery;
  final FakeClock clock = FakeClock(detailNow);
  final FakeAccountRepo accounts = FakeAccountRepo();
  final FakeStorageInfo storage = FakeStorageInfo();
  final FakeCheckNow checkNow = FakeCheckNow();
  int _seq = 0;

  /// Adds a target. Defaults: Own/client, every track on, active.
  Future<Target> addTarget(
    String username, {
    TargetStatus status = TargetStatus.active,
    TargetCategory category = TargetCategory.ownClient,
    String? displayName,
    String? note,
    String? statusReason,
    bool trackStories = true,
    bool trackPosts = true,
    bool trackReels = true,
    DateTime? lastStoriesCheckAt,
    DateTime? lastNewStoryAt,
    DateTime? lastNewPostAt,
  }) => targets.insert(
    Target(
      id: Target.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: 'uid-$username',
      username: username,
      displayName: displayName,
      category: category,
      note: note,
      status: status,
      statusReason: statusReason,
      trackStories: trackStories,
      trackPosts: trackPosts,
      trackReels: trackReels,
      postsWatermarkAt: DateTime.utc(2026),
      addedAt: DateTime.utc(2026),
      lastStoriesCheckAt: lastStoriesCheckAt?.toUtc(),
      lastNewStoryAt: lastNewStoryAt?.toUtc(),
      lastNewPostAt: lastNewPostAt?.toUtc(),
    ),
  );

  /// Stores one downloaded story or post of [target]. Each file is 1 MiB.
  Future<int> addContent(
    Target target, {
    ContentKind kind = ContentKind.story,
  }) async {
    _seq++;
    final isPost = kind == ContentKind.post;
    final result = await content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: target.id,
        kind: kind,
        remoteId: 'r$_seq',
        shortcode: isPost ? 's$_seq' : null,
        postType: isPost ? PostType.photo : null,
        postedAt: detailNow.subtract(Duration(hours: _seq)),
        detectedAt: detailNow.subtract(Duration(hours: _seq)),
        slideCount: 1,
        status: ContentStatus.done,
      ),
      [
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: 0,
          mediaType: MediaType.photo,
          sourceUrl: 'https://example.invalid/$_seq/0',
          status: MediaFileStatus.done,
          contentUri: 'content://fake/$_seq/0',
          thumbPath: '/thumbs/$_seq-0.webp',
          sizeBytes: 1024 * 1024,
        ),
      ],
    );
    return result.contentId;
  }

  /// Stores the logged-in account with [status].
  Future<void> addAccount({
    AccountStatus status = AccountStatus.active,
    String username = 'loginacc',
  }) => accounts.upsert(
    LoginAccount(
      id: LoginAccount.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: 'login-uid',
      username: username,
      status: status,
      connectedAt: DateTime.utc(2026),
    ),
  );

  List<Override> get overrides => [
    targetRepoProvider.overrideWithValue(targets),
    contentRepoProvider.overrideWithValue(content),
    accountRepoProvider.overrideWithValue(accounts),
    galleryStoreProvider.overrideWithValue(gallery),
    mediaCacheProvider.overrideWithValue(cache),
    clockProvider.overrideWithValue(clock),
    storageInfoProvider.overrideWithValue(storage),
    checkNowActionProvider.overrideWithValue(checkNow),
    libraryThumbBuilderProvider.overrideWithValue(fakeThumb),
  ];
}

/// Pumps S-09 for [targetId] inside a router. `/targets` shows a stub S-07 and
/// `/library` a stub S-04, so pops and pushes work.
Future<GoRouter> pumpDetail(
  WidgetTester tester, {
  required DetailRig rig,
  required int targetId,
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 900),
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.targetDetailLocation(targetId),
    routes: [
      GoRoute(
        path: Routes.targetsPath,
        builder: (_, _) => const Scaffold(body: Text('S-07 stub')),
      ),
      GoRoute(
        path: '/targets/:targetId',
        builder: (_, state) => TargetDetailPage(
          targetId: int.parse(state.pathParameters['targetId']!),
        ),
      ),
      GoRoute(
        path: Routes.libraryPath,
        builder: (_, _) => const Scaffold(body: Text('S-04 stub')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: rig.overrides,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return router;
}
