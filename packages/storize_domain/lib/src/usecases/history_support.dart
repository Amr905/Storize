import 'package:storize_domain/src/entities/content.dart';
import 'package:storize_domain/src/entities/media_file.dart';
import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_model/storize_model.dart';

/// Stores [c] with PENDING media, like `RunCheck` does. Returns the new
/// content ID, or null when it exists already or has nothing to download.
///
/// The UNIQUE key `(target, kind, remote_id)` makes a repeat harmless.
Future<int?> insertRemote(
  ContentRepo repo,
  Target target,
  RemoteContent c,
  DateTime detectedAt,
) async {
  if (c.slides.isEmpty) return null;
  final post = c.kind == ContentKind.post;
  final result = await repo.insertIfNew(
    Content(
      id: Content.unsavedId,
      targetId: target.id,
      kind: c.kind,
      remoteId: c.remoteId,
      shortcode: post ? c.shortcode : null,
      postType: post ? c.postType : null,
      postedAt: c.postedAt.toUtc(),
      expiresAt: c.expiresAt?.toUtc(),
      caption: post ? c.caption : null,
      locationName: c.locationName,
      taggedUsernames: c.taggedUsernames,
      slideCount: c.slides.length,
      isCloseFriends: c.closeFriends,
      extras: c.extras,
      detectedAt: detectedAt,
    ),
    [
      for (final s in c.slides)
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: s.index,
          mediaType: s.type,
          sourceUrl: s.url,
          width: s.width,
          height: s.height,
          durationMs: s.duration?.inMilliseconds,
        ),
    ],
  );
  return result.isNew ? result.contentId : null;
}
