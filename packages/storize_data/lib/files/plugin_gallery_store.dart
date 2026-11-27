// ignore_for_file: avoid_catching_errors, the channel cast throws a TypeError.
import 'dart:io';
import 'dart:typed_data';

import 'package:storize_data/files/private_files.dart';
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
  /// Creates the store over the native plugin API. `private` holds the files
  /// hidden from the gallery (FR-79); without it only the gallery works.
  PluginGalleryStore(this._plugin, {this._private});

  final StorizePlatformAndroid _plugin;
  final PrivateFiles? _private;

  PrivateFiles _requirePrivate() =>
      _private ?? (throw const GalleryWriteFailed('PRIVATE_UNAVAILABLE'));

  /// Code used when the native side answers with a wrong type (the channel
  /// cast throws a `TypeError`).
  static const String _badResponse = 'BAD_RESPONSE';

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
    StorageTarget target = StorageTarget.gallery,
  }) async {
    if (target == StorageTarget.private) {
      return _guardPrivate(
        () => _requirePrivate().save(
          sourcePath: sourcePath,
          relativeDir: relativeDir,
          displayName: displayName,
        ),
      );
    }
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
  Future<GalleryFile> copyTo(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) async {
    final from = storageTargetOf(contentUri);
    if (from == to) throw const GalleryWriteFailed('INVALID_ARGUMENT');
    return to == StorageTarget.private
        ? _galleryToPrivate(contentUri, relativeDir, displayName)
        : _privateToGallery(contentUri, relativeDir, displayName, mime);
  }

  Future<GalleryFile> _galleryToPrivate(
    String uri,
    String relativeDir,
    String displayName,
  ) => _guardPrivate(
    () => _requirePrivate().writeNew(
      relativeDir: relativeDir,
      displayName: displayName,
      fill: (tmp) async {
        try {
          final out = await _plugin.exportToFile(uri: uri, destPath: tmp.path);
          return CopyCheck(size: out.size, sha256: out.sha256);
        } on StorizePlatformException catch (e) {
          throw _map(e);
        } on TypeError {
          throw const GalleryWriteFailed(_badResponse);
        }
      },
    ),
  );

  Future<GalleryFile> _privateToGallery(
    String uri,
    String relativeDir,
    String displayName,
    String mime,
  ) async {
    final priv = _requirePrivate();
    final path = await priv.pathOf(uri);
    final file = path == null ? null : File(path);
    if (file == null || !file.existsSync()) {
      throw const GalleryWriteFailed('SOURCE_NOT_FOUND');
    }
    final length = file.lengthSync();
    final sha = length <= PrivateFiles.hashLimitBytes
        ? await PrivateFiles.sha256Of(file)
        : null;
    final InsertedMedia inserted;
    try {
      inserted = await _plugin.insert(
        sourcePath: path!,
        relativeDir: relativeDir,
        displayName: displayName,
        mime: mime,
      );
    } on StorizePlatformException catch (e) {
      throw _map(e);
    } on TypeError {
      throw const GalleryWriteFailed(_badResponse);
    }
    // Verify what landed in the gallery before anyone trusts it; a bad copy is
    // removed and the private original stays.
    try {
      if (inserted.size != length) {
        throw const GalleryWriteFailed('VERIFY_FAILED');
      }
      if (sha != null) {
        final back = await _plugin.readBytes(
          inserted.uri,
          maxBytes: PrivateFiles.hashLimitBytes,
        );
        if (back == null || PrivateFiles.sha256OfBytes(back) != sha) {
          throw const GalleryWriteFailed('VERIFY_FAILED');
        }
      }
    } on Object catch (e) {
      try {
        await _plugin.delete(inserted.uri);
      } on Object {
        // Best effort: the copy is not referenced by any row.
      }
      if (e is GalleryStoreException) rethrow;
      if (e is StorizePlatformException) throw _map(e);
      throw const GalleryWriteFailed('VERIFY_FAILED');
    }
    return GalleryFile(
      uri: inserted.uri,
      sizeBytes: inserted.size,
      relativePath: inserted.relativePath ?? 'Pictures/Storize/$relativeDir/',
      displayName: inserted.displayName,
    );
  }

  @override
  Future<GalleryFile> move(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) async {
    final copy = await copyTo(
      contentUri,
      to: to,
      relativeDir: relativeDir,
      displayName: displayName,
      mime: mime,
    );
    try {
      await delete(contentUri);
    } on GalleryStoreException {
      // The copy is verified: keep it and leave the original.
    }
    return copy;
  }

  /// The bytes of the saved file at [contentUri] for the full-size viewer, or
  /// null when it is missing or longer than [maxBytes]. Works for both kinds
  /// of reference.
  Future<Uint8List?> readBytes(
    String contentUri, {
    int maxBytes = StorizePlatformAndroid.defaultReadCap,
  }) async {
    if (storageTargetOf(contentUri) == StorageTarget.private) {
      return _private?.readBytes(contentUri, maxBytes: maxBytes);
    }
    return _plugin.readBytes(contentUri, maxBytes: maxBytes);
  }

  /// Runs a private-storage operation. A [FileSystemException] that escapes
  /// is reported by code only.
  Future<T> _guardPrivate<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FileSystemException {
      throw const GalleryWriteFailed('IO_ERROR');
    }
  }

  @override
  Future<bool> delete(String contentUri) async {
    if (storageTargetOf(contentUri) == StorageTarget.private) {
      return _guardPrivate(() => _requirePrivate().delete(contentUri));
    }
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
    if (storageTargetOf(contentUri) == StorageTarget.private) {
      return _guardPrivate(() => _requirePrivate().exists(contentUri));
    }
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
    if (storageTargetOf(contentUri) == StorageTarget.private) {
      return _guardPrivate(() => _requirePrivate().size(contentUri));
    }
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
