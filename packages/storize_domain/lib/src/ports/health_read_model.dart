import 'package:storize_domain/src/entities/health_snapshot.dart';

/// Read-only view of the state behind the Health screen (FR-75).
///
/// Implementations only read local state: they never call Instagram and never
/// write.
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class HealthReadModel {
  /// Reads the snapshot now.
  Future<HealthSnapshot> read();
}
