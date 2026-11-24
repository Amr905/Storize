// T-047: tolerant query-name matching, hook name extraction, log hygiene.
// Synthetic ZZFAKE_ values only.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

void main() {
  group('GraphqlQuery.matchesName', () {
    test('exact names still match', () {
      for (final q in GraphqlQuery.values) {
        expect(q.matchesName(q.friendlyName), isTrue);
      }
    });

    test('renamed or suffixed names match', () {
      expect(
        GraphqlQuery.posts.matchesName('PolarisProfilePostsTabContentQuery'),
        isTrue,
      );
      expect(
        GraphqlQuery.posts.matchesName('PolarisProfilePostsQuery_v2'),
        isTrue,
      );
      expect(
        GraphqlQuery.stories.matchesName('PolarisStoriesV3ReelPageQuery'),
        isTrue,
      );
      expect(
        GraphqlQuery.stories.matchesName('XReelPageStandaloneQuery_v2'),
        isTrue,
      );
      expect(
        GraphqlQuery.profile.matchesName('PolarisProfilePageContentQuery_v2'),
        isTrue,
      );
    });

    test('unrelated, tray and seen names do not match', () {
      expect(GraphqlQuery.posts.matchesName('PolarisFeedRootQuery'), isFalse);
      expect(GraphqlQuery.posts.matchesName(null), isFalse);
      expect(GraphqlQuery.posts.matchesName(''), isFalse);
      expect(
        GraphqlQuery.stories.matchesName('PolarisStoriesV3SeenMutation'),
        isFalse,
      );
      expect(
        GraphqlQuery.stories.matchesName('PolarisStoriesV3ReelsTrayQuery'),
        isFalse,
      );
      expect(
        GraphqlQuery.profile.matchesName('PolarisProfilePostsQuery'),
        isFalse,
      );
    });
  });

  group('PageDiscovery.record with aliases', () {
    test('a _connection name fills postsPaging, never posts', () async {
      final d = PageDiscovery(clock: FakeClock())
        ..record(
          friendlyName: 'PolarisProfilePostsTabContentQuery_connection',
          docId: '1111111',
          tokens: const {},
        );
      expect(await d.docIdFor(GraphqlQuery.posts), isNull);
      expect(await d.docIdFor(GraphqlQuery.postsPaging), '1111111');
    });

    test('a suffixed posts alias fills posts and not postsPaging', () async {
      final d = PageDiscovery(clock: FakeClock())
        ..record(
          friendlyName: 'PolarisProfilePostsQuery_v2',
          docId: '2222222',
          tokens: const {},
        );
      expect(await d.docIdFor(GraphqlQuery.posts), '2222222');
      expect(await d.docIdFor(GraphqlQuery.postsPaging), isNull);
      expect(d.knownQueries, [GraphqlQuery.posts]);
    });

    test('an alias does not replace an exact doc_id', () async {
      final d = PageDiscovery(clock: FakeClock())
        ..record(
          friendlyName: 'PolarisProfilePostsQuery',
          docId: '2222222',
          tokens: const {},
        )
        ..record(
          friendlyName: 'PolarisProfilePostsQuery_v2',
          docId: '3333333',
          tokens: const {},
        );
      expect(await d.docIdFor(GraphqlQuery.posts), '2222222');
    });
  });

  group('timeline doc_id use', () {
    final seen = <String>[];
    setUp(seen.clear);

    Future<void> run(Map<GraphqlQuery, String> ids, {String? cursor}) async {
      final t = GraphqlTransport(
        docIds: _MapIds(ids),
        tokens: _Tok(),
      );
      await t.timelinePage(
        '1',
        (r) async {
          seen.add(r.form!['doc_id']!);
          return const Ok(<String, Object?>{});
        },
        cursor: cursor,
        usernameHint: 'zz_user',
      );
    }

    test('the first page never uses the paging doc_id', () async {
      await run({GraphqlQuery.postsPaging: 'PAGING'});
      expect(seen, isEmpty, reason: 'no posts doc_id: nothing sent');
      await run({
        GraphqlQuery.posts: 'FIRST',
        GraphqlQuery.postsPaging: 'PAGING',
      });
      expect(seen, ['FIRST']);
    });

    test('a later page uses the paging doc_id when known', () async {
      await run({
        GraphqlQuery.posts: 'FIRST',
        GraphqlQuery.postsPaging: 'PAGING',
      }, cursor: 'c1');
      expect(seen, ['PAGING']);
      seen.clear();
      await run({GraphqlQuery.posts: 'FIRST'}, cursor: 'c1');
      expect(seen, ['FIRST']);
    });
  });

  group('hook protocol', () {
    Object msg({Map<String, Object?>? extra}) => {
      'url': 'https://www.instagram.com/api/graphql',
      'status': 200,
      'body': '{"data":{}}',
      'origin': 'https://www.instagram.com',
      ...?extra,
    };

    test('name, doc_id and tokens come through from the request', () {
      final m = parseHookMessage([
        msg(
          extra: {
            'friendlyName': 'PolarisProfilePostsTabContentQuery_connection',
            'request': {
              'docId': '1234567890',
              'tokens': {'lsd': 'ZZFAKE_lsd'},
            },
          },
        ),
      ], pageOrigin: 'https://www.instagram.com');
      final c = m as HookCapture;
      expect(c.friendlyName, 'PolarisProfilePostsTabContentQuery_connection');
      expect(c.docId, '1234567890');
      expect(c.tokens.keys, ['lsd']);
    });

    test('log names are sanitized, cut, deduped and capped', () {
      final names = logSafeNames([
        '1234567890123',
        null,
        'A b/c?doc_id=1',
        'Name',
        'Name',
        'x' * 100,
        for (var i = 0; i < 20; i++) 'N$i',
      ]);
      expect(names, hasLength(12));
      expect(names.first, 'Abcdoc_id1');
      expect(names.where((n) => n == 'Name'), hasLength(1));
      expect(names[2].length, 60);
      for (final n in names) {
        expect(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(n), isTrue);
      }
    });
  });
}

final class _MapIds implements DocIdResolver {
  _MapIds(this.ids);
  final Map<GraphqlQuery, String> ids;

  @override
  Future<String?> docIdFor(GraphqlQuery query) async => ids[query];
}

final class _Tok implements PageTokenProvider {
  @override
  Future<Map<String, String>?> tokens() async => {'lsd': 'ZZFAKE_lsd'};
}
