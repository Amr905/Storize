import 'package:storize_domain/src/entities/login_account.dart';
import 'package:storize_domain/src/repos/account_repo.dart';
import 'package:storize_domain/src/testing/change_feed.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [AccountRepo] with the UNIQUE `remoteUserId` rule.
final class FakeAccountRepo implements AccountRepo {
  final Map<int, LoginAccount> _rows = {};
  final ChangeFeed _feed = ChangeFeed();
  int _nextId = 1;

  LoginAccount? _active() {
    LoginAccount? best;
    for (final a in _rows.values) {
      if (best == null ||
          a.connectedAt.isAfter(best.connectedAt) ||
          (a.connectedAt == best.connectedAt && a.id > best.id)) {
        best = a;
      }
    }
    return best;
  }

  @override
  Stream<LoginAccount?> watchActive() => _feed.watch(_active);

  @override
  Future<LoginAccount?> getActive() async => _active();

  @override
  Future<LoginAccount> upsert(LoginAccount account) async {
    final existing = _rows.values
        .where((a) => a.remoteUserId == account.remoteUserId)
        .firstOrNull;
    final stored = account.copyWith(id: existing?.id ?? _nextId++);
    _rows[stored.id] = stored;
    _feed.notify();
    return stored;
  }

  @override
  Future<void> setStatus(
    int id,
    AccountStatus status, {
    String? reason,
    DateTime? lastSuccessAt,
  }) async {
    final row = _rows[id];
    if (row == null) throw StateError('No login account with id $id');
    _rows[id] = row.copyWith(
      status: status,
      statusReason: reason,
      lastSuccessAt: lastSuccessAt ?? row.lastSuccessAt,
    );
    _feed.notify();
  }
}
