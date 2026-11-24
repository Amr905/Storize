import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/direct/fallback_transport.dart';
import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/direct/rest_transport.dart';
import 'package:storize_instagram/probe/probe.dart';

/// Which protocol direct mode should prefer (ADR-0003 addendum).
enum TransportPreference {
  /// GraphQL when its `doc_id` and tokens are known, otherwise
  /// `SchemaChanged` (page mode decides); REST only for probe-proven ops
  /// (`FallbackTransport`). The default.
  graphql,

  /// REST, but only where a probe report says `restProven`. Without a proven
  /// report this is the same as [graphql].
  restWhenProven,
}

/// Picks the direct-mode transport.
///
/// The default is `FallbackTransport`: GraphQL per call when it can run
/// (T-044), REST only for probe-proven ops (T-045). `RestTransport` alone is
/// returned only
/// when [preference] is [TransportPreference.restWhenProven] **and** [probe]
/// exists with `restProven == true` (every REST candidate answered as the
/// mapper expects, in the T-013 live probe). A missing or failed probe does
/// not pin REST, and REST is then used only for the proven ops
/// (`provenRestOps`); an unproven REST route is never tried (T-045).
///
/// [docIds] and [tokens] feed the GraphQL transport; pass the one
/// `PageDiscovery` that page mode also fills, so a page load teaches direct
/// mode the current `doc_id`s and tokens.
IgTransport selectTransport({
  required DocIdResolver docIds,
  required PageTokenProvider tokens,
  TransportPreference preference = TransportPreference.graphql,
  ProbeReport? probe,
  DiagnosticLog? log,
}) {
  if (preference == TransportPreference.restWhenProven &&
      probe != null &&
      probe.restProven) {
    return const RestTransport();
  }
  return FallbackTransport(
    docIds: docIds,
    tokens: tokens,
    restOps: provenRestOps(probe),
    log: log,
  );
}

/// The [IgTransport] op names whose REST candidate [probe] proved (T-045):
/// IG-1 `userByUsername`, IG-2 `storyReels` and `highlightItems`, IG-3
/// `userById`, IG-4 `viewer`, IG-5 `timeline` and `timelinePage`. The
/// highlights tray has no candidate in the probe, so it is never proven.
/// No report gives an empty set.
Set<String> provenRestOps(ProbeReport? probe) {
  const ops = {
    'IG-1': ['userByUsername'],
    'IG-2': ['storyReels', 'highlightItems'],
    'IG-3': ['userById'],
    'IG-4': ['viewer'],
    'IG-5': ['timeline', 'timelinePage'],
  };
  if (probe == null) return const {};
  return {
    for (final e in probe.entries)
      if (e.proven) ...?ops[e.id],
  };
}
