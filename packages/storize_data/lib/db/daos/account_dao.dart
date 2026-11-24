import 'package:drift/drift.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/db/tables.dart';
import 'package:storize_model/storize_model.dart';

part 'account_dao.g.dart';

/// Raw queries for `login_account`.
@DriftAccessor(tables: [LoginAccounts])
class AccountDao extends DatabaseAccessor<StorizeDatabase>
    with _$AccountDaoMixin {
  AccountDao(super.attachedDatabase);

  SimpleSelectStatement<$LoginAccountsTable, LoginAccountRow> _newestFirst() =>
      select(loginAccounts)
        ..orderBy([
          (a) => OrderingTerm.desc(a.connectedAt),
          (a) => OrderingTerm.desc(a.id),
        ])
        ..limit(1);

  /// The active account: the most recently connected row (MVP has one).
  Stream<LoginAccountRow?> watchActive() => _newestFirst().watchSingleOrNull();

  /// One-shot version of [watchActive].
  Future<LoginAccountRow?> getActive() => _newestFirst().getSingleOrNull();

  /// Inserts the account, or updates the row with the same `remote_user_id`
  /// (keeping its id). Returns the stored row.
  Future<LoginAccountRow> upsert(LoginAccountsCompanion account) =>
      transaction(() async {
        await into(loginAccounts).insert(
          account,
          onConflict: DoUpdate(
            (_) => account,
            target: [loginAccounts.remoteUserId],
          ),
        );
        return (select(loginAccounts)..where(
              (a) => a.remoteUserId.equals(account.remoteUserId.value),
            ))
            .getSingle();
      });

  /// Sets the status and reason (a null [reason] clears it). A null
  /// [lastSuccessAt] leaves the stored value alone. Returns rows changed.
  Future<int> setStatus(
    int id,
    AccountStatus status, {
    String? reason,
    DateTime? lastSuccessAt,
  }) => (update(loginAccounts)..where((a) => a.id.equals(id))).write(
    LoginAccountsCompanion(
      status: Value(status),
      statusReason: Value(reason),
      lastSuccessAt: lastSuccessAt == null
          ? const Value.absent()
          : Value(lastSuccessAt),
    ),
  );

  /// Deletes the account. Targets keep existing with a null
  /// `login_account_id` (FK `SET NULL`).
  Future<int> deleteById(int id) =>
      (delete(loginAccounts)..where((a) => a.id.equals(id))).go();
}
