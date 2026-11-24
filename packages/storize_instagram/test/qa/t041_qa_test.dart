// QA tests for T-041 (history and highlights, direct and page mode).
// ignore_for_file: avoid_dynamic_calls, cast_nullable_to_non_nullable, lines_longer_than_80_chars, unnecessary_parenthesis, avoid_redundant_argument_values
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart' as d;
import '../page/support.dart' as p;

const _userId = 'ZZFAKE_user_a';

Future<d.Rig> _directRig(d.Responder responder) async {
  final names = InMemoryUsernameCache();
  await names.remember(_userId, 'zzfake_a');
  return d.Rig(
    responder: responder,
    usernames: names,
    transport: GraphqlTransport(docIds: d.FakeDocIds(), tokens: d.FakeTokens()),
  );
}

d.Responder _ok() => (r) {
  final name = d.friendlyName(r);
  if (name == GraphqlQuery.posts.friendlyName) {
    return d.jsonReply(d.loadSynthetic('timeline_page1.json'));
  }
  if (name == GraphqlQuery.highlights.friendlyName) {
    return d.jsonReply(d.loadSynthetic('highlights_tray.json'));
  }
  return d.jsonReply(d.loadSynthetic('highlight_reel.json'));
};

Map<String, Object?> _timeline(
  List<(String, int)> posts, {
  bool next = true,
}) => {
  'data': {
    'xdt_api__v1__feed__user_timeline_graphql_connection': {
      'edges': [
        for (final (pk, t) in posts)
          {
            'node': {
              'pk': pk,
              'id': '${pk}_$_userId',
              'code': 'ZZFAKE_c_$pk',
              'media_type': 1,
              'product_type': 'feed',
              'taken_at': t,
              'user': {'pk': _userId},
              'owner_id': {'pk': _userId},
              'caption': null,
              'coauthor_producers': <Object?>[],
              'image_versions2': {
                'candidates': [
                  {
                    'url': 'https://cdn.example.test/ZZFAKE_$pk.jpg',
                    'width': 320,
                    'height': 320,
                  },
                ],
              },
            },
          },
      ],
      'page_info': {'has_next_page': next, 'end_cursor': 'ZZFAKE_c'},
    },
  },
};

p.Rig _pageRig({
  required p.OnLoad onLoad,
  void Function(p.FakePageSession, int)? onScroll,
  int pageSize = 12,
  int maxSteps = 30,
}) {
  final rig = p.Rig(
    usernames: const {_userId: p.fakeUser},
    postPageSize: pageSize,
    maxScrollSteps: maxSteps,
    onLoad: onLoad,
  );
  rig.driver.onScroll = onScroll;
  return rig;
}

HookEvent _posts(Object? body) => p.hookResponse(body, name: p.postsName);

void main() {
  group('1 governor', () {
    test('direct: 45 ids stop after the chunk that is rate limited', () async {
      var n = 0;
      final rig = await _directRig(
        (r) => ++n == 2 ? const IgReply(status: 429) : _ok()(r),
      );
      final ids = [for (var i = 0; i < 45; i++) 'ZZFAKE_h$i'];
      final r = await rig.run(rig.extractor.fetchHighlightItems(ids));
      expect(r.failureOrNull, isA<RateLimited>());
      expect(rig.http.requests, hasLength(2), reason: '3 chunks, stop at #2');
      expect(rig.http.maxInFlight, 1);
    });

    test('direct: a paused governor sends nothing', () async {
      final rig = await _directRig(_ok());
      await rig.run(rig.governor.reportRateLimited(1, const RateLimited(null)));
      final ids = [for (var i = 0; i < 100; i++) 'ZZFAKE_h$i'];
      final r = await rig.run(rig.extractor.fetchHighlightItems(ids));
      expect(r.failureOrNull, isA<RateLimited>());
      expect(rig.http.requests, isEmpty);
      final a = await rig.run(rig.extractor.fetchPostPage(_userId));
      expect(a.failureOrNull, isA<RateLimited>());
      expect(rig.http.requests, isEmpty);
    });

    test('page: ids stop at the load that is rate limited', () async {
      var loads = 0;
      final rig = _pageRig(
        onLoad: (s, url) {
          loads++;
          s.emit(
            loads == 3
                ? const HttpErrorEvent(429)
                : p.hookResponse(
                    jsonDecode(
                      jsonEncode(
                        d.loadSynthetic('highlight_reel.json'),
                      ).replaceAll(
                        'highlight:ZZFAKE_hl_1',
                        'highlight:${url.pathSegments[2]}',
                      ),
                    ),
                    name: p.storiesName,
                  ),
          );
        },
      );
      final ids = [for (var i = 0; i < 10; i++) 'ZZFAKE_hl_$i'];
      final r = await rig.run(rig.extractor.fetchHighlightItems(ids));
      expect(r.failureOrNull, isA<RateLimited>());
      expect(loads, 3, reason: '7 further ids must not be loaded');
      expect(rig.driver.maxActive, 1);
      expect(rig.driver.sessions.every((s) => s.disposed), isTrue);
    });

    test(
      'page: each load is one governed pageLoad; scroll adds none',
      () async {
        final rig = _pageRig(
          onLoad: (s, url) => s
            ..emit(_posts(_timeline([('ZZFAKE_a', 1800000100)])))
            ..emit(const LoadStopEvent()),
        );
        final before = await rig.governor.remainingTokens(1);
        final r = await rig.run(rig.extractor.fetchPostPage(_userId));
        expect(r.isOk, isTrue);
        final after = await rig.governor.remainingTokens(1);
        expect(before - after, closeTo(3, 0.5), reason: 'one pageLoad = 3');
        expect(rig.driver.sessions, hasLength(1));
        expect(rig.driver.sessions.single.loads, hasLength(1));
        expect(rig.driver.sessions.single.scrolls, lessThanOrEqualTo(30));
      },
    );

    test('page: a paused governor opens no WebView', () async {
      final rig = _pageRig(onLoad: (s, url) {});
      await rig.run(rig.governor.reportRateLimited(1, const RateLimited(null)));
      final r = await rig.run(
        rig.extractor.fetchHighlightItems([for (var i = 0; i < 20; i++) 'h$i']),
      );
      expect(r.failureOrNull, isA<RateLimited>());
      expect(rig.driver.sessions, isEmpty);
    });
  });

  group('2 seen / scroll', () {
    test('scroll is bounded by maxSteps and loads only the profile', () async {
      final rig = _pageRig(
        maxSteps: 5,
        onLoad: (s, url) => s
          ..emit(_posts(_timeline([('ZZFAKE_a', 1800000100)])))
          ..emit(const LoadStopEvent()),
      );
      await rig.run(rig.extractor.fetchPostPage(_userId));
      final s = rig.driver.sessions.single;
      expect(s.scrolls, 5);
      expect(s.loads.single.path, '/zzfake_user/');
      expect(rig.driver.log.where((e) => e == 'scroll'), hasLength(5));
    });

    test('a seen reply while scrolling a profile trips the guard', () async {
      final guard = SeenGuard();
      final rig = p.Rig(
        usernames: const {_userId: p.fakeUser},
        seenGuard: guard,
        onLoad: (s, url) => s
          ..emit(_posts(_timeline([('ZZFAKE_a', 1800000100)])))
          ..emit(const LoadStopEvent()),
      );
      rig.driver.onScroll = (s, step) => s.emit(
        p.hookResponse({
          'data': {'xdt_mark_story_reel_seen': <String, Object?>{}},
        }, name: p.seenName),
      );
      final r = await rig.run(rig.extractor.fetchPostPage(_userId));
      expect(r.failureOrNull, isA<UnknownFailure>());
      expect(guard.tripped, isTrue);
    });

    test('the scroll timeout ends the run with a result, not a hang', () async {
      final rig = p.Rig(
        usernames: const {_userId: p.fakeUser},
        autoGrace: true,
        onLoad: (s, url) => s.emit(const LoadStopEvent()),
      );
      final f = rig.extractor.fetchPostPage(_userId);
      final r = await rig.run(f);
      // No response was ever seen: must be a failure, and the session closed.
      expect(r.isErr, isTrue);
      expect(rig.driver.sessions.single.disposed, isTrue);
    });
  });

  group('3 cursors', () {
    test(
      'page mode: posts sharing the cursor second are not dropped (F1)',
      () async {
        // Two posts share second 1800000500; the page ends between them.
        final all = _timeline([
          ('ZZFAKE_p1', 1800000900),
          ('ZZFAKE_p2', 1800000500),
          ('ZZFAKE_p3', 1800000500),
          ('ZZFAKE_p4', 1800000100),
        ], next: false);
        final rig = _pageRig(
          pageSize: 2,
          onLoad: (s, url) => s
            ..emit(_posts(all))
            ..emit(const LoadStopEvent()),
        );
        final p1 = (await rig.run(rig.extractor.fetchPostPage(_userId)))
            .valueOrNull!;
        expect(p1.items.map((c) => c.remoteId), ['ZZFAKE_p1', 'ZZFAKE_p3']);
        final p2 = (await rig.run(
          rig.extractor.fetchPostPage(_userId, cursor: p1.nextCursor),
        )).valueOrNull!;
        final got = p2.items.map((c) => c.remoteId).toList();
        expect(got, ['ZZFAKE_p2', 'ZZFAKE_p4']);
      },
    );

    for (final bad in [
      'garbage',
      '',
      'v1|',
      'v1|x|y',
      'v2|1|y',
      'v1|9223372036854775807|x',
      'v1|-9223372036854775808|x',
      'v1|99999999999999|x',
    ]) {
      test('malformed cursor "$bad" fails safely, no loop', () async {
        final rig = await _directRig(_ok());
        final r = await rig.run(
          rig.extractor.fetchPostPage(_userId, cursor: bad),
        );
        expect(r.isErr, isTrue);
        expect(rig.http.requests.length, lessThanOrEqualTo(1));
        final pr = _pageRig(
          onLoad: (s, url) => s
            ..emit(_posts(_timeline([('ZZFAKE_a', 1800000100)], next: false)))
            ..emit(const LoadStopEvent()),
        );
        final r2 = await pr.run(
          pr.extractor.fetchPostPage(_userId, cursor: bad),
        );
        expect(r2, isNotNull);
        expect(pr.driver.sessions.length, lessThanOrEqualTo(1));
      });
    }

    test('direct: has_next_page missing or end_cursor missing is SchemaChanged', () async {
      final m = _timeline([('ZZFAKE_a', 1800000100)]);
      final conn =
          ((m['data']!
                  as Map)['xdt_api__v1__feed__user_timeline_graphql_connection']!
              as Map);
      (conn['page_info']! as Map).remove('has_next_page');
      var rig = await _directRig((r) => d.jsonReply(m));
      var r = await rig.run(rig.extractor.fetchPostPage(_userId));
      expect(r.failureOrNull, isA<SchemaChanged>());
      (conn['page_info']! as Map)
        ..['has_next_page'] = true
        ..remove('end_cursor');
      rig = await _directRig((r) => d.jsonReply(m));
      r = await rig.run(rig.extractor.fetchPostPage(_userId));
      expect(r.failureOrNull, isA<SchemaChanged>());
    });
  });

  group('4 mapping', () {
    test(
      'items: kind, extras, prefix stripped, order from orderStart',
      () async {
        final rig = await _directRig(_ok());
        final reel = d.loadSynthetic('highlight_reel.json') as Map;
        final id =
            ((reel['data'] as Map)['xdt_api__v1__feed__reels_media']
                    as Map)['reels_media'][0]['id']
                as String;
        final plain = id.replaceFirst('highlight:', '');
        final out = (await rig.run(
          rig.extractor.fetchHighlightItems([plain], orderStart: 7),
        )).valueOrNull!;
        final item = out[plain]!.first;
        expect(item.kind, ContentKind.highlight);
        expect(item.extras[HighlightExtras.id], plain);
        expect(item.extras[HighlightExtras.order], 7);
        expect(item.extras.containsKey(HighlightExtras.title), isTrue);
        expect(item.expiresAt, isNull);
        final sent = d.variablesOf(rig.http.requests.single)['reel_ids_arr'];
        expect(sent, ['highlight:$plain']);
      },
    );

    test(
      'direct: a caller id that already has the prefix is not silently lost',
      () async {
        final rig = await _directRig(_ok());
        final reel = d.loadSynthetic('highlight_reel.json') as Map;
        final id =
            ((reel['data'] as Map)['xdt_api__v1__feed__reels_media']
                    as Map)['reels_media'][0]['id']
                as String;
        final r = await rig.run(rig.extractor.fetchHighlightItems([id]));
        final sent = d.variablesOf(rig.http.requests.single)['reel_ids_arr'];
        expect(sent, [id], reason: 'prefix sent once');
        expect(r.valueOrNull!.keys, [id.substring('highlight:'.length)]);
      },
    );

    for (final body in <Object?>[
      <String, Object?>{},
      {'data': null},
      {
        'data': {'highlights': 'x'},
      },
      {
        'data': {
          'xdt_api__v1__feed__reels_media': {
            'reels_media': [1, 'a', null],
          },
        },
      },
      {
        'data': {
          'xdt_api__v1__feed__reels_media': {
            'reels_media': [
              {'id': 5},
            ],
          },
        },
      },
      [1, 2],
    ]) {
      test('unknown shape ${jsonEncode(body)} never throws', () async {
        final rig = await _directRig((r) => d.jsonReply(body));
        final a = await rig.run(rig.extractor.fetchHighlights(_userId));
        final b = await rig.run(
          rig.extractor.fetchHighlightItems(['ZZFAKE_h']),
        );
        final c = await rig.run(rig.extractor.fetchPostPage(_userId));
        for (final r in [a, b, c]) {
          if (r.isErr) {
            expect(
              r.failureOrNull,
              anyOf(isA<SchemaChanged>(), isA<UnknownFailure>()),
            );
          }
        }
      });
    }
  });

  group('5 logging', () {
    test('direct: no ids, titles, cursors or URLs in logs', () async {
      final rig = await _directRig(_ok());
      final p1 = (await rig.run(rig.extractor.fetchPostPage(_userId)))
          .valueOrNull!;
      await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: p1.nextCursor),
      );
      await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: 'junk-ZZFAKE'),
      );
      await rig.run(rig.extractor.fetchHighlights(_userId));
      await rig.run(rig.extractor.fetchHighlightItems(['ZZFAKE_hl_1']));
      for (final w in [
        'ZZFAKE_cursor',
        'ZZFAKE_hl',
        'ZZFAKE_p_',
        'Title One',
        'cdn.example',
        'junk-ZZFAKE',
        'zzfake_a',
        d.fakeSessionId,
      ]) {
        expect(rig.allLogs, isNot(contains(w)), reason: w);
      }
    });

    test('page: no cursor or username in logs', () async {
      final rig = _pageRig(
        onLoad: (s, url) => s
          ..emit(_posts(_timeline([('ZZFAKE_a', 1800000100)], next: false)))
          ..emit(const LoadStopEvent()),
      );
      await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: 'v1|1800000200|'),
      );
      await rig.run(
        rig.extractor.fetchPostPage(_userId, cursor: 'junk-ZZFAKE'),
      );
      for (final w in [
        '1800000200',
        'junk-ZZFAKE',
        'ZZFAKE_a',
        'zzfake_user',
      ]) {
        expect(rig.allLogs, isNot(contains(w)), reason: w);
      }
    });
  });

  group('6 classification', () {
    final cases = <(String, IgReply, bool Function(Failure))>[
      ('429', const IgReply(status: 429), (f) => f is RateLimited),
      ('500', const IgReply(status: 500), (f) => f is! SessionInvalid),
      ('404', const IgReply(status: 404), (f) => f is! SessionInvalid),
      (
        'login redirect',
        const IgReply(status: 302, redirectPath: '/accounts/login/'),
        (f) => f is SessionInvalid,
      ),
      ('401', const IgReply(status: 401), (f) => f is SessionInvalid),
    ];
    for (final (label, reply, ok) in cases) {
      test('direct $label on all three history calls', () async {
        final rig = await _directRig((r) => reply);
        for (final r in [
          await rig.run(rig.extractor.fetchPostPage(_userId)),
          await rig.run(rig.extractor.fetchHighlights(_userId)),
          await rig.run(rig.extractor.fetchHighlightItems(['ZZFAKE_h'])),
        ]) {
          expect(r.isErr, isTrue, reason: label);
          expect(
            ok(r.failureOrNull!),
            isTrue,
            reason: '$label ${r.failureOrNull}',
          );
        }
      });
    }

    test(
      'page: logged-out redirect is SessionInvalid; 429 event RateLimited',
      () async {
        var rig = _pageRig(
          onLoad: (s, url) => s.emit(
            const NavigationEvent(
              host: 'www.instagram.com',
              path: '/accounts/login/',
            ),
          ),
        );
        final all = [
          (await rig.run(rig.extractor.fetchHighlights(_userId))).failureOrNull,
          (await rig.run(rig.extractor.fetchPostPage(_userId))).failureOrNull,
          (await rig.run(
            rig.extractor.fetchHighlightItems(['ZZFAKE_h']),
          )).failureOrNull,
        ];
        for (final f in all) {
          expect(f, isA<SessionInvalid>());
        }
        rig = _pageRig(onLoad: (s, url) => s.emit(const HttpErrorEvent(429)));
        expect(
          (await rig.run(rig.extractor.fetchHighlights(_userId))).failureOrNull,
          isA<RateLimited>(),
        );
      },
    );
  });
}
