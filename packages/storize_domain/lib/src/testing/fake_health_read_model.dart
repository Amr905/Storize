import 'package:storize_domain/src/entities/health_snapshot.dart';
import 'package:storize_domain/src/ports/health_read_model.dart';

/// A [HealthReadModel] that returns the snapshot it was given, or throws
/// [error] when one is set.
final class FakeHealthReadModel implements HealthReadModel {
  /// Creates the fake with [snapshot] as the answer.
  FakeHealthReadModel(this.snapshot);

  /// The snapshot returned by [read]. Tests may replace it.
  HealthSnapshot snapshot;

  /// When set, [read] throws it.
  Object? error;

  /// How many times [read] was called.
  int reads = 0;

  @override
  Future<HealthSnapshot> read() async {
    reads++;
    final e = error;
    if (e != null) throw e;
    return snapshot;
  }
}
