/// The opaque cursor of `fetchPostPage`, shared by both modes.
///
/// Text form: `v1|<taken_at unix seconds>|<igCursor>` with an optional
/// `|<pk>,<pk>` suffix: the posts already delivered in the boundary second
/// ([takenAt]), so a tie across a page boundary loses and repeats nothing.
/// (An Instagram cursor holds no `|` or `,`.) Direct mode continues
/// with [igCursor] (Instagram's `end_cursor`). Page mode ignores it and
/// continues after [takenAt] (the oldest post delivered so far). A cursor
/// made by page mode has an empty [igCursor]: direct mode cannot use it.
final class PostCursor {
  /// Creates a cursor.
  const PostCursor({
    required this.takenAt,
    required this.igCursor,
    this.boundaryPks = const {},
  });

  /// The latest `taken_at` accepted (year 2100), against overflowing text.
  static final int maxSeconds =
      DateTime.utc(2100).millisecondsSinceEpoch ~/ 1000;

  /// Parses [text]; null when it is not a cursor made by [encode].
  static PostCursor? parse(String text) {
    final first = text.indexOf('|');
    if (first < 0 || text.substring(0, first) != 'v1') return null;
    final second = text.indexOf('|', first + 1);
    if (second < 0) return null;
    final seconds = int.tryParse(text.substring(first + 1, second));
    if (seconds == null || seconds < 0 || seconds > maxSeconds) return null;
    final rest = text.substring(second + 1);
    final bar = rest.indexOf('|');
    return PostCursor(
      takenAt: DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
      igCursor: bar < 0 ? rest : rest.substring(0, bar),
      boundaryPks: bar < 0
          ? const {}
          : {
              for (final pk in rest.substring(bar + 1).split(','))
                if (pk.isNotEmpty) pk,
            },
    );
  }

  /// The `taken_at` of the oldest post delivered so far.
  final DateTime takenAt;

  /// Instagram's `end_cursor`, or empty.
  final String igCursor;

  /// The pks delivered in the second [takenAt].
  final Set<String> boundaryPks;

  /// The text form.
  String encode() =>
      'v1|${takenAt.millisecondsSinceEpoch ~/ 1000}|$igCursor'
      '${boundaryPks.isEmpty ? '' : '|${boundaryPks.join(',')}'}';
}
