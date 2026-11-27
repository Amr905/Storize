import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

/// Copies [caption] to the clipboard (FR-77). The caption is never logged.
Future<void> copyCaption(String caption) =>
    Clipboard.setData(ClipboardData(text: caption));

/// The FR-77 block of an Info sheet: caption (selectable, with a Copy action),
/// location with a pin, and the tagged accounts as chips. Parts without a value
/// are left out; the block is empty when there is nothing to show.
class ContentDetails extends StatelessWidget {
  /// Creates the block.
  const ContentDetails({
    required this.caption,
    required this.locationName,
    required this.taggedUsernames,
    required this.onCaptionCopied,
    super.key,
  });

  /// The caption, or null.
  final String? caption;

  /// The location name, or null.
  final String? locationName;

  /// Tagged usernames without "@".
  final List<String> taggedUsernames;

  /// Called after the caption was copied.
  final VoidCallback onCaptionCopied;

  /// Whether there is anything to show.
  static bool hasAny({
    String? caption,
    String? locationName,
    List<String> taggedUsernames = const [],
  }) =>
      (caption != null && caption.isNotEmpty) ||
      (locationName != null && locationName.isNotEmpty) ||
      taggedUsernames.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cap = caption;
    final loc = locationName;
    final label = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cap != null && cap.isNotEmpty) ...[
          Text(l10n.infoCaption, style: label),
          const SizedBox(height: StorizeSpacing.s4),
          SelectableText(cap, style: text.bodyLarge),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, StorizeSpacing.minTouchTarget),
              ),
              icon: const Icon(Icons.copy_rounded),
              label: Text(l10n.infoCopyCaption),
              onPressed: () async {
                await copyCaption(cap);
                onCaptionCopied();
              },
            ),
          ),
          const SizedBox(height: StorizeSpacing.s8),
        ],
        if (loc != null && loc.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
                semanticLabel: l10n.infoLocation,
              ),
              const SizedBox(width: StorizeSpacing.s8),
              Expanded(child: Text(loc, style: text.bodyLarge)),
            ],
          ),
          const SizedBox(height: StorizeSpacing.s12),
        ],
        if (taggedUsernames.isNotEmpty) ...[
          Text(l10n.infoTagged, style: label),
          const SizedBox(height: StorizeSpacing.s8),
          Wrap(
            spacing: StorizeSpacing.s8,
            runSpacing: StorizeSpacing.s8,
            children: [
              for (final u in taggedUsernames) Chip(label: Text('@$u')),
            ],
          ),
          const SizedBox(height: StorizeSpacing.s12),
        ],
      ],
    );
  }
}
