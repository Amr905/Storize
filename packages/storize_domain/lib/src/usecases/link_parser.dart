import 'dart:convert';

import 'package:meta/meta.dart';

/// What an Instagram link points at (FR-80).
enum LinkKind {
  /// One story item: `/stories/<username>/<mediaPk>/`.
  story,

  /// A feed post: `/p/<shortcode>/`.
  post,

  /// A reel: `/reel/<shortcode>/` or `/reels/<shortcode>/`.
  reel,

  /// A highlight: `/stories/highlights/<id>/` or the share short link
  /// `/s/<base64>`.
  highlight,
}

/// An Instagram link understood by [LinkParser]. Never logged: it holds
/// usernames and ids.
@immutable
final class ParsedLink {
  /// Creates a link. Use [LinkParser.parse] in production code.
  const ParsedLink({
    required this.kind,
    this.username,
    this.mediaPk,
    this.shortcode,
    this.highlightId,
  });

  /// What the link points at.
  final LinkKind kind;

  /// The owner's username. Stories only (a post link may carry it too, but it
  /// is not needed).
  final String? username;

  /// The story media pk, or for a highlight link the `story_media_id` item
  /// (the part before `_`), when the link names one.
  final String? mediaPk;

  /// The post or reel shortcode.
  final String? shortcode;

  /// The highlight id (digits, without `highlight:`).
  final String? highlightId;

  @override
  bool operator ==(Object other) =>
      other is ParsedLink &&
      other.kind == kind &&
      other.username == username &&
      other.mediaPk == mediaPk &&
      other.shortcode == shortcode &&
      other.highlightId == highlightId;

  @override
  int get hashCode =>
      Object.hash(kind, username, mediaPk, shortcode, highlightId);

  // Not the values: a link is private.
  @override
  String toString() => 'ParsedLink(${kind.name})';
}

/// Reads Instagram links (FR-80). Pure Dart.
///
/// Accepts the host `instagram.com` with `www.` or `m.` (also bare, without a
/// scheme), ignores the query string except `story_media_id` of a highlight,
/// and ignores a trailing slash and the text around a shared link ("Look at
/// this https://..."). Anything else is `null`.
abstract final class LinkParser {
  static final RegExp _url = RegExp(
    r'(?<![A-Za-z0-9.\-/=@%])(?:https?://)?(?:www\.|m\.)?instagram\.com/[^\s<>"]*',
    caseSensitive: false,
  );
  static final RegExp _username = RegExp(r'^[A-Za-z0-9._]{1,30}$');
  static final RegExp _shortcode = RegExp(r'^[A-Za-z0-9_-]{5,40}$');
  static final RegExp _digits = RegExp(r'^\d{1,25}$');

  /// The first Instagram link in [text], or null. Cheap: used to decide
  /// whether to prefill from the clipboard.
  static bool containsInstagramLink(String text) => _url.hasMatch(text);

  /// Parses the first Instagram link in [text]; null when there is none or it
  /// is not a supported form.
  static ParsedLink? parse(String text) {
    final match = _url.firstMatch(text.trim());
    if (match == null) return null;
    var raw = match.group(0)!;
    // Trailing punctuation of a sentence is not part of the link.
    raw = raw.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');
    final withScheme = RegExp('^https?://', caseSensitive: false).hasMatch(raw)
        ? raw
        : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) return null;
    final segments = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s,
    ];
    if (segments.isEmpty) return null;
    final storyMedia = _storyMediaPk(uri.queryParameters['story_media_id']);
    switch (segments.first.toLowerCase()) {
      case 'stories':
        return _stories(segments.sublist(1), storyMedia);
      case 'p':
        return segments.length == 2 ? _post(segments[1], LinkKind.post) : null;
      case 'reel':
      case 'reels':
        return segments.length == 2 ? _post(segments[1], LinkKind.reel) : null;
      case 's':
        return segments.length == 2 ? _short(segments[1], storyMedia) : null;
      default:
        // `/<username>/p/<shortcode>/` (also `/<username>/reel/<code>/`).
        if (segments.length == 3 && _username.hasMatch(segments.first)) {
          switch (segments[1].toLowerCase()) {
            case 'p':
              return _post(segments[2], LinkKind.post);
            case 'reel':
              return _post(segments[2], LinkKind.reel);
          }
        }
        return null;
    }
  }

  static ParsedLink? _stories(List<String> rest, String? storyMedia) {
    if (rest.isEmpty) return null;
    if (rest.first.toLowerCase() == 'highlights') {
      if (rest.length != 2 || !_digits.hasMatch(rest[1])) return null;
      return ParsedLink(
        kind: LinkKind.highlight,
        highlightId: rest[1],
        mediaPk: storyMedia,
      );
    }
    if (rest.length != 2) return null;
    if (!_username.hasMatch(rest[0]) || !_digits.hasMatch(rest[1])) {
      return null;
    }
    return ParsedLink(
      kind: LinkKind.story,
      username: rest[0],
      mediaPk: rest[1],
    );
  }

  static ParsedLink? _post(String shortcode, LinkKind kind) =>
      _shortcode.hasMatch(shortcode)
      ? ParsedLink(kind: kind, shortcode: shortcode)
      : null;

  /// The share short link: the segment is base64 of `highlight:<id>`.
  static ParsedLink? _short(String encoded, String? storyMedia) {
    try {
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(Uri.decodeComponent(encoded))),
      );
      const prefix = 'highlight:';
      if (!decoded.startsWith(prefix)) return null;
      final id = decoded.substring(prefix.length);
      if (!_digits.hasMatch(id)) return null;
      return ParsedLink(
        kind: LinkKind.highlight,
        highlightId: id,
        mediaPk: storyMedia,
      );
    } on Object {
      return null;
    }
  }

  /// `story_media_id=<pk>_<uid>`: the pk is the part before `_`.
  static String? _storyMediaPk(String? value) {
    if (value == null || value.isEmpty) return null;
    final pk = value.split('_').first;
    return _digits.hasMatch(pk) ? pk : null;
  }
}
