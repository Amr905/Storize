// T-060 (FR-80): PolarisPostRootQuery is on both allowlists (Node harness on
// the real script), and the platform reads a post or highlight by link in
// the page, through the governor, with no direct HTTP.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import '../direct/support.dart' show loadSynthetic;
import '../inpage/rig.dart';

const ExtractionPolicy _policy = ExtractionPolicy.directThenPage;

bool get _hasNode => Process.runSync('node', ['--version']).exitCode == 0;

Map<String, Object?> _json(Object? v) =>
    jsonDecode(jsonEncode(v)) as Map<String, Object?>;

Object? _answer(String name, Map<String, Object?> vars) => switch (name) {
  'PolarisPostRootQuery' => script(
    _json(loadSynthetic('shortcode_web_info.json')),
  ),
  'PolarisStoriesV3ReelPageStandaloneQuery' => script(_highlight()),
  _ => {'error': 'unavailable:operation_module'},
};

Map<String, Object?> _highlight() {
  final body = _json(loadSynthetic('highlight_reel.json'));
  final reels =
      ((body['data']! as Map)['xdt_api__v1__feed__reels_media']!
              as Map)['reels_media']!
          as List;
  ((reels.first as Map)['user']! as Map)['username'] = 'zzfake_user_a';
  return body;
}

void main() {
  group('allowlist (node harness, real script)', () {
    late Map<String, dynamic> res;
    final noNode = _hasNode ? null : 'node is not installed';
    setUpAll(() {
      if (noNode != null) {
        res = {};
        return;
      }
      final r = Process.runSync('node', [
        'test/link/t060_harness.js',
        'assets/inpage_query.js',
      ]);
      if (r.exitCode != 0) fail('harness failed: ${r.stderr}');
      res = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    });

    test('the script runs the query with the page providers', () {
      final req = res['request'] as Map;
      expect(req['n'], 1);
      expect(req['url'], '/api/graphql');
      expect(req['method'], 'POST');
      expect(req['friendly'], 'PolarisPostRootQuery');
      final f = req['form'] as Map;
      expect(f['doc_id'], '444');
      expect(f['fb_api_req_friendly_name'], 'PolarisPostRootQuery');
      final vars = (f['variables'] as Map).cast<String, Object?>();
      expect(vars['shortcode'], 'ZZFAKE_c1');
      expect(vars['include_longform_landscape_cover'], false);
      expect(
        vars.keys.where((k) => k.startsWith('__relay_internal__')),
        hasLength(6),
      );
      expect((res['ok'] as Map)['status'], 200);
    }, skip: noNode);

    test('near-miss, mutation and seen names are refused unsent', () {
      final rejected = (res['rejected'] as Map).cast<String, Object?>();
      expect(rejected, hasLength(4));
      for (final e in rejected.entries) {
        expect((e.value! as Map)['r'], {'error': 'not_allowed'}, reason: e.key);
        expect((e.value! as Map)['sent'], 0, reason: e.key);
      }
    }, skip: noNode);

    test('the script and the Dart allowlist are the same set', () {
      expect(
        (res['allowlist'] as List).cast<String>().toSet(),
        inPageQueryAllowlist,
      );
    }, skip: noNode);
  });

  group('Dart allowlist', () {
    test('allows the query, still refuses Mutation and Seen', () {
      expect(inPageQueryAllowed('PolarisPostRootQuery'), isTrue);
      expect(inPageQueryAllowed('PolarisPostRootMutation'), isFalse);
      expect(inPageQueryAllowed('PolarisPostRootSeenQuery'), isFalse);
      expect(inPageQueryAllowed('PolarisPostRoot'), isFalse);
    });
  });

  group('platform', () {
    test(
      'a post by shortcode: one governed in-page query, no direct HTTP',
      () async {
        final rig = InPageRig(handler: _answer);
        final r = await rig.run(
          rig.platform.fetchPostByShortcode('ZZFAKE_c_link', policy: _policy),
        );
        final items = (r as Ok<LinkedItems>).value;
        expect(items.user.username, 'zzfake_user_a');
        expect(items.items.single.shortcode, 'ZZFAKE_c_link');
        expect(rig.driver.sessions.single.queries, ['PolarisPostRootQuery']);
        expect(rig.http.requests, isEmpty);
        expect(rig.driver.loads, 1);
        // The page load (3) and one query (1) went through the governor.
        expect(await rig.governor.remainingTokens(1), closeTo(2, 0.01));
      },
    );

    test('a removed post is TargetNotFound', () async {
      final rig = InPageRig(
        handler: (n, v) => script({
          'data': {
            'xdt_api__v1__media__shortcode__web_info': {'items': <Object?>[]},
          },
        }),
      );
      final r = await rig.run(
        rig.platform.fetchPostByShortcode('ZZFAKE_c_link', policy: _policy),
      );
      expect(r.failureOrNull, isA<TargetNotFound>());
    });

    test('a highlight with its owner', () async {
      final rig = InPageRig(handler: _answer);
      final r = await rig.run(
        rig.platform.fetchHighlightWithOwner('ZZFAKE_hl_1', policy: _policy),
      );
      final items = (r as Ok<LinkedItems>).value;
      expect(items.user.remoteUserId, 'ZZFAKE_user_a');
      expect(items.items, isNotEmpty);
      expect(
        rig.driver.sessions.single.queries,
        ['PolarisStoriesV3ReelPageStandaloneQuery'],
      );
    });

    test('a rate limit status is passed on', () async {
      final rig = InPageRig(
        handler: (n, v) => script({'message': 'wait'}, status: 429),
      );
      final r = await rig.run(
        rig.platform.fetchPostByShortcode('ZZFAKE_c_link', policy: _policy),
      );
      expect(r.failureOrNull, isA<RateLimited>());
    });

    test(
      'with the page unavailable it fails cleanly, nothing sent direct',
      () async {
        final rig = InPageRig(
          handler: (n, v) => {'error': 'unavailable:graphql_module'},
        );
        final r = await rig.run(
          rig.platform.fetchPostByShortcode('ZZFAKE_c_link', policy: _policy),
        );
        expect(r.failureOrNull, isA<UnknownFailure>());
        expect(rig.http.requests, isEmpty);
      },
    );
  });
}
