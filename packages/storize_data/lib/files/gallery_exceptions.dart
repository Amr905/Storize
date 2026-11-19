/// Base type of the failures `PluginGalleryStore` throws.
///
/// None of them carries a path, URI or file name: only a native error code.
///
/// These live in `storize_data` for now. Use cases cannot catch them without
/// importing `storize_data`; moving them next to the `GalleryStore` port in
/// `storize_domain` is proposed to the Lead (see the T-010 report).
sealed class GalleryStoreException implements Exception {
  const GalleryStoreException(this.code);

  /// The native error code, for example `PERMISSION_DENIED`.
  final String code;
}

/// The gallery refused the write or delete with `PERMISSION_DENIED`.
///
/// On Android 8-9 (API <= 28) the caller should ask for the runtime permission
/// `WRITE_EXTERNAL_STORAGE` (S-03 card) and retry. On a delete it also means
/// the row is not owned by Storize (for example after a reinstall).
final class GalleryPermissionDenied extends GalleryStoreException {
  /// Creates the exception.
  const GalleryPermissionDenied() : super('PERMISSION_DENIED');

  @override
  String toString() => 'GalleryPermissionDenied()';
}

/// The device has no space left for the file (`STORAGE_FULL`).
final class GalleryStorageFull extends GalleryStoreException {
  /// Creates the exception.
  const GalleryStorageFull() : super('STORAGE_FULL');

  @override
  String toString() => 'GalleryStorageFull()';
}

/// Any other native failure. Only the [code] is kept, so the message cannot
/// leak a path.
final class GalleryWriteFailed extends GalleryStoreException {
  /// Creates the exception with the native [code].
  const GalleryWriteFailed(super.code);

  @override
  String toString() => 'GalleryWriteFailed($code)';
}
