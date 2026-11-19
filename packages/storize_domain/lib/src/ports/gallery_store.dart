import 'package:storize_domain/src/exceptions.dart';
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
  ///
  /// Throws [GalleryPermissionDenied] when the gallery refuses the write (on
  /// Android 8-9 the storage permission is missing), [GalleryStorageFull] when
  /// the device is out of space, and [GalleryWriteFailed] for any other
  /// failure, including a missing source file.
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  });

  /// Deletes the file at [contentUri]. Returns true if a file was deleted and
  /// false if it was already gone (BR-9).
  ///
  /// Throws [GalleryPermissionDenied] when the file is not owned by Storize
  /// and [GalleryWriteFailed] for any other failure.
  Future<bool> delete(String contentUri);

  /// Whether the file at [contentUri] still exists (EC-20).
  ///
  /// A missing file is `false`, not an error. Throws [GalleryWriteFailed] when
  /// the check itself fails.
  Future<bool> exists(String contentUri);

  /// The size in bytes of the file at [contentUri], or null if it is missing.
  ///
  /// Throws [GalleryWriteFailed] when the lookup itself fails.
  Future<int?> size(String contentUri);
}
