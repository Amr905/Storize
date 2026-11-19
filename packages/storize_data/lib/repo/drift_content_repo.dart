import 'package:drift/drift.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo_support.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// [ContentRepo] over [ContentDao].
final class DriftContentRepo implements ContentRepo {
  /// Creates the repo over [db].
  ///
  /// The library stream waits [libraryDebounce] after a burst of changes (one
  /// download pass updates many rows) before it emits again. The first value
  /// is not delayed.
  DriftContentRepo(
    StorizeDatabase db, {
    this.libraryDebounce = defaultLibraryDebounce,
  }) : _dao = db.contentDao;

  /// Default quiet period of the library stream.
  static const Duration defaultLibraryDebounce = Duration(milliseconds: 75);

  /// Quiet period of the library stream. [Duration.zero] still coalesces
  /// changes that land in the same event-loop turn.
  final Duration libraryDebounce;

  final ContentDao _dao;

  static const _contentKey = '(target_id, kind, remote_id)';

  @override
  Stream<List<ContentWithMedia>> watchLibrary(ContentFilter filter) =>
      freshStream(
        debounceAfterFirst(
          _dao
              .watchLibrary(filter)
              .map((rows) => rows.map(_toContentWithMedia).toList()),
          libraryDebounce,
        ),
      );

  @override
  Future<ContentWithMedia?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toContentWithMedia(row);
  }

  @override
  Future<List<ContentWithMedia>> getByIds(Iterable<int> ids) async =>
      (await _dao.getByIds(ids)).map(_toContentWithMedia).toList();

  @override
  Future<List<ContentWithMedia>> listByTarget(int targetId) async =>
      (await _dao.listByTarget(targetId)).map(_toContentWithMedia).toList();

  @override
  Future<Set<String>> existingRemoteIds(
    int targetId,
    ContentKind kind,
    Iterable<String> remoteIds,
  ) => _dao.existingRemoteIds(targetId, kind, remoteIds);

  @override
  Future<ContentInsertResult> insertIfNew(
    Content content,
    List<MediaFile> media,
  ) async {
    // Checked here so a duplicate slide index fails the same way as in the
    // fake (ArgumentError) before anything is written, instead of surfacing
    // as a SqliteException from the (content_id, slide_index) UNIQUE index.
    final indexes = media.map((m) => m.slideIndex).toSet();
    if (indexes.length != media.length) {
      throw ArgumentError.value(media, 'media', 'slide indexes must be unique');
    }
    final result = await mapUniqueViolation(
      'content',
      _contentKey,
      () => _dao.insertIfNew(_toContentCompanion(content), [
        for (final m in media) _toMediaCompanion(m),
      ]),
    );
    return ContentInsertResult(
      contentId: result.contentId,
      isNew: result.isNew,
    );
  }

  @override
  Future<List<PendingMedia>> pendingMedia({int? limit}) async => [
    for (final r in await _dao.pendingMedia(limit: limit))
      PendingMedia(_toMediaFile(r.file), _toContent(r.content)),
  ];

  @override
  Future<int> resetInterruptedDownloads() => _dao.resetInterruptedDownloads();

  @override
  Future<void> updateMediaFile(MediaFile file) async {
    final rows = await _dao.updateMediaFilePartial(
      file.id,
      _toMediaCompanion(file, contentId: file.contentId),
    );
    requireRowChanged(rows, 'media file', file.id);
  }

  @override
  Future<void> updateContent(Content content) async {
    final rows = await mapUniqueViolation(
      'content',
      _contentKey,
      () => _dao.updateContentPartial(content.id, _toContentCompanion(content)),
    );
    requireRowChanged(rows, 'content', content.id);
  }

  @override
  Future<void> markViewed(Iterable<int> contentIds) =>
      _dao.markViewed(contentIds);

  @override
  Future<void> deleteByIds(Iterable<int> ids) async {
    await _dao.deleteByIds(ids);
  }

  @override
  Future<List<ContentWithMedia>> olderThan(DateTime cutoff) async =>
      (await _dao.olderThan(cutoff)).map(_toContentWithMedia).toList();

  @override
  Future<Map<int, int>> storageBytesByTarget() => _dao.storageBytesByTarget();
}

ContentWithMedia _toContentWithMedia(ContentWithMediaRows r) =>
    ContentWithMedia(_toContent(r.content), r.media.map(_toMediaFile).toList());

Content _toContent(ContentRow r) => Content(
  id: r.id,
  targetId: r.targetId,
  kind: r.kind,
  remoteId: r.remoteId,
  shortcode: r.shortcode,
  postType: r.postType,
  postedAt: r.postedAt,
  expiresAt: r.expiresAt,
  caption: r.caption,
  slideCount: r.slideCount,
  isCloseFriends: r.isCloseFriends,
  extras: decodeJsonMap(r.extrasJson),
  detectedAt: r.detectedAt,
  status: r.status,
  viewed: r.viewed,
);

MediaFile _toMediaFile(MediaFileRow r) => MediaFile(
  id: r.id,
  contentId: r.contentId,
  slideIndex: r.slideIndex,
  mediaType: r.mediaType,
  sourceUrl: r.sourceUrl,
  status: r.status,
  attempts: r.attempts,
  contentUri: r.contentUri,
  relativePath: r.relativePath,
  displayName: r.displayName,
  thumbPath: r.thumbPath,
  width: r.width,
  height: r.height,
  durationMs: r.durationMs,
  sizeBytes: r.sizeBytes,
  downloadedAt: r.downloadedAt,
);

/// Every column except `id`, which stays absent.
ContentsCompanion _toContentCompanion(Content c) => ContentsCompanion(
  targetId: Value(c.targetId),
  kind: Value(c.kind),
  remoteId: Value(c.remoteId),
  shortcode: Value(c.shortcode),
  postType: Value(c.postType),
  postedAt: Value(c.postedAt),
  expiresAt: Value(c.expiresAt),
  caption: Value(c.caption),
  slideCount: Value(c.slideCount),
  isCloseFriends: Value(c.isCloseFriends),
  extrasJson: Value(encodeJsonMap(c.extras)),
  detectedAt: Value(c.detectedAt),
  status: Value(c.status),
  viewed: Value(c.viewed),
);

/// Every column except `id`. For inserts leave [contentId] null: the DAO sets
/// it to the new content row.
MediaFilesCompanion _toMediaCompanion(MediaFile m, {int? contentId}) =>
    MediaFilesCompanion(
      contentId: contentId == null ? const Value.absent() : Value(contentId),
      slideIndex: Value(m.slideIndex),
      mediaType: Value(m.mediaType),
      sourceUrl: Value(m.sourceUrl),
      status: Value(m.status),
      attempts: Value(m.attempts),
      contentUri: Value(m.contentUri),
      relativePath: Value(m.relativePath),
      displayName: Value(m.displayName),
      thumbPath: Value(m.thumbPath),
      width: Value(m.width),
      height: Value(m.height),
      durationMs: Value(m.durationMs),
      sizeBytes: Value(m.sizeBytes),
      downloadedAt: Value(m.downloadedAt),
    );
