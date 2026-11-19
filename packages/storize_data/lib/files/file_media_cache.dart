import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:storize_domain/storize_domain.dart';

/// [MediaCache] on the app's private directories (NFR-7).
///
/// Layout: `<cacheDir>/part/<id>.part` and `<filesDir>/thumbs/<id>.webp`.
///
/// **Durability.** [append] writes each chunk straight to the file with
/// `RandomAccessFile.writeFrom` (no Dart-side buffer), so once a chunk was
/// pulled from the stream its bytes are in the OS. If the app process is killed
/// mid-append, the file holds a contiguous prefix of the download and at most
/// the one chunk in flight is lost or cut, which is fine because
/// [partialLength] is the resume offset. At the end of every [append] call
/// (also when the stream failed) the file is fsynced and closed. After a power
/// loss in the middle of an append the unsynced tail may be missing; the file
/// can then be shorter than the bytes received, never longer.
///
/// Two appends to the same ID at the same time are not supported.
final class FileMediaCache implements MediaCache {
  /// Creates a cache. Tests pass temp directories.
  FileMediaCache({
    required this._cacheDir,
    required this._filesDir,
  });

  /// The production cache: the app cache and app support directories.
  FileMediaCache.pathProvider()
    : this(
        cacheDir: getApplicationCacheDirectory,
        filesDir: getApplicationSupportDirectory,
      );

  final Future<Directory> Function() _cacheDir;
  final Future<Directory> Function() _filesDir;

  static const String _partSuffix = '.part';

  Future<Directory> _partDir() async =>
      Directory('${(await _cacheDir()).path}/part');

  Future<File> _partFile(int id) async =>
      File('${(await _partDir()).path}/$id$_partSuffix');

  @override
  Future<int> partialLength(int mediaFileId) async {
    final file = await _partFile(mediaFileId);
    try {
      return await file.length();
    } on PathNotFoundException {
      return 0;
    }
  }

  @override
  Future<void> append(int mediaFileId, Stream<List<int>> bytes) async {
    final file = await _partFile(mediaFileId);
    await file.parent.create(recursive: true);
    final raf = await file.open(mode: FileMode.append);
    try {
      await for (final chunk in bytes) {
        await raf.writeFrom(chunk);
      }
    } finally {
      try {
        await raf.flush();
      } finally {
        await raf.close();
      }
    }
  }

  @override
  Future<String> completedPath(int mediaFileId) async {
    final file = await _partFile(mediaFileId);
    if (!file.existsSync()) {
      throw StateError('No part file for media file $mediaFileId');
    }
    return file.path;
  }

  @override
  Future<void> discard(int mediaFileId) async {
    final file = await _partFile(mediaFileId);
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone.
    }
  }

  @override
  Future<int> cleanupOrphans(Set<int> keepIds) async {
    final dir = await _partDir();
    if (!dir.existsSync()) return 0;
    var removed = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.endsWith(_partSuffix)) continue;
      final id = int.tryParse(
        name.substring(0, name.length - _partSuffix.length),
      );
      if (id != null && keepIds.contains(id)) continue;
      try {
        await entity.delete();
        removed++;
      } on PathNotFoundException {
        // Removed by someone else in the meantime.
      }
    }
    return removed;
  }

  @override
  Future<String> writeThumbnail(int mediaFileId, List<int> webpBytes) async {
    final dir = Directory('${(await _filesDir()).path}/thumbs');
    await dir.create(recursive: true);
    final target = File('${dir.path}/$mediaFileId.webp');
    final temp = File('${target.path}.tmp');
    try {
      await temp.writeAsBytes(webpBytes, flush: true);
      await temp.rename(target.path);
    } on Object {
      if (temp.existsSync()) await temp.delete();
      rethrow;
    }
    return target.path;
  }
}
