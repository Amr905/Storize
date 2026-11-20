import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// A story or post tile of S-04: the design-system thumb plus the data
/// mapping, the thumbnail image and the accessibility label.
class LibraryTile extends StatelessWidget {
  /// Creates a tile.
  const LibraryTile({
    required this.item,
    required this.account,
    required this.now,
    required this.kind,
    required this.selected,
    required this.selectionMode,
    required this.cacheWidth,
    required this.thumbBuilder,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  /// The content and its slides.
  final ContentWithMedia item;

  /// The username without "@".
  final String account;

  /// The current time (UTC), for "today" in the label.
  final DateTime now;

  /// Stories (9:16) or posts (square).
  final LibraryKind kind;

  /// Selected for bulk actions.
  final bool selected;

  /// Selection mode is on.
  final bool selectionMode;

  /// Decode width in pixels.
  final int cacheWidth;

  /// Makes the thumbnail image.
  final LibraryThumbBuilder thumbBuilder;

  /// Tap; `broken` tells whether the file failed.
  final void Function(ContentWithMedia item, bool broken) onTap;

  /// Long press.
  final ValueChanged<ContentWithMedia> onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final content = item.content;
    final first = item.media.isEmpty ? null : item.media.first;
    final broken = first?.status == MediaFileStatus.failed;
    final isVideo = content.kind == ContentKind.story
        ? first?.mediaType == MediaType.video
        : content.postType == PostType.video ||
              content.postType == PostType.reel;
    final durationMs = first?.durationMs;
    final duration = isVideo && durationMs != null
        ? Duration(milliseconds: durationMs)
        : null;
    final carousel = content.slideCount > 1 ? content.slideCount : null;

    final type = switch (content.postType) {
      _ when content.kind == ContentKind.story =>
        isVideo
            ? (duration == null
                  ? l10n.libTileVideo
                  : l10n.libTileVideoDuration(formatDuration(duration)))
            : l10n.libTilePhoto,
      PostType.carousel => l10n.libTileCarousel(content.slideCount),
      PostType.reel => l10n.libTileReel,
      PostType.video =>
        duration == null
            ? l10n.libTileVideo
            : l10n.libTileVideoDuration(formatDuration(duration)),
      _ => l10n.libTilePhoto,
    };
    final local = content.postedAt.toLocal();
    final today = now.toLocal();
    final dayDiff = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(local.year, local.month, local.day)).inDays;
    final day = dayDiff == 0
        ? l10n.libDateToday
        : dayDiff == 1
        ? l10n.libDateYesterday
        : loc.formatMediumDate(local);
    final when = l10n.libWhen(
      day,
      loc.formatTimeOfDay(TimeOfDay.fromDateTime(local)),
    );
    final base = content.kind == ContentKind.story
        ? l10n.libTileStory(account, type, when)
        : l10n.libTilePost(account, type, when);
    final label = [
      base,
      if (!content.viewed) l10n.thumbNew,
      if (selected) l10n.thumbSelected,
    ].join(', ');

    final thumbPath = first?.thumbPath;
    final image = thumbPath == null
        ? null
        : thumbBuilder(context, thumbPath, cacheWidth);

    return RepaintBoundary(
      child: kind == LibraryKind.stories
          ? StoryThumb(
              semanticLabel: label,
              content: image,
              isVideo: isVideo,
              duration: duration,
              isNew: !content.viewed,
              selected: selected,
              selectionMode: selectionMode,
              broken: broken,
              onTap: () => onTap(item, broken),
              onLongPress: () => onLongPress(item),
            )
          : PostThumb(
              semanticLabel: label,
              content: image,
              carouselCount: carousel,
              isVideo: isVideo,
              duration: duration,
              isNew: !content.viewed,
              selected: selected,
              selectionMode: selectionMode,
              broken: broken,
              onTap: () => onTap(item, broken),
              onLongPress: () => onLongPress(item),
            ),
    );
  }
}
