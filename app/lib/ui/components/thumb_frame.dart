import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Shared chrome for `StoryThumb` and `PostThumb`: media area, optional "new"
/// ring, selection overlay/check, broken placeholder and corner badges.
/// Internal to the design system.
class ThumbFrame extends StatelessWidget {
  const ThumbFrame({
    required this.aspectRatio,
    required this.semanticLabel,
    this.content,
    this.isNew = false,
    this.selected = false,
    this.selectionMode = false,
    this.broken = false,
    this.onTap,
    this.onLongPress,
    this.topEnd,
    this.bottomStart,
    super.key,
  });

  final double aspectRatio;
  final String semanticLabel;
  final Widget? content;
  final bool isNew;
  final bool selected;
  final bool selectionMode;
  final bool broken;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Badge placed at the top end corner (e.g. carousel count).
  final Widget? topEnd;

  /// Badge placed at the bottom start corner (e.g. duration).
  final Widget? bottomStart;

  static const double _ring = 3;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = StorizeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final media = ClipRRect(
      borderRadius: StorizeRadii.thumbRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (broken)
            ColoredBox(
              color: scheme.surfaceContainerHigh,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: StorizeSpacing.s4),
                  Text(
                    AppLocalizations.of(context).thumbBroken,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            content ?? ColoredBox(color: scheme.surfaceContainerHigh),
          if (selected)
            ColoredBox(color: scheme.primary.withValues(alpha: 0.3)),
          if (bottomStart != null && !broken)
            PositionedDirectional(
              start: StorizeSpacing.s8,
              bottom: StorizeSpacing.s8,
              child: bottomStart!,
            ),
          if (topEnd != null && !broken)
            PositionedDirectional(
              end: StorizeSpacing.s8,
              top: StorizeSpacing.s8,
              child: topEnd!,
            ),
          if (selectionMode)
            PositionedDirectional(
              start: StorizeSpacing.s8,
              top: StorizeSpacing.s8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : colors.mediaScrim,
                  border: Border.all(
                    color: selected ? scheme.primary : colors.onMediaScrim,
                    width: 2,
                  ),
                ),
                child: SizedBox.square(
                  dimension: 22,
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: scheme.onPrimary,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(StorizeRadii.thumb + _gap),
                ),
                border: Border.all(
                  color: isNew && !broken ? scheme.primary : Colors.transparent,
                  width: _ring,
                ),
              ),
              child: Padding(padding: const EdgeInsets.all(_gap), child: media),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark pill with an icon and/or text that sits on top of media.
class MediaBadge extends StatelessWidget {
  const MediaBadge({this.icon, this.text, super.key});

  final IconData? icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final colors = StorizeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.mediaScrim,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s8,
          vertical: StorizeSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 14, color: colors.onMediaScrim),
            if (icon != null && text != null) const SizedBox(width: 4),
            if (text != null)
              Text(
                text!,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.onMediaScrim),
              ),
          ],
        ),
      ),
    );
  }
}
