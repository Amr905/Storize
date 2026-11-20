// The barrels are not edited by this task, so the new files are imported
// directly until the Lead exports them.
import 'package:storize_domain/src/ports/content_signals.dart';
import 'package:storize_domain/src/testing/fake_content_signals.dart';
import 'package:test/test.dart';

void main() {
  group('ContentSignalsSnapshot', () {
    test('defaults to zero', () {
      const s = ContentSignalsSnapshot();
      expect(s.skippedMalformed, 0);
      expect(s.pageModeUses, 0);
    });

    test('has value equality and a readable toString', () {
      expect(
        const ContentSignalsSnapshot(skippedMalformed: 2, pageModeUses: 1),
        const ContentSignalsSnapshot(skippedMalformed: 2, pageModeUses: 1),
      );
      expect(
        const ContentSignalsSnapshot(skippedMalformed: 2).hashCode,
        const ContentSignalsSnapshot(skippedMalformed: 2).hashCode,
      );
      expect(
        const ContentSignalsSnapshot(skippedMalformed: 2),
        isNot(const ContentSignalsSnapshot(pageModeUses: 2)),
      );
      expect(
        const ContentSignalsSnapshot(skippedMalformed: 2).toString(),
        contains('skippedMalformed: 2'),
      );
    });
  });

  group('FakeContentSignals', () {
    test('takeSignals returns the counts and resets them', () {
      final ContentSignals fake = FakeContentSignals();
      final f = fake as FakeContentSignals
        ..addSkippedMalformed(2)
        ..addSkippedMalformed(1)
        ..addPageModeUses(1);
      expect(
        fake.takeSignals(),
        const ContentSignalsSnapshot(skippedMalformed: 3, pageModeUses: 1),
      );
      expect(fake.takeSignals(), const ContentSignalsSnapshot());
      expect(f.takeCount, 2);
    });
  });
}
