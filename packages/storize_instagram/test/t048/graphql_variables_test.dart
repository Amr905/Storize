// T-048: GraphQL requests built from the discovered argument names and
// provider values. Synthetic values only; no network.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/page/page.dart';

import '../direct/support.dart';

const _pv = '__relay_internal__pv__';
const _postsArgs = ['after', 'before', 'data', 'first', 'last', 'username'];
const _pagingArgs = [
  'after',
  'before',
  'data',
  'first',
  'include_multi_captions',
  'last',
  'username',
];
const _postsProviders = <String, Object>{
  '${_pv}PolarisMultiCaptionCarouselEnabled': true,
  '${_pv}PolarisProductTagIndicatorEnabled': false,
  '${_pv}PolarisShortDramaEnabled': true,
};
const _storiesProviders = <String, Object>{
  '${_pv}PolarisCommunityNoteStoriesLabelEnabled': true,
};

PageDiscovery _discovery({
  List<String> postsArgs = _postsArgs,
  bool paging = true,
  List<String> pagingArgs = _pagingArgs,
  List<String> trayArgs = const [
    'after',
    'before',
    'first',
    'last',
    'max_highlights_to_fetch_on_pagination',
    'user_id',
  ],
}) {
  var n = 10000;
  DiscoveredOp op(
    GraphqlQuery q,
    List<String> args, [
    Map<String, Object> provided = const {},
  ]) => DiscoveredOp(
    name: q.friendlyName,
    docId: '${n++}',
    provided: provided,
    args: args,
  );
  final d = PageDiscovery()
    ..recordDiscovery(
      [
        op(GraphqlQuery.posts, postsArgs, _postsProviders),
        if (paging) op(GraphqlQuery.postsPaging, pagingArgs, _postsProviders),
        op(
          GraphqlQuery.stories,
          ['is_highlight', 'media_id', 'reel_ids_arr'],
          _storiesProviders,
        ),
        op(GraphqlQuery.highlights, trayArgs),
        op(GraphqlQuery.profile, ['enable_integrity_filters', 'id']),
      ],
      {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
    );
  return d;
}

Rig _rig(PageDiscovery d, {UsernameCache? usernames}) => Rig(
  responder: (_) => jsonReply({'data': <String, Object?>{}}),
  transport: GraphqlTransport(docIds: d, tokens: d),
  usernames: usernames,
);

UsernameCache _names() {
  final cache = InMemoryUsernameCache();
  unawaited(cache.remember('user_1', 'zzfake_user'));
  return cache;
}

DateTime _t(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

IgRequest _only(Rig rig, String name) =>
    rig.http.requests.singleWhere((r) => friendlyName(r) == name);

void main() {
  group('posts', () {
    test('first page: data + username + providers, nothing else', () async {
      final rig = _rig(_discovery(), usernames: _names());
      await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1)));
      final v = variablesOf(_only(rig, 'PolarisProfilePostsQuery'));
      expect(v, {
        'username': 'zzfake_user',
        'data': {
          'count': 12,
          'include_reel_media_seen_timestamp': true,
          'include_relationship_info': true,
          'latest_besties_reel_media': true,
          'latest_reel_media': true,
        },
        ..._postsProviders,
      });
    });

    test('only arguments in the discovered list are sent', () async {
      final rig = _rig(
        _discovery(postsArgs: ['username']),
        usernames: _names(),
      );
      await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1)));
      expect(variablesOf(_only(rig, 'PolarisProfilePostsQuery')), {
        'username': 'zzfake_user',
        ..._postsProviders,
      });
    });

    test('the username comes from the target store, not the user id', () async {
      final rig = _rig(_discovery(), usernames: _names());
      await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1)));
      final text = rig.http.requests.single.form!['variables']!;
      expect(variablesOf(rig.http.requests.single)['username'], 'zzfake_user');
      expect(text, isNot(contains('user_1')));
    });

    test('paging: the _connection query with after, first, username', () async {
      final rig = _rig(_discovery(), usernames: _names());
      await rig.run(rig.extractor.fetchPostPage('user_1', cursor: _cursor()));
      final req = rig.http.requests.single;
      expect(
        friendlyName(req),
        'PolarisProfilePostsTabContentQuery_connection',
      );
      expect(variablesOf(req), {
        'after': 'ZZFAKE_cursor',
        'first': 12,
        'username': 'zzfake_user',
        'include_multi_captions': true,
        ..._postsProviders,
      });
    });

    test(
      'paging: include_multi_captions only when it is an argument',
      () async {
        final rig = _rig(
          _discovery(pagingArgs: ['after', 'first', 'username']),
          usernames: _names(),
        );
        await rig.run(rig.extractor.fetchPostPage('user_1', cursor: _cursor()));
        expect(
          variablesOf(rig.http.requests.single).keys,
          isNot(contains('include_multi_captions')),
        );
      },
    );

    test('paging without a _connection doc_id uses the posts query', () async {
      final rig = _rig(_discovery(paging: false), usernames: _names());
      await rig.run(rig.extractor.fetchPostPage('user_1', cursor: _cursor()));
      final req = rig.http.requests.single;
      expect(friendlyName(req), 'PolarisProfilePostsQuery');
      final v = variablesOf(req);
      expect(v['after'], 'ZZFAKE_cursor');
      expect(v['first'], 12);
      expect(v['username'], 'zzfake_user');
      expect(v.keys, containsAll(_postsProviders.keys));
    });

    test(
      'without a discovered shape the candidates are sent as before',
      () async {
        final d = PageDiscovery()
          ..record(
            friendlyName: 'PolarisProfilePostsQuery',
            docId: '12345678',
            tokens: {'fb_dtsg': fakeDtsg, 'lsd': fakeLsd},
          );
        final rig = _rig(d, usernames: _names());
        await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1)));
        expect(variablesOf(rig.http.requests.single).keys, [
          'username',
          'data',
        ]);
      },
    );
  });

  group('stories, highlights, tray, profile', () {
    test('stories: reel_ids_arr and is_highlight=false', () async {
      final rig = _rig(_discovery());
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(variablesOf(rig.http.requests.single), {
        'reel_ids_arr': ['user_1'],
        'is_highlight': false,
        ..._storiesProviders,
      });
    });

    test('highlight items: highlight:<id> and is_highlight=true', () async {
      final rig = _rig(_discovery());
      await rig.run(
        rig.extractor.fetchHighlightItems(['ZZFAKE_a', 'ZZFAKE_b']),
      );
      expect(
        friendlyName(rig.http.requests.single),
        'PolarisStoriesV3ReelPageStandaloneQuery',
      );
      expect(variablesOf(rig.http.requests.single), {
        'reel_ids_arr': ['highlight:ZZFAKE_a', 'highlight:ZZFAKE_b'],
        'is_highlight': true,
        ..._storiesProviders,
      });
    });

    test('tray: user_id and first when both are arguments', () async {
      final rig = _rig(_discovery());
      await rig.run(rig.extractor.fetchHighlights('user_1'));
      expect(variablesOf(rig.http.requests.single), {
        'user_id': 'user_1',
        'first': 30,
      });
    });

    test('tray: first is dropped when it is not an argument', () async {
      final rig = _rig(_discovery(trayArgs: ['user_id']));
      await rig.run(rig.extractor.fetchHighlights('user_1'));
      expect(variablesOf(rig.http.requests.single), {'user_id': 'user_1'});
    });

    test('profile: id and enable_integrity_filters', () async {
      final rig = _rig(_discovery());
      await rig.run(rig.extractor.latestStoryTime('user_1'));
      expect(variablesOf(rig.http.requests.single), {
        'id': 'user_1',
        'enable_integrity_filters': true,
      });
    });
  });

  group('form fields and headers', () {
    test('the web app form fields, av from the session, lsd header', () async {
      final rig = _rig(_discovery());
      await rig.run(rig.extractor.fetchStories(['user_1']));
      final req = rig.http.requests.single;
      final f = req.form!;
      expect(req.uri.path, '/api/graphql');
      expect(f['av'], viewerId);
      expect(f['__user'], '0');
      expect(f['__a'], '1');
      expect(f['__comet_req'], '7');
      expect(f['fb_api_caller_class'], 'RelayModern');
      expect(f['server_timestamps'], 'true');
      expect(f['fb_dtsg'], fakeDtsg);
      expect(f['lsd'], fakeLsd);
      expect(
        f['jazoest'],
        '2${fakeDtsg.codeUnits.fold<int>(0, (a, b) => a + b)}',
      );
      expect(f['fb_api_req_friendly_name'], friendlyNameOf(f));
      expect(f['doc_id'], matches(RegExp(r'^\d+$')));
      jsonDecode(f['variables']!);
      expect(req.headers['X-FB-Friendly-Name'], f['fb_api_req_friendly_name']);
      expect(req.headers['X-FB-LSD'], fakeLsd);
      expect(req.headers['X-CSRFToken'], fakeCsrf);
      expect(req.headers['X-IG-App-ID'], fakeAppId);
    });

    test('jazoest follows the web formula', () {
      expect(GraphqlTransport.jazoestOf('ab'), '2${97 + 98}');
    });

    test('buildVariables: exact filter plus providers; null dropped', () {
      const shape = QueryShape(
        provided: {'${_pv}A': true},
        args: ['a', 'b'],
      );
      expect(
        GraphqlTransport.buildVariables({'a': 1, 'b': null, 'c': 3}, shape),
        {'a': 1, '${_pv}A': true},
      );
      expect(
        GraphqlTransport.buildVariables({'a': 1, 'c': 3}, null),
        {'a': 1, 'c': 3},
      );
    });
  });

  group('response shapes', () {
    const mapper = EnvelopeMapper();

    test('stories: xdt_api__v1__feed__reels_media and bare reels_media', () {
      final reel = loadSynthetic('story_reel.json')! as Map<String, Object?>;
      final root =
          (reel['data']! as Map)['xdt_api__v1__feed__reels_media']! as Map;
      final a = mapper.graphqlStories(nodeOf(reel));
      final bare = mapper.graphqlStories(
        nodeOf({
          'data': {'reels_media': root['reels_media']},
        }),
      );
      final list = mapper.graphqlStories(
        nodeOf({
          'data': {'xdt_api__v1__feed__reels_media': root['reels_media']},
        }),
      );
      expect(a, isNotEmpty);
      expect(bare.keys, a.keys);
      expect(list.keys, a.keys);
    });

    test('stories: neither shape is a SchemaException with a path', () {
      expect(
        () => mapper.graphqlStories(nodeOf({'data': <String, Object?>{}})),
        throwsA(isA<SchemaException>()),
      );
    });

    test('tray: a connection under another highlights key is read', () {
      final tray = loadSynthetic('highlights_tray.json')! as Map;
      final inner = (tray['data']! as Map)['highlights'];
      final moved = mapper.graphqlHighlights(
        nodeOf({
          'data': {'xdt_api__v1__highlights__tray_connection': inner},
        }),
      );
      expect(moved.map((h) => h.id), ['ZZFAKE_hl_1', 'ZZFAKE_hl_2']);
    });
  });

  group('failure diagnostics', () {
    test(
      'a failing GraphQL call logs query, status and key names only',
      () async {
        final d = _discovery();
        final rig = Rig(
          responder: (_) => jsonReply({
            'status': 'fail',
            'message': 'ZZFAKE_secret_message',
          }, status: 404),
          transport: GraphqlTransport(docIds: d, tokens: d),
          usernames: _names(),
        );
        await rig.run(rig.extractor.fetchNewPosts('user_1', _t(1)));
        final logs = rig.allLogs;
        expect(logs, contains('query=PolarisProfilePostsQuery'));
        expect(logs, contains('status=404'));
        expect(logs, contains('keys=[status,message]'));
        for (final secret in [
          'ZZFAKE_secret_message',
          fakeDtsg,
          fakeLsd,
          fakeCsrf,
          fakeSessionId,
          'zzfake_user',
        ]) {
          expect(logs, isNot(contains(secret)));
        }
      },
    );
  });
}

String friendlyNameOf(Map<String, String> f) => f['fb_api_req_friendly_name']!;

String _cursor() => PostCursor(
  igCursor: 'ZZFAKE_cursor',
  takenAt: DateTime.utc(2026),
).encode();
