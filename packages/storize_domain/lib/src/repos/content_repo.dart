import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/content.dart';
import 'package:storize_domain/src/entities/content_filter.dart';
import 'package:storize_domain/src/entities/content_with_media.dart';
import 'package:storize_domain/src/entities/media_file.dart';
import 'package:storize_model/storize_model.dart';

/// The result of [ContentRepo.insertIfNew].
@immutable
final class ContentInsertResult {
  /// Creates a result.
  const ContentInsertResult({required this.contentId, required this.isNew});

  /// The ID of the stored row: the new one, or the existing duplicate.
  final int contentId;

  /// True when a row was inserted; false when the UNIQUE key
  /// `(targetId, kind, remoteId)` already existed (BR-3).
  final bool isNew;

  @override
  bool operator ==(Object other) =>
      other is ContentInsertResult &&
      other.contentId == contentId &&
      other.isNew == isNew;

  @override
  int get hashCode => Object.hash(contentId, isNew);

  @override
  String toString() =>
      'ContentInsertResult(contentId: $contentId, isNew: $isNew)';
}

/// Access to stories, posts and their media files (tables `content` and
/// `media_file`).
abstract interface class ContentRepo {
  /// Emits the library now and after every change.
  ///
  /// Items matching [filter] are ordered by `postedAt`, newest first, then by
  /// ID descending. Each item has its media files in slide order.
  Stream<List<ContentWithMedia>> watchLibrary(ContentFilter filter);

  /// Like [watchLibrary], but only items whose username, caption, location
  /// name or highlight title contains [query] (case-insensitive substring; the
  /// caller trims it). An empty [query] returns the same as [watchLibrary].
  /// Items are ordered as in [watchLibrary].
  Stream<List<ContentWithMedia>> watchLibrarySearch(
    ContentFilter filter,
    String query,
  );

  /// The content with [id] and its slides, or null.
  Future<ContentWithMedia?> getById(int id);

  /// The content rows with these [ids] (missing IDs are skipped), with slides.
  Future<List<ContentWithMedia>> getByIds(Iterable<int> ids);

  /// All content of [targetId], with slides, newest first. Used to delete
  /// gallery files before a target is removed (BR-6).
  Future<List<ContentWithMedia>> listByTarget(int targetId);

  /// Which of [remoteIds] are already stored for [targetId] and [kind]. Lets
  /// a check diff a fetch against the database (FR-23).
  Future<Set<String>> existingRemoteIds(
    int targetId,
    ContentKind kind,
    Iterable<String> remoteIds,
  );

  /// Stores [content] and its [media] in one atomic step, unless the UNIQUE
  /// key `(targetId, kind, remoteId)` exists already (FR-23, BR-3).
  ///
  /// The IDs in [content] and [media] are ignored and replaced; each media
  /// file gets the new content ID. Slide indexes must be unique.
  /// On a duplicate nothing is written and `isNew` is false.
  Future<ContentInsertResult> insertIfNew(
    Content content,
    List<MediaFile> media,
  );

  /// Media files with status PENDING, in download order: stories before
  /// posts, then oldest `detectedAt` first, then content ID, then slide index.
  /// At most [limit] items when given.
  Future<List<PendingMedia>> pendingMedia({int? limit});

  /// Sets every media file with status DOWNLOADING back to PENDING and
  /// returns how many changed. Run at the start of a download after a kill
  /// (NFR-7).
  Future<int> resetInterruptedDownloads();

  /// Replaces the stored media file that has the same ID.
  ///
  /// Throws [StateError] when it does not exist.
  Future<void> updateMediaFile(MediaFile file);

  /// Replaces the stored content row that has the same ID.
  ///
  /// Throws [StateError] when it does not exist.
  Future<void> updateContent(Content content);

  /// Marks the content as viewed. Unknown IDs are ignored.
  Future<void> markViewed(Iterable<int> contentIds);

  /// Deletes content rows and, by cascade, their media rows. Callers delete
  /// gallery files first (BR-9). Unknown IDs are ignored.
  Future<void> deleteByIds(Iterable<int> ids);

  /// Deletes one media row. When it was the last media row of its item, the
  /// content row is deleted too. Callers delete the gallery file first (BR-9).
  /// An unknown ID is ignored.
  Future<void> deleteMediaFile(int mediaFileId);

  /// Content with `postedAt` before [cutoff], with slides, for retention
  /// (FR-54).
  Future<List<ContentWithMedia>> olderThan(DateTime cutoff);

  /// The sum of `sizeBytes` of media files with status DONE, per target ID.
  /// Targets without files are absent from the map (FR-53).
  Future<Map<int, int>> storageBytesByTarget();
}
