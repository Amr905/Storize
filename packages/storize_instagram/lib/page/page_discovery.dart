import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/page/discovery_store.dart';
import 'package:storize_instagram/page/hook_protocol.dart';

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
final class PageDiscovery
    implements
        DocIdForgetter,
        TokenForgetter,
        ProviderForgetter,
        QueryShapeProvider {
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
  final Map<GraphqlQuery, QueryShape> _shapes = {};
  final Map<GraphqlQuery, QueryShape> _pendingShapes = {};
  Map<String, String>? _tokens;
  DateTime? _tokensAt;
  final Map<String, String> _tokenSources = {};
  // What this instance recorded and has not saved yet. Only this is merged
  // into the store, so a stale instance never writes old memory back after a
  // logout cleared the store (QA-2).
  final Map<GraphqlQuery, (String, DateTime)> _pendingIds = {};
  Map<String, String>? _pendingTokens;
  DateTime? _pendingTokensAt;
  bool _hadStored = false;
  Future<void> _writes = Future<void>.value();

  Duration get _tokenLife => store == null ? tokenTtl : persistedTokenTtl;

  /// Merges [incoming] tokens into the held ones: a key is added or replaced,
  /// never removed, and an empty value never replaces a good one (T-049: a
  /// capture without `fb_dtsg` used to wipe the discovered pair). [source] is
  /// `module` or `capture`, for the diagnostic only. Returns whether anything
  /// changed.
  bool _mergeTokens(Map<String, String> incoming, String source, DateTime now) {
    final next = <String, String>{...?_tokensFreshOrNull()};
    var changed = false;
    for (final e in incoming.entries) {
      if (e.value.isEmpty) continue;
      if (next[e.key] != e.value) changed = true;
      next[e.key] = e.value;
      if (e.key == 'fb_dtsg' || e.key == 'lsd') _tokenSources[e.key] = source;
    }
    if (!changed) return false;
    _tokens = Map.unmodifiable(next);
    _tokensAt = now;
    _pendingTokens = Map.unmodifiable({...?_pendingTokens, ...next});
    _pendingTokensAt = now;
    return true;
  }

  Map<String, String>? _tokensFreshOrNull() => _tokensFresh() ? _tokens : null;

  /// Merges a shape into memory: provider values are united (the new ones
  /// win), non-empty argument names replace, `loaded` sticks.
  void _mergeShape(
    GraphqlQuery q, {
    Map<String, Object> provided = const {},
    List<String> args = const [],
    bool loaded = false,
    bool overrideProvided = true,
  }) {
    final old = _shapes[q];
    final merged = QueryShape(
      provided: overrideProvided
          ? {...?old?.provided, ...provided}
          : {...provided, ...?old?.provided},
      args: args.isNotEmpty ? args : (old?.args ?? const []),
      loaded: loaded || (old?.loaded ?? false),
    );
    _shapes[q] = merged;
    _pendingShapes[q] = merged;
  }

  /// Stores what one captured request carried (memory now, store soon: see
  /// [flush]). [provided] and [args] are the `variables` of the request: a
  /// real request of the web app, so a fallback for providers the page's
  /// modules did not show (T-049). Tokens are merged, never replaced.
  void record({
    required String? friendlyName,
    required String? docId,
    required Map<String, String> tokens,
    Map<String, Object> provided = const {},
    List<String> args = const [],
    bool variablesSeen = false,
  }) {
    final now = _clock.now();
    var changed = false;
    if (friendlyName != null) {
      for (final q in GraphqlQuery.values) {
        if (!q.matchesName(friendlyName)) continue;
        final exact = q.isExactName(friendlyName);
        var docRecorded = false;
        if (docId != null) {
          // An alias never replaces a fresh doc_id found under the exact name.
          if (!exact && _exact.contains(q) && _docIdFresh(q)) continue;
          if (exact) {
            _exact.add(q);
          } else {
            _exact.remove(q);
          }
          _docIds[q] = (docId, now);
          _pendingIds[q] = (docId, now);
          docRecorded = true;
          changed = true;
        }
        // Providers of a request belong to its own op: the exact name, or an
        // alias whose doc_id was just taken from the same request.
        if ((provided.isNotEmpty || args.isNotEmpty || variablesSeen) &&
            (exact || docRecorded)) {
          // The page's own modules (recorded by recordDiscovery) win.
          _mergeShape(
            q,
            provided: provided,
            args: _shapes[q]?.args.isNotEmpty ?? false ? const [] : args,
            loaded: true,
            overrideProvided: false,
          );
          changed = true;
        }
      }
    }
    if (_mergeTokens(tokens, 'capture', now)) changed = true;
    if (changed && store != null) _enqueue(_persist);
  }

  /// Stores what the hook read from the page's own modules (T-048): for each
  /// op with an exact query name, its doc_id (an exact name beats an alias),
  /// provider values and argument names; `fb_dtsg` and `lsd` are merged into
  /// the tokens (each on its own). Unknown op names are ignored. Returns the
  /// queries recorded.
  List<GraphqlQuery> recordDiscovery(
    List<DiscoveredOp> ops,
    Map<String, String> tokens, {
    Map<String, String> tokenSources = const {},
  }) {
    final now = _clock.now();
    final recorded = <GraphqlQuery>[];
    for (final op in ops) {
      for (final q in GraphqlQuery.values) {
        if (!q.isExactName(op.name)) continue;
        _exact.add(q);
        _docIds[q] = (op.docId, now);
        _pendingIds[q] = (op.docId, now);
        _mergeShape(q, provided: op.provided, args: op.args, loaded: op.loaded);
        recorded.add(q);
      }
    }
    var changed = recorded.isNotEmpty;
    final usable = {
      for (final k in const ['fb_dtsg', 'lsd'])
        if ((tokens[k] ?? '').isNotEmpty) k: tokens[k]!,
    };
    for (final src in {'module', 'capture'}) {
      final part = {
        for (final e in usable.entries)
          if ((tokenSources[e.key] ?? 'module') == src) e.key: e.value,
      };
      if (part.isNotEmpty && _mergeTokens(part, src, now)) changed = true;
    }
    if (changed && store != null) _enqueue(_persist);
    return recorded;
  }

  /// A secret-free summary for the diagnostic log: the number of provider
  /// values per known query and which tokens are held, with their source.
  String describe() {
    final per = [
      for (final q in GraphqlQuery.values)
        if (_shapes[q] != null)
          '${q.friendlyName}:${_shapes[q]!.provided.length}',
    ];
    String tok(String k) => (_tokens?[k] ?? '').isEmpty
        ? 'no'
        : 'yes(${_tokenSources[k] ?? 'store'})';
    return 'provided=${per.isEmpty ? 'none' : per.join(',')} '
        'tokens=dtsg:${tok('fb_dtsg')},lsd:${tok('lsd')}';
  }

  @override
  Future<QueryShape?> shapeFor(GraphqlQuery query) async {
    if (!_docIdFresh(query)) await _reload();
    return _docIdFresh(query) ? _shapes[query] : null;
  }

  /// Completes when the write-throughs started so far are done.
  Future<void> flush() => _writes;

  /// Forgets everything in memory and in the store.
  void clear() {
    _docIds.clear();
    _exact.clear();
    _shapes.clear();
    _pendingShapes.clear();
    _tokens = null;
    _tokensAt = null;
    _pendingIds.clear();
    _pendingTokens = null;
    _pendingTokensAt = null;
    _tokenSources.clear();
    final s = store;
    if (s != null) _enqueue(() => s.clear(accountId));
  }

  @override
  Future<void> forget(GraphqlQuery query) async {
    _docIds.remove(query);
    _exact.remove(query);
    _shapes.remove(query);
    _pendingShapes.remove(query);
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

  @override
  Future<void> forgetTokens() async {
    _tokens = null;
    _tokensAt = null;
    _pendingTokens = null;
    _pendingTokensAt = null;
    _tokenSources.clear();
    if (store != null) _enqueue(() => _persist(dropTokens: true));
    await flush();
  }

  @override
  Future<void> forgetProviders(GraphqlQuery query) async {
    _shapes.remove(query);
    _pendingShapes.remove(query);
    if (store != null) _enqueue(() => _persist(dropShape: query));
    await flush();
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
      if (mine == null || e.at.isAfter(mine.$2)) {
        _docIds[q] = (e.docId, e.at);
        final shape = snap.shapes[q.name];
        if (shape != null) _shapes[q] = shape;
      }
    }
    final t = snap.tokens;
    final at = snap.tokensAt;
    if (t != null && at != null) {
      // Key-wise: a stored pair never wipes newer memory, memory never wipes
      // a stored key it lacks.
      final newer = _tokensAt == null || at.isAfter(_tokensAt!);
      _tokens = Map.unmodifiable(
        newer ? {...?_tokens, ...t} : {...t, ...?_tokens},
      );
      if (newer) _tokensAt = at;
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
    _shapes
      ..clear()
      ..addAll(_pendingShapes);
    _tokens = _pendingTokens;
    _tokensAt = _pendingTokensAt;
  }

  /// Merges what this instance recorded into the stored snapshot (newest
  /// wins, expired entries and [drop] removed) and saves it, then re-reads it
  /// and repeats the merge (up to 3 times) if another isolate's write
  /// replaced ours (QA-1; narrows the race, cannot close it).
  Future<void> _persist({
    GraphqlQuery? drop,
    GraphqlQuery? dropShape,
    bool dropTokens = false,
  }) async {
    final s = store!;
    for (var attempt = 0; attempt < 3; attempt++) {
      final stored = await s.load(accountId);
      if (stored == null && _hadStored) _dropMemoryExceptPending();
      final next = _merge(stored, drop, dropShape, dropTokens);
      await s.save(accountId, next);
      _hadStored = true;
      // Verify after the write: a concurrent writer may have replaced it
      // with a snapshot built before ours. Repeat the merge if we are gone.
      final back = await s.load(accountId);
      if (_holds(back, next)) break;
    }
    if (drop == null && dropShape == null && !dropTokens) {
      _pendingIds.clear();
      _pendingShapes.clear();
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

  DiscoverySnapshot _merge(
    DiscoverySnapshot? stored,
    GraphqlQuery? drop,
    GraphqlQuery? dropShape,
    bool dropTokens,
  ) {
    final now = _clock.now();
    final ids = <String, ({String docId, DateTime at})>{...?stored?.docIds};
    for (final e in _pendingIds.entries) {
      final old = ids[e.key.name];
      if (old == null || !old.at.isAfter(e.value.$2)) {
        ids[e.key.name] = (docId: e.value.$1, at: e.value.$2);
      }
    }
    final shapes = <String, QueryShape>{...?stored?.shapes};
    for (final e in _pendingShapes.entries) {
      shapes[e.key.name] = e.value;
    }
    if (drop != null) {
      ids.remove(drop.name);
      shapes.remove(drop.name);
    }
    if (dropShape != null) shapes.remove(dropShape.name);
    ids.removeWhere((_, v) => now.difference(v.at) > docIdTtl);
    shapes.removeWhere((k, _) => !ids.containsKey(k));
    var tokens = dropTokens ? null : stored?.tokens;
    var tokensAt = dropTokens ? null : stored?.tokensAt;
    final mine = _pendingTokens;
    final mineAt = _pendingTokensAt;
    if (mine != null && mineAt != null) {
      // Key-wise, and an empty value never replaces a good one.
      final newer = tokensAt == null || !tokensAt.isAfter(mineAt);
      final good = {
        for (final e in mine.entries)
          if (e.value.isNotEmpty) e.key: e.value,
      };
      tokens = newer ? {...?tokens, ...good} : {...good, ...?tokens};
      if (newer) tokensAt = mineAt;
    }
    if (tokensAt != null && now.difference(tokensAt) > persistedTokenTtl) {
      tokens = null;
      tokensAt = null;
    }
    return DiscoverySnapshot(
      docIds: ids,
      tokens: tokens,
      tokensAt: tokensAt,
      shapes: shapes,
    );
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
