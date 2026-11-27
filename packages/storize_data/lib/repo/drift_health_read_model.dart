import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/drift_account_repo.dart';
import 'package:storize_data/repo/drift_check_run_repo.dart';
import 'package:storize_data/repo/drift_governor_lease_repo.dart';
import 'package:storize_data/repo/drift_target_repo.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// [HealthReadModel] over the local database (FR-75). Read-only: it reads the
/// account, the governor bucket, the check runs, the targets and today's saved
/// items. It never calls Instagram.
final class DriftHealthReadModel implements HealthReadModel {
  /// Creates the read model over [db].
  ///
  /// [burst] and [callsPerHour] are the governor's bucket settings (ADR-9
  /// defaults). They are used only to turn the stored bucket into a count.
  DriftHealthReadModel(
    StorizeDatabase db, {
    required Clock clock,
    required this.settingsRepo,
    this.burst = 6,
    this.callsPerHour = 60,
  }) : _db = db,
       _clock = clock,
       _accounts = DriftAccountRepo(db),
       _leases = DriftGovernorLeaseRepo(db, clock),
       _checkRuns = DriftCheckRunRepo(db),
       _targets = DriftTargetRepo(db);

  /// The bucket capacity (ADR-9, default 6).
  final int burst;

  /// The sustained refill per hour (ADR-9, default 60).
  final int callsPerHour;

  final StorizeDatabase _db;
  final Clock _clock;
  final SettingsRepo settingsRepo;
  final AccountRepo _accounts;
  final GovernorLeaseRepo _leases;
  final CheckRunRepo _checkRuns;
  final TargetRepo _targets;

  @override
  Future<HealthSnapshot> read() async {
    final now = _clock.now().toUtc();
    final account = await _accounts.getActive();
    final lease = account == null ? null : await _leases.read(account.id);
    final settings = await settingsRepo.get();
    final stories = await _checkRuns.lastFinished(CheckScope.stories);
    final posts = await _checkRuns.lastFinished(CheckScope.posts);
    final targets = await _targets.watchAll().first;
    final saved = await _savedToday(now);

    final bucket = lease?.bucket;
    final backoff = bucket?.backoffUntil;
    final ends = [
      stories?.finishedAt,
      posts?.finishedAt,
    ].whereType<DateTime>();

    return HealthSnapshot(
      at: now,
      session: account == null
          ? null
          : HealthSession(username: account.username, status: account.status),
      budget: HealthBudget(
        burst: burst,
        callsPerHour: callsPerHour,
        // No stored bucket yet means a fresh, full one.
        availableNow: bucket == null ? burst : _available(bucket, now),
        pausedUntil: backoff != null && backoff.isAfter(now) ? backoff : null,
      ),
      schedule: HealthSchedule(
        storyIntervalMin: settings.storyIntervalMin,
        postIntervalMin: settings.postIntervalMin,
        lastRunAt: ends.isEmpty
            ? null
            : ends.reduce((a, b) => a.isAfter(b) ? a : b).toUtc(),
      ),
      targets: [
        for (final t in targets)
          HealthTarget(
            id: t.id,
            username: t.username,
            avatarPath: t.avatarPath,
            status: t.status,
            lastSuccessAt: t.lastSuccessAt,
            lastOutcome: t.lastCheckOutcome,
            lastCode: t.lastCheckCode,
            savedToday: saved[t.id] ?? 0,
          ),
      ],
    );
  }

  /// Whole tokens at [now]: the stored tokens plus the refill since the last
  /// refill, capped at the burst. A clock that ran backwards adds nothing.
  int _available(GovernorBucket bucket, DateTime now) {
    final elapsed = now.difference(bucket.lastRefillAt);
    final hours = elapsed.isNegative ? 0.0 : elapsed.inMilliseconds / 3600000;
    final tokens = bucket.tokens + hours * callsPerHour;
    return math.max(0, math.min(burst, tokens.floor()));
  }

  /// Items saved since the start of the UTC day, per target ID. An item counts
  /// once, when one of its media files is DONE.
  Future<Map<int, int>> _savedToday(DateTime now) async {
    final start = DateTime.utc(now.year, now.month, now.day);
    final rows = await _db
        .customSelect(
          'SELECT c.target_id AS target_id, COUNT(DISTINCT c.id) AS n '
          'FROM content c JOIN media_file m ON m.content_id = c.id '
          "WHERE m.status = 'DONE' AND m.downloaded_at >= ? "
          'GROUP BY c.target_id',
          variables: [Variable<int>(start.millisecondsSinceEpoch)],
          readsFrom: {_db.contents, _db.mediaFiles},
        )
        .get();
    return {
      for (final r in rows) r.read<int>('target_id'): r.read<int>('n'),
    };
  }
}
