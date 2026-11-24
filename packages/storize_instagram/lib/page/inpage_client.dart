import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/failure_classifier.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/direct/ig_session.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/page/hook_config.dart';
import 'package:storize_instagram/page/hook_protocol.dart';
import 'package:storize_instagram/page/inpage_script.dart';
import 'package:storize_instagram/page/page_discovery.dart';
import 'package:storize_instagram/page/page_driver.dart';
import 'package:storize_instagram/page/page_extractor.dart'
    show PageTimerFactory;
import 'package:storize_instagram/page/page_plan.dart';
import 'package:storize_instagram/page/user_initiated.dart';
import 'package:storize_instagram/page/webview_lease.dart';
import 'package:storize_model/storize_model.dart';

/// The reason of the `UnknownFailure` that says "in-page fetching cannot run
/// now": the platform then falls back to direct HTTP (ADR-0003 amendment).
const String inPageUnavailableReason = 'inpage_unavailable';

/// Whether [failure] is the "in-page is unavailable" signal.
bool isInPageUnavailable(Failure? failure) =>
    failure is UnknownFailure &&
    failure.code == null &&
    failure.message == inPageUnavailableReason;

/// The status the client gives an `IgReply` for "the page could not run the
/// query" (an unavailable module or token). `InPageOps` turns it into the
/// unavailable signal through [InPageClient.takeUnavailable].
const int inPageUnavailableStatus = 599;

/// One headless WebView session on `https://www.instagram.com/` that runs the
/// web app's own GraphQL read queries from inside the page (T-050,
/// ADR-0003 amendment "in-page fetch is primary").
///
/// - **One session per run.** [ensureOpen] opens it once (one governed page
///   load, cost `pageLoad`) and reuses it; [close] ends it (the app closes at
///   the end of a run) and an idle timer ([idleTimeout], 2 min) closes it by
///   itself.
/// - **Governor.** The page load is one `run` with cost `pageLoad`. [query]
///   does not govern: the caller (`DirectExtractor` through [InPageHttp])
///   wraps each query in a `run` with cost `api`, so governed calls never
///   nest. [loadProfile] is a governed page load (cost `pageLoad`).
/// - **Safety.** The hook (seen block) is installed at document start; the
///   app-wide WebView lease is held for the session's life; a login redirect,
///   a challenge or an HTTP error ends the session with the failure map.
///   Only allowlisted read queries are sent (`inPageQueryAllowed`).
/// - **Logs.** `session_open ms= ready= modules=`, `session_close queries=`;
///   no values.
final class InPageClient {
  /// Creates the client for the login account [accountId].
  InPageClient({
    required this.accountId,
    required this._governor,
    required this._sessions,
    required this._driver,
    required this.hookSource,
    required this.script,
    this.runsInBackground = false,
    FutureOr<bool> Function()? inPageInBackground,
    this._log,
    PageHookConfig? hookConfig,
    PageDiscovery? discovery,
    SeenGuard? seenGuard,
    WebViewLease? webViewLease,
    this.classifier = const FailureClassifier(),
    this._clock = const SystemClock(),
    this._timer = Timer.new,
    this.readyTimeout = const Duration(seconds: 10),
    this.pollInterval = const Duration(milliseconds: 500),
    this.loadTimeout = const Duration(seconds: 20),
    this.openTimeout = const Duration(seconds: 10),
    this.queryTimeout = const Duration(seconds: 30),
    this.cleanupTimeout = const Duration(seconds: 5),
    this.idleTimeout = const Duration(minutes: 2),
  }) : _inPageInBackground = inPageInBackground ?? (() => true),
       hookConfig = hookConfig ?? PageHookConfig(),
       // ignore: prefer_initializing_formals, a private field behind a name.
       _discovery = discovery,
       _seenGuard = seenGuard ?? SeenGuard.shared,
       _lease = webViewLease ?? const NoopWebViewLease();

  /// The login account.
  final int accountId;

  /// The content of `assets/hook.js`.
  final String hookSource;

  /// The content of `assets/inpage_query.js`.
  final String script;

  /// Whether this runs in a background isolate (gated by the setting).
  final bool runsInBackground;

  /// The failure map.
  final FailureClassifier classifier;

  /// The hook configuration.
  final PageHookConfig hookConfig;

  /// How long the page may take to expose its tokens (10 s).
  final Duration readyTimeout;

  /// The wait between readiness checks.
  final Duration pollInterval;

  /// How long the page load may take.
  final Duration loadTimeout;

  /// How long `driver.open` may take.
  final Duration openTimeout;

  /// How long one script call may take.
  final Duration queryTimeout;

  /// How long each clean-up step may take.
  final Duration cleanupTimeout;

  /// The idle time after which the session closes by itself (2 min).
  final Duration idleTimeout;

  final RequestGovernor _governor;
  final SessionStore _sessions;
  final PageDriver _driver;
  final FutureOr<bool> Function() _inPageInBackground;
  final DiagnosticLog? _log;
  final PageDiscovery? _discovery;
  final SeenGuard _seenGuard;
  final WebViewLease _lease;
  final Clock _clock;
  final PageTimerFactory _timer;

  PageSession? _session;
  InPageScriptRunner? _runner;
  // Cancelled in close().
  // ignore: cancel_subscriptions
  StreamSubscription<PageEvent>? _sub;
  Future<Result<bool>>? _opening;
  Timer? _idle;
  bool _leased = false;
  int _queries = 0;
  int _inflight = 0;
  bool _unavailable = false;
  int _opened = 0;
  Failure? _failure;
  Completer<void>? _loadStopped;
  _Waiter? _waiter;

  /// Whether a session is open.
  bool get isOpen => _session != null;

  /// Sessions opened so far (the load counter of tests).
  int get sessionsOpened => _opened;

  /// Queries sent in the current session.
  int get queriesInSession => _queries;

  /// Reads and resets "a query could not run because the page lacked a
  /// module or token".
  bool takeUnavailable() {
    final v = _unavailable;
    _unavailable = false;
    return v;
  }

  String get _leaseOwner => 'inpage:$accountId';

  // ------------------------------------------------------------------ open

  /// Opens the session if there is none (one governed page load, cost 3).
  /// `Ok(true)` when a session is ready; `Err(unavailable)` when the page
  /// cannot run queries (the platform falls back to direct HTTP); any other
  /// `Err` is a real failure (login lost, rate limit, network, busy).
  Future<Result<bool>> ensureOpen() {
    if (_session != null && _failure == null) {
      _touch();
      return Future.value(const Ok(true));
    }
    return _opening ??= _openGoverned().whenComplete(() => _opening = null);
  }

  Future<Result<bool>> _openGoverned() async {
    if (_session != null) await close(); // A failed session: start clean.
    if (runsInBackground && !isUserInitiatedRun) {
      var allowed = true;
      try {
        allowed = await _inPageInBackground();
      } on Object {
        allowed = true;
      }
      if (!allowed) {
        _log?.log(LogLevel.info, 'inpage', 'background_disabled');
        return const Err(UnknownFailure(null, inPageUnavailableReason));
      }
    }
    final ig = await IgSession.load(_sessions, accountId);
    if (ig == null) {
      return const Err(SessionInvalid(SessionReason.loginRequired));
    }
    try {
      return await _governor.run<Result<bool>>(
        accountId: accountId,
        cost: RequestCost.pageLoad,
        call: () => _open(ig),
      );
    } on GovernorPaused catch (paused) {
      return Err(paused.toFailure());
    } on GovernorBusy {
      return const Err(UnknownFailure(null, 'governor_busy'));
    } on Object catch (error) {
      _log?.log(
        LogLevel.warn,
        'inpage',
        'unexpected_error type=${error.runtimeType}',
      );
      await close();
      return const Err(UnknownFailure(null, 'unexpected_error'));
    }
  }

  Future<Result<bool>> _open(IgSession ig) async {
    final started = _clock.now();
    _failure = null;
    _loadStopped = Completer<void>();
    var modules = 0;
    var ready = false;

    Result<bool> unavailable(String why) {
      _log?.log(LogLevel.warn, 'inpage', 'unavailable why=$why');
      return const Err(UnknownFailure(null, inPageUnavailableReason));
    }

    try {
      var leased = false;
      try {
        leased = await _lease.tryAcquire(_leaseOwner).timeout(cleanupTimeout);
      } on Object {
        leased = false;
      }
      if (!leased) {
        _log?.log(LogLevel.warn, 'inpage', 'webview_busy');
        return const Err(UnknownFailure(null, 'webview_busy'));
      }
      _leased = true;

      final openFuture = _driver.open(
        PageSessionConfig(
          cookies: ig.blob.cookies,
          userAgent: ig.blob.userAgent,
          hookSource: hookConfig.compose(hookSource),
          handlerName: hookConfig.handlerName,
          allowedOrigins: allowedPageOrigins,
        ),
      );
      final timedOut = Completer<void>();
      final openTimer = _timer(openTimeout, () {
        if (!timedOut.isCompleted) timedOut.complete();
      });
      PageSession? opened;
      try {
        opened = await Future.any<PageSession?>([
          openFuture,
          timedOut.future.then<PageSession?>((_) => null),
        ]);
      } on PageHookUnsupportedException {
        await _releaseLease();
        return unavailable('hook_unsupported');
      } on Object catch (error) {
        await _releaseLease();
        return unavailable('open_failed type=${error.runtimeType}');
      } finally {
        openTimer.cancel();
      }
      if (opened == null) {
        openFuture.then<void>((late) async {
          await _guarded('clear_data', late.clearData);
          await _guarded('dispose', late.dispose);
        }, onError: (Object _) {}).ignore();
        await _releaseLease();
        return unavailable('open_timeout');
      }
      final runner = opened is InPageScriptRunner
          ? opened as InPageScriptRunner
          : null;
      _session = opened;
      _runner = runner;
      _sub = opened.events.listen(_onEvent);
      if (runner == null) {
        await close(quiet: true);
        return unavailable('no_script_runner');
      }

      try {
        await opened.load(Uri.https('www.instagram.com', '/'));
      } on Object catch (error) {
        await close(quiet: true);
        return unavailable('load_failed type=${error.runtimeType}');
      }
      // Wait for the load, then for the page to expose its tokens.
      final deadline = started.add(loadTimeout + readyTimeout);
      var loaded = false;
      final loadTimer = _timer(loadTimeout, () {
        final c = _loadStopped;
        if (c != null && !c.isCompleted) c.complete();
      });
      try {
        await _loadStopped!.future;
        loaded = _failure == null;
      } finally {
        loadTimer.cancel();
      }
      if (_failure != null) {
        final f = _failure!;
        await close(quiet: true);
        return Err(f);
      }
      final readyDeadline = _clock.now().add(readyTimeout);
      while (loaded) {
        final probe = await _probe(runner);
        if (_failure != null) break;
        if (probe != null) {
          modules = probe.$2;
          if (probe.$1) {
            ready = true;
            break;
          }
        }
        if (!_clock.now().isBefore(readyDeadline) ||
            !_clock.now().isBefore(deadline)) {
          break;
        }
        await _sleep(pollInterval);
      }
      final ms = _clock.now().difference(started).inMilliseconds;
      _log?.log(
        LogLevel.info,
        'inpage',
        'session_open ms=$ms ready=${ready ? 'yes' : 'no'} modules=$modules',
      );
      final failure = _failure;
      if (failure != null) {
        await close(quiet: true);
        return Err(failure);
      }
      if (!ready) {
        await close(quiet: true);
        return const Err(UnknownFailure(null, inPageUnavailableReason));
      }
      _opened++;
      _queries = 0;
      _touch();
      return const Ok(true);
    } on Object {
      await close(quiet: true);
      rethrow;
    }
  }

  Future<(bool, int)?> _probe(InPageScriptRunner runner) async {
    try {
      final r = await runner
          .callAsync(inPageReadyBody(script), const {})
          .timeout(queryTimeout);
      if (r is Map) {
        final modules = r['modules'];
        return (r['ready'] == true, modules is int ? modules : 0);
      }
    } on Object {
      // Not ready yet.
    }
    return null;
  }

  Future<void> _sleep(Duration d) {
    final c = Completer<void>();
    _timer(d, c.complete);
    return c.future;
  }

  // ----------------------------------------------------------------- query

  /// Runs one allowlisted read query in the page. Not governed (see the class
  /// comment). Throws [TransportException] when the page could not send it.
  /// A page that lacks a module or token gives an `IgReply` with status
  /// [inPageUnavailableStatus] and sets [takeUnavailable].
  Future<IgReply> query(String name, String varsJson) async {
    if (!inPageQueryAllowed(name)) return const IgReply(status: 400);
    final runner = _runner;
    final failure = _failure;
    if (runner == null || _session == null) {
      throw const TransportException('no_session');
    }
    if (failure != null) return _replyOf(failure);
    _inflight++;
    _idle?.cancel();
    try {
      _queries++;
      final Object? raw;
      try {
        raw = await runner
            .callAsync(inPageQueryBody(script), {
              'name': name,
              'varsJson': varsJson,
            })
            .timeout(queryTimeout);
      } on Object {
        _log?.log(LogLevel.warn, 'inpage', 'op=$name error=call_failed');
        throw const TransportException('call_failed');
      }
      if (_failure != null) return _replyOf(_failure!);
      return _replyFromScript(name, raw);
    } finally {
      _inflight--;
      _touch();
    }
  }

  IgReply _replyFromScript(String name, Object? raw) {
    if (raw is! Map) {
      _log?.log(LogLevel.warn, 'inpage', 'op=$name error=bad_result');
      throw const TransportException('bad_result');
    }
    final error = raw['error'];
    final status = raw['status'];
    if (error is String && status is! int) {
      final code = error.replaceAll(RegExp('[^A-Za-z0-9_:]'), '');
      _log?.log(LogLevel.warn, 'inpage', 'op=$name error=$code');
      if (code.startsWith('unavailable')) {
        _unavailable = true;
        return const IgReply(status: inPageUnavailableStatus);
      }
      if (code == 'network') throw const TransportException('network');
      return const IgReply(status: 400);
    }
    final s = status is int ? status : 0;
    if (error is String) {
      _log?.log(LogLevel.warn, 'inpage', 'op=$name error=bad_json status=$s');
      return IgReply(status: s);
    }
    final shielded = raw['shielded'] == true;
    final json = raw['json'];
    final count = _itemCount(json);
    _log?.log(
      LogLevel.info,
      'inpage',
      shielded
          ? 'op=$name status=$s error=shielded'
          : 'op=$name status=$s items=$count',
    );
    return IgReply(status: s, json: json, shielded: shielded);
  }

  /// The number of entries of the first list found under `data` (a count
  /// only, never a value).
  static int _itemCount(Object? json) {
    if (json is! Map) return 0;
    final data = json['data'];
    if (data is! Map) return 0;
    int walk(Object? v, int depth) {
      if (v is List) return v.length;
      if (v is Map && depth < 3) {
        for (final key in const ['edges', 'items', 'reels_media']) {
          final inner = v[key];
          if (inner is List) return inner.length;
        }
        for (final inner in v.values) {
          final n = walk(inner, depth + 1);
          if (n > 0) return n;
        }
      }
      return 0;
    }

    return walk(data, 0);
  }

  IgReply _replyOf(Failure failure) => switch (failure) {
    SessionInvalid(:final reason) when reason == SessionReason.challenge =>
      const IgReply(status: 302, redirectPath: '/challenge/'),
    SessionInvalid() => const IgReply(status: 401),
    NetworkFailure() => throw const TransportException('network'),
    _ => const IgReply(status: 400),
  };

  // --------------------------------------------------------------- profile

  /// The profile of [username] read from its profile page, in the same
  /// session (the fallback of `resolveUser` for an account without posts).
  /// One governed page load (cost `pageLoad`). The session must be open.
  Future<Result<UserProfile>> loadProfile(String username) async {
    final session = _session;
    if (session == null) return const Err(NetworkFailure());
    try {
      return await _governor.run<Result<UserProfile>>(
        accountId: accountId,
        cost: RequestCost.pageLoad,
        call: () => _navigateProfile(session, username),
      );
    } on GovernorPaused catch (paused) {
      return Err(paused.toFailure());
    } on GovernorBusy {
      return const Err(UnknownFailure(null, 'governor_busy'));
    } on Object catch (error) {
      _log?.log(
        LogLevel.warn,
        'inpage',
        'unexpected_error type=${error.runtimeType}',
      );
      return const Err(UnknownFailure(null, 'unexpected_error'));
    }
  }

  Future<Result<UserProfile>> _navigateProfile(
    PageSession session,
    String username,
  ) async {
    final plan = PagePlans.profile(username);
    final done = Completer<Result<UserProfile>>();
    _idle?.cancel();
    _inflight++;
    _waiter = _Waiter(
      onCapture: (capture) {
        if (done.isCompleted || !plan.matches(capture)) return;
        final failure = classifier.classify(
          IgReply(status: capture.status, json: capture.json),
        );
        if (failure != null) {
          done.complete(Err(failure));
          return;
        }
        try {
          final r = plan.parse(Node.root(capture.json, 'response'));
          if (r != null) done.complete(r);
        } on SchemaException catch (e) {
          done.complete(Err(e.toFailure()));
        }
      },
      onFailure: (f) {
        if (!done.isCompleted) done.complete(Err(f));
      },
    );
    final timer = _timer(loadTimeout, () {
      if (!done.isCompleted) {
        done.complete(const Err(SchemaChanged('page_timeout')));
      }
    });
    try {
      session
          .load(plan.url)
          .then<void>(
            (_) {},
            onError: (Object _) {
              if (!done.isCompleted) {
                done.complete(const Err(UnknownFailure(null, 'load_failed')));
              }
            },
          )
          .ignore();
      final r = await done.future;
      _log?.log(
        LogLevel.info,
        'inpage',
        'op=resolveUser via=profile_page '
            '${r is Ok ? 'status=ok' : 'error=${r.failureOrNull.runtimeType}'}',
      );
      return r;
    } finally {
      timer.cancel();
      _waiter = null;
      _inflight--;
      _touch();
    }
  }

  // ---------------------------------------------------------------- events

  static const List<String> _failurePaths = [
    '/accounts/login',
    '/challenge',
    '/accounts/suspended',
    '/accounts/disabled',
  ];

  void _fail(Failure failure) {
    _failure ??= failure;
    final c = _loadStopped;
    if (c != null && !c.isCompleted) c.complete();
    _waiter?.onFailure(failure);
  }

  void _onEvent(PageEvent event) {
    switch (event) {
      case HookEvent():
        final msg = parseHookMessage(event.args, pageOrigin: event.pageOrigin);
        switch (msg) {
          case HookDiscovery():
            _discovery?.recordDiscovery(
              msg.ops,
              msg.tokens,
              tokenSources: msg.tokenSources,
            );
          case HookCapture():
            final name = msg.friendlyName;
            final json = msg.json;
            final leak =
                (name != null &&
                    hookConfig.blockedFriendlyNames.contains(name)) ||
                (json is Map &&
                    json['data'] is Map &&
                    (json['data'] as Map).containsKey(
                      'xdt_mark_story_reel_seen',
                    ));
            if (leak) {
              _seenGuard.trip();
              _log?.log(LogLevel.error, 'inpage', 'seen_block_leak');
              _fail(const UnknownFailure(null, 'seen_block_leak'));
              return;
            }
            _discovery?.record(
              friendlyName: msg.friendlyName,
              docId: msg.docId,
              tokens: msg.tokens,
              provided: msg.provided,
              args: msg.args,
              variablesSeen: msg.variablesSeen,
            );
            _waiter?.onCapture(msg);
          case HookDropped() || HookBlocked():
            break;
        }
      case NavigationEvent():
        final host = event.host;
        if (host != 'instagram.com' && !host.endsWith('.instagram.com')) {
          return;
        }
        final path = event.path.toLowerCase();
        if (_failurePaths.any(path.startsWith)) {
          final f = classifier.classify(
            IgReply(status: 302, redirectPath: path),
          );
          if (f != null) _fail(f);
        }
      case HttpErrorEvent():
        final f = classifier.classify(IgReply(status: event.status));
        if (f != null) _fail(f);
      case LoadErrorEvent():
        _fail(const NetworkFailure());
      case LoadStopEvent():
        final c = _loadStopped;
        if (c != null && !c.isCompleted) c.complete();
    }
  }

  // ----------------------------------------------------------------- close

  void _touch() {
    _idle?.cancel();
    if (_session == null) return;
    _idle = _timer(idleTimeout, () {
      if (_inflight > 0) {
        _touch();
      } else {
        close().ignore();
      }
    });
  }

  Future<void> _releaseLease() async {
    if (!_leased) return;
    _leased = false;
    await _guarded('lease_release', () => _lease.release(_leaseOwner));
  }

  /// Closes the session: clears cookies and web data, disposes the WebView,
  /// releases the lease. Idempotent, bounded, never throws.
  Future<void> close({bool quiet = false}) async {
    _idle?.cancel();
    _idle = null;
    final session = _session;
    final queries = _queries;
    _session = null;
    _runner = null;
    _waiter = null;
    final sub = _sub;
    _sub = null;
    if (session != null) {
      await _guarded('cancel_events', () async => sub?.cancel());
      await _guarded('clear_data', session.clearData);
      await _guarded('dispose', session.dispose);
      if (!quiet) {
        _log?.log(LogLevel.info, 'inpage', 'session_close queries=$queries');
      }
    }
    await _releaseLease();
    final d = _discovery;
    if (d != null) await _guarded('discovery_flush', d.flush);
    _queries = 0;
  }

  Future<void> _guarded(String step, Future<void> Function() action) async {
    try {
      await action().timeout(cleanupTimeout);
    } on TimeoutException {
      _log?.log(LogLevel.warn, 'inpage', 'cleanup_timeout step=$step');
    } on Object catch (error) {
      _log?.log(
        LogLevel.warn,
        'inpage',
        'cleanup_failed step=$step type=${error.runtimeType}',
      );
    }
  }
}

final class _Waiter {
  const _Waiter({required this.onCapture, required this.onFailure});

  final void Function(HookCapture capture) onCapture;
  final void Function(Failure failure) onFailure;
}

/// An `IgHttp` whose "network" is the page of an [InPageClient]. A request is
/// the neutral form made by `InPageTransport`: `name` and `variables`.
final class InPageHttp implements IgHttp {
  /// Creates the adapter.
  const InPageHttp(this.client);

  /// The page session.
  final InPageClient client;

  @override
  Future<IgReply> send(IgRequest request) {
    final form = request.form ?? const <String, String>{};
    return client.query(form['name'] ?? '', form['variables'] ?? '{}');
  }
}
