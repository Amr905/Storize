// ignore: until the Lead exports it from the barrel.
import 'package:storize_domain/storize_domain.dart';

/// Counters that `InstagramPlatform` fills while it works. Values only: no ids,
/// names or URLs.
///
/// Calls of one account run one at a time (the governor), so the pattern
/// "take, call, take" gives the signals of exactly that call. The snapshot is
/// the domain `ContentSignalsSnapshot`.
final class PlatformSignals {
  int _skipped = 0;
  int _pageUses = 0;

  /// Adds [count] skipped timeline edges.
  void addSkippedMalformed(int count) {
    if (count > 0) _skipped += count;
  }

  /// Notes one use of page mode.
  void addPageModeUse() => _pageUses++;

  /// Returns the counters since the last call and resets them.
  ContentSignalsSnapshot take() {
    final snapshot = ContentSignalsSnapshot(
      skippedMalformed: _skipped,
      pageModeUses: _pageUses,
    );
    _skipped = 0;
    _pageUses = 0;
    return snapshot;
  }
}
