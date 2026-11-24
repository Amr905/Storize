// T-015 with the REAL extractors, governor and lease on fakes: governor
// discipline, shared discovery, the GraphQL default, the background gate, the
// WebView lease (R2-F2/F3), the seen breaker (R2-F5), signals (N3) and the
// persistent username cache.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// Direct import until the Lead exports the port from the barrel.
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart' as d;
import '../governor/fake_time.dart';
import '../page/support.dart' as p;
import 'support.dart';

const _noJitter = GovernorConfig(
  jitterMin: Duration.zero,
  jitterMax: Duration.zero,
);

Target _target(String id, String name) => Target(
  id: 0,
  platform: PlatformId.instagram,
  remoteUserId: id,
  username: name,
  category: TargetCategory.public,
  postsWatermarkAt: DateTime.utc(2026),
  addedAt: DateTime.utc(2026),
);

/// The platform, assembled from the real parts on fake time.
class _Rig {
  _Rig({
    d.Responder? responder,
    p.OnLoad? onLoad,
    GovernorConfig config = _noJitter,
    bool seedDiscovery = false,
    this.runsInBackground = false,
    bool Function()? backgroundAllowed,
    SeenGuard? seenGuard,
    GovernorWebViewLease? webViewLease,
    TransportPreference preference = TransportPreference.graphql,
    ProbeReport? probe,
    Completer<void>? openGate,
    bool withActivity = false,
    Map<String, String> targets = const {'user_1': p.fakeUser},
    FakeTime? sharedTime,
    FakeGovernorLeaseRepo? sharedLeases,
  }) : time = sharedTime ?? FakeTime() {
    leases = sharedLeases ?? FakeGovernorLeaseRepo(time.clock);
    governor = RequestGovernor(
      leases: leases,
      clock: time.clock,
      holder: 'test',
      config: config,
      delay: time.delay,
      log: governorLogs.add,
    );
    unawaited(sessions.save(1, d.fakeSession()));
    targets.forEach(
      (id, name) => unawaited(targetRepo.insert(_target(id, name))),
    );
    http = d.FakeIgHttp(
      // No doc_id and no tokens: direct mode goes to REST (T-044); an empty
      // object is a REST answer of the wrong shape (SchemaChanged).
      responder ?? (_) => d.jsonReply({'status': 'ok'}),
    );
    driver = p.FakePageDriver(onLoad ?? (_, _) {}, openGate: openGate);
    discovery = PageDiscovery(clock: time.clock);
    if (seedDiscovery) {
      for (final q in GraphqlQuery.values) {
        discovery.record(
          friendlyName: q.friendlyName,
          docId: p.fakeDocId,
          tokens: {'fb_dtsg': d.fakeDtsg, 'lsd': d.fakeLsd},
        );
      }
    }
    cdn = FakeCdnHttp((uri, headers) {
      cdnBodies++;
      return CdnResponse(
        status: 200,
        body: bodyOf([
          [1, 2, 3],
        ]),
      );
    });
    activity = FakeActivityRepo(time.clock);
    this.webViewLease = webViewLease;
    platform = InstagramPlatform.assemble(
      accountId: 1,
      governor: governor,
      sessions: sessions,
      http: http,
      cdnHttp: cdn,
      pageDriver: driver,
      hookSource: '/* hook */',
      targets: targetRepo,
      appId: d.fakeAppId,
      log: log,
      activity: withActivity ? activity : null,
      clock: time.clock,
      transportPreference: preference,
      probe: probe,
      discovery: discovery,
      seenGuard: seenGuard ?? SeenGuard(),
      webViewLease: webViewLease ?? const NoopWebViewLease(),
      runsInBackground: runsInBackground,
      pageModeInBackground: backgroundAllowed,
      pageTimer: manualTimers,
    );
  }

  /// A second "isolate": same clock and lease table as [other], its own
  /// governor, WebView lease and fake WebView.
  factory _Rig.sharing(
    _Rig other,
    GovernorWebViewLease lease,
    p.OnLoad onLoad, [
    Completer<void>? openGate,
  ]) => _Rig(
    onLoad: onLoad,
    webViewLease: lease,
    openGate: openGate,
    sharedTime: other.time,
    sharedLeases: other.leases,
  );

  final bool runsInBackground;
  final FakeTime time;
  late final FakeGovernorLeaseRepo leases;
  late final RequestGovernor governor;
  final FakeSessionStore sessions = FakeSessionStore();
  final FakeTargetRepo targetRepo = FakeTargetRepo();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final List<String> governorLogs = [];
  late final d.FakeIgHttp http;
  late final p.FakePageDriver driver;
  late final PageDiscovery discovery;
  late final FakeCdnHttp cdn;
  late final FakeActivityRepo activity;
  late final InstagramPlatform platform;
  GovernorWebViewLease? webViewLease;
  int cdnBodies = 0;
  final List<p.ManualTimer> openTimers = [];
  final List<p.ManualTimer> timers = [];

  Timer manualTimers(Duration duration, void Function() fire) {
    final t = p.ManualTimer(duration, fire);
    if (duration == const Duration(seconds: 10)) {
      openTimers.add(t);
    } else {
      timers.add(t);
    }
    if (duration == const Duration(seconds: 2)) scheduleMicrotask(t.fire);
    return t;
  }

  Future<T> run<T>(Future<T> future) => time.drive(future);

  Future<Result<List<RemoteContent>>> posts({
    String userId = 'user_1',
    ExtractionPolicy policy = ExtractionPolicy.directThenPage,
    DateTime? watermark,
  }) => run(
    platform.fetchNewPosts(
      userId,
      watermark ?? DateTime.utc(2000),
      policy: policy,
    ),
  );

  Future<Result<Map<String, List<RemoteContent>>>> stories([
    ExtractionPolicy policy = ExtractionPolicy.directThenPage,
  ]) => run(platform.fetchStories(['user_1'], policy: policy));

  String get logs =>
      '${logText(log)}\n${governorLogs.join('\n')}\n${http.requests}';

  int get pageLoads => driver.sessions.fold(0, (n, s) => n + s.loads.length);
}

Object? _postsBody() => p.loadReal('profile', '007_graphql.json');

d.Responder _directPosts() => d.graphqlResponder(posts: _postsBody());

List<PageEvent> _pagePosts() => [
  p.hookResponse(_postsBody(), name: p.postsName),
];

void main() {
  group('AC1: the assembled platform is a ContentPlatform', () {
    test('it implements the port and answers through direct mode', () async {
      final rig = _Rig(responder: _directPosts(), seedDiscovery: true);
      final ContentPlatform platform = rig.platform;
      expect(platform.id, PlatformId.instagram);
      expect(rig.platform, isA<ContentSignals>());
      final r = await rig.posts();
      expect(r.isOk, isTrue);
      expect(rig.driver.sessions, isEmpty, reason: 'page mode not touched');
    });
  });

  group('T-039 interactive maxWait', () {
    Future<void> drain(_Rig rig) async {
      for (var i = 0; i < 6; i++) {
        await rig.run(
          rig.governor.run(
            accountId: 1,
            cost: RequestCost.api,
            call: () async => i,
          ),
        );
      }
    }

    test('an interactive resolveUser over the budget returns RateLimited '
        'at once, sends nothing and spends nothing', () async {
      final rig = _Rig(responder: _directPosts(), seedDiscovery: true);
      await drain(rig);
      final before = rig.http.requests.length;
      final r = await rig.run(
        RequestGovernor.withMaxWait(
          const Duration(seconds: 8),
          () => rig.platform.resolveUser(p.fakeUser),
        ),
      );
      expect(r.failureOrNull, isA<RateLimited>());
      expect((r.failureOrNull! as RateLimited).retryAfter, isNotNull);
      expect(rig.http.requests.length, before);
      expect(await rig.governor.remainingTokens(1), 0);
      expect(await rig.governor.isPaused(1), isFalse);
    });

    test('without the wrapper the same call waits for a token', () async {
      final rig = _Rig(responder: _directPosts(), seedDiscovery: true);
      await drain(rig);
      final before = rig.http.requests.length;
      Result<RemoteUser>? answer;
      unawaited(rig.platform.resolveUser(p.fakeUser).then((r) => answer = r));
      await rig.time.elapse(const Duration(seconds: 59));
      expect(answer, isNull, reason: 'waiting, never RateLimited');
      expect(rig.http.requests.length, before, reason: 'nothing sent yet');
      await rig.time.elapse(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(rig.http.requests.length, before + 1, reason: 'sent at refill');
    });
  });

  group('AC2 directThenPage: page mode after SchemaChanged only', () {
    test('missing doc_id: SchemaChanged in direct, then page mode answers, '
        'costing one pageLoad (3 tokens)', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()));
      final r = await rig.posts();
      expect(r.valueOrNull, isNotEmpty);
      expect(
        rig.http.requests,
        isEmpty,
        reason: 'no doc_id and no proof: no direct request at all (T-045)',
      );
      expect(rig.driver.sessions, hasLength(1));
      expect(rig.driver.sessions.single.loads.single.path, '/${p.fakeUser}/');
      expect(
        await rig.governor.remainingTokens(1),
        3,
        reason: '6 - pageLoad',
      );
      expect(
        rig.governorLogs.where((l) => l.contains('cost=pageLoad')),
        hasLength(1),
      );
      expect(rig.governorLogs.where((l) => l.contains('cost=api')), isEmpty);
      expect(
        rig.log.entries.map((e) => e.message),
        contains('PAGE_MODE_USED op=fetchNewPosts'),
      );
      expect(rig.platform.takeSignals().pageModeUses, 1);
    });

    test('directOnly: the same situation returns SchemaChanged and loads '
        'nothing', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()));
      final r = await rig.posts(policy: ExtractionPolicy.directOnly);
      expect(r.failureOrNull, isA<SchemaChanged>());
      expect((r.failureOrNull! as SchemaChanged).where, startsWith('doc_id:'));
      expect(rig.driver.sessions, isEmpty);
      expect(await rig.governor.remainingTokens(1), 6, reason: 'no request');
    });

    final directFailures = <String, IgReply>{
      'login_required (401)': d.jsonReply({
        'message': 'login_required',
        'status': 'fail',
      }, status: 401),
      'checkpoint': d.jsonReply({
        'message': 'checkpoint_required',
        'status': 'fail',
      }, status: 400),
      'feedback_required': d.jsonReply({
        'message': 'feedback_required',
        'status': 'fail',
      }, status: 400),
      '429': d.jsonReply({
        'message': 'Please wait a few minutes',
        'status': 'fail',
      }, status: 429),
    };
    for (final MapEntry(key: name, value: reply) in directFailures.entries) {
      test(
        '$name: the failure is returned and the WebView is never opened',
        () async {
          final rig = _Rig(
            responder: (_) => reply,
            seedDiscovery: true,
            onLoad: p.emitting(_pagePosts()),
          );
          final r = await rig.posts();
          final f = r.failureOrNull;
          expect(
            f,
            anyOf(
              isA<SessionInvalid>(),
              isA<AccountRestricted>(),
              isA<RateLimited>(),
            ),
          );
          expect(rig.driver.sessions, isEmpty);
          expect(rig.driver.log, isEmpty);
          expect(rig.platform.takeSignals().pageModeUses, 0);
          expect(rig.logs, isNot(contains('PAGE_MODE_USED')));
        },
      );
    }

    test('a rate limit pauses the governor, and the next call stays '
        'RateLimited without page mode', () async {
      final rig = _Rig(
        responder: (_) => d.jsonReply({
          'message': 'Please wait a few minutes',
          'status': 'fail',
        }, status: 429),
        seedDiscovery: true,
        onLoad: p.emitting(_pagePosts()),
      );
      expect((await rig.posts()).failureOrNull, isA<RateLimited>());
      expect(await rig.governor.isPaused(1), isTrue);
      expect((await rig.posts()).failureOrNull, isA<RateLimited>());
      expect(rig.driver.sessions, isEmpty);
    });

    test('Retry-After is capped at the governor maximum (N4)', () async {
      final rig = _Rig(
        responder: (_) => d.jsonReply(
          {'status': 'fail'},
          status: 429,
          retryAfter: const Duration(days: 400),
        ),
        seedDiscovery: true,
      );
      final f = (await rig.posts()).failureOrNull! as RateLimited;
      expect(f.retryAfter, const Duration(hours: 24));
      final short = _Rig(
        config: const GovernorConfig(
          jitterMin: Duration.zero,
          jitterMax: Duration.zero,
          maxPause: Duration(hours: 1),
        ),
        responder: (_) => d.jsonReply(
          {'status': 'fail'},
          status: 429,
          retryAfter: const Duration(hours: 5),
        ),
        seedDiscovery: true,
      );
      final g = (await short.posts()).failureOrNull! as RateLimited;
      expect(g.retryAfter, const Duration(hours: 1));
    });
  });

  group('T-013 follow-up: shared PageDiscovery and the GraphQL default', () {
    test('a page load teaches the GraphQL transport the doc_id and the '
        'tokens; the next call is direct and uses them', () async {
      final graphql = _directPosts();
      final rig = _Rig(
        responder: (r) => r.uri.path == '/api/graphql'
            ? graphql(r)
            : d.jsonReply({'status': 'ok'}),
        onLoad: p.emitting(_pagePosts()),
      );
      expect((await rig.posts()).isOk, isTrue);
      expect(rig.http.requests, isEmpty, reason: 'nothing before the load');
      expect(await rig.discovery.docIdFor(GraphqlQuery.posts), p.fakeDocId);

      final again = await rig.posts();
      expect(again.isOk, isTrue);
      expect(rig.driver.sessions, hasLength(1), reason: 'no second page load');
      final request = rig.http.requests.last;
      expect(rig.http.requests, hasLength(1));
      expect(request.uri.path, '/api/graphql');
      expect(request.form!['doc_id'], p.fakeDocId);
      expect(request.form!['fb_dtsg'], d.fakeDtsg);
      expect(request.form!['lsd'], d.fakeLsd);
    });

    test('the default transport is GraphQL (a POST to /api/graphql)', () async {
      final rig = _Rig(responder: _directPosts(), seedDiscovery: true);
      await rig.posts();
      expect(rig.http.requests.single.method, IgMethod.post);
      expect(rig.http.requests.single.uri.path, '/api/graphql');
    });

    test('a proven probe alone does not switch to REST', () async {
      final rig = _Rig(
        responder: _directPosts(),
        seedDiscovery: true,
        probe: _provenProbe(),
      );
      await rig.posts();
      expect(rig.http.requests.single.uri.path, '/api/graphql');
    });

    test('restWhenProven plus a proven probe uses REST', () async {
      final rig = _Rig(
        responder: (_) => d.jsonReply(d.loadSynthetic('rest_feed_user.json')),
        preference: TransportPreference.restWhenProven,
        probe: _provenProbe(),
        targets: const {'ZZFAKE_user_a': 'zz'},
      );
      final r = await rig.posts(userId: 'ZZFAKE_user_a');
      expect(r.isOk, isTrue);
      expect(rig.http.requests.single.method, IgMethod.get);
      expect(rig.http.requests.single.uri.path, contains('/api/v1/feed/user/'));
    });

    test(
      'restWhenProven without a proven probe falls back to GraphQL',
      () async {
        final rig = _Rig(
          responder: _directPosts(),
          seedDiscovery: true,
          preference: TransportPreference.restWhenProven,
        );
        await rig.posts();
        expect(rig.http.requests.single.uri.path, '/api/graphql');
      },
    );
  });

  group('AC1 background gate', () {
    test('background and the setting is off: page mode is refused, the '
        'direct SchemaChanged is returned, nothing is loaded', () async {
      final rig = _Rig(
        runsInBackground: true,
        backgroundAllowed: () => false,
        onLoad: p.emitting(_pagePosts()),
      );
      final r = await rig.posts();
      expect(r.failureOrNull, isA<SchemaChanged>());
      expect(rig.driver.log, isEmpty);
      expect(rig.http.requests, isEmpty, reason: 'zero requests (T-045)');
      expect(await rig.governor.remainingTokens(1), 6, reason: 'no request');
      expect(rig.platform.takeSignals().pageModeUses, 0);
      expect(rig.logs, isNot(contains('PAGE_MODE_USED')));
    });

    test('background and the setting is on: page mode runs', () async {
      final rig = _Rig(
        runsInBackground: true,
        backgroundAllowed: () => true,
        onLoad: p.emitting(_pagePosts()),
      );
      expect((await rig.posts()).isOk, isTrue);
      expect(rig.platform.takeSignals().pageModeUses, 1);
    });

    test('foreground ignores the setting', () async {
      final rig = _Rig(
        backgroundAllowed: () => false,
        onLoad: p.emitting(_pagePosts()),
      );
      expect((await rig.posts()).isOk, isTrue);
    });
  });

  group('AC1 WebView lease (cross-isolate, R2-F2, R2-F3)', () {
    GovernorWebViewLease leaseFor(_Rig rig, String instance) =>
        GovernorWebViewLease(
          repo: rig.leases,
          clock: rig.time.clock,
          instanceId: instance,
          ticker: (_, _) => _Idle(),
        );

    Future<bool> leaseHeld(_Rig rig) async {
      final row = await rig.leases.read(GovernorWebViewLease.reservedAccountId);
      return row != null && row.isHeldAt(rig.time.clock.now());
    }

    test('the login WebView (another isolate) holds it: page mode returns '
        'NetworkFailure, loads nothing, spends no token', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()));
      final login = leaseFor(rig, 'ui-isolate');
      expect(await login.tryAcquire('login'), isTrue);
      final background = leaseFor(rig, 'bg-isolate');
      final rig2 = _Rig.sharing(rig, background, p.emitting(_pagePosts()));
      final r = await rig2.posts();
      expect(r.failureOrNull, const NetworkFailure());
      expect(rig2.driver.log, isEmpty);
      expect(rig2.platform.takeSignals().pageModeUses, 0);
      expect(
        logText(rig2.log),
        contains('page_mode_skipped reason=webview_busy'),
      );
      await login.release('login');
      expect((await rig2.posts()).isOk, isTrue);
    });

    test('a run takes the lease and gives it back, hold included', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()));
      final lease = leaseFor(rig, 'bg');
      final rig2 = _Rig.sharing(rig, lease, p.emitting(_pagePosts()));
      expect((await rig2.posts()).isOk, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(await leaseHeld(rig2), isFalse);
      expect(lease.isHeld, isFalse);
      expect(rig2.driver.sessions.single.disposed, isTrue);
    });

    test('R2-F2: an open that finishes after page_open_timeout keeps the '
        'lease until the late session is closed', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()));
      final lease = leaseFor(rig, 'bg');
      final gate = Completer<void>();
      final rig2 = _Rig.sharing(rig, lease, p.emitting(_pagePosts()), gate);
      final running = rig2.platform.fetchNewPosts(
        'user_1',
        DateTime.utc(2000),
        policy: ExtractionPolicy.directThenPage,
      );
      for (var i = 0; i < 100 && rig2.openTimers.isEmpty; i++) {
        await rig2.time.elapse(Duration.zero);
      }
      expect(rig2.openTimers, hasLength(1));
      rig2.openTimers.single.fire(); // the 10 s open timeout
      final r = await rig2.run(running);
      expect(r.failureOrNull, const UnknownFailure(null, 'page_open_timeout'));
      expect(await leaseHeld(rig2), isTrue, reason: 'hold: open still pending');
      expect(
        await leaseFor(rig2, 'login-isolate').tryAcquire('login'),
        isFalse,
      );
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Nobody listened to the late session; the fake closes its controller
      // only once something does.
      rig2.driver.sessions.single.events.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(rig2.driver.sessions.single.cleared, isTrue);
      expect(rig2.driver.sessions.single.disposed, isTrue);
      expect(await leaseHeld(rig2), isFalse);
      expect(await leaseFor(rig2, 'login-isolate').tryAcquire('login'), isTrue);
    });
  });

  group('R2-F5 the seen breaker through the platform', () {
    test('a persisted trip refuses page-mode stories: direct SchemaChanged, '
        'no WebView', () async {
      final store = CountingSeenStore(value: true);
      final rig = _Rig(
        seenGuard: SeenGuard(store: store),
        onLoad: p.emitting([
          p.hookResponse(
            p.loadReal('story', '003_graphql.json'),
            name: p.storiesName,
          ),
        ]),
      );
      final r = await rig.stories();
      expect(r.failureOrNull, isA<SchemaChanged>());
      expect(rig.driver.sessions, isEmpty);
      expect(store.reads, greaterThanOrEqualTo(1));
      expect(logText(rig.log), contains('seen_guard_tripped'));
    });

    test('a leak trips the breaker and writes the store before the call '
        'returns; the next process refuses', () async {
      final store = CountingSeenStore();
      final rig = _Rig(
        seenGuard: SeenGuard(store: store),
        onLoad: p.emitting([
          p.hookResponse(<String, Object?>{
            'data': <String, Object?>{},
          }, name: p.seenName),
        ]),
      );
      final r = await rig.stories();
      expect(r.failureOrNull, const UnknownFailure(null, 'seen_block_leak'));
      expect(store.value, isTrue, reason: 'persisted');
      final next = _Rig(
        seenGuard: SeenGuard(store: store),
        onLoad: p.emitting(const []),
      );
      expect((await next.stories()).failureOrNull, isA<SchemaChanged>());
      expect(next.driver.sessions, isEmpty);
    });

    test('a healthy store: the story page loads once per user', () async {
      final store = CountingSeenStore();
      final rig = _Rig(
        seenGuard: SeenGuard(store: store),
        onLoad: (s, url) {
          final reel = p.loadReal('story', '003_graphql.json');
          s.emit(p.hookResponse(reel, name: p.storiesName));
        },
      );
      final r = await rig.stories();
      expect(r.isOk, isTrue);
      expect(store.reads, 1);
      expect(rig.pageLoads, 1);
    });
  });

  group('N3 skipped malformed edges reach the caller', () {
    Map<String, Object?> postsBody(List<Map<String, Object?>> nodes) => {
      'data': {
        'xdt_api__v1__feed__user_timeline_graphql_connection': {
          'edges': [
            for (final n in nodes) {'node': n},
          ],
        },
      },
    };
    Map<String, Object?> ok(String pk, int t) => {
      'pk': pk,
      'code': 'ZZFAKE',
      'taken_at': t,
      'media_type': 1,
      'user': {'pk': 'ZZ_owner'},
      'image_versions2': {
        'candidates': [
          {'url': 'u', 'width': 1, 'height': 1},
        ],
      },
    };

    test('fetchNewPosts and latestPostTime count them; take resets', () async {
      final rig = _Rig(
        responder: d.graphqlResponder(
          posts: postsBody([
            ok('a', 300),
            ok('b', 10)..['taken_at'] = 'ZZFAKE_text',
            {'ZZFAKE': 'not a post'},
          ]),
        ),
        seedDiscovery: true,
        targets: const {'ZZ_owner': 'zz'},
      );
      expect(rig.platform.takeSignals().skippedMalformed, 0);
      final r = await rig.posts(
        userId: 'ZZ_owner',
        watermark: DateTime.utc(1970),
      );
      expect(r.valueOrNull!.map((c) => c.remoteId), ['a']);
      expect(rig.platform.takeSignals().skippedMalformed, 2);
      expect(rig.platform.takeSignals().skippedMalformed, 0, reason: 'reset');
      await rig.run(rig.platform.latestPostTime('ZZ_owner'));
      expect(rig.platform.takeSignals().skippedMalformed, 2);
    });

    test('a clean timeline reports 0, a failed call reports nothing', () async {
      final clean = _Rig(responder: _directPosts(), seedDiscovery: true);
      await clean.posts();
      expect(clean.platform.takeSignals().skippedMalformed, 0);
      final failing = _Rig(
        responder: (_) =>
            d.jsonReply({'message': 'login_required'}, status: 401),
        seedDiscovery: true,
      );
      await failing.posts();
      expect(failing.platform.takeSignals().skippedMalformed, 0);
    });
  });

  group('persistent UsernameCache (T-014 QA-F12)', () {
    test('a restarted process knows the username of a stored target: posts '
        'cost 1 governed call, not 2', () async {
      final rig = _Rig(responder: _directPosts(), seedDiscovery: true);
      final r = await rig.posts();
      expect(r.isOk, isTrue);
      expect(rig.http.requests, hasLength(1));
      expect(d.variablesOf(rig.http.requests.single)['username'], p.fakeUser);
      expect(await rig.governor.remainingTokens(1), 5);
    });

    test('page mode finds the username of a stored target without a '
        'lookup', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()));
      await rig.posts();
      expect(rig.driver.sessions.single.loads.single.path, '/${p.fakeUser}/');
    });
  });

  group('AC4 PAGE_MODE_USED with an ActivityRepo', () {
    test('one event, no values', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()), withActivity: true);
      await rig.posts();
      final events = await rig.activity.watchRecent().first;
      expect(events.single.type, ActivityType.pageModeUsed);
      expect(events.single.payload, {'op': 'fetchNewPosts'});
      expect(jsonEncode(events.single.payload), isNot(contains(p.fakeUser)));
    });
  });

  group('AC4 governor discipline', () {
    test(
      'one governed call per operation, none nested, none left running',
      () async {
        final rig = _Rig(responder: _directPosts(), seedDiscovery: true);
        await rig.posts();
        await rig.posts();
        await rig.run(rig.platform.latestPostTime('user_1'));
        expect(rig.http.requests, hasLength(3));
        expect(rig.http.maxInFlight, 1);
        expect(
          rig.governorLogs.where((l) => l.contains('cost=api')),
          hasLength(3),
        );
        expect(
          rig.governorLogs.where((l) => l.contains('outcome=error')),
          isEmpty,
        );
        expect(logText(rig.log), isNot(contains('unexpected_error')));
        await rig.time.pump();
        expect(rig.time.pendingTimers, 0, reason: 'nothing left unawaited');
      },
    );

    test('a page-mode fallback is exactly one pageLoad after the direct '
        'run has returned (no nesting)', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()));
      await rig.posts();
      await rig.time.pump();
      expect(
        rig.governorLogs.where((l) => l.contains('cost=pageLoad')),
        hasLength(1),
      );
      expect(rig.driver.maxActive, 1);
      expect(logText(rig.log), isNot(contains('unexpected_error')));
    });

    test('stories in page mode cost 3 tokens per user', () async {
      final rig = _Rig(
        onLoad: (s, url) => s.emit(
          p.hookResponse(
            p.loadReal('story', '003_graphql.json'),
            name: p.storiesName,
          ),
        ),
      );
      await rig.stories();
      expect(await rig.governor.remainingTokens(1), 3, reason: 'page only');
    });
  });

  group('AC3 openMedia is not governed (ADR-0009) and sends no cookies', () {
    test('a download touches neither the governor nor the Instagram client '
        'nor the session', () async {
      final rig = _Rig(responder: _directPosts(), seedDiscovery: true);
      final bytes = [
        for (final c in await rig.platform.openMedia(secretUrl).toList()) ...c,
      ];
      final resumed = [
        for (final c
            in await rig.platform.openMedia(secretUrl, fromByte: 2).toList())
          ...c,
      ];
      expect(bytes, [1, 2, 3]);
      expect(resumed, [3], reason: 'the fake ignores Range: 200 skips 2');
      expect(rig.http.requests, isEmpty);
      expect(rig.governorLogs, isEmpty);
      expect(
        await rig.leases.read(1),
        isNull,
        reason: 'governor lease untouched',
      );
      expect(await rig.governor.remainingTokens(1), 6);
      expect(rig.cdn.uris, hasLength(2));
      for (final h in rig.cdn.headers) {
        expect(
          h.keys.map((k) => k.toLowerCase()),
          everyElement(isIn(['range'])),
        );
        expect(h.values.join(), isNot(contains(d.fakeSessionId)));
      }
    });

    test('works while the account is paused by a rate limit', () async {
      final rig = _Rig(
        responder: (_) => d.jsonReply({'status': 'fail'}, status: 429),
        seedDiscovery: true,
      );
      await rig.posts();
      expect(await rig.governor.isPaused(1), isTrue);
      final bytes = [
        for (final c in await rig.platform.openMedia(secretUrl).toList()) ...c,
      ];
      expect(bytes, [1, 2, 3]);
    });

    test(
      'expiry is signalled on the stream for the caller to refresh',
      () async {
        final rig = _Rig();
        final platform = InstagramPlatform.assemble(
          accountId: 1,
          governor: rig.governor,
          sessions: rig.sessions,
          http: rig.http,
          cdnHttp: FakeCdnHttp(
            (_, _) => CdnResponse(status: 403, body: bodyOf(const [])),
          ),
          pageDriver: rig.driver,
          hookSource: '',
          targets: rig.targetRepo,
          seenGuard: SeenGuard(),
        );
        await expectLater(
          platform.openMedia(secretUrl),
          emitsError(isA<ExpiredMediaUrl>()),
        );
      },
    );

    test('nothing in any log holds the URL or a cookie', () async {
      final rig = _Rig(onLoad: p.emitting(_pagePosts()));
      await rig.platform.openMedia(secretUrl).drain<void>();
      await rig.platform
          .openMedia('https://evil.test/ZZFAKE')
          .drain<void>()
          .catchError((_) {});
      await rig.posts();
      expect(rig.logs, isNot(contains('ZZFAKE')));
      expect(rig.logs, isNot(contains(d.fakeSessionId)));
      expect(rig.logs, isNot(contains(d.fakeCsrf)));
    });
  });
}

ProbeReport _provenProbe() => ProbeReport(
  entries: [
    for (final id in ProbeEntry.expectedKeys.keys)
      ProbeEntry(
        id: id,
        label: 'x',
        outcome: 'ok',
        status: 200,
        topLevelKeys: ProbeEntry.expectedKeys[id]!,
      ),
  ],
);

final class _Idle implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}
