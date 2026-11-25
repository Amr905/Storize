import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/content.dart';
import 'package:storize_domain/src/entities/media_file.dart';
import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/ports/diagnostic_log.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_domain/src/usecases/download_pending.dart';
import 'package:storize_model/storize_model.dart';

/// What happened to one previewed item.
enum PreviewSaveStatus {
  /// The files are in the gallery now.
  saved,

  /// The item was in the gallery already; nothing was downloaded.
  alreadySaved,

  /// The item could not be saved; see [PreviewItemResult.reason].
  failed,
}

/// The result for one previewed item.
@immutable
final class PreviewItemResult {
  /// Creates a result.
  const PreviewItemResult({
    required this.remoteId,
    required this.kind,
    required this.status,
    this.contentId,
    this.reason,
  });

  /// The item's remote id.
  final String remoteId;

  /// Story or post.
  final ContentKind kind;

  /// The outcome.
  final PreviewSaveStatus status;

  /// The stored content row, when there is one.
  final int? contentId;

  /// A short code for a failure: `no_media`, `not_stored`, `busy`,
  /// `storage_paused`, `gallery_permission`, `session`, `rate_limited`,
  /// `time_budget` or a download code (`network`, `url_expired`, ...).
  final String? reason;

  @override
  String toString() =>
      'PreviewItemResult(${kind.name}, ${status.name}, reason: $reason)';
}

/// The outcome of [SavePreviewItems.call].
@immutable
final class PreviewSaveResult {
  /// Creates the result.
  PreviewSaveResult({
    required this.target,
    required List<PreviewItemResult> items,
  }) : items = List.unmodifiable(items);

  /// The target the items were stored under.
  final Target target;

  /// One result per distinct input item, in input order.
  final List<PreviewItemResult> items;

  /// How many items are saved now.
  int get saved => _count(PreviewSaveStatus.saved);

  /// How many items were saved before.
  int get alreadySaved => _count(PreviewSaveStatus.alreadySaved);

  /// How many items failed.
  int get failed => _count(PreviewSaveStatus.failed);

  int _count(PreviewSaveStatus s) => items.where((i) => i.status == s).length;
}

/// Saves items the user picked in the profile preview, now, in the foreground
/// (FR-74).
///
/// 1. Finds the target (by user id) or, for an account that is not tracked,
///    creates a **preview-only** target: status `paused` with reason
///    [previewOnlyReason], so no check ever visits it and nothing downloads
///    on its own. (`Target` needs one track flag on, so "all off" is the
///    paused status. Tracking it later is [activatePreviewTarget].)
/// 2. Stores the content rows like a check does (`insertIfNew`, deduplicated
///    by remote id).
/// 3. Runs [DownloadPending] limited to those rows. Media is saved only
///    through `GalleryStore`, inside [DownloadPending].
/// 4. Reports saved, already saved or failed for each item.
final class SavePreviewItems {
  /// Creates the use case.
  SavePreviewItems({
    required this._targets,
    required this._content,
    required this._downloads,
    required this._platform,
    required this._clock,
    this._log,
  });

  final TargetRepo _targets;
  final ContentRepo _content;
  final DownloadPending _downloads;
  final ContentPlatform _platform;
  final Clock _clock;
  final DiagnosticLog? _log;

  /// `Target.statusReason` of a target that exists only to hold manually
  /// saved items.
  static const String previewOnlyReason = 'preview_only';

  /// Whether [target] was created by a preview save and is not tracked.
  static bool isPreviewOnly(Target target) =>
      target.status == TargetStatus.paused &&
      target.statusReason == previewOnlyReason;

  /// Starts normal tracking of a preview-only target (every track on, status
  /// active). Returns the target unchanged when it is tracked already.
  Future<Target> activatePreviewTarget(int targetId) async {
    final t = await _targets.getById(targetId);
    if (t == null) throw StateError('target_missing');
    if (!isPreviewOnly(t)) return t;
    final next = t.copyWith(
      status: TargetStatus.active,
      statusReason: null,
      trackStories: true,
      trackPosts: true,
      trackReels: true,
    );
    await _targets.update(next);
    return next;
  }

  /// Saves [items] of [user].
  ///
  /// [targetId] is the tracked target when the preview was opened from one;
  /// otherwise the target is looked up by `user.remoteUserId` and created if
  /// it is missing. [category] is used only when a target is created.
  Future<PreviewSaveResult> call({
    required RemoteUser user,
    required List<RemoteContent> items,
    int? targetId,
    TargetCategory category = TargetCategory.public,
  }) async {
    final target = await _targetFor(user, targetId, category);

    // Distinct by (kind, remote id), in input order.
    final seen = <(ContentKind, String)>{};
    final input = [
      for (final c in items)
        if (seen.add((c.kind, c.remoteId))) c,
    ];

    final contentIds = <(ContentKind, String), int>{};
    final newIds = <int>{};
    final noMedia = <(ContentKind, String)>{};
    for (final c in input) {
      final key = (c.kind, c.remoteId);
      if (c.slides.isEmpty) {
        noMedia.add(key);
        continue;
      }
      final r = await _content.insertIfNew(_row(target, c), _media(c));
      if (r.isNew) newIds.add(r.contentId);
      contentIds[key] = r.contentId;
    }

    // Rows that exist already may be done, or still wait for a download.
    final before = await _statusOf(target.id);
    final wanted = {
      for (final e in contentIds.entries)
        if (newIds.contains(e.value) || before[e.value] != ContentStatus.done)
          e.value,
    };

    var stop = DownloadStopReason.completed;
    var downloadError = false;
    DownloadPendingResult? ran;
    if (wanted.isNotEmpty) {
      try {
        ran = await _downloads.run(
          policy: ExtractionPolicy.directThenPage,
          onlyContentIds: wanted,
        );
        stop = ran.stopReason;
      } on Object {
        downloadError = true;
      }
    }

    final after = await _statusOf(target.id);
    final failureCodes = <int, String>{
      for (final f in ran?.failures ?? const <DownloadFailure>[])
        f.contentId: f.code,
    };
    final results = <PreviewItemResult>[];
    for (final c in input) {
      final key = (c.kind, c.remoteId);
      final id = contentIds[key];
      if (noMedia.contains(key)) {
        results.add(_failed(c, null, 'no_media'));
      } else if (id == null || !after.containsKey(id)) {
        results.add(_failed(c, id, 'not_stored'));
      } else if (!wanted.contains(id)) {
        results.add(
          PreviewItemResult(
            remoteId: c.remoteId,
            kind: c.kind,
            status: PreviewSaveStatus.alreadySaved,
            contentId: id,
          ),
        );
      } else if (after[id] == ContentStatus.done) {
        results.add(
          PreviewItemResult(
            remoteId: c.remoteId,
            kind: c.kind,
            status: PreviewSaveStatus.saved,
            contentId: id,
          ),
        );
      } else {
        results.add(
          _failed(
            c,
            id,
            failureCodes[id] ??
                (downloadError ? 'download_error' : _reasonOf(stop)),
          ),
        );
      }
    }

    final result = PreviewSaveResult(target: target, items: results);
    _log?.log(
      LogLevel.info,
      'preview',
      'save n=${input.length} saved=${result.saved} failed=${result.failed}',
    );
    return result;
  }

  PreviewItemResult _failed(RemoteContent c, int? id, String reason) =>
      PreviewItemResult(
        remoteId: c.remoteId,
        kind: c.kind,
        status: PreviewSaveStatus.failed,
        contentId: id,
        reason: reason,
      );

  static String _reasonOf(DownloadStopReason stop) => switch (stop) {
    DownloadStopReason.busy || DownloadStopReason.alreadyRunning => 'busy',
    DownloadStopReason.storagePaused ||
    DownloadStopReason.galleryStorageFull => 'storage_paused',
    DownloadStopReason.permissionDenied => 'gallery_permission',
    DownloadStopReason.sessionProblem => 'session',
    DownloadStopReason.rateLimited => 'rate_limited',
    DownloadStopReason.deadline => 'time_budget',
    DownloadStopReason.completed => 'not_downloaded',
  };

  Future<Map<int, ContentStatus>> _statusOf(int targetId) async => {
    for (final c in await _content.listByTarget(targetId))
      c.content.id: c.content.status,
  };

  Future<Target> _targetFor(
    RemoteUser user,
    int? targetId,
    TargetCategory category,
  ) async {
    if (targetId != null) {
      final t = await _targets.getById(targetId);
      if (t != null) return t;
    }
    final existing = await _targets.getByRemoteUserId(
      _platform.id,
      user.remoteUserId,
    );
    if (existing != null) return existing;
    final now = _clock.now();
    final local = now.toLocal();
    return _targets.insert(
      Target(
        id: Target.unsavedId,
        platform: _platform.id,
        remoteUserId: user.remoteUserId,
        username: user.username,
        displayName: user.displayName,
        category: category,
        isPrivate: user.isPrivate,
        status: TargetStatus.paused,
        statusReason: previewOnlyReason,
        postsWatermarkAt: DateTime(local.year, local.month, local.day).toUtc(),
        addedAt: now,
      ),
    );
  }

  Content _row(Target target, RemoteContent c) {
    final isStory = c.kind == ContentKind.story;
    return Content(
      id: Content.unsavedId,
      targetId: target.id,
      kind: c.kind,
      remoteId: c.remoteId,
      shortcode: c.shortcode,
      postType: isStory ? null : c.postType,
      postedAt: c.postedAt.toUtc(),
      expiresAt: c.expiresAt?.toUtc(),
      caption: isStory ? null : c.caption,
      slideCount: c.slides.length,
      isCloseFriends: c.closeFriends,
      extras: c.extras,
      detectedAt: _clock.now(),
    );
  }

  List<MediaFile> _media(RemoteContent c) => [
    for (final s in c.slides)
      MediaFile(
        id: MediaFile.unsavedId,
        contentId: MediaFile.unsavedContentId,
        slideIndex: s.index,
        mediaType: s.type,
        sourceUrl: s.url,
        width: s.width,
        height: s.height,
        durationMs: s.duration?.inMilliseconds,
      ),
  ];
}
