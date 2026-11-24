// T-013 follow-ups N1 (header-safe session) and N4 (Retry-After clamp), and
// N3 (skipped malformed edges reach the caller).
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

SessionBlob _blob({
  String sessionId = fakeSessionId,
  String agent = fakeAgent,
  Map<String, String> extra = const {},
}) => SessionBlob(
  cookies: {
    'sessionid': sessionId,
    'ds_user_id': viewerId,
    'csrftoken': fakeCsrf,
    ...extra,
  },
  userAgent: agent,
  capturedAt: DateTime.utc(2026),
);

Future<IgSession?> _load(SessionBlob blob, {String? appId}) async {
  final store = FakeSessionStore();
  await store.save(1, blob);
  return IgSession.load(store, 1, appId: appId);
}

void main() {
  group('N1 IgSession.load refuses what a header cannot carry', () {
    final bad = <String, String>{
      'NUL': 'abc\u0000def',
      'DEL': 'abc\u007fdef',
      'control 0x01': 'abc\u0001def',
      'escape 0x1b': 'abc\u001bdef',
      'CR': 'abc\rdef',
      'LF': 'abc\ndef',
      'non-ASCII latin': 'café',
      'non-ASCII CJK': '中文',
      'emoji': 'a\u{1F600}b',
      'zero-width space': 'a​b',
      'right-to-left mark': 'a‏b',
      'next line 0x85': 'a\u0085b',
    };
    for (final MapEntry(key: name, :value) in bad.entries) {
      test('cookie value with $name gives no session', () async {
        expect(await _load(_blob(extra: {'ig_did': value})), isNull);
        expect(await _load(_blob(sessionId: value)), isNull);
      });
    }

    test(
      'the same characters in a cookie name, the user agent or the app id',
      () async {
        for (final v in bad.values) {
          expect(await _load(_blob(extra: {v: 'x'})), isNull);
          expect(await _load(_blob(agent: v)), isNull);
          expect(await _load(_blob(), appId: v), isNull);
        }
      },
    );

    test('printable ASCII, space and TAB are accepted', () async {
      final value = [for (var c = 0x20; c <= 0x7e; c++) String.fromCharCode(c)]
          .join();
      final session = await _load(
        _blob(extra: {'ig_did': value, 'x': 'a\tb'}),
        appId: '936619743392459',
      );
      expect(session, isNotNull);
      expect(session!.headers()['Cookie'], contains('ig_did=$value'));
    });

    test('an empty app id and a plain session are accepted', () async {
      expect(await _load(_blob()), isNotNull);
      expect(await _load(_blob(), appId: ''), isNotNull);
    });

    test('through the extractor: SessionInvalid, nothing sent, no token '
        'spent, nothing logged, no echo', () async {
      final rig = Rig(responder: graphqlResponder(), withSession: false);
      await rig.sessions.save(1, _blob(extra: {'ig_did': 'ZZFAKE_é_value'}));
      final r = await rig.run(
        rig.extractor.fetchNewPosts('user_1', DateTime(2000)),
      );
      expect(
        r.failureOrNull,
        const SessionInvalid(SessionReason.loginRequired),
      );
      expect(rig.http.requests, isEmpty);
      expect(await rig.governor.remainingTokens(1), 6);
      expect('${r.failureOrNull}${rig.allLogs}', isNot(contains('ZZFAKE')));
      expect(rig.allLogs, isNot(contains('é')));
    });

    test('toString of the session shows cookie names only', () async {
      final s = (await _load(_blob()))!;
      expect(s.toString(), isNot(contains(fakeSessionId)));
    });
  });

  group('N4 Retry-After is clamped before it becomes a Duration', () {
    test('the wrap that motivated it', () {
      // Dart wraps this to under a minute: the clamp must come first.
      expect(
        const Duration(seconds: 18446744073769).inSeconds,
        isNot(18446744073769),
      );
    });

    test('clampedRetryAfter', () {
      expect(clampedRetryAfter(0), Duration.zero);
      expect(clampedRetryAfter(30), const Duration(seconds: 30));
      expect(clampedRetryAfter(86399), const Duration(seconds: 86399));
      expect(clampedRetryAfter(86400), const Duration(hours: 24));
      expect(clampedRetryAfter(86401), const Duration(hours: 24));
      expect(clampedRetryAfter(10000000), const Duration(hours: 24));
      expect(clampedRetryAfter(18446744073769), const Duration(hours: 24));
      expect(clampedRetryAfter(9223372036854775807), const Duration(hours: 24));
      expect(clampedRetryAfter(-1), isNull);
      expect(clampedRetryAfter(-9223372036854775808), isNull);
    });

    test('clampedRetryAfter follows a custom governor maximum', () {
      expect(
        clampedRetryAfter(7200, max: const Duration(hours: 1)),
        const Duration(hours: 1),
      );
      expect(
        clampedRetryAfter(60, max: const Duration(hours: 1)),
        const Duration(minutes: 1),
      );
    });

    RateLimited? limited(FailureClassifier c, Duration? hint) =>
        c.classify(IgReply(status: 429, retryAfter: hint)) as RateLimited?;

    test('the classifier caps a RateLimited hint at its maximum', () {
      const c = FailureClassifier();
      expect(
        limited(c, const Duration(days: 400))!.retryAfter,
        const Duration(hours: 24),
      );
      expect(
        limited(c, const Duration(minutes: 5))!.retryAfter,
        const Duration(minutes: 5),
      );
      expect(limited(c, null)!.retryAfter, isNull);
      expect(limited(c, const Duration(seconds: -5))!.retryAfter, isNull);
      const short = FailureClassifier(maxRetryAfter: Duration(hours: 1));
      expect(
        limited(short, const Duration(hours: 5))!.retryAfter,
        const Duration(hours: 1),
      );
    });

    test('a "please wait" body is capped the same way', () {
      const c = FailureClassifier();
      final f = c.classify(
        const IgReply(
          status: 200,
          json: {'status': 'fail', 'message': 'Please wait a few minutes'},
          retryAfter: Duration(days: 999),
        ),
      );
      expect(f, const RateLimited(Duration(hours: 24)));
    });
  });
}
