import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/failure_classifier.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/direct/ig_session.dart';
import 'package:storize_instagram/direct/username_cache.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/page/dom_fallback.dart';
import 'package:storize_instagram/page/hook_config.dart';
import 'package:storize_instagram/page/hook_protocol.dart';
import 'package:storize_instagram/page/page_discovery.dart';
import 'package:storize_instagram/page/page_driver.dart';
import 'package:storize_instagram/page/page_plan.dart';
import 'package:storize_instagram/page/webview_lease.dart';
import 'package:storize_model/storize_model.dart';

/// Creates the timeout timer. Injected so tests control time.
typedef PageTimerFactory = Timer Function(Duration d, void Function() fire);

/// Page mode: the fallback that loads the real page in a headless WebView
/// (ADR-3, FR-29) and reads the JSON the page itself fetches.
///
/// - **Same mappers** as direct mode (`EnvelopeMapper`, `MediaMapper`) and the
///   same `FailureClassifier`.
/// - **Governor:** one page load is one `RequestGovernor.run` with cost
///   `pageLoad`. The governed closure only drives one WebView; the next load
///   starts after `run` has returned, so governed calls never nest.
/// - **Seen mutation (UD-3):** the hook never sends the names in
///   `PageHookConfig.blockedFriendlyNames`, and nothing here clicks or scrolls
///   in the page.
/// - **Timeout:** [timeout] (20 s) without the wanted response is
///   `SchemaChanged('page_timeout')`.
/// - **Clean-up:** cookies, web storage and cache are cleared and the WebView
///   disposed in a `finally`, success or not.
/// - **Background:** when [runsInBackground] is true, a load happens only if
///   `pageModeInBackground` says so (settings, wired by T-015).
/// - **Discovery:** the `doc_id`s and tokens the page used are kept in
///   [discovery] (memory only) for the direct GraphQL transport.
/// - **Logs:** operation names, outcome, failure type and counters only. No
///   cookies, tokens, `doc_id`s, URLs or usernames.
///
/// Every operation needs the username of the user (from the username
/// cache); an unknown
/// one is `UnknownFailure('username_unknown')` without loading anything.
final class PageExtractor {
  /// Creates the extractor for the login account [accountId].
  PageExtractor({
    required this.accountId,
    required this._governor,
    required this._sessions,
    required this._driver,
    required this.hookSource,
    this.runsInBackground = false,
    FutureOr<bool> Function()? pageModeInBackground,
    this._log,
    PageHookConfig? hookConfig,
    PageDiscovery? discovery,
    UsernameCache? usernames,
    this.timeout = const Duration(seconds: 20),
    this.openTimeout = const Duration(seconds: 10),
    this.cleanupTimeout = const Duration(seconds: 5),
    this.emptyGrace = const Duration(seconds: 2),
    this.domSettle = const Duration(seconds: 3),
    WebViewLease? webViewLease,
    SeenGuard? seenGuard,
    this.classifier = const FailureClassifier(),
    this._timer = Timer.new,
  }) : _pageModeInBackground = pageModeInBackground ?? (() => false),
       hookConfig = hookConfig ?? PageHookConfig(),
       discovery = discovery ?? PageDiscovery(),
       _usernames = usernames ?? InMemoryUsernameCache(),
       _lease = webViewLease ?? const NoopWebViewLease(),
       seenGuard = seenGuard ?? SeenGuard.shared;

  /// The login account whose session and request budget are used.
  final int accountId;

  /// The content of `assets/hook.js`.
  final String hookSource;

  /// Whether this runs in the background isolate (gated by the setting).
  final bool runsInBackground;

  /// The wait for the wanted response (20 s, AC3).
  final Duration timeout;

  /// How long `driver.open` may take (QA-F6). Longer is
  /// `UnknownFailure('page_open_timeout')`.
  final Duration openTimeout;

  /// How long `clearData`, `dispose` and the lease release may each take. A
  /// step that hangs is abandoned (logged, never rethrown).
  final Duration cleanupTimeout;

  /// The wait after the page loaded before a tentative answer ("no stories",
  /// "username mismatch") is accepted. A definitive reply wins if it comes
  /// first.
  final Duration emptyGrace;

  /// The breaker of the story "seen" guard (process-wide by default).
  final SeenGuard seenGuard;

  /// How long the DOM last resort waits after the load.
  final Duration domSettle;

  /// The failure map shared with direct mode.
  final FailureClassifier classifier;

  /// The hook configuration (blocked names).
  final PageHookConfig hookConfig;

  /// The `doc_id`s and tokens seen so far; give it to `GraphqlTransport`.
  final PageDiscovery discovery;

  final RequestGovernor _governor;
  final SessionStore _sessions;
  final PageDriver _driver;
  final FutureOr<bool> Function() _pageModeInBackground;
  final DiagnosticLog? _log;
  final UsernameCache _usernames;
  final PageTimerFactory _timer;
  final WebViewLease _lease;
  final MediaMapper _media = const MediaMapper();

  int _droppedOrigin = 0;
  int _droppedMalformed = 0;
  int _blocked = 0;
  int _seenLeaks = 0;

  /// Hook messages dropped because of their origin (AC5), all runs.
  int get droppedOriginCount => _droppedOrigin;

  /// Hook messages dropped for a bad shape, all runs.
  int get droppedMalformedCount => _droppedMalformed;

  /// Requests the hook answered locally instead of sending (UD-3), all runs.
  int get blockedRequestCount => _blocked;

  /// Replies to a blocked name that were captured anyway (the block failed).
  int get seenLeakCount => _seenLeaks;

  // ----------------------------------------------------------------- users

  /// Looks up [username] on its profile page.
  Future<Result<RemoteUser>> resolveUser(String username) => _op(
    'resolveUser',
    () async {
      final clean = username.trim().replaceFirst(RegExp('^@'), '');
      if (!pageUsernameShape.hasMatch(clean)) {
        return const Err(TargetNotFound());
      }
      final r = await _load('resolveUser', PagePlans.profile(clean));
      return switch (r) {
        Err(:final failure) => Err(failure),
        Ok(:final value)
            when value.user.username.toLowerCase() != clean.toLowerCase() =>
          const Err(
            UnknownFailure(null, 'username_mismatch'),
          ),
        Ok(:final value) => await _remember(value),
      };
    },
  );

  /// Reloads a user by loading the profile page of [lastUsername]. The answer
  /// counts only if it has the id [remoteUserId].
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  ) => _op('refreshUser', () async {
    final name = lastUsername.trim();
    if (!pageUsernameShape.hasMatch(name)) return const Err(TargetNotFound());
    final r = await _load('refreshUser', PagePlans.profile(name));
    return switch (r) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.user.remoteUserId != remoteUserId =>
        const Err(TargetNotFound()),
      Ok(:final value) => await _remember(value),
    };
  });

  /// The time of the newest story item of [userId] (profile page).
  Future<Result<DateTime?>> latestStoryTime(String userId) => _op(
    'latestStoryTime',
    () async {
      final profile = await _profileOf(userId, 'latestStoryTime');
      return profile.map((p) => p.latestReelMedia);
    },
  );

  // --------------------------------------------------------------- stories

  /// The stories of [userIds], one page load per user (cost 3 each). Users
  /// without story items are left out. The first failure fails the call.
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds,
  ) => _op('fetchStories', () async {
    final ids = {
      for (final id in userIds)
        if (id.trim().isNotEmpty) id.trim(),
    }.toList();
    final names = <String, String>{};
    for (final id in ids) {
      final name = await _usernameOf(id);
      if (name == null || !pageUsernameShape.hasMatch(name)) {
        return const Err(UnknownFailure(null, 'username_unknown'));
      }
      names[id] = name;
    }
    final out = <String, List<RemoteContent>>{};
    for (final id in ids) {
      final r = await _load('fetchStories', PagePlans.stories(id, names[id]!));
      switch (r) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          if (value.items.isNotEmpty) out[id] = value.items;
      }
    }
    return Ok(out);
  });

  // ----------------------------------------------------------------- posts

  /// Posts of [userId] published after [watermark], newest first, from the
  /// profile page (first page only, like direct mode).
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  ) => _op('fetchNewPosts', () async {
    final t = await _timelineOf(userId, 'fetchNewPosts');
    switch (t) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final seen = <String>{};
        final fresh = [
          for (final e in value.entries)
            if (e.belongsTo(userId) &&
                e.takenAt.isAfter(watermark) &&
                seen.add(e.pk))
              e,
        ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
        return guardMapping(
          () => [
            for (final e in fresh)
              _media.post(
                e.node,
                pinned: e.pinned,
                collab: e.isCollabOf(userId),
              ),
          ],
        );
    }
  });

  /// The publish time of the newest post of [userId], or null.
  Future<Result<DateTime?>> latestPostTime(String userId) => _op(
    'latestPostTime',
    () async {
      final t = await _timelineOf(userId, 'latestPostTime');
      return t.map((timeline) {
        DateTime? latest;
        for (final e in timeline.entries) {
          if (!e.belongsTo(userId)) continue;
          if (latest == null || e.takenAt.isAfter(latest)) latest = e.takenAt;
        }
        return latest;
      });
    },
  );

  /// One post, carousel or reel by [shortcode], from the page's own
  /// `media/<pk>/info/` request. Used to refresh an expired media URL.
  Future<Result<RemoteContent>> fetchPost(String shortcode) => _op(
    'fetchPost',
    () async {
      final plan = PagePlans.post(shortcode);
      if (plan == null) return const Err(TargetNotFound());
      return _load('fetchPost', plan);
    },
  );

  // ------------------------------------------------------------ last resort

  /// LAST RESORT. Loads the profile or story page of [username] and reads the
  /// `img` / `video` CDN URLs from the DOM (read-only). The result has no ids,
  /// times or owners, so it is not `RemoteContent`; use it only to see that
  /// media is on the page when the JSON paths are broken. The URLs are signed:
  /// never log them.
  Future<Result<List<DomMedia>>> lastResortDomMedia(
    String username, {
    bool stories = false,
  }) => _op('lastResortDomMedia', () async {
    if (!pageUsernameShape.hasMatch(username)) {
      return const Err(TargetNotFound());
    }
    final plan = PagePlan<List<DomMedia>>(
      url: Uri.https(
        'www.instagram.com',
        stories ? '/stories/$username/' : '/$username/',
      ),
      collectOnLoad: (page) async =>
          parseDomMedia(await page.collectDomMedia()),
    );
    return _load('lastResortDomMedia', plan);
  });

  // --------------------------------------------------------------- plumbing

  Future<Result<UserProfile>> _profileOf(String userId, String op) async {
    final name = await _usernameOf(userId);
    if (name == null || !pageUsernameShape.hasMatch(name)) {
      return const Err(UnknownFailure(null, 'username_unknown'));
    }
    final r = await _load(op, PagePlans.profile(name));
    if (r is Ok<UserProfile> && r.value.user.remoteUserId != userId) {
      return const Err(TargetNotFound());
    }
    return r;
  }

  Future<Result<Timeline>> _timelineOf(String userId, String op) async {
    final name = await _usernameOf(userId);
    if (name == null || !pageUsernameShape.hasMatch(name)) {
      return const Err(UnknownFailure(null, 'username_unknown'));
    }
    return _load(op, PagePlans.posts(name));
  }

  Future<Result<RemoteUser>> _remember(UserProfile profile) async {
    try {
      await _usernames.remember(
        profile.user.remoteUserId,
        profile.user.username,
      );
    } on Object {
      // Only an optimisation.
    }
    return Ok(profile.user);
  }

  Future<String?> _usernameOf(String userId) async {
    try {
      return await _usernames.usernameOf(userId);
    } on Object {
      return null;
    }
  }

  /// Runs one operation: schema problems and surprises become `Err`; the
  /// outcome is logged without values.
  Future<Result<T>> _op<T>(
    String name,
    Future<Result<T>> Function() body,
  ) async {
    Result<T> result;
    try {
      result = await body();
    } on SchemaException catch (e) {
      result = Err(e.toFailure());
    } on Object catch (error) {
      _log?.log(
        LogLevel.warn,
        'page',
        'op=$name unexpected_error type=${error.runtimeType}',
      );
      result = const Err(UnknownFailure(null, 'unexpected_error'));
    }
    final failure = result.failureOrNull;
    if (failure == null) {
      _log?.log(LogLevel.info, 'page', 'op=$name ok');
    } else {
      final detail = switch (failure) {
        SchemaChanged(:final where) => ' where=$where',
        UnknownFailure(:final code, :final message) =>
          ' code=$code message=$message',
        _ => '',
      };
      _log?.log(
        LogLevel.warn,
        'page',
        'op=$name failure=${failure.runtimeType}$detail',
      );
    }
    return result;
  }

  /// One governed page load (cost `pageLoad`). Gate, session, governor.
  Future<Result<T>> _load<T>(String op, PagePlan<T> plan) async {
    if (runsInBackground) {
      var allowed = false;
      try {
        allowed = await _pageModeInBackground();
      } on Object {
        allowed = false;
      }
      if (!allowed) {
        return const Err(UnknownFailure(null, 'page_mode_background_disabled'));
      }
    }
    if (plan.storyViewer && seenGuard.tripped) {
      _log?.log(LogLevel.warn, 'page', 'op=$op seen_guard_tripped');
      return const Err(UnknownFailure(null, 'seen_guard_tripped'));
    }
    final session = await IgSession.load(_sessions, accountId);
    if (session == null) {
      return const Err(SessionInvalid(SessionReason.loginRequired));
    }
    try {
      return await _governor.run<Result<T>>(
        accountId: accountId,
        cost: RequestCost.pageLoad,
        call: () => _drive(op, plan, session),
      );
    } on GovernorPaused catch (paused) {
      return Err(paused.toFailure());
    } on GovernorBusy {
      return const Err(UnknownFailure(null, 'governor_busy'));
    } on Object catch (error) {
      _log?.log(
        LogLevel.warn,
        'page',
        'op=$op unexpected_error type=${error.runtimeType}',
      );
      return const Err(UnknownFailure(null, 'unexpected_error'));
    }
  }

  /// Drives one WebView until the plan is answered, fails or times out.
  /// Nothing governed happens in here, and it always completes: the lease,
  /// the open, the wait and every clean-up step are bounded.
  Future<Result<T>> _drive<T>(
    String op,
    PagePlan<T> plan,
    IgSession ig,
  ) async {
    PageSession? page;
    StreamSubscription<PageEvent>? sub;
    Timer? timer;
    Timer? settle;
    Timer? grace;
    var leased = false;
    final done = Completer<Result<T>>();
    Result<T>? pending;
    var loadStopped = false;

    void finish(Result<T> r) {
      if (!done.isCompleted) done.complete(r);
    }

    // A tentative answer is accepted after the load plus the grace period.
    void armGrace() {
      if (pending != null && loadStopped && grace == null) {
        grace = _timer(emptyGrace, () => finish(pending!));
      }
    }

    void setPending(Result<T> r) {
      pending ??= r;
      armGrace();
    }

    var accepted = 0;
    var droppedOrigin = 0;
    var droppedMalformed = 0;
    var blocked = 0;
    try {
      // The app-wide WebView lease (QA-F7): never wipe a jar another part of
      // the app is using.
      try {
        leased = await _lease.tryAcquire(_leaseOwner).timeout(cleanupTimeout);
      } on Object {
        leased = false;
      }
      if (!leased) {
        _log?.log(LogLevel.warn, 'page', 'op=$op webview_busy');
        return const Err(UnknownFailure(null, 'webview_busy'));
      }

      final openFuture = _driver.open(
        PageSessionConfig(
          cookies: ig.blob.cookies,
          userAgent: ig.blob.userAgent,
          hookSource: hookConfig.compose(hookSource),
          handlerName: hookConfig.handlerName,
          allowedOrigins: allowedPageOrigins,
        ),
      );
      final openTimedOut = Completer<void>();
      final openTimer = _timer(openTimeout, () {
        if (!openTimedOut.isCompleted) openTimedOut.complete();
      });
      PageSession? opened;
      try {
        opened = await Future.any<PageSession?>([
          openFuture,
          openTimedOut.future.then<PageSession?>((_) => null),
        ]);
      } on PageHookUnsupportedException {
        _log?.log(LogLevel.warn, 'page', 'op=$op page_hook_unsupported');
        return const Err(UnknownFailure(null, 'page_hook_unsupported'));
      } on Object catch (error) {
        _log?.log(
          LogLevel.warn,
          'page',
          'op=$op webview_unavailable type=${error.runtimeType}',
        );
        return const Err(UnknownFailure(null, 'webview_unavailable'));
      } finally {
        openTimer.cancel();
      }
      if (opened == null) {
        // Too slow. If it finishes later, close that session in the
        // background so no WebView or cookie is left behind.
        openFuture
            .then<void>(
              (late) => _closeSession(op, late),
              onError: (Object _) {},
            )
            .ignore();
        _log?.log(LogLevel.warn, 'page', 'op=$op page_open_timeout');
        return const Err(UnknownFailure(null, 'page_open_timeout'));
      }
      page = opened;

      sub = opened.events.listen((event) {
        if (done.isCompleted) return;
        switch (event) {
          case HookEvent():
            final msg = parseHookMessage(
              event.args,
              pageOrigin: event.pageOrigin,
            );
            switch (msg) {
              case HookDropped(:final reason):
                if (reason == HookDropReason.origin) {
                  droppedOrigin++;
                } else {
                  droppedMalformed++;
                }
              case HookBlocked():
                blocked++;
              case HookCapture():
                accepted++;
                if (_isSeenLeak(msg)) {
                  // The reply of a blocked name exists, so the request was
                  // sent: the block failed (UD-3 canary).
                  _seenLeaks++;
                  seenGuard.trip();
                  _log?.log(LogLevel.error, 'page', 'op=$op seen_block_leak');
                  finish(const Err(UnknownFailure(null, 'seen_block_leak')));
                  return;
                }
                discovery.record(
                  friendlyName: msg.friendlyName,
                  docId: msg.docId,
                  tokens: msg.tokens,
                );
                if (plan.matches(msg)) _answer(plan, msg, finish, setPending);
            }
          case NavigationEvent():
            _navigated(plan, event, finish, setPending);
          case HttpErrorEvent():
            final f = classifier.classify(IgReply(status: event.status));
            if (f != null) finish(Err(f));
          case LoadErrorEvent():
            finish(const Err(NetworkFailure()));
          case LoadStopEvent():
            loadStopped = true;
            armGrace();
            final collect = plan.collectOnLoad;
            if (collect != null && settle == null) {
              settle = _timer(domSettle, () async {
                try {
                  finish(Ok(await collect(opened!)));
                } on Object catch (error) {
                  _log?.log(
                    LogLevel.warn,
                    'page',
                    'op=$op dom_failed type=${error.runtimeType}',
                  );
                  finish(const Err(UnknownFailure(null, 'dom_failed')));
                }
              });
            }
        }
      });
      timer = _timer(
        timeout,
        () => finish(pending ?? const Err(SchemaChanged('page_timeout'))),
      );
      // Not awaited: a load that hangs must not outlive the run timer.
      try {
        opened
            .load(plan.url)
            .then<void>(
              (_) {},
              onError: (Object error) {
                _log?.log(
                  LogLevel.warn,
                  'page',
                  'op=$op load_failed type=${error.runtimeType}',
                );
                finish(const Err(UnknownFailure(null, 'load_failed')));
              },
            )
            .ignore();
      } on Object catch (error) {
        _log?.log(
          LogLevel.warn,
          'page',
          'op=$op load_failed type=${error.runtimeType}',
        );
        finish(const Err(UnknownFailure(null, 'load_failed')));
      }
      return await done.future;
    } finally {
      timer?.cancel();
      settle?.cancel();
      grace?.cancel();
      await _guarded(op, 'cancel_events', () async => sub?.cancel());
      final opened = page;
      if (opened != null) await _closeSession(op, opened);
      if (leased) {
        await _guarded(op, 'lease_release', () => _lease.release(_leaseOwner));
      }
      _droppedOrigin += droppedOrigin;
      _droppedMalformed += droppedMalformed;
      _blocked += blocked;
      _log?.log(
        LogLevel.info,
        'page',
        'op=$op accepted=$accepted dropped_origin=$droppedOrigin '
            'dropped_malformed=$droppedMalformed blocked=$blocked',
      );
    }
  }

  String get _leaseOwner => 'page_mode:$accountId';

  /// Clears the data of [session], then disposes it. Each step is bounded
  /// and never rethrows.
  Future<void> _closeSession(String op, PageSession session) async {
    await _guarded(op, 'clear_data', session.clearData);
    await _guarded(op, 'dispose', session.dispose);
  }

  /// A clean-up step that must not stop the next one, hide the result or
  /// hang: bounded by [cleanupTimeout], never rethrows, logs the type only.
  Future<void> _guarded(
    String op,
    String step,
    Future<void> Function() action,
  ) async {
    try {
      await action().timeout(cleanupTimeout);
    } on TimeoutException {
      _log?.log(
        LogLevel.warn,
        'page',
        'op=$op cleanup_timeout step=$step',
      );
    } on Object catch (error) {
      _log?.log(
        LogLevel.warn,
        'page',
        'op=$op cleanup_failed step=$step type=${error.runtimeType}',
      );
    }
  }

  /// Whether a capture is the reply of a blocked request, which can only
  /// exist if the request was sent.
  bool _isSeenLeak(HookCapture capture) {
    final name = capture.friendlyName;
    if (name != null && hookConfig.blockedFriendlyNames.contains(name)) {
      return true;
    }
    final json = capture.json;
    if (json is Map) {
      final data = json['data'];
      if (data is Map && data.containsKey('xdt_mark_story_reel_seen')) {
        return true;
      }
    }
    return false;
  }

  void _answer<T>(
    PagePlan<T> plan,
    HookCapture capture,
    void Function(Result<T>) finish,
    void Function(Result<T>) setPending,
  ) {
    final failure = classifier.classify(
      IgReply(status: capture.status, json: capture.json),
    );
    if (failure != null) {
      finish(Err(failure));
      return;
    }
    try {
      final body = Node.root(capture.json, 'response');
      final r = plan.parse(body);
      if (r != null) {
        finish(r);
        return;
      }
      final t = plan.tentative?.call(body);
      if (t != null) setPending(t);
    } on SchemaException catch (e) {
      finish(Err(e.toFailure()));
    }
  }

  static const List<String> _failurePaths = [
    '/accounts/login',
    '/challenge',
    '/accounts/suspended',
    '/accounts/disabled',
  ];

  /// First path segments that are routes of the site, not user names.
  static const Set<String> _reservedSegments = {
    'accounts',
    'challenge',
    'stories',
    'explore',
    'direct',
    'reels',
    'reel',
    'p',
    'tv',
    'web',
    'about',
    'legal',
  };

  void _navigated<T>(
    PagePlan<T> plan,
    NavigationEvent event,
    void Function(Result<T>) finish,
    void Function(Result<T>) setPending,
  ) {
    final host = event.host;
    if (host != 'instagram.com' && !host.endsWith('.instagram.com')) return;
    final path = event.path.toLowerCase();
    if (_failurePaths.any(path.startsWith)) {
      final f = classifier.classify(IgReply(status: 302, redirectPath: path));
      if (f != null) {
        finish(Err(f));
        return;
      }
    }
    final empty = plan.empty;
    final emptyPath = plan.emptyOnPath;
    if (empty != null && emptyPath != null) {
      final normal = path.length > 1 && path.endsWith('/')
          ? path.substring(0, path.length - 1)
          : path;
      if (normal == emptyPath) {
        setPending(empty);
        return;
      }
      final segments = normal.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.length == 1 && !_reservedSegments.contains(segments.first)) {
        // Another user's page: a renamed account, whose old name is now held
        // by someone else.
        setPending(const Err(UnknownFailure(null, 'username_mismatch')));
      }
    }
  }
}
