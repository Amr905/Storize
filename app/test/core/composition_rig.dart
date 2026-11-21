// drift is a dependency of storize_data; the in-memory database needs it here.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:storize_app/core/composition.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/log/log.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_data/update/update.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_model/storize_model.dart';

import '../features/lock/lock_fakes.dart';

final DateTime t0 = DateTime.utc(2026, 11, 20, 8);

/// Fails the test if anything reaches the network.
final class NoNetwork implements IgHttp, CdnHttp {
  int sends = 0;

  @override
  Future<IgReply> send(IgRequest request) async {
    sends++;
    throw StateError('network must not be used');
  }

  @override
  Future<CdnResponse> get(Uri uri, {Map<String, String> headers = const {}}) {
    sends++;
    throw StateError('network must not be used');
  }
}

/// A page driver that must never open.
final class NoPages implements PageDriver {
  @override
  Future<PageSession> open(PageSessionConfig config) =>
      throw StateError('no WebView in tests');
}

/// Everything a composition test needs, over an in-memory database.
final class CompositionRig {
  CompositionRig({
    this.background = false,
    DateTime? now,
    MediaCache Function(FakeMediaCache inner)? wrapCache,
  }) : clock = FakeClock(now ?? t0) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = StorizeDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('storize_rig');
    diagnostics = StorizeDiagnostics.create(
      tmp,
      clock: clock,
      release: true,
    );
    parts = CompositionParts(
      db: db,
      settings: settings,
      sessions: sessions,
      gallery: FakeGalleryStore(cache: cache),
      cache: wrapCache?.call(cache) ?? cache,
      storage: FakeStorageInfo(),
      igHttp: network,
      cdnHttp: network,
      pageDriver: NoPages(),
      hookSource: () async {
        hookLoads++;
        return '// hook';
      },
      seenStore: InMemorySeenBreakerStore(),
      log: log,
      scheduler: scheduler,
      enqueuer: enqueuer,
      updateChecker: UpdateChecker(),
      currentVersion: '0.1.0',
      pins: FakePinStore(),
      biometric: FakeBiometric(),
      crashMarker: diagnostics.marker,
      clock: clock,
      closers: [
        () async => closed++,
        db.close,
      ],
    );
    composition = AppComposition.assemble(parts, background: background);
  }

  final bool background;
  final FakeClock clock;
  final FakeSettingsRepo settings = FakeSettingsRepo();
  final FakeSessionStore sessions = FakeSessionStore();
  final FakeMediaCache cache = FakeMediaCache();
  final NoNetwork network = NoNetwork();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final FakeScheduler scheduler = FakeScheduler();
  final RecordingEnqueuer enqueuer = RecordingEnqueuer();
  int hookLoads = 0;
  int closed = 0;

  late final StorizeDatabase db;
  late final Directory tmp;
  late final StorizeDiagnostics diagnostics;
  late final CompositionParts parts;
  late final AppComposition composition;

  /// Inserts a target and a content row with one media file; returns
  /// `(contentId, mediaFileId)`.
  Future<(int, int)> addMedia({
    MediaFileStatus status = MediaFileStatus.done,
    String remoteId = 'r1',
    String remoteUserId = '100',
  }) async {
    final t = await composition.targets.insert(
      Target(
        id: Target.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: remoteUserId,
        username: 'user$remoteUserId',
        category: TargetCategory.public,
        postsWatermarkAt: t0,
        addedAt: t0,
      ),
    );
    final r = await composition.content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: t.id,
        kind: ContentKind.story,
        remoteId: remoteId,
        postedAt: t0,
        slideCount: 1,
        detectedAt: t0,
      ),
      [
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: 0,
          mediaType: MediaType.photo,
          sourceUrl: 'https://example.invalid/m',
          status: status,
        ),
      ],
    );
    final got = await composition.content.getById(r.contentId);
    return (r.contentId, got!.media.single.id);
  }

  Future<void> dispose() async {
    await composition.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  }
}

/// Records roll-over requests.
final class RecordingEnqueuer implements DownloadEnqueuer {
  final List<bool> calls = [];

  @override
  Future<void> enqueueDownload({required bool wifiOnly}) async =>
      calls.add(wifiOnly);
}

/// A cache whose thumbnail sweep fails; everything else is the inner cache.
final class ThumbSweepFails implements MediaCache {
  ThumbSweepFails(this.inner);

  final MediaCache inner;

  @override
  Future<int> cleanupOrphanThumbnails(Set<int> liveMediaIds) async =>
      throw StateError('/private/path/secret.webp');

  @override
  Future<void> append(int id, Stream<List<int>> bytes) =>
      inner.append(id, bytes);

  @override
  Future<int> cleanupOrphans(Set<int> ids) => inner.cleanupOrphans(ids);

  @override
  Future<String> completedPath(int id) => inner.completedPath(id);

  @override
  Future<void> deleteThumbnail(int id) => inner.deleteThumbnail(id);

  @override
  Future<void> discard(int id) => inner.discard(id);

  @override
  Future<int> partialLength(int id) => inner.partialLength(id);

  @override
  Future<String> writeThumbnail(int id, List<int> bytes) =>
      inner.writeThumbnail(id, bytes);
}
