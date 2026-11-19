import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/internal.dart';
import 'package:storize_model/storize_model.dart';

/// A stored story or post (table `content`).
@immutable
final class Content {
  /// Creates content. Use [unsavedId] for [id] before it is stored.
  Content({
    required this.id,
    required this.targetId,
    required this.kind,
    required this.remoteId,
    required this.postedAt,
    required this.slideCount,
    required this.detectedAt,
    this.shortcode,
    this.postType,
    this.expiresAt,
    this.caption,
    this.isCloseFriends = false,
    Map<String, Object?> extras = const {},
    this.status = ContentStatus.pending,
    this.viewed = false,
  }) : extras = freezeMap(extras);

  /// The [id] of an entity that has not been stored yet.
  static const int unsavedId = 0;

  /// The database ID.
  final int id;

  /// The owning target. Deleting the target deletes this row.
  final int targetId;

  /// Story or post.
  final ContentKind kind;

  /// The media pk. With [targetId] and [kind] it is unique (BR-3).
  final String remoteId;

  /// The `/p/<code>/` shortcode. Posts only.
  final String? shortcode;

  /// The post shape. Posts only.
  final PostType? postType;

  /// When it was published (UTC).
  final DateTime postedAt;

  /// When a story expires (UTC). Stories only.
  final DateTime? expiresAt;

  /// The caption. Posts only.
  final String? caption;

  /// How many media files it has: 1 for a story.
  final int slideCount;

  /// Whether it was shared with close friends (FR-27).
  final bool isCloseFriends;

  /// Link stickers, mentions and location (`extras_json`).
  final Map<String, Object?> extras;

  /// When we first saw it (UTC).
  final DateTime detectedAt;

  /// Download progress.
  final ContentStatus status;

  /// Whether the user has seen it. Drives the "new" ring.
  final bool viewed;

  /// Returns a copy with the given fields replaced. Pass null to clear a
  /// nullable field. The identity key ([targetId], [kind], [remoteId]) cannot
  /// change.
  Content copyWith({
    int? id,
    Object? shortcode = unset,
    Object? postType = unset,
    DateTime? postedAt,
    Object? expiresAt = unset,
    Object? caption = unset,
    int? slideCount,
    bool? isCloseFriends,
    Map<String, Object?>? extras,
    DateTime? detectedAt,
    ContentStatus? status,
    bool? viewed,
  }) => Content(
    id: id ?? this.id,
    targetId: targetId,
    kind: kind,
    remoteId: remoteId,
    shortcode: pick<String>(shortcode, this.shortcode),
    postType: pick<PostType>(postType, this.postType),
    postedAt: postedAt ?? this.postedAt,
    expiresAt: pick<DateTime>(expiresAt, this.expiresAt),
    caption: pick<String>(caption, this.caption),
    slideCount: slideCount ?? this.slideCount,
    isCloseFriends: isCloseFriends ?? this.isCloseFriends,
    extras: extras ?? this.extras,
    detectedAt: detectedAt ?? this.detectedAt,
    status: status ?? this.status,
    viewed: viewed ?? this.viewed,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Content &&
          other.id == id &&
          other.targetId == targetId &&
          other.kind == kind &&
          other.remoteId == remoteId &&
          other.shortcode == shortcode &&
          other.postType == postType &&
          other.postedAt == postedAt &&
          other.expiresAt == expiresAt &&
          other.caption == caption &&
          other.slideCount == slideCount &&
          other.isCloseFriends == isCloseFriends &&
          deepEquals(other.extras, extras) &&
          other.detectedAt == detectedAt &&
          other.status == status &&
          other.viewed == viewed);

  @override
  int get hashCode => Object.hash(
    id,
    targetId,
    kind,
    remoteId,
    shortcode,
    postType,
    postedAt,
    expiresAt,
    caption,
    slideCount,
    isCloseFriends,
    deepHash(extras),
    detectedAt,
    status,
    viewed,
  );

  /// Omits [caption] and [extras] so that post content does not reach logs.
  @override
  String toString() =>
      'Content(id: $id, targetId: $targetId, kind: ${kind.name}, '
      'remoteId: $remoteId, status: ${status.name}, viewed: $viewed)';
}
