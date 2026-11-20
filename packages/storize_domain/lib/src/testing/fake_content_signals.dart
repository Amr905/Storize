import 'package:storize_domain/src/ports/content_signals.dart';

/// An in-memory [ContentSignals] for tests: add counts, then read and reset.
final class FakeContentSignals implements ContentSignals {
  int _skipped = 0;
  int _pageUses = 0;

  /// How many times [takeSignals] was called.
  int takeCount = 0;

  /// Adds [count] skipped malformed timeline edges.
  void addSkippedMalformed(int count) => _skipped += count;

  /// Adds [count] page-mode uses.
  void addPageModeUses(int count) => _pageUses += count;

  @override
  ContentSignalsSnapshot takeSignals() {
    takeCount++;
    final snapshot = ContentSignalsSnapshot(
      skippedMalformed: _skipped,
      pageModeUses: _pageUses,
    );
    _skipped = 0;
    _pageUses = 0;
    return snapshot;
  }
}
