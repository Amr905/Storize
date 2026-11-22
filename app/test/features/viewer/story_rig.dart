import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_app/features/viewer/story_video_player.dart';
import 'package:storize_app/features/viewer/story_viewer_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import '../library/library_rig.dart' show RecordingShare, testNow;

/// A gallery that knows which URIs still exist. The shared fake only knows
/// files it saved itself.
class ViewerGallery implements GalleryStore {
  final Set<String> files = {};

  /// Makes the next delete fail as a write error.
  bool deleteFails = false;

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => throw UnimplementedError('not used by S-06');

  @override
  Future<bool> delete(String contentUri) async {
    if (deleteFails) throw const GalleryWriteFailed('WRITE');
    return files.remove(contentUri);
  }

  @override
  Future<bool> exists(String contentUri) async => files.contains(contentUri);

  @override
  Future<int?> size(String contentUri) async =>
      files.contains(contentUri) ? 512 * 1024 : null;
}

/// A video player that never touches the platform.
class FakeStoryPlayer implements StoryVideoPlayer {
  FakeStoryPlayer(this.contentUri);

  final String contentUri;

  /// Makes [initialize] throw.
  bool failInit = false;

  int plays = 0;
  int pauses = 0;
  bool? muted;
  Duration? seeked;
  bool disposed = false;

  final ValueNotifier<StoryVideoValue> _value = ValueNotifier(
    const StoryVideoValue(),
  );

  @override
  ValueListenable<StoryVideoValue> get value => _value;

  void _emit({bool? playing, Duration? position, bool? initialized}) {
    final v = _value.value;
    _value.value = StoryVideoValue(
      initialized: initialized ?? v.initialized,
      playing: playing ?? v.playing,
      position: position ?? v.position,
      duration: v.duration,
      aspectRatio: v.aspectRatio,
    );
  }

  @override
  Future<void> initialize() async {
    if (failInit) throw Exception('cannot open');
    _value.value = const StoryVideoValue(
      initialized: true,
      duration: Duration(seconds: 12),
    );
  }

  @override
  Future<void> play() async {
    plays++;
    _emit(playing: true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    _emit(playing: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    seeked = position;
    _emit(position: position);
  }

  @override
  Future<void> setMuted(bool muted) async => this.muted = muted;

  @override
  Widget buildSurface(BuildContext context) =>
      fakeMedia(const Color(0xFF335577), const Color(0xFF112233));

  @override
  Future<void> dispose() async {
    disposed = true;
    _value.dispose();
  }
}

/// Seeds stories and wires every S-06 port to a fake.
class StoryRig {
  StoryRig() {
    content = FakeContentRepo(targets: targets);
  }

  final FakeTargetRepo targets = FakeTargetRepo();
  late final FakeContentRepo content;
  final FakeMediaCache cache = FakeMediaCache();
  final ViewerGallery gallery = ViewerGallery();
  final FakeClock clock = FakeClock(testNow);
  final RecordingShare share = RecordingShare();
  final List<FakeStoryPlayer> players = [];

  /// Makes every video fail to open.
  bool failVideoInit = false;

  int _seq = 0;

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

  /// Adds a story. [inGallery] puts its file in the fake gallery.
  Future<int> addStory(
    Target target, {
    required DateTime postedAt,
    MediaType type = MediaType.photo,
    bool inGallery = true,
    Map<String, Object?> extras = const {},
    int? durationMs,
    bool viewed = false,
  }) async {
    _seq++;
    final uri = 'content://viewer/$_seq';
    if (inGallery) gallery.files.add(uri);
    final result = await content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: target.id,
        kind: ContentKind.story,
        remoteId: 'item-$_seq',
        slideCount: 1,
        postedAt: postedAt.toUtc(),
        detectedAt: postedAt.toUtc(),
        extras: extras,
        viewed: viewed,
        status: ContentStatus.done,
      ),
      [
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: 0,
          mediaType: type,
          sourceUrl: 'https://example.invalid/$_seq',
          status: MediaFileStatus.done,
          contentUri: uri,
          relativePath: 'Pictures/Storize/${target.username}/',
          displayName: 'item-$_seq',
          thumbPath: '/thumbs/$_seq-0.webp',
          durationMs: durationMs,
          sizeBytes: 512 * 1024,
          downloadedAt: postedAt.add(const Duration(minutes: 5)).toUtc(),
        ),
      ],
    );
    return result.contentId;
  }

  /// Overrides for a [ProviderScope].
  List<Override> get overrides => [
    targetRepoProvider.overrideWithValue(targets),
    contentRepoProvider.overrideWithValue(content),
    galleryStoreProvider.overrideWithValue(gallery),
    mediaCacheProvider.overrideWithValue(cache),
    clockProvider.overrideWithValue(clock),
    shareServiceProvider.overrideWithValue(share),
    storyPhotoBuilderProvider.overrideWithValue(
      (context, media) =>
          fakeMedia(const Color(0xFFE0854F), const Color(0xFFB8400F)),
    ),
    storyVideoPlayerFactoryProvider.overrideWithValue((uri) {
      final p = FakeStoryPlayer(uri)..failInit = failVideoInit;
      players.add(p);
      return p;
    }),
  ];
}

/// Pumps the S-06 page at [contentId] inside a router with a Library
/// placeholder, so close and "no stories left" have a destination.
Future<void> pumpStoryViewer(
  WidgetTester t,
  StoryRig rig, {
  required int contentId,
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 800),
  List<Override> extra = const [],
}) async {
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(t.view.reset);
  final router = GoRouter(
    initialLocation: Routes.storyLocation(contentId),
    routes: [
      GoRoute(
        path: Routes.libraryPath,
        builder: (_, _) => const Scaffold(body: Text('LIBRARY')),
      ),
      GoRoute(
        path: '/story/:contentId',
        builder: (_, state) => StoryViewerPage(
          contentId: int.parse(state.pathParameters['contentId']!),
        ),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [...rig.overrides, ...extra],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: brightness == Brightness.light
            ? StorizeTheme.light()
            : StorizeTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await t.pumpAndSettle();
}
