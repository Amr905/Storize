import 'package:storize_domain/src/ports/media_cache.dart';

/// An in-memory [MediaCache] with fake paths.
///
/// Pass the same instance to `FakeGalleryStore(cache: …)` so that saving a
/// path from [completedPath] reports the real byte count.
final class FakeMediaCache implements MediaCache {
  final Map<int, List<int>> _parts = {};
  final Map<int, List<int>> _thumbs = {};

  /// The fake path prefix of part files.
  static const String partDir = 'fake-cache/part';

  /// The fake path prefix of thumbnails.
  static const String thumbDir = 'fake-cache/thumbs';

  /// The IDs that currently have a part file.
  Set<int> get partIds => Set.unmodifiable(_parts.keys);

  /// The bytes of the part file of [mediaFileId], or null.
  List<int>? partBytes(int mediaFileId) => _parts[mediaFileId];

  /// The bytes of the thumbnail of [mediaFileId], or null.
  List<int>? thumbnailBytes(int mediaFileId) => _thumbs[mediaFileId];

  /// The size of the part file at [path], or null when [path] is not a part
  /// file path of this cache.
  int? sizeOfPath(String path) {
    for (final e in _parts.entries) {
      if (path == _partPath(e.key)) return e.value.length;
    }
    return null;
  }

  String _partPath(int id) => '$partDir/$id.part';

  @override
  Future<int> partialLength(int mediaFileId) async =>
      _parts[mediaFileId]?.length ?? 0;

  @override
  Future<void> append(int mediaFileId, Stream<List<int>> bytes) async {
    final part = _parts.putIfAbsent(mediaFileId, () => <int>[]);
    await bytes.forEach(part.addAll);
  }

  @override
  Future<String> completedPath(int mediaFileId) async {
    if (!_parts.containsKey(mediaFileId)) {
      throw StateError('No part file for media file $mediaFileId');
    }
    return _partPath(mediaFileId);
  }

  @override
  Future<void> discard(int mediaFileId) async => _parts.remove(mediaFileId);

  @override
  Future<int> cleanupOrphans(Set<int> keepIds) async {
    final partOrphans = _parts.keys
        .where((id) => !keepIds.contains(id))
        .toList();
    final thumbOrphans = _thumbs.keys
        .where((id) => !keepIds.contains(id))
        .toList();
    partOrphans.forEach(_parts.remove);
    thumbOrphans.forEach(_thumbs.remove);
    return partOrphans.length + thumbOrphans.length;
  }

  @override
  Future<String> writeThumbnail(int mediaFileId, List<int> webpBytes) async {
    _thumbs[mediaFileId] = List<int>.of(webpBytes);
    return '$thumbDir/$mediaFileId.webp';
  }

  @override
  Future<void> deleteThumbnail(int mediaFileId) async =>
      _thumbs.remove(mediaFileId);
}
