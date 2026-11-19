import 'package:storize_domain/src/usecases/apply_retention.dart';
import 'package:storize_domain/src/usecases/delete_content.dart';
import 'package:storize_domain/src/usecases/remove_target.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../support.dart' as s;

/// A gallery that records, for each `delete`, whether the content row still
/// existed at that moment (to prove file-before-row ordering).
final class SpyGallery implements GalleryStore {
  SpyGallery(this.inner, this.rowExists);

  final FakeGalleryStore inner;
  final Future<bool> Function(String uri) rowExists;
  final List<({String uri, bool rowStillThere})> deletes = [];

  @override
  Future<bool> delete(String contentUri) async {
    deletes.add((uri: contentUri, rowStillThere: await rowExists(contentUri)));
    return inner.delete(contentUri);
  }

  @override
  Future<bool> exists(String contentUri) => inner.exists(contentUri);

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => inner.save(
    sourcePath: sourcePath,
    relativeDir: relativeDir,
    displayName: displayName,
    mime: mime,
  );

  @override
  Future<int?> size(String contentUri) => inner.size(contentUri);
}

/// A media cache whose `discard` always fails.
final class ThrowingCache implements MediaCache {
  ThrowingCache(this.inner);

  final FakeMediaCache inner;

  @override
  Future<void> discard(int mediaFileId) async => throw StateError('boom');

  @override
  Future<void> append(int mediaFileId, Stream<List<int>> bytes) =>
      inner.append(mediaFileId, bytes);

  @override
  Future<int> cleanupOrphans(Set<int> keepIds) => inner.cleanupOrphans(keepIds);

  @override
  Future<String> completedPath(int mediaFileId) =>
      inner.completedPath(mediaFileId);

  @override
  Future<int> partialLength(int mediaFileId) =>
      inner.partialLength(mediaFileId);

  @override
  Future<String> writeThumbnail(int mediaFileId, List<int> webpBytes) =>
      inner.writeThumbnail(mediaFileId, webpBytes);
}

final class Harness {
  Harness({MediaCache Function(FakeMediaCache)? wrapCache, DateTime? now})
    : cache = FakeMediaCache(),
      clock = FakeClock(now ?? s.t0) {
    targets = FakeTargetRepo();
    content = FakeContentRepo(targets: targets);
    gallery = FakeGalleryStore(cache: cache);
    spy = SpyGallery(gallery, _rowForUri);
    settings = FakeSettingsRepo();
    checkRuns = FakeCheckRunRepo();
    deleteContent = DeleteContent(
      content: content,
      gallery: spy,
      cache: wrapCache?.call(cache) ?? cache,
      chunkSize: 2,
    );
    removeTarget = RemoveTarget(
      targets: targets,
      content: content,
      deleteContent: deleteContent,
    );
    retention = ApplyRetention(
      settings: settings,
      content: content,
      checkRuns: checkRuns,
      deleteContent: deleteContent,
      clock: clock,
    );
  }

  final FakeMediaCache cache;
  final FakeClock clock;
  late final FakeTargetRepo targets;
  late final FakeContentRepo content;
  late final FakeGalleryStore gallery;
  late final SpyGallery spy;
  late final FakeSettingsRepo settings;
  late final FakeCheckRunRepo checkRuns;
  late final DeleteContent deleteContent;
  late final RemoveTarget removeTarget;
  late final ApplyRetention retention;

  final Map<String, int> _uriToContent = {};

  Future<bool> _rowForUri(String uri) async {
    final id = _uriToContent[uri];
    return id != null && await content.getById(id) != null;
  }

  Future<Target> addTarget({String remoteUserId = '100', String name = 'a'}) =>
      targets.insert(s.target(remoteUserId: remoteUserId, username: name));

  /// Stores content with [slides] downloaded files in the fake gallery.
  /// Returns the content ID.
  Future<int> addContent(
    Target t, {
    required String remoteId,
    int slides = 1,
    DateTime? postedAt,
    DateTime? detectedAt,
    DateTime? downloadedAt,
    DateTime? expiresAt,
    ContentKind kind = ContentKind.story,
    bool withFiles = true,
  }) async {
    final files = <GalleryFile>[];
    if (withFiles) {
      for (var i = 0; i < slides; i++) {
        files.add(
          await gallery.save(
            sourcePath: 'none',
            relativeDir: 'Pictures/Storize/${t.username}',
            displayName: '$remoteId-$i.jpg',
            mime: 'image/jpeg',
          ),
        );
      }
    }
    final base = s.content(
      targetId: t.id,
      remoteId: remoteId,
      kind: kind,
      postedAt: postedAt,
      detectedAt: detectedAt,
      status: ContentStatus.done,
    );
    final c = expiresAt == null ? base : base.copyWith(expiresAt: expiresAt);
    final result = await content.insertIfNew(c, [
      for (var i = 0; i < slides; i++)
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: i,
          mediaType: MediaType.photo,
          sourceUrl: 'https://example.invalid/$remoteId/$i',
          status: withFiles ? MediaFileStatus.done : MediaFileStatus.pending,
          contentUri: withFiles ? files[i].uri : null,
          downloadedAt: downloadedAt,
        ),
    ]);
    for (final f in files) {
      _uriToContent[f.uri] = result.contentId;
    }
    return result.contentId;
  }
}
