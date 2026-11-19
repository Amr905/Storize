import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/components/thumb_frame.dart';
import 'package:storize_app/ui/utils/bidi.dart';

/// Square post tile (S-04 Posts): carousel-count badge, video badge, "new"
/// ring, selected check and broken state. Presentational like `StoryThumb`.
class PostThumb extends StatelessWidget {
  /// Creates a post tile.
  const PostThumb({
    required this.semanticLabel,
    this.content,
    this.carouselCount,
    this.isVideo = false,
    this.duration,
    this.isNew = false,
    this.selected = false,
    this.selectionMode = false,
    this.broken = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  /// Spoken description.
  final String semanticLabel;

  /// Media content.
  final Widget? content;

  /// Number of items when the post is a carousel (> 1 shows the badge).
  final int? carouselCount;

  /// Video post/reel (shows a play badge).
  final bool isVideo;

  /// Video length (optional, shown next to the play icon).
  final Duration? duration;

  /// Not yet seen: draws the primary ring.
  final bool isNew;

  /// Selected for bulk actions.
  final bool selected;

  /// Selection mode on.
  final bool selectionMode;

  /// Media failed to load / file missing.
  final bool broken;

  /// Tap.
  final VoidCallback? onTap;

  /// Long press.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final count = carouselCount;
    return ThumbFrame(
      aspectRatio: 1,
      semanticLabel: semanticLabel,
      content: content,
      isNew: isNew,
      selected: selected,
      selectionMode: selectionMode || selected,
      broken: broken,
      onTap: onTap,
      onLongPress: onLongPress,
      topEnd: count != null && count > 1
          ? MediaBadge(icon: Icons.collections_rounded, text: '$count')
          : null,
      bottomStart: isVideo
          ? MediaBadge(
              icon: Icons.play_arrow_rounded,
              text: duration == null ? null : formatDuration(duration!),
            )
          : null,
    );
  }
}
