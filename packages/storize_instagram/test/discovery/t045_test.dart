// T-045: persisted page discovery, REST gated by probe proof, and the
// secret-free diagnostics. Synthetic ZZFAKE_ values only.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _user = 'ZZFAKE_user_a';

PageDiscovery _discovery(
  InMemoryDiscoveryStore store,
  FakeClock clock, {
  int accountId = 1,
}) => PageDiscovery(clock: clock, store: store, accountId: accountId);

Future<void> _learn(PageDiscovery d, {bool allQueries = true}) async {
  for (final q in allQueries ? GraphqlQuery.values : [GraphqlQuery.stories]) {
    d.record(
      friendlyName: q.friendlyName,
      docId: 'ZZFAKE_doc_${q.name}',
      tokens: {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
    );
  }
  await d.flush();
}

Object? _storyReelsGraphql() => {
  'data': {
    'xdt_api__v1__feed__reels_media': {'reels_media': <Object?>[]},
  },
};

final class _FailingStore implements DiscoveryStore {
  @override
  Future<DiscoverySnapshot?> load(int accountId) async =>
      throw StateError('ZZFAKE_secret_in_error');

  @override
  Future<void> save(int accountId, DiscoverySnapshot snapshot) async =>
      throw StateError('ZZFAKE_secret_in_error');

  @override
  Future<void> clear(int accountId) async {}
}

void main() {
  group('persistence across isolates (two instances, one store)', () {
    test('a doc_id and tokens recorded by one are read by the other', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final fg = _discovery(store, clock);
      final bg = _discovery(store, clock);
      expect(await bg.docIdFor(GraphqlQuery.stories), isNull);

      await _learn(fg);

      expect(await bg.docIdFor(GraphqlQuery.stories), 'ZZFAKE_doc_stories');
      expect(await bg.docIdFor(GraphqlQuery.posts), 'ZZFAKE_doc_posts');
      expect(await bg.tokens(), {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd});
    });

    test('accounts do not see each other', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      await _learn(_discovery(store, clock));
      final other = _discovery(store, clock, accountId: 2);
      expect(await other.docIdFor(GraphqlQuery.stories), isNull);
      expect(await other.tokens(), isNull);
    });

    test('a second record merges with what the store holds', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final a = _discovery(store, clock);
      final b = _discovery(store, clock);
      a.record(
        friendlyName: GraphqlQuery.stories.friendlyName,
        docId: 'ZZFAKE_doc_s',
        tokens: const {},
      );
      await a.flush();
      b.record(
        friendlyName: GraphqlQuery.posts.friendlyName,
        docId: 'ZZFAKE_doc_p',
        tokens: const {},
      );
      await b.flush();
      final snap = (await store.load(1))!;
      expect(snap.docIds.keys, {'stories', 'posts'});
    });

    test('the snapshot JSON round trips; garbage reads as nothing', () {
      final snap = DiscoverySnapshot(
        docIds: {'stories': (docId: 'ZZFAKE_d', at: DateTime.utc(2026, 1, 2))},
        tokens: const {'lsd': 'ZZFAKE_t'},
        tokensAt: DateTime.utc(2026, 1, 2, 1),
      );
      final back = DiscoverySnapshot.fromJson(snap.toJson())!;
      expect(back.docIds['stories']!.docId, 'ZZFAKE_d');
      expect(back.tokens, {'lsd': 'ZZFAKE_t'});
      expect(back.tokensAt, DateTime.utc(2026, 1, 2, 1));
      expect(DiscoverySnapshot.fromJson('not json ZZFAKE_x'), isNull);
      expect(DiscoverySnapshot.fromJson('{"v":2}'), isNull);
      expect(DiscoverySnapshot.fromJson('[]'), isNull);
    });

    test('toString shows counts only, never a value', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final d = _discovery(store, clock);
      await _learn(d);
      final text = '$d ${await store.load(1)} $store';
      expect(text, contains('docIds: 4'));
      expect(text, isNot(contains('ZZFAKE')));
      expect(text, isNot(contains(fakeDtsg)));
    });

    test('a failing store never throws and never leaks its message', () async {
      final errors = <String>[];
      final d = PageDiscovery(
        clock: FakeClock(),
        store: _FailingStore(),
        onWriteError: errors.add,
      );
      await _learn(d);
      expect(await d.docIdFor(GraphqlQuery.stories), 'ZZFAKE_doc_stories');
      await d.flush();
      expect(errors, isNotEmpty);
      expect(errors.join(), isNot(contains('ZZFAKE_secret')));
    });
  });

  group('TTL', () {
    test('doc_ids last 6 h, persisted tokens 12 h', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      await _learn(_discovery(store, clock));

      clock.advance(const Duration(hours: 5, minutes: 59));
      final fresh = _discovery(store, clock);
      expect(await fresh.docIdFor(GraphqlQuery.stories), isNotNull);

      clock.advance(const Duration(minutes: 2)); // 6 h 1 min
      final later = _discovery(store, clock);
      expect(await later.docIdFor(GraphqlQuery.stories), isNull);
      expect(await later.tokens(), isNotNull, reason: 'tokens live 12 h');

      clock.advance(const Duration(hours: 6)); // 12 h 1 min
      final late = _discovery(store, clock);
      expect(await late.tokens(), isNull);
    });

    test('without a store the old 30 min token lifetime stays', () async {
      final clock = FakeClock();
      final d = PageDiscovery(clock: clock);
      await _learn(d);
      clock.advance(const Duration(minutes: 31));
      expect(await d.tokens(), isNull);
      expect(await d.docIdFor(GraphqlQuery.stories), isNotNull);
    });
  });

  group('clearing', () {
    test('clear() empties memory and the store', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final d = _discovery(store, clock);
      await _learn(d);
      d.clear();
      await d.flush();
      expect(await store.load(1), isNull);
      expect(await _discovery(store, clock).tokens(), isNull);
    });

    test('forget() drops one doc_id from the store, keeps the rest', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final d = _discovery(store, clock);
      await _learn(d);
      await d.forget(GraphqlQuery.stories);
      final other = _discovery(store, clock);
      expect(await other.docIdFor(GraphqlQuery.stories), isNull);
      expect(await other.docIdFor(GraphqlQuery.posts), isNotNull);
      expect(await other.tokens(), isNotNull);
    });

    test('a GraphQL SchemaChanged (stale doc_id) drops it from the store '
        'and does not go to REST', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final d = _discovery(store, clock);
      await _learn(d);
      final rig = Rig(
        transport: FallbackTransport(docIds: d, tokens: d),
        responder: (_) => jsonReply({'data': <String, Object?>{}}),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.failureOrNull, isA<SchemaChanged>());
      expect(rig.http.requests.map((r) => r.uri.path), ['/api/graphql']);
      expect(
        await _discovery(store, clock).docIdFor(GraphqlQuery.stories),
        isNull,
      );
      expect(
        await _discovery(store, clock).docIdFor(GraphqlQuery.posts),
        isNotNull,
        reason: 'only the queries of that op are dropped',
      );
    });
  });

  group('the fallback without proof', () {
    test(
      'no discovery and no proof: zero HTTP requests, SchemaChanged',
      () async {
        final d = PageDiscovery(clock: FakeClock());
        final rig = Rig(
          transport: FallbackTransport(docIds: d, tokens: d),
          responder: (_) => throw StateError('no request may be sent'),
        );
        final stories = await rig.run(rig.extractor.fetchStories([_user]));
        final posts = await rig.run(
          rig.extractor.fetchNewPosts(_user, DateTime.utc(2026)),
        );
        final tray = await rig.run(rig.extractor.fetchHighlights(_user));
        for (final r in [
          stories.failureOrNull,
          posts.failureOrNull,
          tray.failureOrNull,
        ]) {
          expect(r, isA<SchemaChanged>());
          expect((r! as SchemaChanged).where, startsWith('doc_id:'));
        }
        expect(rig.http.requests, isEmpty);
        expect(await rig.governor.remainingTokens(1), 6, reason: 'no token');
      },
    );

    test(
      'persisted discovery lets a "background" instance use GraphQL',
      () async {
        final clock = FakeClock();
        final store = InMemoryDiscoveryStore();
        await _learn(_discovery(store, clock));
        final bg = _discovery(store, clock);
        final rig = Rig(
          transport: FallbackTransport(docIds: bg, tokens: bg),
          responder: (_) => jsonReply(_storyReelsGraphql()),
        );
        final r = await rig.run(rig.extractor.fetchStories([_user]));
        expect(r.isOk, isTrue);
        expect(rig.http.requests.single.uri.path, '/api/graphql');
      },
    );

    test('the verify bootstrap still reaches REST without discovery', () async {
      final d = PageDiscovery(clock: FakeClock());
      final rig = Rig(
        transport: FallbackTransport(docIds: d, tokens: d),
        responder: (r) => r.uri.path.contains('current_user')
            ? jsonReply({
                'user': {'pk': viewerId, 'username': 'ZZFAKE_me'},
                'status': 'ok',
              })
            : jsonReply({'status': 'ok'}),
      );
      await rig.run(rig.extractor.verifySession());
      expect(
        rig.http.requests.map((r) => r.uri.path),
        contains(contains('current_user')),
      );
    });

    test('REST runs only for the ops a probe proved', () async {
      ProbeEntry entry(String id, {required bool ok}) => ProbeEntry(
        id: id,
        label: 'x',
        outcome: 'ok',
        status: ok ? 200 : 404,
        topLevelKeys: ok ? ProbeEntry.expectedKeys[id]! : const [],
      );
      final probe = ProbeReport(
        entries: [
          entry('IG-1', ok: false),
          entry('IG-2', ok: true),
          entry('IG-3', ok: false),
          entry('IG-4', ok: false),
          entry('IG-5', ok: false),
        ],
      );
      expect(provenRestOps(probe), {'storyReels', 'highlightItems'});
      expect(provenRestOps(null), isEmpty);

      final d = PageDiscovery(clock: FakeClock());
      final rig = Rig(
        transport: selectTransport(docIds: d, tokens: d, probe: probe),
        responder: (r) => r.uri.path == '/api/v1/feed/reels_media/'
            ? jsonReply(loadSynthetic('rest_reels_media.json'))
            : throw StateError('only the proven route may be requested'),
      );
      final stories = await rig.run(rig.extractor.fetchStories([_user]));
      expect(stories.isOk, isTrue);
      expect(rig.http.requests, hasLength(1));
      final posts = await rig.run(
        rig.extractor.fetchNewPosts(_user, DateTime.utc(2026)),
      );
      expect(posts.failureOrNull, isA<SchemaChanged>());
      expect(rig.http.requests, hasLength(1), reason: 'no request for posts');
    });
  });

  group('diagnostics hygiene', () {
    test('a rate limit logs op, transport, status and hint only', () async {
      final d = PageDiscovery(clock: FakeClock());
      final rig = Rig(
        transport: FallbackTransport(
          docIds: d,
          tokens: d,
          restOps: allRestOps,
        ),
        responder: (_) => jsonReply(
          {
            'message':
                'Please wait a few minutes before you try again. '
                'ZZFAKE_user_a 1234567890',
            'status': 'fail',
          },
          status: 400,
        ),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.failureOrNull, isA<RateLimited>());
      final line = rig.log.entries
          .map((e) => e.message)
          .singleWhere((m) => m.contains('rate_limited'));
      expect(line, contains('op=fetchStories'));
      expect(line, contains('via=rest'));
      expect(line, contains('status=400'));
      expect(line, contains('hint=please_wait_a_few_minutes'));
      final all = rig.allLogs;
      for (final secret in [
        'ZZFAKE_user_a',
        '1234567890',
        fakeSessionId,
        fakeCsrf,
        'http',
        'instagram.com',
      ]) {
        expect(all, isNot(contains(secret)), reason: secret);
      }
    });

    test('a 429 on GraphQL says via=graphql with the status', () async {
      final clock = FakeClock();
      final store = InMemoryDiscoveryStore();
      final d = _discovery(store, clock);
      await _learn(d);
      final rig = Rig(
        transport: FallbackTransport(docIds: d, tokens: d),
        responder: (_) => const IgReply(status: 429),
      );
      await rig.run(rig.extractor.fetchStories([_user]));
      final line = rig.log.entries
          .map((e) => e.message)
          .singleWhere((m) => m.contains('rate_limited'));
      expect(line, contains('via=graphql'));
      expect(line, contains('status=429'));
    });

    test('SchemaChanged logs the status and at most 8 plain key names, '
        'no values', () async {
      final d = PageDiscovery(clock: FakeClock());
      final rig = Rig(
        transport: FallbackTransport(
          docIds: d,
          tokens: d,
          restOps: allRestOps,
        ),
        responder: (_) => jsonReply({
          'alpha': 'ZZFAKE_value_1',
          'beta': 1,
          'gamma': 1,
          'delta': 1,
          'eps': 1,
          'zeta': 1,
          'eta': 1,
          'theta': 1,
          'iota': 'ZZFAKE_value_2',
          'kappa': 1,
          'ZZFAKE_UserKey99': 'ZZFAKE_value_3',
          '1234567890': 'ZZFAKE_value_4',
        }),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.failureOrNull, isA<SchemaChanged>());
      final line = rig.log.entries
          .map((e) => e.message)
          .singleWhere((m) => m.contains('failure=SchemaChanged'));
      expect(line, contains('status=200'));
      final keys = RegExp(r'keys=\[(.*?)\]').firstMatch(line)!.group(1)!;
      expect(keys.split(','), hasLength(8));
      expect(keys, startsWith('alpha,beta'));
      for (final secret in ['ZZFAKE', '1234567890', 'value']) {
        expect(rig.allLogs, isNot(contains(secret)), reason: secret);
      }
    });

    test('UnknownFailure (HTTP 500) logs status and keys', () async {
      final d = PageDiscovery(clock: FakeClock());
      final rig = Rig(
        transport: FallbackTransport(
          docIds: d,
          tokens: d,
          restOps: allRestOps,
        ),
        responder: (_) =>
            jsonReply({'status': 'fail', 'detail': 1}, status: 500),
      );
      await rig.run(rig.extractor.fetchStories([_user]));
      final line = rig.log.entries
          .map((e) => e.message)
          .singleWhere((m) => m.contains('failure=UnknownFailure'));
      expect(line, contains('status=500'));
      expect(line, contains('keys=[status,detail]'));
    });
  });
}
