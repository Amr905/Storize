import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';
import 'package:storize_app/ui/utils/bidi.dart';

/// One selectable account.
@immutable
class AccountChipItem {
  /// Creates an item.
  const AccountChipItem({required this.id, required this.label});

  /// Stable id.
  final String id;

  /// Display text, e.g. "@nour_k".
  final String label;
}

/// Horizontal row of account filter chips (S-04, S-05).
///
/// An empty [selectedIds] means "All". In single-select mode tapping a chip
/// selects only it; in multi-select mode it toggles. With more than
/// [maxVisible] items the rest collapse into a "+N" chip ([onOverflowTap]).
class AccountChipRow extends StatelessWidget {
  /// Creates the row.
  const AccountChipRow({
    required this.items,
    required this.selectedIds,
    required this.onChanged,
    this.multiSelect = false,
    this.maxVisible,
    this.onOverflowTap,
    this.allLabel,
    super.key,
  });

  /// Accounts.
  final List<AccountChipItem> items;

  /// Selected ids; empty = All.
  final Set<String> selectedIds;

  /// Called with the new selection.
  final ValueChanged<Set<String>> onChanged;

  /// Multi-select instead of single-select.
  final bool multiSelect;

  /// Show at most this many account chips, then "+N".
  final int? maxVisible;

  /// "+N" chip tapped.
  final VoidCallback? onOverflowTap;

  /// Text of the "All" chip.
  final String? allLabel;

  void _tap(AccountChipItem item) {
    final isSelected = selectedIds.contains(item.id);
    if (multiSelect) {
      final next = {...selectedIds};
      if (isSelected) {
        next.remove(item.id);
      } else {
        next.add(item.id);
      }
      onChanged(next);
    } else {
      onChanged(isSelected ? <String>{} : {item.id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final limit = maxVisible;
    final visible = limit == null ? items : items.take(limit).toList();
    final hidden = items.length - visible.length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StorizeSpacing.s16,
      ),
      child: Row(
        children: [
          _Chip(
            label: allLabel ?? AppLocalizations.of(context).all,
            selected: selectedIds.isEmpty,
            onTap: () {
              if (!setEquals(selectedIds, <String>{})) {
                onChanged(<String>{});
              }
            },
          ),
          for (final item in visible) ...[
            const SizedBox(width: StorizeSpacing.s8),
            _Chip(
              label: isolateLtr(item.label),
              semanticLabel: item.label,
              selected: selectedIds.contains(item.id),
              onTap: () => _tap(item),
            ),
          ],
          if (hidden > 0) ...[
            const SizedBox(width: StorizeSpacing.s8),
            _Chip(
              label: '+$hidden',
              semanticLabel: AppLocalizations.of(context)
                  .a11yMoreAccounts(hidden),
              selected: false,
              onTap: onOverflowTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: StorizeSpacing.minTouchTarget,
            minWidth: StorizeSpacing.minTouchTarget,
          ),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : null,
                borderRadius: StorizeRadii.chipRadius,
                border: Border.all(
                  color: selected ? scheme.primaryContainer : scheme.outline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: StorizeSpacing.s16,
                  vertical: 7,
                ),
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
