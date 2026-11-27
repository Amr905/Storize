import 'package:storize_domain/src/ports/gallery_store.dart';
import 'package:storize_domain/src/ports/move_state_store.dart';

/// An in-memory [MoveStateStore].
final class FakeMoveStateStore implements MoveStateStore {
  /// Creates the store with [progress].
  FakeMoveStateStore([this.progress = MoveProgress.none]);

  /// The stored progress.
  MoveProgress progress;

  /// Every progress written, in order.
  final List<MoveProgress> writes = [];

  bool _cancel = false;

  @override
  Future<MoveProgress> read() async => progress;

  @override
  Future<void> write(MoveProgress progress) async {
    this.progress = progress;
    writes.add(progress);
  }

  @override
  Future<bool> cancelRequested() async => _cancel;

  @override
  Future<void> setCancelRequested({required bool value}) async =>
      _cancel = value;
}

/// A [MoveScheduler] that records its calls.
final class FakeMoveScheduler implements MoveScheduler {
  /// The `enqueueMove` calls, in order.
  final List<({StorageTarget target, bool rollover})> enqueued = [];

  /// How many times `cancelMove` was called.
  int cancelCalls = 0;

  @override
  Future<void> enqueueMove(
    StorageTarget target, {
    bool rollover = false,
  }) async => enqueued.add((target: target, rollover: rollover));

  @override
  Future<void> cancelMove() async => cancelCalls += 1;
}
