import 'package:drift/drift.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo_support.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// [AccountRepo] over [AccountDao].
final class DriftAccountRepo implements AccountRepo {
  /// Creates the repo over [db].
  DriftAccountRepo(StorizeDatabase db) : _dao = db.accountDao;

  final AccountDao _dao;

  @override
  Stream<LoginAccount?> watchActive() => freshStream(
    _dao.watchActive().map((row) => row == null ? null : _toAccount(row)),
  );

  @override
  Future<LoginAccount?> getActive() async {
    final row = await _dao.getActive();
    return row == null ? null : _toAccount(row);
  }

  @override
  Future<LoginAccount> upsert(LoginAccount account) async => _toAccount(
    await _dao.upsert(
      LoginAccountsCompanion(
        platform: Value(account.platform),
        remoteUserId: Value(account.remoteUserId),
        username: Value(account.username),
        status: Value(account.status),
        statusReason: Value(account.statusReason),
        connectedAt: Value(account.connectedAt),
        lastSuccessAt: Value(account.lastSuccessAt),
        userAgent: Value(account.userAgent),
      ),
    ),
  );

  @override
  Future<void> setStatus(
    int id,
    AccountStatus status, {
    String? reason,
    DateTime? lastSuccessAt,
  }) async {
    final rows = await _dao.setStatus(
      id,
      status,
      reason: reason,
      lastSuccessAt: lastSuccessAt,
    );
    requireRowChanged(rows, 'login account', id);
  }
}

LoginAccount _toAccount(LoginAccountRow r) => LoginAccount(
  id: r.id,
  platform: r.platform,
  remoteUserId: r.remoteUserId,
  username: r.username,
  status: r.status,
  statusReason: r.statusReason,
  connectedAt: r.connectedAt,
  lastSuccessAt: r.lastSuccessAt,
  userAgent: r.userAgent,
);
