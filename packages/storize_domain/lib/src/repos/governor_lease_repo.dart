import 'package:storize_domain/src/entities/governor_lease.dart';

/// Shared state of the request governor between isolates (table
/// `governor_lease`, ADR-9).
///
/// A lease is held while its `expiresAt` is in the future. The bucket state
/// survives release and expiry, so the next holder continues from it.
///
/// **Clock skew.** If the wall clock jumps backwards, a stored `expiresAt`
/// can lie far in the future. [acquire] therefore treats a lease with
/// `expiresAt > now + ttl` (its own `ttl`) as expired: no honest holder can
/// have set it. [release] stores the epoch (UTC 0) as `expiresAt`, a value
/// that can never block, whatever the clock does.
abstract interface class GovernorLeaseRepo {
  /// Tries to take the lease of [accountId] for [holder] for [ttl].
  /// All holders of one account must use the same [ttl] (the governor's
  /// single `leaseTtl`); a shorter ttl would treat a longer lease as skewed.
  ///
  /// Succeeds, returning the lease, when no lease exists, the old one has
  /// expired (`expiresAt <= now`, or `expiresAt > now + ttl` after a clock
  /// jump back; exactly `now + ttl` is still valid), or [holder] already
  /// holds it. Returns null when another holder
  /// has an unexpired lease. A first-time lease starts with
  /// [initialBucket].
  Future<GovernorLease?> acquire({
    required int accountId,
    required String holder,
    required Duration ttl,
    required GovernorBucket initialBucket,
  });

  /// Extends the lease of [holder] to now + [ttl]. Returns false when
  /// [holder] does not hold an unexpired lease.
  Future<bool> renew({
    required int accountId,
    required String holder,
    required Duration ttl,
  });

  /// Ends the lease of [holder] now by setting `expiresAt` to the epoch.
  /// Does nothing if [holder] is not the
  /// holder. The bucket state is kept.
  Future<void> release({required int accountId, required String holder});

  /// The stored lease row, including an expired one, or null if none.
  Future<GovernorLease?> read(int accountId);

  /// Stores [bucket] on the lease of [accountId]. Returns false (and writes
  /// nothing) when [holder] does not hold an unexpired lease.
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  });
}
