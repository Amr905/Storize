import 'dart:convert';

/// What page mode discovered for one login account: `doc_id`s by query and
/// the page tokens, each with the time it was seen (T-045).
///
/// The values are secret (tokens) or session-bound: `toString` shows counts
/// only, and nothing here is ever logged.
final class DiscoverySnapshot {
  /// Creates a snapshot. [docIds] is keyed by `GraphqlQuery.name`.
  const DiscoverySnapshot({this.docIds = const {}, this.tokens, this.tokensAt});

  /// Reads the JSON made by [toJson]; null when it is not a snapshot (a
  /// corrupt or foreign value is treated as "nothing discovered").
  static DiscoverySnapshot? fromJson(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, Object?> || map['v'] != 1) return null;
      final docIds = <String, ({String docId, DateTime at})>{};
      final rawIds = map['docIds'];
      if (rawIds is Map<String, Object?>) {
        for (final e in rawIds.entries) {
          final v = e.value;
          if (v is Map<String, Object?> &&
              v['id'] is String &&
              v['at'] is int) {
            final at = _time(v['at']! as int);
            if (at != null) docIds[e.key] = (docId: v['id']! as String, at: at);
          }
        }
      }
      Map<String, String>? tokens;
      final rawTokens = map['tokens'];
      if (rawTokens is Map<String, Object?> &&
          rawTokens.values.every((v) => v is String)) {
        tokens = {for (final e in rawTokens.entries) e.key: e.value! as String};
      }
      final tokensAt = map['tokensAt'] is int
          ? _time(map['tokensAt']! as int)
          : null;
      return DiscoverySnapshot(
        docIds: docIds,
        tokens: tokens != null && tokensAt != null ? tokens : null,
        tokensAt: tokens != null ? tokensAt : null,
      );
    } on FormatException {
      // The exception text quotes the input: dropped.
      return null;
    }
  }

  // 100 million days of milliseconds: the DateTime limit.
  static const int _maxMs = 86400000 * 100000000;

  static DateTime? _time(int ms) {
    if (ms < 0 || ms > _maxMs) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// `doc_id` and capture time by `GraphqlQuery.name`.
  final Map<String, ({String docId, DateTime at})> docIds;

  /// The page tokens, or null.
  final Map<String, String>? tokens;

  /// When [tokens] were seen.
  final DateTime? tokensAt;

  /// Whether nothing is stored.
  bool get isEmpty => docIds.isEmpty && tokens == null;

  /// The newest capture time of any part, or null when empty.
  DateTime? get newestAt {
    var newest = tokensAt;
    for (final e in docIds.values) {
      if (newest == null || e.at.isAfter(newest)) newest = e.at;
    }
    return newest;
  }

  /// The JSON the stores keep. Contains secrets.
  String toJson() => jsonEncode({
    'v': 1,
    'docIds': {
      for (final e in docIds.entries)
        e.key: {'id': e.value.docId, 'at': e.value.at.millisecondsSinceEpoch},
    },
    'tokens': ?tokens,
    'tokensAt': ?tokensAt?.millisecondsSinceEpoch,
  });

  @override
  String toString() =>
      'DiscoverySnapshot(docIds: ${docIds.length}, tokens: ${tokens != null})';
}

/// Keeps one [DiscoverySnapshot] per login account so that every isolate sees
/// what page mode found in the foreground (T-045). The production adapter is
/// in secure storage, next to the session cookies. Implementations never log
/// values and never throw from [load] (null instead).
abstract interface class DiscoveryStore {
  /// The snapshot of [accountId], or null when none is stored or readable.
  Future<DiscoverySnapshot?> load(int accountId);

  /// Replaces the snapshot of [accountId].
  Future<void> save(int accountId, DiscoverySnapshot snapshot);

  /// Removes the snapshot of [accountId].
  Future<void> clear(int accountId);
}

/// A [DiscoveryStore] in memory, for tests and for builds that wire none.
/// Instances that share one object stand in for two isolates.
final class InMemoryDiscoveryStore implements DiscoveryStore {
  final Map<int, DiscoverySnapshot> _data = {};

  @override
  Future<DiscoverySnapshot?> load(int accountId) async => _data[accountId];

  @override
  Future<void> save(int accountId, DiscoverySnapshot snapshot) async {
    _data[accountId] = snapshot;
  }

  @override
  Future<void> clear(int accountId) async => _data.remove(accountId);

  @override
  String toString() => 'InMemoryDiscoveryStore(accounts: ${_data.length})';
}
