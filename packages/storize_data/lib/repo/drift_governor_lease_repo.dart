import 'package:storize_data/db/db.dart';
import 'package:storize_domain/storize_domain.dart';

/// [GovernorLeaseRepo] over [GovernorLeaseDao]. Expiry follows the [Clock].
final class DriftGovernorLeaseRepo implements GovernorLeaseRepo {
  /// Creates the repo over [db]; [clock] decides when leases expire.
  DriftGovernorLeaseRepo(StorizeDatabase db, Clock clock)
    : _dao = db.governorLeaseDao,
      _clock = clock;

  final GovernorLeaseDao _dao;
  final Clock _clock;

  @override
  Future<GovernorLease?> acquire({
    required int accountId,
    required String holder,
    required Duration ttl,
    required GovernorBucket initialBucket,
  }) async {
    final row = await _dao.acquire(
      accountId: accountId,
      holder: holder,
      now: _clock.now(),
      ttl: ttl,
      initialBucket: initialBucket,
    );
    return row == null ? null : _toLease(row);
  }

  @override
  Future<bool> renew({
    required int accountId,
    required String holder,
    required Duration ttl,
  }) => _dao.renew(
    accountId: accountId,
    holder: holder,
    now: _clock.now(),
    ttl: ttl,
  );

  @override
  Future<void> release({required int accountId, required String holder}) =>
      _dao.release(accountId: accountId, holder: holder, now: _clock.now());

  @override
  Future<GovernorLease?> read(int accountId) async {
    final row = await _dao.read(accountId);
    return row == null ? null : _toLease(row);
  }

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) => _dao.writeBucket(
    accountId: accountId,
    holder: holder,
    now: _clock.now(),
    bucket: bucket,
  );
}

GovernorLease _toLease(GovernorLeaseRow r) => GovernorLease(
  loginAccountId: r.loginAccountId,
  holder: r.holder,
  expiresAt: r.expiresAt,
  bucket: GovernorBucket(
    tokens: r.tokens,
    lastRefillAt: r.lastRefillAt,
    backoffUntil: r.backoffUntil,
    backoffMultiplier: r.backoffMultiplier,
  ),
);
