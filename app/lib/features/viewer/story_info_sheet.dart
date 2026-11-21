import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Shows the S-06 Info sheet for [item]: times, type, duration, size, item ID
/// and the gallery folder.
Future<void> showStoryInfoSheet(
  BuildContext context, {
  required ContentWithMedia item,
  required String username,
}) => showModalBottomSheet<void>(
  context: context,
  shape: const RoundedRectangleBorder(
    borderRadius: StorizeRadii.sheetRadius,
  ),
  builder: (_) => StoryInfoSheet(item: item, username: username),
);

/// The Info sheet body. Rows without a value are left out.
class StoryInfoSheet extends StatelessWidget {
  /// Creates the sheet.
  const StoryInfoSheet({
    required this.item,
    required this.username,
    super.key,
  });

  /// The story.
  final ContentWithMedia item;

  /// The account handle without "@", for the default folder.
  final String username;

  static String _when(BuildContext context, DateTime utc) {
    final loc = MaterialLocalizations.of(context);
    final local = utc.toLocal();
    return '${loc.formatMediumDate(local)} · '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  static String _clock(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = item.media.isEmpty ? null : item.media.first;
    final isVideo = media?.mediaType == MediaType.video;
    final size = media?.sizeBytes;
    final folder = media?.relativePath ?? 'Pictures/Storize/$username/';

    final rows = <(String, String)>[
      (l10n.storyInfoPosted, _when(context, item.content.postedAt)),
      if (media?.downloadedAt != null)
        (l10n.storyInfoDownloaded, _when(context, media!.downloadedAt!)),
      (
        l10n.storyInfoType,
        isVideo ? l10n.storyTypeVideo : l10n.storyTypePhoto,
      ),
      if (isVideo && media?.durationMs != null)
        (
          l10n.storyInfoDuration,
          _clock(Duration(milliseconds: media!.durationMs!)),
        ),
      if (size != null)
        (
          l10n.storyInfoSize,
          size < 1024 * 1024
              ? l10n.storySizeKb((size / 1024).round().toString())
              : l10n.storySizeMb(
                  (size / (1024 * 1024)).toStringAsFixed(1),
                ),
        ),
      (l10n.storyInfoItemId, item.content.remoteId),
      (l10n.storyInfoFolder, folder),
    ];

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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
                    Expanded(
                      child: Text(value, style: text.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
