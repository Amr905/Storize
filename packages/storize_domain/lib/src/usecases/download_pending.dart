// StateError is what the repo contract throws for a row deleted meanwhile.
// ignore_for_file: avoid_catching_errors, prefer_initializing_formals

import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/activity_event.dart';
import 'package:storize_domain/src/entities/content.dart';
import 'package:storize_domain/src/entities/content_filter.dart';
import 'package:storize_domain/src/entities/content_with_media.dart';
import 'package:storize_domain/src/entities/governor_lease.dart';
import 'package:storize_domain/src/entities/media_file.dart';
import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/ports/gallery_store.dart';
import 'package:storize_domain/src/ports/media_cache.dart';
import 'package:storize_domain/src/ports/storage_info.dart';
import 'package:storize_domain/src/repos/activity_repo.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/governor_lease_repo.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_model/storize_model.dart';

/// Builds the gallery file name (TECH_SPEC §3 "Files").
///
/// The signature matches `displayNameFor` in `storize_data`, which the app
/// passes in. The domain cannot import `storize_data`.
typedef DisplayNameBuilder = String Function({
  required String username,
  required DateTime postedAt,
  required String remoteId,
  required String ext,
  int? slideIndex,
});

/// Builds the single gallery folder segment for a username.
///
/// The signature matches `relativeDirFor` in `storize_data`.
typedef RelativeDirBuilder = String Function(String username);

/// Where new files are saved right now (FR-79): the gallery, or private
/// storage when the user hides Storize's files from it. Read before every
/// save, so a changed setting applies to the next file.
typedef StorageTargetResolver = Future<StorageTarget> Function();

/// Looks up a file that is already in the gallery folder [relativeDir] under
/// [displayName], or returns null.
///
/// It lets a re-run adopt a file that was saved just before a kill instead of
/// saving it twice (NFR-7). It is optional because `GalleryStore` has no such
/// method yet; see the T-018 report.
typedef GalleryFileFinder = Future<GalleryFile?> Function({
  required String relativeDir,
  required String displayName,
});

/// Why a [DownloadPending] run ended.
enum DownloadStopReason {
  /// No PENDING item was left to try.
  completed,

  /// The time budget ran out. Remaining items roll over to the next run.
  deadline,

  /// Free space is under 200 MiB (NFR-13). `STORAGE_PAUSED` was written.
  storagePaused,

  /// The gallery is full (`GalleryStorageFull`). `STORAGE_PAUSED` was written.
  galleryStorageFull,

  /// The gallery refused the write (`GalleryPermissionDenied`). An event was
  /// written and the item stays PENDING.
  permissionDenied,

  /// The session is invalid or the account restricted (BR-7). No attempt was
  /// charged to the item.
  sessionProblem,

  /// Instagram asked us to slow down. No attempt was charged to the item.
  rateLimited,

  /// Another run is active in this object; nothing was done.
  alreadyRunning,

  /// Another instance or isolate holds the downloads lease (or it was lost
  /// mid-run). Nothing was done, or the run stopped before the next item.
  busy,
}

/// New files of one target and kind in one run, for notifications (EC-8).
@immutable
final class DownloadCounts {
  /// Creates counts.
  const DownloadCounts({
    required this.targetId,
    required this.kind,
    required this.files,
    required this.contents,
    required this.failed,
    required this.removed,
  });

  /// The target.
  final int targetId;

  /// Story or post.
  final ContentKind kind;

  /// Media files saved in this run.
  final int files;

  /// Content items that got at least one file in this run.
  final int contents;

  /// Media files that became FAILED in this run.
  final int failed;

  /// Content items found removed before download (EC-7, EC-21).
  final int removed;

  @override
  bool operator ==(Object other) =>
      other is DownloadCounts &&
      other.targetId == targetId &&
      other.kind == kind &&
      other.files == files &&
      other.contents == contents &&
      other.failed == failed &&
      other.removed == removed;

  @override
  int get hashCode =>
      Object.hash(targetId, kind, files, contents, failed, removed);

  @override
  String toString() =>
      'DownloadCounts(target: $targetId, ${kind.name}, files: $files, '
      'contents: $contents, failed: $failed, removed: $removed)';
}

/// One failed download attempt. Carries no URL, path or file name.
@immutable
final class DownloadFailure {
  /// Creates a failure record.
  const DownloadFailure({
    required this.mediaFileId,
    required this.contentId,
    required this.code,
    required this.attempts,
    required this.isFinal,
  });

  /// The media file.
  final int mediaFileId;

  /// Its content.
  final int contentId;

  /// A short code such as `url_expired`, `http_500`, `network`, `empty_file`,
  /// `gallery_<CODE>`, `refresh_<reason>` or `removed`.
  final String code;

  /// The attempts used so far.
  final int attempts;

  /// True when the file is now FAILED (no more retries).
  final bool isFinal;

  @override
  String toString() =>
      'DownloadFailure(file: $mediaFileId, $code, attempts: $attempts, '
      'final: $isFinal)';
}

/// The outcome of [DownloadPending.run]. Never contains URLs or paths.
@immutable
final class DownloadPendingResult {
  /// Creates a result. The lists are copied into unmodifiable lists.
  DownloadPendingResult({
    required this.stopReason,
    required this.remaining,
    required List<DownloadCounts> counts,
    required List<DownloadFailure> failures,
  }) : counts = List.unmodifiable(counts),
       failures = List.unmodifiable(failures);

  /// Why the run ended.
  final DownloadStopReason stopReason;

  /// How many media files are still PENDING when the run ended. It includes
  /// files whose attempt failed in this run and will be retried next time.
  final int remaining;

  /// New files per target and kind. Targets without activity are absent.
  final List<DownloadCounts> counts;

  /// Every failed attempt of this run.
  final List<DownloadFailure> failures;

  /// Files saved in this run, over all targets.
  int get totalFiles => counts.fold(0, (a, c) => a + c.files);

  @override
  String toString() =>
      'DownloadPendingResult($stopReason, remaining: $remaining, '
      'files: $totalFiles, failures: ${failures.length})';
}

class _Tally {
  int files = 0;
  int failed = 0;
  int removed = 0;
  final Set<int> contents = {};
}

class _RunState {
  _RunState(this.deadline, this.policy, this.onlyContentIds);

  final DateTime deadline;
  final ExtractionPolicy policy;
  final Set<int>? onlyContentIds;
  final Set<int> touched = {};
  final Map<(int, ContentKind), _Tally> tallies = {};
  final List<DownloadFailure> failures = [];
  DownloadStopReason? stop;
  bool lowWritten = false;
  bool cut = false;

  _Tally tally(int targetId, ContentKind kind) =>
      tallies.putIfAbsent((targetId, kind), _Tally.new);
}

sealed class _Step {
  const _Step();
}

final class _Ok extends _Step {
  const _Ok();
}

final class _Fail extends _Step {
  const _Fail(this.code);
  final String code;
}

final class _Gone extends _Step {
  const _Gone({required this.wholeContent});
  final bool wholeContent;
}

final class _RefreshedUrl extends _Step {
  const _RefreshedUrl(this.url);
  final String url;
}

final class _Stop extends _Step {
  const _Stop(this.reason);
  final DownloadStopReason reason;
}

/// Downloads every PENDING media file (FR-22, FR-25, FR-33, NFR-7, NFR-13).
///
/// Per file: stream the CDN file into the private `.part` cache (resuming
/// with `Range` from the bytes already there), save it into the gallery under
/// the target's **current** username, then mark the row DONE. The `.part` is
/// discarded only after the row is DONE, so a kill at any step leaves a state
/// the next run repairs:
///
/// - Killed mid-stream: the row is DOWNLOADING with a partial `.part`. The
///   next run resets it to PENDING and resumes from the `.part` length.
/// - Killed with a complete `.part` that is not saved: the resume asks for
///   no new bytes (a 416 is treated as complete), then saves.
/// - Killed after the gallery save, before the row update: the `.part` is
///   still there, and the file is **adopted** through [GalleryFileFinder]
///   instead of being saved twice.
/// - Killed after the row is DONE, before the discard: a stray `.part` is
///   left and `cleanupOrphans` removes it.
///
/// An attempt is charged only when it fails, never for a kill. A run never
/// appends to the same file from two places: items are processed one by one,
/// and a second `run` on the same object returns [DownloadStopReason
/// .alreadyRunning].
///
/// Ends at the deadline, at the first "stop everything" condition
/// (storage, gallery permission, session, rate limit), or when nothing is
/// left to try. An item already in flight when the deadline passes is
/// finished first, so the budget must leave headroom (about 8 of 10 minutes).
final class DownloadPending {
  /// Creates the use case.
  DownloadPending({
    required ContentRepo content,
    required TargetRepo targets,
    required ActivityRepo activity,
    required ContentPlatform platform,
    required MediaCache cache,
    required GalleryStore gallery,
    required StorageInfo storage,
    required Clock clock,
    required GovernorLeaseRepo leases,
    required DisplayNameBuilder displayName,
    required RelativeDirBuilder relativeDir,
    GalleryFileFinder? findExisting,
    StorageTargetResolver? storageTarget,
    String? holder,
    this.budget = const Duration(minutes: 8),
  }) : _content = content,
       _targets = targets,
       _activity = activity,
       _platform = platform,
       _cache = cache,
       _gallery = gallery,
       _storage = storage,
       _clock = clock,
       _leases = leases,
       _holder = holder ?? _uniqueHolder(clock),
       _displayName = displayName,
       _relativeDir = relativeDir,
       _find = findExisting,
       _storageTarget = storageTarget;

  /// The default time budget of a run (TECH_SPEC §1, "10-minute rule").
  final Duration budget;

  /// The `extras` key the mapper sets for slides it had to drop because the
  /// video has only a DASH manifest.
  static const String unsupportedStreamKey = 'unsupported_stream';

  final ContentRepo _content;
  final TargetRepo _targets;
  final ActivityRepo _activity;
  final ContentPlatform _platform;
  final MediaCache _cache;
  final GalleryStore _gallery;
  final StorageInfo _storage;
  final Clock _clock;
  final DisplayNameBuilder _displayName;
  final RelativeDirBuilder _relativeDir;
  final GalleryFileFinder? _find;
  final StorageTargetResolver? _storageTarget;
  final GovernorLeaseRepo _leases;
  final String _holder;

  /// The reserved lease key of the whole downloads run (`-1` is another
  /// reserved key; real login accounts are positive).
  static const int leaseKey = -2;

  /// How long the downloads lease lasts; renewed before every item.
  static const Duration leaseTtl = Duration(minutes: 10);

  static int _seq = 0;

  static String _uniqueHolder(Clock clock) =>
      'downloads-${clock.now().microsecondsSinceEpoch}-${_seq++}-'
      '${Object().hashCode}';

  bool _running = false;

  /// Runs until [deadline] (default: now + [budget]).
  ///
  /// [policy] is the extraction policy used when a URL must be refreshed.
  ///
  /// With [onlyContentIds] only the pending files of those content rows are
  /// tried (T-052: "Save" in the profile preview); every other pending file
  /// is left alone.
  Future<DownloadPendingResult> run({
    DateTime? deadline,
    ExtractionPolicy policy = ExtractionPolicy.directOnly,
    Set<int>? onlyContentIds,
  }) async {
    if (_running) {
      return DownloadPendingResult(
        stopReason: DownloadStopReason.alreadyRunning,
        remaining: (await _content.pendingMedia()).length,
        counts: const [],
        failures: const [],
      );
    }
    _running = true;
    try {
      final lease = await _leases.acquire(
        accountId: leaseKey,
        holder: _holder,
        ttl: leaseTtl,
        initialBucket: GovernorBucket(
          tokens: 0,
          lastRefillAt: _clock.now().toUtc(),
        ),
      );
      if (lease == null) {
        return DownloadPendingResult(
          stopReason: DownloadStopReason.busy,
          remaining: (await _content.pendingMedia()).length,
          counts: const [],
          failures: const [],
        );
      }
      try {
        return await _run(
          _RunState(
            deadline ?? _clock.now().add(budget),
            policy,
            onlyContentIds,
          ),
        );
      } finally {
        await _leases.release(accountId: leaseKey, holder: _holder);
      }
    } finally {
      _running = false;
    }
  }

  Future<DownloadPendingResult> _run(_RunState s) async {
    // A kill leaves rows DOWNLOADING (NFR-7). Their `.part` files stay.
    await _content.resetInterruptedDownloads();
    await _cleanOrphanParts();
    await _repairContentStatuses();

    while (true) {
      if (!_clock.now().isBefore(s.deadline)) {
        s.stop = DownloadStopReason.deadline;
        break;
      }
      final next = await _nextPending(s);
      if (next == null) break;
      if (!await _leases.renew(
        accountId: leaseKey,
        holder: _holder,
        ttl: leaseTtl,
      )) {
        s.stop = DownloadStopReason.busy; // Lost the lease: stop at once.
        break;
      }
      if (await _storageStops(s)) break;
      s.touched.add(next.file.id);
      await _process(next, s);
      if (s.stop != null) break;
    }

    final remaining = (await _content.pendingMedia()).length;
    var reason = s.stop ?? DownloadStopReason.completed;
    if (reason == DownloadStopReason.deadline && remaining == 0) {
      reason = DownloadStopReason.completed;
    }
    await _writeSummaryEvents(s);
    return DownloadPendingResult(
      stopReason: reason,
      remaining: remaining,
      counts: [
        for (final e in s.tallies.entries)
          DownloadCounts(
            targetId: e.key.$1,
            kind: e.key.$2,
            files: e.value.files,
            contents: e.value.contents.length,
            failed: e.value.failed,
            removed: e.value.removed,
          ),
      ],
      failures: s.failures,
    );
  }

  /// A kill between "row DONE" and "content settled" leaves a PENDING content
  /// whose files are all finished. Settle those first (NFR-7).
  Future<void> _repairContentStatuses() async {
    final open = await _content
        .watchLibrary(ContentFilter(statuses: const {ContentStatus.pending}))
        .first;
    for (final c in open) {
      await _settle(c.content.id, removedWhole: false);
    }
  }

  Future<void> _cleanOrphanParts() async {
    try {
      final pending = await _content.pendingMedia();
      await _cache.cleanupOrphans({for (final p in pending) p.file.id});
    } on Exception {
      // Cleaning is best effort; a failure must not stop the downloads.
    }
  }

  Future<PendingMedia?> _nextPending(_RunState s) async {
    final only = s.onlyContentIds;
    for (final p in await _content.pendingMedia()) {
      if (only != null && !only.contains(p.content.id)) continue;
      if (!s.touched.contains(p.file.id)) return p;
    }
    return null;
  }

  /// Returns true when the run must stop because of low space (NFR-13).
  Future<bool> _storageStops(_RunState s) async {
    int free;
    try {
      free = await _storage.freeBytes();
    } on Object {
      return false; // Unknown: never stop because of it.
    }
    if (free < 0) return false; // Nonsense value: treat as unknown.
    if (free < StoragePolicy.pauseBytes) {
      await _event(
        ActivityType.storagePaused,
        Severity.error,
        payload: {'reason': 'low_space', 'freeBytes': free},
      );
      s.stop = DownloadStopReason.storagePaused;
      return true;
    }
    if (free < StoragePolicy.lowSpaceBytes && !s.lowWritten) {
      s.lowWritten = true;
      await _event(
        ActivityType.storageLow,
        Severity.warn,
        payload: {'freeBytes': free},
      );
    }
    return false;
  }

  Future<void> _event(
    ActivityType type,
    Severity severity, {
    int? targetId,
    int count = 1,
    Map<String, Object?> payload = const {},
  }) async {
    await _activity.add(
      ActivityEvent(
        id: ActivityEvent.unsavedId,
        at: _clock.now(),
        type: type,
        severity: severity,
        targetId: targetId,
        count: count,
        payload: payload,
      ),
    );
  }

  Future<void> _writeSummaryEvents(_RunState s) async {
    for (final e in s.tallies.entries) {
      final t = e.value;
      if (t.contents.isEmpty) continue;
      final story = e.key.$2 != ContentKind.post;
      await _event(
        story ? ActivityType.downloadedStories : ActivityType.downloadedPosts,
        t.failed > 0 ? Severity.warn : Severity.info,
        targetId: e.key.$1,
        count: t.contents.length,
        payload: {'files': t.files, 'failed': t.failed},
      );
    }
  }

  Future<void> _process(PendingMedia p, _RunState s) async {
    final target = await _targets.getById(p.content.targetId);
    if (target == null) return; // The target was removed meanwhile.
    var file = p.file.copyWith(status: MediaFileStatus.downloading);
    try {
      await _content.updateMediaFile(file);
    } on StateError {
      return; // The row was deleted meanwhile.
    }

    final _Step step;
    try {
      step = await _transfer(file, p.content, target, s, (f) => file = f);
    } on GalleryPermissionDenied {
      return _stopItem(file, s, DownloadStopReason.permissionDenied);
    } on GalleryStorageFull {
      return _stopItem(file, s, DownloadStopReason.galleryStorageFull);
    } on GalleryWriteFailed catch (e) {
      await _discardQuietly(file.id);
      return _fail(file, p.content, 'gallery_${e.code}', s);
    } on MediaStreamException catch (e) {
      return _fail(file, p.content, _streamCode(e), s);
    } on Exception {
      return _fail(file, p.content, 'io_error', s);
    }

    switch (step) {
      case _Ok():
        await _settle(p.content.id, removedWhole: false);
      case _Fail(:final code):
        await _fail(file, p.content, code, s);
      case _Gone(:final wholeContent):
        await _gone(file, p.content, s, wholeContent: wholeContent);
      case _Stop(:final reason):
        await _stopItem(file, s, reason);
      case _RefreshedUrl():
        break; // Handled inside `_transfer`; never returned from it.
    }
  }

  String _streamCode(MediaStreamException e) => switch (e) {
    ExpiredMediaUrl() => 'url_expired',
    MediaStreamFailure(:final statusCode) =>
      statusCode == null ? 'network' : 'http_$statusCode',
  };

  /// Streams, saves and marks the row DONE. [track] keeps the caller's copy of
  /// the row current.
  Future<_Step> _transfer(
    MediaFile start,
    Content content,
    Target target,
    _RunState s,
    void Function(MediaFile) track,
  ) async {
    var file = start;
    final photo = file.mediaType == MediaType.photo;
    final ext = photo ? 'jpg' : 'mp4';
    final relativeDir = _folderFor(target, content);
    final name = _displayName(
      username: target.username,
      postedAt: content.postedAt,
      remoteId: content.remoteId,
      ext: ext,
      slideIndex: content.kind == ContentKind.post ? file.slideIndex : null,
    );

    // Adopt a file a killed run saved but did not record (NFR-7).
    final adopted = await _adopt(file, relativeDir, name);
    if (adopted != null) {
      await _markDone(file, adopted, content, s, track);
      return const _Ok();
    }

    var url = file.sourceUrl;
    var refreshed = false;
    while (true) {
      final from = await _cache.partialLength(file.id);
      try {
        s.cut = false;
        await _cache.append(
          file.id,
          _untilDeadline(_platform.openMedia(url, fromByte: from), s),
        );
        break;
      } on ExpiredMediaUrl {
        if (refreshed) return const _Fail('url_expired');
        refreshed = true;
        final r = await _refresh(file, content, target, s.policy);
        if (r is! _RefreshedUrl) return r;
        url = r.url;
        file = file.copyWith(sourceUrl: url);
        track(file);
        await _content.updateMediaFile(file);
      } on MediaStreamFailure catch (e) {
        // 416 on a resume: the `.part` already holds the whole file.
        if (e.statusCode == 416 && from > 0) break;
        rethrow;
      }
    }

    // Cut at the deadline: keep the `.part`, charge no attempt (resumes next).
    if (s.cut) return const _Stop(DownloadStopReason.deadline);
    if (await _cache.partialLength(file.id) == 0) {
      await _discardQuietly(file.id);
      return const _Fail('empty_file');
    }
    final path = await _cache.completedPath(file.id);
    final saved = await _gallery.save(
      sourcePath: path,
      relativeDir: relativeDir,
      displayName: name,
      mime: photo ? 'image/jpeg' : 'video/mp4',
      target: await _target(),
    );
    await _markDone(file, saved, content, s, track);
    return const _Ok();
  }

  /// The storage for the next file. A failing setting read means the default
  /// (the gallery): a download must not stop because of it.
  Future<StorageTarget> _target() async {
    final resolve = _storageTarget;
    if (resolve == null) return StorageTarget.gallery;
    try {
      return await resolve();
    } on Object {
      return StorageTarget.gallery;
    }
  }

  /// Ends [src] cleanly once the deadline has passed (checked per chunk).
  Stream<List<int>> _untilDeadline(Stream<List<int>> src, _RunState s) async* {
    await for (final chunk in src) {
      yield chunk;
      if (!_clock.now().isBefore(s.deadline)) {
        s.cut = true;
        return; // Cancels the source.
      }
    }
  }

  /// The gallery folder: `<username>`, or for a highlight item
  /// `<username>/Highlights/<title>` (TECH_SPEC §17.5). The title goes through
  /// the same segment sanitizer as the username.
  String _folderFor(Target target, Content content) {
    final base = _relativeDir(target.username);
    if (content.kind != ContentKind.highlight) return base;
    final title = content.extras[HighlightExtras.title];
    return '$base/Highlights/${_relativeDir(title is String ? title : '')}';
  }

  Future<GalleryFile?> _adopt(
    MediaFile file,
    String relativeDir,
    String name,
  ) async {
    final uri = file.contentUri;
    if (uri != null && await _gallery.exists(uri)) {
      final size = await _gallery.size(uri);
      if (size != null) {
        return GalleryFile(
          uri: uri,
          sizeBytes: size,
          relativePath: file.relativePath ?? relativeDir,
          displayName: file.displayName ?? name,
        );
      }
    }
    final find = _find;
    // A `.part` means an earlier run reached this file; only then can a
    // gallery copy exist without a DONE row.
    if (find != null && await _cache.partialLength(file.id) > 0) {
      final found = await find(relativeDir: relativeDir, displayName: name);
      if (found == null || found.displayName != name) return null;
      // Never take a file another row already owns (BR-9).
      final all = await _content.watchLibrary(ContentFilter()).first;
      for (final c in all) {
        for (final m in c.media) {
          if (m.id != file.id && m.contentUri == found.uri) return null;
        }
      }
      return found;
    }
    return null;
  }

  Future<void> _markDone(
    MediaFile file,
    GalleryFile saved,
    Content content,
    _RunState s,
    void Function(MediaFile) track,
  ) async {
    final done = file.copyWith(
      status: MediaFileStatus.done,
      contentUri: saved.uri,
      relativePath: saved.relativePath,
      displayName: saved.displayName,
      sizeBytes: saved.sizeBytes,
      downloadedAt: _clock.now(),
    );
    try {
      await _content.updateMediaFile(done);
    } on StateError {
      // The user deleted the item while it was saving. Remove the file, so
      // the gallery keeps nothing the app does not know (BR-9).
      try {
        await _gallery.delete(saved.uri);
      } on Exception {
        // Best effort.
      }
      await _discardQuietly(file.id);
      return;
    }
    track(done);
    // Only now is the `.part` disposable.
    await _discardQuietly(file.id);
    s.tally(content.targetId, content.kind)
      ..files += 1
      ..contents.add(content.id);
    // Thumbnails: no port generates the WebP yet (follow-up in the report).
  }

  Future<_Step> _refresh(
    MediaFile file,
    Content content,
    Target target,
    ExtractionPolicy policy,
  ) async {
    final RemoteContent? item;
    if (content.kind == ContentKind.highlight) {
      final hid = content.extras[HighlightExtras.id];
      if (hid is! String) return const _Gone(wholeContent: true);
      final r = await _platform.fetchHighlightItems([hid], policy: policy);
      switch (r) {
        case Err(:final failure):
          return _failureStep(failure);
        case Ok(:final value):
          item = _find1(value[hid], content.remoteId);
      }
    } else if (content.kind == ContentKind.story) {
      final r = await _platform.fetchStories([
        target.remoteUserId,
      ], policy: policy);
      switch (r) {
        case Err(:final failure):
          return _failureStep(failure);
        case Ok(:final value):
          item = _find1(value[target.remoteUserId], content.remoteId);
      }
    } else {
      final r = await _platform.fetchNewPosts(
        target.remoteUserId,
        content.postedAt.subtract(const Duration(seconds: 1)),
        policy: policy,
      );
      switch (r) {
        case Err(:final failure):
          return _failureStep(failure);
        case Ok(:final value):
          item = _find1(value, content.remoteId);
      }
    }
    if (item == null) return const _Gone(wholeContent: true);
    for (final slide in item.slides) {
      if (slide.index == file.slideIndex) return _RefreshedUrl(slide.url);
    }
    return const _Gone(wholeContent: false);
  }

  RemoteContent? _find1(List<RemoteContent>? list, String remoteId) {
    for (final c in list ?? const <RemoteContent>[]) {
      if (c.remoteId == remoteId) return c;
    }
    return null;
  }

  _Step _failureStep(Failure f) => switch (f) {
    SessionInvalid() ||
    AccountRestricted() => const _Stop(DownloadStopReason.sessionProblem),
    RateLimited() => const _Stop(DownloadStopReason.rateLimited),
    TargetNotFound() => const _Fail('refresh_target_not_found'),
    TargetNotVisible() => const _Fail('refresh_target_not_visible'),
    NetworkFailure() => const _Fail('refresh_network'),
    SchemaChanged() => const _Fail('refresh_schema_changed'),
    UnknownFailure() => const _Fail('refresh_unknown'),
  };

  /// A stop that is not the item's fault: back to PENDING, no attempt used.
  Future<void> _stopItem(
    MediaFile file,
    _RunState s,
    DownloadStopReason reason,
  ) async {
    await _updateQuietly(file.copyWith(status: MediaFileStatus.pending));
    s.stop = reason;
    switch (reason) {
      case DownloadStopReason.permissionDenied:
        await _event(
          ActivityType.storagePaused,
          Severity.error,
          payload: {'reason': 'gallery_permission_denied'},
        );
      case DownloadStopReason.galleryStorageFull:
        await _event(
          ActivityType.storagePaused,
          Severity.error,
          payload: {'reason': 'gallery_storage_full'},
        );
      case _:
        break;
    }
  }

  /// Charges one attempt. At [MediaFile.maxAttempts] the file is FAILED.
  Future<void> _fail(
    MediaFile file,
    Content content,
    String code,
    _RunState s,
  ) async {
    final attempts = file.attempts + 1;
    final dead = attempts >= MediaFile.maxAttempts;
    await _updateQuietly(
      file.copyWith(
        attempts: attempts,
        status: dead ? MediaFileStatus.failed : MediaFileStatus.pending,
      ),
    );
    s.failures.add(
      DownloadFailure(
        mediaFileId: file.id,
        contentId: content.id,
        code: code,
        attempts: attempts,
        isFinal: dead,
      ),
    );
    if (dead) {
      await _discardQuietly(file.id);
      s.tally(content.targetId, content.kind).failed += 1;
      await _settle(content.id, removedWhole: false);
    }
  }

  /// The item no longer exists remotely (EC-7, EC-21).
  Future<void> _gone(
    MediaFile file,
    Content content,
    _RunState s, {
    required bool wholeContent,
  }) async {
    await _discardQuietly(file.id);
    if (!wholeContent) {
      await _updateQuietly(file.copyWith(status: MediaFileStatus.failed));
      s.failures.add(
        DownloadFailure(
          mediaFileId: file.id,
          contentId: content.id,
          code: 'removed',
          attempts: file.attempts,
          isFinal: true,
        ),
      );
      s.tally(content.targetId, content.kind).failed += 1;
      await _settle(content.id, removedWhole: false);
      return;
    }
    final current = await _content.getById(content.id);
    for (final m in current?.media ?? const <MediaFile>[]) {
      if (m.status == MediaFileStatus.pending ||
          m.status == MediaFileStatus.downloading) {
        await _updateQuietly(m.copyWith(status: MediaFileStatus.failed));
        await _discardQuietly(m.id);
      }
    }
    s.tally(content.targetId, content.kind).removed += 1;
    await _settle(content.id, removedWhole: true);
    await _event(
      ActivityType.removedBeforeDownload,
      Severity.info,
      targetId: content.targetId,
      payload: {'kind': content.kind.dbValue, 'remoteId': content.remoteId},
    );
  }

  /// Sets the content status from its slides once none is left to try.
  Future<void> _settle(int contentId, {required bool removedWhole}) async {
    final c = await _content.getById(contentId);
    if (c == null) return;
    final media = c.media;
    // No slide rows (every slide was unsupported): nothing to download, and
    // never DONE.
    if (media.isEmpty && !_hasUnsupported(c.content)) return;
    final open = media.any(
      (m) =>
          m.status == MediaFileStatus.pending ||
          m.status == MediaFileStatus.downloading,
    );
    if (open) return;
    final done = media.where((m) => m.status == MediaFileStatus.done).length;
    final failed = media.any((m) => m.status == MediaFileStatus.failed);
    final ContentStatus status;
    if (removedWhole && done == 0) {
      status = ContentStatus.removedBeforeDownload;
    } else if (failed || _hasUnsupported(c.content)) {
      status = ContentStatus.partial; // EC-21: keep the slides that worked.
    } else {
      status = ContentStatus.done;
    }
    if (status == c.content.status) return;
    try {
      await _content.updateContent(c.content.copyWith(status: status));
    } on StateError {
      // Deleted meanwhile.
    }
  }

  bool _hasUnsupported(Content c) {
    final v = c.extras[unsupportedStreamKey];
    return v != null && v != false && !(v is Iterable && v.isEmpty);
  }

  Future<void> _updateQuietly(MediaFile file) async {
    try {
      await _content.updateMediaFile(file);
    } on StateError {
      // Deleted meanwhile.
    }
  }

  Future<void> _discardQuietly(int id) async {
    try {
      await _cache.discard(id);
    } on Exception {
      // `cleanupOrphans` removes it later.
    }
  }
}
