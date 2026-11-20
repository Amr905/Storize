// DirectExtractor on the GraphQL transport: the real capture fixtures and
// the synthetic ones, through the real RequestGovernor on fake time.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

DateTime _t(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

/// The real profile body with the username replaced, so that the username
/// check of `resolveUser` passes (the capture holds only placeholders).
Object? _profileNamed(String username) {
  final body = jsonDecode(
    jsonEncode(loadReal('profile', '004_graphql.json')),
  ) as Map<String, Object?>;
  ((body['data']! as Map<String, Object?>)['user']!
          as Map<String, Object?>)['username'] =
      username;
  return body;
}

Rig _realRig({String sessionUserId = viewerId}) => Rig(
  sessionUserId: sessionUserId,
  responder: graphqlResponder(
    stories: loadReal('story', '003_graphql.json'),
    profile: _profileNamed('ZZFake_Name'),
    posts: loadReal('profile', '007_graphql.json'),
  ),
);

Rig _syntheticPostsRig() => Rig(
  responder: graphqlResponder(
    posts: loadSynthetic('timeline.json'),
    profile: loadReal('profile', '004_graphql.json'),
  ),
);

void main() {
  group('AC1 users', () {
    test('resolveUser: owner id from the posts (not from the collab node), '
        'then the profile by id; 2 governed calls', () async {
      final rig = _realRig();
      final user = (await rig.run(rig.extractor.resolveUser('@ZZFake_Name ')))
          .valueOrNull!;
      expect(user.remoteUserId, 'user_1');
      expect(user.followedByViewer, isTrue);
      final names = rig.http.requests.map(friendlyName).toList();
      expect(names, [
        'PolarisProfilePostsQuery',
        'PolarisProfilePageContentQuery',
      ]);
      expect(variablesOf(rig.http.requests[0])['username'], 'ZZFake_Name');
      expect(variablesOf(rig.http.requests[1])['id'], 'user_1');
      expect(
        await rig.governor.remainingTokens(1),
        4,
        reason: '2 api calls of 6',
      );
    });

    test(
      'resolveUser: a blank name is TargetNotFound without any call',
      () async {
        final rig = _realRig();
        final r = await rig.run(rig.extractor.resolveUser('  @ '));
        expect(r.failureOrNull, const TargetNotFound());
        expect(rig.http.requests, isEmpty);
      },
    );

    test('resolveUser: only collab posts: the one id present in all of them '
        'is the owner', () async {
      final rig = Rig(
        responder: graphqlResponder(
          posts: loadSynthetic('timeline_all_collab.json'),
          profile: loadReal('profile', '004_graphql.json'),
        ),
      );
      await rig.run(rig.extractor.resolveUser('zz'));
      expect(variablesOf(rig.http.requests[1])['id'], 'ZZFAKE_user_a');
    });

    test('resolveUser: no posts, or two ids in every post, fails softly '
        'instead of guessing', () async {
      Map<String, Object?> posts(List<Map<String, Object?>> nodes) => {
        'data': {
          'xdt_api__v1__feed__user_timeline_graphql_connection': {
            'edges': [
              for (final n in nodes) {'node': n},
            ],
          },
        },
      };
      Map<String, Object?> node(String pk) => {
        'pk': pk,
        'taken_at': 1800000000,
        'user': {'pk': 'ZZFAKE_x'},
        'coauthor_producers': [
          {'pk': 'ZZFAKE_a'},
          {'pk': 'ZZFAKE_b'},
        ],
      };
      for (final body in [
        posts([]),
        posts([node('ZZFAKE_1'), node('ZZFAKE_2')]),
      ]) {
        final rig = Rig(responder: graphqlResponder(posts: body));
        final r = await rig.run(rig.extractor.resolveUser('zz'));
        expect(
          r.failureOrNull,
          const UnknownFailure(null, 'username_unresolvable'),
        );
      }
    });

    test('refreshUser: by id, one call, rename visible', () async {
      final rig = _realRig();
      final user = (await rig.run(
        rig.extractor.refreshUser('user_1', 'old_name'),
      )).valueOrNull!;
      expect(user.remoteUserId, 'user_1');
      expect(rig.http.requests, hasLength(1));
    });

    test('refreshUser: not found by id, falls back to the old username; the '
        'same id is accepted, another id is TargetNotFound', () async {
      for (final (id, expected) in [('user_1', true), ('user_9', false)]) {
        var first = true;
        final rig = Rig(
          responder: (r) {
            if (friendlyName(r) == 'PolarisProfilePageContentQuery' && first) {
              first = false;
              return jsonReply(
                loadSynthetic('failures/graphql_user_null.json'),
              );
            }
            return graphqlResponder(
              posts: loadReal('profile', '007_graphql.json'),
              profile: loadReal('profile', '004_graphql.json'),
            )(r);
          },
        );
        final r = await rig.run(rig.extractor.refreshUser(id, 'kept_name'));
        expect(r.isOk, expected, reason: id);
        if (!expected) expect(r.failureOrNull, const TargetNotFound());
      }
    });

    test('verifySession: the viewer id equals ds_user_id', () async {
      final rig = _realRig();
      final user = (await rig.run(rig.extractor.verifySession())).valueOrNull!;
      expect(
        user.remoteUserId,
        'user_1',
        reason: 'the profile query of own id',
      );
      expect(variablesOf(rig.http.requests.single)['id'], viewerId);
    });

    test(
      'verifySession: another viewer id is SessionInvalid(loginRequired)',
      () async {
        final rig = _realRig(sessionUserId: 'ZZFAKE_other');
        final r = await rig.run(rig.extractor.verifySession());
        expect(
          r.failureOrNull,
          const SessionInvalid(SessionReason.loginRequired),
        );
      },
    );
  });

  group('AC1 stories', () {
    test('maps the real story reel', () async {
      final rig = _realRig();
      final stories = (await rig.run(rig.extractor.fetchStories(['user_1'])))
          .valueOrNull!;
      expect(stories.keys, ['user_1']);
      expect(stories['user_1']!.single.kind, ContentKind.story);
      expect(variablesOf(rig.http.requests.single)['reel_ids_arr'], ['user_1']);
    });

    test(
      'chunks of at most 20 users, sequentially, duplicates removed',
      () async {
        final rig = _realRig();
        final ids = [
          for (var i = 0; i < 45; i++) 'ZZFAKE_u$i',
          'ZZFAKE_u0',
          ' ',
        ];
        final r = await rig.run(rig.extractor.fetchStories(ids));
        expect(r.isOk, isTrue);
        final sizes = [
          for (final q in rig.http.requests)
            (variablesOf(q)['reel_ids_arr']! as List<Object?>).length,
        ];
        expect(sizes, [20, 20, 5]);
        expect(rig.http.maxInFlight, 1);
        expect(await rig.governor.remainingTokens(1), 3);
      },
    );

    test('an empty list makes no call', () async {
      final rig = _realRig();
      final r = await rig.run(rig.extractor.fetchStories([]));
      expect(r.valueOrNull, isEmpty);
      expect(rig.http.requests, isEmpty);
    });

    test('a failing chunk fails the call with that failure', () async {
      var n = 0;
      final rig = Rig(
        responder: (r) => ++n == 2
            ? const IgReply(status: 500)
            : jsonReply(loadReal('story', '003_graphql.json')),
      );
      final r = await rig.run(
        rig.extractor.fetchStories([for (var i = 0; i < 25; i++) 'ZZFAKE_u$i']),
      );
      expect(r.failureOrNull, const UnknownFailure(500, 'http_500'));
    });

    test(
      'latestStoryTime: latest_reel_media of the profile, one call',
      () async {
        final rig = _realRig();
        final t = (await rig.run(rig.extractor.latestStoryTime('user_1')))
            .valueOrNull;
        expect(t, _t(1795115924));
        expect(rig.http.requests, hasLength(1));
      },
    );

    test('latestStoryTime: null when the user has no story', () async {
      final body = jsonDecode(
        jsonEncode(loadReal('profile', '004_graphql.json')),
      ) as Map<String, Object?>;
      ((body['data']! as Map<String, Object?>)['user']!
              as Map<String, Object?>)['latest_reel_media'] =
          null;
      final rig = Rig(responder: graphqlResponder(profile: body));
      final r = await rig.run(rig.extractor.latestStoryTime('user_1'));
      expect(r, const Ok<DateTime?>(null));
    });

    test(
      'synthetic reel: live dropped, DASH-only kept as unsupported',
      () async {
        final rig = Rig(
          responder: graphqlResponder(
            stories: loadSynthetic('story_reel.json'),
          ),
        );
        final items = (await rig.run(
          rig.extractor.fetchStories(['ZZFAKE_user_a']),
        )).valueOrNull!['ZZFAKE_user_a']!;
        expect(
          items.map((c) => c.remoteId),
          isNot(contains('ZZFAKE_story_live')),
        );
        expect(
          items
              .firstWhere((c) => c.remoteId == 'ZZFAKE_story_dash')
              .extras[unsupportedStreamKey],
          [0],
        );
      },
    );
  });

  group('AC1/AC8 posts: watermark by taken_at, pinned order ignored', () {
    test(
      'real timeline: only posts newer than the watermark, newest first',
      () async {
        final rig = _realRig();
        final posts = (await rig.run(
          rig.extractor.fetchNewPosts('user_1', _t(1794700000)),
        )).valueOrNull!;
        expect(posts.map((p) => p.remoteId), [
          'media_135',
          'media_138',
          'media_143',
        ]);
        expect(posts.map((p) => p.postType), [
          PostType.photo,
          PostType.carousel,
          PostType.reel,
        ]);
        expect(posts.every((p) => !p.extras.containsKey('pinned')), isTrue);
      },
    );

    test('AC8 errors[] next to complete data is not SchemaChanged', () async {
      final rig = _realRig();
      final r = await rig.run(
        rig.extractor.fetchNewPosts('user_1', _t(1794700000)),
      );
      expect(r.isOk, isTrue);
      expect(
        (loadReal('profile', '007_graphql.json')! as Map)['errors'],
        isNotEmpty,
      );
    });

    test(
      'AC8 a low watermark includes the pinned and collab posts, marked',
      () async {
        final rig = _realRig();
        final posts = (await rig.run(
          rig.extractor.fetchNewPosts('user_1', _t(1700000000)),
        )).valueOrNull!;
        expect(posts, hasLength(12));
        final collab = posts.firstWhere((p) => p.remoteId == 'media_125');
        expect(collab.extras, {'pinned': true, 'collab': true});
        expect(
          posts.first.remoteId,
          'media_135',
          reason: 'newest first, not pinned first',
        );
      },
    );

    test(
      'the watermark is exclusive and nothing newer gives an empty list',
      () async {
        final rig = _realRig();
        final posts = (await rig.run(
          rig.extractor.fetchNewPosts('user_1', _t(1795115861)),
        )).valueOrNull!;
        expect(posts, isEmpty);
      },
    );

    test(
      'latestPostTime is the largest taken_at, not edges[0] (pinned)',
      () async {
        final rig = _realRig();
        final t = (await rig.run(rig.extractor.latestPostTime('user_1')))
            .valueOrNull;
        expect(t, _t(1795115861));
        expect(t, isNot(_t(1781876964)), reason: 'that is the pinned edges[0]');
      },
    );

    test('latestPostTime: a freshly pinned post counts by its time', () async {
      final rig = _syntheticPostsRig();
      final t = (await rig.run(rig.extractor.latestPostTime('ZZFAKE_user_a')))
          .valueOrNull;
      expect(t, _t(1800000500));
    });

    test('latestPostTime: null when the user has no posts', () async {
      final rig = Rig(
        responder: graphqlResponder(
          profile: loadReal('profile', '004_graphql.json'),
          posts: {
            'data': {
              'xdt_api__v1__feed__user_timeline_graphql_connection': {
                'edges': <Object?>[],
              },
            },
          },
        ),
      );
      final r = await rig.run(rig.extractor.latestPostTime('ZZFAKE_u'));
      expect(r, const Ok<DateTime?>(null));
    });

    test('synthetic: foreign posts and duplicates are dropped, collab counts, '
        'an old malformed post is never mapped', () async {
      final rig = _syntheticPostsRig();
      final posts = (await rig.run(
        rig.extractor.fetchNewPosts('ZZFAKE_user_a', _t(1799999000)),
      )).valueOrNull!;
      expect(posts.map((p) => p.remoteId), [
        'ZZFAKE_post_pinned_fresh',
        'ZZFAKE_post_new_photo',
        'ZZFAKE_post_collab',
        'ZZFAKE_post_carousel',
        'ZZFAKE_post_reel',
        'ZZFAKE_post_video',
      ]);
    });

    test('a malformed new post is SchemaChanged', () async {
      final rig = _syntheticPostsRig();
      final r = await rig.run(
        rig.extractor.fetchNewPosts('ZZFAKE_user_a', _t(1600000000)),
      );
      expect(
        r.failureOrNull,
        const SchemaChanged(
          'response.data.xdt_api__v1__feed__user_timeline_graphql_connection.edges[5].node.image_versions2.candidates',
        ),
      );
    });

    test(
      'the username is cached: the first posts call looks it up once',
      () async {
        final rig = _realRig();
        await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1794700000)));
        await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1794700000)));
        final names = rig.http.requests.map(friendlyName).toList();
        expect(names, [
          'PolarisProfilePageContentQuery',
          'PolarisProfilePostsQuery',
          'PolarisProfilePostsQuery',
        ]);
      },
    );
  });

  group('governor and session (AC1, AC6)', () {
    test('every call is one api token, never a page-load weight; calls run '
        'one at a time', () async {
      final rig = _realRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      await rig.run(rig.extractor.latestPostTime('user_1'));
      expect(
        await rig.governor.remainingTokens(1),
        6 - rig.http.requests.length,
      );
      expect(rig.governorLogs, everyElement(contains('cost=api')));
      expect(
        rig.governorLogs.where((l) => l.contains('outcome=ok')),
        hasLength(rig.http.requests.length),
      );
      expect(rig.http.maxInFlight, 1);
    });

    test(
      'the 7th call in an hour waits for a token instead of failing',
      () async {
        final rig = _realRig();
        for (var i = 0; i < 7; i++) {
          await rig.run(rig.extractor.fetchStories(['user_1']));
        }
        expect(rig.time.clock.now().isAfter(DateTime.utc(2026)), isTrue);
      },
    );

    test(
      'a 429 pauses the account: the next call is refused without a request',
      () async {
        final rig = Rig(
          responder: (_) => jsonReply(
            {'status': 'fail'},
            status: 429,
            retryAfter: const Duration(minutes: 5),
          ),
        );
        final first = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(first.failureOrNull, const RateLimited(Duration(minutes: 5)));
        final second = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(second.failureOrNull, isA<RateLimited>());
        expect(rig.http.requests, hasLength(1));
        expect(await rig.governor.isPaused(1), isTrue);
      },
    );

    test(
      'AC6 session headers: cookies, WebView user agent, csrf, referer, app id',
      () async {
        final rig = _realRig();
        await rig.run(rig.extractor.fetchStories(['user_1']));
        final h = rig.http.requests.single.headers;
        expect(h['Cookie'], contains('sessionid=$fakeSessionId'));
        expect(h['Cookie'], contains('ds_user_id=$viewerId'));
        expect(h['User-Agent'], fakeAgent);
        expect(h['X-CSRFToken'], fakeCsrf);
        expect(h['Referer'], 'https://www.instagram.com/');
        expect(h['X-IG-App-ID'], fakeAppId);
      },
    );

    test('GraphQL request: POST /api/graphql, form with the runtime doc_id and tokens', () async {
      final rig = _realRig();
      await rig.run(rig.extractor.fetchStories(['user_1']));
      final r = rig.http.requests.single;
      expect(r.method, IgMethod.post);
      expect(r.uri.host, 'www.instagram.com');
      expect(r.uri.path, '/api/graphql');
      expect(r.form!['doc_id'], 'ZZFAKE_doc_stories');
      expect(
        r.form!['fb_api_req_friendly_name'],
        'PolarisStoriesV3ReelPageStandaloneQuery',
      );
      expect(r.form!['fb_dtsg'], fakeDtsg);
    });

    test('no session: SessionInvalid(loginRequired), nothing sent', () async {
      final rig = Rig(
        withSession: false,
        responder: (_) => throw StateError('no call expected'),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(
        r.failureOrNull,
        const SessionInvalid(SessionReason.loginRequired),
      );
      expect(rig.http.requests, isEmpty);
    });

    test(
      'a doc_id that cannot be found is SchemaChanged (-> page mode)',
      () async {
        final rig = Rig(
          transport: GraphqlTransport(
            docIds: FakeDocIds(missing: {GraphqlQuery.stories}),
            tokens: FakeTokens(),
          ),
          responder: (_) => throw StateError('no call expected'),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(
          r.failureOrNull,
          const SchemaChanged('doc_id:PolarisStoriesV3ReelPageStandaloneQuery'),
        );
        expect(rig.http.requests, isEmpty);
      },
    );

    test('missing page tokens are SchemaChanged', () async {
      final rig = Rig(
        transport: GraphqlTransport(
          docIds: FakeDocIds(),
          tokens: FakeTokens(available: false),
        ),
        responder: (_) => throw StateError('no call expected'),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, const SchemaChanged('page_tokens'));
    });
  });

  group('logging: nothing sensitive', () {
    test('success and failure paths never log cookies, tokens, doc_ids, URLs or names', () async {
      final rig = _realRig();
      await rig.run(rig.extractor.resolveUser('ZZFake_Name'));
      await rig.run(rig.extractor.fetchStories(['user_1']));
      await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1700000000)));
      rig.http.responder = (_) => jsonReply(
        loadSynthetic('failures/checkpoint_required.json'),
        status: 400,
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      rig.http.responder = (_) => jsonReply({'data': <String, Object?>{}});
      await rig.run(rig.extractor.fetchStories(['user_1']));

      final logs = rig.allLogs;
      expect(rig.log.entries, isNotEmpty);
      expect(rig.governorLogs, isNotEmpty);
      for (final secret in [
        fakeSessionId,
        fakeCsrf,
        fakeAgent,
        fakeDtsg,
        fakeLsd,
        'ZZFAKE_doc',
        'ZZFake_Name',
        'Cookie',
        'http',
        'instagram.com',
        'cdn.example',
        'caption',
      ]) {
        expect(logs, isNot(contains(secret)), reason: secret);
      }
      expect(
        logs,
        contains('op=fetchStories via=graphql failure=SessionInvalid'),
      );
      expect(
        logs,
        contains(
          'schema_changed'.isEmpty
              ? ''
              : 'failure=SchemaChanged where=response.data',
        ),
      );
    });
  });
}
