// T-041 direct mode: post pages (cursor in, nextCursor out), the highlights
// tray and highlight items, governed and without values in the logs.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

const _userId = 'ZZFAKE_user_a';

Responder _responder() => (r) {
  final name = friendlyName(r);
  if (name == GraphqlQuery.posts.friendlyName) {
    final after = variablesOf(r)['after'];
    final file = switch (after) {
      null => 'timeline_page1.json',
      'ZZFAKE_cursor_2' => 'timeline_page2.json',
      _ => 'timeline_page3.json',
    };
    return jsonReply(loadSynthetic(file));
  }
  if (name == GraphqlQuery.highlights.friendlyName) {
    return jsonReply(loadSynthetic('highlights_tray.json'));
  }
  if (name == GraphqlQuery.stories.friendlyName) {
    return jsonReply(loadSynthetic('highlight_reel.json'));
  }
  return jsonReply({'status': 'fail'}, status: 500);
};

Future<Rig> _rig({Responder? responder, FakeDocIds? docIds}) async {
  final names = InMemoryUsernameCache();
  await names.remember(_userId, 'zzfake_a');
  return Rig(
    responder: responder ?? _responder(),
    usernames: names,
    transport: GraphqlTransport(
      docIds: docIds ?? FakeDocIds(),
      tokens: FakeTokens(),
    ),
  );
}

void main() {
  group('fetchPostPage', () {
    test('cursor in, nextCursor out, the last page has none', () async {
      final rig = await _rig();
      final p1 = (await rig.run(rig.extractor.fetchPostPage(_userId)))
          .valueOrNull!;
      expect(p1.items.map((c) => c.remoteId), [
        'ZZFAKE_p_1001',
        'ZZFAKE_p_1002',
        'ZZFAKE_p_pinned_old',
      ]);
      final c1 = PostCursor.parse(p1.nextCursor!)!;
      expect(c1.igCursor, 'ZZFAKE_cursor_2');
      expect(c1.takenAt.millisecondsSinceEpoch, 1800000800 * 1000);
      final first = variablesOf(rig.http.requests[0]);
      expect(first.containsKey('after'), isFalse);

      final p2 = (await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: p1.nextCursor),
      )).valueOrNull!;
      final second = variablesOf(rig.http.requests[1]);
      expect(second['after'], 'ZZFAKE_cursor_2');
      expect(second['first'], 12);
      expect(p2.items, hasLength(3));
      expect(PostCursor.parse(p2.nextCursor!)!.igCursor, 'ZZFAKE_cursor_3');

      final p3 = (await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: p2.nextCursor),
      )).valueOrNull!;
      expect(p3.items, hasLength(2));
      expect(p3.nextCursor, isNull);
      expect(rig.http.maxInFlight, 1);
      expect(await rig.governor.remainingTokens(1), 3, reason: '3 api calls');
    });

    test('a page-mode cursor is SchemaChanged without a request', () async {
      final rig = await _rig();
      final cursor = PostCursor(
        takenAt: DateTime.utc(2027),
        igCursor: '',
      ).encode();
      final r = await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: cursor),
      );
      expect(r.failureOrNull, isA<SchemaChanged>());
      expect(rig.http.requests, isEmpty);
    });

    test('a garbage cursor is a bad_cursor failure', () async {
      final rig = await _rig();
      final r = await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: 'nope'),
      );
      expect(r.failureOrNull, isA<UnknownFailure>());
      expect(rig.http.requests, isEmpty);
    });

    test('a response without has_next_page is SchemaChanged', () async {
      final body =
          loadSynthetic('timeline_page1.json')! as Map<String, Object?>;
      final conn =
          (body['data']!
                  as Map)['xdt_api__v1__feed__user_timeline_graphql_connection']
              as Map;
      (conn['page_info']! as Map).remove('has_next_page');
      final rig = await _rig(responder: (_) => jsonReply(body));
      final r = await rig.run(rig.extractor.fetchPostPage(_userId));
      expect(r.failureOrNull, isA<SchemaChanged>());
    });

    test(
      'a missing timeline doc_id is SchemaChanged (page-mode signal)',
      () async {
        final rig = await _rig(
          docIds: FakeDocIds(missing: {GraphqlQuery.posts}),
        );
        final r = await rig.run(rig.extractor.fetchPostPage(_userId));
        expect(r.failureOrNull, isA<SchemaChanged>());
        expect(rig.http.requests, isEmpty);
      },
    );
  });

  group('highlights', () {
    test(
      'the tray maps id (prefix stripped), title, cover, time, in order',
      () async {
        final rig = await _rig();
        final tray = (await rig.run(rig.extractor.fetchHighlights(_userId)))
            .valueOrNull!;
        expect(tray.map((h) => h.id), ['ZZFAKE_hl_1', 'ZZFAKE_hl_2']);
        expect(tray[0].title, 'ZZFAKE Title One');
        expect(tray[0].coverUrl, contains('ZZFAKE_cover_1'));
        expect(tray[0].itemCount, 2);
        expect(tray[0].latestItemAt!.millisecondsSinceEpoch, 1800000200 * 1000);
        expect(tray[1].latestItemAt, isNull);
        expect(variablesOf(rig.http.requests.single)['user_id'], _userId);
      },
    );

    test('items: kind highlight, extras, reel ids carry the prefix', () async {
      final rig = await _rig();
      final out = (await rig.run(
        rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1']),
      )).valueOrNull!;
      expect(out.keys, ['ZZFAKE_hl_1'], reason: 'the other reel is ignored');
      final items = out['ZZFAKE_hl_1']!;
      expect(items.map((c) => c.remoteId), ['ZZFAKE_h_1', 'ZZFAKE_h_2']);
      for (final c in items) {
        expect(c.kind, ContentKind.highlight);
        expect(c.extras[HighlightExtras.id], 'ZZFAKE_hl_1');
        expect(c.extras[HighlightExtras.title], 'ZZFAKE Title One');
        expect(c.extras[HighlightExtras.order], 0);
      }
      expect(items[1].slides.single.type, MediaType.video);
      expect(variablesOf(rig.http.requests.single)['reel_ids_arr'], [
        'highlight:ZZFAKE_hl_1',
      ]);
    });

    test('missing tray doc_id is SchemaChanged', () async {
      final rig = await _rig(
        docIds: FakeDocIds(missing: {GraphqlQuery.highlights}),
      );
      final r = await rig.run(rig.extractor.fetchHighlights(_userId));
      expect(r.failureOrNull, isA<SchemaChanged>());
    });

    test(
      'a 429 pauses the account; no ids, titles or URLs are logged',
      () async {
        final rig = await _rig();
        await rig.run(rig.extractor.fetchHighlights(_userId));
        await rig.run(rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1']));
        await rig.run(rig.extractor.fetchPostPage(_userId));
        for (final w in ['ZZFAKE_hl', 'Title One', 'cdn.example', 'cursor']) {
          expect(rig.allLogs, isNot(contains(w)), reason: w);
        }
        final limited = await _rig(
          responder: (_) => jsonReply({'message': 'x'}, status: 429),
        );
        final r1 = await limited.run(
          limited.extractor.fetchHighlights(_userId),
        );
        expect(r1.failureOrNull, isA<RateLimited>());
        final n = limited.http.requests.length;
        final r2 = await limited.run(limited.extractor.fetchPostPage(_userId));
        expect(r2.failureOrNull, isA<RateLimited>());
        expect(limited.http.requests, hasLength(n));
      },
    );
  });
}
