// T-049 QA: extra checks on the guard through the governor, secret hygiene
// and the SessionInvalid blast radius. Synthetic values only.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _pv = '__relay_internal__pv__PolarisZzFakeEnabled';
const _stories = 'PolarisStoriesV3ReelPageStandaloneQuery';

PageDiscovery _disc({Map<String, String> tokens = const {}}) =>
    PageDiscovery(
      clock: FakeClock(),
      accountId: 1,
    )..recordDiscovery([
      const DiscoveredOp(
        name: _stories,
        docId: '11111111111111111',
        provided: {_pv: true},
      ),
    ], tokens);

void main() {
  test('guard: incomplete tokens send no HTTP request at all', () async {
    final d = _disc(tokens: {'fb_dtsg': fakeDtsg});
    final rig = Rig(
      transport: GraphqlTransport(docIds: d, tokens: d),
      responder: (_) => throw StateError('must not be sent'),
    );
    final r = await rig.run(rig.extractor.fetchStories(['user_1']));
    expect(r.failureOrNull, const SchemaChanged('page_tokens'));
    expect(rig.http.requests, isEmpty);
  });

  test('guard: unknown providers send no HTTP request', () async {
    final d = PageDiscovery(clock: FakeClock(), accountId: 1)
      ..recordDiscovery(
        [
          const DiscoveredOp(name: _stories, docId: '11111111111111111'),
        ],
        {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
      );
    final rig = Rig(
      transport: GraphqlTransport(docIds: d, tokens: d),
      responder: (_) => throw StateError('must not be sent'),
    );
    final r = await rig.run(rig.extractor.fetchStories(['user_1']));
    expect(r.failureOrNull, const SchemaChanged('providers'));
    expect(rig.http.requests, isEmpty);
  });

  test('toString of discovery objects never carries secrets', () {
    final d = _disc(tokens: {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd});
    final all = [
      d.toString(),
      d.describe(),
      const HookDiscovery(
        tokens: {'fb_dtsg': 'SECRETDTSG', 'lsd': 'SECRETLSD'},
      ).toString(),
      const HookCapture(
        path: '/api/graphql',
        json: null,
        status: 200,
        tokens: {'fb_dtsg': 'SECRETDTSG'},
        docId: '12345678',
      ).toString(),
    ].join('\n');
    expect(all, isNot(contains(fakeDtsg)));
    expect(all, isNot(contains(fakeLsd)));
    expect(all, isNot(contains('SECRET')));
  });

  test('a stale-token reply (non-login code) is never SessionInvalid, '
      'even repeated', () async {
    for (var i = 0; i < 3; i++) {
      final d = _disc(tokens: {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd});
      final rig = Rig(
        transport: GraphqlTransport(docIds: d, tokens: d),
        responder: (_) => const IgReply(
          status: 200,
          json: <String, Object?>{'error': 1357004},
          shielded: true,
        ),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, const SchemaChanged('page_tokens'));
    }
  });

  test('1357001 repeats after a fresh discovery: still SessionInvalid, '
      'one request per call (documents current behaviour)', () async {
    final d = _disc(tokens: {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd});
    final rig = Rig(
      transport: GraphqlTransport(docIds: d, tokens: d),
      responder: (_) => const IgReply(
        status: 200,
        json: <String, Object?>{'error': 1357001},
        shielded: true,
      ),
    );
    final r = await rig.run(rig.extractor.fetchStories(['user_1']));
    expect(r.failureOrNull, isA<SessionInvalid>());
    expect(rig.http.requests.length, 1);
    // Tokens are NOT dropped on the login code: no fresh discovery is forced.
    expect(await d.tokens(), isNotNull);
  });
}
