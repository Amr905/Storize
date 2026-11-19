import 'package:meta/meta.dart';
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
  const RetentionResult({this.skipped, this.deletion});

  /// Set when the run did nothing on purpose.
  final RetentionSkip? skipped;

  /// What was deleted. Null when [skipped] is set.
  final DeleteContentResult? deletion;

  @override
  String toString() => 'RetentionResult(skipped: $skipped, $deletion)';
}

/// Deletes content older than `retentionDays` days, files first (FR-54, BR-9).
///
/// - **Age basis:** `Content.postedAt`, because that is what
///   `ContentRepo.olderThan` filters on. Content is deleted when
///   `postedAt < now - N days` (strict): exactly N days old is kept, N days
///   and 1 ms is deleted.
/// - `retentionDays` null means off. A non-positive value is treated as off
///   too, for safety (`AppSettings` already forbids it).
/// - Deletion follows [DeleteContent]: a failed item keeps its rows and is
///   retried at the next run; the rest of the batch carries on.
/// - **Clock-skew guard** (the spec does not define one; this is a proposal).
///   Nothing is deleted when any of these hold:
///   1. `now` is earlier than the end of the last finished check run
///      (the clock went backwards);
///   2. a candidate has `detectedAt` or `downloadedAt` after `now`
///      (content from the future: the clock went backwards);
///   3. the last finished check run ended more than [maxIdleGap] ago. A clock
///      that jumped forward looks exactly like a long idle time, and the
///      cost of waiting is only that old files stay until the next check run
///      completes (which refreshes the reference).
///   With no finished check run there is no reference, so only rule 2 applies.
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
    for (final item in candidates) {
      final detected = item.content.detectedAt;
      if (detected.isAfter(now) ||
          item.media.any((m) => m.downloadedAt?.isAfter(now) ?? false)) {
        return const RetentionResult(skipped: RetentionSkip.clockSkew);
      }
    }
    final deletion = await _deleteContent.deleteLoaded(candidates);
    return RetentionResult(deletion: deletion);
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
