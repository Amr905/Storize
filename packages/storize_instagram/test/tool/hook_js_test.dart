// QA: hook.js must not forward cookies or bodies when includeBody is false.
// Runs the real asset under Node with a mocked browser (FAKE data). Skipped
// when Node is not installed.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<List<dynamic>> _run(bool includeBody) async {
  final r = await Process.run('node', [
    'test/tool/hook_harness.js',
    'assets/hook.js',
    '$includeBody',
  ]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return jsonDecode('${r.stdout}'.trim()) as List<dynamic>;
}

void main() {
  final hasNode = Process.runSync('node', ['--version']).exitCode == 0;

  test(
    'includeBody=false: no body, no cookies, only summary fields',
    skip: hasNode ? null : 'node not installed',
    () async {
      final sent = await _run(false);
      expect(sent, hasLength(1), reason: 'only the instagram.com fetch');
      final msg = (sent.single as Map)['msg'] as Map;
      expect(msg.containsKey('body'), isFalse);
      expect(msg.keys.toSet(), {
        'url',
        'status',
        'bodyLength',
        'topLevelKeys',
        'origin',
        'via',
      });
      final text = jsonEncode(sent);
      expect(text, isNot(contains('ZZFAKEbodysecret')));
      expect(text, isNot(contains('ZZFAKEdocumentcookie')));
      expect(text, isNot(contains('ZZFAKEcsrf')));
      expect(msg['topLevelKeys'], contains('reels_media'));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'includeBody=true (T-014 only) is the sole way a body is sent',
    skip: hasNode ? null : 'node not installed',
    () async {
      final sent = await _run(true);
      final msg = (sent.single as Map)['msg'] as Map;
      expect(msg['body'], contains('reels_media'));
      expect(jsonEncode(sent), isNot(contains('ZZFAKEdocumentcookie')));
    },
  );

  // QA-7: the reported url carries no query string unless includeBody.
  test('QA-7 reported url should not carry the query string', () async {
    final sent = await _run(false);
    final msg = (sent.single as Map)['msg'] as Map;
    expect('${msg['url']}', isNot(contains('?')));
  });

  test(
    'includeBody=true (T-014) keeps the full URL, for the mapper',
    skip: hasNode ? null : 'node not installed',
    () async {
      final sent = await _run(true);
      final msg = (sent.single as Map)['msg'] as Map;
      expect('${msg['url']}', contains('?'));
    },
  );
}
