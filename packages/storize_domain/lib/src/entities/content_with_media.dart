import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/content.dart';
import 'package:storize_domain/src/entities/internal.dart';
import 'package:storize_domain/src/entities/media_file.dart';

/// A [Content] row with its media files (slides), ordered by slide index.
@immutable
final class ContentWithMedia {
  /// Creates the pair. The list is copied into an unmodifiable list.
  ContentWithMedia(this.content, List<MediaFile> media)
    : media = List<MediaFile>.unmodifiable(media);

  /// The content row.
  final Content content;

  /// The media files, in slide order.
  final List<MediaFile> media;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentWithMedia &&
          other.content == content &&
          deepEquals(other.media, media));

  @override
  int get hashCode => Object.hash(content, deepHash(media));

  @override
  String toString() => 'ContentWithMedia($content, media: ${media.length})';
}

/// A media file that waits for download, with the content it belongs to.
///
/// The download use case needs the content to build the gallery file name
/// and to decide which target folder to use.
@immutable
final class PendingMedia {
  /// Creates a pending item.
  const PendingMedia(this.file, this.content);

  /// The file to download.
  final MediaFile file;

  /// The content that owns [file].
  final Content content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMedia && other.file == file && other.content == content);

  @override
  int get hashCode => Object.hash(file, content);

  @override
  String toString() => 'PendingMedia($file, $content)';
}
