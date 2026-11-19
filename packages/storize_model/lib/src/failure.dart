// Every class here is immutable: final fields and unmodifiable collections.
// The lint cannot see that without @immutable from package:meta, which this
// package does not depend on (T-003 rules out new dependencies).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:storize_model/src/enums.dart';

/// Why an operation failed. Each subclass maps to a row of the failure table
/// in TECH_SPEC §4.1 and §7.
sealed class Failure {
  const Failure();
}

/// The request could not be completed (socket, DNS or timeout).
final class NetworkFailure extends Failure {
  /// Creates a network failure.
  const NetworkFailure();

  @override
  bool operator ==(Object other) => other is NetworkFailure;

  @override
  int get hashCode => 'NetworkFailure'.hashCode;

  @override
  String toString() => 'NetworkFailure()';
}

/// Instagram asked us to slow down. [retryAfter] is the server's hint, if any.
final class RateLimited extends Failure {
  /// Creates a rate-limit failure.
  const RateLimited(this.retryAfter);

  /// How long to wait before retrying, or null when the server gave no hint.
  final Duration? retryAfter;

  @override
  bool operator ==(Object other) =>
      other is RateLimited && other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash('RateLimited', retryAfter);

  @override
  String toString() => 'RateLimited(retryAfter: $retryAfter)';
}

/// The stored session can no longer be used.
final class SessionInvalid extends Failure {
  /// Creates a session failure with the [reason].
  const SessionInvalid(this.reason);

  /// Whether a login is required or a challenge must be completed.
  final SessionReason reason;

  @override
  bool operator ==(Object other) =>
      other is SessionInvalid && other.reason == reason;

  @override
  int get hashCode => Object.hash('SessionInvalid', reason);

  @override
  String toString() => 'SessionInvalid(reason: ${reason.name})';
}

/// The account is restricted (feedback required or disabled).
final class AccountRestricted extends Failure {
  /// Creates an account-restricted failure.
  const AccountRestricted();

  @override
  bool operator ==(Object other) => other is AccountRestricted;

  @override
  int get hashCode => 'AccountRestricted'.hashCode;

  @override
  String toString() => 'AccountRestricted()';
}

/// The tracked username or user ID no longer exists.
final class TargetNotFound extends Failure {
  /// Creates a target-not-found failure.
  const TargetNotFound();

  @override
  bool operator ==(Object other) => other is TargetNotFound;

  @override
  int get hashCode => 'TargetNotFound'.hashCode;

  @override
  String toString() => 'TargetNotFound()';
}

/// The target exists but is private and not followed, or blocked.
final class TargetNotVisible extends Failure {
  /// Creates a target-not-visible failure.
  const TargetNotVisible();

  @override
  bool operator ==(Object other) => other is TargetNotVisible;

  @override
  int get hashCode => 'TargetNotVisible'.hashCode;

  @override
  String toString() => 'TargetNotVisible()';
}

/// An expected field is missing from a response. [where] names the place.
final class SchemaChanged extends Failure {
  /// Creates a schema-changed failure located at [where].
  const SchemaChanged(this.where);

  /// Where the unexpected response was found, for example a field path.
  final String where;

  @override
  bool operator ==(Object other) =>
      other is SchemaChanged && other.where == where;

  @override
  int get hashCode => Object.hash('SchemaChanged', where);

  @override
  String toString() => 'SchemaChanged(where: $where)';
}

/// Anything not covered above. Keeps the HTTP [code] and a short [message].
final class UnknownFailure extends Failure {
  /// Creates an unknown failure.
  const UnknownFailure(this.code, this.message);

  /// The HTTP status code, when there is one.
  final int? code;

  /// A short diagnostic message. Must not contain secrets.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is UnknownFailure && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash('UnknownFailure', code, message);

  @override
  String toString() => 'UnknownFailure(code: $code, message: $message)';
}
