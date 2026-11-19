import 'package:meta/meta.dart';

/// The token-bucket and back-off state of the request governor (ADR-9).
@immutable
final class GovernorBucket {
  /// Creates a bucket state.
  const GovernorBucket({
    required this.tokens,
    required this.lastRefillAt,
    this.backoffUntil,
    this.backoffMultiplier = 1,
  });

  /// Tokens left. Fractional because of continuous refill.
  final double tokens;

  /// When tokens were last refilled (UTC).
  final DateTime lastRefillAt;

  /// No requests before this instant (UTC), or null when not backing off.
  final DateTime? backoffUntil;

  /// The current back-off factor. 1 means no back-off.
  final double backoffMultiplier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GovernorBucket &&
          other.tokens == tokens &&
          other.lastRefillAt == lastRefillAt &&
          other.backoffUntil == backoffUntil &&
          other.backoffMultiplier == backoffMultiplier);

  @override
  int get hashCode =>
      Object.hash(tokens, lastRefillAt, backoffUntil, backoffMultiplier);

  @override
  String toString() =>
      'GovernorBucket(tokens: $tokens, lastRefillAt: $lastRefillAt, '
      'backoffUntil: $backoffUntil, backoffMultiplier: $backoffMultiplier)';
}

/// The governor lease of one login account (table `governor_lease`).
///
/// It keeps the governor consistent between the UI isolate and background
/// isolates. A lease is held while [expiresAt] is in the future.
@immutable
final class GovernorLease {
  /// Creates a lease.
  const GovernorLease({
    required this.loginAccountId,
    required this.holder,
    required this.expiresAt,
    required this.bucket,
  });

  /// The login account that the lease belongs to (primary key).
  final int loginAccountId;

  /// The isolate or task that holds the lease.
  final String holder;

  /// When the lease lapses (UTC).
  final DateTime expiresAt;

  /// The bucket state shared by all holders.
  final GovernorBucket bucket;

  /// Whether the lease is still held at [now].
  bool isHeldAt(DateTime now) => expiresAt.isAfter(now);

  /// Returns a copy with the given fields replaced.
  GovernorLease copyWith({
    String? holder,
    DateTime? expiresAt,
    GovernorBucket? bucket,
  }) => GovernorLease(
    loginAccountId: loginAccountId,
    holder: holder ?? this.holder,
    expiresAt: expiresAt ?? this.expiresAt,
    bucket: bucket ?? this.bucket,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GovernorLease &&
          other.loginAccountId == loginAccountId &&
          other.holder == holder &&
          other.expiresAt == expiresAt &&
          other.bucket == bucket);

  @override
  int get hashCode => Object.hash(loginAccountId, holder, expiresAt, bucket);

  @override
  String toString() =>
      'GovernorLease(loginAccountId: $loginAccountId, holder: $holder, '
      'expiresAt: $expiresAt, bucket: $bucket)';
}
