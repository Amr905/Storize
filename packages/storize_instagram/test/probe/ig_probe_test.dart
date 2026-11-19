// AC7 step 0: the dev-only live probe, driven by a fake transport.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';
import '../governor/fake_time.dart';

const _user = 'ZZFAKE_probe_user';
const _id = 'ZZFAKE_probe_id';
const _secretValue = 'ZZFAKE_body_value_must_not_leak';

IgReply _good(IgRequest r) => switch (r.uri.path) {
  '/api/v1/users/web_profile_info/' => jsonReply({
    'data': {'x': _secretValue},
    'status': 'ok',
  }),
  '/api/v1/feed/reels_media/' => jsonReply({
    'reels': {_id: _secretValue},
    'status': 'ok',
  }),
  '/api/v1/users/$_id/info/' => jsonReply({
    'user': {'pk': _secretValue},
    'status': 'ok',
  }),
  '/api/v1/accounts/current_user/' => jsonReply({
    'user': <String, Object?>{},
    'status': 'ok',
    'weird key/with space': 1,
  }),
  '/api/v1/feed/user/$_id/' => jsonReply({
    'items': <Object?>[],
    'num_results': 0,
  }),
  _ => const IgReply(status: 404),
};

final class _Rig {
  _Rig({Responder? responder, bool withSession = true}) {
    final repo = FakeGovernorLeaseRepo(time.clock);
    governor = RequestGovernor(
      leases: repo,
      clock: time.clock,
      holder: 'probe',
      config: noJitter,
      delay: time.delay,
      log: governorLogs.add,
    );
    http = FakeIgHttp(responder ?? _good);
    if (withSession) unawaited(sessions.save(1, fakeSession()));
    probe = IgProbe(
      accountId: 1,
      governor: governor,
      sessions: sessions,
      http: http,
      log: log,
      appId: fakeAppId,
    );
  }

  final FakeTime time = FakeTime();
  late final RequestGovernor governor;
  final FakeSessionStore sessions = FakeSessionStore();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final List<String> governorLogs = [];
  late final FakeIgHttp http;
  late final IgProbe probe;

  Future<T> run<T>(Future<T> f) => time.drive(f);

  String everything(ProbeReport report) =>
      '${report.render()}\n${report.toJson()}\n'
      '${log.entries.join('\n')}\n${governorLogs.join('\n')}';
}

void main() {
  group('AC7 the probe sends IG-1 to IG-5 once each, through the governor', () {
    test('five requests in order, each one api token, one at a time', () async {
      final rig = _Rig();
      final report = await rig.run(rig.probe.run(username: _user, userId: _id));
      expect(rig.http.requests.map((r) => r.uri.path), [
        '/api/v1/users/web_profile_info/',
        '/api/v1/feed/reels_media/',
        '/api/v1/users/$_id/info/',
        '/api/v1/accounts/current_user/',
        '/api/v1/feed/user/$_id/',
      ]);
      expect(rig.http.requests[2].uri.host, 'i.instagram.com');
      expect(rig.http.maxInFlight, 1);
      expect(rig.governorLogs, hasLength(5));
      expect(
        rig.governorLogs,
        everyElement(allOf(contains('cost=api'), contains('outcome=ok'))),
      );
      expect(await rig.governor.remainingTokens(1), 1);
      expect(report.entries.map((e) => e.id), [
        'IG-1',
        'IG-2',
        'IG-3',
        'IG-4',
        'IG-5',
      ]);
    });

    test('the session headers are applied', () async {
      final rig = _Rig();
      await rig.run(rig.probe.run(username: _user, userId: _id));
      for (final r in rig.http.requests) {
        expect(r.headers['Cookie'], contains(fakeSessionId));
        expect(r.headers['User-Agent'], fakeAgent);
      }
    });
  });

  group('AC7 only status and top-level key names are recorded', () {
    test('keys sorted and made safe; proven and restProven computed', () async {
      final rig = _Rig();
      final report = await rig.run(rig.probe.run(username: _user, userId: _id));
      final byId = {for (final e in report.entries) e.id: e};
      expect(byId['IG-1']!.status, 200);
      expect(byId['IG-1']!.topLevelKeys, ['data', 'status']);
      expect(byId['IG-4']!.topLevelKeys, [
        'status',
        'user',
        'weird?key?with?space',
      ]);
      expect(report.restProven, isTrue);
      expect(
        report.render(),
        contains(
          'IG-1 users/web_profile_info outcome=ok status=200 keys=[data,status] proven=true',
        ),
      );
    });

    test('no body value, cookie, token, URL or input ever appears in the '
        'report or the logs', () async {
      final rig = _Rig();
      final report = await rig.run(rig.probe.run(username: _user, userId: _id));
      final text = rig.everything(report);
      for (final secret in [
        _secretValue,
        fakeSessionId,
        fakeCsrf,
        fakeAgent,
        _user,
        _id,
        'http',
        'Cookie',
      ]) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
      expect(rig.log.entries, isNotEmpty);
    });

    test('an error status is recorded as http_error with its keys', () async {
      final rig = _Rig(
        responder: (r) => r.uri.path.contains('reels_media')
            ? jsonReply({
                'message': _secretValue,
                'status': 'fail',
              }, status: 400)
            : _good(r),
      );
      final report = await rig.run(rig.probe.run(username: _user, userId: _id));
      final e = report.entries[1];
      expect((e.outcome, e.status, e.proven), ('http_error', 400, false));
      expect(e.topLevelKeys, ['message', 'status']);
      expect(report.restProven, isFalse);
      expect(rig.everything(report), isNot(contains(_secretValue)));
    });

    test('a 200 that lacks the expected key is not proven', () async {
      final rig = _Rig(responder: (_) => jsonReply({'other': 1}));
      final report = await rig.run(rig.probe.run(username: _user, userId: _id));
      expect(report.entries.every((e) => e.status == 200 && !e.proven), isTrue);
    });

    test('a network error is recorded and the probe goes on', () async {
      final rig = _Rig(
        responder: (r) => r.uri.path.contains('current_user')
            ? throw const TransportException('socket')
            : _good(r),
      );
      final report = await rig.run(rig.probe.run(username: _user, userId: _id));
      expect(report.entries[3].outcome, 'network');
      expect(report.entries[3].status, isNull);
      expect(report.entries[4].outcome, 'ok');
    });
  });

  group('AC7 rate limit and session', () {
    test(
      'a 429 stops the probe: the rest are skipped, the account is paused',
      () async {
        final rig = _Rig(
          responder: (r) => r.uri.path.contains('reels_media')
              ? const IgReply(status: 429, retryAfter: Duration(minutes: 5))
              : _good(r),
        );
        final report = await rig.run(
          rig.probe.run(username: _user, userId: _id),
        );
        expect(report.entries.map((e) => e.outcome), [
          'ok',
          'rate_limited',
          'skipped',
          'skipped',
          'skipped',
        ]);
        expect(rig.http.requests, hasLength(2));
        expect(await rig.governor.isPaused(1), isTrue);
        final again = await rig.run(
          rig.probe.run(username: _user, userId: _id),
        );
        expect(again.entries.first.outcome, 'paused');
        expect(
          rig.http.requests,
          hasLength(2),
          reason: 'no request while paused',
        );
      },
    );

    test('no stored session: nothing is sent', () async {
      final rig = _Rig(withSession: false);
      final report = await rig.run(rig.probe.run(username: _user, userId: _id));
      expect(report.entries.every((e) => e.outcome == 'no_session'), isTrue);
      expect(rig.http.requests, isEmpty);
    });
  });

  group('AC7 plain CDN download check (T-002 AC2)', () {
    RemoteMedia media(MediaType type) => RemoteMedia(
      index: 0,
      type: type,
      url: 'https://cdn.example.test/ZZFAKE_file?sig=ZZFAKE_signature',
      width: 1,
      height: 1,
    );

    test(
      'a ranged GET without cookies; only status and content type kept',
      () async {
        final rig = _Rig(
          responder: (r) => IgReply(
            status: 206,
            contentType: r.uri.path.contains('file') ? 'image/jpeg' : null,
          ),
        );
        final cdn = await rig.run(
          rig.probe.checkCdn({
            'story_image': media(MediaType.photo),
            'story_video': media(MediaType.video),
          }),
        );
        for (final r in rig.http.requests) {
          expect(r.headers.keys.map((k) => k.toLowerCase()), ['range']);
          expect(r.headers['Range'], 'bytes=0-1023');
        }
        expect(cdn.map((c) => (c.label, c.outcome, c.status)), [
          ('story_image', 'ok', 206),
          ('story_video', 'ok', 206),
        ]);
        final report = const ProbeReport(entries: []).withCdn(cdn);
        expect(
          report.render(),
          contains('CDN story_image outcome=ok status=206 type=image/jpeg'),
        );
        final text =
            '${report.render()}${report.toJson()}${rig.log.entries.join()}';
        expect(text, isNot(contains('ZZFAKE_signature')));
        expect(text, isNot(contains('cdn.example')));
        expect(
          await rig.governor.remainingTokens(1),
          6,
          reason: 'the CDN is not governed',
        );
      },
    );

    test('403 is http_error, a socket error is network', () async {
      final rig = _Rig(responder: (_) => const IgReply(status: 403));
      var cdn = await rig.run(
        rig.probe.checkCdn({'story_image': media(MediaType.photo)}),
      );
      expect((cdn.single.outcome, cdn.single.status), ('http_error', 403));
      rig.http.responder = (_) => throw const TransportException('timeout');
      cdn = await rig.run(
        rig.probe.checkCdn({'story_video': media(MediaType.video)}),
      );
      expect(cdn.single.outcome, 'network');
    });
  });
}
