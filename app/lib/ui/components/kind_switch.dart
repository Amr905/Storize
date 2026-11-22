import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// The two library kinds.
enum LibraryKind { stories, posts }

/// Stories / Posts segmented control with counts (S-04).
class KindSwitch extends StatelessWidget {
  /// Creates the switch.
  const KindSwitch({
    required this.selected,
    required this.onChanged,
    required this.storiesLabel,
    required this.postsLabel,
    this.storiesCount,
    this.postsCount,
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
                selected: selected == LibraryKind.stories,
                onTap: () => onChanged(LibraryKind.stories),
              ),
            ),
            Expanded(
              child: _Segment(
                label: postsLabel,
                count: postsCount,
                selected: selected == LibraryKind.posts,
                onTap: () => onChanged(LibraryKind.posts),
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
          child: DecoratedBox(
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
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: StorizeSpacing.s8,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (count != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        borderRadius: StorizeRadii.fullRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: StorizeSpacing.s8,
                          vertical: 2,
                        ),
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected ? scheme.onPrimary : scheme.surface,
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
