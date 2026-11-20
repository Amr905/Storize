import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/direct/graphql_transport.dart';
import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/direct/rest_transport.dart';
import 'package:storize_instagram/probe/probe.dart';

/// Which protocol direct mode should prefer (ADR-0003 addendum).
enum TransportPreference {
  /// The observed GraphQL queries. The default.
  graphql,

  /// REST, but only where a probe report says `restProven`. Without a proven
  /// report this is the same as [graphql].
  restWhenProven,
}

/// Picks the direct-mode transport.
///
/// GraphQL is the default and the fallback. `RestTransport` is returned only
/// when [preference] is [TransportPreference.restWhenProven] **and** [probe]
/// exists with `restProven == true` (every REST candidate answered as the
/// mapper expects, in the T-013 live probe). A missing or failed probe never
/// enables REST.
///
/// [docIds] and [tokens] feed the GraphQL transport; pass the one
/// `PageDiscovery` that page mode also fills, so a page load teaches direct
/// mode the current `doc_id`s and tokens.
IgTransport selectTransport({
  required DocIdResolver docIds,
  required PageTokenProvider tokens,
  TransportPreference preference = TransportPreference.graphql,
  ProbeReport? probe,
}) {
  if (preference == TransportPreference.restWhenProven &&
      probe != null &&
      probe.restProven) {
    return const RestTransport();
  }
  return GraphqlTransport(docIds: docIds, tokens: tokens);
}
