import 'package:storize_domain/src/entities/governor_lease.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/repos/governor_lease_repo.dart';

/// An in-memory [GovernorLeaseRepo]. Expiry follows the given [Clock].
final class FakeGovernorLeaseRepo implements GovernorLeaseRepo {
  /// Creates the repo. Use a `FakeClock` to make leases expire.
  FakeGovernorLeaseRepo(this._clock);

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  final Clock _clock;
  final Map<int, GovernorLease> _rows = {};

  bool _holds(GovernorLease? lease, String holder) =>
      lease != null && lease.holder == holder && lease.isHeldAt(_clock.now());

  @override
  Future<GovernorLease?> acquire({
    required int accountId,
    required String holder,
    required Duration ttl,
    required GovernorBucket initialBucket,
  }) async {
    final existing = _rows[accountId];
    final now = _clock.now();
    if (existing != null &&
        existing.isHeldAt(now) &&
        !existing.expiresAt.isAfter(now.add(ttl)) &&
        existing.holder != holder) {
      return null;
    }
    final lease = GovernorLease(
      loginAccountId: accountId,
      holder: holder,
      expiresAt: now.add(ttl),
      bucket: existing?.bucket ?? initialBucket,
    );
    _rows[accountId] = lease;
    return lease;
  }

  @override
  Future<bool> renew({
    required int accountId,
    required String holder,
    required Duration ttl,
  }) async {
    final lease = _rows[accountId];
    if (!_holds(lease, holder)) return false;
    _rows[accountId] = lease!.copyWith(expiresAt: _clock.now().add(ttl));
    return true;
  }

  @override
  Future<void> release({required int accountId, required String holder}) async {
    final lease = _rows[accountId];
    if (lease == null || lease.holder != holder) return;
    _rows[accountId] = lease.copyWith(expiresAt: _epoch);
  }

  @override
  Future<GovernorLease?> read(int accountId) async => _rows[accountId];

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) async {
    final lease = _rows[accountId];
    if (!_holds(lease, holder)) return false;
    _rows[accountId] = lease!.copyWith(bucket: bucket);
    return true;
  }
}
