// Shared helpers for the direct-mode tests: fixture loading, a scripted HTTP
// fake and a rig that wires the real governor on fake time.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

import '../governor/fake_time.dart';

/// Fake secrets: none of these may ever reach a log or a report.
const fakeSessionId = 'ZZFAKE_sessionid_value';
const fakeCsrf = 'ZZFAKE_csrf_value';
const fakeAgent = 'ZZFAKE-Agent/1.0 (test)';
const fakeDtsg = 'ZZFAKE_dtsg_value';
const fakeLsd = 'ZZFAKE_lsd_value';
const fakeAppId = '123456';

/// The user id of the logged-in fake account. It matches the viewer id in the
/// real capture fixtures (`user_3` in the profile response).
const viewerId = 'user_3';

Object? loadReal(String capture, String body) => jsonDecode(
  File('test/fixtures/real/$capture/bodies/$body').readAsStringSync(),
);

Object? loadSynthetic(String name) =>
    jsonDecode(File('test/fixtures/synthetic/$name').readAsStringSync());

Node nodeOf(Object? json) => Node.root(json, 'response');

/// A JSON reply.
IgReply jsonReply(
  Object? json, {
  int status = 200,
  Duration? retryAfter,
  String? redirectPath,
}) => IgReply(
  status: status,
  json: json,
  retryAfter: retryAfter,
  redirectPath: redirectPath,
);

SessionBlob fakeSession({String userId = viewerId}) => SessionBlob(
  cookies: {
    'sessionid': fakeSessionId,
    'ds_user_id': userId,
    'csrftoken': fakeCsrf,
  },
  userAgent: fakeAgent,
  capturedAt: DateTime.utc(2026),
);

typedef Responder = FutureOr<IgReply> Function(IgRequest request);

/// Records every request and answers from [responder]. Tracks how many
/// requests were in flight at once (the governor must keep it at 1).
final class FakeIgHttp implements IgHttp {
  FakeIgHttp(this.responder);

  Responder responder;
  final List<IgRequest> requests = [];
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<IgReply> send(IgRequest request) async {
    requests.add(request);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await Future<void>.delayed(Duration.zero);
      return await responder(request);
    } finally {
      inFlight--;
    }
  }
}

/// The GraphQL friendly name of a request, or null for a non-GraphQL one.
String? friendlyName(IgRequest r) => r.form?['fb_api_req_friendly_name'];

Map<String, Object?> variablesOf(IgRequest r) =>
    jsonDecode(r.form!['variables']!) as Map<String, Object?>;

/// Answers each GraphQL query from the given bodies.
Responder graphqlResponder({
  Object? stories,
  Object? profile,
  Object? posts,
  Map<String, IgReply> overrides = const {},
}) {
  return (r) {
    final name = friendlyName(r);
    if (name != null && overrides.containsKey(name)) return overrides[name]!;
    return switch (name) {
      'PolarisStoriesV3ReelPageStandaloneQuery' => jsonReply(stories),
      'PolarisProfilePageContentQuery' => jsonReply(profile),
      'PolarisProfilePostsQuery' => jsonReply(posts),
      _ => jsonReply({'status': 'fail'}, status: 500),
    };
  };
}

final class FakeDocIds implements DocIdResolver {
  FakeDocIds({this.missing = const {}});

  final Set<GraphqlQuery> missing;

  @override
  Future<String?> docIdFor(GraphqlQuery query) async =>
      missing.contains(query) ? null : 'ZZFAKE_doc_${query.name}';
}

final class FakeTokens implements PageTokenProvider {
  FakeTokens({this.available = true});

  final bool available;

  @override
  Future<Map<String, String>?> tokens() async =>
      available ? {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd} : null;
}

const noJitter = GovernorConfig(
  jitterMin: Duration.zero,
  jitterMax: Duration.zero,
);

/// A real governor on fake time, a fake session store, and a log.
final class Rig {
  Rig({
    Responder? responder,
    IgTransport? transport,
    bool withSession = true,
    String sessionUserId = viewerId,
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
    http = FakeIgHttp(
      responder ?? (_) => throw StateError('no responder set for this test'),
    );
    if (withSession) {
      unawaited(sessions.save(1, fakeSession(userId: sessionUserId)));
    }
    extractor = DirectExtractor(
      accountId: 1,
      governor: governor,
      sessions: sessions,
      http: http,
      transport:
          transport ??
          GraphqlTransport(docIds: FakeDocIds(), tokens: FakeTokens()),
      log: log,
      appId: fakeAppId,
    );
  }

  final FakeTime time = FakeTime();
  late final FakeGovernorLeaseRepo leases;
  late final RequestGovernor governor;
  final FakeSessionStore sessions = FakeSessionStore();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final List<String> governorLogs = [];
  late final FakeIgHttp http;
  late final DirectExtractor extractor;

  /// Runs [future] to completion on fake time.
  Future<T> run<T>(Future<T> future) => time.drive(future);

  /// Every line logged by the extractor and the governor, as one string.
  String get allLogs =>
      '${log.entries.map((e) => '$e ${e.error ?? ''}').join('\n')}\n'
      '${governorLogs.join('\n')}';
}
