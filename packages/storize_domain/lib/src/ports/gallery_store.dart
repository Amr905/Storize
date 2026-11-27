import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_model/storize_model.dart';

/// Where a saved file lives (FR-79).
enum StorageTarget {
  /// The phone gallery: `Pictures/Storize/<username>/`, addressed by a
  /// `content://` URI. Gallery and Photos show these files.
  gallery,

  /// Storize's private storage (app-specific external files, not scanned into
  /// the gallery), addressed by a `file://` URI. Only Storize shows these
  /// files, and uninstalling Storize deletes them.
  private,
}

/// The [StorageTarget] that a stored file reference points at: a `file://`
/// reference is private, anything else is the gallery.
StorageTarget storageTargetOf(String contentUri) =>
    contentUri.startsWith('file://')
    ? StorageTarget.private
    : StorageTarget.gallery;

/// Saves media into the phone gallery (`Pictures/Storize/<username>/`) or, for
/// the hide-from-gallery setting (FR-79), into Storize's private storage.
///
/// This is the only way media is written (ADR-5, ADR-11). The native plugin
/// sits behind it. Every method takes the reference that [save] returned and
/// works for both kinds of reference ([storageTargetOf]).
abstract interface class GalleryStore {
  /// Copies the file at [sourcePath] into the gallery folder [relativeDir]
  /// under the name [displayName], then returns where it landed.
  ///
  /// [mime] is the media type, for example `image/jpeg`. The source file is
  /// not deleted: the caller removes its `.part` file.
  ///
  /// With [target] [StorageTarget.private] the file goes to private storage
  /// instead and no gallery permission is needed; [GalleryFile.uri] is then a
  /// `file://` reference.
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
    StorageTarget target = StorageTarget.gallery,
  });

  /// Copies the file at [contentUri] to the other kind of storage [to] and
  /// returns the new reference. **The original is never touched**: the caller
  /// stores the new reference first and then calls [delete] on the original,
  /// so an interruption never loses a file (FR-79).
  ///
  /// The copy is verified before it is returned: same size, and the same
  /// sha256 when the file is at most 50 MB. On any failure the partial copy is
  /// removed and an exception is thrown; the original is still there.
  /// [relativeDir], [displayName] and [mime] are as in [save].
  ///
  /// Throws [GalleryWriteFailed] with code `SOURCE_NOT_FOUND` when the original
  /// is missing, `VERIFY_FAILED` when the copy differs, plus the exceptions of
  /// [save].
  Future<GalleryFile> copyTo(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  });

  /// [copyTo], then deletes the original once the copy is verified. Returns
  /// the new reference. When only the delete of the original fails, the copy
  /// is kept and returned (a leftover original is safer than a lost file).
  Future<GalleryFile> move(
    String contentUri, {
    required StorageTarget to,
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
  /// A missing file is `false`, not an error. Throws [GalleryPermissionDenied]
  /// when the gallery refuses the lookup, [GalleryStorageFull] when the
  /// system reports the device as full, and [GalleryWriteFailed] when the
  /// check itself fails for any other reason.
  Future<bool> exists(String contentUri);

  /// The size in bytes of the file at [contentUri], or null if it is missing.
  ///
  /// Throws the same set as [exists]: [GalleryPermissionDenied],
  /// [GalleryStorageFull] or [GalleryWriteFailed].
  Future<int?> size(String contentUri);
}
