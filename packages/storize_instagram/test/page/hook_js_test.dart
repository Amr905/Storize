// Runs the REAL assets/hook.js in Node (test/page/hook_harness.js) to prove
// the seen-mutation blocking (UD-3): a blocked request is answered locally
// and never reaches the page's fetch / XHR / sendBeacon.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic>? _results;

Future<Map<String, dynamic>> _run() async {
  final r = await Process.run('node', [
    'test/page/hook_harness.js',
    'assets/hook.js',
  ]);
  if (r.exitCode != 0) fail('harness failed: ${r.stderr}');
  return jsonDecode(r.stdout as String) as Map<String, dynamic>;
}

bool get _hasNode => Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  final noNode = _hasNode ? null : 'node is not installed';
  late Map<String, dynamic> res;
  setUpAll(() async {
    if (noNode == null) _results ??= await _run();
    res = _results ?? {};
  });

  Map<String, dynamic> s(String name) => res[name] as Map<String, dynamic>;

  test('fetch of the seen mutation is answered locally, not sent', () {
    final r = s('fetch_seen_blocked');
    expect(r['sent'], 0);
    expect(r['status'], 200);
    expect((r['body'] as Map)['status'], 'ok');
    final msgs = r['handled'] as List;
    expect(msgs, hasLength(1));
    expect((msgs.first as Map)['type'], 'blocked');
    expect((msgs.first as Map)['friendlyName'], 'PolarisStoriesV3SeenMutation');
  }, skip: noNode);

  test('a URLSearchParams body and a relative URL are blocked too', () {
    expect(s('fetch_seen_urlsearchparams_blocked')['sent'], 0);
  }, skip: noNode);

  test('with no config the default list still blocks the mutation', () {
    expect(s('fetch_default_list_blocks_seen')['sent'], 0);
  }, skip: noNode);

  test('XHR of the seen mutation finishes locally and is not sent', () {
    final r = s('xhr_seen_blocked');
    expect(r['sent'], 0);
    expect(r['loaded'], isTrue);
    expect(r['status'], 200);
    expect(r['readyState'], 4);
    expect((jsonDecode(r['text'] as String) as Map)['status'], 'ok');
    expect(((r['handled'] as List).first as Map)['via'], 'xhr');
  }, skip: noNode);

  test('sendBeacon of the seen mutation is swallowed, others pass', () {
    final r = s('beacon_seen_blocked');
    expect(r['r1'], isTrue);
    expect(r['sent'], 1);
  }, skip: noNode);

  test('other queries pass through and are reported with their name', () {
    final r = s('fetch_other_passes_and_reports');
    expect(r['sent'], 1);
    final msg = (r['handled'] as List).single as Map;
    expect(msg.containsKey('type'), isFalse);
    expect(msg['friendlyName'], 'PolarisStoriesV3ReelPageStandaloneQuery');
    expect((msg['request'] as Map)['docId'], isNotEmpty);
    expect(
      ((msg['request'] as Map)['tokens'] as Map).keys,
      containsAll(['fb_dtsg', 'lsd']),
    );
    expect(
      ((msg['request'] as Map)['tokens'] as Map).keys,
      isNot(contains('doc_id')),
    );
    expect(s('xhr_other_passes')['sent'], 1);
  }, skip: noNode);

  test('request secrets and the body are sent only when configured', () {
    final msg =
        (s('fetch_no_secrets_when_not_configured')['handled'] as List).single
            as Map;
    expect(msg.containsKey('request'), isFalse);
    expect(msg.containsKey('body'), isFalse);
  }, skip: noNode);

  test('the blocked list is configurable and replaces the default', () {
    expect(s('custom_list_replaces_default')['sent'], ['seen']);
  }, skip: noNode);

  test('only instagram.com requests are blocked', () {
    expect(s('non_instagram_host_not_blocked')['sent'], 1);
  }, skip: noNode);

  test('hook.js never clicks, taps or scrolls (UD-3)', () {
    final src = File('assets/hook.js').readAsStringSync();
    for (final word in [
      '.click(',
      'scrollTo',
      'scrollBy',
      'TouchEvent',
      'MouseEvent',
      'PointerEvent',
      'KeyboardEvent',
      'querySelector',
    ]) {
      expect(src, isNot(contains(word)), reason: word);
    }
  });
}
