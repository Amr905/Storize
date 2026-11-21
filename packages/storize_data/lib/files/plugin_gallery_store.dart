// ignore_for_file: avoid_catching_errors, the channel cast throws a TypeError.
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
/// `GalleryWriteFailed`. `exists` and `size` can throw all three. A wrong-typed
/// native answer is `GalleryWriteFailed(BAD_RESPONSE)`. A missing file is
/// `false`/`null`, never an error.
final class PluginGalleryStore implements GalleryStore {
  /// Creates the store over the native plugin API.
  PluginGalleryStore(this._plugin);

  final StorizePlatformAndroid _plugin;

  /// Code used when the native side answers with a wrong type (the channel
  /// cast throws a `TypeError`).
  static const String _badResponse = 'BAD_RESPONSE';

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
    } on TypeError {
      throw const GalleryWriteFailed(_badResponse);
    }
    return GalleryFile(
      uri: inserted.uri,
      sizeBytes: inserted.size,
      relativePath: inserted.relativePath ?? 'Pictures/Storize/$relativeDir/',
      displayName: inserted.displayName,
    );
  }

  /// Finds a file this app saved under `relativeDir` with exactly
  /// `displayName`, or null (the `GalleryFileFinder` that `DownloadPending`
  /// takes as `findExisting`). Owner-scoped natively. Any failure is "not
  /// found": adoption is best effort and the download then saves normally.
  Future<GalleryFile?> findExisting({
    required String relativeDir,
    required String displayName,
  }) async {
    try {
      final found = await _plugin.findByName(
        relativeDir: relativeDir,
        displayName: displayName,
      );
      if (found == null) return null;
      return GalleryFile(
        uri: found.uri,
        sizeBytes: found.size,
        relativePath: found.relativePath ?? 'Pictures/Storize/$relativeDir/',
        displayName: found.displayName,
      );
      // A lookup is only an optimisation: any failure means "not found".
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> delete(String contentUri) async {
    try {
      return await _plugin.delete(contentUri);
    } on StorizePlatformException catch (e) {
      if (_isMissing(e)) return false;
      throw _map(e);
    } on TypeError {
      throw const GalleryWriteFailed(_badResponse);
    }
  }

  @override
  Future<bool> exists(String contentUri) async {
    try {
      return await _plugin.exists(contentUri);
    } on StorizePlatformException catch (e) {
      if (_isMissing(e)) return false;
      throw _map(e);
    } on TypeError {
      throw const GalleryWriteFailed(_badResponse);
    }
  }

  @override
  Future<int?> size(String contentUri) async {
    try {
      return await _plugin.size(contentUri);
    } on StorizePlatformException catch (e) {
      if (_isMissing(e)) return null;
      throw _map(e);
    } on TypeError {
      throw const GalleryWriteFailed(_badResponse);
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
