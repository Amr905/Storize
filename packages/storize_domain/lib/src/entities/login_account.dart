import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/internal.dart';
import 'package:storize_model/storize_model.dart';

/// The Instagram login that checks targets (table `login_account`).
@immutable
final class LoginAccount {
  /// Creates a login account. Use [unsavedId] for [id] before it is stored.
  const LoginAccount({
    required this.id,
    required this.platform,
    required this.remoteUserId,
    required this.username,
    required this.status,
    required this.connectedAt,
    this.statusReason,
    this.lastSuccessAt,
    this.userAgent,
  });

  /// The [id] of an entity that has not been stored yet.
  static const int unsavedId = 0;

  /// The database ID.
  final int id;

  /// The platform of this login.
  final PlatformId platform;

  /// The stable user ID (`ds_user_id`). Unique.
  final String remoteUserId;

  /// The current username.
  final String username;

  /// Whether the session works.
  final AccountStatus status;

  /// A short reason for a non-active [status].
  final String? statusReason;

  /// When the login was captured (UTC).
  final DateTime connectedAt;

  /// The last time a request with this session succeeded (UTC).
  final DateTime? lastSuccessAt;

  /// The WebView user agent that requests reuse.
  final String? userAgent;

  /// Returns a copy with the given fields replaced. Pass null to clear a
  /// nullable field.
  LoginAccount copyWith({
    int? id,
    String? username,
    AccountStatus? status,
    Object? statusReason = unset,
    DateTime? connectedAt,
    Object? lastSuccessAt = unset,
    Object? userAgent = unset,
  }) => LoginAccount(
    id: id ?? this.id,
    platform: platform,
    remoteUserId: remoteUserId,
    username: username ?? this.username,
    status: status ?? this.status,
    statusReason: pick<String>(statusReason, this.statusReason),
    connectedAt: connectedAt ?? this.connectedAt,
    lastSuccessAt: pick<DateTime>(lastSuccessAt, this.lastSuccessAt),
    userAgent: pick<String>(userAgent, this.userAgent),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoginAccount &&
          other.id == id &&
          other.platform == platform &&
          other.remoteUserId == remoteUserId &&
          other.username == username &&
          other.status == status &&
          other.statusReason == statusReason &&
          other.connectedAt == connectedAt &&
          other.lastSuccessAt == lastSuccessAt &&
          other.userAgent == userAgent);

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    remoteUserId,
    username,
    status,
    statusReason,
    connectedAt,
    lastSuccessAt,
    userAgent,
  );

  @override
  String toString() =>
      'LoginAccount(id: $id, username: $username, status: ${status.name})';
}
