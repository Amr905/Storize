import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/content_with_media.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/ports/gallery_store.dart';
import 'package:storize_domain/src/ports/media_cache.dart';
import 'package:storize_domain/src/repos/content_repo.dart';

/// One content item that could not be deleted.
@immutable
final class DeleteFailure {
  /// Creates a failure for [contentId] caused by [error].
  const DeleteFailure(this.contentId, this.error);

  /// The content whose gallery file could not be deleted. Its rows are kept.
  final int contentId;

  /// Why: [GalleryPermissionDenied] (the file is not owned by Storize),
  /// [GalleryStorageFull] or [GalleryWriteFailed]. Carries no path or URI.
  final GalleryStoreException error;

  @override
  bool operator ==(Object other) =>
      other is DeleteFailure &&
      other.contentId == contentId &&
      other.error.code == error.code &&
      other.error.runtimeType == error.runtimeType;

  @override
  int get hashCode => Object.hash(contentId, error.code, error.runtimeType);

  @override
  String toString() => 'DeleteFailure($contentId, $error)';
}

/// The outcome of a delete batch. Never contains paths or URIs.
@immutable
final class DeleteContentResult {
  /// Creates a result. The lists are copied into unmodifiable lists.
  DeleteContentResult({
    required List<int> deletedContentIds,
    required List<DeleteFailure> failures,
    required List<int> notFoundIds,
    required this.filesDeleted,
    required this.filesMissing,
  }) : deletedContentIds = List.unmodifiable(deletedContentIds),
       failures = List.unmodifiable(failures),
       notFoundIds = List.unmodifiable(notFoundIds);

  /// Content whose gallery files are gone and whose rows were removed.
  final List<int> deletedContentIds;

  /// Content that was kept because a gallery file could not be deleted.
  final List<DeleteFailure> failures;

  /// Requested IDs that had no row (already deleted: ignored, BR-9 re-run).
  final List<int> notFoundIds;

  /// Gallery files that were deleted.
  final int filesDeleted;

  /// Gallery files that were already gone (`delete` returned false).
  final int filesMissing;

  /// True when nothing failed.
  bool get isComplete => failures.isEmpty;

  @override
  String toString() =>
      'DeleteContentResult(deleted: ${deletedContentIds.length}, '
      'failed: ${failures.length}, notFound: ${notFoundIds.length}, '
      'filesDeleted: $filesDeleted, filesMissing: $filesMissing)';
}

/// Deletes content: the gallery files first, then the rows (BR-9).
///
/// Rules:
/// - A missing gallery file (`GalleryStore.delete` returns false) is ignored
///   and the rows are still removed.
/// - When any file of an item fails with a [GalleryStoreException], the rows
///   of that item are kept and the item is reported in
///   [DeleteContentResult.failures]. The rest of the batch carries on.
/// - The part file in the [MediaCache] is discarded best-effort once the
///   gallery files are gone. A cache error never blocks the delete.
/// - Rows are removed in chunks of [chunkSize], so a crash loses at most one
///   chunk of progress. Re-running is safe: files already gone count as
///   missing and unknown IDs are ignored.
///
/// Nothing here looks at `Content.expiresAt` or the remote state (BR-4).
final class DeleteContent {
  /// Creates the use case.
  DeleteContent({
    required this._content,
    required this._gallery,
    required this._cache,
    this.chunkSize = 50,
  }) {
    if (chunkSize < 1) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be positive');
    }
  }

  /// How many items are handled before their rows are removed.
  final int chunkSize;

  final ContentRepo _content;
  final GalleryStore _gallery;
  final MediaCache _cache;

  /// Deletes the content with [contentIds] (duplicates are ignored).
  Future<DeleteContentResult> call(Iterable<int> contentIds) async {
    final ids = contentIds.toSet().toList();
    final found = <ContentWithMedia>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = i + chunkSize > ids.length ? ids.length : i + chunkSize;
      found.addAll(await _content.getByIds(ids.sublist(i, end)));
    }
    final foundIds = {for (final c in found) c.content.id};
    final result = await deleteLoaded(found);
    return DeleteContentResult(
      deletedContentIds: result.deletedContentIds,
      failures: result.failures,
      notFoundIds: [
        for (final id in ids)
          if (!foundIds.contains(id)) id,
      ],
      filesDeleted: result.filesDeleted,
      filesMissing: result.filesMissing,
    );
  }

  /// Deletes already loaded [items]. Used by `RemoveTarget` and
  /// `ApplyRetention`, which load their own lists.
  Future<DeleteContentResult> deleteLoaded(
    Iterable<ContentWithMedia> items,
  ) async {
    final list = items.toList();
    final deleted = <int>[];
    final failures = <DeleteFailure>[];
    var filesDeleted = 0;
    var filesMissing = 0;

    for (var i = 0; i < list.length; i += chunkSize) {
      final end = i + chunkSize > list.length ? list.length : i + chunkSize;
      final chunkOk = <int>[];
      for (final item in list.sublist(i, end)) {
        GalleryStoreException? firstError;
        var itemDeleted = 0;
        var itemMissing = 0;
        for (final file in item.media) {
          final uri = file.contentUri;
          if (uri == null) continue;
          try {
            if (await _gallery.delete(uri)) {
              itemDeleted++;
            } else {
              itemMissing++;
            }
          } on GalleryStoreException catch (e) {
            firstError ??= e;
          }
        }
        filesDeleted += itemDeleted;
        filesMissing += itemMissing;
        if (firstError != null) {
          failures.add(DeleteFailure(item.content.id, firstError));
          continue;
        }
        for (final file in item.media) {
          await _discardPart(file.id);
        }
        chunkOk.add(item.content.id);
      }
      if (chunkOk.isNotEmpty) {
        await _content.deleteByIds(chunkOk);
        deleted.addAll(chunkOk);
      }
    }
    return DeleteContentResult(
      deletedContentIds: deleted,
      failures: failures,
      notFoundIds: const [],
      filesDeleted: filesDeleted,
      filesMissing: filesMissing,
    );
  }

  Future<void> _discardPart(int mediaFileId) async {
    try {
      await _cache.discard(mediaFileId);
    } on Object {
      // Best effort: a stale part file is removed by cleanupOrphans.
    }
  }
}
