import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/page/discovery_store.dart';
import 'package:storize_model/storize_model.dart';

/// The [DiscoveryStore] in secure storage (T-045), next to the session
/// cookies: the page tokens are as secret as a cookie, so they never go to
/// shared preferences, a file or a log.
///
/// One entry per account (`storize.discovery.<accountId>`), written by the
/// foreground isolate (page mode) and read by every isolate. Like the session
/// store it must be created once per isolate. Reads never throw (an unreadable
/// or foreign value is "nothing discovered"); nothing is logged and
/// `toString` shows nothing but the type.
final class SecureStorageDiscoveryStore implements DiscoveryStore {
  /// Creates the store over the secure storage (the same instance type as
  /// the session store's).
  SecureStorageDiscoveryStore(this._storage);

  /// The storage key of [accountId].
  static String keyFor(int accountId) => 'storize.discovery.$accountId';

  final FlutterSecureStorage _storage;

  @override
  Future<DiscoverySnapshot?> load(int accountId) async {
    final String? raw;
    try {
      raw = await _storage.read(key: keyFor(accountId));
    } on Object {
      // The text of a platform error is not kept.
      return null;
    }
    if (raw == null) return null;
    return DiscoverySnapshot.fromJson(raw);
  }

  @override
  Future<void> save(int accountId, DiscoverySnapshot snapshot) =>
      _storage.write(key: keyFor(accountId), value: snapshot.toJson());

  @override
  Future<void> clear(int accountId) => _storage.delete(key: keyFor(accountId));

  @override
  String toString() => 'SecureStorageDiscoveryStore()';
}

/// A [SessionStore] that also forgets the page discovery of an account when
/// its session is removed or replaced (T-045): tokens belong to one session,
/// so logout, account removal and a new login must not leave them behind.
///
/// Every logout path ends in `SessionStore.clear`, so wrapping the store
/// covers them all. A failing discovery clear never hides the session
/// operation's own result.
final class DiscoveryClearingSessionStore implements SessionStore {
  /// Wraps [inner]; [discovery] is cleared with it.
  DiscoveryClearingSessionStore(this.inner, this.discovery);

  /// The real session vault.
  final SessionStore inner;

  /// The discovery to forget with it.
  final DiscoveryStore discovery;

  @override
  Future<void> save(int accountId, SessionBlob session) async {
    await inner.save(accountId, session);
    await _forget(accountId);
  }

  @override
  Future<SessionBlob?> load(int accountId) => inner.load(accountId);

  @override
  Future<void> clear(int accountId) async {
    try {
      await inner.clear(accountId);
    } finally {
      await _forget(accountId);
    }
  }

  Future<void> _forget(int accountId) async {
    try {
      await discovery.clear(accountId);
    } on Object {
      // Best effort: the session result matters more.
    }
  }

  @override
  String toString() => 'DiscoveryClearingSessionStore()';
}
