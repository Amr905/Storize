import 'package:storize_data/files/gallery_exceptions.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

/// [GalleryStore] over the native plugin (ADR-5, ADR-11).
///
/// [save] reports what the plugin returned, not what was requested: the
/// folder can become `Movies/Storize/<dir>/` (video fallback) and the name can
/// become `name (1).ext`. Store both. [delete], [exists] and [size] must only
/// receive URIs that [save] returned.
///
/// Errors: see `GalleryPermissionDenied`, `GalleryStorageFull` and
/// `GalleryWriteFailed`. A missing file is `false`/`null`, never an error.
final class PluginGalleryStore implements GalleryStore {
  /// Creates the store over the native plugin API.
  PluginGalleryStore(this._plugin);

  final StorizePlatformAndroid _plugin;

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) async {
    final InsertedMedia inserted;
    try {
      inserted = await _plugin.insert(
        sourcePath: sourcePath,
        relativeDir: relativeDir,
        displayName: displayName,
        mime: mime,
      );
    } on StorizePlatformException catch (e) {
      throw _map(e);
    }
    return GalleryFile(
      uri: inserted.uri,
      sizeBytes: inserted.size,
      relativePath: inserted.relativePath ?? 'Pictures/Storize/$relativeDir/',
      displayName: inserted.displayName,
    );
  }

  @override
  Future<bool> delete(String contentUri) async {
    try {
      return await _plugin.delete(contentUri);
    } on StorizePlatformException catch (e) {
      if (_isMissing(e)) return false;
      throw _map(e);
    }
  }

  @override
  Future<bool> exists(String contentUri) async {
    try {
      return await _plugin.exists(contentUri);
    } on StorizePlatformException catch (e) {
      if (_isMissing(e)) return false;
      throw _map(e);
    }
  }

  @override
  Future<int?> size(String contentUri) async {
    try {
      return await _plugin.size(contentUri);
    } on StorizePlatformException catch (e) {
      if (_isMissing(e)) return null;
      throw _map(e);
    }
  }

  bool _isMissing(StorizePlatformException e) =>
      e.kind == StorizePlatformErrorKind.sourceNotFound;

  GalleryStoreException _map(StorizePlatformException e) => switch (e.kind) {
    StorizePlatformErrorKind.permissionDenied =>
      const GalleryPermissionDenied(),
    StorizePlatformErrorKind.storageFull => const GalleryStorageFull(),
    _ => GalleryWriteFailed(e.code),
  };
}
