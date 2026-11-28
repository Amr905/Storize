/// What the in-page transport needs from a WebView (T-050).
library;

/// The queries the bundled `inpage_query.js` may run (read queries only).
/// Mirrors `QUERY_ALLOWLIST` of the script; the Dart side refuses anything
/// else before the script is called.
const Set<String> inPageQueryAllowlist = {
  'PolarisProfilePostsQuery',
  'PolarisProfilePostsTabContentQuery_connection',
  'PolarisStoriesV3ReelPageStandaloneQuery',
  'PolarisProfileStoryHighlightsTrayContentQuery',
  'PolarisPostRootQuery',
};

/// Whether [name] may be run in the page: on the allowlist and without
/// `Mutation` or `Seen` in it.
bool inPageQueryAllowed(String name) =>
    inPageQueryAllowlist.contains(name) &&
    !name.contains('Mutation') &&
    !name.contains('Seen');

/// A `PageSession` that can also run a script in the page's own JavaScript
/// world (`callAsyncJavaScript`). Kept apart from `PageSession` so existing
/// fakes keep compiling; a session that does not implement it cannot do
/// in-page fetching.
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class InPageScriptRunner {
  /// Runs [functionBody] (the body of an async function) with [arguments] as
  /// its named parameters and returns the JSON-like value it returns.
  Future<Object?> callAsync(
    String functionBody,
    Map<String, Object?> arguments,
  );
}

/// The function body of the readiness probe: `scriptSource` plus a call.
String inPageReadyBody(String scriptSource) =>
    '$scriptSource\nreturn __storizeReady();';

/// The function body of one query; `name` and `varsJson` are arguments.
String inPageQueryBody(String scriptSource) =>
    '$scriptSource\nreturn await __storizeQuery(name, varsJson);';
