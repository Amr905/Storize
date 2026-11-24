// QA (T-013): attacks on the live probe. Tests marked `skip:` document a
// finding and assert the behaviour wanted after a fix.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';
import '../governor/fake_time.dart';

final class _Rig {
  _Rig(Responder responder) {
    final repo = FakeGovernorLeaseRepo(time.clock);
    governor = RequestGovernor(
      leases: repo,
      clock: time.clock,
      holder: 'probe',
      config: noJitter,
      delay: time.delay,
    );
    http = FakeIgHttp(responder);
    unawaited(sessions.save(1, fakeSession()));
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
  late final FakeIgHttp http;
  late final IgProbe probe;
  Future<T> run<T>(Future<T> f) => time.drive(f);
}

RemoteMedia _media(String url) =>
    RemoteMedia(index: 0, type: MediaType.photo, url: url, width: 1, height: 1);

void main() {
  test('one run is exactly 5 governed calls; a 6th needs another run() '
      '(no internal loop, no retry)', () async {
    final rig = _Rig((_) => const IgReply(status: 500));
    final report = await rig.run(rig.probe.run(username: 'u', userId: '1'));
    expect(rig.http.requests, hasLength(5));
    expect(report.entries, hasLength(5));
    expect(rig.http.maxInFlight, 1);
    expect(await rig.governor.remainingTokens(1), lessThan(1.01));
  });

  test(
    'NOTE: calling run() twice sends 10 calls (only the governor limits)',
    () async {
      final rig = _Rig((_) => jsonReply(<String, Object?>{}));
      await rig.run(rig.probe.run(username: 'u', userId: '1'));
      await rig.run(rig.probe.run(username: 'u', userId: '1'));
      expect(rig.http.requests, hasLength(10));
    },
  );

  test('a 429 stops the probe and pauses the account (4 skipped)', () async {
    final rig = _Rig(
      (_) => jsonReply(
        {'message': 'Please wait'},
        status: 429,
        retryAfter: const Duration(minutes: 20),
      ),
    );
    final report = await rig.run(rig.probe.run(username: 'u', userId: '1'));
    expect(rig.http.requests, hasLength(1));
    expect(report.entries.map((e) => e.outcome), [
      'rate_limited',
      'skipped',
      'skipped',
      'skipped',
      'skipped',
    ]);
    expect(await rig.governor.isPaused(1), isTrue);
  });

  test(
    'QA-F9: after a checkpoint / login_required / feedback_required reply the '
    'probe should stop instead of sending the remaining calls',
    () async {
      final rig = _Rig(
        (_) => jsonReply({
          'message': 'checkpoint_required',
          'status': 'fail',
        }, status: 400),
      );
      await rig.run(rig.probe.run(username: 'u', userId: '1'));
      expect(rig.http.requests, hasLength(1));
    },
  );

  test('QA-F9: a 401, a login redirect or a 200 login_required body also stops '
      'the probe; the rest is skipped', () async {
    for (final reply in [
      const IgReply(status: 401),
      const IgReply(status: 302, redirectPath: '/accounts/login/'),
      const IgReply(status: 302, redirectPath: '/challenge/'),
      jsonReply({'message': 'login_required', 'status': 'fail'}),
      jsonReply({
        'message': 'feedback_required',
        'status': 'fail',
      }, status: 400),
    ]) {
      final rig = _Rig((_) => reply);
      final report = await rig.run(rig.probe.run(username: 'u', userId: '1'));
      expect(rig.http.requests, hasLength(1), reason: '$reply');
      expect(
        report.entries.skip(1).map((e) => e.outcome),
        everyElement('skipped'),
      );
      expect(report.entries.first.status, reply.status);
      expect(report.entries.first.proven, isFalse);
    }
  });

  test('a 200 "please wait" body (not 429) is fed to the governor and stops '
      'the probe', () async {
    final rig = _Rig(
      (_) => jsonReply({'status': 'fail', 'message': 'Please wait a few min'}),
    );
    await rig.run(rig.probe.run(username: 'u', userId: '1'));
    expect(rig.http.requests, hasLength(1));
    expect(await rig.governor.isPaused(1), isTrue);
  });

  group('CDN check', () {
    test(
      'sends no cookie or session header, only Range, and logs no URL',
      () async {
        final rig = _Rig(
          (_) => const IgReply(status: 206, contentType: 'image/jpeg'),
        );
        final out = await rig.probe.checkCdn({
          'story_image': _media(
            'https://scontent.cdninstagram.com/a.jpg?sig=ZZURLSECRET&oh=ZZ2',
          ),
        });
        expect(out.single.outcome, 'ok');
        final r = rig.http.requests.single;
        expect(r.headers.keys, ['Range']);
        expect(
          '${out.single.render()} ${out.single.toJson()} '
          '${rig.log.entries.join()}',
          isNot(contains('ZZURLSECRET')),
        );
        expect(await rig.governor.remainingTokens(1), 6, reason: 'ungoverned');
      },
    );

    test(
      'QA-F10: only https CDN hosts may be requested by the ungoverned check',
      () async {
        final rig = _Rig((_) => const IgReply(status: 200));
        await rig.probe.checkCdn({
          'a': _media('https://www.instagram.com/api/v1/feed/reels_media/'),
          'b': _media('http://scontent.cdninstagram.com/a.jpg'),
        });
        expect(rig.http.requests, isEmpty);
      },
    );

    test('a malformed URL string is a rejected entry, not a throw', () async {
      final rig = _Rig((_) => const IgReply(status: 200));
      final out = await rig.probe.checkCdn({'a': _media('http://[::1')});
      expect(out.single.outcome, 'rejected');
      expect(rig.http.requests, isEmpty);
    });

    test('403 and a socket error are recorded, the loop goes on', () async {
      var n = 0;
      final rig = _Rig((_) {
        n++;
        if (n == 1) throw const TransportException('socket');
        return const IgReply(status: 403);
      });
      final out = await rig.probe.checkCdn({
        'a': _media('https://scontent.cdninstagram.com/1'),
        'b': _media('https://scontent.cdninstagram.com/2'),
      });
      expect(out.map((e) => e.outcome), ['network', 'http_error']);
    });
  });

  test('the report never holds a body value even for hostile top-level keys '
      'with odd characters', () async {
    final rig = _Rig(
      (_) => jsonReply({
        'odd key; with=chars': 1,
        'data': {'x': 'ZZFAKE_value'},
      }),
    );
    final report = await rig.run(rig.probe.run(username: 'u', userId: '1'));
    final text =
        '${report.render()}${report.toJson()}${rig.log.entries.join()}';
    expect(text, isNot(contains('ZZFAKE')));
    expect(text, isNot(contains(';')), reason: 'keys are sanitised');
    expect(text, isNot(contains('with=chars')));
  });
}
