import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/doc_id_resolver.dart';

/// The `doc_id`s and page tokens that page mode sees on the real page (AC9).
///
/// Implements the two direct-mode ports, so `GraphqlTransport` can use what a
/// page load found. Memory only: nothing is persisted, logged or printed, and
/// `toString` shows counts only. Values expire (`docIdTtl`, `tokenTtl`).
///
/// It never loads a page itself: it is filled as a side effect of page-mode
/// runs. (A resolver that loaded pages would run inside the governed call of
/// the transport that asked it.)
final class PageDiscovery implements DocIdResolver, PageTokenProvider {
  /// Creates an empty store.
  PageDiscovery({
    this._clock = const SystemClock(),
    this.docIdTtl = const Duration(hours: 6),
    this.tokenTtl = const Duration(minutes: 30),
  });

  /// How long a discovered `doc_id` is offered.
  final Duration docIdTtl;

  /// How long discovered tokens are offered.
  final Duration tokenTtl;

  final Clock _clock;
  final Map<GraphqlQuery, (String, DateTime)> _docIds = {};
  Map<String, String>? _tokens;
  DateTime? _tokensAt;

  /// Stores what one captured request carried.
  void record({
    required String? friendlyName,
    required String? docId,
    required Map<String, String> tokens,
  }) {
    final now = _clock.now();
    if (docId != null && friendlyName != null) {
      for (final q in GraphqlQuery.values) {
        if (q.matchesName(friendlyName)) _docIds[q] = (docId, now);
      }
    }
    if (tokens.isNotEmpty) {
      _tokens = Map.unmodifiable(tokens);
      _tokensAt = now;
    }
  }

  /// Forgets everything.
  void clear() {
    _docIds.clear();
    _tokens = null;
    _tokensAt = null;
  }

  @override
  Future<String?> docIdFor(GraphqlQuery query) async {
    final entry = _docIds[query];
    if (entry == null) return null;
    if (_clock.now().difference(entry.$2) > docIdTtl) {
      _docIds.remove(query);
      return null;
    }
    return entry.$1;
  }

  @override
  Future<Map<String, String>?> tokens() async {
    final at = _tokensAt;
    final tokens = _tokens;
    if (tokens == null || at == null) return null;
    if (_clock.now().difference(at) > tokenTtl) {
      _tokens = null;
      _tokensAt = null;
      return null;
    }
    return Map.of(tokens);
  }

  @override
  String toString() =>
      'PageDiscovery(docIds: ${_docIds.length}, tokens: ${_tokens != null})';
}
