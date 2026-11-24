import 'package:meta/meta.dart';
import 'package:storize_model/src/enums.dart';
import 'package:storize_model/src/remote_content.dart';

/// Keys of the `extras` of a [ContentKind.highlight] item.
abstract final class HighlightExtras {
  /// The highlight's ID (string).
  static const String id = 'highlightId';

  /// The highlight's title at download time (string).
  static const String title = 'highlightTitle';

  /// The position of the highlight in the tray, 0 first (int).
  static const String order = 'highlightOrder';
}

/// Progress of a post-history backfill, saved per target (FR-69).
@immutable
final class HistoryProgress {
  /// Creates progress.
  const HistoryProgress({
    required this.state,
    required this.fetched,
    required this.updatedAt,
    this.cursor,
    this.oldestSeenAt,
  });

  /// Where the backfill stands.
  final HistoryState state;

  /// The cursor of the next page, or null for the first page.
  final String? cursor;

  /// How many posts were looked at so far.
  final int fetched;

  /// The publish time of the oldest post seen so far.
  final DateTime? oldestSeenAt;

  /// When this record was last written (UTC).
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced. Pass null to clear
  /// [cursor] or [oldestSeenAt].
  HistoryProgress copyWith({
    HistoryState? state,
    Object? cursor = _unset,
    int? fetched,
    Object? oldestSeenAt = _unset,
    DateTime? updatedAt,
  }) => HistoryProgress(
    state: state ?? this.state,
    cursor: identical(cursor, _unset) ? this.cursor : cursor as String?,
    fetched: fetched ?? this.fetched,
    oldestSeenAt: identical(oldestSeenAt, _unset)
        ? this.oldestSeenAt
        : oldestSeenAt as DateTime?,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryProgress &&
          other.state == state &&
          other.cursor == cursor &&
          other.fetched == fetched &&
          other.oldestSeenAt == oldestSeenAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode =>
      Object.hash(state, cursor, fetched, oldestSeenAt, updatedAt);

  /// Omits [cursor], which is an opaque Instagram token.
  @override
  String toString() =>
      'HistoryProgress(${state.name}, fetched: $fetched, '
      'oldestSeenAt: $oldestSeenAt)';
}

const Object _unset = Object();

/// One page of a user's posts, newest first (IG-5).
@immutable
final class PostPage {
  /// Creates a page. The list is copied into an unmodifiable list.
  PostPage({required List<RemoteContent> items, this.nextCursor})
    : items = List<RemoteContent>.unmodifiable(items);

  /// The posts of this page.
  final List<RemoteContent> items;

  /// The cursor of the next page, or null on the last page.
  final String? nextCursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PostPage &&
          other.nextCursor == nextCursor &&
          other.items.length == items.length &&
          [
            for (var i = 0; i < items.length; i++) other.items[i] == items[i],
          ].every((e) => e));

  @override
  int get hashCode => Object.hash(nextCursor, Object.hashAll(items));

  @override
  String toString() =>
      'PostPage(items: ${items.length}, hasNext: ${nextCursor != null})';
}

/// A highlight in a user's tray (FR-71).
@immutable
final class RemoteHighlight {
  /// Creates a highlight entry.
  const RemoteHighlight({
    required this.id,
    required this.title,
    this.coverUrl,
    this.itemCount,
    this.latestItemAt,
  });

  /// The highlight ID, without the `highlight:` prefix.
  final String id;

  /// The title.
  final String title;

  /// The cover image URL. Signed, so redacted in [toString].
  final String? coverUrl;

  /// How many items it holds, when known.
  final int? itemCount;

  /// When its newest item was added. A change means new items.
  final DateTime? latestItemAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteHighlight &&
          other.id == id &&
          other.title == title &&
          other.coverUrl == coverUrl &&
          other.itemCount == itemCount &&
          other.latestItemAt == latestItemAt);

  @override
  int get hashCode => Object.hash(id, title, coverUrl, itemCount, latestItemAt);

  @override
  String toString() =>
      'RemoteHighlight(id: $id, itemCount: $itemCount, '
      'latestItemAt: $latestItemAt)';
}
