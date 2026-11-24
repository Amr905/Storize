// QA (T-048): independent checks on top risks. Synthetic values only.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';

import '../direct/support.dart';

const _origin = 'https://www.instagram.com';

Map<String, Object?> _msg({Object? tokens, List<Object?>? ops}) => {
  'type': 'discovery',
  'origin': _origin,
  'ops':
      ops ??
      [
        {'name': 'PolarisProfilePostsQuery', 'docId': '12345678901'},
      ],
  'tokens': tokens ?? {'fb_dtsg': 'ZZFAKE_a', 'lsd': 'ZZFAKE_b'},
};

void main() {
  test(
    'unknown username: profile lookup fails, user id never used as name',
    () async {
      final d = PageDiscovery()
        ..recordDiscovery(
          [
            for (final q in GraphqlQuery.values)
              DiscoveredOp(
                name: q.friendlyName,
                docId: '${1000000 + q.index}',
                args: const ['username', 'data', 'id', 'user_id'],
              ),
          ],
          {'fb_dtsg': 'ZZFAKE_a', 'lsd': 'ZZFAKE_b'},
        );
      final rig = Rig(
        responder: (_) => jsonReply({'status': 'fail'}, status: 500),
        transport: GraphqlTransport(docIds: d, tokens: d),
      );
      final r = await rig.run(
        rig.extractor.fetchNewPosts('user_77', DateTime(2000)),
      );
      expect(r.toString(), contains('Err'));
      for (final req in rig.http.requests) {
        expect(variablesOf(req)['username'], isNot('user_77'));
      }
    },
  );

  test(
    'direct mode never sends a seen/mutation or tray-seen operation',
    () async {
      final d = PageDiscovery()
        ..recordDiscovery(
          [
            for (final q in GraphqlQuery.values)
              DiscoveredOp(name: q.friendlyName, docId: '${1000000 + q.index}'),
          ],
          {'fb_dtsg': 'ZZFAKE_a', 'lsd': 'ZZFAKE_b'},
        );
      final rig = Rig(
        responder: (_) => jsonReply({'data': <String, Object?>{}}),
        transport: GraphqlTransport(docIds: d, tokens: d),
      );
      await rig.run(rig.extractor.fetchStories(['u1']));
      await rig.run(rig.extractor.fetchHighlights('u1'));
      await rig.run(rig.extractor.fetchHighlightItems(['a']));
      for (final q in GraphqlQuery.values) {
        expect(q.friendlyName, isNot(contains('Seen')));
      }
      for (final req in rig.http.requests) {
        expect(friendlyName(req), isNot(contains('Seen')));
        expect(friendlyName(req), isNot(contains('Mutation')));
      }
    },
  );

  test('token longer than 4096 is rejected; foreign origin dropped', () {
    final big = 'x' * 4097;
    final m = parseHookMessage([
      _msg(tokens: {'fb_dtsg': big}),
    ], pageOrigin: _origin);
    expect(m, isA<HookDropped>());
    final f = parseHookMessage([_msg()], pageOrigin: 'https://evil.example');
    expect((f as HookDropped).reason, HookDropReason.origin);
    final spoof = _msg()..['origin'] = 'https://evil.example';
    expect(
      (parseHookMessage([spoof], pageOrigin: _origin) as HookDropped).reason,
      HookDropReason.origin,
    );
  });

  test('13 ops, bad doc id and string-encoded json handled strictly', () {
    final ops = [
      for (var i = 0; i < 13; i++) {'name': 'Op$i', 'docId': '12345678901'},
    ];
    expect(
      parseHookMessage([_msg(ops: ops)], pageOrigin: _origin),
      isA<HookDropped>(),
    );
    expect(
      parseHookMessage([jsonEncode(_msg())], pageOrigin: _origin),
      isA<HookDiscovery>(),
    );
    expect(
      parseHookMessage([
        _msg(
          ops: [
            {'name': 'A', 'docId': '12a45'},
          ],
        ),
      ], pageOrigin: _origin),
      isA<HookDropped>(),
    );
  });

  test('tokens and doc ids never appear in toString of snapshot/shape', () {
    final d = PageDiscovery()
      ..recordDiscovery(
        [
          const DiscoveredOp(
            name: 'PolarisProfilePostsQuery',
            docId: '98765432101',
          ),
        ],
        {'fb_dtsg': 'ZZFAKE_dtsg_secret', 'lsd': 'ZZFAKE_lsd_secret'},
      );
    final s = d.toString();
    expect(s, isNot(contains('ZZFAKE')));
    expect(s, isNot(contains('98765432101')));
    final snap = DiscoverySnapshot(
      docIds: {'posts': (docId: '98765432101', at: DateTime(2020))},
      tokens: const {'fb_dtsg': 'ZZFAKE_dtsg_secret'},
      tokensAt: DateTime(2020),
    );
    expect(snap.toString(), isNot(contains('ZZFAKE')));
    expect(snap.toString(), isNot(contains('98765432101')));
  });

  test('user-initiated zone: Timer/Future spawned inside keeps flag (documented), outside does not', () async {
    expect(isUserInitiatedRun, isFalse);
    var inside = false;
    await runUserInitiated(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      inside = isUserInitiatedRun;
    });
    expect(inside, isTrue);
    expect(isUserInitiatedRun, isFalse);
    // a throwing body does not leave the flag set
    await runUserInitiated<void>(() async => throw StateError('x'))
        .then((_) {}, onError: (_) {});
    expect(isUserInitiatedRun, isFalse);
  });
}
