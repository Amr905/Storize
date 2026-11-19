/// The private app cache for partial downloads and thumbnails (NFR-7).
///
/// Part files let a download resume with an HTTP `Range` request (CDN-1)
/// after a kill or a lost connection. Keys are media file IDs.
abstract interface class MediaCache {
  /// The number of bytes already stored in the part file of [mediaFileId], or
  /// 0 when there is none. Use it as `fromByte` when resuming.
  Future<int> partialLength(int mediaFileId);

  /// Appends [bytes] to the part file of [mediaFileId], creating it if needed.
  ///
  /// Bytes received before a stream error stay in the file, so the caller can
  /// resume from [partialLength]. The error is rethrown.
  Future<void> append(int mediaFileId, Stream<List<int>> bytes);

  /// The local path of the part file of [mediaFileId], ready to pass to
  /// `GalleryStore.save` as `sourcePath`.
  ///
  /// Throws [StateError] when there is no part file.
  Future<String> completedPath(int mediaFileId);

  /// Deletes the part file of [mediaFileId]. Does nothing if there is none.
  Future<void> discard(int mediaFileId);

  /// Deletes every part file whose media file ID is not in [pendingIds] and
  /// returns how many were removed. [pendingIds] are the IDs of downloads that
  /// are still in progress. Thumbnails are not touched; see
  /// [cleanupOrphanThumbnails], which takes a different ID set.
  Future<int> cleanupOrphans(Set<int> pendingIds);

  /// Deletes every thumbnail `<id>.webp` and every `<id>.webp.tmp` leftover
  /// whose media file ID is not in [liveMediaIds], and returns how many files
  /// were removed.
  ///
  /// The caller must pass the IDs of **all** `media_file` rows, not only the
  /// pending ones. A downloaded item still shows its thumbnail, so its ID is
  /// live even though its part file is gone. Passing only pending IDs deletes
  /// the thumbnails of every downloaded item. Files that are not exactly
  /// `<int>.webp` or `<int>.webp.tmp` are left alone.
  Future<int> cleanupOrphanThumbnails(Set<int> liveMediaIds);

  /// Stores [webpBytes] as the thumbnail of [mediaFileId], replacing any old
  /// one, and returns its path (for `MediaFile.thumbPath`).
  Future<String> writeThumbnail(int mediaFileId, List<int> webpBytes);

  /// Deletes the thumbnail of [mediaFileId] and any leftover temp file of an
  /// interrupted [writeThumbnail].
  ///
  /// Idempotent: a missing thumbnail is not an error, and a call for a missing
  /// file never throws.
  Future<void> deleteThumbnail(int mediaFileId);
}
