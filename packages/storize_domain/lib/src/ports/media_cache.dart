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

  /// Deletes every part file and every thumbnail whose media file ID is not in
  /// [keepIds], and returns how many files were removed in total (part files
  /// and thumbnails together). Files that are not part files or `<id>.webp`
  /// thumbnails are left alone.
  Future<int> cleanupOrphans(Set<int> keepIds);

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
