import 'package:meta/meta.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/ports/gallery_store.dart';
import 'package:storize_domain/src/ports/media_cache.dart';
import 'package:storize_domain/src/repos/content_repo.dart';

/// The outcome of [RemoveMediaFile]. Never contains paths or URIs.
@immutable
final class RemoveMediaFileResult {
  /// Creates a result.
  const RemoveMediaFileResult({
    required this.removed,
    this.contentDeleted = false,
    this.notFound = false,
    this.error,
  });

  /// True when the media row is gone.
  final bool removed;

  /// True when it was the last slide, so the content row was removed too.
  final bool contentDeleted;

  /// True when there was no such media row.
  final bool notFound;

  /// Why the gallery file could not be deleted (the row is kept), or null.
  final GalleryStoreException? error;

  @override
  String toString() =>
      'RemoveMediaFileResult(removed: $removed, '
      'contentDeleted: $contentDeleted, notFound: $notFound, error: $error)';
}

/// Removes one slide: the gallery file first, then the thumbnail, then the row
/// (EC-20). Mirrors the failure rules of `DeleteContent`: a missing gallery
/// file is ignored; a [GalleryStoreException] keeps the row.
final class RemoveMediaFile {
  /// Creates the use case.
  RemoveMediaFile({
    required this._content,
    required this._gallery,
    required this._cache,
  });

  final ContentRepo _content;
  final GalleryStore _gallery;
  final MediaCache _cache;

  /// Removes the media file with [mediaFileId] of content [contentId].
  Future<RemoveMediaFileResult> call(int contentId, int mediaFileId) async {
    final item = await _content.getById(contentId);
    final file = item?.media.where((m) => m.id == mediaFileId).firstOrNull;
    if (item == null || file == null) {
      return const RemoveMediaFileResult(removed: false, notFound: true);
    }
    final uri = file.contentUri;
    if (uri != null) {
      try {
        await _gallery.delete(uri);
      } on GalleryStoreException catch (e) {
        return RemoveMediaFileResult(removed: false, error: e);
      }
    }
    try {
      await _cache.discard(mediaFileId);
    } on Object {
      // Best effort.
    }
    try {
      await _cache.deleteThumbnail(mediaFileId);
    } on Object {
      // Best effort: cleanupOrphanThumbnails removes it later.
    }
    await _content.deleteMediaFile(mediaFileId);
    return RemoveMediaFileResult(
      removed: true,
      contentDeleted: item.media.length == 1,
    );
  }
}
