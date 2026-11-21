import 'dart:async';

import 'package:storize_instagram/platform/governor_webview_lease.dart';

/// The cross-isolate WebView lease the login screen holds for its whole
/// lifetime, so page mode never runs while S-02 is open (ADR-0003 addendum).
abstract interface class LoginLease {
  /// The owner name S-02 uses.
  static const String owner = 'login';

  /// Tries to take the lease. Does not wait.
  Future<bool> tryAcquire(String owner);

  /// Gives it back. Idempotent.
  Future<void> release(String owner);

  /// Emits when a held lease was lost (renewal failed).
  Stream<void> get onLost;
}

/// [LoginLease] over the shared [GovernorWebViewLease] (key -1).
final class GovernorLoginLease implements LoginLease {
  /// Wraps [lease].
  GovernorLoginLease(this._lease);

  final GovernorWebViewLease _lease;

  @override
  Future<bool> tryAcquire(String owner) => _lease.tryAcquire(owner);

  @override
  Future<void> release(String owner) => _lease.release(owner);

  @override
  Stream<void> get onLost => _lease.onLost;
}
