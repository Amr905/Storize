import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/preview/preview_page.dart';
import 'package:storize_app/features/preview/preview_providers.dart';
import 'package:storize_app/features/targets/add_target_page.dart';
import 'package:storize_app/features/targets/target_detail_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../library/library_rig.dart' show fakeThumb;

final DateTime previewNow = DateTime.utc(2026, 11, 25, 12);

/// A platform that forwards to [inner] and can hold `resolveUser` open.
final class GatedPlatform implements ContentPlatform {
  GatedPlatform(this.inner);

  final FakeContentPlatform inner;

  /// When set, `resolveUser` waits for it.
  Completer<void>? resolveGate;

  @override
  PlatformId get id => inner.id;

  @override
  Future<Result<RemoteUser>> resolveUser(String username) async {
    await resolveGate?.future;
    return inner.resolveUser(username);
  }

  @override
  Future<Result<RemoteUser>> refreshUser(String a, String b) =>
      inner.refreshUser(a, b);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds, {
    required ExtractionPolicy policy,
  }) => inner.fetchStories(userIds, policy: policy);

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark, {
    required ExtractionPolicy policy,
  }) => inner.fetchNewPosts(userId, watermark, policy: policy);

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) =>
      inner.latestPostTime(userId);

  @override
  Future<Result<PostPage>> fetchPostPage(
    String userId, {
    required ExtractionPolicy policy,
    String? cursor,
  }) => inner.fetchPostPage(userId, policy: policy, cursor: cursor);

  @override
  Future<Result<List<RemoteHighlight>>> fetchHighlights(
    String userId, {
    required ExtractionPolicy policy,
  }) => inner.fetchHighlights(userId, policy: policy);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchHighlightItems(
    List<String> highlightIds, {
    required ExtractionPolicy policy,
  }) => inner.fetchHighlightItems(highlightIds, policy: policy);

  @override
  Future<Result<RemoteUser>> verifySession() => inner.verifySession();

  @override
  Stream<List<int>> openMedia(String url, {int fromByte = 0}) =>
      inner.openMedia(url, fromByte: fromByte);
}

RemoteContent remote(
  String id, {
  ContentKind kind = ContentKind.post,
  int slides = 1,
  MediaType type = MediaType.photo,
}) => RemoteContent(
  remoteId: id,
  kind: kind,
  postType: kind == ContentKind.post
      ? (slides > 1
            ? PostType.carousel
            : (type == MediaType.video ? PostType.video : PostType.photo))
      : null,
  shortcode: kind == ContentKind.post ? 'c$id' : null,
  postedAt: previewNow,
  slides: [
    for (var i = 0; i < slides; i++)
      RemoteMedia(
        index: i,
        type: type,
        url: 'https://cdn.example.test/$id/$i',
        width: 10,
        height: 10,
      ),
  ],
);

RemoteUser previewUser({
  String username = 'zed',
  String? displayName = 'Zed Example',
  bool isPrivate = false,
}) => RemoteUser(
  remoteUserId: 'uid-$username',
  username: username,
  displayName: displayName,
  isPrivate: isPrivate,
  followedByViewer: true,
  blockedByViewer: false,
);

String _dn({
  required String username,
  required DateTime postedAt,
  required String remoteId,
  required String ext,
  int? slideIndex,
}) => '${username}_$remoteId${slideIndex == null ? '' : '_$slideIndex'}.$ext';

/// The preview use cases over in-memory fakes.
class PreviewRig {
  PreviewRig() : clock = FakeClock(previewNow) {
    content = FakeContentRepo(targets: targets);
    cache = FakeMediaCache();
    gallery = FakeGalleryStore(cache: cache);
    platform = GatedPlatform(fake);
    previewProfile = PreviewProfile(
      platform: platform,
      log: log,
      onFinished: () async => closed++,
    );
    savePreview = SavePreviewItems(
      targets: targets,
      content: content,
      downloads: DownloadPending(
        content: content,
        targets: targets,
        activity: FakeActivityRepo(clock),
        platform: platform,
        cache: cache,
        gallery: gallery,
        storage: FakeStorageInfo(),
        clock: clock,
        leases: FakeGovernorLeaseRepo(clock),
        displayName: _dn,
        relativeDir: (u) => 'Pictures/Storize/$u',
      ),
      platform: platform,
      clock: clock,
      log: log,
    );
  }

  final FakeClock clock;
  final FakeTargetRepo targets = FakeTargetRepo();
  final FakeAccountRepo accounts = FakeAccountRepo();
  final FakeScheduler scheduler = FakeScheduler();
  final FakeContentPlatform fake = FakeContentPlatform();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  late final FakeContentRepo content;
  late final FakeMediaCache cache;
  late final FakeGalleryStore gallery;
  late final GatedPlatform platform;
  late final PreviewProfile previewProfile;
  late final SavePreviewItems savePreview;

  /// How many times the in-page session was closed.
  int closed = 0;

  /// Scripts a full successful load for [username].
  void script({
    String username = 'zed',
    bool isPrivate = false,
    List<RemoteContent>? stories,
    List<RemoteContent>? posts,
  }) {
    final user = previewUser(username: username, isPrivate: isPrivate);
    fake.resolveUserResults.add(Ok(user));
    fake.fetchStoriesResults.add(
      Ok({
        user.remoteUserId:
            stories ??
            [
              remote('s1', kind: ContentKind.story, type: MediaType.video),
              remote('s2', kind: ContentKind.story),
            ],
      }),
    );
    fake.fetchPostPageResults.add(
      Ok(
        PostPage(
          items:
              posts ??
              [
                remote('p1'),
                remote('p2', slides: 3),
                remote('p3', type: MediaType.video),
              ],
        ),
      ),
    );
  }

  Future<Target> addTarget(String username) => targets.insert(
    Target(
      id: Target.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: 'uid-$username',
      username: username,
      category: TargetCategory.public,
      postsWatermarkAt: DateTime.utc(2026),
      addedAt: DateTime.utc(2026),
    ),
  );

  Future<void> addAccount() => accounts.upsert(
    LoginAccount(
      id: LoginAccount.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: 'login-uid',
      username: 'loginacc',
      status: AccountStatus.active,
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
    contentPlatformProvider.overrideWithValue(platform),
    schedulerProvider.overrideWithValue(scheduler),
    previewProfileProvider.overrideWithValue(previewProfile),
    savePreviewItemsProvider.overrideWithValue(savePreview),
    checkNowActionProvider.overrideWithValue(const StubCheckNowAction()),
    storageInfoProvider.overrideWithValue(FakeStorageInfo()),
    libraryThumbBuilderProvider.overrideWithValue(fakeThumb),
  ];
}

/// Lets real async work (fakes, streams, file copies) finish.
Future<void> settleAsync(WidgetTester t, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps a router: [initial] picks the screen (`/targets/add` is S-08,
/// `/targets/:id` is S-09, `/` a stub). With [open] the preview is pushed
/// above it, the way the app does (a `Navigator` push).
Future<GoRouter> pumpPreview(
  WidgetTester tester, {
  required PreviewRig rig,
  String initial = '/',
  PreviewArgs? open = const PreviewArgs(username: 'zed'),
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 900),
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home stub')),
      ),
      GoRoute(
        path: Routes.addTargetPath,
        builder: (_, _) => const AddTargetPage(),
      ),
      GoRoute(
        path: '/targets/:targetId',
        builder: (_, state) => TargetDetailPage(
          targetId: int.parse(state.pathParameters['targetId']!),
        ),
      ),
      GoRoute(
        path: Routes.targetsPath,
        builder: (_, _) => const Scaffold(body: Text('S-07 stub')),
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
  await tester.pump();
  if (open != null) {
    unawaited(
      PreviewPage.open(
        router.routerDelegate.navigatorKey.currentContext!,
        open,
      ),
    );
  }
  if (settle) {
    await settleAsync(tester);
  } else {
    await tester.pump();
  }
  return router;
}
