// A rig for the in-page tests: the real platform, governor and extractors on
// fake time, with a fake WebView whose script runner is scripted.
import 'dart:async';
import 'dart:convert';

import 'package:storize_domain/testing.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart' as d;
import '../governor/fake_time.dart';
import '../page/support.dart' as p;
import '../platform/support.dart';

const inPageNoJitter = GovernorConfig(
  jitterMin: Duration.zero,
  jitterMax: Duration.zero,
);

/// What the page's script answers: a query name and variables to a result map.
typedef ScriptHandler = Object? Function(
  String name,
  Map<String, Object?> variables,
);

final class RunnerSession implements PageSession, InPageScriptRunner {
  RunnerSession(this.driver);

  final RunnerDriver driver;
  final StreamController<PageEvent> controller = StreamController<PageEvent>();
  final List<Uri> loads = [];
  final List<String> queries = [];
  bool cleared = false;
  bool disposed = false;

  @override
  Stream<PageEvent> get events => controller.stream;

  @override
  Future<void> load(Uri url) async {
    loads.add(url);
    scheduleMicrotask(() => driver.onLoad(this, url));
  }

  @override
  Future<Object?> callAsync(
    String functionBody,
    Map<String, Object?> arguments,
  ) async {
    if (functionBody.endsWith('return __storizeReady();')) {
      return driver.ready(this);
    }
    final name = arguments['name']! as String;
    queries.add(name);
    return driver.script(
      name,
      jsonDecode(arguments['varsJson']! as String) as Map<String, Object?>,
    );
  }

  @override
  Future<Object?> collectDomMedia() async => null;

  @override
  Future<void> scrollDown() async {}

  @override
  Future<void> clearData() async => cleared = true;

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}

final class RunnerDriver implements PageDriver {
  RunnerDriver({required this.script, this.documentStart = true});

  ScriptHandler script;
  final bool documentStart;
  final List<RunnerSession> sessions = [];
  bool isReady = true;

  /// What the page does after `load`: by default it finishes loading.
  void Function(RunnerSession s, Uri url) onLoad = (s, url) =>
      s.controller.add(const LoadStopEvent());

  Object? ready(RunnerSession s) => {'ready': isReady, 'modules': 2};

  @override
  Future<PageSession> open(PageSessionConfig config) async {
    if (!documentStart) throw const PageHookUnsupportedException();
    final s = RunnerSession(this);
    sessions.add(s);
    return s;
  }

  int get loads => sessions.fold(0, (n, s) => n + s.loads.length);
  int get queries => sessions.fold(0, (n, s) => n + s.queries.length);
}

Object? script(Object? json, {int status = 200}) => {
  'status': status,
  'json': json,
};

/// The real posts reply with every post owned by [username].
Map<String, Object?> postsFor(String username) {
  final body = jsonDecode(
    jsonEncode(p.loadReal('profile', '007_graphql.json')),
  ) as Map<String, Object?>;
  final c =
      (body['data']!
              as Map)['xdt_api__v1__feed__user_timeline_graphql_connection']!
          as Map;
  for (final e in c['edges']! as List) {
    ((e as Map)['node'] as Map)['user']['username'] = username;
  }
  return body;
}

Map<String, Object?> emptyPosts() => {
  'data': {
    'xdt_api__v1__feed__user_timeline_graphql_connection': {
      'edges': <Object?>[],
      'page_info': {'has_next_page': false, 'end_cursor': null},
    },
  },
};

Map<String, Object?> emptyStories() => {
  'data': {
    'xdt_api__v1__feed__reels_media': {'reels_media': <Object?>[]},
  },
};

final class InPageRig {
  InPageRig({
    ScriptHandler? handler,
    this.runsInBackground = false,
    FutureOr<bool> Function()? inPageInBackground,
    d.Responder? responder,
    GovernorConfig config = inPageNoJitter,
    bool seedDiscovery = false,
    bool documentStart = true,
    bool withScript = true,
    bool allowUnmetered = false,
  }) : time = FakeTime() {
    leases = FakeGovernorLeaseRepo(time.clock);
    governor = RequestGovernor(
      leases: leases,
      clock: time.clock,
      holder: 'test',
      config: config,
      delay: time.delay,
      log: governorLogs.add,
      allowUnmetered: allowUnmetered,
    );
    unawaited(sessions.save(1, d.fakeSession()));
    unawaited(
      targetRepo.insert(
        Target(
          id: 0,
          platform: PlatformId.instagram,
          remoteUserId: 'user_1',
          username: p.fakeUser,
          category: TargetCategory.public,
          postsWatermarkAt: DateTime.utc(2026),
          addedAt: DateTime.utc(2026),
        ),
      ),
    );
    http = d.FakeIgHttp(responder ?? (_) => d.jsonReply({'status': 'ok'}));
    driver = RunnerDriver(
      script: handler ?? (n, v) => {'error': 'unavailable:tokens'},
      documentStart: documentStart,
    );
    final discovery = PageDiscovery(clock: time.clock);
    if (seedDiscovery) {
      for (final q in GraphqlQuery.values) {
        discovery.record(
          variablesSeen: true,
          friendlyName: q.friendlyName,
          docId: p.fakeDocId,
          tokens: {'fb_dtsg': d.fakeDtsg, 'lsd': d.fakeLsd},
        );
      }
    }
    platform = InstagramPlatform.assemble(
      accountId: 1,
      governor: governor,
      sessions: sessions,
      http: http,
      cdnHttp: FakeCdnHttp(
        (uri, headers) => CdnResponse(
          status: 200,
          body: bodyOf([
            [1],
          ]),
        ),
      ),
      pageDriver: driver,
      hookSource: '/* hook */',
      targets: targetRepo,
      appId: d.fakeAppId,
      log: log,
      clock: time.clock,
      discovery: discovery,
      seenGuard: SeenGuard(),
      runsInBackground: runsInBackground,
      inPageScript: withScript ? 'SCRIPT' : null,
      inPageInBackground: inPageInBackground,
      pageTimer: timer,
    );
  }

  final bool runsInBackground;
  final FakeTime time;
  late final FakeGovernorLeaseRepo leases;
  late final RequestGovernor governor;
  final FakeSessionStore sessions = FakeSessionStore();
  final FakeTargetRepo targetRepo = FakeTargetRepo();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final List<String> governorLogs = [];
  final List<p.ManualTimer> manual = [];
  late final d.FakeIgHttp http;
  late final RunnerDriver driver;
  late final InstagramPlatform platform;

  /// Poll sleeps (500 ms) fire at once and move the fake clock; the idle and
  /// the timeouts are manual.
  Timer timer(Duration duration, void Function() fire) {
    final t = p.ManualTimer(duration, fire);
    if (duration == const Duration(milliseconds: 500)) {
      time.clock.set(time.clock.now().add(duration));
      scheduleMicrotask(t.fire);
    } else {
      manual.add(t);
    }
    return t;
  }

  Future<T> run<T>(Future<T> future) => time.drive(future);

  String get logs =>
      '${logText(log)}\n${governorLogs.join('\n')}\n${http.requests}';
}
