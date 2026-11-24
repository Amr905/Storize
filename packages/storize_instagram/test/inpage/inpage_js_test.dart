// Runs the REAL assets/inpage_query.js in Node (inpage_harness.js) with a
// fake window.require, document.cookie and fetch (T-050).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool get _hasNode => Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  final noNode = _hasNode ? null : 'node is not installed';
  late Map<String, dynamic> res;
  setUpAll(() {
    if (noNode != null) {
      res = {};
      return;
    }
    final r = Process.runSync('node', [
      'test/inpage/inpage_harness.js',
      'assets/inpage_query.js',
    ]);
    if (r.exitCode != 0) fail('harness failed: ${r.stderr}');
    res = jsonDecode(r.stdout as String) as Map<String, dynamic>;
  });

  test('the request has the shape of the web app POST', () {
    final r = res['request'] as Map;
    expect(r['n'], 1);
    expect(r['url'], '/api/graphql');
    expect(r['method'], 'POST');
    expect(r['credentials'], 'include');
    final h = r['headers'] as Map;
    expect(h['X-FB-LSD'], 'ZZFAKE_lsd');
    expect(h['X-CSRFToken'], 'ZZcsrf');
    expect(h['X-IG-App-ID'], isNotEmpty);
    expect(h['X-FB-Friendly-Name'], 'PolarisProfilePostsQuery');
    final f = r['form'] as Map;
    expect(f['av'], '900001');
    expect(f['fb_dtsg'], 'ZZFAKE_dtsg');
    expect(f['doc_id'], '111');
    expect(f['fb_api_req_friendly_name'], 'PolarisProfilePostsQuery');
    expect(f['server_timestamps'], 'true');
    // The variables are the caller's plus the provided relay values.
    expect((f['variables'] as Map)['username'], 'zzfake');
    expect((f['variables'] as Map)['__relay_internal__pv__X'], true);
    expect(res['ok'], {
      'status': 200,
      'json': {
        'data': {'ok': 1},
      },
    });
  }, skip: noNode);

  test('mutations, seen names and unknown names are refused unsent', () {
    final rejected = res['rejected'] as Map;
    expect(rejected, isNotEmpty);
    for (final e in rejected.entries) {
      expect((e.value as Map)['r'], {'error': 'not_allowed'}, reason: e.key);
      expect((e.value as Map)['sent'], 0, reason: e.key);
    }
    expect(res['nonstring'], {'error': 'not_allowed'});
  }, skip: noNode);

  test('bad variables are refused', () {
    expect(res['badvars'], {'error': 'bad_variables'});
    expect(res['badjson'], {'error': 'bad_variables'});
  }, skip: noNode);

  test('a for (;;); body is stripped and gives the error code', () {
    expect(res['shielded'], {
      'status': 200,
      'shielded': true,
      'fbError': 1357054,
      'json': {'error': 1357054},
    });
  }, skip: noNode);

  test('failure paths: bad json, network, http status passes through', () {
    expect((res['bad_json_reply'] as Map)['error'], 'bad_json');
    expect(res['network'], {'error': 'network'});
    expect((res['status429'] as Map)['status'], 429);
  }, skip: noNode);

  test('a missing module is force-loaded with requireLazy', () {
    expect((res['lazy'] as Map)['status'], 200);
    expect(res['lazy_requested'], [
      'PolarisProfileStoryHighlightsTrayContentQuery_instagramRelayOperation',
      'PolarisProfileStoryHighlightsTrayContentQuery.graphql',
    ]);
    expect(res['lazy_doc'], '333');
  }, skip: noNode);

  test('unavailable codes: no lazy loader, no require, no tokens/cookies', () {
    expect(res['no_lazy_unavailable'], {
      'error': 'unavailable:operation_module',
    });
    expect(res['no_require'], {'error': 'unavailable:require'});
    expect(res['no_tokens'], {'error': 'unavailable:tokens'});
    expect(res['no_cookies'], {'error': 'unavailable:cookies'});
  }, skip: noNode);

  test('readiness needs both tokens and both cookies', () {
    expect((res['ready'] as Map)['ready'], isTrue);
    expect((res['ready'] as Map)['modules'], 2);
    expect((res['ready_nocookie'] as Map)['ready'], isFalse);
    expect((res['ready_notoken'] as Map)['ready'], isFalse);
  }, skip: noNode);
}
