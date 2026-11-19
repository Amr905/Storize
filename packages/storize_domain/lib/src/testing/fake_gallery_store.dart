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
  FakeGalleryStore({this.defaultSizeBytes = 1024, this.cache});

  /// The cache whose fake part paths this store understands, if any.
  final FakeMediaCache? cache;

  /// The size reported for sources that do not exist on disk.
  final int defaultSizeBytes;

  final Map<String, GalleryFile> _files = {};
  final List<GalleryFile> _saved = [];
  Object? _nextSaveError;
  GalleryStoreException? _nextDeleteError;
  int _counter = 0;

  /// The files that currently exist, in save order.
  List<GalleryFile> get files => List.unmodifiable(_files.values);

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

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) async {
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
      uri: 'content://fake/media/${++_counter}',
      sizeBytes: size,
      relativePath: relativeDir,
      displayName: displayName,
    );
    _files[file.uri] = file;
    _saved.add(file);
    return file;
  }

  @override
  Future<bool> delete(String contentUri) async {
    final error = _nextDeleteError;
    if (error != null) {
      _nextDeleteError = null;
      throw error;
    }
    return _files.remove(contentUri) != null;
  }

  @override
  Future<bool> exists(String contentUri) async =>
      _files.containsKey(contentUri);

  @override
  Future<int?> size(String contentUri) async => _files[contentUri]?.sizeBytes;
}
