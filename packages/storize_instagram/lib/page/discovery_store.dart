import 'dart:convert';

/// The shape of one GraphQL query as the page's own modules describe it
/// (T-048): the relay provided-variable values and the argument names. Both
/// are code constants of the web app, not secret.
final class QueryShape {
  /// Creates a shape.
  const QueryShape({
    this.provided = const {},
    this.args = const [],
    this.loaded = false,
  });

  /// `__relay_internal__pv__X` to its current bool, number or short string.
  final Map<String, Object> provided;

  /// The argument names the query takes.
  final List<String> args;

  /// The query's `.graphql` module was read, so an empty [provided] is real.
  final bool loaded;

  /// Whether the provider values are settled: some were found, or the module
  /// (or a captured request) shows there are none. An unknown shape must not
  /// be sent (Instagram answers `missing_required_variable_value`).
  bool get isKnown => provided.isNotEmpty || args.isNotEmpty || loaded;

  /// The JSON map kept in a snapshot.
  Map<String, Object?> toJson() => {
    'p': provided,
    'a': args,
    if (loaded) 'l': true,
  };

  /// Reads [toJson]; null when [raw] is not a shape.
  static QueryShape? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final p = raw['p'];
    final a = raw['a'];
    if (p is! Map<String, Object?> || a is! List<Object?>) return null;
    final provided = <String, Object>{};
    for (final e in p.entries) {
      final v = e.value;
      if (v is bool || v is num || v is String) provided[e.key] = v!;
    }
    return QueryShape(
      provided: provided,
      args: [
        for (final x in a)
          if (x is String) x,
      ],
      loaded: raw['l'] == true,
    );
  }

  @override
  String toString() =>
      'QueryShape(provided: ${provided.length}, '
      'args: ${args.length}, loaded: $loaded)';
}

/// What page mode discovered for one login account: `doc_id`s by query and
/// the page tokens, each with the time it was seen (T-045).
///
/// The values are secret (tokens) or session-bound: `toString` shows counts
/// only, and nothing here is ever logged.
final class DiscoverySnapshot {
  /// Creates a snapshot. [docIds] is keyed by `GraphqlQuery.name`.
  const DiscoverySnapshot({
    this.docIds = const {},
    this.tokens,
    this.tokensAt,
    this.shapes = const {},
  });

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
      final shapes = <String, QueryShape>{};
      final rawShapes = map['shapes'];
      if (rawShapes is Map<String, Object?>) {
        for (final e in rawShapes.entries) {
          final shape = QueryShape.fromJson(e.value);
          if (shape != null) shapes[e.key] = shape;
        }
      }
      return DiscoverySnapshot(
        docIds: docIds,
        tokens: tokens != null && tokensAt != null ? tokens : null,
        tokensAt: tokens != null ? tokensAt : null,
        shapes: shapes,
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

  /// The provider values and argument names by `GraphqlQuery.name`.
  final Map<String, QueryShape> shapes;

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
    if (shapes.isNotEmpty)
      'shapes': {for (final e in shapes.entries) e.key: e.value.toJson()},
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

/// A [DiscoveryStore] that also remembers when a foreground refresh was last
/// attempted per account, so a failing load is not retried at every app start
/// (T-045 QA-3). Not secret. [DiscoveryStore.clear] forgets it too.
abstract interface class DiscoveryAttemptStore implements DiscoveryStore {
  /// When a refresh was last attempted for [accountId], or null.
  Future<DateTime?> lastAttempt(int accountId);

  /// Records an attempt at [at].
  Future<void> markAttempt(int accountId, DateTime at);
}

/// A [DiscoveryStore] in memory, for tests and for builds that wire none.
/// Instances that share one object stand in for two isolates.
final class InMemoryDiscoveryStore implements DiscoveryAttemptStore {
  final Map<int, DiscoverySnapshot> _data = {};
  final Map<int, DateTime> _attempts = {};

  @override
  Future<DiscoverySnapshot?> load(int accountId) async => _data[accountId];

  @override
  Future<void> save(int accountId, DiscoverySnapshot snapshot) async {
    _data[accountId] = snapshot;
  }

  @override
  Future<void> clear(int accountId) async {
    _data.remove(accountId);
    _attempts.remove(accountId);
  }

  @override
  Future<DateTime?> lastAttempt(int accountId) async => _attempts[accountId];

  @override
  Future<void> markAttempt(int accountId, DateTime at) async {
    _attempts[accountId] = at;
  }

  @override
  String toString() => 'InMemoryDiscoveryStore(accounts: ${_data.length})';
}
