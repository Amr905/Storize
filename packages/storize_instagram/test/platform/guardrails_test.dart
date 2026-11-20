// Source guardrails for T-015: layering, governor discipline, no URLs or
// secrets in logs, no hard-coded ids.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dart(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

/// Source without comments, so a doc sentence cannot trip a check.
String _code(String path) =>
    File(
          path,
        )
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trim().startsWith('//'))
        .join('\n');

List<File> get _newFiles => [
  ..._dart('lib/media'),
  ..._dart('lib/platform'),
  File('lib/instagram_platform.dart'),
];

void main() {
  test('the new code is pure Dart: no Flutter, no WebView plugin', () {
    for (final f in _newFiles) {
      final src = _code(f.path);
      expect(src, isNot(contains("import 'package:flutter/")), reason: f.path);
      expect(src, isNot(contains('flutter_inappwebview')), reason: f.path);
      expect(src, isNot(contains('page/webview.dart')), reason: f.path);
    }
  });

  test('dart:io is used only by the real CDN client', () {
    for (final f in _newFiles) {
      final uses = _code(f.path).contains("import 'dart:io'");
      expect(uses, f.path.endsWith('dart_io_cdn_http.dart'), reason: f.path);
    }
  });

  test('the media download path has no governor, session or cookie', () {
    for (final f in _dart('lib/media')) {
      final src = _code(f.path);
      for (final w in [
        'RequestGovernor',
        'governor',
        'IgSession',
        'SessionStore',
        'Cookie',
        'cookie',
        'X-CSRFToken',
      ]) {
        expect(src.contains(w), isFalse, reason: '${f.path} has $w');
      }
    }
  });

  test('the platform class makes no governed call and starts nothing '
      'unawaited', () {
    final src = _code('lib/instagram_platform.dart');
    expect(src.contains('.run<'), isFalse);
    expect(src.contains('RequestCost'), isFalse);
    expect(src.contains('unawaited('), isFalse);
  });

  test('page mode is reached from exactly one place, after SchemaChanged', () {
    final src = _code('lib/instagram_platform.dart');
    expect(RegExp(r'_guarded\(page\)').allMatches(src), hasLength(1));
    final run = src.substring(src.indexOf('Future<Result<T>> _run<T>'));
    final gate = run.indexOf('is! SchemaChanged');
    final call = run.indexOf('_guarded(page)');
    expect(gate, greaterThan(-1));
    expect(call, greaterThan(gate));
  });

  test('no log call interpolates a URL, host, name or value', () {
    for (final f in _newFiles) {
      final src = _code(f.path);
      for (final m in RegExp(
        r'_?log\??\.log\(([^;]*?)\);',
        dotAll: true,
      ).allMatches(src)) {
        final call = m.group(1)!;
        for (final bad in [
          r'$url',
          r'$_url',
          r'$uri',
          r'$username',
          r'$name',
        ]) {
          expect(call.contains(bad), isFalse, reason: '${f.path}: $call');
        }
      }
    }
  });

  test('no long numeric literal (doc_id) in the new code', () {
    final longNumber = RegExp(r'(?<![\w.])\d{10,}(?![\w.])');
    for (final f in _newFiles) {
      expect(longNumber.hasMatch(_code(f.path)), isFalse, reason: f.path);
    }
  });

  test('the CDN allowlist rule matches the T-013 probe rule', () {
    final probe = File('lib/probe/ig_probe.dart').readAsStringSync();
    final policy = File('lib/media/cdn_policy.dart').readAsStringSync();
    expect(probe, contains("['cdninstagram.com', 'fbcdn.net']"));
    expect(policy, contains("['cdninstagram.com', 'fbcdn.net']"));
  });

  test('the lease and the breaker store have no Instagram or session code', () {
    for (final name in [
      'lib/platform/governor_webview_lease.dart',
      'lib/platform/seen_breaker_store.dart',
    ]) {
      final src = _code(name);
      expect(src.contains('SessionStore'), isFalse, reason: name);
      expect(src.contains('doc_id'), isFalse, reason: name);
    }
  });
}
