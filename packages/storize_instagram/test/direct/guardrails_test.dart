// Source guardrails for T-013: no hard-coded doc_id, mappers independent of
// the transports, every governed call goes through RequestGovernor.run.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

List<File> _dart(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

void main() {
  test(
    'no long numeric literal (a doc_id or app id) in direct, mapper or probe',
    () {
      final longNumber = RegExp(r'(?<![\w.])\d{10,}(?![\w.])');
      for (final dir in ['lib/direct', 'lib/mapper', 'lib/probe']) {
        for (final f in _dart(dir)) {
          expect(longNumber.hasMatch(_read(f.path)), isFalse, reason: f.path);
        }
      }
    },
  );

  test('mappers import only the model: no transports, governor or dart:io', () {
    for (final f in _dart('lib/mapper')) {
      final imports = RegExp(
        "^import '([^']+)'",
        multiLine: true,
      ).allMatches(_read(f.path)).map((m) => m.group(1)!);
      for (final i in imports) {
        expect(
          i.startsWith('package:storize_model/') ||
              i.startsWith('package:storize_instagram/mapper/'),
          isTrue,
          reason: '${f.path} imports $i',
        );
      }
    }
  });

  test('only the extractor and the probe touch IgHttp.send, both inside '
      'governor.run (CDN checks excepted)', () {
    final senders = [
      for (final dir in ['lib/direct', 'lib/probe'])
        for (final f in _dart(dir))
          if (RegExp(r'_http\.send\(').hasMatch(_read(f.path)))
            f.path.split('/').last,
    ]..sort();
    expect(senders, ['direct_extractor.dart', 'ig_probe.dart']);
    expect(
      _read('lib/direct/direct_extractor.dart'),
      contains('_governor.run<'),
    );
    expect(_read('lib/probe/ig_probe.dart'), contains('_governor.run<'));
  });
}
