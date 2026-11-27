import 'package:meta/meta.dart';
import 'package:storize_model/src/enums.dart';
import 'package:storize_model/src/internal/deep_equality.dart';

/// One media file of a remote story or post (a carousel has several).
@immutable
final class RemoteMedia {
  /// Creates a remote media item.
  const RemoteMedia({
    required this.index,
    required this.type,
    required this.url,
    required this.width,
    required this.height,
    this.duration,
  });

  /// The slide index: 0 for stories and single posts.
  final int index;

  /// Photo or video.
  final MediaType type;

  /// The CDN URL. It is signed and expires, so it is redacted in [toString].
  final String url;

  /// Pixel width of the chosen rendition.
  final int width;

  /// Pixel height of the chosen rendition.
  final int height;

  /// Video length, or null for photos.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteMedia &&
          other.index == index &&
          other.type == type &&
          other.url == url &&
          other.width == width &&
          other.height == height &&
          other.duration == duration);

  @override
  int get hashCode => Object.hash(index, type, url, width, height, duration);

  @override
  String toString() =>
      'RemoteMedia(index: $index, type: ${type.name}, width: $width, '
      'height: $height, duration: $duration, url: <redacted>)';
}

/// A story or a post as Instagram reports it.
@immutable
final class RemoteContent {
  /// Creates remote content. Lists and maps are copied into unmodifiable forms.
  RemoteContent({
    required this.remoteId,
    required this.kind,
    required this.postedAt,
    required List<RemoteMedia> slides,
    Map<String, Object?> extras = const {},
    this.shortcode,
    this.postType,
    this.expiresAt,
    this.caption,
    this.locationName,
    List<String> taggedUsernames = const [],
    this.closeFriends = false,
  }) : slides = List<RemoteMedia>.unmodifiable(slides),
       taggedUsernames = List<String>.unmodifiable(taggedUsernames),
       extras = Map<String, Object?>.unmodifiable({
         for (final e in extras.entries) e.key: deepUnmodifiable(e.value),
       });

  /// The media primary key (`pk`). Unique per target and kind (BR-3).
  final String remoteId;

  /// Story or post.
  final ContentKind kind;

  /// The `/p/<code>/` shortcode. Posts only (FR-62).
  final String? shortcode;

  /// The post shape. Posts only.
  final PostType? postType;

  /// When the content was published.
  final DateTime postedAt;

  /// When a story expires. Stories only.
  final DateTime? expiresAt;

  /// The caption. Posts only.
  final String? caption;

  /// The location name, when Instagram provides one (FR-77).
  final String? locationName;

  /// Usernames tagged in the media, deduplicated (FR-77).
  final List<String> taggedUsernames;

  /// Whether the story was shared with close friends (FR-27).
  final bool closeFriends;

  /// The media files, in slide order.
  final List<RemoteMedia> slides;

  /// Extra data such as link stickers, mentions and location.
  final Map<String, Object?> extras;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteContent &&
          other.remoteId == remoteId &&
          other.kind == kind &&
          other.shortcode == shortcode &&
          other.postType == postType &&
          other.postedAt == postedAt &&
          other.expiresAt == expiresAt &&
          other.caption == caption &&
          other.locationName == locationName &&
          deepEquals(other.taggedUsernames, taggedUsernames) &&
          other.closeFriends == closeFriends &&
          deepEquals(other.slides, slides) &&
          deepEquals(other.extras, extras));

  @override
  int get hashCode => Object.hash(
    remoteId,
    kind,
    shortcode,
    postType,
    postedAt,
    expiresAt,
    caption,
    locationName,
    deepHash(taggedUsernames),
    closeFriends,
    deepHash(slides),
    deepHash(extras),
  );

  /// Omits [caption], [locationName], [taggedUsernames] and [extras] so that
  /// post content does not reach logs.
  @override
  String toString() =>
      'RemoteContent(remoteId: $remoteId, kind: ${kind.name}, '
      'postType: ${postType?.name}, postedAt: $postedAt, '
      'slides: ${slides.length})';
}
