import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_page.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

/// "Now" in every library test: 2026-11-20 12:00 local time.
final DateTime testNow = DateTime(2026, 11, 20, 12).toUtc();

/// Fakes, seed helpers and overrides for the library tests.
class LibraryRig {
  LibraryRig() {
    cache = FakeMediaCache();
    gallery = FakeGalleryStore(cache: cache);
    content = FakeContentRepo(targets: targets);
  }

  final FakeTargetRepo targets = FakeTargetRepo();
  late final FakeContentRepo content;
  late final FakeMediaCache cache;
  late final FakeGalleryStore gallery;
  final FakeClock clock = FakeClock(testNow);
  final FakeAccountRepo accounts = FakeAccountRepo();
  final RecordingShare share = RecordingShare();
  final CountingCheckNow checkNow = CountingCheckNow();

  final Map<String, Target> byName = {};

  Future<Target> addTarget(
    String username, {
    DateTime? lastStoriesCheckAt,
    DateTime? lastPostsCheckAt,
  }) async => byName[username] = await targets.insert(
    Target(
      id: Target.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: 'uid-$username',
      username: username,
      category: TargetCategory.ownClient,
      postsWatermarkAt: DateTime.utc(2026),
      addedAt: DateTime.utc(2026),
      lastStoriesCheckAt: lastStoriesCheckAt,
      lastPostsCheckAt: lastPostsCheckAt,
    ),
  );

  int _seq = 0;

  /// Local time [postedAt] in hours-ago form keeps goldens stable.
  Future<int> addContent(
    Target target, {
    required DateTime postedAt,
    ContentKind kind = ContentKind.story,
    bool viewed = false,
    PostType? postType,
    int slideCount = 1,
    MediaType mediaType = MediaType.photo,
    int? durationMs,
    MediaFileStatus status = MediaFileStatus.done,
    bool withUri = true,
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
        postType: isPost ? (postType ?? PostType.photo) : null,
        postedAt: postedAt.toUtc(),
        slideCount: slideCount,
        detectedAt: postedAt.toUtc(),
        viewed: viewed,
        status: ContentStatus.done,
      ),
      [
        for (var i = 0; i < slideCount; i++)
          MediaFile(
            id: MediaFile.unsavedId,
            contentId: MediaFile.unsavedContentId,
            slideIndex: i,
            mediaType: mediaType,
            sourceUrl: 'https://example.invalid/$_seq/$i',
            status: status,
            contentUri: withUri ? 'content://fake/$_seq/$i' : null,
            thumbPath: '/thumbs/$_seq-$i.webp',
            durationMs: durationMs,
          ),
      ],
    );
    return result.contentId;
  }

  /// Leaves the content repo unwired (it throws when read).
  bool unwiredContent = false;

  List<Override> get overrides => [
    targetRepoProvider.overrideWithValue(targets),
    if (!unwiredContent) contentRepoProvider.overrideWithValue(content),
    accountRepoProvider.overrideWithValue(accounts),
    galleryStoreProvider.overrideWithValue(gallery),
    mediaCacheProvider.overrideWithValue(cache),
    clockProvider.overrideWithValue(clock),
    shareServiceProvider.overrideWithValue(share),
    checkNowActionProvider.overrideWithValue(checkNow),
    libraryThumbBuilderProvider.overrideWithValue(fakeThumb),
  ];
}

/// A cheap stand-in for decoding an image: a gradient picked from the path.
Widget fakeThumb(BuildContext context, String path, int cacheWidth) {
  final h = path.hashCode;
  final a = HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.55, 0.62).toColor();
  final b = HSLColor.fromAHSL(
    1,
    ((h ~/ 7) % 360).toDouble(),
    0.6,
    0.42,
  ).toColor();
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [a, b],
      ),
    ),
  );
}

class RecordingShare implements ShareService {
  final List<List<ShareFile>> calls = [];
  Exception? error;

  @override
  Future<void> share(List<ShareFile> files) async {
    if (error != null) throw error!;
    calls.add(files);
  }
}

class CountingCheckNow implements CheckNowAction {
  int calls = 0;
  CheckNowResult result = const CheckNowResult(newItems: 2);
  Future<CheckNowResult> Function()? gate;

  @override
  Future<CheckNowResult> call({int? targetId}) async {
    calls++;
    return gate != null ? gate!() : result;
  }
}

/// Pumps [LibraryPage] in a router so taps can navigate.
Future<ProviderContainer> pumpLibrary(
  WidgetTester tester,
  LibraryRig rig, {
  Brightness brightness = Brightness.light,
  TextDirection? direction,
  Size size = const Size(400, 2400),
  List<Override> extra = const [],
  ContentKind? kind,
  int? targetId,
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => LibraryPage(kind: kind, targetId: targetId),
      ),
      GoRoute(
        path: '/story/:id',
        builder: (_, s) =>
            Scaffold(body: Text('story ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (_, s) =>
            Scaffold(body: Text('post ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/targets/add',
        builder: (_, _) => const Scaffold(body: Text('add target')),
      ),
      GoRoute(
        path: '/account',
        builder: (_, _) => const Scaffold(body: Text('account')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final scope = ProviderScope(
    overrides: [...rig.overrides, ...extra],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: brightness == Brightness.light
          ? StorizeTheme.light()
          : StorizeTheme.dark(),
      builder: direction == null
          ? null
          : (context, c) => Directionality(textDirection: direction, child: c!),
    ),
  );
  await tester.pumpWidget(scope);
  if (settle) await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(LibraryPage)));
}

/// A standard data set: three accounts, stories and posts over two days.
Future<void> seedStandard(LibraryRig rig) async {
  final nour = await rig.addTarget(
    'nour_k',
    lastStoriesCheckAt: DateTime(2026, 11, 20, 10, 42).toUtc(),
  );
  final brandx = await rig.addTarget('brandx');
  final client = await rig.addTarget('client_co');
  DateTime at(int day, int h, [int m = 0]) => DateTime(2026, 11, day, h, m);
  await rig.addContent(nour, postedAt: at(20, 10, 15));
  await rig.addContent(
    nour,
    postedAt: at(20, 9, 30),
    mediaType: MediaType.video,
    durationMs: 12000,
  );
  await rig.addContent(nour, postedAt: at(20, 8, 5));
  await rig.addContent(brandx, postedAt: at(20, 7, 40), viewed: true);
  await rig.addContent(
    brandx,
    postedAt: at(20, 7, 10),
    viewed: true,
    mediaType: MediaType.video,
    durationMs: 8000,
  );
  await rig.addContent(brandx, postedAt: at(20, 6), viewed: true);
  await rig.addContent(client, postedAt: at(19, 18, 20), viewed: true);
  await rig.addContent(client, postedAt: at(19, 17, 45), viewed: true);
  await rig.addContent(
    client,
    postedAt: at(19, 12),
    viewed: true,
    mediaType: MediaType.video,
    durationMs: 21000,
  );
  // Posts.
  await rig.addContent(
    nour,
    kind: ContentKind.post,
    postedAt: at(20, 11),
    postType: PostType.carousel,
    slideCount: 4,
  );
  await rig.addContent(
    brandx,
    kind: ContentKind.post,
    postedAt: at(20, 9),
    postType: PostType.reel,
    mediaType: MediaType.video,
    durationMs: 15000,
    viewed: true,
  );
  await rig.addContent(
    brandx,
    kind: ContentKind.post,
    postedAt: at(19, 20),
    viewed: true,
  );
  await rig.addContent(
    client,
    kind: ContentKind.post,
    postedAt: at(19, 9),
    postType: PostType.video,
    mediaType: MediaType.video,
    durationMs: 33000,
  );
}

/// Pulls the list down far enough to trigger the refresh indicator.
Future<void> pullToRefresh(WidgetTester tester) async {
  final g = await tester.startGesture(const Offset(200, 400));
  for (var i = 0; i < 10; i++) {
    await g.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
