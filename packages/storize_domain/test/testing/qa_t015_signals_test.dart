// QA (T-015): the ContentSignals port stays pure Dart and value-only.
// ignore_for_file: unnecessary_raw_strings
import 'dart:io';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:test/test.dart';

void main() {
  test('port and fake import only meta and the port itself', () {
    for (final f in [
      'lib/src/ports/content_signals.dart',
      'lib/src/testing/fake_content_signals.dart',
    ]) {
      final imports = RegExp(
        r"^import '([^']+)'",
        multiLine: true,
      ).allMatches(File(f).readAsStringSync()).map((m) => m.group(1)!).toList();
      for (final i in imports) {
        expect(
          i == 'package:meta/meta.dart' ||
              i == 'package:storize_domain/src/ports/content_signals.dart',
          isTrue,
          reason: '$f imports $i',
        );
      }
      expect(
        File(f).readAsStringSync().toLowerCase(),
        isNot(contains('instagram')),
      );
    }
  });

  test('values: unequal snapshots differ, equal ones share a hash code', () {
    const a = ContentSignalsSnapshot(skippedMalformed: 1);
    const b = ContentSignalsSnapshot(pageModeUses: 1);
    expect(a == b, isFalse);
    expect(
      const ContentSignalsSnapshot(skippedMalformed: 1).hashCode,
      a.hashCode,
    );
  });

  test('the fake resets on every take and counts the takes', () {
    final f = FakeContentSignals()
      ..addSkippedMalformed(2)
      ..addPageModeUses(3);
    expect(
      f.takeSignals(),
      const ContentSignalsSnapshot(skippedMalformed: 2, pageModeUses: 3),
    );
    expect(f.takeSignals(), const ContentSignalsSnapshot());
    expect(f.takeCount, 2);
  });
}
