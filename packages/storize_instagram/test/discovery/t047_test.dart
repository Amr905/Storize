// T-047: tolerant query-name matching, hook name extraction, log hygiene.
// Synthetic ZZFAKE_ values only.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';

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
        GraphqlQuery.posts.matchesName(
          'PolarisProfilePostsTabContentQuery_connection',
        ),
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
    test(
      'an alias is recorded, and does not replace an exact doc_id',
      () async {
        final clock = FakeClock();
        final d = PageDiscovery(clock: clock)
          ..record(
            friendlyName: 'PolarisProfilePostsTabContentQuery_connection',
            docId: '1111111',
            tokens: const {},
          );
        expect(await d.docIdFor(GraphqlQuery.posts), '1111111');
        d.record(
          friendlyName: 'PolarisProfilePostsQuery',
          docId: '2222222',
          tokens: const {},
        );
        expect(await d.docIdFor(GraphqlQuery.posts), '2222222');
        d.record(
          friendlyName: 'PolarisProfilePostsTabContentQuery_connection',
          docId: '3333333',
          tokens: const {},
        );
        expect(await d.docIdFor(GraphqlQuery.posts), '2222222');
        expect(d.knownQueries, [GraphqlQuery.posts]);
        expect(d.hasTokens, isFalse);
      },
    );
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
