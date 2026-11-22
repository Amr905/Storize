import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/components/avatar.dart';
import 'package:storize_app/ui/components/category_tag.dart';
import 'package:storize_app/ui/components/status_badge.dart';
import 'package:storize_app/ui/theme/theme.dart';
import 'package:storize_app/ui/utils/bidi.dart';

/// The action revealed by swiping a [TargetRow] towards the end edge.
class TargetRowSwipeAction {
  /// Creates a swipe action.
  const TargetRowSwipeAction({
    required this.label,
    required this.icon,
    required this.onTriggered,
    this.destructive = false,
  });

  /// Text shown on the revealed background.
  final String label;

  /// Icon shown on the revealed background.
  final IconData icon;

  /// Called when the swipe completes. The row snaps back.
  final VoidCallback onTriggered;

  /// Use error colours.
  final bool destructive;
}

/// One tracked account in the Targets list (S-07).
class TargetRow extends StatelessWidget {
  /// Creates a row.
  const TargetRow({
    required this.username,
    required this.category,
    required this.status,
    this.meta,
    this.avatar,
    this.onTap,
    this.swipeAction,
    super.key,
  });

  /// Username without the "@".
  final String username;

  /// Category tag kind.
  final CategoryKind category;

  /// Health.
  final StorizeStatus status;

  /// Meta line, e.g. "Last check 10:12 - 3 new".
  final String? meta;

  /// Avatar override (default: initial of the username).
  final Widget? avatar;

  /// Row tapped.
  final VoidCallback? onTap;

  /// Optional swipe action.
  final TargetRowSwipeAction? swipeAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final swipe = swipeAction;
    Widget row = Semantics(
      container: true,
      button: onTap != null,
      customSemanticsActions: swipe == null
          ? null
          : {CustomSemanticsAction(label: swipe.label): swipe.onTriggered},
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: StorizeSpacing.minRowHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StorizeSpacing.s16,
              vertical: StorizeSpacing.s8,
            ),
            child: Row(
              children: [
                avatar ??
                    StorizeAvatar(initial: username.isEmpty ? '' : username[0]),
                const SizedBox(width: StorizeSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: StorizeSpacing.s8,
                        runSpacing: StorizeSpacing.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            isolateLtr('@$username'),
                            semanticsLabel: username,
                            style: theme.textTheme.titleMedium,
                          ),
                          CategoryTag(kind: category),
                        ],
                      ),
                      const SizedBox(height: StorizeSpacing.s4),
                      Wrap(
                        spacing: StorizeSpacing.s8,
                        runSpacing: StorizeSpacing.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(status: status),
                          if (meta != null)
                            Text(
                              meta!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final action = swipeAction;
    if (action != null) {
      final colors = StorizeColors.of(context);
      final tone = action.destructive ? colors.error : colors.warning;
      row = Dismissible(
        key: ValueKey('target-row-$username'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          action.onTriggered();
          return false;
        },
        background: ColoredBox(
          color: tone.container,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                end: StorizeSpacing.s24,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, color: tone.onContainer),
                  const SizedBox(width: StorizeSpacing.s8),
                  Text(
                    action.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tone.onContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: ColoredBox(color: scheme.surface, child: row),
      );
    }
    return row;
  }
}
