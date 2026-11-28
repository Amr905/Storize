import 'package:meta/meta.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_model/storize_model.dart';

/// The owner of linked content and the items that were found (FR-80).
@immutable
final class LinkedItems {
  /// Creates the value. [items] is copied into an unmodifiable list.
  LinkedItems({required this.user, required List<RemoteContent> items})
    : items = List.unmodifiable(items);

  /// Who posted the items.
  final RemoteUser user;

  /// The items: one post or reel, or all items of a highlight.
  final List<RemoteContent> items;
}

/// Reads content that an Instagram link points at, where
/// [ContentPlatform] has no call for it (FR-80, T-060). Additive to the
/// port: a platform adds it next to `ContentPlatform`, so existing
/// implementers keep compiling.
///
/// A story link needs no method: `resolveUser` then `fetchStories`.
/// Implementations route every call through the request governor.
abstract interface class LinkedContentSource {
  /// Reads one post or reel by its [shortcode] (an interactive,
  /// read-only query).
  ///
  /// A post that is removed, or that the account may not see, is
  /// `Err(TargetNotFound)` or `Err(TargetNotVisible)`.
  Future<Result<LinkedItems>> fetchPostByShortcode(
    String shortcode, {
    required ExtractionPolicy policy,
  });

  /// Reads all items of the highlight [highlightId] and its owner. Items have
  /// [ContentKind.highlight] (see `fetchHighlightItems`).
  Future<Result<LinkedItems>> fetchHighlightWithOwner(
    String highlightId, {
    required ExtractionPolicy policy,
  });
}
