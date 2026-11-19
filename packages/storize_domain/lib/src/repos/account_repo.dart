import 'package:storize_domain/src/entities/login_account.dart';
import 'package:storize_model/storize_model.dart';

/// Access to the logged-in account (table `login_account`).
///
/// The MVP has one login. When several rows exist, the "active" account is the
/// one with the latest `connectedAt`.
abstract interface class AccountRepo {
  /// Emits the active account now and after every change, or null if none.
  Stream<LoginAccount?> watchActive();

  /// The active account, or null.
  Future<LoginAccount?> getActive();

  /// Inserts the account, or updates the row with the same `remoteUserId`
  /// (which is unique). Returns the stored row with its ID.
  Future<LoginAccount> upsert(LoginAccount account);

  /// Sets the status and its reason (null clears it). When [lastSuccessAt] is
  /// given it is stored too.
  ///
  /// Throws [StateError] when the account does not exist.
  Future<void> setStatus(
    int id,
    AccountStatus status, {
    String? reason,
    DateTime? lastSuccessAt,
  });
}
