import 'package:meta/meta.dart';
import 'package:storize_domain/src/ports/gallery_store.dart';

/// How a move of the saved files (FR-79) stands.
enum MoveStatus {
  /// No move has run, or the last one was acknowledged.
  idle,

  /// A move is running (or was interrupted: see [MoveProgress.isStale]).
  running,

  /// Every file that could be moved was moved.
  done,

  /// The user cancelled. Files moved so far stay moved; a new run continues.
  cancelled,

  /// The device ran out of space. Nothing was lost; a new run continues.
  storageFull,
}

/// The progress of the move of the saved files (FR-79), shared between the
/// background task that moves and the Settings screen that shows it.
@immutable
final class MoveProgress {
  /// Creates a progress value.
  const MoveProgress({
    this.status = MoveStatus.idle,
    this.target,
    this.total = 0,
    this.moved = 0,
    this.missing = 0,
    this.failed = 0,
    this.updatedAt,
  });

  /// No move.
  static const MoveProgress none = MoveProgress();

  /// A running move that has not written for this long counts as interrupted.
  static const Duration staleAfter = Duration(minutes: 3);

  /// The state.
  final MoveStatus status;

  /// Where the files are being moved to, or null when idle.
  final StorageTarget? target;

  /// How many files this move covers (moved, missing and still to do).
  final int total;

  /// How many files are moved.
  final int moved;

  /// Files whose original was gone (reported, not an error).
  final int missing;

  /// Files that could not be moved this time (they stay where they are).
  final int failed;

  /// When this value was written (UTC).
  final DateTime? updatedAt;

  /// Files handled so far.
  int get handled => moved + missing + failed;

  /// Whether a move is marked running but has stopped writing, for example
  /// because the app was force-stopped.
  bool isStale(DateTime nowUtc) =>
      status == MoveStatus.running &&
      (updatedAt == null || nowUtc.difference(updatedAt!) > staleAfter);

  /// Returns a copy with the given fields replaced.
  MoveProgress copyWith({
    MoveStatus? status,
    StorageTarget? target,
    int? total,
    int? moved,
    int? missing,
    int? failed,
    DateTime? updatedAt,
  }) => MoveProgress(
    status: status ?? this.status,
    target: target ?? this.target,
    total: total ?? this.total,
    moved: moved ?? this.moved,
    missing: missing ?? this.missing,
    failed: failed ?? this.failed,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoveProgress &&
          other.status == status &&
          other.target == target &&
          other.total == total &&
          other.moved == moved &&
          other.missing == missing &&
          other.failed == failed &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode =>
      Object.hash(status, target, total, moved, missing, failed, updatedAt);

  @override
  String toString() =>
      'MoveProgress(${status.name}, ${target?.name}, total: $total, '
      'moved: $moved, missing: $missing, failed: $failed)';
}

/// Where the progress and the cancel request of a move live, so the
/// background isolate and the UI see the same values. Production keeps them
/// in shared preferences.
abstract interface class MoveStateStore {
  /// The current progress ([MoveProgress.none] when nothing is stored).
  Future<MoveProgress> read();

  /// Replaces the progress.
  Future<void> write(MoveProgress progress);

  /// Whether the user asked the running move to stop.
  Future<bool> cancelRequested();

  /// Sets or clears the cancel request.
  Future<void> setCancelRequested({required bool value});
}

/// Starts and stops the background `move-library` task (FR-79). Separate from
/// `Scheduler` so that port does not change. Production:
/// `WorkmanagerScheduler`.
abstract interface class MoveScheduler {
  /// Enqueues the move to [target]. A user start ([rollover] false) replaces
  /// a run that is queued or running (the move is resumable); a roll-over from
  /// the task itself, after its time budget, queues after the current run.
  Future<void> enqueueMove(StorageTarget target, {bool rollover = false});

  /// Cancels the queued or running task.
  Future<void> cancelMove();
}
