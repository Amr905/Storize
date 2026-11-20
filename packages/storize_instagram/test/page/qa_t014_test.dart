// QA (T-014), independent adversarial checks. Tests marked `skip:` assert the
// WANTED behaviour and fail today; each names its finding (QA-Fn) in
// docs/05-reviews/T-014.md. Plain tests pin what the code does today.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

Future<Map<String, dynamic>> _hookScenarios() async {
  final r = await Process.run('node', [
    'test/page/qa_hook_harness.js',
    'assets/hook.js',
  ]);
  if (r.exitCode != 0) fail('qa harness failed: ${r.stderr}');
  return jsonDecode(r.stdout as String) as Map<String, dynamic>;
}

bool get _hasNode {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  final noNode = _hasNode ? null : 'node is not installed';

  group('QA seen-mutation block: shapes that ARE blocked (pinned)', () {
    late Map<String, dynamic> r;
    setUpAll(() async {
      if (noNode == null) r = await _hookScenarios();
    });
    bool reached(String k) => (r[k] as Map)['reached'] as bool;

    test('control and every supported shape never reach the network', () {
      for (final k in [
        'control_string_body',
        'fetch_request_object_plus_init_body',
        'path_graphql_query',
        'path_api_graphql_slash',
        'path_relative',
        'path_bare_domain',
        'path_subdomain_i',
        'path_graph_host',
        'xhr_string',
        'xhr_url_object',
        'beacon_string',
        'beacon_urlsearchparams',
        'config_null_list',
        'config_string_list',
        'config_undefined_all',
      ]) {
        expect(reached(k), isFalse, reason: k);
        expect((r[k] as Map)['blockedNotices'], 1, reason: k);
      }
    }, skip: noNode);

    test('other hosts are not touched (lookalike, facebook.com)', () {
      expect(reached('host_lookalike_not_instagram'), isTrue);
      expect(reached('host_facebook'), isTrue);
    }, skip: noNode);

    test('a second injection does not wrap fetch twice', () {
      expect(
        (r['page_reassigns_fetch_to_original_via_iframe_like']
            as Map)['stableWrapper'],
        isTrue,
      );
    }, skip: noNode);

    test('the fake reply: 200, JSON, no url, only a content-type header', () {
      final f = r['fake_reply_shape_fetch'] as Map;
      expect(f['status'], 200);
      expect(f['headers'], {'content-type': 'application/json'});
      expect(f['url'], '');
      final x = r['fake_reply_shape_xhr'] as Map;
      expect(x['events'], ['readystatechange', 'load', 'loadend']);
      expect(x['ready'], 4);
      // json responseType works; arraybuffer/blob get a STRING (QA-F9, Low)
      expect(
        (r['xhr_json_response_type'] as Map)['response'],
        isA<Map<String, dynamic>>(),
      );
      expect(
        (r['xhr_blob_arraybuffer_response_type'] as Map)['responseType'],
        'string',
      );
    }, skip: noNode);
  });

  group('QA seen-mutation block: BYPASSES (pinned; wanted = blocked)', () {
    late Map<String, dynamic> r;
    setUpAll(() async {
      if (noNode == null) r = await _hookScenarios();
    });
    bool reached(String k) => (r[k] as Map)['reached'] as bool;

    const bypasses = {
      'fetch_request_object': 'fetch(new Request(url,{body}))',
      'fetch_url_object_input': 'fetch(new URL(..), {body})',
      'fetch_formdata_body': 'FormData body',
      'fetch_blob_body': 'Blob body',
      'fetch_arraybuffer_body': 'Uint8Array body',
      'fetch_json_body': 'JSON body',
      'fetch_name_in_header_only': 'x-fb-friendly-name header',
      'fetch_name_in_query_only': 'name in the URL query (POST)',
      'fetch_get_with_query': 'GET with the form in the query',
      'xhr_formdata': 'XHR FormData',
      'xhr_blob': 'XHR Blob',
      'xhr_header_name': 'XHR header',
      'beacon_blob': 'sendBeacon Blob',
      'beacon_formdata': 'sendBeacon FormData',
    };

    test('documents today: the mutation still reaches the network', () {
      for (final k in bypasses.keys) {
        expect(reached(k), isTrue, reason: '${bypasses[k]} (QA-F1)');
      }
    }, skip: noNode);

    for (final e in bypasses.entries) {
      test(
        'WANTED blocked: ${e.value}',
        () => expect(reached(e.key), isFalse),
        skip:
            'QA-F1: hook inspects only string / URLSearchParams bodies '
            'of fetch(url, init), XHR and beacon',
      );
    }
  });

  group('QA custom blocked list', () {
    test('an empty or foreign list REPLACES the default (seen unblocked)', () {
      expect(
        PageHookConfig(blockedFriendlyNames: const []).prelude(),
        contains('"blockedFriendlyNames":[]'),
      );
      final other = PageHookConfig(blockedFriendlyNames: const ['Other']);
      expect(other.prelude(), isNot(contains(seenName)));
    });

    test('the hook sends the mutation with an empty or foreign list', () async {
      final r = await _hookScenarios();
      expect((r['config_empty_list'] as Map)['reached'], isTrue);
      expect((r['config_other_list'] as Map)['reached'], isTrue);
    }, skip: noNode);

    test(
      'WANTED: the seen mutation stays blocked whatever the list says',
      () {
        final cfg = PageHookConfig(blockedFriendlyNames: const ['Other']);
        expect(cfg.prelude(), contains(seenName));
        expect(
          PageHookConfig(blockedFriendlyNames: const []).prelude(),
          contains(seenName),
        );
      },
      skip: 'QA-F2: default is replaced, not unioned',
    );
  });

  group('QA no canary for a leaked seen mutation', () {
    test(
      'a captured response of the seen mutation is silently accepted',
      () async {
        final rig = Rig(
          onLoad: emitting([
            hookResponse({
              'data': {
                'xdt_mark_story_reel_seen': {'status': 'ok'},
              },
            }, name: seenName),
            hookResponse(
              loadReal('story', '003_graphql.json'),
              name: storiesName,
            ),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
        expect(rig.extractor.blockedRequestCount, 0);
        expect(rig.allLogs, isNot(contains('leak')));
        expect(rig.allLogs, isNot(contains('seen')));
      },
    );

    test('WANTED: a seen-mutation reply is logged as a leak', () async {
      final rig = Rig(
        onLoad: emitting([
          hookResponse({
            'data': {'xdt_mark_story_reel_seen': <String, Object?>{}},
          }, name: seenName),
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
          ),
        ]),
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(rig.allLogs, contains('seen_mutation_not_blocked'));
    }, skip: 'QA-F3: no detection if the block is bypassed');
  });

  group('QA origin checks', () {
    Object? payload({String origin = okOrigin}) => {
      'url': 'https://www.instagram.com/api/graphql',
      'status': 200,
      'origin': origin,
      'body': '{}',
    };
    HookMessage parse(String frame, {String claimed = okOrigin}) =>
        parseHookMessage([payload(origin: claimed)], pageOrigin: frame);

    test('frame origins that must be dropped', () {
      for (final o in [
        'https://instagram.com.evil',
        'https://instagram.com.evil.test',
        'https://www.instagram.com.evil.test',
        'https://xn--instagram-9ya.com',
        'https://xn--nstagram-7ya.com',
        'https://www.xn--instagram.com',
        'https://evil.test/https://www.instagram.com',
        'https://www.instagram.com@evil.test',
        'https://www.instagram.com:444',
        'https://www.instagram.com:0',
        'https://www.instagram.com.',
        'https://WWW.INSTAGRAM.COM',
        'https://Instagram.com',
        'HTTPS://www.instagram.com',
        'http://www.instagram.com',
        'about:blank',
        'null',
        '',
        'data:text/html,hi',
        'blob:https://www.instagram.com/1234',
        'file://',
        'https://www.instagram.com/',
        'https://www.instagram.com/path',
        ' https://www.instagram.com',
        'https://www.instagram.com ',
        'https://www.instagram.com\u0000',
        'https://www.instagram.com\n',
        'https://help.instagram.com',
        'https://l.instagram.com',
        'https://i.instagram.com',
      ]) {
        expect(parse(o), isA<HookDropped>(), reason: 'frame "$o"');
      }
    });

    test('claimed origins that must be dropped (frame is fine)', () {
      for (final o in [
        'https://instagram.com.evil',
        'null',
        'about:blank',
        'blob:https://www.instagram.com/1',
        'https://WWW.INSTAGRAM.COM',
        'https://www.instagram.com/',
        'https://m.instagram.com',
      ]) {
        final m = parse(okOrigin, claimed: o);
        expect(m, isA<HookDropped>(), reason: 'claimed "$o"');
        expect((m as HookDropped).reason, HookDropReason.origin);
      }
      // wrong types
      for (final bad in <Object?>[
        null,
        1,
        true,
        ['https://www.instagram.com'],
        {'a': 1},
      ]) {
        final m = parseHookMessage([
          {
            'url': 'https://www.instagram.com/x',
            'status': 200,
            'origin': bad,
            'body': '{}',
          },
        ], pageOrigin: okOrigin);
        expect(m, isA<HookDropped>());
      }
    });

    test('originOf: default ports collapse, others do not', () {
      expect(originOf('https', 'www.instagram.com', 443), okOrigin);
      expect(originOf('https', 'www.instagram.com'), okOrigin);
      expect(originOf('https', 'www.instagram.com', -1), okOrigin);
      expect(originOf('https', 'www.instagram.com', 0), okOrigin);
      expect(originOf('https', 'www.instagram.com', 80), isNot(okOrigin));
      expect(
        originOf('http', 'www.instagram.com', 80),
        'http://www.instagram.com',
      );
      expect(
        allowedPageOrigins.contains(originOf('https', 'instagram.com', 443)),
        isTrue,
      );
    });

    test('the instagram frame and claimed origins are accepted', () {
      expect(parse(okOrigin), isA<HookCapture>());
      expect(
        parse('https://instagram.com', claimed: 'https://instagram.com'),
        isA<HookCapture>(),
      );
      // frame and claim may differ between the two allowed origins
      expect(parse('https://instagram.com'), isA<HookCapture>());
    });

    test('a blocked notice needs both origins too', () {
      for (final bad in ['https://evil.test', 'about:blank', 'null']) {
        expect(
          parseHookMessage([
            {'type': 'blocked', 'friendlyName': seenName, 'origin': okOrigin},
          ], pageOrigin: bad),
          isA<HookDropped>(),
        );
        expect(
          parseHookMessage([
            {'type': 'blocked', 'friendlyName': seenName, 'origin': bad},
          ], pageOrigin: okOrigin),
          isA<HookDropped>(),
        );
      }
    });

    test('message urls: userinfo, lookalike, scheme and case', () {
      for (final u in [
        'https://www.instagram.com@evil.test/api/graphql',
        'https://evil.test/www.instagram.com',
        'https://instagram.com.evil.test/x',
        'http://www.instagram.com/x',
        'wss://www.instagram.com/x',
        'blob:https://www.instagram.com/1',
        '//www.instagram.com/x',
        '/api/graphql',
        '',
      ]) {
        final m = parseHookMessage([
          {'url': u, 'status': 200, 'origin': okOrigin, 'body': '{}'},
        ], pageOrigin: okOrigin);
        expect(m, isA<HookDropped>(), reason: u);
      }
      // Uri lower-cases the host, so an upper-case host is accepted: harmless
      final up = parseHookMessage([
        {
          'url': 'https://WWW.INSTAGRAM.COM/api/graphql',
          'status': 200,
          'origin': okOrigin,
          'body': '{}',
        },
      ], pageOrigin: okOrigin);
      expect(up, isA<HookCapture>());
    });

    test(
      'a forged message carrying a huge or hostile payload is dropped safely',
      () {
        final big = 'x' * (maxHookBodyLength + 1);
        expect(
          parseHookMessage([
            {
              'url': 'https://www.instagram.com/x',
              'status': 200,
              'origin': okOrigin,
              'body': '"$big"',
            },
          ], pageOrigin: okOrigin),
          isA<HookDropped>(),
        );
        expect(
          parseHookMessage([
            {
              'url': 'https://www.instagram.com/x',
              'status': '200',
              'origin': okOrigin,
              'body': '{}',
            },
          ], pageOrigin: okOrigin),
          isA<HookDropped>(),
        );
        // doc_id of the wrong shape and tokens with hostile keys are ignored
        final m = parseHookMessage([
          {
            'url': 'https://www.instagram.com/x',
            'status': 200,
            'origin': okOrigin,
            'body': '{}',
            'request': {
              'docId': '12; DROP',
              'tokens': {'ok_key': 'v', 'bad key!': 'v', '': 'v', 'e': ''},
            },
          },
        ], pageOrigin: okOrigin) as HookCapture;
        expect(m.docId, isNull);
        expect(m.tokens, {'ok_key': 'v'});
      },
    );
  });

  group('QA native handler guard on the adapter', () {
    final adapter = File('lib/page/webview.dart').readAsStringSync();
    test('webview.dart does not set the plugin-level origin allow-list', () {
      expect(adapter, isNot(contains('javaScriptHandlersOriginAllowList')));
      expect(adapter, isNot(contains('javaScriptHandlersForMainFrameOnly')));
    });
    test(
      'WANTED: native allow-list and main-frame-only are set',
      () {
        expect(adapter, contains('javaScriptHandlersOriginAllowList'));
        expect(adapter, contains('javaScriptHandlersForMainFrameOnly'));
      },
      skip:
          'QA-F4: the "native frame origin" is window.location.origin '
          'computed by the plugin bridge JS inside the frame',
    );
    test(
      'WANTED: fail closed when document-start scripts are unsupported',
      () {
        expect(adapter, contains('DOCUMENT_START_SCRIPT'));
      },
      skip:
          'QA-F5: without the feature the plugin injects in onPageStarted '
          '(race with the page) and re-injects at document end',
    );
    test('the clean-up wipes the app-wide jar (S-02 conflict, QA-F7)', () {
      expect(adapter, contains('deleteAllCookies()'));
      expect(adapter, contains('deleteAllData()'));
      expect(adapter, contains('clearAllCache()'));
    });
    test('the session never opens an unbounded wait before the timer', () {
      // `await created.future` has no timeout (QA-F6)
      expect(adapter, contains('await created.future;'));
      expect(adapter, isNot(contains('.timeout(')));
    });
  });

  group('QA governor discipline and failure paths', () {
    OnLoad byUrl() => (s, url) {
      if (url.path.startsWith('/stories/')) {
        emitting([
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
          ),
        ])(s, url);
      } else {
        emitting([
          hookResponse(realProfile(), name: profileName),
          hookResponse(
            loadReal('profile', '007_graphql.json'),
            name: postsName,
          ),
        ])(s, url);
      }
    };

    test('concurrent calls are serialised: one WebView at a time', () async {
      final rig = Rig(onLoad: byUrl());
      final rs = await rig.run(
        Future.wait([
          rig.extractor.fetchStories(['user_1']),
          rig.extractor.resolveUser(fakeUser),
          rig.extractor.latestStoryTime('user_1'),
          rig.extractor.fetchNewPosts('user_1', DateTime.utc(2000)),
        ]),
      );
      expect(rig.driver.maxActive, 1);
      expect(rig.driver.sessions, hasLength(4));
      expect(
        rs.every((r) => r.failureOrNull == null),
        isTrue,
        reason: rs.map((r) => r.failureOrNull).toString(),
      );
      expect(rig.driver.sessions.every((s) => s.cleared && s.disposed), isTrue);
      expect(
        rig.governorLogs.where((l) => l.contains('cost=pageLoad')),
        hasLength(4),
      );
      expect(rig.governorLogs.where((l) => l.contains('cost=api')), isEmpty);
    });

    test(
      'open throwing: webview_unavailable, no clear, nothing leaks',
      () async {
        final rig = Rig(onLoad: byUrl(), openThrows: true);
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(
          r.failureOrNull,
          const UnknownFailure(null, 'webview_unavailable'),
        );
        expect(rig.timers, isEmpty); // no timer was armed
        expect(rig.allLogs, isNot(contains('ZZFAKE')));
        expect(rig.driver.active, 0);
        // the governor lease is released: the next call can run
        final again = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(
          again.failureOrNull,
          const UnknownFailure(null, 'webview_unavailable'),
        );
      },
    );

    test(
      'an open() that never completes holds the governed call forever',
      () async {
        final never = Completer<PageSession>();
        final rig = Rig(onLoad: byUrl());
        final ex = PageExtractor(
          accountId: 1,
          governor: rig.governor,
          sessions: rig.sessions,
          driver: _HangingDriver(never),
          hookSource: '',
          usernames: _cache(),
          timer: (d, f) {
            final t = ManualTimer(d, f);
            rig.timers.add(t);
            return t;
          },
        );
        var done = false;
        unawaited(ex.fetchStories(['user_1']).whenComplete(() => done = true));
        await rig.time.pump();
        await rig.time.elapse(const Duration(minutes: 10));
        expect(done, isFalse);
        expect(
          rig.timers,
          isEmpty,
          reason: 'the 20 s timer starts only after open',
        );
      },
    );

    test('WANTED: open() is bounded by the 20 s timeout', () async {
      final never = Completer<PageSession>();
      final rig = Rig(onLoad: byUrl());
      final ex = PageExtractor(
        accountId: 1,
        governor: rig.governor,
        sessions: rig.sessions,
        driver: _HangingDriver(never),
        hookSource: '',
        usernames: _cache(),
        timer: (d, f) {
          final t = ManualTimer(d, f);
          rig.timers.add(t);
          return t;
        },
      );
      final f = ex.fetchStories(['user_1']);
      await rig.time.pump();
      expect(rig.timers, isNotEmpty);
      rig.timers.first.fire();
      expect((await f).failureOrNull, isNotNull);
    }, skip: 'QA-F6: open() and the clean-up awaits have no timeout');

    test('timeout then a late match: the first outcome stands', () async {
      final rig = Rig(onLoad: (s, u) {});
      final f = rig.extractor.fetchStories(['user_1']);
      await rig.time.pump();
      final s = rig.driver.sessions.single;
      rig.timers.single.fire();
      // arrives after the timer fired, before the finally has run
      s.emit(
        hookResponse(loadReal('story', '003_graphql.json'), name: storiesName),
      );
      final r = await rig.run(f);
      expect(r.failureOrNull, const SchemaChanged('page_timeout'));
      expect(
        await rig.discovery.docIdFor(GraphqlQuery.stories),
        isNull,
        reason: 'a capture after the timeout is not recorded',
      );
      expect(s.disposed, isTrue);
    });
  });

  group('QA parsing: ordering, duplicates, unrelated captures', () {
    final story = loadReal('story', '003_graphql.json');
    test(
      'two matching captures: the first answer wins, the second is ignored',
      () async {
        final rig = Rig(
          onLoad: emitting([
            hookResponse(story, name: storiesName),
            hookResponse(loadPage('reels_empty.json'), name: storiesName),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(
          (r as Ok<Map<String, List<RemoteContent>>>).value['user_1'],
          isNotEmpty,
        );
      },
    );

    test(
      'a failing match first, a good one second: the failure wins',
      () async {
        final rig = Rig(
          onLoad: emitting([
            hookResponse(
              loadSynthetic('failures/please_wait.json'),
              name: storiesName,
            ),
            hookResponse(story, name: storiesName),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(r.failureOrNull, isA<RateLimited>());
      },
    );

    test(
      'an empty reel list first, then the real one: the empty one wins (QA-F8)',
      () async {
        // A page may fire the reel query twice (tray, then the user). The first
        // reply with an empty list ends the run as "no stories".
        final rig = Rig(
          onLoad: emitting([
            hookResponse(loadPage('reels_empty.json'), name: storiesName),
            hookResponse(story, name: storiesName),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect((r as Ok<Map<String, List<RemoteContent>>>).value, isEmpty);
      },
    );

    test('many unrelated captures then a match', () async {
      final rig = Rig(
        onLoad: emitting([
          for (var i = 0; i < 50; i++)
            hookResponse(loadPage('unrelated_graphql.json'), name: 'Other$i'),
          hookResponse({'data': null}),
          hookResponse(story, name: storiesName),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect((r as Ok<Map<String, List<RemoteContent>>>).value, isNotEmpty);
    });

    test('a capture with no friendly name never answers a plan', () async {
      final rig = Rig(onLoad: emitting([hookResponse(story)]));
      final f = rig.extractor.fetchStories(['user_1']);
      await rig.time.pump();
      rig.timers.single.fire();
      expect((await f).failureOrNull, const SchemaChanged('page_timeout'));
    });

    test(
      'page mode and direct mode map the real fixtures identically',
      () async {
        const m = EnvelopeMapper();
        // profile
        final prof = realProfile();
        final rig = Rig(
          onLoad: emitting([hookResponse(prof, name: profileName)]),
        );
        final u = (await rig.run(
          rig.extractor.resolveUser(fakeUser),
        ) as Ok<RemoteUser>).value;
        expect(u, m.graphqlProfile(Node.root(prof, 'r')).$1!.user);
        // posts
        final posts = loadReal('profile', '007_graphql.json');
        final rig2 = Rig(
          onLoad: emitting([hookResponse(posts, name: postsName)]),
        );
        final got = (await rig2.run(
          rig2.extractor.fetchNewPosts('user_1', DateTime.utc(2000)),
        ) as Ok<List<RemoteContent>>).value;
        expect(got, isNotEmpty);
        expect(got.map((e) => e.remoteId).toSet(), hasLength(got.length));
        // post / reel / carousel by shortcode
        var checked = 0;
        for (final (cap, body) in [
          ('post_photo', '003_media_info.json'),
          ('post_carousel', '002_media_info.json'),
          ('reel', '003_media_info.json'),
        ]) {
          final raw = jsonDecode(
            File('test/fixtures/real/$cap/bodies/$body').readAsStringSync(),
          ) as Map<String, Object?>;
          const code = 'ZZcode12345';
          ((raw['items']! as List).first as Map)['code'] = code;
          checked++;
          final r3 = Rig(
            onLoad: emitting([
              hookResponse(
                raw,
                path: '/api/v1/media/1234567/info/',
              ),
            ]),
          );
          final item = (await r3.run(
            r3.extractor.fetchPost(code),
          ) as Ok<RemoteContent>).value;
          expect(
            item,
            const MediaMapper().post(Node.root(raw, 'r')['items'].list.first),
          );
        }
        expect(checked, greaterThan(0), reason: 'no fixture had a usable code');
      },
    );

    test(
      'a media info path that is not .../media/<digits>/info/ never matches',
      () async {
        final raw = realMediaInfo('ZZcode123');
        for (final p in [
          '/api/v1/media/abc/info/',
          '/api/v1/media/1/info/extra',
          '/x/api/v1/media/1/info/',
          '/api/v1/media//info/',
        ]) {
          final rig = Rig(
            onLoad: emitting([hookResponse(raw, path: p)]),
          );
          final f = rig.extractor.fetchPost('ZZcode123');
          await rig.time.pump();
          rig.timers.single.fire();
          expect(
            (await f).failureOrNull,
            const SchemaChanged('page_timeout'),
            reason: p,
          );
        }
      },
    );
  });

  group('QA secrets', () {
    test(
      'hostile bodies, names and errors never reach logs or failures',
      () async {
        const evil =
            'ZZFAKE_sessionid_value ZZFAKE_csrf_value ZZFAKE_dtsg_value';
        final story = {
          'data': {
            evil: {
              'edges': [evil],
            },
            'xdt_api__v1__feed__reels_media': {'reels_media': evil},
          },
        };
        final rig = Rig(
          onLoad: emitting([hookResponse(story, name: storiesName)]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        final text =
            '${r.failureOrNull} ${rig.allLogs} ${rig.discovery} '
            '${rig.driver.sessions.single.config}';
        for (final s in [
          'ZZFAKE_sessionid_value',
          'ZZFAKE_csrf_value',
          'ZZFAKE_dtsg_value',
          fakeDocId,
          fakeUser,
        ]) {
          expect(text, isNot(contains(s)), reason: s);
        }
      },
    );

    test('toString of every event, message and config hides payloads', () {
      final e = hookResponse({'a': 1}, name: storiesName);
      expect('$e', 'HookEvent');
      final m = parseHookMessage(e.args, pageOrigin: okOrigin);
      expect('$m', isNot(contains(fakeDtsg)));
      expect('$m', isNot(contains(fakeDocId)));
      expect(
        '${const PageSessionConfig(
          cookies: {'sessionid': 'ZZ'},
          userAgent: 'UA',
          hookSource: 's',
          handlerName: 'h',
          allowedOrigins: allowedPageOrigins,
        )}',
        isNot(contains('ZZ')),
      );
    });

    test('page loads set includeRequestSecrets; the inspector does not', () {
      final cfg = PageHookConfig().prelude();
      expect(cfg, contains('"includeRequestSecrets":true'));
      final inspector = File('../../app/lib/debug/inspector_screen.dart')
          .readAsStringSync();
      expect(inspector, isNot(contains('includeRequestSecrets')));
      expect(inspector, contains('includeBody: false'));
    });

    test('doc_id and tokens are not written by any page file', () {
      for (final f in Directory('lib/page').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('SharedPreferences')), reason: f.path);
        expect(src, isNot(contains('writeAsString')), reason: f.path);
        expect(src, isNot(contains('print(')), reason: f.path);
        expect(src, isNot(contains('debugPrint')), reason: f.path);
      }
    });
  });
}

InMemoryUsernameCache _cache() {
  final c = InMemoryUsernameCache();
  unawaited(c.remember('user_1', fakeUser));
  return c;
}

final class _HangingDriver implements PageDriver {
  _HangingDriver(this._c);
  final Completer<PageSession> _c;
  @override
  Future<PageSession> open(PageSessionConfig config) => _c.future;
}
