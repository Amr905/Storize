import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// The two library kinds.
enum LibraryKind { stories, posts }

/// Stories / Posts (/ Highlights) segmented control with saffron "N new"
/// badges (S-04). The Highlights segment shows only when [highlightsLabel] is
/// set.
class KindSwitch extends StatelessWidget {
  /// Creates the switch.
  const KindSwitch({
    required this.selected,
    required this.onChanged,
    required this.storiesLabel,
    required this.postsLabel,
    this.storiesCount,
    this.postsCount,
    this.highlightsLabel,
    this.highlightsSelected = false,
    this.onHighlights,
    super.key,
  });

  /// Current kind.
  final LibraryKind selected;

  /// Called with the tapped kind.
  final ValueChanged<LibraryKind> onChanged;

  /// "Stories" text.
  final String storiesLabel;

  /// "Posts" text.
  final String postsLabel;

  /// Count badge for stories (hidden when null).
  final int? storiesCount;

  /// Count badge for posts (hidden when null).
  final int? postsCount;

  /// "Highlights" text; the segment is hidden when null.
  final String? highlightsLabel;

  /// Whether the Highlights segment is the selected one (then neither
  /// [selected] segment is drawn selected).
  final bool highlightsSelected;

  /// Called when the Highlights segment is tapped.
  final VoidCallback? onHighlights;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: StorizeRadii.fullRadius,
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                label: storiesLabel,
                count: storiesCount,
                selected:
                    !highlightsSelected && selected == LibraryKind.stories,
                onTap: () => onChanged(LibraryKind.stories),
              ),
            ),
            Expanded(
              child: _Segment(
                label: postsLabel,
                count: postsCount,
                selected: !highlightsSelected && selected == LibraryKind.posts,
                onTap: () => onChanged(LibraryKind.posts),
              ),
            ),
            if (highlightsLabel != null)
              Expanded(
                child: _Segment(
                  label: highlightsLabel!,
                  count: null,
                  selected: highlightsSelected,
                  onTap: () => onHighlights?.call(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = StorizeColors.of(context).accent;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: count == null
          ? label
          : AppLocalizations.of(context).kindSwitchSemantics(label, count!),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: StorizeMotion.standard,
          curve: StorizeMotion.curve,
          constraints: const BoxConstraints(
            minHeight: StorizeSpacing.minTouchTarget,
          ),
          alignment: AlignmentDirectional.center,
          padding: const EdgeInsets.all(StorizeSpacing.s4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? scheme.surface : Colors.transparent,
              borderRadius: StorizeRadii.fullRadius,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: StorizeSpacing.s4,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (count != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.container,
                        borderRadius: StorizeRadii.fullRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        child: Text(
                          AppLocalizations.of(context)
                              .kindSwitchNewBadge(count!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
