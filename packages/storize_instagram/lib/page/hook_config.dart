import 'dart:convert';

/// The JS handler name `hook.js` posts to.
const String pageHookHandlerName = 'storizeHook';

/// The origins accepted for page mode (AC5).
const Set<String> allowedPageOrigins = {
  'https://www.instagram.com',
  'https://instagram.com',
};

/// Configuration of `hook.js` for page mode.
///
/// [blockedFriendlyNames] are GraphQL `fb_api_req_friendly_name` values the
/// hook answers locally and never sends (UD-3). The default is the story
/// "seen" mutation. Passing a list replaces the default.
final class PageHookConfig {
  /// Creates the config.
  PageHookConfig({
    this.blockedFriendlyNames = defaultBlockedFriendlyNames,
    this.handlerName = pageHookHandlerName,
  }) {
    final pattern = RegExp(r'^[A-Za-z0-9_]{1,120}$');
    for (final name in blockedFriendlyNames) {
      if (!pattern.hasMatch(name)) {
        throw ArgumentError.value(name, 'blockedFriendlyNames', 'bad name');
      }
    }
  }

  /// `PolarisStoriesV3SeenMutation`: opening a story fires it (BR-8).
  static const List<String> defaultBlockedFriendlyNames = [
    'PolarisStoriesV3SeenMutation',
  ];

  /// Names whose requests are never sent.
  final List<String> blockedFriendlyNames;

  /// The handler name.
  final String handlerName;

  /// The JS that sets `window.__STORIZE_HOOK_CONFIG` before the hook runs.
  String prelude() =>
      'window.__STORIZE_HOOK_CONFIG = ${jsonEncode({
        'handler': handlerName,
        'includeBody': true,
        'includeRequestSecrets': true,
        'blockedFriendlyNames': blockedFriendlyNames,
      })};';

  /// The full user script for [hookSource] (the content of `hook.js`).
  String compose(String hookSource) => '${prelude()}\n$hookSource';
}
