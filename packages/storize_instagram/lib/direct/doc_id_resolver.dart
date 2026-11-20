/// The GraphQL queries direct mode uses, by the web app's friendly name.
enum GraphqlQuery {
  /// Story items of users (`reel_ids_arr`).
  stories('PolarisStoriesV3ReelPageStandaloneQuery'),

  /// A profile by user id.
  profile('PolarisProfilePageContentQuery'),

  /// The posts of a user by username.
  posts('PolarisProfilePostsQuery');

  const GraphqlQuery(this.friendlyName);

  /// The `fb_api_req_friendly_name` value.
  final String friendlyName;
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
