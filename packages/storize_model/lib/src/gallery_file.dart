import 'package:meta/meta.dart';

/// A file saved in the phone gallery through `GalleryStore`.
@immutable
final class GalleryFile {
  /// Creates a gallery file reference.
  const GalleryFile({
    required this.uri,
    required this.sizeBytes,
    required this.relativePath,
    required this.displayName,
  });

  /// The MediaStore content URI.
  final String uri;

  /// The file size in bytes.
  final int sizeBytes;

  /// The folder under `Pictures/`, for example `Pictures/Storize/<username>/`.
  final String relativePath;

  /// The file name shown in the gallery.
  final String displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryFile &&
          other.uri == uri &&
          other.sizeBytes == sizeBytes &&
          other.relativePath == relativePath &&
          other.displayName == displayName);

  @override
  int get hashCode => Object.hash(uri, sizeBytes, relativePath, displayName);

  @override
  String toString() =>
      'GalleryFile(uri: $uri, sizeBytes: $sizeBytes, '
      'relativePath: $relativePath, displayName: $displayName)';
}
