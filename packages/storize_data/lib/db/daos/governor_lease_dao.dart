import 'package:drift/drift.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/db/tables.dart';
import 'package:storize_domain/storize_domain.dart';

part 'governor_lease_dao.g.dart';

/// Raw queries for `governor_lease` (ADR-9). Every method that depends on the
/// time takes `now` as a parameter, so the caller owns the clock.
///
/// Each read-modify-write runs in a transaction. All isolates share one
/// connection (see `StorizeDatabase.open`), so transactions serialise.
@DriftAccessor(tables: [GovernorLeases])
class GovernorLeaseDao extends DatabaseAccessor<StorizeDatabase>
    with _$GovernorLeaseDaoMixin {
  GovernorLeaseDao(super.attachedDatabase);

  SimpleSelectStatement<$GovernorLeasesTable, GovernorLeaseRow> _byAccount(
    int accountId,
  ) => select(governorLeases)..where((l) => l.loginAccountId.equals(accountId));

  bool _held(GovernorLeaseRow? row, String holder, DateTime now) =>
      row != null && row.holder == holder && row.expiresAt.isAfter(now);

  /// The stored row, including an expired one.
  Future<GovernorLeaseRow?> read(int accountId) =>
      _byAccount(accountId).getSingleOrNull();

  /// Takes the lease for [holder] until `now + ttl`. Returns the row, or null
  /// when another holder has an unexpired lease. A lease with
  /// `expiresAt > now + ttl` counts as expired (the clock moved back). A
  /// first lease starts from [initialBucket]; later ones keep the stored
  /// bucket.
  Future<GovernorLeaseRow?> acquire({
    required int accountId,
    required String holder,
    required DateTime now,
    required Duration ttl,
    required GovernorBucket initialBucket,
  }) => transaction(() async {
    final existing = await read(accountId);
    if (existing != null &&
        existing.expiresAt.isAfter(now) &&
        // A lease further away than ttl cannot be real (clock moved back).
        !existing.expiresAt.isAfter(now.add(ttl)) &&
        existing.holder != holder) {
      return null;
    }
    final expiresAt = now.add(ttl);
    if (existing == null) {
      await into(governorLeases).insert(
        GovernorLeasesCompanion.insert(
          loginAccountId: Value(accountId),
          holder: holder,
          expiresAt: expiresAt,
          tokens: initialBucket.tokens,
          lastRefillAt: initialBucket.lastRefillAt,
          backoffUntil: Value(initialBucket.backoffUntil),
          backoffMultiplier: Value(initialBucket.backoffMultiplier),
        ),
      );
    } else {
      await (update(
        governorLeases,
      )..where((l) => l.loginAccountId.equals(accountId))).write(
        GovernorLeasesCompanion(
          holder: Value(holder),
          expiresAt: Value(expiresAt),
        ),
      );
    }
    return read(accountId);
  });

  /// Extends the lease of [holder] to `now + ttl`. False when [holder] does
  /// not hold an unexpired lease.
  Future<bool> renew({
    required int accountId,
    required String holder,
    required DateTime now,
    required Duration ttl,
  }) => transaction(() async {
    if (!_held(await read(accountId), holder, now)) return false;
    await (update(governorLeases)
          ..where((l) => l.loginAccountId.equals(accountId)))
        .write(GovernorLeasesCompanion(expiresAt: Value(now.add(ttl))));
    return true;
  });

  /// Ends the lease of [holder] by setting `expiresAt` to [now]; the bucket
  /// stays. No-op for a different holder. [GovernorLeaseRepo.release] passes
  /// the epoch so the value can never block after a clock jump back.
  Future<void> release({
    required int accountId,
    required String holder,
    required DateTime now,
  }) async {
    await (update(governorLeases)..where(
          (l) => l.loginAccountId.equals(accountId) & l.holder.equals(holder),
        ))
        .write(GovernorLeasesCompanion(expiresAt: Value(now)));
  }

  /// Stores [bucket]. False (nothing written) when [holder] does not hold an
  /// unexpired lease.
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required DateTime now,
    required GovernorBucket bucket,
  }) => transaction(() async {
    if (!_held(await read(accountId), holder, now)) return false;
    await (update(
      governorLeases,
    )..where((l) => l.loginAccountId.equals(accountId))).write(
      GovernorLeasesCompanion(
        tokens: Value(bucket.tokens),
        lastRefillAt: Value(bucket.lastRefillAt),
        backoffUntil: Value(bucket.backoffUntil),
        backoffMultiplier: Value(bucket.backoffMultiplier),
      ),
    );
    return true;
  });
}
