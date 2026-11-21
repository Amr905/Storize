import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/activity_event.dart';
import 'package:storize_domain/src/entities/check_run.dart';
import 'package:storize_domain/src/entities/content.dart';
import 'package:storize_domain/src/entities/login_account.dart';
import 'package:storize_domain/src/entities/media_file.dart';
import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/ports/content_signals.dart';
import 'package:storize_domain/src/repos/account_repo.dart';
import 'package:storize_domain/src/repos/activity_repo.dart';
import 'package:storize_domain/src/repos/check_run_repo.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/settings_repo.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_model/storize_model.dart';

/// The outcome of [RunCheck].
@immutable
final class CheckRunResult {
  /// Creates the result.
  const CheckRunResult({
    required this.run,
    required this.newContentIds,
  });

  /// The finished `check_run` row.
  final CheckRun run;

  /// IDs of the content rows this run stored, in storage order.
  final List<int> newContentIds;

  /// The outcome of the run.
  CheckResult get result => run.result ?? CheckResult.failed;

  @override
  String toString() => 'CheckRunResult($run)';
}

/// Checks tracked accounts for new stories or posts (TECH_SPEC §6, §7).
///
/// One call runs one [CheckScope] (stories or posts). A combined run is two
/// calls. Targets are checked one after the other; a failure of one target
/// never stops the others. Only a session problem (BR-7) or a rate limit
/// (EC-15) ends the run early.
///
/// **Round-robin carry-over (ADR-9).** `TargetRepo.listActive` orders targets
/// by least recent check. This use case stamps the check time only on targets
/// it finished, so targets left over after a rate limit, or after the
/// `deadline`, come first in the next run.
final class RunCheck {
  /// Creates the use case.
  RunCheck({
    required this._platform,
    required this._signals,
    required this._targets,
    required this._content,
    required this._accounts,
    required this._checkRuns,
    required this._activity,
    required this._settings,
    required this._clock,
  });

  final ContentPlatform _platform;
  final ContentSignals _signals;
  final TargetRepo _targets;
  final ContentRepo _content;
  final AccountRepo _accounts;
  final CheckRunRepo _checkRuns;
  final ActivityRepo _activity;
  final SettingsRepo _settings;
  final Clock _clock;

  /// The most users in one `fetchStories` call (IG-2).
  static const int storyBatchSize = 20;

  /// After this many schema failures in a row the run stops, to save budget.
  static const int _maxSchemaFailures = 3;

  /// Runs a check of [scope] (stories or posts; `all` is rejected).
  ///
  /// With [targetId] only that target is checked (manual check of one
  /// account). No new target is started after [deadline]; the rest carry over
  /// to the next run and the result is `PARTIAL`.
  Future<CheckRunResult> call({
    required CheckScope scope,
    required CheckTrigger trigger,
    int? targetId,
    DateTime? deadline,
  }) async {
    if (scope == CheckScope.all) {
      throw ArgumentError.value(scope, 'scope', 'use stories or posts');
    }
    final started = await _checkRuns.start(
      scope: scope,
      trigger: trigger,
      startedAt: _clock.now(),
    );
    final run = _Run(
      scope: scope,
      trigger: trigger,
      runId: started.id,
      deadline: deadline,
    );
    try {
      await _execute(run, targetId);
    } on Object catch (_) {
      run.end(CheckResult.failed, 'unexpected_error');
    }
    return _finish(run);
  }

  Future<CheckRunResult> _finish(_Run run) async {
    final result =
        run.result ??
        (run.failed == 0
            ? CheckResult.ok
            : (run.checked == 0 ? CheckResult.failed : CheckResult.partial));
    final mode = run.calls == 0
        ? null
        : (run.pageModeUses > 0 ? ExtractionMode.page : ExtractionMode.direct);
    final stored = await _checkRuns.finish(
      run.runId,
      finishedAt: _clock.now(),
      result: result,
      mode: mode,
      targetsChecked: run.checked,
      newItems: run.newIds.length,
      errorCode: run.errorCode,
    );
    if (run.pageModeUses > 0) {
      await _event(
        run,
        ActivityType.pageModeUsed,
        count: run.pageModeUses,
      );
    }
    if (result == CheckResult.ok || result == CheckResult.partial) {
      await _event(
        run,
        ActivityType.checkDone,
        count: run.newIds.length,
        severity: result == CheckResult.ok ? Severity.info : Severity.warn,
        payload: {'targets': run.checked, 'failed': run.failed},
      );
    }
    return CheckRunResult(run: stored, newContentIds: run.newIds);
  }

  Future<void> _event(
    _Run run,
    ActivityType type, {
    Severity severity = Severity.info,
    int? targetId,
    int count = 1,
    Map<String, Object?> payload = const {},
  }) async {
    try {
      await _activity.add(
        ActivityEvent(
          id: ActivityEvent.unsavedId,
          at: _clock.now(),
          type: type,
          severity: severity,
          targetId: targetId,
          checkRunId: run.runId,
          count: count,
          payload: {'scope': run.scope.dbValue, ...payload},
        ),
      );
    } on Object catch (_) {
      // The activity log must never break a check.
    }
  }

  Future<void> _execute(_Run run, int? targetId) async {
    // BR-7: no active session, no calls.
    final account = await _accounts.getActive();
    if (account == null || account.status != AccountStatus.active) {
      run.end(CheckResult.skippedSession, 'session_not_active');
      return;
    }
    run.account = account;

    final settings = await _settings.get();
    run.policy =
        (run.trigger != CheckTrigger.periodic || settings.pageModeInBackground)
        ? ExtractionPolicy.directThenPage
        : ExtractionPolicy.directOnly;

    final stories = run.scope == CheckScope.stories;
    final all = await _targets.listActive(run.scope);
    final due = [
      for (final t in all)
        if (t.status == TargetStatus.active &&
            t.platform == _platform.id &&
            (targetId == null || t.id == targetId) &&
            (stories ? t.trackStories : (t.trackPosts || t.trackReels)))
          t,
    ];
    if (stories) {
      await _checkStories(run, due);
    } else {
      await _checkPosts(run, due);
    }
    if (run.success && run.result == null) {
      await _accounts.setStatus(
        account.id,
        AccountStatus.active,
        lastSuccessAt: _clock.now(),
      );
    }
  }

  bool _pastDeadline(_Run run) {
    final d = run.deadline;
    if (d == null || run.result != null) return run.result != null;
    if (_clock.now().isBefore(d)) return false;
    run.end(CheckResult.partial, 'deadline');
    return true;
  }

  // ---------------------------------------------------------------- stories

  Future<void> _checkStories(_Run run, List<Target> due) async {
    for (var i = 0; i < due.length; i += storyBatchSize) {
      if (_pastDeadline(run)) return;
      final chunk = due.sublist(
        i,
        i + storyBatchSize > due.length ? due.length : i + storyBatchSize,
      );
      await _storiesChunk(run, chunk);
      if (run.result != null) return;
    }
  }

  Future<void> _storiesChunk(_Run run, List<Target> chunk) async {
    final res = await _call(
      run,
      () => _platform.fetchStories([
        for (final t in chunk) t.remoteUserId,
      ], policy: run.policy),
    );
    switch (res) {
      case Ok(:final value):
        for (final target in chunk) {
          await _guard(run, () async {
            final ids = await _storeStories(
              run,
              target,
              value[target.remoteUserId] ?? const [],
            );
            await _markStoriesChecked(target.id, ids.length);
            run.checked++;
            run.success = true;
            run.newIds.addAll(ids);
            await _maybeRefreshUser(run, target, target.lastStoriesCheckAt);
          });
        }
      case Err(:final failure):
        final targetLevel =
            failure is TargetNotVisible || failure is TargetNotFound;
        if (targetLevel && chunk.length > 1) {
          // A batch cannot say whose fault it is: ask one by one.
          for (final t in chunk) {
            if (run.result != null || _pastDeadline(run)) return;
            await _storiesChunk(run, [t]);
          }
          return;
        }
        await _onFailure(run, failure, targetLevel ? chunk.single : null);
        if (failure is SchemaChanged && chunk.length == 1) {
          await _rotateToBack(chunk.single, CheckScope.stories);
        }
    }
  }

  Future<List<int>> _storeStories(
    _Run run,
    Target target,
    List<RemoteContent> items,
  ) async {
    final stories = [
      for (final c in items)
        if (c.kind == ContentKind.story) c,
    ];
    final existing = await _content.existingRemoteIds(
      target.id,
      ContentKind.story,
      [for (final c in stories) c.remoteId],
    );
    final ids = <int>[];
    for (final c in stories) {
      if (existing.contains(c.remoteId)) continue;
      final id = await _insert(target, c);
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Future<void> _markStoriesChecked(int targetId, int newCount) async {
    final t = await _targets.getById(targetId);
    if (t == null) return;
    final now = _clock.now();
    await _targets.update(
      t.copyWith(
        lastStoriesCheckAt: now,
        lastNewStoryAt: newCount > 0 ? now : t.lastNewStoryAt,
      ),
    );
  }

  // ------------------------------------------------------------------ posts

  Future<void> _checkPosts(_Run run, List<Target> due) async {
    for (final target in due) {
      if (_pastDeadline(run)) return;
      final res = await _call(
        run,
        () => _platform.fetchNewPosts(
          target.remoteUserId,
          target.postsWatermarkAt,
          policy: run.policy,
        ),
        afterCall: (snapshot) {
          // EC-14: skipped timeline edges mean the response shape changed.
          if (snapshot.skippedMalformed > 0) {
            run.malformed += snapshot.skippedMalformed;
          }
        },
      );
      if (run.malformed > 0) {
        final n = run.malformed;
        run.malformed = 0;
        await _event(
          run,
          ActivityType.platformChanged,
          severity: Severity.warn,
          targetId: target.id,
          count: n,
          payload: {'reason': 'skipped_malformed'},
        );
      }
      switch (res) {
        case Ok(:final value):
          await _guard(run, () async {
            final ids = await _storePosts(target, value);
            run.checked++;
            run.success = true;
            run.newIds.addAll(ids);
            await _maybeRefreshUser(run, target, target.lastPostsCheckAt);
          });
        case Err(:final failure):
          final targetLevel =
              failure is TargetNotVisible || failure is TargetNotFound;
          await _onFailure(run, failure, targetLevel ? target : null);
          if (failure is SchemaChanged) {
            await _rotateToBack(target, CheckScope.posts);
          }
      }
      if (run.result != null) return;
    }
  }

  /// Moves a target that hit `SchemaChanged` to the back of the round-robin.
  ///
  /// Only the check time is stamped, so `TargetRepo.listActive` puts the target
  /// last. The watermark is untouched, so nothing is skipped: the target is
  /// tried again once the others had their turn. Without this, targets whose
  /// responses keep changing shape sit at the front, use up the "3 schema
  /// failures in a row" budget every run and starve the healthy targets.
  Future<void> _rotateToBack(Target target, CheckScope scope) async {
    try {
      final t = await _targets.getById(target.id);
      if (t == null) return;
      final now = _clock.now();
      await _targets.update(
        scope == CheckScope.stories
            ? t.copyWith(lastStoriesCheckAt: now)
            : t.copyWith(lastPostsCheckAt: now),
      );
    } on Object catch (_) {
      // Rotation is best effort; it must never break a check.
    }
  }

  Future<List<int>> _storePosts(Target target, List<RemoteContent> all) async {
    final watermark = target.postsWatermarkAt;
    final fresh = [
      for (final c in all)
        if (c.kind == ContentKind.post && c.postedAt.isAfter(watermark)) c,
    ];
    final wanted = [
      for (final c in fresh)
        if (c.postType == PostType.reel ? target.trackReels : target.trackPosts)
          c,
    ];
    final ids = <int>[];
    for (final c in wanted) {
      // The UNIQUE key (target, kind, remote_id) makes a repeat harmless.
      final id = await _insert(target, c);
      if (id != null) ids.add(id);
    }
    // The watermark moves only now, after every insert succeeded, and it
    // follows all returned posts, including pinned and filtered ones.
    var newMark = watermark;
    for (final c in all) {
      if (c.postedAt.isAfter(newMark)) newMark = c.postedAt.toUtc();
    }
    final t = await _targets.getById(target.id);
    if (t != null) {
      final now = _clock.now();
      final mark = t.postsWatermarkAt.isAfter(newMark)
          ? t.postsWatermarkAt
          : newMark;
      await _targets.update(
        t.copyWith(
          postsWatermarkAt: mark,
          lastPostsCheckAt: now,
          lastNewPostAt: ids.isNotEmpty ? now : t.lastNewPostAt,
        ),
      );
    }
    return ids;
  }

  // ----------------------------------------------------------------- shared

  /// Stores [c] with PENDING media. Returns the new content ID, or null when
  /// it exists already or has nothing to download.
  Future<int?> _insert(Target target, RemoteContent c) async {
    if (c.slides.isEmpty) return null;
    final isStory = c.kind == ContentKind.story;
    final result = await _content.insertIfNew(
      Content(
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
      ),
      [
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
      ],
    );
    return result.isNew ? result.contentId : null;
  }

  /// Makes one platform call and reads the signals around it.
  Future<Result<T>> _call<T>(
    _Run run,
    Future<Result<T>> Function() call, {
    void Function(ContentSignalsSnapshot snapshot)? afterCall,
  }) async {
    _signals.takeSignals(); // drop anything left from before this call
    run.calls++;
    final Result<T> res;
    try {
      res = await call();
    } on Object catch (_) {
      _signals.takeSignals();
      return const Err(UnknownFailure(null, 'platform_threw'));
    }
    final snap = _signals.takeSignals();
    run.pageModeUses += snap.pageModeUses;
    afterCall?.call(snap);
    return res;
  }

  /// Runs one target's work; its failure is counted and never rethrown.
  Future<void> _guard(_Run run, Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (_) {
      run.failed++;
      run.errorCode ??= 'target_error';
    }
  }

  /// Daily username and visibility refresh (EC-3, EC-4, EC-5, EC-6).
  ///
  /// It runs on the first check of a UTC day for the scope that owns the
  /// target's calls, so the cost is one call per target per day (IG-3).
  Future<void> _maybeRefreshUser(
    _Run run,
    Target target,
    DateTime? lastCheck,
  ) async {
    if (run.result != null) return;
    if (run.scope == CheckScope.stories &&
        (target.trackPosts || target.trackReels)) {
      return; // the posts scope does it
    }
    final now = _clock.now();
    if (lastCheck != null && _sameDay(lastCheck.toUtc(), now)) return;
    final res = await _call(
      run,
      () => _platform.refreshUser(target.remoteUserId, target.username),
    );
    switch (res) {
      case Ok(:final value):
        await _applyUser(run, target.id, value);
      case Err(:final failure):
        final targetLevel =
            failure is TargetNotVisible || failure is TargetNotFound;
        await _onFailure(run, failure, targetLevel ? target : null);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _applyUser(_Run run, int targetId, RemoteUser user) async {
    final t = await _targets.getById(targetId);
    if (t == null || user.remoteUserId != t.remoteUserId) return;
    var next = t.copyWith(
      username: user.username,
      displayName: user.displayName ?? t.displayName,
      isPrivate: user.isPrivate,
    );
    if (user.username != t.username) {
      await _event(
        run,
        ActivityType.targetStatus,
        targetId: t.id,
        payload: {'change': 'renamed'},
      );
    }
    if (user.blockedByViewer || (user.isPrivate && !user.followedByViewer)) {
      next = next.copyWith(
        status: TargetStatus.notVisible,
        statusReason: user.blockedByViewer ? 'blocked' : 'private',
      );
      await _event(
        run,
        ActivityType.targetStatus,
        severity: Severity.warn,
        targetId: t.id,
        payload: {'status': TargetStatus.notVisible.dbValue},
      );
    }
    await _targets.update(next);
  }

  Future<void> _setTargetStatus(
    _Run run,
    Target target,
    TargetStatus status,
    String reason,
  ) async {
    final t = await _targets.getById(target.id);
    if (t == null) return;
    await _targets.update(t.copyWith(status: status, statusReason: reason));
    await _event(
      run,
      ActivityType.targetStatus,
      severity: Severity.warn,
      targetId: t.id,
      payload: {'status': status.dbValue},
    );
  }

  /// Maps a failure to state changes. [target] is set when the failure is
  /// about one target.
  Future<void> _onFailure(_Run run, Failure failure, Target? target) async {
    switch (failure) {
      case TargetNotVisible():
        if (target != null) {
          await _setTargetStatus(
            run,
            target,
            TargetStatus.notVisible,
            'not_visible',
          ); // EC-3, EC-4
        }
        run.checked++;
        run.success = true;
      case TargetNotFound():
        if (target != null) {
          await _setTargetStatus(
            run,
            target,
            TargetStatus.unavailable,
            'not_found',
          ); // EC-6
        }
        run.checked++;
        run.success = true;
      case NetworkFailure():
        // Includes governor_busy and webview_busy: retry next period.
        run.failed++;
        run.errorCode ??= 'network';
      case RateLimited(:final retryAfter):
        run.end(CheckResult.rateLimited, 'rate_limited');
        await _event(
          run,
          ActivityType.rateLimited,
          severity: Severity.warn,
          payload: {'retryAfterSec': ?retryAfter?.inSeconds},
        );
      case SessionInvalid(:final reason):
        await _stopForSession(
          run,
          AccountStatus.needsRelogin,
          reason == SessionReason.challenge ? 'challenge' : 'login_required',
        );
      case AccountRestricted():
        await _stopForSession(run, AccountStatus.restricted, 'restricted');
      case SchemaChanged():
        run.failed++;
        run.errorCode ??= 'schema_changed';
        run.schemaFailures++;
        if (run.schemaFailures == 1) {
          await _event(
            run,
            ActivityType.platformChanged,
            severity: Severity.error,
            payload: {'reason': 'schema_changed'},
          );
        }
        if (run.schemaFailures >= _maxSchemaFailures) {
          run.result = CheckResult.failed;
        }
      case UnknownFailure():
        run.failed++;
        run.errorCode ??= 'unknown';
    }
  }

  Future<void> _stopForSession(
    _Run run,
    AccountStatus status,
    String reason,
  ) async {
    final account = run.account;
    if (account != null) {
      await _accounts.setStatus(account.id, status, reason: reason);
    }
    run.end(CheckResult.failed, 'session_${status.dbValue.toLowerCase()}');
    await _event(
      run,
      ActivityType.sessionProblem,
      severity: Severity.error,
      payload: {'reason': reason},
    );
  }
}

/// Mutable state of one run.
final class _Run {
  _Run({
    required this.scope,
    required this.trigger,
    required this.runId,
    required this.deadline,
  });

  final CheckScope scope;
  final CheckTrigger trigger;
  final int runId;
  final DateTime? deadline;
  LoginAccount? account;
  ExtractionPolicy policy = ExtractionPolicy.directOnly;
  CheckResult? result;
  String? errorCode;
  int checked = 0;
  int failed = 0;
  int calls = 0;
  int pageModeUses = 0;
  int malformed = 0;
  int schemaFailures = 0;
  bool success = false;
  final List<int> newIds = [];

  void end(CheckResult r, String code) {
    result = r;
    errorCode = code;
  }
}
