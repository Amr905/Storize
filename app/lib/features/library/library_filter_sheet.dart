import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// What S-05 returns when Apply is tapped.
typedef LibraryFilterResult = ({LibraryKind kind, LibraryFilters filters});

/// S-05: the filter bottom sheet. Pops a [LibraryFilterResult] on Apply, and
/// null when dismissed.
class LibraryFilterSheet extends StatefulWidget {
  /// Creates the sheet.
  const LibraryFilterSheet({
    required this.targets,
    required this.kind,
    required this.filters,
    required this.today,
    super.key,
  });

  /// Accounts to choose from.
  final List<Target> targets;

  /// The current kind.
  final LibraryKind kind;

  /// The current filters.
  final LibraryFilters filters;

  /// The current local day: the last day a custom range may end on.
  final DateTime today;

  /// Shows the sheet.
  static Future<LibraryFilterResult?> show(
    BuildContext context, {
    required List<Target> targets,
    required LibraryKind kind,
    required LibraryFilters filters,
    required DateTime today,
  }) => showModalBottomSheet<LibraryFilterResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => LibraryFilterSheet(
      targets: targets,
      kind: kind,
      filters: filters,
      today: today,
    ),
  );

  @override
  State<LibraryFilterSheet> createState() => _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends State<LibraryFilterSheet> {
  late LibraryKind _kind = widget.kind;
  late LibraryFilters _filters = widget.filters;

  Future<void> _pickRange() async {
    final today = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      // The app clock, not the system one, so "today" is consistent.
      currentDate: today,
      initialDateRange: _filters.customFrom != null && _filters.customTo != null
          ? DateTimeRange(start: _filters.customFrom!, end: _filters.customTo!)
          : null,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filters = _filters.copyWith(
        date: DatePreset.custom,
        customFrom: picked.start,
        customTo: picked.end,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    final types = [
      (TypeFilter.all, l10n.libTypeAll),
      (TypeFilter.photos, l10n.libTypePhotos),
      (TypeFilter.videos, l10n.libTypeVideos),
      if (_kind == LibraryKind.posts) ...[
        (TypeFilter.carousels, l10n.libTypeCarousels),
        (TypeFilter.reels, l10n.libTypeReels),
      ],
    ];
    final customLabel =
        _filters.date == DatePreset.custom &&
            _filters.customFrom != null &&
            _filters.customTo != null
        ? l10n.libDateRange(
            loc.formatMediumDate(_filters.customFrom!),
            loc.formatMediumDate(_filters.customTo!),
          )
        : l10n.libDateCustom;
    final type = _filters.effectiveType(_kind);

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsetsDirectional.only(top: StorizeSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: StorizeSpacing.s8),
          child,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        StorizeSpacing.s24,
        0,
        StorizeSpacing.s24,
        StorizeSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.libFiltersTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (widget.targets.isNotEmpty)
            section(
              l10n.libFilterAccounts,
              Wrap(
                spacing: StorizeSpacing.s8,
                children: [
                  for (final t in widget.targets)
                    FilterChip(
                      key: ValueKey('filter-account-${t.id}'),
                      label: Text(isolateLtr('@${t.username}')),
                      selected: _filters.targetIds.contains(t.id),
                      onSelected: (on) => setState(() {
                        final ids = {..._filters.targetIds};
                        on ? ids.add(t.id) : ids.remove(t.id);
                        _filters = _filters.copyWith(targetIds: ids);
                      }),
                    ),
                ],
              ),
            ),
          section(
            l10n.libFilterKind,
            Wrap(
              spacing: StorizeSpacing.s8,
              children: [
                for (final (k, label) in [
                  (LibraryKind.stories, l10n.libStoriesTab),
                  (LibraryKind.posts, l10n.libPostsTab),
                ])
                  ChoiceChip(
                    key: ValueKey('filter-kind-${k.name}'),
                    label: Text(label),
                    selected: _kind == k && !_filters.highlightsOnly,
                    showCheckmark: true,
                    onSelected: (_) => setState(() {
                      _kind = k;
                      _filters = _filters.copyWith(highlightsOnly: false);
                    }),
                  ),
                ChoiceChip(
                  key: const ValueKey('filter-kind-highlights'),
                  label: Text(l10n.libHighlightsFilter),
                  selected: _filters.highlightsOnly,
                  showCheckmark: true,
                  onSelected: (on) => setState(() {
                    _filters = _filters.copyWith(highlightsOnly: on);
                    if (on) _kind = LibraryKind.stories;
                  }),
                ),
              ],
            ),
          ),
          section(
            l10n.libFilterDate,
            Wrap(
              spacing: StorizeSpacing.s8,
              children: [
                for (final (p, label) in [
                  (DatePreset.today, l10n.libDateToday),
                  (DatePreset.days7, l10n.libDate7),
                  (DatePreset.days30, l10n.libDate30),
                ])
                  ChoiceChip(
                    key: ValueKey('filter-date-${p.name}'),
                    label: Text(label),
                    selected: _filters.date == p,
                    onSelected: (on) => setState(
                      () => _filters = _filters.copyWith(
                        date: on ? p : DatePreset.any,
                      ),
                    ),
                  ),
                ChoiceChip(
                  key: const ValueKey('filter-date-custom'),
                  label: Text(customLabel),
                  selected: _filters.date == DatePreset.custom,
                  onSelected: (_) => _pickRange(),
                ),
              ],
            ),
          ),
          section(
            l10n.libFilterType,
            Wrap(
              spacing: StorizeSpacing.s8,
              children: [
                for (final (t, label) in types)
                  ChoiceChip(
                    key: ValueKey('filter-type-${t.name}'),
                    label: Text(label),
                    selected: type == t,
                    onSelected: (_) =>
                        setState(() => _filters = _filters.copyWith(type: t)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: StorizeSpacing.s24),
          Row(
            children: [
              Expanded(
                child: TonalButton(
                  label: l10n.libClear,
                  expand: true,
                  onPressed: () => setState(() {
                    _filters = LibraryFilters.none;
                  }),
                ),
              ),
              const SizedBox(width: StorizeSpacing.s16),
              Expanded(
                child: PrimaryButton(
                  label: l10n.libApply,
                  expand: true,
                  onPressed: () =>
                      Navigator.of(context)
                          .pop((kind: _kind, filters: _filters)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
