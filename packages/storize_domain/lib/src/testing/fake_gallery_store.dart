import 'dart:io';

import 'package:storize_domain/src/ports/gallery_store.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [GalleryStore].
///
/// `save` reads the size of the source file when it exists on disk, otherwise
/// it uses [defaultSizeBytes], so tests do not need real files. Name
/// collisions are not renamed: each save gets a fresh URI.
final class FakeGalleryStore implements GalleryStore {
  /// Creates a store. [defaultSizeBytes] is used when the source file is not
  /// on disk.
  FakeGalleryStore({this.defaultSizeBytes = 1024});

  /// The size reported for sources that do not exist on disk.
  final int defaultSizeBytes;

  final Map<String, GalleryFile> _files = {};
  final List<GalleryFile> _saved = [];
  Object? _nextSaveError;
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
    final size = source.existsSync() ? source.lengthSync() : defaultSizeBytes;
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
  Future<bool> delete(String contentUri) async =>
      _files.remove(contentUri) != null;

  @override
  Future<bool> exists(String contentUri) async =>
      _files.containsKey(contentUri);

  @override
  Future<int?> size(String contentUri) async => _files[contentUri]?.sizeBytes;
}
