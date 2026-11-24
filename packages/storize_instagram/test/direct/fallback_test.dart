// T-044: GraphQL when it can, REST otherwise, per call; and the REST ops for
// paging, highlights and highlight items. Synthetic ZZFAKE_ bodies.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/platform/transport_selection.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

const _user = 'ZZFAKE_user_a';

Object? _item(String pk, int takenAt) => {
  'pk': pk,
  'code': 'ZZFAKE_c_$pk',
  'media_type': 1,
  'taken_at': takenAt,
  'user': {'pk': _user},
  'owner_id': {'pk': _user},
  'timeline_pinned_user_ids': <Object?>[],
  'coauthor_producers': <Object?>[],
  'image_versions2': {
    'candidates': [
      {
        'url': 'https://cdn.example.test/ZZFAKE_$pk.jpg',
        'width': 1,
        'height': 1,
      },
    ],
  },
};

Object? _feed({required bool more, String? next, List<Object?>? items}) => {
  'items': items ?? [_item('ZZFAKE_p1', 1800000300)],
  'more_available': more,
  'next_max_id': ?next,
  'status': 'ok',
};

Object? _storyItem(String pk, int t) => {
  'pk': pk,
  'id': '${pk}_$_user',
  'media_type': 1,
  'product_type': 'story',
  'taken_at': t,
  'user': {'pk': _user},
  'image_versions2': {
    'candidates': [
      {
        'url': 'https://cdn.example.test/ZZFAKE_$pk.jpg',
        'width': 1,
        'height': 1,
      },
    ],
  },
};

Object? _tray() => {
  'tray': [
    {
      'id': 'highlight:ZZFAKE_hl_1',
      'title': 'ZZFAKE Title One',
      'latest_reel_media': 1800000200,
      'cover_media': {
        'cropped_image_version': {
          'url': 'https://cdn.example.test/ZZFAKE_cv.jpg',
        },
      },
    },
    {'id': 'ZZFAKE_hl_2', 'title': 'ZZFAKE Two', 'cover_media': null},
  ],
  'status': 'ok',
};

Object? _hlReels() => {
  'reels': {
    'highlight:ZZFAKE_hl_1': {
      'id': 'highlight:ZZFAKE_hl_1',
      'title': 'ZZFAKE Title One',
      'items': [
        _storyItem('ZZFAKE_h2', 1800000200),
        _storyItem('ZZFAKE_h1', 1800000100),
      ],
    },
    'highlight:ZZFAKE_hl_9': {
      'id': 'highlight:ZZFAKE_hl_9',
      'items': [_storyItem('ZZFAKE_x', 1800000000)],
    },
  },
  'status': 'ok',
};

Object? _graphqlStories() => {
  'data': {
    'xdt_api__v1__feed__reels_media': {'reels_media': <Object?>[]},
  },
};

IgReply _rest(IgRequest r) {
  final p = r.uri.path;
  if (p.endsWith('/highlights_tray/')) return jsonReply(_tray());
  if (p == '/api/v1/feed/reels_media/') {
    final ids = r.uri.queryParametersAll['reel_ids']!;
    return ids.first.startsWith('highlight:')
        ? jsonReply(_hlReels())
        : jsonReply(loadSynthetic('rest_reels_media.json'));
  }
  if (p.startsWith('/api/v1/feed/user/')) {
    return r.uri.queryParameters['max_id'] == null
        ? jsonReply(_feed(more: true, next: 'ZZFAKE_cur1'))
        : jsonReply(
            _feed(
              more: false,
              items: [_item('ZZFAKE_p2', 1800000200)],
            ),
          );
  }
  return const IgReply(status: 404);
}

Rig _fallbackRig({
  bool docId = true,
  bool tokens = true,
  Responder? responder,
}) {
  return Rig(
    transport: FallbackTransport(
      docIds: FakeDocIds(
        missing: docId ? const {} : GraphqlQuery.values.toSet(),
      ),
      tokens: FakeTokens(available: tokens),
    ),
    responder: responder ?? _rest,
  );
}

bool _isGraphql(IgRequest r) => r.uri.path == '/api/graphql';

void main() {
  group('fallback order', () {
    test(
      'no doc_id: REST only, one governed call, no GraphQL request',
      () async {
        final rig = _fallbackRig(docId: false);
        final r = await rig.run(rig.extractor.fetchStories([_user]));
        expect(r.valueOrNull![_user]!.single.remoteId, 'ZZFAKE_story_rest');
        expect(rig.http.requests, hasLength(1));
        expect(rig.http.requests.single.uri.path, '/api/v1/feed/reels_media/');
      },
    );

    test('no page tokens: REST only', () async {
      final rig = _fallbackRig(tokens: false);
      await rig.run(rig.extractor.fetchStories([_user]));
      expect(rig.http.requests.where(_isGraphql), isEmpty);
      expect(rig.http.requests, hasLength(1));
    });

    test('GraphQL answers when ready: no REST request', () async {
      final rig = _fallbackRig(
        responder: (r) =>
            _isGraphql(r) ? jsonReply(_graphqlStories()) : _rest(r),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.isOk, isTrue);
      expect(rig.http.requests.single.uri.path, '/api/graphql');
    });

    test('GraphQL SchemaChanged falls to REST once', () async {
      final rig = _fallbackRig(
        responder: (r) =>
            _isGraphql(r) ? jsonReply({'data': <String, Object?>{}}) : _rest(r),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.valueOrNull![_user], isNotNull);
      expect(rig.http.requests.map((r) => r.uri.path), [
        '/api/graphql',
        '/api/v1/feed/reels_media/',
      ]);
    });

    test('REST SchemaChanged is returned (page mode may follow)', () async {
      final rig = _fallbackRig(
        docId: false,
        responder: (_) => jsonReply({'status': 'ok'}),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.failureOrNull, isA<SchemaChanged>());
      expect(rig.http.requests, hasLength(1));
    });

    test('REST UnknownFailure is returned', () async {
      final rig = _fallbackRig(
        docId: false,
        responder: (_) => const IgReply(status: 500),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.failureOrNull, isA<UnknownFailure>());
    });

    test('RateLimited from GraphQL is not retried on REST', () async {
      final rig = _fallbackRig(
        responder: (r) => _isGraphql(r) ? const IgReply(status: 429) : _rest(r),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.failureOrNull, isA<RateLimited>());
      expect(rig.http.requests, hasLength(1));
      expect(_isGraphql(rig.http.requests.single), isTrue);
    });

    test('session failure from GraphQL is not retried on REST', () async {
      final rig = _fallbackRig(
        responder: (r) => const IgReply(status: 401),
      );
      final r = await rig.run(rig.extractor.fetchStories([_user]));
      expect(r.failureOrNull, isA<SessionInvalid>());
      expect(rig.http.requests, hasLength(1));
    });

    test('selectTransport: fallback by default, REST when proven', () {
      final docIds = FakeDocIds();
      final tokens = FakeTokens();
      expect(
        selectTransport(docIds: docIds, tokens: tokens),
        isA<FallbackTransport>(),
      );
      expect(
        selectTransport(
          docIds: docIds,
          tokens: tokens,
          preference: TransportPreference.restWhenProven,
        ),
        isA<FallbackTransport>(),
      );
    });
  });

  group('REST ops', () {
    test('timeline page 1 then page 2: next_max_id, then the end', () async {
      final rig = _fallbackRig(docId: false);
      final first = (await rig.run(rig.extractor.fetchPostPage(_user)))
          .valueOrNull!;
      expect(first.items.single.remoteId, 'ZZFAKE_p1');
      expect(first.nextCursor, isNotNull);
      final r1 = rig.http.requests.single;
      expect(r1.uri.path, '/api/v1/feed/user/$_user/');
      expect(r1.uri.queryParameters, {'count': '12'});

      final second = (await rig.run(
        rig.extractor.fetchPostPage(_user, cursor: first.nextCursor),
      )).valueOrNull!;
      expect(second.items.single.remoteId, 'ZZFAKE_p2');
      expect(second.nextCursor, isNull);
      expect(
        rig.http.requests.last.uri.queryParameters['max_id'],
        'ZZFAKE_cur1',
      );
    });

    test('highlights tray: ids normalized, order kept', () async {
      final rig = _fallbackRig(docId: false);
      final tray = (await rig.run(rig.extractor.fetchHighlights(_user)))
          .valueOrNull!;
      expect(tray.map((h) => h.id), ['ZZFAKE_hl_1', 'ZZFAKE_hl_2']);
      expect(tray[0].title, 'ZZFAKE Title One');
      expect(tray[0].coverUrl, contains('ZZFAKE_cv'));
      expect(tray[0].latestItemAt!.millisecondsSinceEpoch, 1800000200 * 1000);
      expect(
        rig.http.requests.single.uri.path,
        '/api/v1/highlights/$_user/highlights_tray/',
      );
    });

    test(
      'highlight items: prefixed reel_ids, kind, extras, oldest first',
      () async {
        final rig = _fallbackRig(docId: false);
        final out = (await rig.run(
          rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1']),
        )).valueOrNull!;
        expect(out.keys, ['ZZFAKE_hl_1']);
        final items = out['ZZFAKE_hl_1']!;
        expect(items.map((c) => c.remoteId), ['ZZFAKE_h1', 'ZZFAKE_h2']);
        for (final c in items) {
          expect(c.kind, ContentKind.highlight);
          expect(c.extras[HighlightExtras.id], 'ZZFAKE_hl_1');
          expect(c.extras[HighlightExtras.title], 'ZZFAKE Title One');
          expect(c.extras[HighlightExtras.order], 0);
        }
        expect(rig.http.requests.single.uri.queryParametersAll['reel_ids'], [
          'highlight:ZZFAKE_hl_1',
        ]);
      },
    );

    test('highlight items: at most 20 ids per request', () async {
      final rig = _fallbackRig(docId: false);
      final ids = [for (var i = 0; i < 45; i++) 'ZZFAKE_hl_$i'];
      await rig.run(rig.extractor.fetchHighlightItems(ids));
      expect(
        [
          for (final r in rig.http.requests)
            r.uri.queryParametersAll['reel_ids']!.length,
        ],
        [20, 20, 5],
      );
    });

    test('REST requests carry the session headers of verifySession', () async {
      final rig = _fallbackRig(docId: false);
      await rig.run(rig.extractor.fetchHighlights(_user));
      final h = rig.http.requests.single.headers;
      expect(h['X-IG-App-ID'], fakeAppId);
      expect(h['X-Requested-With'], 'XMLHttpRequest');
    });
  });

  group('guardrails', () {
    test('no seen endpoint is requested by any op', () async {
      final rig = _fallbackRig(docId: false);
      await rig.run(rig.extractor.fetchStories([_user]));
      await rig.run(rig.extractor.fetchPostPage(_user));
      await rig.run(rig.extractor.fetchHighlights(_user));
      await rig.run(rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1']));
      expect(rig.http.requests, isNotEmpty);
      for (final r in rig.http.requests) {
        expect(r.uri.toString(), isNot(contains('seen')));
        expect(r.method, IgMethod.get);
      }
    });

    test('logs hold no ids, usernames, cursors, URLs or secrets', () async {
      final rig = _fallbackRig(docId: false);
      final first = (await rig.run(rig.extractor.fetchPostPage(_user)))
          .valueOrNull!;
      await rig.run(
        rig.extractor.fetchPostPage(_user, cursor: first.nextCursor),
      );
      await rig.run(rig.extractor.fetchHighlights(_user));
      await rig.run(rig.extractor.fetchStories([_user]));
      final logs = rig.allLogs;
      expect(logs, contains('op='));
      for (final secret in [
        'ZZFAKE',
        'cdn.example.test',
        'http',
        fakeSessionId,
        fakeCsrf,
      ]) {
        expect(logs, isNot(contains(secret)));
      }
    });
  });
}
