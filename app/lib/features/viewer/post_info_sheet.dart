import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The Instagram link of a post, built from its shortcode (FR-62). Null when
/// the shortcode is unknown.
String? postLinkFor(Content content) {
  final code = content.shortcode;
  if (code == null || code.isEmpty) return null;
  return 'https://www.instagram.com/p/$code/';
}

/// Shows the S-15 Info sheet for [item].
Future<void> showPostInfoSheet(
  BuildContext context, {
  required ContentWithMedia item,
  required String username,
}) => showModalBottomSheet<void>(
  context: context,
  shape: const RoundedRectangleBorder(borderRadius: StorizeRadii.sheetRadius),
  builder: (_) => PostInfoSheet(item: item, username: username),
);

/// The Info sheet body: the post link (copyable), slide count, size, type,
/// posted time and the gallery folder. Rows without a value are left out.
class PostInfoSheet extends StatefulWidget {
  /// Creates the sheet.
  const PostInfoSheet({required this.item, required this.username, super.key});

  /// The post.
  final ContentWithMedia item;

  /// The account handle without "@", for the default folder.
  final String username;

  @override
  State<PostInfoSheet> createState() => _PostInfoSheetState();
}

class _PostInfoSheetState extends State<PostInfoSheet> {
  bool _copied = false;

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) setState(() => _copied = true);
  }

  static String _when(BuildContext context, DateTime utc) {
    final loc = MaterialLocalizations.of(context);
    final local = utc.toLocal();
    return '${loc.formatMediumDate(local)} · '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = widget.item.content;
    final media = widget.item.media;
    final link = postLinkFor(content);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final sizes = [
      for (final m in media)
        if (m.sizeBytes != null) m.sizeBytes!,
    ];
    final totalBytes = sizes.fold<int>(0, (a, b) => a + b);
    final folder = media.isEmpty
        ? 'Pictures/Storize/${widget.username}/'
        : (media.first.relativePath ?? 'Pictures/Storize/${widget.username}/');

    final rows = <(String, String)>[
      (l10n.storyInfoPosted, _when(context, content.postedAt)),
      (l10n.storyInfoType, postTypeLabel(l10n, content, media)),
      (l10n.postInfoSlides, l10n.postInfoSlideCount(media.length)),
      if (sizes.isNotEmpty)
        (
          l10n.storyInfoSize,
          totalBytes < 1024 * 1024
              ? l10n.storySizeKb((totalBytes / 1024).round().toString())
              : l10n.storySizeMb(
                  (totalBytes / (1024 * 1024)).toStringAsFixed(1),
                ),
        ),
      (l10n.storyInfoItemId, content.remoteId),
      (l10n.storyInfoFolder, folder),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          StorizeSpacing.s24,
          StorizeSpacing.s8,
          StorizeSpacing.s24,
          StorizeSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.storyInfoTitle, style: text.titleLarge),
            const SizedBox(height: StorizeSpacing.s12),
            if (link != null) ...[
              Text(
                l10n.postLinkTitle,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: StorizeSpacing.minTouchTarget,
                      minHeight: StorizeSpacing.minTouchTarget,
                    ),
                    tooltip: l10n.postCopyLink,
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copy(link),
                  ),
                ],
              ),
              if (_copied)
                Text(
                  l10n.postLinkCopied,
                  style: text.bodySmall?.copyWith(color: scheme.primary),
                ),
              const SizedBox(height: StorizeSpacing.s12),
            ],
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: StorizeSpacing.s12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(
                        label,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text(value, style: text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The type label: Photo, Video, Carousel or Reel. Falls back to the slide
/// shape when the post type is not known.
String postTypeLabel(
  AppLocalizations l10n,
  Content content,
  List<MediaFile> media,
) {
  final type =
      content.postType ??
      (media.length > 1
          ? PostType.carousel
          : media.isNotEmpty && media.first.mediaType == MediaType.video
          ? PostType.video
          : PostType.photo);
  return switch (type) {
    PostType.photo => l10n.postTypePhoto,
    PostType.video => l10n.postTypeVideo,
    PostType.carousel => l10n.postTypeCarousel,
    PostType.reel => l10n.postTypeReel,
  };
}
