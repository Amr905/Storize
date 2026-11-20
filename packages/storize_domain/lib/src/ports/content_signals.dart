import 'package:meta/meta.dart';

/// Out-of-band signals from the last platform calls (read-and-reset).
///
/// `ContentPlatform` returns `Result`s and cannot carry everything a caller
/// needs to know. This port adds counters next to it: RunCheck reads it around
/// a check and turns the numbers into activity events (EC-14, `PAGE_MODE_USED`,
/// `check_run.mode`) without a change to `ContentPlatform`.
///
/// The pattern "take, call, take" gives the signals of exactly that call, as
/// long as calls of one account run one at a time (the request governor
/// guarantees this).
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class ContentSignals {
  /// Returns the signals counted since the last call and resets them to zero.
  ContentSignalsSnapshot takeSignals();
}

/// The counters returned by [ContentSignals.takeSignals]. Values only: no
/// ids, names or URLs.
@immutable
final class ContentSignalsSnapshot {
  /// Creates a snapshot. Both counters default to zero.
  const ContentSignalsSnapshot({
    this.skippedMalformed = 0,
    this.pageModeUses = 0,
  });

  /// Timeline edges that were left out because their `pk` or `taken_at` was
  /// missing or broken. A value above 0 right after a post check means the
  /// response shape may have changed (EC-14): the newest post could be among
  /// the skipped ones.
  final int skippedMalformed;

  /// How many times page mode was used (TECH_SPEC §4.1 `PAGE_MODE_USED`).
  final int pageModeUses;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentSignalsSnapshot &&
          other.skippedMalformed == skippedMalformed &&
          other.pageModeUses == pageModeUses);

  @override
  int get hashCode => Object.hash(skippedMalformed, pageModeUses);

  @override
  String toString() =>
      'ContentSignalsSnapshot(skippedMalformed: $skippedMalformed, '
      'pageModeUses: $pageModeUses)';
}
