import 'dart:async';
import 'dart:io';

import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/ports/gallery_store.dart';
import 'package:storize_domain/src/testing/fake_media_cache.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [GalleryStore].
///
/// `save` reads the size of the source file when it exists on disk, otherwise
/// it uses [defaultSizeBytes], so tests do not need real files. Name
/// collisions are not renamed: each save gets a fresh URI.
final class FakeGalleryStore implements GalleryStore {
  /// Creates a store. [defaultSizeBytes] is used when the source file is not
  /// on disk.
  ///
  /// With a [cache], a source path produced by it reports the cached byte
  /// count.
  FakeGalleryStore({
    this.defaultSizeBytes = 1024,
    this.cache,
    this.onOperation,
  });

  /// Called at the start of `save`, `copyTo` and `delete` (before they change
  /// anything) with the operation name and the reference, so a test can look
  /// at other state at that moment (for example the stored row).
  final FutureOr<void> Function(String operation, String? contentUri)?
  onOperation;

  /// The cache whose fake part paths this store understands, if any.
  final FakeMediaCache? cache;

  /// The size reported for sources that do not exist on disk.
  final int defaultSizeBytes;

  final Map<String, GalleryFile> _files = {};
  final List<GalleryFile> _saved = [];
  Object? _nextSaveError;
  GalleryStoreException? _nextDeleteError;
  GalleryStoreException? _nextExistsError;
  GalleryStoreException? _nextSizeError;
  GalleryStoreException? _nextCopyError;
  int _copyAfter = 0;
  int _counter = 0;

  /// The files that currently exist, in save order.
  List<GalleryFile> get files => List.unmodifiable(_files.values);

  /// The files that currently exist in private storage.
  List<GalleryFile> get privateFiles => List.unmodifiable(
    _files.values.where((f) => storageTargetOf(f.uri) == StorageTarget.private),
  );

  /// The files that currently exist in the gallery.
  List<GalleryFile> get galleryFiles => List.unmodifiable(
    _files.values.where((f) => storageTargetOf(f.uri) == StorageTarget.gallery),
  );

  /// Every file ever saved, including ones deleted later.
  List<GalleryFile> get saved => List.unmodifiable(_saved);

  /// Makes the next `save` throw [error] (for example a `FileSystemException`
  /// to model a full disk).
  // ignore: use_setters_to_change_properties, a verb reads better in tests.
  void failNextSave(Object error) => _nextSaveError = error;

  /// Removes the file as if the user deleted it in another app (EC-20).
  /// Returns false when it did not exist.
  bool simulateMissing(String contentUri) => _files.remove(contentUri) != null;

  /// Makes the next `save` throw [GalleryPermissionDenied].
  void failNextSaveWithPermissionDenied() =>
      failNextSave(const GalleryPermissionDenied());

  /// Makes the next `save` throw [GalleryStorageFull].
  void failNextSaveWithStorageFull() =>
      failNextSave(const GalleryStorageFull());

  /// Makes the next `save` throw [GalleryWriteFailed] with [code].
  void failNextSaveWithWriteFailed([String code = 'IO_ERROR']) =>
      failNextSave(GalleryWriteFailed(code));

  /// Makes the next `delete` throw [error] (for example
  /// `GalleryPermissionDenied()` for a row Storize does not own).
  // ignore: use_setters_to_change_properties, a verb reads better in tests.
  void failNextDelete(GalleryStoreException error) => _nextDeleteError = error;

  /// Makes the next `exists` throw [error]: any of [GalleryPermissionDenied],
  /// [GalleryStorageFull] or [GalleryWriteFailed], as the port documents.
  // ignore: use_setters_to_change_properties, a verb reads better in tests.
  void failNextExists(GalleryStoreException error) => _nextExistsError = error;

  /// Makes the next `size` throw [error], same set as [failNextExists].
  // ignore: use_setters_to_change_properties, a verb reads better in tests.
  void failNextSize(GalleryStoreException error) => _nextSizeError = error;

  /// Makes a `copyTo` throw [error] once, after [after] successful copies
  /// (default: the next one). Models a full disk or a failed verification.
  void failNextCopy(GalleryStoreException error, {int after = 0}) {
    _nextCopyError = error;
    _copyAfter = after;
  }

  String _newUri(StorageTarget target) => switch (target) {
    StorageTarget.gallery => 'content://fake/media/${++_counter}',
    StorageTarget.private => 'file:///fake/private/${++_counter}',
  };

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
    StorageTarget target = StorageTarget.gallery,
  }) async {
    await onOperation?.call('save', null);
    final error = _nextSaveError;
    if (error != null) {
      _nextSaveError = null;
      // ignore: only_throw_errors, the test scripts any error object.
      throw error;
    }
    final source = File(sourcePath);
    final size =
        cache?.sizeOfPath(sourcePath) ??
        (source.existsSync() ? source.lengthSync() : defaultSizeBytes);
    final file = GalleryFile(
      uri: _newUri(target),
      sizeBytes: size,
      relativePath: relativeDir,
      displayName: displayName,
    );
    _files[file.uri] = file;
    _saved.add(file);
    return file;
  }

  @override
  Future<GalleryFile> copyTo(
    String contentUri, {
    required StorageTarget to,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) async {
    await onOperation?.call('copy', contentUri);
    final error = _nextCopyError;
    if (error != null) {
      if (_copyAfter == 0) {
        _nextCopyError = null;
        throw error;
      }
      _copyAfter -= 1;
    }
    final original = _files[contentUri];
    if (original == null) throw const GalleryWriteFailed('SOURCE_NOT_FOUND');
    final file = GalleryFile(
      uri: _newUri(to),
      sizeBytes: original.sizeBytes,
      relativePath: relativeDir,
      displayName: displayName,
    );
    _files[file.uri] = file;
    _saved.add(file);
    return file;
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
      // The copy is verified: keep it, leave the original.
    }
    return copy;
  }

  @override
  Future<bool> delete(String contentUri) async {
    await onOperation?.call('delete', contentUri);
    final error = _nextDeleteError;
    if (error != null) {
      _nextDeleteError = null;
      throw error;
    }
    return _files.remove(contentUri) != null;
  }

  @override
  Future<bool> exists(String contentUri) async {
    final error = _nextExistsError;
    if (error != null) {
      _nextExistsError = null;
      throw error;
    }
    return _files.containsKey(contentUri);
  }

  @override
  Future<int?> size(String contentUri) async {
    final error = _nextSizeError;
    if (error != null) {
      _nextSizeError = null;
      throw error;
    }
    return _files[contentUri]?.sizeBytes;
  }
}
