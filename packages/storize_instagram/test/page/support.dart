// Helpers for the page-mode tests: a scripted fake WebView, hook message
// builders, a manual timer and a rig with the real governor on fake time.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import '../governor/fake_time.dart';

/// Fake secrets: none of these may reach a log.
const fakeSessionId = 'ZZFAKE_sessionid_value';
const fakeCsrf = 'ZZFAKE_csrf_value';
const fakeAgent = 'ZZFAKE-Agent/1.0 (test)';
const fakeDtsg = 'ZZFAKE_dtsg_value';
const fakeLsd = 'ZZFAKE_lsd_value';
const fakeDocId = '9876543210123';
const fakeUser = 'zzfake_user';
const viewerId = 'user_3';
const okOrigin = 'https://www.instagram.com';

Object? loadReal(String capture, String body) => jsonDecode(
  File('test/fixtures/real/$capture/bodies/$body').readAsStringSync(),
);

Object? loadPage(String name) =>
    jsonDecode(File('test/fixtures/page/$name').readAsStringSync());

Object? loadSynthetic(String name) =>
    jsonDecode(File('test/fixtures/synthetic/$name').readAsStringSync());

/// The real profile reply with the placeholder username replaced.
Map<String, Object?> realProfile({String username = fakeUser}) {
  final body = loadReal('profile', '004_graphql.json')! as Map<String, Object?>;
  final copy = jsonDecode(jsonEncode(body)) as Map<String, Object?>;
  ((copy['data']! as Map)['user']! as Map)['username'] = username;
  return copy;
}

/// The real media info reply with the placeholder shortcode replaced.
Map<String, Object?> realMediaInfo(String code) {
  final body =
      loadReal('post_photo', '003_media_info.json')! as Map<String, Object?>;
  final copy = jsonDecode(jsonEncode(body)) as Map<String, Object?>;
  ((copy['items']! as List).first as Map)['code'] = code;
  return copy;
}

SessionBlob fakeSession() => SessionBlob(
  cookies: const {
    'sessionid': fakeSessionId,
    'ds_user_id': viewerId,
    'csrftoken': fakeCsrf,
  },
  userAgent: fakeAgent,
  capturedAt: DateTime.utc(2026),
);

/// A hook "response" message as the native side delivers it.
HookEvent hookResponse(
  Object? body, {
  String? name,
  String path = '/api/graphql',
  int status = 200,
  String pageOrigin = okOrigin,
  String claimedOrigin = okOrigin,
  String host = 'www.instagram.com',
  String? docId = fakeDocId,
  Map<String, String>? tokens,
}) => HookEvent(
  pageOrigin: pageOrigin,
  args: [
    {
      'url': 'https://$host$path',
      'status': status,
      'bodyLength': 1,
      'topLevelKeys': ['data'],
      'origin': claimedOrigin,
      'via': 'fetch',
      'friendlyName': ?name,
      'body': jsonEncode(body),
      'request': {
        'docId': docId,
        'tokens': tokens ?? {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
      },
    },
  ],
);

HookEvent hookBlocked(String name, {String pageOrigin = okOrigin}) => HookEvent(
  pageOrigin: pageOrigin,
  args: [
    {
      'type': 'blocked',
      'friendlyName': name,
      'origin': okOrigin,
      'via': 'fetch',
    },
  ],
);

const storiesName = 'PolarisStoriesV3ReelPageStandaloneQuery';
const profileName = 'PolarisProfilePageContentQuery';
const postsName = 'PolarisProfilePostsQuery';
const seenName = 'PolarisStoriesV3SeenMutation';

/// A scripted fake WebView. `onLoad` decides which events the "page" emits.
final class FakePageSession implements PageSession {
  FakePageSession(this.driver, this.config);

  final FakePageDriver driver;
  final PageSessionConfig config;
  final StreamController<PageEvent> controller = StreamController<PageEvent>();
  final List<Uri> loads = [];
  bool cleared = false;
  bool disposed = false;
  int collectCalls = 0;

  void emit(PageEvent e) => controller.add(e);

  @override
  Stream<PageEvent> get events => controller.stream;

  @override
  Future<void> load(Uri url) async {
    loads.add(url);
    driver.log.add('load');
    // Events come after `load` returns, like a real page.
    scheduleMicrotask(() => driver.onLoad(this, url));
  }

  @override
  Future<Object?> collectDomMedia() async {
    collectCalls++;
    return driver.domResult;
  }

  @override
  Future<void> clearData() async {
    driver.log.add('clear');
    cleared = true;
    if (driver.clearThrows) throw StateError('clear failed ZZFAKE_cookie');
    if (driver.clearHangs) await Completer<void>().future;
  }

  @override
  Future<void> dispose() async {
    driver.log.add('dispose');
    disposed = true;
    driver.active--;
    await controller.close();
    if (driver.disposeHangs) await Completer<void>().future;
  }
}

typedef OnLoad = void Function(FakePageSession session, Uri url);

final class FakePageDriver implements PageDriver {
  FakePageDriver(
    this.onLoad, {
    this.openThrows = false,
    this.clearThrows = false,
    this.clearHangs = false,
    this.disposeHangs = false,
    this.documentStart = true,
    this.openGate,
  });

  OnLoad onLoad;
  final bool openThrows;
  final bool clearThrows;
  final bool clearHangs;
  final bool disposeHangs;

  /// False: `open` throws [PageHookUnsupportedException] like the real
  /// adapter on a WebView without document-start scripts.
  final bool documentStart;

  /// When set, `open` waits for it before it returns the session.
  final Completer<void>? openGate;
  Object? domResult;
  final List<String> log = [];
  final List<FakePageSession> sessions = [];
  int active = 0;
  int maxActive = 0;

  @override
  Future<PageSession> open(PageSessionConfig config) async {
    log.add('open');
    if (!documentStart) throw const PageHookUnsupportedException();
    final gate = openGate;
    if (gate != null) await gate.future;
    if (openThrows) throw StateError('no webview ZZFAKE_cookie');
    final s = FakePageSession(this, config);
    sessions.add(s);
    active++;
    if (active > maxActive) maxActive = active;
    return s;
  }
}

/// A timer the test fires by hand.
final class ManualTimer implements Timer {
  ManualTimer(this.duration, this._fire);

  final Duration duration;
  final void Function() _fire;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    if (cancelled || fired) return;
    fired = true;
    _fire();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}

const noJitter = GovernorConfig(
  jitterMin: Duration.zero,
  jitterMax: Duration.zero,
);

final class Rig {
  Rig({
    required OnLoad onLoad,
    this.runsInBackground = false,
    bool Function()? backgroundAllowed,
    bool withSession = true,
    this.autoGrace = true,
    bool openThrows = false,
    bool clearThrows = false,
    bool clearHangs = false,
    bool disposeHangs = false,
    bool documentStart = true,
    Completer<void>? openGate,
    Duration cleanupTimeout = const Duration(seconds: 5),
    WebViewLease? webViewLease,
    SeenGuard? seenGuard,
    Map<String, String> usernames = const {'user_1': fakeUser},
    PageHookConfig? hookConfig,
  }) {
    leases = FakeGovernorLeaseRepo(time.clock);
    governor = RequestGovernor(
      leases: leases,
      clock: time.clock,
      holder: 'test',
      config: noJitter,
      delay: time.delay,
      log: governorLogs.add,
    );
    driver = FakePageDriver(
      onLoad,
      openThrows: openThrows,
      clearThrows: clearThrows,
      clearHangs: clearHangs,
      disposeHangs: disposeHangs,
      documentStart: documentStart,
      openGate: openGate,
    );
    if (withSession) unawaited(sessions.save(1, fakeSession()));
    final cache = InMemoryUsernameCache();
    usernames.forEach((id, name) => unawaited(cache.remember(id, name)));
    discovery = PageDiscovery(clock: time.clock);
    extractor = PageExtractor(
      accountId: 1,
      governor: governor,
      sessions: sessions,
      driver: driver,
      hookSource: '/* hook source */',
      runsInBackground: runsInBackground,
      pageModeInBackground: backgroundAllowed,
      log: log,
      hookConfig: hookConfig,
      discovery: discovery,
      usernames: cache,
      timer: manualTimers,
      cleanupTimeout: cleanupTimeout,
      webViewLease: webViewLease,
      seenGuard: seenGuard ?? SeenGuard(),
    );
  }

  /// The timer factory of the rig: the open timer (10 s) goes to
  /// [openTimers], every other one (run 20 s, grace, DOM settle) to [timers].
  Timer manualTimers(Duration d, void Function() fire) {
    final t = ManualTimer(d, fire);
    (d == const Duration(seconds: 10) ? openTimers : timers).add(t);
    if (autoGrace && d == const Duration(seconds: 2)) scheduleMicrotask(t.fire);
    return t;
  }

  final bool runsInBackground;

  /// When true the "tentative answer" grace timer (2 s) fires by itself,
  /// right after it is armed (a microtask later). Set false to fire it by
  /// hand from `timers`.
  final bool autoGrace;
  final FakeTime time = FakeTime();
  late final FakeGovernorLeaseRepo leases;
  late final RequestGovernor governor;
  late final FakePageDriver driver;
  late final PageDiscovery discovery;
  late final PageExtractor extractor;
  final FakeSessionStore sessions = FakeSessionStore();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final List<String> governorLogs = [];
  final List<ManualTimer> timers = [];
  final List<ManualTimer> openTimers = [];

  Future<T> run<T>(Future<T> future) => time.drive(future);

  String get allLogs =>
      '${log.entries.map((e) => '$e ${e.error ?? ''}').join('\n')}\n'
      '${governorLogs.join('\n')}';
}

/// Emits [events] when the page loads.
OnLoad emitting(List<PageEvent> events) =>
    (s, url) => events.forEach(s.emit);

/// A lease with a scripted answer that records every call.
final class FakeWebViewLease implements WebViewLease {
  FakeWebViewLease({this.busy = false});

  /// True: another owner holds the lease, `tryAcquire` says no.
  bool busy;
  final List<String> acquired = [];
  final List<String> released = [];

  @override
  Future<bool> tryAcquire(String owner) async {
    if (busy) return false;
    acquired.add(owner);
    return true;
  }

  @override
  Future<void> release(String owner) async => released.add(owner);
}
