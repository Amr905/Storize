// QA (T-014), independent adversarial checks (round 1), un-skipped in round 2.
// Each test names its finding (QA-Fn) in docs/05-reviews/T-014.md.
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
      // QA-F9: the reply has the type the page asked for
      expect(
        (r['xhr_json_response_type'] as Map)['response'],
        isA<Map<String, dynamic>>(),
      );
      final ab = r['xhr_blob_arraybuffer_response_type'] as Map;
      expect(ab['responseType'], 'object');
      expect(ab['response'], '[object ArrayBuffer]');
    }, skip: noNode);
  });

  group('QA-F1 seen-mutation block: every request shape fails closed', () {
    late Map<String, dynamic> r;
    setUpAll(() async {
      if (noNode == null) r = await _hookScenarios();
    });
    bool reached(String k) => (r[k] as Map)['reached'] as bool;

    const shapes = {
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

    for (final e in shapes.entries) {
      test('blocked: ${e.value}', () {
        expect(reached(e.key), isFalse);
        expect((r[e.key] as Map)['blockedNotices'], greaterThanOrEqualTo(1));
      }, skip: noNode);
    }
  });

  group('QA-F2 custom blocked list can only add names', () {
    test('the seen mutation stays in the list whatever the config says', () {
      for (final names in [
        const <String>[],
        const ['Other'],
      ]) {
        final cfg = PageHookConfig(blockedFriendlyNames: names);
        expect(cfg.blockedFriendlyNames, contains(seenName));
        expect(cfg.prelude(), contains(seenName));
        expect(cfg.blockedFriendlyNames, containsAll(names));
      }
    });

    test('the list cannot be changed after it is built', () {
      final cfg = PageHookConfig();
      final names = cfg.blockedFriendlyNames;
      expect(names.clear, throwsUnsupportedError);
    });

    test(
      'hook.js blocks the seen mutation with an empty or foreign list',
      () async {
        final r = await _hookScenarios();
        expect((r['config_empty_list'] as Map)['reached'], isFalse);
        expect((r['config_other_list'] as Map)['reached'], isFalse);
      },
      skip: noNode,
    );
  });

  group('QA-F3 canary: a reply to a blocked name means the block failed', () {
    OnLoad leak(Object? body, {String? name = seenName}) => emitting([
      hookResponse(body, name: name),
      hookResponse(loadReal('story', '003_graphql.json'), name: storiesName),
    ]);

    test(
      'a reply with the blocked name fails the run, counted, logged',
      () async {
        final rig = Rig(
          onLoad: leak({
            'data': {'xdt_mark_story_reel_seen': <String, Object?>{}},
          }),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(r.failureOrNull, const UnknownFailure(null, 'seen_block_leak'));
        expect(rig.extractor.seenLeakCount, 1);
        expect(rig.allLogs, contains('seen_block_leak'));
        expect(rig.driver.sessions.single.disposed, isTrue);
      },
    );

    test(
      'a reply with the mutation data key and no name also counts',
      () async {
        final rig = Rig(
          onLoad: leak({
            'data': {'xdt_mark_story_reel_seen': <String, Object?>{}},
          }, name: null),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(r.failureOrNull, const UnknownFailure(null, 'seen_block_leak'));
      },
    );

    test('a configured extra name counts too', () async {
      final rig = Rig(
        hookConfig: PageHookConfig(blockedFriendlyNames: ['Extra_Name']),
        onLoad: leak(<String, Object?>{'data': null}, name: 'Extra_Name'),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, const UnknownFailure(null, 'seen_block_leak'));
    });

    test('the log has the code but no value, id or username', () async {
      final rig = Rig(
        onLoad: leak({
          'data': {
            'xdt_mark_story_reel_seen': {'secret': fakeSessionId},
          },
        }),
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(rig.allLogs, isNot(contains(fakeSessionId)));
      expect(rig.allLogs, isNot(contains(fakeUser)));
      expect(rig.allLogs, isNot(contains(fakeDocId)));
    });

    test('the breaker refuses later story loads, not profile loads', () async {
      final guard = SeenGuard();
      final rig = Rig(
        seenGuard: guard,
        onLoad: (s, u) {
          if (u.path.startsWith('/stories/')) {
            leak({
              'data': {'xdt_mark_story_reel_seen': <String, Object?>{}},
            })(s, u);
          } else {
            emitting([hookResponse(realProfile(), name: profileName)])(s, u);
          }
        },
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(guard.tripped, isTrue);
      final opened = rig.driver.sessions.length;
      final again = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(
        again.failureOrNull,
        const UnknownFailure(null, 'seen_guard_tripped'),
      );
      expect(rig.driver.sessions, hasLength(opened), reason: 'nothing opened');
      final profile = await rig.run(rig.extractor.resolveUser(fakeUser));
      expect(profile, isA<Ok<RemoteUser>>());
    });

    test('the breaker is shared by extractors that share the guard', () async {
      final guard = SeenGuard();
      final a = Rig(
        seenGuard: guard,
        onLoad: leak({
          'data': {'xdt_mark_story_reel_seen': <String, Object?>{}},
        }),
      );
      await a.run(a.extractor.fetchStories(['user_1']));
      final b = Rig(
        seenGuard: guard,
        onLoad: emitting(const []),
      );
      final r = await b.run(b.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, const UnknownFailure(null, 'seen_guard_tripped'));
      expect(b.driver.log, isEmpty);
    });

    test('no leak on a normal run: no reply with a blocked name', () async {
      final rig = Rig(
        onLoad: emitting([
          hookBlocked(seenName),
          hookResponse(
            loadReal('story', '003_graphql.json'),
            name: storiesName,
          ),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
      expect(rig.extractor.seenLeakCount, 0);
      expect(rig.extractor.blockedRequestCount, 1);
    });
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

  group('QA native handler guard on the adapter (source guards)', () {
    final adapter = File('lib/page/webview.dart').readAsStringSync();
    test('QA-F4: native allow-list is the two origins, main frame only', () {
      expect(adapter, contains('javaScriptHandlersOriginAllowList'));
      expect(adapter, contains('javaScriptHandlersForMainFrameOnly: true'));
    });
    test('QA-F4: the allow-list patterns accept exactly the two origins', () {
      final patterns = {
        r'^https://www\.instagram\.com$',
        r'^https://instagram\.com$',
      };
      expect(adapter, contains('pageHandlerOriginPatterns'));
      for (final p in patterns) {
        expect(adapter, contains(p));
      }
      bool ok(String o) => patterns.any((p) => RegExp(p).hasMatch(o));
      expect(ok('https://www.instagram.com'), isTrue);
      expect(ok('https://instagram.com'), isTrue);
      for (final bad in [
        'https://www.instagram.com.evil.test',
        'https://evil.test/https://www.instagram.com',
        'http://www.instagram.com',
        'https://help.instagram.com',
        'https://www.instagram.com:444',
        'https://www.instagram.com\n',
      ]) {
        expect(ok(bad), isFalse, reason: bad);
      }
    });
    test('QA-F5: the adapter checks DOCUMENT_START_SCRIPT before it opens', () {
      expect(adapter, contains('WebViewFeature.DOCUMENT_START_SCRIPT'));
      final check = adapter.indexOf('await _documentStartSupported()');
      final wipe = adapter.indexOf('await _wipe();');
      expect(check, isNonNegative);
      expect(check, lessThan(wipe), reason: 'checked before any cookie work');
      expect(adapter, contains('throw const PageHookUnsupportedException()'));
    });
    test('the clean-up wipes the app-wide jar (S-02 conflict, QA-F7)', () {
      expect(adapter, contains('deleteAllCookies()'));
      expect(adapter, contains('deleteAllData()'));
      expect(adapter, contains('clearAllCache()'));
    });
    test('QA-F10: open wipes leftover cookies BEFORE it sets the new ones', () {
      final open = adapter.substring(
        adapter.indexOf('Future<PageSession> open'),
      );
      final wipe = open.indexOf('await _wipe();');
      final set = open.indexOf('cookies.setCookie');
      expect(wipe, isNonNegative);
      expect(set, greaterThan(wipe));
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

  // ----------------------------------------------------------------- round 2
  NavigationEvent nav(String path) =>
      NavigationEvent(host: 'www.instagram.com', path: path);
  final story = loadReal('story', '003_graphql.json');
  final emptyReels = loadPage('reels_empty.json');

  group('QA-F5 fail closed without document-start support', () {
    test('page_hook_unsupported, nothing loaded, lease released', () async {
      final lease = FakeWebViewLease();
      final rig = Rig(
        documentStart: false,
        webViewLease: lease,
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(
        r.failureOrNull,
        const UnknownFailure(null, 'page_hook_unsupported'),
      );
      expect(rig.driver.sessions, isEmpty);
      expect(rig.driver.log, ['open'], reason: 'no load, no clear');
      expect(rig.timers, isEmpty);
      expect(lease.released, lease.acquired);
      expect(rig.allLogs, contains('page_hook_unsupported'));
    });

    test('it applies to every plan, not only stories', () async {
      final rig = Rig(documentStart: false, onLoad: emitting(const []));
      final r = await rig.run(rig.extractor.resolveUser(fakeUser));
      expect(
        r.failureOrNull,
        const UnknownFailure(null, 'page_hook_unsupported'),
      );
    });
  });

  group('QA-F6 timeouts: the governed call always completes', () {
    test('open() is bounded by 10 s: page_open_timeout', () async {
      final gate = Completer<void>();
      final lease = FakeWebViewLease();
      final rig = Rig(
        openGate: gate,
        webViewLease: lease,
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      );
      final f = rig.extractor.fetchStories(['user_1']);
      await rig.time.pump();
      expect(rig.openTimers.single.duration, const Duration(seconds: 10));
      expect(rig.timers, isEmpty, reason: 'the 20 s timer starts after open');
      rig.openTimers.single.fire();
      final r = await f;
      expect(r.failureOrNull, const UnknownFailure(null, 'page_open_timeout'));
      expect(lease.released, lease.acquired, reason: 'lease released');
      expect(lease.acquired, hasLength(1));
      // The governor lease is free again: the next call runs.
      gate.complete();
      await rig.time.pump();
      final again = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(again.failureOrNull, isNull);
    });

    test(
      'a session that opens after the timeout is cleaned in the background',
      () async {
        final gate = Completer<void>();
        final rig = Rig(openGate: gate, onLoad: emitting(const []));
        final f = rig.extractor.fetchStories(['user_1']);
        await rig.time.pump();
        rig.openTimers.single.fire();
        await f;
        expect(rig.driver.sessions, isEmpty);
        gate.complete();
        await rig.time.pump();
        final late = rig.driver.sessions.single;
        expect(late.cleared, isTrue);
        expect(late.disposed, isTrue);
        expect(late.loads, isEmpty, reason: 'a late session is never used');
      },
    );

    test('open() that throws after the timeout is ignored', () async {
      final gate = Completer<void>();
      final rig = Rig(
        openGate: gate,
        openThrows: true,
        onLoad: emitting(const []),
      );
      final f = rig.extractor.fetchStories(['user_1']);
      await rig.time.pump();
      rig.openTimers.single.fire();
      expect(
        (await f).failureOrNull,
        const UnknownFailure(null, 'page_open_timeout'),
      );
      gate.complete();
      await rig.time.pump();
    });

    test('a clearData that hangs is abandoned; dispose still runs', () async {
      final rig = Rig(
        clearHangs: true,
        cleanupTimeout: const Duration(milliseconds: 30),
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      );
      final r = await rig.extractor.fetchStories(['user_1']);
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
      expect(rig.driver.sessions.single.disposed, isTrue);
      expect(rig.allLogs, contains('cleanup_timeout step=clear_data'));
    });

    test('a dispose that hangs is abandoned; the result stands', () async {
      final lease = FakeWebViewLease();
      final rig = Rig(
        disposeHangs: true,
        webViewLease: lease,
        cleanupTimeout: const Duration(milliseconds: 30),
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      );
      final r = await rig.extractor.fetchStories(['user_1']);
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
      expect(rig.allLogs, contains('cleanup_timeout step=dispose'));
      expect(lease.released, lease.acquired, reason: 'lease still released');
    });

    test('a lease that never answers is bounded: webview_busy', () async {
      final rig = Rig(
        webViewLease: _HangingLease(),
        cleanupTimeout: const Duration(milliseconds: 30),
        onLoad: emitting(const []),
      );
      final r = await rig.extractor.fetchStories(['user_1']);
      expect(r.failureOrNull, const UnknownFailure(null, 'webview_busy'));
    });

    test('the default timeouts are 10 s (open) and 5 s (clean-up)', () {
      final rig = Rig(onLoad: emitting(const []));
      expect(rig.extractor.openTimeout, const Duration(seconds: 10));
      expect(rig.extractor.cleanupTimeout, const Duration(seconds: 5));
      expect(rig.extractor.timeout, const Duration(seconds: 20));
    });
  });

  group('QA-F7 WebView lease', () {
    test('busy: webview_busy at once, nothing opened or wiped', () async {
      final lease = FakeWebViewLease(busy: true);
      final rig = Rig(webViewLease: lease, onLoad: emitting(const []));
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, const UnknownFailure(null, 'webview_busy'));
      expect(rig.driver.log, isEmpty);
      expect(rig.timers, isEmpty);
      expect(rig.openTimers, isEmpty);
      expect(lease.released, isEmpty, reason: 'never acquired, never released');
      expect(rig.allLogs, contains('webview_busy'));
    });

    test('acquired for the run and released after success', () async {
      final lease = FakeWebViewLease();
      final rig = Rig(
        webViewLease: lease,
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(lease.acquired, ['page_mode:1']);
      expect(lease.released, ['page_mode:1']);
      final order = rig.driver.log;
      expect(order.first, 'open');
    });

    test('released after a failure and after an open that throws', () async {
      final lease = FakeWebViewLease();
      final bad = Rig(
        webViewLease: lease,
        openThrows: true,
        onLoad: emitting(const []),
      );
      await bad.run(bad.extractor.fetchStories(['user_1']));
      expect(lease.released, lease.acquired);
      final fail = Rig(
        webViewLease: lease,
        onLoad: emitting([nav('/accounts/login/')]),
      );
      final r = await fail.run(fail.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, isA<SessionInvalid>());
      expect(lease.released, lease.acquired);
      expect(lease.acquired, hasLength(2));
    });

    test(
      'the lease is taken for each load (three users, three leases)',
      () async {
        final lease = FakeWebViewLease();
        final rig = Rig(
          webViewLease: lease,
          usernames: const {'a': 'zzfake_a', 'b': 'zzfake_b'},
          onLoad: emitting([
            hookResponse(emptyReels, name: storiesName),
            const LoadStopEvent(),
          ]),
        );
        await rig.run(rig.extractor.fetchStories(['a', 'b']));
        expect(lease.acquired, hasLength(2));
        expect(lease.released, hasLength(2));
      },
    );

    test('the default lease is free (no-op)', () async {
      const lease = NoopWebViewLease();
      expect(await lease.tryAcquire('x'), isTrue);
      await lease.release('x');
    });

    test(
      'a lease that blocks the story load also blocks profile loads',
      () async {
        final lease = FakeWebViewLease(busy: true);
        final rig = Rig(webViewLease: lease, onLoad: emitting(const []));
        final r = await rig.run(rig.extractor.resolveUser(fakeUser));
        expect(r.failureOrNull, const UnknownFailure(null, 'webview_busy'));
      },
    );
  });

  group('QA-F8 an empty reel reply does not end the run early', () {
    test('empty first, the target reel second: the reel wins', () async {
      final rig = Rig(
        autoGrace: false,
        onLoad: emitting([
          hookResponse(emptyReels, name: storiesName),
          const LoadStopEvent(),
          hookResponse(story, name: storiesName),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(
        (r as Ok<Map<String, List<RemoteContent>>>).value['user_1'],
        isNotEmpty,
      );
    });

    test('empty reply but no LoadStop yet: the run keeps waiting', () async {
      final rig = Rig(
        autoGrace: false,
        onLoad: emitting([hookResponse(emptyReels, name: storiesName)]),
      );
      var done = false;
      final f = rig.extractor
          .fetchStories(['user_1'])
          .whenComplete(() => done = true);
      await rig.time.pump();
      expect(done, isFalse);
      expect(rig.timers.single.duration, const Duration(seconds: 20));
      // the 20 s timer ends with the tentative answer: no stories
      rig.timers.single.fire();
      final r = await f;
      expect((r as Ok<Map<String, List<RemoteContent>>>).value, isEmpty);
    });

    test('empty reply, LoadStop, then the grace period: no stories', () async {
      final rig = Rig(
        autoGrace: false,
        onLoad: emitting([
          hookResponse(emptyReels, name: storiesName),
          const LoadStopEvent(),
        ]),
      );
      var done = false;
      final f = rig.extractor
          .fetchStories(['user_1'])
          .whenComplete(() => done = true);
      await rig.time.pump();
      expect(done, isFalse, reason: 'the grace period has not passed');
      final grace = rig.timers.firstWhere(
        (t) => t.duration == rig.extractor.emptyGrace,
      );
      expect(grace.duration, const Duration(seconds: 2));
      grace.fire();
      expect(
        ((await f) as Ok<Map<String, List<RemoteContent>>>).value,
        isEmpty,
      );
    });

    test(
      'a real reel that arrives during the grace period still wins',
      () async {
        final rig = Rig(
          autoGrace: false,
          onLoad: emitting([
            hookResponse(emptyReels, name: storiesName),
            const LoadStopEvent(),
          ]),
        );
        final f = rig.extractor.fetchStories(['user_1']);
        await rig.time.pump();
        rig.driver.sessions.single.emit(hookResponse(story, name: storiesName));
        final r = await f;
        expect(
          (r as Ok<Map<String, List<RemoteContent>>>).value['user_1'],
          isNotEmpty,
        );
      },
    );

    test('landing on the profile path is tentative too', () async {
      final rig = Rig(
        autoGrace: false,
        onLoad: emitting([nav('/$fakeUser/'), const LoadStopEvent()]),
      );
      var done = false;
      final f = rig.extractor
          .fetchStories(['user_1'])
          .whenComplete(() => done = true);
      await rig.time.pump();
      expect(done, isFalse);
      rig.driver.sessions.single.emit(hookResponse(story, name: storiesName));
      final r = await f;
      expect(
        (r as Ok<Map<String, List<RemoteContent>>>).value['user_1'],
        isNotEmpty,
      );
    });

    test('a failure still ends the run at once', () async {
      final rig = Rig(
        autoGrace: false,
        onLoad: emitting([
          hookResponse(emptyReels, name: storiesName),
          hookResponse(
            loadSynthetic('failures/please_wait.json'),
            name: storiesName,
          ),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, isA<RateLimited>());
    });
  });

  group('QA-F11 story path: another user is a quick username_mismatch', () {
    test('the reel list holds only other users', () async {
      final rig = Rig(
        onLoad: emitting([
          hookResponse(loadPage('reels_other_user.json'), name: storiesName),
          const LoadStopEvent(),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, const UnknownFailure(null, 'username_mismatch'));
    });

    test("a redirect to another user's page", () async {
      final rig = Rig(
        onLoad: emitting([
          nav('/stories/$fakeUser/'),
          nav('/someone_else/'),
          const LoadStopEvent(),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r.failureOrNull, const UnknownFailure(null, 'username_mismatch'));
    });

    test(
      'no capture for the target and a load that stops: not a timeout',
      () async {
        final rig = Rig(
          onLoad: emitting([
            nav('/someone_else/'),
            hookResponse(<String, Object?>{'data': null}, name: 'Other'),
            const LoadStopEvent(),
          ]),
        );
        final r = await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(r.failureOrNull, isNot(const SchemaChanged('page_timeout')));
      },
    );

    test('the target reel arriving first still wins', () async {
      final rig = Rig(
        autoGrace: false,
        onLoad: emitting([
          nav('/someone_else/'),
          const LoadStopEvent(),
          hookResponse(story, name: storiesName),
        ]),
      );
      final r = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(r, isA<Ok<Map<String, List<RemoteContent>>>>());
    });
  });
}

final class _HangingLease implements WebViewLease {
  @override
  Future<bool> tryAcquire(String owner) => Completer<bool>().future;
  @override
  Future<void> release(String owner) async {}
}
