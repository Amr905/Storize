// Source guardrails for T-014.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dart(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

String _read(String p) => File(p).readAsStringSync();

void main() {
  test('only webview.dart imports flutter_inappwebview or flutter', () {
    for (final f in _dart('lib/page')) {
      final src = _read(f.path);
      final isAdapter = f.path.endsWith('webview.dart');
      expect(src.contains('flutter_inappwebview'), isAdapter, reason: f.path);
      if (!isAdapter) {
        expect(
          src,
          isNot(contains("import 'package:flutter/")),
          reason: f.path,
        );
        expect(src, isNot(contains("import 'dart:io'")), reason: f.path);
      }
    }
  });

  test('page.dart does not export the WebView adapter', () {
    final exports = _read('lib/page/page.dart')
        .split('\n')
        .where((l) => l.startsWith('export'));
    expect(exports.where((l) => l.contains('webview.dart')), isEmpty);
  });

  test('the pin matches the app and the lock', () {
    final app = RegExp(r'flutter_inappwebview:\s*(\S+)')
        .firstMatch(_read('../../app/pubspec.yaml'))!
        .group(1);
    final pkg = RegExp(r'flutter_inappwebview:\s*(\S+)')
        .firstMatch(_read('pubspec.yaml'))!
        .group(1);
    expect(pkg, app);
    expect(app, '6.2.0-beta.3');
  });

  test('no long numeric literal (doc_id) and no doc_id value in lib/page', () {
    final longNumber = RegExp(r'(?<![\w.])\d{10,}(?![\w.])');
    for (final f in _dart('lib/page')) {
      expect(longNumber.hasMatch(_read(f.path)), isFalse, reason: f.path);
    }
  });

  test('the extractor starts governed work only through governor.run with '
      'cost pageLoad, and nothing is started unawaited inside', () {
    final src = _read('lib/page/page_extractor.dart');
    expect(RegExp(r'_governor\.run<').allMatches(src), hasLength(1));
    expect(src, contains('cost: RequestCost.pageLoad,'));
    expect(src, isNot(contains('RequestCost.api')));
    expect(src, isNot(contains('unawaited(')));
    // `_drive` (the governed closure body) never calls a governed method.
    final drive = src.substring(src.indexOf('Future<Result<T>> _drive<T>'));
    for (final m in ['_load(', '_governor', 'resolveUser(', 'fetchStories(']) {
      expect(drive.contains(m), isFalse, reason: m);
    }
  });

  test('page mode never interacts with the page UI (UD-3)', () {
    for (final f in _dart('lib/page')) {
      final src = _read(f.path).replaceAll(RegExp('///.*'), '');
      for (final w in [
        '.click(',
        'scrollTo',
        'scrollBy',
        'tap(',
        'evaluateJavascript',
      ]) {
        if (f.path.endsWith('webview.dart') &&
            (w == 'evaluateJavascript' || w == 'scrollBy')) {
          continue; // only the read-only domCollectScript
        }
        expect(src.contains(w), isFalse, reason: '${f.path} $w');
      }
    }
    final adapter = _read('lib/page/webview.dart');
    expect(
      RegExp('evaluateJavascript').allMatches(adapter),
      hasLength(1),
    );
    expect(adapter, contains('source: domCollectScript'));
    // The one scroll (T-041 post history): `PageSession.scrollDown` only.
    expect(RegExp('scrollBy').allMatches(adapter), hasLength(1));
  });

  test('no hard-coded doc_id: the page supplies it', () {
    for (final f in _dart('lib/page')) {
      expect(
        _read(f.path),
        isNot(matches(RegExp(r'''doc_id['"]?\s*[:=]\s*['"]\d'''))),
      );
    }
  });
}
