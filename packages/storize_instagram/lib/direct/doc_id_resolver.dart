/// The GraphQL queries direct mode uses, by the web app's friendly name.
enum GraphqlQuery {
  /// Story items of users (`reel_ids_arr`).
  stories('PolarisStoriesV3ReelPageStandaloneQuery'),

  /// A profile by user id.
  profile('PolarisProfilePageContentQuery'),

  /// The posts of a user by username.
  posts('PolarisProfilePostsQuery'),

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
  //  - posts: `PolarisProfilePosts...`, including the paging variant
  //    `...TabContentQuery_connection`: its variables are `username`, `data`,
  //    `first` and `after`, which is what the timeline request builds, so its
  //    doc_id is compatible.
  //  - stories: any `...StoriesV3Reel...` / `...ReelPageStandalone...` query
  //    except the tray and the seen mutation (other variables, or blocked).
  //  - profile: `PolarisProfilePageContentQuery...` with a suffix.
  bool _aliasMatch(String name) {
    switch (this) {
      case GraphqlQuery.posts:
        return name.startsWith('PolarisProfilePosts');
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
