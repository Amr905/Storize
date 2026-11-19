import 'package:storize_domain/src/entities/content.dart';
import 'package:storize_domain/src/entities/content_filter.dart';
import 'package:storize_domain/src/entities/content_with_media.dart';
import 'package:storize_domain/src/entities/media_file.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/testing/change_feed.dart';
import 'package:storize_domain/src/testing/fake_target_repo.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [ContentRepo] with the UNIQUE `(targetId, kind, remoteId)`
/// rule, atomic inserts and cascading deletes.
final class FakeContentRepo implements ContentRepo {
  /// Creates the repo. When [targets] is given, deleting a target also deletes
  /// its content and media (the `ON DELETE CASCADE` of the real schema).
  FakeContentRepo({FakeTargetRepo? targets}) {
    targets?.onDelete(_deleteTarget);
  }

  final Map<int, Content> _contents = {};
  final Map<int, MediaFile> _media = {};
  final ChangeFeed _feed = ChangeFeed();
  int _nextContentId = 1;
  int _nextMediaId = 1;

  void _deleteTarget(int targetId) {
    final ids = _contents.values
        .where((c) => c.targetId == targetId)
        .map((c) => c.id)
        .toList();
    _remove(ids);
  }

  bool _remove(Iterable<int> ids) {
    var changed = false;
    for (final id in ids.toList()) {
      if (_contents.remove(id) == null) continue;
      _media.removeWhere((_, m) => m.contentId == id);
      changed = true;
    }
    return changed;
  }

  List<MediaFile> _slides(int contentId) {
    final list = _media.values.where((m) => m.contentId == contentId).toList()
      ..sort((a, b) => a.slideIndex.compareTo(b.slideIndex));
    return list;
  }

  ContentWithMedia _join(Content c) => ContentWithMedia(c, _slides(c.id));

  int _newestFirst(Content a, Content b) {
    final byTime = b.postedAt.compareTo(a.postedAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  }

  @override
  Stream<List<ContentWithMedia>> watchLibrary(ContentFilter filter) =>
      _feed.watch(() {
        final rows =
            _contents.values
                .where((c) => filter.matches(c, _slides(c.id)))
                .toList()
              ..sort(_newestFirst);
        return rows.map(_join).toList();
      });

  @override
  Future<ContentWithMedia?> getById(int id) async {
    final c = _contents[id];
    return c == null ? null : _join(c);
  }

  @override
  Future<List<ContentWithMedia>> getByIds(Iterable<int> ids) async => [
    for (final id in ids)
      if (_contents[id] case final Content c) _join(c),
  ];

  @override
  Future<List<ContentWithMedia>> listByTarget(int targetId) async =>
      (_contents.values.where((c) => c.targetId == targetId).toList()
            ..sort(_newestFirst))
          .map(_join)
          .toList();

  @override
  Future<Set<String>> existingRemoteIds(
    int targetId,
    ContentKind kind,
    Iterable<String> remoteIds,
  ) async {
    final wanted = remoteIds.toSet();
    return {
      for (final c in _contents.values)
        if (c.targetId == targetId &&
            c.kind == kind &&
            wanted.contains(c.remoteId))
          c.remoteId,
    };
  }

  @override
  Future<ContentInsertResult> insertIfNew(
    Content content,
    List<MediaFile> media,
  ) async {
    final indexes = media.map((m) => m.slideIndex).toSet();
    if (indexes.length != media.length) {
      throw ArgumentError.value(media, 'media', 'slide indexes must be unique');
    }
    final existing = _contents.values
        .where(
          (c) =>
              c.targetId == content.targetId &&
              c.kind == content.kind &&
              c.remoteId == content.remoteId,
        )
        .firstOrNull;
    if (existing != null) {
      return ContentInsertResult(contentId: existing.id, isNew: false);
    }
    final stored = content.copyWith(id: _nextContentId++);
    _contents[stored.id] = stored;
    for (final m in media) {
      final file = m.copyWith(id: _nextMediaId++, contentId: stored.id);
      _media[file.id] = file;
    }
    _feed.notify();
    return ContentInsertResult(contentId: stored.id, isNew: true);
  }

  @override
  Future<List<PendingMedia>> pendingMedia({int? limit}) async {
    final items =
        [
          for (final m in _media.values)
            // A media file never outlives its content row (cascade), so the
            // lookup cannot be null.
            if (m.status == MediaFileStatus.pending)
              PendingMedia(m, _contents[m.contentId]!),
        ]..sort((a, b) {
          final kind = a.content.kind.index.compareTo(b.content.kind.index);
          if (kind != 0) return kind;
          final detected = a.content.detectedAt.compareTo(b.content.detectedAt);
          if (detected != 0) return detected;
          final content = a.content.id.compareTo(b.content.id);
          return content != 0
              ? content
              : a.file.slideIndex.compareTo(b.file.slideIndex);
        });
    return limit == null ? items : items.take(limit).toList();
  }

  @override
  Future<int> resetInterruptedDownloads() async {
    var count = 0;
    for (final m in _media.values.toList()) {
      if (m.status == MediaFileStatus.downloading) {
        _media[m.id] = m.copyWith(status: MediaFileStatus.pending);
        count++;
      }
    }
    if (count > 0) _feed.notify();
    return count;
  }

  @override
  Future<void> updateMediaFile(MediaFile file) async {
    if (!_media.containsKey(file.id)) {
      throw StateError('No media file with id ${file.id}');
    }
    _media[file.id] = file;
    _feed.notify();
  }

  @override
  Future<void> updateContent(Content content) async {
    if (!_contents.containsKey(content.id)) {
      throw StateError('No content with id ${content.id}');
    }
    _contents[content.id] = content;
    _feed.notify();
  }

  @override
  Future<void> markViewed(Iterable<int> contentIds) async {
    var changed = false;
    for (final id in contentIds) {
      final c = _contents[id];
      if (c != null && !c.viewed) {
        _contents[id] = c.copyWith(viewed: true);
        changed = true;
      }
    }
    if (changed) _feed.notify();
  }

  @override
  Future<void> deleteByIds(Iterable<int> ids) async {
    if (_remove(ids)) _feed.notify();
  }

  @override
  Future<List<ContentWithMedia>> olderThan(DateTime cutoff) async =>
      (_contents.values.where((c) => c.postedAt.isBefore(cutoff)).toList()
            ..sort((a, b) => a.postedAt.compareTo(b.postedAt)))
          .map(_join)
          .toList();

  @override
  Future<Map<int, int>> storageBytesByTarget() async {
    final totals = <int, int>{};
    for (final m in _media.values) {
      final size = m.sizeBytes;
      if (m.status != MediaFileStatus.done || size == null) continue;
      final targetId = _contents[m.contentId]!.targetId;
      totals[targetId] = (totals[targetId] ?? 0) + size;
    }
    return totals;
  }
}
