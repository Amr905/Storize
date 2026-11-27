import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/viewer/post_viewer_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../library/library_rig.dart' show testNow;
import 'story_rig.dart';

/// One slide to seed. Downloaded slides get a gallery URI; [inGallery] false
/// makes the file disappear (EC-20). [status] other than done is EC-21.
class SlideSpec {
  const SlideSpec(
    this.type, {
    this.inGallery = true,
    this.status = MediaFileStatus.done,
  });

  final MediaType type;
  final bool inGallery;
  final MediaFileStatus status;
}

int _postSeq = 1000;

/// Seeds a post with [slides] for [target] and returns its content id.
Future<int> addPost(
  StoryRig rig,
  Target target, {
  required List<SlideSpec> slides,
  PostType? postType,
  String? caption,
  String? locationName,
  List<String> taggedUsernames = const [],
  String? shortcode = 'ABC123',
  DateTime? postedAt,
}) async {
  final seq = ++_postSeq;
  final media = <MediaFile>[];
  for (var i = 0; i < slides.length; i++) {
    final s = slides[i];
    final done = s.status == MediaFileStatus.done;
    final uri = done ? 'content://post/$seq/$i' : null;
    if (done && s.inGallery && uri != null) rig.gallery.files.add(uri);
    media.add(
      MediaFile(
        id: MediaFile.unsavedId,
        contentId: MediaFile.unsavedContentId,
        slideIndex: i,
        mediaType: s.type,
        sourceUrl: 'https://example.invalid/post/$seq/$i',
        status: s.status,
        contentUri: uri,
        relativePath: 'Pictures/Storize/${target.username}/',
        displayName: 'post-$seq-$i',
        thumbPath: done ? '/thumbs/post-$seq-$i.webp' : null,
        durationMs: s.type == MediaType.video ? 12000 : null,
        sizeBytes: 512 * 1024,
        downloadedAt: done ? testNow : null,
      ),
    );
  }
  final result = await rig.content.insertIfNew(
    Content(
      id: Content.unsavedId,
      targetId: target.id,
      kind: ContentKind.post,
      remoteId: 'post-$seq',
      shortcode: shortcode,
      postType: postType,
      caption: caption,
      locationName: locationName,
      taggedUsernames: taggedUsernames,
      slideCount: slides.length,
      postedAt: (postedAt ?? testNow.subtract(const Duration(hours: 3)))
          .toUtc(),
      detectedAt: testNow,
      status: ContentStatus.done,
    ),
    media,
  );
  return result.contentId;
}

/// Pumps S-15 at [contentId] inside a router with a Library placeholder.
Future<void> pumpPostViewer(
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
    initialLocation: Routes.postLocation(contentId),
    routes: [
      GoRoute(
        path: Routes.libraryPath,
        builder: (_, _) => const Scaffold(body: Text('LIBRARY')),
      ),
      GoRoute(
        path: '/post/:contentId',
        builder: (_, state) => PostViewerPage(
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
