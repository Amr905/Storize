import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/activity_event.dart';
import 'package:storize_domain/src/repos/activity_repo.dart';
import 'package:storize_domain/src/repos/check_run_repo.dart';
import 'package:storize_domain/src/repos/settings_repo.dart';
import 'package:storize_model/storize_model.dart';

/// A period without story checks that is too long (EC-10, EC-11).
@immutable
final class Gap {
  /// Creates a gap.
  const Gap({
    required this.from,
    required this.to,
    required this.threshold,
    required this.recorded,
  });

  /// When the last story run finished (UTC). The gap starts here.
  final DateTime from;

  /// The instant the gap was detected (UTC).
  final DateTime to;

  /// The silence allowed before this gap, see [DetectGaps.thresholdFor].
  final Duration threshold;

  /// True when this call stored a new `GAP` event. False when an event for
  /// the same gap was already stored by an earlier call.
  final bool recorded;

  /// How long checks were silent.
  Duration get length => to.difference(from);

  @override
  String toString() =>
      'Gap(from: ${from.toIso8601String()}, '
      'to: ${to.toIso8601String()}, recorded: $recorded)';
}

/// Detects a gap in story checks and records one `GAP` activity event for it
/// (EC-10, EC-11).
///
/// The rule: a gap exists when `now − last story run > max(2×interval,
/// interval + 30 min)`, where `interval` is the story interval from settings.
/// Exactly at the threshold is not a gap. With no finished story run there is
/// no baseline, so there is no gap.
///
/// Each gap is identified by the end of the last story run. The `GAP` event
/// stores that instant as `fromMs`. A later call for the same gap finds the
/// event and does not write a second one. The lookup covers the 7-day
/// activity window only.
final class DetectGaps {
  /// Creates the use case.
  DetectGaps({
    required this.checkRuns,
    required this.settings,
    required this.activity,
  });

  /// The extra slack added to one interval (30 min).
  static const Duration slack = Duration(minutes: 30);

  /// Finished check runs, for the last story run.
  final CheckRunRepo checkRuns;

  /// The story interval.
  final SettingsRepo settings;

  /// Where the `GAP` event is stored.
  final ActivityRepo activity;

  /// The silence allowed for [interval]: `max(2×interval, interval + 30 min)`.
  static Duration thresholdFor(Duration interval) {
    final doubled = interval * 2;
    final padded = interval + slack;
    return doubled > padded ? doubled : padded;
  }

  /// Returns the gap at [now], or null when story checks are on schedule.
  Future<Gap?> call(DateTime now) async {
    final last = await checkRuns.lastFinished(CheckScope.stories);
    if (last == null) return null;
    final from = (last.finishedAt ?? last.startedAt).toUtc();
    final at = now.toUtc();

    final current = await settings.get();
    final interval = Duration(minutes: current.storyIntervalMin);
    final threshold = thresholdFor(interval);
    if (at.difference(from) <= threshold) return null;

    final fromMs = from.millisecondsSinceEpoch;
    final known = await activity.watchRecent(types: {ActivityType.gap}).first;
    final alreadyRecorded = known.any((e) => e.payload['fromMs'] == fromMs);
    if (alreadyRecorded) {
      return Gap(from: from, to: at, threshold: threshold, recorded: false);
    }

    await activity.add(
      ActivityEvent(
        id: ActivityEvent.unsavedId,
        at: at,
        type: ActivityType.gap,
        severity: Severity.warn,
        payload: {'fromMs': fromMs, 'toMs': at.millisecondsSinceEpoch},
      ),
    );
    return Gap(from: from, to: at, threshold: threshold, recorded: true);
  }
}
