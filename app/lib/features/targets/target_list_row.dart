import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

/// One tracked account on S-07, laid out as in the design mockup: name and
/// status badge on the first line, category tag and a note on the second,
/// "Checked … · N saved" on the third.
class TargetListRow extends StatelessWidget {
  /// Creates a row.
  const TargetListRow({
    required this.username,
    required this.category,
    required this.status,
    this.statusLabel,
    this.note,
    this.checkedLine,
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

  /// Replaces the badge text, when set (a pending lookup, FR-73).
  final String? statusLabel;

  /// Text next to the category tag.
  final String? note;

  /// Third line.
  final String? checkedLine;

  /// Row tapped.
  final VoidCallback? onTap;

  /// Optional swipe action.
  final TargetRowSwipeAction? swipeAction;

  static String categoryLabel(AppLocalizations l10n, CategoryKind kind) =>
      switch (kind) {
        CategoryKind.ownClient => l10n.tgtCatOwn,
        CategoryKind.consented => l10n.tgtCatConsented,
        CategoryKind.publicFigure => l10n.tgtCatPublicShort,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final swipe = swipeAction;
    Widget row = Semantics(
      container: true,
      button: onTap != null,
      customSemanticsActions: swipe == null
          ? null
          : {CustomSemanticsAction(label: swipe.label): swipe.onTriggered},
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StorizeSpacing.s16,
              vertical: StorizeSpacing.s12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StorizeAvatar(
                  initial: username.isEmpty ? '' : username[0],
                  size: 44,
                ),
                const SizedBox(width: StorizeSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isolateLtr('@$username'),
                              semanticsLabel: username,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: StorizeSpacing.s8),
                          DotStatusBadge(status: status, label: statusLabel),
                        ],
                      ),
                      const SizedBox(height: StorizeSpacing.s4),
                      Wrap(
                        spacing: StorizeSpacing.s12,
                        runSpacing: StorizeSpacing.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          CategoryTag(
                            kind: category,
                            label: categoryLabel(l10n, category),
                          ),
                          if (note != null) Text(note!, style: muted),
                        ],
                      ),
                      if (checkedLine != null) ...[
                        const SizedBox(height: StorizeSpacing.s4),
                        Text(checkedLine!, style: muted),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (swipe != null) {
      final colors = StorizeColors.of(context);
      final tone = swipe.destructive ? colors.error : colors.warning;
      row = Dismissible(
        key: ValueKey('target-row-$username'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          swipe.onTriggered();
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
                  Icon(swipe.icon, color: tone.onContainer),
                  const SizedBox(width: StorizeSpacing.s8),
                  Text(
                    swipe.label,
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
