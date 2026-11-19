import 'package:storize_model/storize_model.dart';

/// URI scheme of Storize deep links (TECH_SPEC section 4.3).
const String deepLinkScheme = 'storize';

/// Parses a content or target ID: digits only, greater than zero.
/// Returns null for anything else (including null).
int? parseId(String? raw) {
  if (raw == null || !RegExp(r'^\d{1,15}$').hasMatch(raw)) return null;
  final id = int.parse(raw);
  return id > 0 ? id : null;
}

/// Parses the Library `kind` filter (`stories` or `posts`).
ContentKind? parseKind(String? raw) => switch (raw) {
  'stories' => ContentKind.story,
  'posts' => ContentKind.post,
  _ => null,
};

/// Sections of Settings that a link can scroll to.
enum SettingsSection {
  /// The storage section (`storize://settings/storage`).
  storage,
}

/// A parsed `storize://` link and the in-app location it opens.
sealed class DeepLink {
  const DeepLink();

  /// Parses [uri].
  ///
  /// Returns null when [uri] is not a `storize://` link. A `storize://` link
  /// that is unknown or has an invalid ID never throws: it becomes
  /// [LibraryLink] with no filters.
  static DeepLink? parse(Uri uri) {
    if (uri.scheme != deepLinkScheme) return null;
    final segments = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    if (segments.isEmpty) return const LibraryLink();
    final rest = segments.sublist(1);
    switch (segments.first) {
      case 'story':
        final id = rest.length == 1 ? parseId(rest.first) : null;
        return id == null ? const LibraryLink() : StoryLink(id);
      case 'post':
        final id = rest.length == 1 ? parseId(rest.first) : null;
        return id == null ? const LibraryLink() : PostLink(id);
      case 'account':
        return rest.isEmpty ? const AccountLink() : const LibraryLink();
      case 'library':
        if (rest.isNotEmpty) return const LibraryLink();
        return LibraryLink(
          kind: parseKind(uri.queryParameters['kind']),
          targetId: parseId(uri.queryParameters['target']),
        );
      case 'settings':
        if (rest.isEmpty) return const SettingsLink();
        if (rest.length == 1 && rest.first == 'storage') {
          return const SettingsLink(section: SettingsSection.storage);
        }
        return const LibraryLink();
      default:
        return const LibraryLink();
    }
  }

  /// The in-app location (path and query) for this link.
  String get location;
}

/// `storize://story/{contentId}`: S-06.
final class StoryLink extends DeepLink {
  /// Creates a link to story [contentId].
  const StoryLink(this.contentId);

  /// The content ID.
  final int contentId;

  @override
  String get location => '/story/$contentId';
}

/// `storize://post/{contentId}`: S-15.
final class PostLink extends DeepLink {
  /// Creates a link to post [contentId].
  const PostLink(this.contentId);

  /// The content ID.
  final int contentId;

  @override
  String get location => '/post/$contentId';
}

/// `storize://account`: S-13.
final class AccountLink extends DeepLink {
  /// Creates the account link.
  const AccountLink();

  @override
  String get location => '/account';
}

/// `storize://library?kind=posts&target={id}`: S-04 with filters.
final class LibraryLink extends DeepLink {
  /// Creates a Library link with optional filters.
  const LibraryLink({this.kind, this.targetId});

  /// Kind filter, if any.
  final ContentKind? kind;

  /// Target filter, if any.
  final int? targetId;

  @override
  String get location {
    final query = <String, String>{
      if (kind != null) 'kind': kind == ContentKind.post ? 'posts' : 'stories',
      if (targetId != null) 'target': '$targetId',
    };
    return Uri(
      path: '/library',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }
}

/// `storize://settings[/storage]`: S-12.
final class SettingsLink extends DeepLink {
  /// Creates a Settings link.
  const SettingsLink({this.section});

  /// The section to scroll to, if any.
  final SettingsSection? section;

  @override
  String get location =>
      section == null ? '/settings' : '/settings?section=${section!.name}';
}
