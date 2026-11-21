// ignore: until the Lead exports it from the barrel.
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Counters that `InstagramPlatform` fills while it works. Values only: no ids,
/// names or URLs.
///
/// Calls of one account run one at a time (the governor), so the pattern
/// "take, call, take" gives the signals of exactly that call. The snapshot is
/// the domain `ContentSignalsSnapshot`.
final class PlatformSignals {
  int _skipped = 0;
  int _pageUses = 0;

  /// The partial stories record, set by the platform; read it with
  /// [takePartialStories].
  PartialStories? partialStories;

  /// Adds [count] skipped timeline edges.
  void addSkippedMalformed(int count) {
    if (count > 0) _skipped += count;
  }

  /// Notes one use of page mode.
  void addPageModeUse() => _pageUses++;

  /// Returns the partial stories of the last failed multi-user page call and
  /// clears them; null when there are none.
  PartialStories? takePartialStories() {
    final partial = partialStories;
    partialStories = null;
    return partial;
  }

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

/// What a multi-user page-mode stories call had loaded when it failed (T-015a
/// F1). The call itself returns the failure (the port's `Result` cannot say
/// "some"); the loaded data is kept here so the caller does not lose it.
final class PartialStories {
  /// Creates the record.
  const PartialStories({required this.loaded, required this.skipped});

  /// The stories of the users that were loaded, by remote user id (users
  /// without story items are left out, as in a full result).
  final Map<String, List<RemoteContent>> loaded;

  /// How many users were not loaded: the one that failed and every one after
  /// it.
  final int skipped;
}
