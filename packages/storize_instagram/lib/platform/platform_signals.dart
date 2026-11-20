/// What the platform noticed since the last [PlatformSignals.take]: counters
/// the caller (RunCheck, T-017) turns into activity events without a change to
/// the `ContentPlatform` port.
final class PlatformSignalsSnapshot {
  /// Creates a snapshot.
  const PlatformSignalsSnapshot({
    this.skippedMalformed = 0,
    this.pageModeUses = 0,
  });

  /// Timeline edges direct mode left out because `pk` or `taken_at` was
  /// missing or broken (T-013 N3). A value above 0 right after a post check
  /// means Instagram may have changed the shape (EC-14): the newest post could
  /// be among the skipped ones.
  final int skippedMalformed;

  /// How many times page mode was used (TECH_SPEC §4.1 `PAGE_MODE_USED`).
  final int pageModeUses;

  @override
  String toString() =>
      'PlatformSignalsSnapshot(skippedMalformed: $skippedMalformed, '
      'pageModeUses: $pageModeUses)';
}

/// Counters that `InstagramPlatform` fills while it works. Values only: no ids,
/// names or URLs.
///
/// Calls of one account run one at a time (the governor), so the pattern
/// "take, call, take" gives the signals of exactly that call.
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
  PlatformSignalsSnapshot take() {
    final snapshot = PlatformSignalsSnapshot(
      skippedMalformed: _skipped,
      pageModeUses: _pageUses,
    );
    _skipped = 0;
    _pageUses = 0;
    return snapshot;
  }
}
