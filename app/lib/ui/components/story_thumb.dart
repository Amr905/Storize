import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/components/thumb_frame.dart';
import 'package:storize_app/ui/utils/bidi.dart';

/// 9:16 story tile (S-04, S-09): photo or video with a duration badge, a
/// "new" ring, a selected check and a broken state.
///
/// [content] is the already-decoded media widget (the screen passes an
/// `Image`); the component itself does no I/O.
class StoryThumb extends StatelessWidget {
  /// Creates a story tile. [semanticLabel] should read like
  /// "Story by @nour_k, video, 0:12, today 10:15".
  const StoryThumb({
    required this.semanticLabel,
    this.content,
    this.isVideo = false,
    this.duration,
    this.isNew = false,
    this.selected = false,
    this.selectionMode = false,
    this.broken = false,
    this.onTap,
    this.onLongPress,
    this.highlightLabel,
    super.key,
  });

  /// Spoken description.
  final String semanticLabel;

  /// Media content.
  final Widget? content;

  /// Video (shows the play + duration badge).
  final bool isVideo;

  /// Video length.
  final Duration? duration;

  /// Not yet seen: draws the primary ring.
  final bool isNew;

  /// Selected for bulk actions.
  final bool selected;

  /// Selection mode on: shows empty/filled check circles.
  final bool selectionMode;

  /// Media failed to load / file missing.
  final bool broken;

  /// Tap.
  final VoidCallback? onTap;

  /// Long press (starts selection).
  final VoidCallback? onLongPress;

  /// Shows the saffron "Highlight" badge with this text (null = hidden).
  final String? highlightLabel;

  @override
  Widget build(BuildContext context) {
    return ThumbFrame(
      aspectRatio: 9 / 16,
      semanticLabel: semanticLabel,
      content: content,
      isNew: isNew,
      selected: selected,
      selectionMode: selectionMode || selected,
      broken: broken,
      onTap: onTap,
      onLongPress: onLongPress,
      highlightLabel: highlightLabel,
      bottomStart: isVideo
          ? MediaBadge(
              icon: Icons.play_arrow_rounded,
              text: duration == null ? null : formatDuration(duration!),
            )
          : null,
    );
  }
}
