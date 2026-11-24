// T-048: in-page discovery. The hook routine runs in Node against a fake
// `window.require`; the protocol, PageDiscovery, the extractor wiring and the
// manual-check allowance run in Dart. Synthetic values only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import '../page/support.dart';

const _origin = 'https://www.instagram.com';
const _postsDoc = '11111111111111111';
const _storiesDoc = '22222222222222222';
const _dtsg = 'ZZFAKE_dtsg_discovery';
const _lsd = 'ZZFAKE_lsd_discovery';
const _pvKey = '__relay_internal__pv__PolarisShortDramaEnabled';

Map<String, Object?> _op(
  String name,
  Object docId, {
  Map<String, Object?> provided = const {},
  List<Object?> args = const [],
}) => {'name': name, 'docId': docId, 'provided': provided, 'args': args};

Map<String, Object?> _msg({
  List<Object?>? ops,
  Object? tokens,
  Object? error,
}) => {
  'type': 'discovery',
  'origin': _origin,
  'ops': ops ?? [_op('PolarisProfilePostsQuery', _postsDoc)],
  'tokens': tokens ?? {'fb_dtsg': _dtsg, 'lsd': _lsd},
  'error': ?error,
};

HookMessage _parse(Object? data, {String pageOrigin = _origin}) =>
    parseHookMessage([data], pageOrigin: pageOrigin);

NavigationEvent nav(String path) =>
    NavigationEvent(host: 'www.instagram.com', path: path);

bool get _hasNode => Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  final noNode = _hasNode ? null : 'node is not installed';

  group('hook routine (real hook.js, fake window.require)', () {
    late Map<String, dynamic> res;
    setUpAll(() async {
      if (noNode != null) return;
      final r = await Process.run('node', [
        'test/t048/discovery_harness.js',
        'assets/hook.js',
      ]);
      if (r.exitCode != 0) fail('harness failed: ${r.stderr}');
      res = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    });

    Map<String, dynamic> s(String n) => res[n] as Map<String, dynamic>;

    test('success: ops, provided values, arg names and tokens', () {
      final msgs = s('success')['msgs'] as List;
      expect(msgs, hasLength(1));
      final m = msgs.single as Map;
      final ops = m['ops'] as List;
      expect(ops.map((o) => (o as Map)['name']), [
        'PolarisProfilePostsQuery',
        'PolarisStoriesV3ReelPageStandaloneQuery',
      ]);
      final posts = ops.first as Map;
      expect(posts['docId'], '11111111111111111');
      // Only scalar values behind a well-formed provider key.
      expect(posts['provided'], {
        '__relay_internal__pv__PolarisShortDramaEnabled': true,
        '__relay_internal__pv__PolarisSEOIsCrawler': false,
        '__relay_internal__pv__PolarisLevel': 3,
        '__relay_internal__pv__PolarisLabel': 'zzfake',
      });
      // An argument name outside [a-z_] is dropped.
      expect(posts['args'], ['after', 'data', 'username', 'first']);
      expect(m['tokens'], {'fb_dtsg': 'ZZFAKE_dtsg', 'lsd': 'ZZFAKE_lsd'});
      // A doc id that is not digits is not an op.
      expect(
        jsonEncode(ops),
        isNot(contains('PolarisProfilePageContentQuery')),
      );
    }, skip: noNode);

    test('it makes no network request and posts one message', () {
      final r = s('success');
      expect(r['sent'], {'fetch': 0, 'xhr': 0, 'beacon': 0});
      expect(r['total'], 1);
    }, skip: noNode);

    test('without includeRequestSecrets nothing is read or posted', () {
      expect(s('not_configured')['total'], 0);
    }, skip: noNode);

    test('a message from the page runs it again, others are ignored', () {
      final r = s('no_require_yet_then_message');
      expect(r['before'], 0);
      expect(r['after'], 1);
      expect(s('other_message_ignored')['after'], 0);
    }, skip: noNode);

    test('a missing module leaves that op (and token) out', () {
      final m = (s('missing_module')['msgs'] as List).single as Map;
      expect((m['ops'] as List).map((o) => (o as Map)['name']), [
        'PolarisProfilePostsQuery',
      ]);
      expect(m['tokens'], {'fb_dtsg': 'ZZFAKE_dtsg'});
    }, skip: noNode);

    test('a module that throws keeps the doc id, drops the shape', () {
      final m = (s('one_module_throws')['msgs'] as List).single as Map;
      final posts = (m['ops'] as List).first as Map;
      expect(posts['docId'], '11111111111111111');
      expect(posts['provided'], isEmpty);
      expect(posts['args'], isEmpty);
      expect(m['ops'] as List, hasLength(2));
    }, skip: noNode);

    test('require that always throws: empty ops, an error code, no values', () {
      final r = s('require_throws');
      final m = (r['msgs'] as List).single as Map;
      expect(m['ops'], isEmpty);
      expect(m['tokens'], isEmpty);
      expect(m['error'], 'require_failed');
      expect(jsonEncode(m), isNot(contains('ZZFAKE')));
      expect(r['sent'], {'fetch': 0, 'xhr': 0, 'beacon': 0});
    }, skip: noNode);

    test('nothing resolving posts nothing; posts are bounded', () {
      expect(s('nothing_resolves')['msgs'], isEmpty);
      // Unchanged modules are posted once (T-049 dedupe); the cap is tested
      // in the T-049 harness.
      expect(s('bounded_posts')['count'], 1);
    }, skip: noNode);
  });

  group('hook protocol: strict discovery shapes', () {
    test('a good message parses', () {
      final m = _parse(
        _msg(
          ops: [
            _op(
              'PolarisProfilePostsQuery',
              _postsDoc,
              provided: {_pvKey: true, '__relay_internal__pv__N': 2},
              args: ['after', 'username'],
            ),
          ],
        ),
      );
      m as HookDiscovery;
      expect(m.ops.single.docId, _postsDoc);
      expect(m.ops.single.provided, {
        _pvKey: true,
        '__relay_internal__pv__N': 2,
      });
      expect(m.ops.single.args, ['after', 'username']);
      expect(m.tokens, {'fb_dtsg': _dtsg, 'lsd': _lsd});
      expect(m.toString(), isNot(contains(_postsDoc)));
      expect(m.ops.single.toString(), isNot(contains(_postsDoc)));
    });

    test('an empty failure message parses with its error code', () {
      final m = _parse(_msg(ops: [], tokens: {}, error: 'require_failed'));
      m as HookDiscovery;
      expect(m.ops, isEmpty);
      expect(m.error, 'require_failed');
    });

    void dropped(String why, Object? data) {
      final m = _parse(data);
      expect(m, isA<HookDropped>(), reason: why);
      expect((m as HookDropped).reason, HookDropReason.malformed, reason: why);
    }

    test('bad doc ids are refused', () {
      for (final bad in ['1234', 'a' * 5, '1' * 33, '12 345', '', 12345]) {
        dropped(
          'doc id $bad',
          _msg(ops: [_op('PolarisProfilePostsQuery', bad)]),
        );
      }
    });

    test('bad provider keys and values are refused', () {
      for (final key in [
        'pv',
        '__relay_internal__pv__',
        'x__relay_internal__pv__A',
        '__relay_internal__pv__a-b',
      ]) {
        dropped(
          'key $key',
          _msg(
            ops: [
              _op('PolarisProfilePostsQuery', _postsDoc, provided: {key: true}),
            ],
          ),
        );
      }
      for (final value in [
        <String, Object?>{},
        <Object?>[],
        null,
        'x' * 65,
      ]) {
        dropped(
          'value $value',
          _msg(
            ops: [
              _op(
                'PolarisProfilePostsQuery',
                _postsDoc,
                provided: {_pvKey: value},
              ),
            ],
          ),
        );
      }
    });

    test('bad argument names and containers are refused', () {
      for (final arg in ['Username', 'a-b', '', 'x' * 65, 7, 'a b']) {
        dropped(
          'arg $arg',
          _msg(
            ops: [
              _op('PolarisProfilePostsQuery', _postsDoc, args: [arg]),
            ],
          ),
        );
      }
      dropped('ops not a list', (_msg()..['ops'] = 'x'));
      dropped(
        'too many ops',
        _msg(ops: [for (var i = 0; i < 13; i++) _op('Q$i', _postsDoc)]),
      );
      dropped('bad op name', _msg(ops: [_op('bad name', _postsDoc)]));
      dropped('tokens not a map', _msg(tokens: 'x'));
      dropped('token not a string', _msg(tokens: {'fb_dtsg': 1}));
      dropped('error shape', _msg(error: 'Bad Error!'));
    });

    test('a foreign origin is dropped as origin, not parsed', () {
      expect(
        (_parse(_msg(), pageOrigin: 'https://evil.test') as HookDropped).reason,
        HookDropReason.origin,
      );
      final claimed = _msg()..['origin'] = 'https://evil.test';
      expect((_parse(claimed) as HookDropped).reason, HookDropReason.origin);
    });

    test('unknown tokens are not kept, only fb_dtsg and lsd', () {
      final m = _parse(
        _msg(tokens: {'fb_dtsg': _dtsg, 'lsd': _lsd, 'cookie': 'x'}),
      );
      expect((m as HookDiscovery).tokens.keys, ['fb_dtsg', 'lsd']);
    });
  });

  group('PageDiscovery.recordDiscovery', () {
    const ops = [
      DiscoveredOp(
        name: 'PolarisProfilePostsQuery',
        docId: _postsDoc,
        provided: {_pvKey: true},
        args: ['username', 'data'],
      ),
      DiscoveredOp(
        name: 'PolarisStoriesV3ReelPageStandaloneQuery',
        docId: _storiesDoc,
        args: ['reel_ids_arr', 'is_highlight'],
      ),
      DiscoveredOp(name: 'SomethingElseQuery', docId: '33333'),
    ];

    test('records doc id, shape and tokens; unknown ops are ignored', () async {
      final d = PageDiscovery();
      final got = d.recordDiscovery(ops, {'fb_dtsg': _dtsg, 'lsd': _lsd});
      expect(got, [GraphqlQuery.posts, GraphqlQuery.stories]);
      expect(await d.docIdFor(GraphqlQuery.posts), _postsDoc);
      expect(await d.docIdFor(GraphqlQuery.profile), isNull);
      final shape = await d.shapeFor(GraphqlQuery.posts);
      expect(shape!.provided, {_pvKey: true});
      expect(shape.args, ['username', 'data']);
      expect(await d.shapeFor(GraphqlQuery.highlights), isNull);
      expect(await d.tokens(), {'fb_dtsg': _dtsg, 'lsd': _lsd});
    });

    test(
      'only one token present: kept, but not a complete pair (T-049)',
      () async {
        final d = PageDiscovery()..recordDiscovery(ops, {'fb_dtsg': _dtsg});
        expect(await d.tokens(), {'fb_dtsg': _dtsg});
        expect(pageTokensComplete(await d.tokens()), isFalse);
      },
    );

    test('shapes and docIds persist through the store', () async {
      final store = InMemoryDiscoveryStore();
      final a = PageDiscovery(store: store, accountId: 7)
        ..recordDiscovery(ops, {'fb_dtsg': _dtsg, 'lsd': _lsd});
      await a.flush();
      final b = PageDiscovery(store: store, accountId: 7);
      expect(await b.docIdFor(GraphqlQuery.posts), _postsDoc);
      final shape = await b.shapeFor(GraphqlQuery.posts);
      expect(shape!.args, ['username', 'data']);
      expect(shape.provided, {_pvKey: true});
      final snap = (await store.load(7))!;
      final json = jsonDecode(snap.toJson()) as Map<String, Object?>;
      expect((json['shapes']! as Map).keys, containsAll(['posts', 'stories']));
      expect(DiscoverySnapshot.fromJson(snap.toJson())!.shapes['posts']!.args, [
        'username',
        'data',
      ]);
    });

    test('forget drops the shape with the doc id', () async {
      final store = InMemoryDiscoveryStore();
      final d = PageDiscovery(store: store, accountId: 1)
        ..recordDiscovery(ops, {});
      await d.flush();
      await d.forget(GraphqlQuery.posts);
      expect(await d.shapeFor(GraphqlQuery.posts), isNull);
      expect((await store.load(1))!.shapes.containsKey('posts'), isFalse);
    });

    test('an old snapshot without shapes still loads', () {
      final snap = DiscoverySnapshot.fromJson(
        '{"v":1,"docIds":{"posts":{"id":"$_postsDoc","at":1700000000000}}}',
      );
      expect(snap!.docIds['posts']!.docId, _postsDoc);
      expect(snap.shapes, isEmpty);
    });
  });

  group('PageExtractor handles the discovery message', () {
    Rig rigWith(Map<String, Object?> discovery) => Rig(
      onLoad: emitting([
        nav('/$fakeUser/'),
        HookEvent(pageOrigin: _origin, args: [discovery]),
        hookResponse(realProfile(), name: profileName),
      ]),
    );

    test(
      'records into the shared discovery and logs names and counts',
      () async {
        final rig = rigWith(
          _msg(
            ops: [
              _op(
                'PolarisProfilePostsQuery',
                _postsDoc,
                provided: {_pvKey: true, '__relay_internal__pv__B': false},
                args: ['username'],
              ),
              _op(
                'PolarisStoriesV3ReelPageStandaloneQuery',
                _storiesDoc,
                args: ['reel_ids_arr'],
              ),
            ],
          ),
        );
        final r = await rig.run(rig.extractor.resolveUser(fakeUser));
        expect(r, isA<Ok<RemoteUser>>());
        expect(await rig.discovery.docIdFor(GraphqlQuery.posts), _postsDoc);
        expect((await rig.discovery.shapeFor(GraphqlQuery.stories))!.args, [
          'reel_ids_arr',
        ]);
        final line = rig.log.entries
            .map((e) => '$e')
            .firstWhere((l) => l.contains('discovery ops='));
        expect(
          line,
          contains(
            'ops=PolarisProfilePostsQuery,'
            'PolarisStoriesV3ReelPageStandaloneQuery',
          ),
        );
        expect(
          line,
          contains(
            'provided=PolarisStoriesV3ReelPageStandaloneQuery:0,'
            'PolarisProfilePostsQuery:2',
          ),
        );
        expect(line, contains('tokens=dtsg:yes(module),lsd:yes(module)'));
      },
    );

    test(
      'log hygiene: no doc id, token or provider value in any log',
      () async {
        final rig = rigWith(_msg());
        await rig.run(rig.extractor.resolveUser(fakeUser));
        final logs = rig.allLogs;
        for (final secret in [
          _postsDoc,
          _dtsg,
          _lsd,
          fakeDocId,
          fakeDtsg,
          fakeLsd,
        ]) {
          expect(logs, isNot(contains(secret)));
        }
      },
    );

    test(
      'a malformed discovery is dropped and counted, nothing recorded',
      () async {
        final rig = rigWith(
          _msg(ops: [_op('PolarisProfilePostsQuery', 'abc')]),
        );
        await rig.run(rig.extractor.resolveUser(fakeUser));
        expect(rig.extractor.droppedMalformedCount, 1);
        // The doc id the profile capture itself carried is for another query.
        expect(await rig.discovery.docIdFor(GraphqlQuery.posts), isNull);
      },
    );

    test('a failure message records nothing and logs the error code', () async {
      final rig = rigWith(_msg(ops: [], tokens: {}, error: 'require_failed'));
      await rig.run(rig.extractor.resolveUser(fakeUser));
      expect(rig.discovery.knownQueries, [GraphqlQuery.profile]);
      expect(
        rig.log.entries
            .map((e) => '$e')
            .any((l) => l.contains('error=require_failed')),
        isTrue,
      );
    });
  });

  group('manual checks may load pages in the background', () {
    Rig bg({bool Function()? allowed}) => Rig(
      runsInBackground: true,
      backgroundAllowed: allowed,
      onLoad: emitting([
        nav('/stories/$fakeUser/'),
        hookResponse(loadReal('story', '003_graphql.json'), name: storiesName),
      ]),
    );

    test('user-initiated: loads although the setting is off', () async {
      final rig = bg(allowed: () => false);
      final r = await rig.run(
        runUserInitiated(() => rig.extractor.fetchStories(['user_1'])),
      );
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
      expect(rig.driver.sessions, hasLength(1));
    });

    test('scheduled: refused, nothing opened', () async {
      final rig = bg(allowed: () => false);
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(
        r.failureOrNull,
        const UnknownFailure(null, 'page_mode_background_disabled'),
      );
      expect(rig.driver.log, isEmpty);
    });

    test('the allowance survives awaits and ends with the run', () async {
      final seen = <bool>[];
      await runUserInitiated(() async {
        await Future<void>.delayed(Duration.zero);
        seen.add(isUserInitiatedRun);
      });
      seen.add(isUserInitiatedRun);
      expect(seen, [true, false]);
    });
  });
}
