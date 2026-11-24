import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/page/discovery_store.dart';

/// The `doc_id`s and page tokens that page mode sees on the real page (AC9).
///
/// Implements the two direct-mode ports, so `GraphqlTransport` can use what a
/// page load found. Values expire (`docIdTtl`, `tokenTtl`). `toString` shows
/// counts only; nothing is logged or printed.
///
/// **Persistence (T-045).** With a [store], one instance per isolate shares
/// what was discovered: a read that finds nothing fresh in memory loads the
/// account's snapshot from the store, and [record] writes through (merged
/// with what the store holds, newest wins). With a store the token lifetime is
/// [persistedTokenTtl] (12 h), without one it is [tokenTtl].
///
/// It never loads a page itself: it is filled as a side effect of page-mode
/// runs. (A resolver that loaded pages would run inside the governed call of
/// the transport that asked it.)
final class PageDiscovery implements DocIdForgetter, PageTokenProvider {
  /// Creates a store-less (memory only) discovery, or one persisted in
  /// [store] under [accountId].
  PageDiscovery({
    this._clock = const SystemClock(),
    this.docIdTtl = const Duration(hours: 6),
    this.tokenTtl = const Duration(minutes: 30),
    this.persistedTokenTtl = const Duration(hours: 12),
    this.store,
    this.accountId = 0,
    this.onWriteError,
  });

  /// How long a discovered `doc_id` is offered.
  final Duration docIdTtl;

  /// How long discovered tokens are offered when nothing is persisted.
  final Duration tokenTtl;

  /// How long tokens are offered when a [store] keeps them.
  final Duration persistedTokenTtl;

  /// Where the snapshot is shared across isolates, or null.
  final DiscoveryStore? store;

  /// The login account the snapshot belongs to.
  final int accountId;

  /// Called with the error type when a write-through fails (never the text).
  final void Function(String errorType)? onWriteError;

  final Clock _clock;
  final Map<GraphqlQuery, (String, DateTime)> _docIds = {};
  final Set<GraphqlQuery> _exact = {};
  Map<String, String>? _tokens;
  DateTime? _tokensAt;
  // What this instance recorded and has not saved yet. Only this is merged
  // into the store, so a stale instance never writes old memory back after a
  // logout cleared the store (QA-2).
  final Map<GraphqlQuery, (String, DateTime)> _pendingIds = {};
  Map<String, String>? _pendingTokens;
  DateTime? _pendingTokensAt;
  bool _hadStored = false;
  Future<void> _writes = Future<void>.value();

  Duration get _tokenLife => store == null ? tokenTtl : persistedTokenTtl;

  /// Stores what one captured request carried (memory now, store soon: see
  /// [flush]).
  void record({
    required String? friendlyName,
    required String? docId,
    required Map<String, String> tokens,
  }) {
    final now = _clock.now();
    var changed = false;
    if (docId != null && friendlyName != null) {
      for (final q in GraphqlQuery.values) {
        if (!q.matchesName(friendlyName)) continue;
        final exact = q.isExactName(friendlyName);
        // An alias never replaces a fresh doc_id found under the exact name.
        if (!exact && _exact.contains(q) && _docIdFresh(q)) continue;
        if (exact) {
          _exact.add(q);
        } else {
          _exact.remove(q);
        }
        _docIds[q] = (docId, now);
        _pendingIds[q] = (docId, now);
        changed = true;
      }
    }
    if (tokens.isNotEmpty) {
      _tokens = Map.unmodifiable(tokens);
      _tokensAt = now;
      _pendingTokens = _tokens;
      _pendingTokensAt = now;
      changed = true;
    }
    if (changed && store != null) _enqueue(_persist);
  }

  /// Completes when the write-throughs started so far are done.
  Future<void> flush() => _writes;

  /// Forgets everything in memory and in the store.
  void clear() {
    _docIds.clear();
    _exact.clear();
    _tokens = null;
    _tokensAt = null;
    _pendingIds.clear();
    _pendingTokens = null;
    _pendingTokensAt = null;
    final s = store;
    if (s != null) _enqueue(() => s.clear(accountId));
  }

  @override
  Future<void> forget(GraphqlQuery query) async {
    _docIds.remove(query);
    _exact.remove(query);
    _pendingIds.remove(query);
    if (store != null) _enqueue(() => _persist(drop: query));
    await flush();
  }

  @override
  Future<String?> docIdFor(GraphqlQuery query) async {
    if (!_docIdFresh(query)) await _reload();
    return _docIdFresh(query) ? _docIds[query]!.$1 : null;
  }

  @override
  Future<Map<String, String>?> tokens() async {
    if (!_tokensFresh()) await _reload();
    return _tokensFresh() ? Map.of(_tokens!) : null;
  }

  bool _docIdFresh(GraphqlQuery query) {
    final entry = _docIds[query];
    if (entry == null) return false;
    if (_clock.now().difference(entry.$2) > docIdTtl) {
      _docIds.remove(query);
      return false;
    }
    return true;
  }

  bool _tokensFresh() {
    final at = _tokensAt;
    if (_tokens == null || at == null) return false;
    if (_clock.now().difference(at) > _tokenLife) {
      _tokens = null;
      _tokensAt = null;
      return false;
    }
    return true;
  }

  /// Adopts what the store holds when it is newer than memory.
  Future<void> _reload() async {
    final s = store;
    if (s == null) return;
    await _writes; // our own pending write first
    final DiscoverySnapshot? snap;
    try {
      snap = await s.load(accountId);
    } on Object catch (e) {
      onWriteError?.call('load:${e.runtimeType}');
      return;
    }
    if (snap == null) {
      if (_hadStored) _dropMemoryExceptPending(); // cleared behind us
      return;
    }
    _hadStored = true;
    for (final q in GraphqlQuery.values) {
      final e = snap.docIds[q.name];
      if (e == null) continue;
      final mine = _docIds[q];
      if (mine == null || e.at.isAfter(mine.$2)) _docIds[q] = (e.docId, e.at);
    }
    final t = snap.tokens;
    final at = snap.tokensAt;
    if (t != null &&
        at != null &&
        (_tokensAt == null || at.isAfter(_tokensAt!))) {
      _tokens = Map.unmodifiable(t);
      _tokensAt = at;
    }
  }

  void _enqueue(Future<void> Function() job) {
    _writes = _writes.then((_) async {
      try {
        await job();
      } on Object catch (e) {
        onWriteError?.call('write:${e.runtimeType}');
      }
    });
  }

  /// The store was cleared (logout) after this instance used it: forget what
  /// it held, keep only what it recorded itself and has not saved.
  void _dropMemoryExceptPending() {
    _hadStored = false;
    _docIds
      ..clear()
      ..addAll(_pendingIds);
    _tokens = _pendingTokens;
    _tokensAt = _pendingTokensAt;
  }

  /// Merges what this instance recorded into the stored snapshot (newest
  /// wins, expired entries and [drop] removed) and saves it, then re-reads it
  /// and repeats the merge (up to 3 times) if another isolate's write
  /// replaced ours (QA-1; narrows the race, cannot close it).
  Future<void> _persist({GraphqlQuery? drop}) async {
    final s = store!;
    for (var attempt = 0; attempt < 3; attempt++) {
      final stored = await s.load(accountId);
      if (stored == null && _hadStored) _dropMemoryExceptPending();
      final next = _merge(stored, drop);
      await s.save(accountId, next);
      _hadStored = true;
      // Verify after the write: a concurrent writer may have replaced it
      // with a snapshot built before ours. Repeat the merge if we are gone.
      final back = await s.load(accountId);
      if (_holds(back, next)) break;
    }
    if (drop == null) {
      _pendingIds.clear();
      _pendingTokens = null;
      _pendingTokensAt = null;
    }
  }

  /// Whether [back] still has every doc_id of [mine] (or a newer one).
  bool _holds(DiscoverySnapshot? back, DiscoverySnapshot mine) {
    if (back == null) return false;
    for (final e in mine.docIds.entries) {
      final got = back.docIds[e.key];
      if (got == null || got.at.isBefore(e.value.at)) return false;
    }
    return true;
  }

  DiscoverySnapshot _merge(DiscoverySnapshot? stored, GraphqlQuery? drop) {
    final now = _clock.now();
    final ids = <String, ({String docId, DateTime at})>{...?stored?.docIds};
    for (final e in _pendingIds.entries) {
      final old = ids[e.key.name];
      if (old == null || !old.at.isAfter(e.value.$2)) {
        ids[e.key.name] = (docId: e.value.$1, at: e.value.$2);
      }
    }
    if (drop != null) ids.remove(drop.name);
    ids.removeWhere((_, v) => now.difference(v.at) > docIdTtl);
    var tokens = stored?.tokens;
    var tokensAt = stored?.tokensAt;
    final mine = _pendingTokens;
    final mineAt = _pendingTokensAt;
    if (mine != null &&
        mineAt != null &&
        (tokensAt == null || !tokensAt.isAfter(mineAt))) {
      tokens = mine;
      tokensAt = mineAt;
    }
    if (tokensAt != null && now.difference(tokensAt) > persistedTokenTtl) {
      tokens = null;
      tokensAt = null;
    }
    return DiscoverySnapshot(docIds: ids, tokens: tokens, tokensAt: tokensAt);
  }

  /// The queries that have a fresh doc_id in memory (names only, for
  /// diagnostics: never a value).
  List<GraphqlQuery> get knownQueries => [
    for (final q in GraphqlQuery.values)
      if (_docIdFresh(q)) q,
  ];

  /// Whether fresh tokens are held in memory.
  bool get hasTokens => _tokensFresh();

  @override
  String toString() =>
      'PageDiscovery(docIds: ${_docIds.length}, tokens: ${_tokens != null})';
}
