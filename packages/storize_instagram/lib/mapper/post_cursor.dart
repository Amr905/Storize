/// The opaque cursor of `fetchPostPage`, shared by both modes.
///
/// Text form: `v1|<taken_at unix seconds>|<igCursor>`. Direct mode continues
/// with [igCursor] (Instagram's `end_cursor`). Page mode ignores it and
/// continues after [takenAt] (the oldest post delivered so far). A cursor
/// made by page mode has an empty [igCursor]: direct mode cannot use it.
final class PostCursor {
  /// Creates a cursor.
  const PostCursor({required this.takenAt, required this.igCursor});

  /// Parses [text]; null when it is not a cursor made by [encode].
  static PostCursor? parse(String text) {
    final first = text.indexOf('|');
    if (first < 0 || text.substring(0, first) != 'v1') return null;
    final second = text.indexOf('|', first + 1);
    if (second < 0) return null;
    final seconds = int.tryParse(text.substring(first + 1, second));
    if (seconds == null) return null;
    return PostCursor(
      takenAt: DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
      igCursor: text.substring(second + 1),
    );
  }

  /// The `taken_at` of the oldest post delivered so far.
  final DateTime takenAt;

  /// Instagram's `end_cursor`, or empty.
  final String igCursor;

  /// The text form.
  String encode() => 'v1|${takenAt.millisecondsSinceEpoch ~/ 1000}|$igCursor';
}
