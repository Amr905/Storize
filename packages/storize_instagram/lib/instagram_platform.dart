import 'dart:async';

// ignore: until the Lead exports it from the barrel.
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

/// The Instagram adapter of the `ContentPlatform` port (TECH_SPEC §4.1, §4.3,
/// ADR-0003 with its addendum).
///
/// ## Mode selection
/// Direct mode runs first, always. **Page mode runs only after direct mode
/// returned `SchemaChanged`**, and only if the policy allows it:
///
/// | direct result | `directOnly` | `directThenPage` |
/// |---|---|---|
/// | `Ok` | result | result |
/// | `SchemaChanged` | `SchemaChanged` | page mode (see below) |
/// | `SessionInvalid`, `RateLimited`, `AccountRestricted` | failure | failure |
/// | every other failure | failure | failure |
///
/// Page mode **never** runs after `SessionInvalid`, `RateLimited` or
/// `AccountRestricted`: a WebView would only add traffic.
///
/// After `SchemaChanged`, page mode decides:
/// - It ran and succeeded: its result, and `PAGE_MODE_USED` is logged.
/// - It ran and failed: its failure (so a login redirect in the page is a
///   `SessionInvalid`, a page timeout a `SchemaChanged`). Logged as used.
/// - It did **not** run because it is not allowed or not possible right now
///   (`page_mode_background_disabled`, `seen_guard_tripped`,
///   `username_unknown`): the original direct `SchemaChanged`, so RunCheck
///   still sees "Instagram changed" (EC-14).
/// - It did not run because something is busy (`webview_busy`: the login
///   WebView holds the lease; `governor_busy`): `NetworkFailure`, the
///   "retry next period, no state change" row of §7.
///
/// "Did not run" means **no WebView page was opened** (T-015a): `assemble`
/// counts the page driver's `open` calls, so a `RateLimited` from a paused
/// governor or a `SessionInvalid` from a missing session is returned as is and
/// is not a `PAGE_MODE_USED`. Once a stories loop has loaded a user the use is
/// counted, and a later gate stop (guard, username) returns the direct
/// `SchemaChanged`; any other failure is returned as is. What a failed
/// multi-user stories call had loaded is in [takePartialStories].
///
/// The background gate (`pageModeInBackground`) and the WebView lease are
/// enforced by `PageExtractor` (give it `runsInBackground` and the lease).
///
/// Methods without a `policy` parameter (`resolveUser`, `refreshUser`,
/// `latestPostTime`) use [lookupPolicy] (default `directThenPage`: in the
/// foreground adding a target must work even when the GraphQL `doc_id`s are
/// unknown). `verifySession` is direct only: a WebView cannot check a session.
///
/// ## Failure map
/// The direct and page extractors already return the §4.1 failure map. This
/// class adds one rule: `governor_busy` and `webview_busy` (another isolate or
/// the login WebView is in the way, nothing was sent) become `NetworkFailure`,
/// because §7 has no "try later" failure and `NetworkFailure` is exactly
/// "WorkManager back-off, next period, diagnostic only, no state change". It
/// is never `RateLimited` (nothing was paused).
///
/// ## openMedia
/// Delegated to [CdnMediaOpener]: plain HTTPS GET, no cookies, `Range`
/// resume, host allowlist, 403/410 as `ExpiredMediaUrl`, **not governed**
/// (ADR-0009), no URLs in logs.
///
/// ## Signals (T-013 N3)
/// The platform also implements the domain `ContentSignals` port.
/// [takeSignals] returns what the port cannot carry: how many malformed
/// timeline edges direct mode skipped, and how many times page mode was used,
/// since the last call. RunCheck reads it around each post check (EC-14).
///
/// ## PAGE_MODE_USED
/// Each use writes `PAGE_MODE_USED op=<name>` to the [DiagnosticLog] (no
/// values: no ids, names, URLs, `where` or failure text) and, when an
/// `ActivityRepo` is given, an activity event of type `pageModeUsed` with
/// `payload {op}` and no target. Use the activity repo here **or** let RunCheck
/// write the event from [takeSignals], not both.
///
/// Governed calls: every direct request is one `RequestCost.api` call and
/// every page load one `RequestCost.pageLoad` (3) call inside the extractors;
/// this class makes no governed call itself and never nests or leaves one
/// unawaited.
final class InstagramPlatform implements ContentPlatform, ContentSignals {
  /// Creates the platform from its parts. Use [InstagramPlatform.assemble] to
  /// build the parts with the right sharing.
  InstagramPlatform({
    required this._direct,
    required this._page,
    required this._media,
    SeenGuard? seenGuard,
    this._log,
    this._activity,
    this._clock = const SystemClock(),
    this.lookupPolicy = ExtractionPolicy.directThenPage,
    PlatformSignals? signals,
    this._usernames,
  }) : _seenGuard = seenGuard ?? SeenGuard.shared,
       signals = signals ?? PlatformSignals();

  /// Builds the platform and wires the shared parts (T-013/T-014 follow-ups):
  ///
  /// - **GraphQL with a per-call REST fallback is the default transport.**
  ///   REST alone only when
  ///   [transportPreference] is `restWhenProven` and [probe] says
  ///   `restProven` (see `selectTransport`).
  /// - **One `PageDiscovery`** is given to page mode (it fills it) and to the
  ///   GraphQL transport (it reads `doc_id`s and tokens from it). With a
  ///   [discoveryStore] it is persisted per account, so every isolate sees
  ///   what the foreground found (T-045; ignored when [discovery] is given).
  /// - **One `UsernameCache`**, by default the persistent
  ///   `TargetRepoUsernameCache`, shared by direct and page mode.
  /// - **One `SeenGuard`** for page mode and for this class.
  /// - The `FailureClassifier` caps `Retry-After` at the governor's
  ///   `maxPause`.
  /// - If [webViewLease] is a `GovernorWebViewLease`, the page driver is
  ///   wrapped so the lease is held through a late `open` (R2-F2).
  /// - `SkipCountingTransport` reports skipped timeline edges to [signals].
  factory InstagramPlatform.assemble({
    required int accountId,
    required RequestGovernor governor,
    required SessionStore sessions,
    required IgHttp http,
    required CdnHttp cdnHttp,
    required PageDriver pageDriver,
    required String hookSource,
    required TargetRepo targets,
    String? appId,
    DiagnosticLog? log,
    ActivityRepo? activity,
    Clock clock = const SystemClock(),
    ExtractionPolicy lookupPolicy = ExtractionPolicy.directThenPage,
    TransportPreference transportPreference = TransportPreference.graphql,
    ProbeReport? probe,
    UsernameCache? usernames,
    PageDiscovery? discovery,
    DiscoveryStore? discoveryStore,
    SeenGuard? seenGuard,
    WebViewLease webViewLease = const NoopWebViewLease(),
    bool runsInBackground = false,
    FutureOr<bool> Function()? pageModeInBackground,
    PageHookConfig? hookConfig,
    PageTimerFactory? pageTimer,
    Duration cleanupTimeout = const Duration(seconds: 5),
    PlatformSignals? signals,
  }) {
    final sharedSignals = signals ?? PlatformSignals();
    final sharedDiscovery =
        discovery ??
        PageDiscovery(
          clock: clock,
          store: discoveryStore,
          accountId: accountId,
          onWriteError: (type) => log?.log(
            LogLevel.warn,
            'platform',
            'discovery_store_failed $type',
          ),
        );
    final sharedNames = usernames ?? TargetRepoUsernameCache(targets);
    final guard = seenGuard ?? SeenGuard.shared;
    final classifier = FailureClassifier(
      maxRetryAfter: governor.config.maxPause,
    );
    final transport = SkipCountingTransport(
      selectTransport(
        docIds: sharedDiscovery,
        tokens: sharedDiscovery,
        preference: transportPreference,
        probe: probe,
        log: log,
      ),
      sharedSignals,
    );
    final direct = DirectExtractor(
      accountId: accountId,
      governor: governor,
      sessions: sessions,
      http: http,
      transport: transport,
      log: log,
      appId: appId,
      classifier: classifier,
      usernames: sharedNames,
    );
    final opens = PageOpenCounter();
    final driver = CountingPageDriver(
      webViewLease is GovernorWebViewLease
          ? LeaseHoldingPageDriver(pageDriver, webViewLease)
          : pageDriver,
      opens,
    );
    final page = PageExtractor(
      accountId: accountId,
      governor: governor,
      sessions: sessions,
      driver: driver,
      hookSource: hookSource,
      runsInBackground: runsInBackground,
      pageModeInBackground: pageModeInBackground,
      log: log,
      hookConfig: hookConfig,
      discovery: sharedDiscovery,
      usernames: sharedNames,
      webViewLease: webViewLease,
      seenGuard: guard,
      classifier: classifier,
      cleanupTimeout: cleanupTimeout,
      timer: pageTimer ?? Timer.new,
    );
    return InstagramPlatform(
      direct: DirectExtractorOps(direct),
      page: PageExtractorOps(page, counter: opens),
      media: CdnMediaOpener(http: cdnHttp, log: log),
      seenGuard: guard,
      log: log,
      activity: activity,
      clock: clock,
      lookupPolicy: lookupPolicy,
      signals: sharedSignals,
      usernames: sharedNames,
    );
  }

  /// The policy of the methods that have no `policy` parameter.
  final ExtractionPolicy lookupPolicy;

  /// The counters behind [takeSignals].
  final PlatformSignals signals;

  final DirectOps _direct;
  final PageOps _page;
  final CdnMediaOpener _media;
  final SeenGuard _seenGuard;
  final DiagnosticLog? _log;
  final ActivityRepo? _activity;
  final Clock _clock;
  final UsernameCache? _usernames;

  @override
  PlatformId get id => PlatformId.instagram;

  @override
  ContentSignalsSnapshot takeSignals() => signals.take();

  /// What the last multi-user page-mode stories call had loaded when it
  /// failed, read-and-reset; null if there is none (T-015a F1). The call
  /// itself returns the failure.
  PartialStories? takePartialStories() => signals.takePartialStories();

  // ----------------------------------------------------------------- users

  @override
  Future<Result<RemoteUser>> resolveUser(String username) => _run(
    'resolveUser',
    lookupPolicy,
    () => _direct.resolveUser(username),
    () => _page.resolveUser(username),
  );

  @override
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  ) => _run(
    'refreshUser',
    lookupPolicy,
    () => _direct.refreshUser(remoteUserId, lastUsername),
    () => _page.refreshUser(remoteUserId, lastUsername),
  );

  /// Loads the profile of [username] in **page mode only**, so the page's
  /// `doc_id`s and tokens are recorded in the shared discovery (T-045). One
  /// governed page load; the result is not used. Foreground only: a
  /// background platform refuses page mode unless the setting allows it.
  Future<Result<RemoteUser>> loadDiscovery(String username) =>
      _guarded(() => _page.resolveUser(username));

  /// When the newest story of [userId] was posted, as the last profile page
  /// load saw it (no request); null when it showed none (T-047).
  DateTime? profileStoryTime(String userId) {
    final page = _page;
    return page is PageExtractorOps
        ? page.extractor.profileStoryTime(userId)
        : null;
  }

  @override
  Future<Result<RemoteUser>> verifySession() async =>
      _normalize(await _guarded(_direct.verifySession));

  // --------------------------------------------------------------- content

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds, {
    required ExtractionPolicy policy,
  }) {
    final progress = _StoriesProgress();
    return _run(
      'fetchStories',
      policy,
      () => _direct.fetchStories(userIds),
      () => _pageStories(userIds, progress),
      pageLoadedData: () => progress.loadedUsers > 0,
    );
  }

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark, {
    required ExtractionPolicy policy,
  }) => _run(
    'fetchNewPosts',
    policy,
    () => _direct.fetchNewPosts(userId, watermark),
    () => _page.fetchNewPosts(userId, watermark),
  );

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) => _run(
    'latestPostTime',
    lookupPolicy,
    () => _direct.latestPostTime(userId),
    () => _page.latestPostTime(userId),
  );

  @override
  Future<Result<PostPage>> fetchPostPage(
    String userId, {
    required ExtractionPolicy policy,
    String? cursor,
  }) async {
    try {
      return await _run(
        'fetchPostPage',
        policy,
        () => _history(_direct, (o) => o.fetchPostPage(userId, cursor: cursor)),
        () => _history(_page, (o) => o.fetchPostPage(userId, cursor: cursor)),
      );
    } finally {
      await _seenGuard.flush();
    }
  }

  @override
  Future<Result<List<RemoteHighlight>>> fetchHighlights(
    String userId, {
    required ExtractionPolicy policy,
  }) => _run(
    'fetchHighlights',
    policy,
    () => _history(_direct, (o) => o.fetchHighlights(userId)),
    () => _history(_page, (o) => o.fetchHighlights(userId)),
  );

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchHighlightItems(
    List<String> highlightIds, {
    required ExtractionPolicy policy,
  }) {
    final progress = _StoriesProgress();
    return _run(
      'fetchHighlightItems',
      policy,
      () => _history(_direct, (o) => o.fetchHighlightItems(highlightIds)),
      () => _pageHighlightItems(highlightIds, progress),
      pageLoadedData: () => progress.loadedUsers > 0,
    );
  }

  @override
  Stream<List<int>> openMedia(String url, {int fromByte = 0}) =>
      _media.open(url, fromByte: fromByte);

  // --------------------------------------------------------------- plumbing

  /// Page-mode stories, one user per page load, so the persisted seen breaker
  /// is read before **each** story page load (R2-F5) and a trip stops the
  /// loop at once.
  ///
  /// - **Pre-check (F1).** Every username is checked before the first load
  ///   (like `PageExtractor.fetchStories`), so a `username_unknown` aborts
  ///   before any WebView page is loaded. Only when a [UsernameCache] was
  ///   given.
  /// - **First failure fails the call**, and is returned as is. The port's
  ///   `Result` cannot say "some users", and an `Ok` with fewer users would
  ///   hide a `SessionInvalid` or `RateLimited` that RunCheck must see, and
  ///   make a user whose load was skipped look like "no stories". So a
  ///   failure after at least one loaded user is a failure, and what was
  ///   loaded is kept in
  ///   the platform signals ([takePartialStories]) with the number of users
  ///   skipped.
  Future<Result<Map<String, List<RemoteContent>>>> _pageStories(
    List<String> userIds,
    _StoriesProgress progress,
  ) async {
    final ids = {
      for (final id in userIds)
        if (id.trim().isNotEmpty) id.trim(),
    }.toList();
    final names = _usernames;
    if (names != null) {
      for (final id in ids) {
        String? name;
        try {
          name = await names.usernameOf(id);
        } on Object {
          name = null;
        }
        if (name == null || !pageUsernameShape.hasMatch(name)) {
          return const Err(UnknownFailure(null, 'username_unknown'));
        }
      }
    }
    final out = <String, List<RemoteContent>>{};
    Result<Map<String, List<RemoteContent>>> fail(Failure failure) {
      if (progress.loadedUsers > 0) {
        signals.partialStories = PartialStories(
          loaded: Map.of(out),
          skipped: ids.length - progress.loadedUsers,
        );
        _log?.log(
          LogLevel.warn,
          'platform',
          'op=fetchStories page_stories_partial '
              'loaded=${progress.loadedUsers} '
              'skipped=${ids.length - progress.loadedUsers}',
        );
      }
      return Err(failure);
    }

    try {
      for (final id in ids) {
        await _seenGuard.refresh();
        final r = await _page.fetchStories([id]);
        switch (r) {
          case Err(:final failure):
            return fail(failure);
          case Ok(:final value):
            progress.loadedUsers++;
            out.addAll(value);
        }
      }
      return Ok(out);
    } finally {
      await _seenGuard.flush();
    }
  }

  /// Page-mode highlight items, one highlight page per id, so the persisted
  /// seen breaker is read before **each** page (like `_pageStories`) and a
  /// trip stops the loop at once. The first failure fails the call.
  Future<Result<Map<String, List<RemoteContent>>>> _pageHighlightItems(
    List<String> highlightIds,
    _StoriesProgress progress,
  ) async {
    final ids = {
      for (final id in highlightIds)
        if (stripHighlightPrefix(id.trim()).isNotEmpty)
          stripHighlightPrefix(id.trim()),
    }.toList();
    final out = <String, List<RemoteContent>>{};
    try {
      for (var i = 0; i < ids.length; i++) {
        await _seenGuard.refresh();
        final r = await _history(
          _page,
          (o) => o.fetchHighlightItems([ids[i]], orderStart: i),
        );
        switch (r) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            progress.loadedUsers++;
            out.addAll(value);
        }
      }
      return Ok(out);
    } finally {
      await _seenGuard.flush();
    }
  }

  Future<Result<T>> _history<T>(
    ExtractionOps mode,
    Future<Result<T>> Function(HistoryOps ops) body,
  ) async => mode is HistoryOps
      ? body(mode as HistoryOps)
      : Err<T>(const UnknownFailure(null, 'not_implemented'));

  Future<Result<T>> _run<T>(
    String op,
    ExtractionPolicy policy,
    Future<Result<T>> Function() direct,
    Future<Result<T>> Function() page, {
    bool Function()? pageLoadedData,
  }) async {
    final first = await _guarded(direct);
    if (first.failureOrNull is! SchemaChanged ||
        policy == ExtractionPolicy.directOnly) {
      return _normalize(first);
    }
    final openedBefore = _page.pagesOpened;
    final second = await _guarded(page);
    final failure = second.failureOrNull;
    final openedAfter = _page.pagesOpened;
    final sessions = openedBefore == null || openedAfter == null
        ? null
        : openedAfter - openedBefore;
    final skippedReason = failure != null && _pageDidNotRun(failure);
    // Did page mode load at least one page? The session counter is exact; if
    // there is none, a loaded user (stories) or a result that is not a
    // "refused before loading" reason says so.
    final used =
        (pageLoadedData?.call() ?? false) ||
        (sessions != null ? sessions > 0 : !skippedReason);
    if (!used) {
      // Nothing was loaded: not allowed, not possible, busy, a paused
      // governor or no stored session. Not a PAGE_MODE_USED (F1, I2).
      if (failure == null) return _normalize(second);
      _log?.log(
        LogLevel.info,
        'platform',
        'op=$op page_mode_skipped reason=${_reasonOf(failure) ?? 'refused'}',
      );
      if (_isBusy(failure)) return _normalize(second);
      return skippedReason ? first : _normalize(second);
    }
    await _notePageModeUsed(op);
    if (failure != null && skippedReason && !_isBusy(failure)) {
      // Stopped by a gate after loading (a multi-user stories loop): the
      // original "Instagram changed" answer (EC-14), the use is counted.
      return first;
    }
    return _normalize(second);
  }

  Future<Result<T>> _guarded<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } on Object catch (error) {
      // An extractor must not throw; if one does, only the type is logged.
      _log?.log(
        LogLevel.warn,
        'platform',
        'unexpected_error type=${error.runtimeType}',
      );
      return Err<T>(const UnknownFailure(null, 'unexpected_error'));
    }
  }

  Future<void> _notePageModeUsed(String op) async {
    signals.addPageModeUse();
    _log?.log(LogLevel.info, 'platform', 'PAGE_MODE_USED op=$op');
    final activity = _activity;
    if (activity == null) return;
    try {
      await activity.add(
        ActivityEvent(
          id: ActivityEvent.unsavedId,
          at: _clock.now(),
          type: ActivityType.pageModeUsed,
          payload: {'op': op},
        ),
      );
    } on Object catch (error) {
      _log?.log(
        LogLevel.warn,
        'platform',
        'activity_write_failed type=${error.runtimeType}',
      );
    }
  }

  /// `UnknownFailure` reasons that mean page mode never loaded anything.
  static const Set<String> _notRunReasons = {
    'page_mode_background_disabled',
    'seen_guard_tripped',
    'username_unknown',
    'webview_busy',
    'governor_busy',
  };

  /// Reasons that mean "something is in the way, try later".
  static const Set<String> _busyReasons = {'webview_busy', 'governor_busy'};

  static String? _reasonOf(Failure failure) =>
      failure is UnknownFailure && failure.code == null
      ? failure.message
      : null;

  static bool _pageDidNotRun(Failure failure) =>
      _notRunReasons.contains(_reasonOf(failure));

  static bool _isBusy(Failure failure) =>
      _busyReasons.contains(_reasonOf(failure));

  /// The failure map rule of this class: "busy" is `NetworkFailure`.
  static Result<T> _normalize<T>(Result<T> result) {
    final failure = result.failureOrNull;
    if (failure != null && _isBusy(failure)) {
      return Err<T>(const NetworkFailure());
    }
    return result;
  }
}

/// How many users the page-mode stories loop loaded in one call.
final class _StoriesProgress {
  int loadedUsers = 0;
}
