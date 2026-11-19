import 'package:storize_model/storize_model.dart';

/// Thrown by `RequestGovernor.run` when another isolate held the lease of the
/// account for the whole `acquireTimeout`. The call was **not** made.
///
/// Callers treat it as "try again later", never as an Instagram failure.
final class GovernorBusy implements Exception {
  /// Creates the exception.
  const GovernorBusy({required this.accountId, required this.waited});

  /// The login account.
  final int accountId;

  /// How long the governor waited for the lease.
  final Duration waited;

  @override
  String toString() => 'GovernorBusy(account: $accountId, waited: $waited)';
}

/// Thrown by `RequestGovernor.run` while the account is paused after a rate
/// limit. The call was **not** made.
final class GovernorPaused implements Exception {
  /// Creates the exception.
  const GovernorPaused({
    required this.accountId,
    required this.until,
    required this.retryAfter,
  });

  /// The login account.
  final int accountId;

  /// When calls may resume (UTC).
  final DateTime until;

  /// Time left of the pause when the call was refused.
  final Duration retryAfter;

  /// The equivalent failure, for the failure map of the platform adapter.
  RateLimited toFailure() => RateLimited(retryAfter);

  @override
  String toString() =>
      'GovernorPaused(account: $accountId, until: $until, '
      'retryAfter: $retryAfter)';
}
