import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/internal.dart';
import 'package:storize_model/storize_model.dart';

/// One downloadable file of a content row (table `media_file`).
@immutable
final class MediaFile {
  /// Creates a media file. Use [unsavedId] for [id] before it is stored.
  const MediaFile({
    required this.id,
    required this.contentId,
    required this.slideIndex,
    required this.mediaType,
    required this.sourceUrl,
    this.status = MediaFileStatus.pending,
    this.attempts = 0,
    this.contentUri,
    this.relativePath,
    this.displayName,
    this.thumbPath,
    this.width,
    this.height,
    this.durationMs,
    this.sizeBytes,
    this.downloadedAt,
  });

  /// The [id] of an entity that has not been stored yet.
  static const int unsavedId = 0;

  /// The [contentId] of a media file that is inserted together with its
  /// content, which assigns the real ID.
  static const int unsavedContentId = 0;

  /// The maximum number of download attempts (FR-25).
  static const int maxAttempts = 5;

  /// The database ID.
  final int id;

  /// The owning content row. With [slideIndex] it is unique.
  final int contentId;

  /// The slide index: 0 for stories.
  final int slideIndex;

  /// Photo or video.
  final MediaType mediaType;

  /// The signed CDN URL. It expires and is redacted in [toString].
  final String sourceUrl;

  /// Download progress.
  final MediaFileStatus status;

  /// How many download attempts have run, at most [maxAttempts].
  final int attempts;

  /// The MediaStore URI once saved.
  final String? contentUri;

  /// The gallery folder, for example `Pictures/Storize/<username>/`.
  final String? relativePath;

  /// The gallery file name.
  final String? displayName;

  /// The cached thumbnail path.
  final String? thumbPath;

  /// Pixel width.
  final int? width;

  /// Pixel height.
  final int? height;

  /// Video length in milliseconds.
  final int? durationMs;

  /// The saved file size in bytes.
  final int? sizeBytes;

  /// When the download finished (UTC).
  final DateTime? downloadedAt;

  /// Returns a copy with the given fields replaced. Pass null to clear a
  /// nullable field.
  MediaFile copyWith({
    int? id,
    int? contentId,
    String? sourceUrl,
    MediaFileStatus? status,
    int? attempts,
    Object? contentUri = unset,
    Object? relativePath = unset,
    Object? displayName = unset,
    Object? thumbPath = unset,
    Object? width = unset,
    Object? height = unset,
    Object? durationMs = unset,
    Object? sizeBytes = unset,
    Object? downloadedAt = unset,
  }) => MediaFile(
    id: id ?? this.id,
    contentId: contentId ?? this.contentId,
    slideIndex: slideIndex,
    mediaType: mediaType,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    contentUri: pick<String>(contentUri, this.contentUri),
    relativePath: pick<String>(relativePath, this.relativePath),
    displayName: pick<String>(displayName, this.displayName),
    thumbPath: pick<String>(thumbPath, this.thumbPath),
    width: pick<int>(width, this.width),
    height: pick<int>(height, this.height),
    durationMs: pick<int>(durationMs, this.durationMs),
    sizeBytes: pick<int>(sizeBytes, this.sizeBytes),
    downloadedAt: pick<DateTime>(downloadedAt, this.downloadedAt),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaFile &&
          other.id == id &&
          other.contentId == contentId &&
          other.slideIndex == slideIndex &&
          other.mediaType == mediaType &&
          other.sourceUrl == sourceUrl &&
          other.status == status &&
          other.attempts == attempts &&
          other.contentUri == contentUri &&
          other.relativePath == relativePath &&
          other.displayName == displayName &&
          other.thumbPath == thumbPath &&
          other.width == width &&
          other.height == height &&
          other.durationMs == durationMs &&
          other.sizeBytes == sizeBytes &&
          other.downloadedAt == downloadedAt);

  @override
  int get hashCode => Object.hash(
    id,
    contentId,
    slideIndex,
    mediaType,
    sourceUrl,
    status,
    attempts,
    contentUri,
    relativePath,
    displayName,
    thumbPath,
    width,
    height,
    durationMs,
    sizeBytes,
    downloadedAt,
  );

  /// Redacts [sourceUrl] and [contentUri].
  @override
  String toString() =>
      'MediaFile(id: $id, contentId: $contentId, slideIndex: $slideIndex, '
      'type: ${mediaType.name}, status: ${status.name}, attempts: $attempts, '
      'sourceUrl: <redacted>)';
}
