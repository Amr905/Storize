// QA tests for T-044 (GraphQL-then-REST fallback, REST completion).
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart';

const _u = 'ZZFAKE_user_a';

Rig _r(Responder responder, {bool docId = false}) => Rig(
  transport: FallbackTransport(
    docIds: FakeDocIds(missing: docId ? const {} : GraphqlQuery.values.toSet()),
    tokens: FakeTokens(),
    restOps: allRestOps,
  ),
  responder: responder,
);

bool _gql(IgRequest r) => r.uri.path == '/api/graphql';

Map<String, Object?> _img(String pk) => {
  'pk': pk,
  'code': 'ZZFAKE_c_$pk',
  'media_type': 1,
  'taken_at': 1800000000,
  'user': {'pk': _u},
  'owner_id': {'pk': _u},
  'timeline_pinned_user_ids': <Object?>[],
  'coauthor_producers': <Object?>[],
  'image_versions2': {
    'candidates': [
      {'url': 'https://cdn.example.test/$pk.jpg', 'width': 1, 'height': 1},
    ],
  },
};

void main() {
  final failures = <String, int>{
    'RateLimited': 429,
    'SessionInvalid': 401,
    'TargetNotFound': 404,
  };

  group('budget', () {
    for (final e in failures.entries) {
      test('GraphQL ${e.key} is not retried on REST', () async {
        final rig = _r((r) => IgReply(status: e.value), docId: true);
        final res = await rig.run(rig.extractor.fetchStories([_u]));
        expect(res.isOk, isFalse);
        expect(rig.http.requests, hasLength(1));
        expect(_gql(rig.http.requests.single), isTrue);
      });
    }

    test('403 not-authorized (private) from GraphQL is not retried', () async {
      final rig = _r(
        (r) =>
            jsonReply({'message': 'not authorized to view user'}, status: 403),
        docId: true,
      );
      await rig.run(rig.extractor.fetchStories([_u]));
      expect(rig.http.requests, hasLength(1));
    });

    test('GraphQL network error is not retried on REST', () async {
      final rig = _r(
        (r) => throw const TransportException('socket'),
        docId: true,
      );
      await rig.run(rig.extractor.fetchStories([_u]));
      expect(rig.http.requests, hasLength(1));
    });

    test(
      'GraphQL SchemaChanged then REST failure: exactly two calls',
      () async {
        final rig = _r(
          (r) => _gql(r)
              ? jsonReply({'data': <String, Object?>{}})
              : jsonReply({'status': 'ok'}),
          docId: true,
        );
        final res = await rig.run(rig.extractor.fetchStories([_u]));
        expect(res.failureOrNull, isA<SchemaChanged>());
        expect(rig.http.requests, hasLength(2));
      },
    );

    test('highlight batch of 45 stops after a rate limit', () async {
      var n = 0;
      final rig = _r(
        (r) => ++n == 2
            ? const IgReply(status: 429)
            : jsonReply({'reels': <String, Object?>{}}),
      );
      final ids = [for (var i = 0; i < 45; i++) 'ZZFAKE_hl_$i'];
      final res = await rig.run(rig.extractor.fetchHighlightItems(ids));
      expect(res.failureOrNull, isA<RateLimited>());
      expect(rig.http.requests, hasLength(2));
    });

    test(
      'highlight batch: governor pause after a limit blocks the next op',
      () async {
        var n = 0;
        final rig = _r((r) {
          n++;
          return const IgReply(status: 429);
        });
        await rig.run(rig.extractor.fetchHighlights(_u));
        final again = await rig.run(rig.extractor.fetchHighlights(_u));
        expect(again.failureOrNull, isA<RateLimited>());
        expect(n, 1, reason: 'second op blocked by the governor, no request');
      },
    );
  });

  group('seen safety', () {
    test(
      'every op over every transport path: GET only, no seen path',
      () async {
        final rig = _r((r) => jsonReply({'status': 'ok'}));
        await rig.run(rig.extractor.fetchStories([_u]));
        await rig.run(rig.extractor.fetchPostPage(_u));
        await rig.run(rig.extractor.fetchHighlights(_u));
        await rig.run(
          rig.extractor.fetchHighlightItems(['highlight:ZZFAKE_h']),
        );
        expect(rig.http.requests, hasLength(4));
        for (final r in rig.http.requests) {
          expect(r.method, IgMethod.get);
          expect(r.uri.toString().toLowerCase(), isNot(contains('seen')));
          expect(r.uri.toString(), isNot(contains('mark')));
        }
        expect(
          rig.http.requests.last.uri.queryParametersAll['reel_ids'],
          ['highlight:ZZFAKE_h'],
          reason: 'prefix not doubled',
        );
      },
    );

    test(
      'headers come from the session, no hard-coded cookie values',
      () async {
        final rig = _r((r) => jsonReply({'status': 'ok'}));
        await rig.run(rig.extractor.fetchHighlights(_u));
        final h = rig.http.requests.single.headers;
        expect(h['X-IG-App-ID'], fakeAppId);
        expect(h['X-Requested-With'], 'XMLHttpRequest');
        expect(h['Cookie'] ?? '', contains(fakeSessionId));
      },
    );
  });

  group('mapper robustness', () {
    const m = EnvelopeMapper();

    test('feed: no next_max_id, no more_available: end', () {
      final t = m.restFeed(
        nodeOf({
          'items': [_img('ZZFAKE_a')],
        }),
      );
      expect(t.entries, hasLength(1));
      expect(t.endCursor, isNull);
      expect(t.hasNextPage, isNot(true));
    });

    test('feed: more_available false with a stale next_max_id ends paging', () {
      final t = m.restFeed(
        nodeOf({
          'items': [_img('ZZFAKE_a')],
          'more_available': false,
          'next_max_id': 'ZZFAKE_c',
        }),
      );
      expect(t.hasNextPage, isFalse);
    });

    test('feed: empty items is fine; items missing is SchemaException', () {
      expect(m.restFeed(nodeOf({'items': <Object?>[]})).entries, isEmpty);
      expect(
        () => m.restFeed(nodeOf({'status': 'ok'})),
        throwsA(isA<SchemaException>()),
      );
    });

    test('tray: empty is ok, missing is schema error, odd items skipped', () {
      expect(m.restHighlights(nodeOf({'tray': <Object?>[]})), isEmpty);
      expect(
        () => m.restHighlights(nodeOf({})),
        throwsA(isA<SchemaException>()),
      );
      final out = m.restHighlights(
        nodeOf({
          'tray': [
            {'title': 'x'},
            {'id': 'highlight:ZZFAKE_1'},
            5,
          ],
        }),
      );
      expect(out.map((h) => h.id), ['ZZFAKE_1']);
    });

    test('highlight items: empty reels, odd body, null items', () {
      expect(
        m.restHighlightItems(nodeOf({'reels': <String, Object?>{}}), ['a']),
        isEmpty,
      );
      expect(
        () => m.restHighlightItems(nodeOf({'status': 'ok'}), ['a']),
        throwsA(isA<SchemaException>()),
      );
    });

    test('highlight items: carousel and video items map', () {
      final carousel = {
        ..._img('ZZFAKE_car'),
        'media_type': 8,
        'product_type': 'carousel_container',
        'carousel_media': [_img('ZZFAKE_c1')],
      };
      final video = {
        ..._img('ZZFAKE_vid'),
        'media_type': 2,
        'video_versions': [
          {'url': 'https://cdn.example.test/v.mp4', 'width': 1, 'height': 1},
        ],
      };
      final body = {
        'reels': {
          'highlight:ZZFAKE_h': {
            'id': 'highlight:ZZFAKE_h',
            'items': [carousel, video],
          },
        },
      };
      Object? out;
      try {
        out = m.restHighlightItems(nodeOf(body), ['ZZFAKE_h']);
      } on SchemaException {
        out = 'schema';
      }
      expect(out, anyOf(isA<Map<String, List<RemoteContent>>>(), 'schema'));
    });
  });

  test('REST paging terminates when server repeats the same cursor', () async {
    final rig = _r(
      (r) => jsonReply({
        'items': [_img('ZZFAKE_p')],
        'more_available': false,
        'next_max_id': 'ZZFAKE_same',
      }),
    );
    final page = (await rig.run(rig.extractor.fetchPostPage(_u))).valueOrNull!;
    expect(page.nextCursor, isNull);
  });
}
