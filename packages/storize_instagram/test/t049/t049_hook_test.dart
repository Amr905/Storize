// T-049: the real hook.js against a fake page (Node): late modules,
// requireLazy, providers and tokens from captured requests. Synthetic values.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_instagram/page/page.dart';

const _origin = 'https://www.instagram.com';
const _pv = '__relay_internal__pv__PolarisZzFakeEnabled';

bool get _hasNode => Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  final noNode = _hasNode ? null : 'node is not installed';
  late Map<String, dynamic> res;
  setUpAll(() async {
    if (noNode != null) return;
    final r = await Process.run('node', [
      'test/t049/t049_harness.js',
      'assets/hook.js',
    ]);
    if (r.exitCode != 0) fail('harness failed: ${r.stderr}');
    res = jsonDecode(r.stdout as String) as Map<String, dynamic>;
  });
  Map<String, dynamic> s(String n) => res[n] as Map<String, dynamic>;
  List<Map<dynamic, dynamic>> list(Object? v) =>
      (v! as List).cast<Map<dynamic, dynamic>>();

  Map<dynamic, dynamic> firstOp(Map<dynamic, dynamic> m) =>
      (m['ops'] as List).first as Map<dynamic, dynamic>;

  group('late modules and retries', () {
    test('a doc_id alone does not end discovery: the later .graphql and '
        'tokens are merged and posted, then it stops', () {
      final r = s('late_modules');
      expect(r['early'], 1, reason: 'the doc_id alone is posted once');
      final msgs = list(r['msgs']);
      final last = msgs.last;
      final op = (last['ops'] as List).single as Map;
      expect(op['provided'], {_pv: true});
      expect(op['args'], ['username', 'data']);
      expect(op['src'], 'module');
      expect(last['tokens'], {'fb_dtsg': 'ZZFAKE_dtsg', 'lsd': 'ZZFAKE_lsd'});
      expect(r['after'], msgs.length, reason: 'complete: nothing more posted');
    }, skip: noNode);

    test('modules that appear only after 2 s are found by a later try', () {
      final r = s('modules_after_two_seconds');
      expect(r['early'], 0);
      final msgs = list(r['msgs']);
      expect(msgs, hasLength(1));
      expect(msgs.single['tokens'], {
        'fb_dtsg': 'ZZFAKE_dtsg2',
        'lsd': 'ZZFAKE_lsd2',
      }, reason: 'DTSGInitData is read too');
      expect(((msgs.single['ops'] as List).single as Map)['provided'], {
        _pv: false,
      });
    }, skip: noNode);

    test('requireLazy loads a missing .graphql module once, no API call', () {
      final r = s('require_lazy');
      expect(r['calls'], [
        ['PolarisProfilePostsQuery.graphql'],
      ]);
      final msgs = list(r['msgs']);
      expect(firstOp(msgs.first)['loaded'], isFalse);
      expect(firstOp(msgs.last)['provided'], {_pv: true});
      expect(r['sent'], {'fetch': 0, 'xhr': 0, 'beacon': 0});
    }, skip: noNode);

    test('a throwing requireLazy never breaks discovery', () {
      final msgs = list(s('require_lazy_throws')['msgs']);
      expect(msgs, hasLength(1));
      expect(msgs.single['tokens'], {'lsd': 'ZZFAKE_lsd'});
    }, skip: noNode);

    test('the number of discovery posts is capped', () {
      expect(s('cap')['count'], 10);
    }, skip: noNode);
  });

  group('captured requests', () {
    test('doc_id as the LAST form field is read without a trailing newline '
        '(why has_doc_id was 0), with providers, args and tokens', () {
      final cap = list(s('capture_urlencoded')['caps']).single;
      final req = cap['request'] as Map;
      expect(req['docId'], '33333333333333333');
      expect(RegExp(r'^\d{5,32}$').hasMatch(req['docId'] as String), isTrue);
      expect(req['provided'], {_pv: true}, reason: 'scalars only');
      expect(req['args'], ['username', 'data']);
      expect(req['vars'], isTrue);
      expect((req['tokens'] as Map)['fb_dtsg'], 'ZZFAKE_cap_dtsg');
      expect((req['tokens'] as Map)['lsd'], 'ZZFAKE_cap_lsd');
      expect((req['tokens'] as Map).containsKey('variables'), isFalse);
      // Dart accepts exactly this message.
      final m = parseHookMessage([
        {...cap, 'origin': _origin},
      ], pageOrigin: _origin);
      expect(m, isA<HookCapture>());
      final c = m as HookCapture;
      expect(c.docId, '33333333333333333');
      expect(c.docIdRejected, isFalse);
      expect(c.provided, {_pv: true});
    }, skip: noNode);

    test('providers and tokens from the capture complete discovery', () {
      final r = s('complete_from_captures');
      final msgs = list(r['msgs']);
      expect(r['before'], 1);
      final last = msgs.last;
      expect(firstOp(last)['provided'], {_pv: true});
      expect(firstOp(last)['src'], 'capture');
      expect(last['tokens'], {
        'fb_dtsg': 'ZZFAKE_cap_dtsg',
        'lsd': 'ZZFAKE_cap_lsd',
      });
      expect(last['tokenSources'], {'fb_dtsg': 'capture', 'lsd': 'capture'});
      expect(r['after'], msgs.length, reason: 'complete: no more posts');
    }, skip: noNode);

    test('multipart FormData and JSON bodies are read too', () {
      final caps = list(s('capture_formdata_and_json')['caps']);
      expect(caps, hasLength(2));
      for (final c in caps) {
        final req = c['request'] as Map;
        expect(req['docId'], '33333333333333333');
        expect(req['provided'], {_pv: true});
        expect((req['tokens'] as Map)['fb_dtsg'], 'ZZFAKE_cap_dtsg');
      }
    }, skip: noNode);

    test('doc_id from the URL query, lsd from the X-FB-LSD header', () {
      final req =
          list(s('capture_query_and_header')['caps']).single['request'] as Map;
      expect(req['docId'], '44444444444444');
      expect((req['tokens'] as Map)['lsd'], 'ZZFAKE_hdr_lsd');
      expect(req['provided'], isEmpty);
      expect(req['vars'], isTrue, reason: 'variables seen: none needed');
    }, skip: noNode);

    test('the seen mutation is still blocked and never sent', () {
      final r = s('seen_still_blocked');
      expect(r['sent'], {'fetch': 0, 'xhr': 0, 'beacon': 0});
      expect(r['blocked'], 1);
    }, skip: noNode);
  });
}
