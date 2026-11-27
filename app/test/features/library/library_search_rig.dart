import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'library_rig.dart';

/// Seed for the FR-76 search tests. Captions and locations are set here
/// (the standard seed has none). Kind switch starts on Stories.
///
/// Posts (4): nour_k carousel "Sunset at the beach" (Alexandria), nour_k reel
/// "Beach day reel", brandx photo "Coffee morning" (Cairo), client_co video
/// "Sunset timelapse". Stories (2): nour_k and brandx.
Future<void> seedSearch(LibraryRig rig) async {
  final nour = await rig.addTarget('nour_k');
  final brandx = await rig.addTarget('brandx');
  final client = await rig.addTarget('client_co');
  var n = 0;
  Future<void> put(
    Target t, {
    required DateTime postedAt,
    ContentKind kind = ContentKind.story,
    PostType? postType,
    MediaType media = MediaType.photo,
    String? caption,
    String? location,
  }) async {
    n++;
    await rig.content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: t.id,
        kind: kind,
        remoteId: 'r$n',
        postType: kind == ContentKind.post
            ? (postType ?? PostType.photo)
            : null,
        postedAt: postedAt.toUtc(),
        slideCount: 1,
        detectedAt: postedAt.toUtc(),
        status: ContentStatus.done,
        caption: caption,
        locationName: location,
      ),
      [
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: 0,
          mediaType: media,
          sourceUrl: 'https://example.invalid/$n',
          status: MediaFileStatus.done,
          contentUri: 'content://fake/$n',
          thumbPath: '/thumbs/$n-0.webp',
        ),
      ],
    );
  }

  DateTime at(int day, int h, [int m = 0]) => DateTime(2026, 11, day, h, m);
  await put(nour, postedAt: at(20, 10, 15));
  await put(brandx, postedAt: at(20, 7, 40));
  await put(
    nour,
    kind: ContentKind.post,
    postType: PostType.carousel,
    postedAt: at(20, 11),
    caption: 'Sunset at the beach',
    location: 'Alexandria',
  );
  await put(
    nour,
    kind: ContentKind.post,
    postType: PostType.reel,
    postedAt: at(20, 9),
    media: MediaType.video,
    caption: 'Beach day reel',
  );
  await put(
    brandx,
    kind: ContentKind.post,
    postedAt: at(19, 12),
    caption: 'Coffee morning',
    location: 'Cairo',
  );
  await put(
    client,
    kind: ContentKind.post,
    postedAt: at(19, 18, 20),
    media: MediaType.video,
    caption: 'Sunset timelapse',
  );
}
