// QA (T-014), round 2: new adversarial shapes for the seen block (run against
// the REAL assets/hook.js in Node), false-positive checks for the queries the
// extractor needs, and lifecycle checks (lease, timers, ordering, breaker).
// Tests named RESIDUAL pin a known, accepted gap; each is listed in
// docs/05-reviews/T-014.md (Round 2 verification).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

Future<Map<String, dynamic>> _scenarios() async {
  final r = await Process.run('node', [
    'test/page/qa2_hook_harness.js',
    'assets/hook.js',
  ]);
  if (r.exitCode != 0) fail('qa2 harness failed: ${r.stderr}');
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
  late Map<String, dynamic> r;
  setUpAll(() async {
    if (noNode == null) r = await _scenarios();
  });
  bool reached(String k) => (r[k] as Map)['reached'] as bool;
  int sent(String k) => (r[k] as Map)['requests'] as int;
  int notices(String k) => (r[k] as Map)['blockedNotices'] as int;

  void blocked(Iterable<String> keys) {
    for (final k in keys) {
      expect((r[k] as Map).containsKey('error'), isFalse, reason: '$k errored');
      expect(reached(k), isFalse, reason: '$k reached the network');
      expect(sent(k), 0, reason: '$k sent something');
      expect(notices(k), greaterThanOrEqualTo(1), reason: '$k not reported');
    }
  }

  group('QA2-F1 new shapes are blocked', () {
    test('split across chunks: stream bodies', () {
      blocked([
        'stream_init_body_graphql_split', // unreadable + graphql: fail closed
        'request_stream_body_split', // Request(stream): read through clone()
        'request_stream_body_split_non_graphql',
        'fetch_keepalive_stream_graphql',
      ]);
    }, skip: noNode);

    test('multipart: string body, FormData with a Blob part, field name', () {
      blocked([
        'multipart_string_body',
        'multipart_formdata_blob_part',
        'multipart_string_name_in_field_name',
      ]);
    }, skip: noNode);

    test('percent-encoding: once, twice, partial, malformed neighbours', () {
      blocked([
        'encoded_all_chars_once',
        'encoded_all_chars_twice',
        'encoded_some_chars_twice_mixed',
        'name_in_url_query',
        'malformed_percent_does_not_throw',
      ]);
    }, skip: noNode);

    test('case: upper and lower', () {
      blocked(['case_upper', 'case_lower']);
    }, skip: noNode);

    test('legacy markers: path (any case), body marker', () {
      blocked([
        'legacy_rest_path',
        'legacy_rest_path_upper',
        'legacy_marker_in_body',
        'beacon_marker_in_url',
      ]);
    }, skip: noNode);

    test('sendBeacon: URLSearchParams, Blob, typed array, URL object', () {
      blocked([
        'beacon_urlsearchparams',
        'beacon_blob',
        'beacon_blob_return_value',
        'beacon_url_object',
        'beacon_typed_array',
      ]);
      // an async-read beacon still answers `true` (queued), like the browser
      expect((r['beacon_blob_return_value'] as Map)['ret'], isTrue);
    }, skip: noNode);

    test('XMLHttpRequest reused: blocked twice, ok then blocked', () {
      expect(sent('xhr_reused_blocked_then_blocked'), 0);
      expect(notices('xhr_reused_blocked_then_blocked'), 2);
      expect(reached('xhr_reused_ok_then_blocked'), isFalse);
      expect(sent('xhr_reused_ok_then_blocked'), 1, reason: 'only the ok one');
      expect(notices('xhr_reused_ok_then_blocked'), 1);
      blocked([
        'xhr_async_body_blocked_then_not_sent',
        'xhr_subclass_page_defined',
        'proto_restore_xhr_send_via_getOwnPropertyDescriptor',
      ]);
    }, skip: noNode);

    test('an aborted XHR whose body was read async is never sent', () {
      expect(sent('xhr_blocked_then_abort_before_send_microtask'), 0);
    }, skip: noNode);

    test('the page wraps, re-applies or re-injects: still blocked', () {
      blocked([
        'page_wraps_hooked_fetch',
        'page_second_hook_inject_does_not_unwrap',
        'page_deletes_flag_and_reinjects_double_wrap',
      ]);
      expect(notices('page_calls_fetch_via_apply_call_reflect'), 3);
      expect(sent('page_calls_fetch_via_apply_call_reflect'), 0);
    }, skip: noNode);

    test('keepalive fetch: string, Request, Blob', () {
      blocked([
        'fetch_keepalive_string',
        'fetch_keepalive_request',
        'fetch_keepalive_blob',
        'fetch_request_plus_init_override_headers_only',
        'fetch_url_with_userinfo_and_hash',
        'fetch_protocol_relative',
        'fetch_headers_instance_name',
        'fetch_headers_array_pairs',
        'fetch_body_getter_throws', // fails closed on a GraphQL path
        'json_plain',
      ]);
    }, skip: noNode);
  });

  group('QA2-F1 RESIDUAL: shapes that still pass (pinned, none seen live)', () {
    // Each passes because the server matches the request by doc_id and the
    // name only as a label, or would have to decode more than the hook does.
    // Dart's canary (seen_block_leak) is the second barrier for all of them.
    test('three-fold percent-encoding passes (a server decodes once)', () {
      expect(sent('encoded_all_chars_thrice'), 1);
      expect(notices('encoded_all_chars_thrice'), 0);
    }, skip: noNode);

    test(r'JSON \u escapes inside a JSON body pass (the API takes a form)', () {
      expect(sent('json_unicode_escape'), 1);
    }, skip: noNode);

    test('look-alike unicode never matches (a server does not fold it)', () {
      for (final k in [
        'unicode_fullwidth',
        'unicode_dotted_I_and_long_s',
        'unicode_combining_mark_inside',
      ]) {
        expect(sent(k), 1, reason: k);
        expect(reached(k), isFalse, reason: k);
      }
    }, skip: noNode);

    test('a stream body to a NON-GraphQL instagram path passes', () {
      expect(reached('stream_init_body_non_graphql_split'), isTrue);
      expect(reached('beacon_stream_non_graphql'), isTrue);
    }, skip: noNode);

    test('a nameless request (doc_id only) passes: name-based block', () {
      expect(sent('fetch_no_name_but_doc_id_only'), 1);
    }, skip: noNode);
  });

  group('QA2-F9 / R2-F1 (fixed in T-015): a reused XHR is not poisoned', () {
    test(
      'after a blocked send, the NEXT real request reads the real reply',
      () {
        final x = r['xhr_reused_blocked_then_ok'] as Map;
        expect(x['requests'], 1, reason: 'the second request was sent');
        // open() deletes the fake own-properties, so the prototype accessors
        // answer again.
        expect(x['secondStatusReal'], isTrue);
      },
      skip: noNode,
    );
  });

  group('QA2-F1 no needed query is blocked', () {
    const kinds = [
      'stories',
      'profile',
      'posts',
      'timeline',
      'media_info',
    ];
    const shapes = ['string', 'formdata', 'request_obj', 'xhr', 'typed_array'];
    test('reel, profile, posts, timeline, media/info in 5 shapes each', () {
      for (final k in kinds) {
        for (final s in shapes) {
          final key = 'needed_${k}_$s';
          expect((r[key] as Map).containsKey('error'), isFalse, reason: key);
          expect(sent(key), 1, reason: '$key was blocked');
          expect(notices(key), 0, reason: '$key reported as blocked');
        }
      }
    }, skip: noNode);

    test('REST GETs the page makes are not blocked', () {
      for (final k in [
        'needed_get_media_info_rest',
        'needed_get_reels_media_rest',
        'needed_get_user_info_rest',
        'needed_get_feed_user',
        'needed_get_request_object_no_body',
      ]) {
        expect(sent(k), 1, reason: k);
        expect(notices(k), 0, reason: k);
      }
    }, skip: noNode);

    test(
      'the substring "seen" alone, in body, header, URL, name: not blocked',
      () {
        for (final k in [
          'needed_substring_seen_variables',
          'needed_header_substring_seen',
          'needed_url_substring_seen',
          'needed_username_called_seen',
        ]) {
          expect(sent(k), 1, reason: k);
          expect(notices(k), 0, reason: k);
        }
      },
      skip: noNode,
    );

    test('other hosts, big bodies and a GraphQL Request(stream) are fine', () {
      expect(sent('needed_non_instagram_host_stream'), 1);
      expect(sent('needed_large_body_900kb'), 1);
      // read through clone(), so no "unreadable" block
      expect(
        sent('needed_graphql_request_with_stream_body_is_read_not_blocked'),
        1,
      );
    }, skip: noNode);

    test('the one over-block: init.body ReadableStream to /api/graphql', () {
      // Documented: "ordinary queries have string bodies". If the web client
      // ever streams its bodies the plan ends in page_timeout (fail safe, not
      // a leak). Pinned so a change is noticed.
      expect(sent('needed_graphql_stream_body_is_blocked_by_rule'), 0);
      expect(notices('needed_graphql_stream_body_is_blocked_by_rule'), 1);
    }, skip: noNode);

    test('an error inside the hook blocks only GraphQL paths', () {
      expect(sent('fetch_init_getter_throws_on_non_graphql'), 1);
    }, skip: noNode);
  });

  // ------------------------------------------------------------- lifecycle
  final story = loadReal('story', '003_graphql.json');
  Map<String, Object?> leakBody() => {
    'data': {'xdt_mark_story_reel_seen': <String, Object?>{}},
  };

  group('QA2-F7 lease: released on EVERY path, never before the close', () {
    final cases = <String, Rig Function(FakeWebViewLease)>{
      'success': (l) => Rig(
        webViewLease: l,
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      ),
      'run timeout (20 s)': (l) => Rig(webViewLease: l, onLoad: (s, u) {}),
      'session invalid redirect': (l) => Rig(
        webViewLease: l,
        onLoad: emitting([
          const NavigationEvent(
            host: 'www.instagram.com',
            path: '/accounts/login/',
          ),
        ]),
      ),
      'seen leak': (l) => Rig(
        webViewLease: l,
        onLoad: emitting([hookResponse(leakBody(), name: seenName)]),
      ),
      'load error event': (l) =>
          Rig(webViewLease: l, onLoad: emitting([const LoadErrorEvent()])),
      'open throws': (l) =>
          Rig(webViewLease: l, openThrows: true, onLoad: emitting(const [])),
      'hook unsupported': (l) => Rig(
        webViewLease: l,
        documentStart: false,
        onLoad: emitting(const []),
      ),
      'clear throws': (l) => Rig(
        webViewLease: l,
        clearThrows: true,
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      ),
    };
    for (final e in cases.entries) {
      test(e.key, () async {
        final lease = FakeWebViewLease();
        final rig = e.value(lease);
        final f = rig.extractor.fetchStories(['user_1']);
        await rig.time.pump();
        if (e.key == 'run timeout (20 s)') {
          rig.timers.firstWhere((t) => t.duration.inSeconds == 20).fire();
        }
        await rig.time.drive(f);
        expect(lease.acquired, hasLength(1));
        expect(lease.released, lease.acquired, reason: 'released once');
        for (final s in rig.driver.sessions) {
          expect(s.disposed, isTrue, reason: 'session left open');
        }
      });
    }

    test('order: acquire, open, load, clear, dispose, release', () async {
      late Rig rig;
      final order = <String>[];
      final lease = _OrderLease(order);
      rig = Rig(
        webViewLease: lease,
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      );
      // The driver log and the lease calls are merged by the lease, which
      // snapshots the driver log when it is called.
      lease.driverLog = () => rig.driver.log;
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(lease.snapshots, [
        <String>[], // acquire: nothing opened yet
        ['open', 'load', 'clear', 'dispose'], // release: after the close
      ]);
      expect(order, ['acquire', 'release']);
    });

    test(
      'hook unsupported: no wipe, no load, lease before open only',
      () async {
        final lease = FakeWebViewLease();
        final rig = Rig(
          webViewLease: lease,
          documentStart: false,
          onLoad: emitting([hookResponse(story, name: storiesName)]),
        );
        await rig.run(rig.extractor.fetchStories(['user_1']));
        expect(rig.driver.log, ['open']);
        expect(rig.driver.sessions, isEmpty);
      },
    );
  });

  group('QA2-F7 RESIDUAL: a lease answer that arrives after the timeout', () {
    test(
      'tryAcquire answering true late is never released (needs a TTL)',
      () async {
        final answer = Completer<bool>();
        final lease = _SlowLease(answer);
        final rig = Rig(
          webViewLease: lease,
          cleanupTimeout: const Duration(milliseconds: 20),
          onLoad: emitting(const []),
        );
        final r = await rig.extractor.fetchStories(['user_1']);
        expect(r.failureOrNull, const UnknownFailure(null, 'webview_busy'));
        answer.complete(true); // the real lease is now held by page mode
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // The extractor no longer knows it: nothing releases it. The lease
        // contract's TTL is the only protection (T-015 must implement it).
        expect(lease.released, isEmpty);
      },
    );
  });

  group('QA2-F6 no leaked timers', () {
    void expectNoActiveTimers(Rig rig, String why) {
      for (final t in [...rig.timers, ...rig.openTimers]) {
        expect(t.isActive, isFalse, reason: '$why: ${t.duration} still active');
      }
    }

    test('success cancels the run, open, grace and settle timers', () async {
      final rig = Rig(
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      );
      await rig.run(rig.extractor.fetchStories(['user_1']));
      expectNoActiveTimers(rig, 'success');
      expect(rig.openTimers.single.cancelled, isTrue);
    });

    test(
      'tentative answer: the 20 s timer is cancelled after the grace',
      () async {
        final rig = Rig(
          onLoad: emitting([
            hookResponse(loadPage('reels_empty.json'), name: storiesName),
            const LoadStopEvent(),
          ]),
        );
        await rig.run(rig.extractor.fetchStories(['user_1']));
        expectNoActiveTimers(rig, 'grace');
      },
    );

    test('seen leak and open failure leave no active timer', () async {
      final a = Rig(
        onLoad: emitting([hookResponse(leakBody(), name: seenName)]),
      );
      await a.run(a.extractor.fetchStories(['user_1']));
      expectNoActiveTimers(a, 'leak');
      final b = Rig(openThrows: true, onLoad: emitting(const []));
      await b.run(b.extractor.fetchStories(['user_1']));
      expectNoActiveTimers(b, 'open throws');
    });

    test(
      'open timeout leaves no active timer once the open timer fired',
      () async {
        final gate = Completer<void>();
        final rig = Rig(openGate: gate, onLoad: emitting(const []));
        final f = rig.extractor.fetchStories(['user_1']);
        await rig.time.pump();
        rig.openTimers.single.fire();
        await f;
        expectNoActiveTimers(rig, 'open timeout');
        gate.complete();
        await rig.time.pump();
      },
    );

    test('a hung clear leaves no timer of the extractor active', () async {
      final rig = Rig(
        clearHangs: true,
        cleanupTimeout: const Duration(milliseconds: 20),
        onLoad: emitting([hookResponse(story, name: storiesName)]),
      );
      await rig.extractor.fetchStories(['user_1']);
      expectNoActiveTimers(rig, 'hung clear');
    });
  });

  group('QA2-F3 breaker scope', () {
    test('the default guard is the static SeenGuard.shared (per isolate)', () {
      final src = File('lib/page/page_extractor.dart').readAsStringSync();
      expect(src, contains('seenGuard = seenGuard ?? SeenGuard.shared'));
      final lease = File('lib/page/webview_lease.dart').readAsStringSync();
      expect(lease, contains('static final SeenGuard shared = SeenGuard();'));
      // nothing persists it: no storage import in the file
      expect(lease, isNot(contains('shared_preferences')));
      expect(lease, isNot(contains('dart:io')));
    });

    test('a new guard (new isolate / process) starts untripped', () {
      expect(SeenGuard().tripped, isFalse);
    });

    test('a tripped guard blocks story loads but not profile loads', () async {
      final guard = SeenGuard()..trip();
      final rig = Rig(
        seenGuard: guard,
        onLoad: emitting([hookResponse(realProfile(), name: profileName)]),
      );
      final s = await rig.run(rig.extractor.fetchStories(['user_1']));
      expect(s.failureOrNull, const UnknownFailure(null, 'seen_guard_tripped'));
      expect(rig.driver.sessions, isEmpty);
      final p = await rig.run(rig.extractor.resolveUser(fakeUser));
      expect(p, isA<Ok<RemoteUser>>());
    });

    test('T-015 (R2-F5): only an explicit reset clears the breaker; a '
        'refresh never does', () async {
      final g = SeenGuard()..trip();
      expect(g.tripped, isTrue);
      expect(await g.refresh(), isTrue);
      expect(g.tripped, isTrue);
      await g.reset();
      expect(g.tripped, isFalse);
      final src = File('lib/page/webview_lease.dart').readAsStringSync();
      // `_tripped = false`: the field initializer and reset(), nothing else.
      expect(RegExp('_tripped = false').allMatches(src), hasLength(2));
    });

    test('the leak trips the guard from a PROFILE load too', () async {
      final guard = SeenGuard();
      final rig = Rig(
        seenGuard: guard,
        onLoad: emitting([hookResponse(leakBody(), name: seenName)]),
      );
      await rig.run(rig.extractor.resolveUser(fakeUser));
      expect(guard.tripped, isTrue);
    });
  });
}

/// Records the lease calls and a snapshot of the driver log at each call.
final class _OrderLease implements WebViewLease {
  _OrderLease(this.events);
  final List<String> events;
  late List<String> Function() driverLog;
  final List<List<String>> snapshots = [];

  @override
  Future<bool> tryAcquire(String owner) async {
    events.add('acquire');
    snapshots.add(List.of(driverLog()));
    return true;
  }

  @override
  Future<void> release(String owner) async {
    events.add('release');
    snapshots.add(List.of(driverLog()));
  }
}

final class _SlowLease implements WebViewLease {
  _SlowLease(this.answer);
  final Completer<bool> answer;
  final List<String> released = [];

  @override
  Future<bool> tryAcquire(String owner) => answer.future;

  @override
  Future<void> release(String owner) async => released.add(owner);
}
