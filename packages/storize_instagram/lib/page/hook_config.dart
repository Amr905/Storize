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
/// hook answers locally and never sends (UD-3). The list is the **union** of
/// [defaultBlockedFriendlyNames] and the names passed in: a config can add
/// names but can never remove the story "seen" mutation.
final class PageHookConfig {
  /// Creates the config. [blockedFriendlyNames] are added to the default.
  PageHookConfig({
    List<String> blockedFriendlyNames = const [],
    this.handlerName = pageHookHandlerName,
  }) : blockedFriendlyNames = List.unmodifiable({
         ...defaultBlockedFriendlyNames,
         ...blockedFriendlyNames,
       }) {
    final pattern = RegExp(r'^[A-Za-z0-9_]{1,120}$');
    for (final name in this.blockedFriendlyNames) {
      if (!pattern.hasMatch(name)) {
        throw ArgumentError.value(name, 'blockedFriendlyNames', 'bad name');
      }
    }
  }

  /// `PolarisStoriesV3SeenMutation`: opening a story fires it (BR-8). Always
  /// blocked.
  static const List<String> defaultBlockedFriendlyNames = [
    'PolarisStoriesV3SeenMutation',
  ];

  /// Names whose requests are never sent: the default plus the configured.
  final List<String> blockedFriendlyNames;

  /// The handler name.
  final String handlerName;

  /// The JS that sets `window.__STORIZE_HOOK_CONFIG` before the hook runs.
  String prelude() =>
      'window.__STORIZE_HOOK_CONFIG = ${jsonEncode({'handler': handlerName, 'includeBody': true, 'includeRequestSecrets': true, 'blockedFriendlyNames': blockedFriendlyNames})};';

  /// The full user script for [hookSource] (the content of `hook.js`).
  String compose(String hookSource) => '${prelude()}\n$hookSource';
}
