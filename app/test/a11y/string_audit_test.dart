// T-038 string audit: no hard-coded user-facing copy in app/lib (outside
// l10n/). Scans Text(...), tooltip:, semanticsLabel: and label: literals.
// A literal is allowed when it has no letters once interpolations are removed
// (numbers, separators, account handles such as '@$name'), or when it lives in
// the allowlisted developer-only inspector.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _literal = r'''(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")''';

final _patterns = <RegExp>[
  RegExp(r'\bText\(\s*' + _literal),
  RegExp(r'\btooltip:\s*' + _literal),
  RegExp(r'\bsemanticsLabel:\s*' + _literal),
  RegExp(r'\blabel:\s*' + _literal),
];

/// Path prefixes (relative to app/lib) whose literals are not user-facing.
/// debug/ is the developer WebView inspector (main_debug_inspector.dart only).
/// startup_error.dart is the screen shown when the app could not start: it
/// must not depend on anything that may have failed, so it stays plain
/// English (a fallback screen, not regular UI).
const _allowedDirs = ['l10n/', 'debug/', 'startup_error.dart'];

final _hasLetters = RegExp(r'\p{L}', unicode: true);
final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');

/// Returns `file:line: literal` for every violation under [libDir].
List<String> scanForHardCodedStrings(String libDir) {
  final root = Directory(libDir);
  final found = <String>[];
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final rel = file.path
        .substring(root.path.length)
        .replaceFirst(RegExp(r'^[/\\]+'), '')
        .replaceAll(RegExp(r'\\'), '/');
    if (_allowedDirs.any(rel.startsWith)) continue;
    final text = file.readAsStringSync();
    for (final pattern in _patterns) {
      for (final match in pattern.allMatches(text)) {
        final literal = match.group(0)!;
        final lit = literal.substring(literal.indexOf(RegExp('[\'"]')));
        final visible = lit.replaceAll(_interpolation, '');
        if (!_hasLetters.hasMatch(visible)) continue;
        final line = '\n'.allMatches(text.substring(0, match.start)).length + 1;
        found.add('$rel:$line: $lit');
      }
    }
  }
  return found;
}

void main() {
  test('scanner catches a hard-coded Text literal (self-check)', () {
    expect(_patterns.any((p) => p.hasMatch("Text('Save changes')")), isTrue);
    expect(_patterns.any((p) => p.hasMatch("tooltip: 'Clear list'")), isTrue);
    // Non-copy literals are allowed by the letter rule.
    expect(
      scanForHardCodedStrings('lib').where((f) => f.contains("'@")),
      isEmpty,
    );
  });

  test('no hard-coded user-facing strings in app/lib (outside l10n/)', () {
    final found = scanForHardCodedStrings('lib');
    expect(
      found,
      isEmpty,
      reason:
          'Move these to app_en.arb (or add a justified allowlist entry):\n'
          '${found.join('\n')}',
    );
  });
}
