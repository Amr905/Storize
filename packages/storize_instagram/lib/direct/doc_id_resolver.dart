import 'package:storize_instagram/page/discovery_store.dart';

/// The GraphQL queries direct mode uses, by the web app's friendly name.
enum GraphqlQuery {
  /// Story items of users (`reel_ids_arr`).
  stories('PolarisStoriesV3ReelPageStandaloneQuery'),

  /// A profile by user id.
  profile('PolarisProfilePageContentQuery'),

  /// The posts of a user by username.
  posts('PolarisProfilePostsQuery'),

  /// The paging variant of the posts query (`..._connection`), used only
  /// for pages after the first (it takes `first` and `after`).
  postsPaging('PolarisProfilePostsTabContentQuery_connection'),

  /// The highlights tray of a profile. **The name is an assumption** (the
  /// T-002 capture saw the query but did not record its name): see
  /// INSTAGRAM_EXTRACTION.md v0.3.
  highlights('PolarisProfileStoryHighlightsTrayContentQuery');

  const GraphqlQuery(this.friendlyName);

  /// The `fb_api_req_friendly_name` value.
  final String friendlyName;

  /// Whether [name] is this query's friendly name, or a known alias of it
  /// (see [_aliasMatch]): Instagram renames and suffixes its queries, so an
  /// exact match alone leaves direct mode without a `doc_id`.
  bool matchesName(String? name) {
    if (name == null || name.isEmpty) return false;
    return name == friendlyName || _aliasMatch(name);
  }

  /// Whether [name] is exactly [friendlyName] (an alias is a weaker match).
  bool isExactName(String? name) => name == friendlyName;

  // The known aliases, in ONE place. A name that is only an alias is recorded
  // but never replaces a `doc_id` found under the exact name.
  //  - posts: `PolarisProfilePosts...` without `_connection` (first page).
  //  - postsPaging: `PolarisProfilePosts...` with `_connection`: its doc_id
  //    is used only for `timelinePage`, never for the first-page timeline.
  //  - stories: any `...StoriesV3Reel...` / `...ReelPageStandalone...` query
  //    except the tray and the seen mutation (other variables, or blocked).
  //  - profile: `PolarisProfilePageContentQuery...` with a suffix.
  bool _aliasMatch(String name) {
    switch (this) {
      case GraphqlQuery.posts:
        return name.startsWith('PolarisProfilePosts') &&
            !name.contains('_connection');
      case GraphqlQuery.postsPaging:
        return name.startsWith('PolarisProfilePosts') &&
            name.contains('_connection');
      case GraphqlQuery.stories:
        if (name.contains('Tray') || name.contains('Seen')) return false;
        return name.contains('StoriesV3Reel') ||
            name.contains('ReelPageStandalone');
      case GraphqlQuery.profile:
        return name.startsWith('PolarisProfilePageContentQuery');
      case GraphqlQuery.highlights:
        return name.contains('Highlights') && name.contains('Tray');
    }
  }
}

/// Finds the current `doc_id` of a query.
///
/// Instagram changes every `doc_id` on each deploy, so none is hard-coded
/// anywhere. Reading them from the page bundle or HTML is a later task
/// (T-014/T-015). When it returns null the GraphQL transport reports
/// `SchemaChanged('doc_id:<name>')`, which sends the run to page mode.
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class DocIdResolver {
  /// The `doc_id` for [query], or null if it cannot be found right now.
  Future<String?> docIdFor(GraphqlQuery query);
}

/// Supplies the page and session tokens a GraphQL POST carries (`fb_dtsg`,
/// `lsd`, `jazoest`, `av`, `__user` and similar). Whether a plain HTTP client
/// can obtain them without loading the page is unknown
/// (INSTAGRAM_EXTRACTION.md).
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class PageTokenProvider {
  /// The form fields to add to every GraphQL POST, or null when none are
  /// available. The values are secret: never log them.
  Future<Map<String, String>?> tokens();
}

/// A [DocIdResolver] that can drop a `doc_id` that proved stale.
abstract interface class DocIdForgetter implements DocIdResolver {
  /// Forgets the `doc_id` of [query] (memory and store).
  Future<void> forget(GraphqlQuery query);
}

/// A [DocIdResolver] that also knows the shape of the queries it found: the
/// relay provider values and the argument names the page's own modules gave
/// (T-048). Null when only a `doc_id` is known.
abstract interface class QueryShapeProvider implements DocIdResolver {
  /// The shape of [query] now, or null when unknown.
  Future<QueryShape?> shapeFor(GraphqlQuery query);
}

/// A [PageTokenProvider] that can drop tokens that proved stale (T-049).
abstract interface class TokenForgetter implements PageTokenProvider {
  /// Forgets the tokens (memory and store).
  Future<void> forgetTokens();
}

/// A [DocIdResolver] that can drop the provider values of one query that
/// proved wrong or missing (T-049); its `doc_id` stays.
abstract interface class ProviderForgetter implements DocIdResolver {
  /// Forgets the shape (providers) of [query] (memory and store).
  Future<void> forgetProviders(GraphqlQuery query);
}

/// Whether [tokens] holds both `fb_dtsg` and `lsd`, the two a GraphQL POST
/// cannot do without (T-049: without `fb_dtsg` Instagram answers a
/// `for (;;);` error body).
bool pageTokensComplete(Map<String, String>? tokens) =>
    (tokens?['fb_dtsg'] ?? '').isNotEmpty && (tokens?['lsd'] ?? '').isNotEmpty;
