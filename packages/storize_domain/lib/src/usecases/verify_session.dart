import 'package:meta/meta.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/repos/account_repo.dart';
import 'package:storize_model/storize_model.dart';

/// The outcome of [VerifySession].
sealed class VerifySessionOutcome {
  const VerifySessionOutcome();
}

/// The account status was written to the repo.
@immutable
final class AccountUpdated extends VerifySessionOutcome {
  /// Creates the outcome.
  const AccountUpdated(this.status, {this.reason});

  /// The status now stored on the account.
  final AccountStatus status;

  /// The stored reason (`SESSION_EXPIRED`, `CHECKPOINT`), or null.
  final String? reason;

  @override
  String toString() =>
      'AccountUpdated(status: ${status.name}, reason: $reason)';
}

/// The check could not decide (network, busy governor or another failure).
/// The stored account status was left as it was.
@immutable
final class AccountUnchanged extends VerifySessionOutcome {
  /// Creates the outcome.
  const AccountUnchanged(this.failure);

  /// Why the status was not changed.
  final Failure failure;

  @override
  String toString() => 'AccountUnchanged(failure: $failure)';
}

/// There is no login account, so nothing was checked.
@immutable
final class NoLoginAccount extends VerifySessionOutcome {
  /// Creates the outcome.
  const NoLoginAccount();

  @override
  String toString() => 'NoLoginAccount()';
}

/// Checks the stored session and stores the account health (FR-3, FR-4).
///
/// - Works: `ACTIVE`, reason cleared, `lastSuccessAt` set to now.
/// - Login required: `NEEDS_RELOGIN`, reason `SESSION_EXPIRED`.
/// - Checkpoint or challenge: `NEEDS_RELOGIN`, reason `CHECKPOINT`.
/// - Account restricted: `RESTRICTED`.
/// - Network failure (includes `governor_busy` and `webview_busy`) or any
///   other failure: no status change. The failure is returned.
///
/// Without a login account it returns [NoLoginAccount] and makes no request.
final class VerifySession {
  /// Creates the use case.
  VerifySession({
    required this.accounts,
    required this.platform,
    required this.clock,
  });

  /// The reason stored for an expired login.
  static const String reasonExpired = 'SESSION_EXPIRED';

  /// The reason stored for a checkpoint or challenge.
  static const String reasonCheckpoint = 'CHECKPOINT';

  /// The login account that is updated.
  final AccountRepo accounts;

  /// The content platform that verifies the session.
  final ContentPlatform platform;

  /// The time source for `lastSuccessAt`.
  final Clock clock;

  /// Verifies the active session and updates the account.
  Future<VerifySessionOutcome> call() async {
    final account = await accounts.getActive();
    if (account == null) return const NoLoginAccount();

    final result = await platform.verifySession();
    return switch (result) {
      Ok<RemoteUser>() => _store(
        account.id,
        AccountStatus.active,
        null,
        lastSuccessAt: clock.now().toUtc(),
      ),
      Err<RemoteUser>(:final failure) => _fromFailure(account.id, failure),
    };
  }

  Future<VerifySessionOutcome> _fromFailure(int id, Failure failure) {
    return switch (failure) {
      SessionInvalid(reason: SessionReason.loginRequired) => _store(
        id,
        AccountStatus.needsRelogin,
        reasonExpired,
      ),
      SessionInvalid(reason: SessionReason.challenge) => _store(
        id,
        AccountStatus.needsRelogin,
        reasonCheckpoint,
      ),
      AccountRestricted() => _store(id, AccountStatus.restricted, null),
      NetworkFailure() ||
      RateLimited() ||
      TargetNotFound() ||
      TargetNotVisible() ||
      SchemaChanged() ||
      UnknownFailure() => Future.value(AccountUnchanged(failure)),
    };
  }

  Future<VerifySessionOutcome> _store(
    int id,
    AccountStatus status,
    String? reason, {
    DateTime? lastSuccessAt,
  }) async {
    await accounts.setStatus(
      id,
      status,
      reason: reason,
      lastSuccessAt: lastSuccessAt,
    );
    return AccountUpdated(status, reason: reason);
  }
}
