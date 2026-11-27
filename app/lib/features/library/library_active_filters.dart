import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// The applied search and filters of S-04 as removable chips, with the result
/// count and "Clear all". Renders nothing when nothing is applied.
class ActiveFilterChips extends StatelessWidget {
  /// Creates the chips.
  const ActiveFilterChips({
    required this.filters,
    required this.kind,
    required this.query,
    required this.targets,
    required this.count,
    required this.onFiltersChanged,
    required this.onClearQuery,
    required this.onClearAll,
    super.key,
  });

  /// The applied filters (the kind switch is not a chip).
  final LibraryFilters filters;

  /// The current kind (decides whether the type filter applies).
  final LibraryKind kind;

  /// The committed search text, or '' when no search is active.
  final String query;

  /// All accounts, to name the account chips.
  final List<Target> targets;

  /// Items that pass the search and filters.
  final int count;

  /// Called with the filters after one chip is removed.
  final ValueChanged<LibraryFilters> onFiltersChanged;

  /// Ends the search.
  final VoidCallback onClearQuery;

  /// Removes every chip and ends the search.
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final active = query.isNotEmpty || filters.isActive;
    if (!active) return const SizedBox.shrink();

    final dateLabel = switch (filters.date) {
      DatePreset.any => null,
      DatePreset.today => l10n.libDateToday,
      DatePreset.days7 => l10n.libDate7,
      DatePreset.days30 => l10n.libDate30,
      DatePreset.custom =>
        filters.customFrom == null || filters.customTo == null
            ? l10n.libDateCustom
            : l10n.libDateRange(
                loc.formatMediumDate(filters.customFrom!),
                loc.formatMediumDate(filters.customTo!),
              ),
    };
    final typeLabel = switch (filters.effectiveType(kind)) {
      TypeFilter.all => null,
      TypeFilter.photos => l10n.libTypePhotos,
      TypeFilter.videos => l10n.libTypeVideos,
      TypeFilter.carousels => l10n.libTypeCarousels,
    };
    final accounts = [
      for (final t in targets)
        if (filters.targetIds.contains(t.id)) t,
    ];

    final chips = <Widget>[
      if (query.isNotEmpty)
        InputChip(
          key: const ValueKey('active-filter-search'),
          label: Text(l10n.libSearchChip(query)),
          deleteButtonTooltipMessage: l10n.libRemoveFilter,
          onDeleted: onClearQuery,
        ),
      for (final t in accounts)
        InputChip(
          key: ValueKey('active-filter-account-${t.id}'),
          label: Text(isolateLtr('@${t.username}')),
          deleteButtonTooltipMessage: l10n.libRemoveFilter,
          onDeleted: () => onFiltersChanged(
            filters.copyWith(
              targetIds: {...filters.targetIds}..remove(t.id),
            ),
          ),
        ),
      if (dateLabel != null)
        InputChip(
          key: const ValueKey('active-filter-date'),
          label: Text(dateLabel),
          deleteButtonTooltipMessage: l10n.libRemoveFilter,
          onDeleted: () => onFiltersChanged(
            filters.copyWith(date: DatePreset.any),
          ),
        ),
      if (filters.reelsOnly)
        InputChip(
          key: const ValueKey('active-filter-reels'),
          label: Text(l10n.libKindReels),
          deleteButtonTooltipMessage: l10n.libRemoveFilter,
          onDeleted: () => onFiltersChanged(filters.copyWith(reelsOnly: false)),
        ),
      if (filters.highlightsOnly)
        InputChip(
          key: const ValueKey('active-filter-highlights'),
          label: Text(l10n.libHighlightsFilter),
          deleteButtonTooltipMessage: l10n.libRemoveFilter,
          onDeleted: () =>
              onFiltersChanged(filters.copyWith(highlightsOnly: false)),
        ),
      if (typeLabel != null)
        InputChip(
          key: const ValueKey('active-filter-type'),
          label: Text(typeLabel),
          deleteButtonTooltipMessage: l10n.libRemoveFilter,
          onDeleted: () =>
              onFiltersChanged(filters.copyWith(type: TypeFilter.all)),
        ),
    ];

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        StorizeSpacing.s16,
        0,
        StorizeSpacing.s16,
        StorizeSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: StorizeSpacing.s8,
            runSpacing: StorizeSpacing.s8,
            children: chips,
          ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    key: const ValueKey('library-result-count'),
                    l10n.libResultCount(count),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('active-filter-clear-all'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    StorizeSpacing.minTouchTarget,
                    StorizeSpacing.minTouchTarget,
                  ),
                ),
                onPressed: onClearAll,
                child: Text(l10n.libClearAll),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
