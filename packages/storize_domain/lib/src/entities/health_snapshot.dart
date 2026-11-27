import 'package:meta/meta.dart';
import 'package:storize_model/storize_model.dart';

/// What the Health screen (FR-75) shows, read at one instant. It holds no
/// personal content: no captions, no URLs, no cookies.
@immutable
final class HealthSnapshot {
  /// Creates a snapshot taken at [at] (UTC).
  const HealthSnapshot({
    required this.at,
    required this.budget,
    required this.schedule,
    required this.targets,
    this.session,
  });

  /// When the snapshot was read (UTC).
  final DateTime at;

  /// The login account, or null when none is connected.
  final HealthSession? session;

  /// The Instagram request budget and pause.
  final HealthBudget budget;

  /// The check schedule and the last run.
  final HealthSchedule schedule;

  /// One row per tracked account, in the order of the target list.
  final List<HealthTarget> targets;
}

/// The login account and its state.
@immutable
final class HealthSession {
  /// Creates a session summary.
  const HealthSession({required this.username, required this.status});

  /// The Instagram username of the login account.
  final String username;

  /// The stored account status.
  final AccountStatus status;
}

/// The request budget of the governor (ADR-9).
///
/// The governor stores a token bucket, not a count of this hour's requests,
/// so the screen shows how many requests are available right now.
@immutable
final class HealthBudget {
  /// Creates a budget.
  const HealthBudget({
    required this.burst,
    required this.callsPerHour,
    required this.availableNow,
    this.pausedUntil,
  });

  /// The bucket capacity: the most requests in one burst.
  final int burst;

  /// The sustained refill, in requests per hour.
  final int callsPerHour;

  /// Whole requests available at [HealthSnapshot.at], from the stored bucket
  /// after the refill up to now. Never above [burst].
  final int availableNow;

  /// When Instagram's pause ends (UTC), or null when checks are not paused.
  final DateTime? pausedUntil;
}

/// The check schedule.
@immutable
final class HealthSchedule {
  /// Creates a schedule.
  const HealthSchedule({
    required this.storyIntervalMin,
    required this.postIntervalMin,
    this.lastRunAt,
  });

  /// How often stories are checked, in minutes.
  final int storyIntervalMin;

  /// How often posts are checked, in minutes.
  final int postIntervalMin;

  /// When the last check run finished (UTC), or null if none has.
  final DateTime? lastRunAt;
}

/// One tracked account on the Health screen.
@immutable
final class HealthTarget {
  /// Creates a row.
  const HealthTarget({
    required this.id,
    required this.username,
    required this.status,
    required this.savedToday,
    this.avatarPath,
    this.lastSuccessAt,
    this.lastOutcome,
    this.lastCode,
  });

  /// The target ID.
  final int id;

  /// The current username.
  final String username;

  /// The local avatar file, if any.
  final String? avatarPath;

  /// The target status (paused, pending lookup, and so on).
  final TargetStatus status;

  /// When a check last succeeded (UTC), or null.
  final DateTime? lastSuccessAt;

  /// The outcome of the last check, or null if none has run.
  final TargetCheckOutcome? lastOutcome;

  /// The short failure code when [lastOutcome] is failed.
  final String? lastCode;

  /// Items saved today (UTC day) for this target.
  final int savedToday;
}
