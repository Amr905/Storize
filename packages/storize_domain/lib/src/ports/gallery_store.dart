import 'package:storize_model/storize_model.dart';

/// Saves media into the phone gallery (`Pictures/Storize/<username>/`).
///
/// This is the only way media is written (ADR-5, ADR-11). The native plugin
/// sits behind it.
abstract interface class GalleryStore {
  /// Copies the file at [sourcePath] into the gallery folder [relativeDir]
  /// under the name [displayName], then returns where it landed.
  ///
  /// [mime] is the media type, for example `image/jpeg`. The source file is
  /// not deleted: the caller removes its `.part` file.
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  });

  /// Deletes the file at [contentUri]. Returns true if a file was deleted and
  /// false if it was already gone (BR-9).
  Future<bool> delete(String contentUri);

  /// Whether the file at [contentUri] still exists (EC-20).
  Future<bool> exists(String contentUri);

  /// The size in bytes of the file at [contentUri], or null if it is missing.
  Future<int?> size(String contentUri);
}
