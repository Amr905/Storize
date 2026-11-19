import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/content_with_media.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/repos/check_run_repo.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/settings_repo.dart';
import 'package:storize_domain/src/usecases/delete_content.dart';
import 'package:storize_model/storize_model.dart';

/// Why [ApplyRetention] deleted nothing.
enum RetentionSkip {
  /// `retentionDays` is null: keep forever (FR-54, A-9).
  disabled,

  /// The clock looks wrong (see [ApplyRetention]). Nothing was deleted.
  clockSkew,
}

/// The outcome of [ApplyRetention].
@immutable
final class RetentionResult {
  /// Creates a result.
  const RetentionResult({
    this.skipped,
    this.deletion,
    this.skippedFutureDated = 0,
  });

  /// Set when the run did nothing on purpose.
  final RetentionSkip? skipped;

  /// What was deleted. Null when [skipped] is set.
  final DeleteContentResult? deletion;

  /// Candidates left alone because `detectedAt` or a `downloadedAt` lies after
  /// `now` (a stale timestamp from a bad clock). They are not deleted and do
  /// not block the rest of the run.
  final int skippedFutureDated;

  @override
  String toString() =>
      'RetentionResult(skipped: $skipped, futureDated: $skippedFutureDated, '
      '$deletion)';
}

/// Whether [item] may be deleted by retention for [cutoff] (`now - N days`).
///
/// The age of an item is how long Storize has had it, not when it was posted:
/// it is eligible only when `postedAt`, `detectedAt` and the latest
/// `downloadedAt` of its media are all strictly before [cutoff]. A post made
/// 10 days ago and downloaded today is therefore kept for N days from today.
///
/// Pure. `ApplyRetention` uses it, and the Settings preview ("X items, Y MB")
/// must use it too so the preview matches what will be deleted.
bool isRetentionEligible(ContentWithMedia item, DateTime cutoff) =>
    item.content.postedAt.isBefore(cutoff) &&
    _lastSeenByStorize(item).isBefore(cutoff);

DateTime _lastSeenByStorize(ContentWithMedia item) {
  var latest = item.content.detectedAt;
  for (final m in item.media) {
    final d = m.downloadedAt;
    if (d != null && d.isAfter(latest)) latest = d;
  }
  return latest;
}

/// Deletes content older than `retentionDays` days, files first (FR-54, BR-9).
///
/// - **Age basis:** how long Storize has had the item (see
///   [isRetentionEligible]): `max(detectedAt, latest downloadedAt)` must be
///   before `now - N days`, strictly. `ContentRepo.olderThan` pre-filters by
///   `postedAt`; since an item is posted before it is detected, the extra
///   check can only narrow that set. Exactly N days old is kept, N days and
///   1 ms is deleted.
/// - `retentionDays` null means off. A non-positive value is treated as off
///   too, for safety (`AppSettings` already forbids it).
/// - Deletion follows [DeleteContent]: a failed item keeps its rows and is
///   retried at the next run; the rest of the batch carries on.
/// - **Clock-skew guard** (the spec does not define one; this is a proposal).
///   The whole run is skipped when either holds:
///   1. `now` is earlier than the end of the last finished check run
///      (the clock went backwards);
///   Rule 1 and 3 skip the whole run. A candidate whose `detectedAt` or
///   `downloadedAt` is after `now` (a stale timestamp from a bad clock) is
///   only excluded and counted in `skippedFutureDated`; the rest is deleted.
///   2. the last finished check run ended more than [maxIdleGap] ago. A clock
///      that jumped forward looks exactly like a long idle time, and the
///      cost of waiting is only that old files stay until the next check run
///      completes (which refreshes the reference).
///   With no finished check run there is no reference, so rules 1 and 2 do not
///   apply.
/// - Remote state is never read, so stories that expired or were deleted on
///   Instagram are kept (BR-4).
final class ApplyRetention {
  /// Creates the use case.
  ApplyRetention({
    required this._settings,
    required this._content,
    required this._checkRuns,
    required this._deleteContent,
    required this._clock,
    this.maxIdleGap = const Duration(days: 30),
  });

  /// The longest silence since the last finished check run before the clock
  /// is distrusted.
  final Duration maxIdleGap;

  /// The largest window used, so `now - N days` stays a valid `DateTime`.
  static const int maxDays = 365000;

  final SettingsRepo _settings;
  final ContentRepo _content;
  final CheckRunRepo _checkRuns;
  final DeleteContent _deleteContent;
  final Clock _clock;

  /// Runs one retention pass.
  Future<RetentionResult> call() async {
    final days = (await _settings.get()).retentionDays;
    if (days == null || days <= 0) {
      return const RetentionResult(skipped: RetentionSkip.disabled);
    }
    final now = _clock.now();
    if (await _referenceLooksWrong(now)) {
      return const RetentionResult(skipped: RetentionSkip.clockSkew);
    }
    final cutoff = now.subtract(
      Duration(days: days > maxDays ? maxDays : days),
    );
    final candidates = await _content.olderThan(cutoff);
    final eligible = <ContentWithMedia>[];
    var futureDated = 0;
    for (final item in candidates) {
      if (_lastSeenByStorize(item).isAfter(now)) {
        futureDated++;
      } else if (isRetentionEligible(item, cutoff)) {
        eligible.add(item);
      }
    }
    final deletion = await _deleteContent.deleteLoaded(eligible);
    return RetentionResult(deletion: deletion, skippedFutureDated: futureDated);
  }

  Future<bool> _referenceLooksWrong(DateTime now) async {
    DateTime? newest;
    for (final scope in const [CheckScope.stories, CheckScope.posts]) {
      final at = (await _checkRuns.lastFinished(scope))?.finishedAt;
      if (at != null && (newest == null || at.isAfter(newest))) newest = at;
    }
    if (newest == null) return false;
    return now.isBefore(newest) || now.difference(newest) > maxIdleGap;
  }
}
