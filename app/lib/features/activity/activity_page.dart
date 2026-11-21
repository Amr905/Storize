import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/ui_state.dart';
import 'package:storize_app/core/ui_state_view.dart';
import 'package:storize_app/features/activity/activity_entry.dart';
import 'package:storize_app/features/activity/activity_model.dart';
import 'package:storize_app/features/activity/activity_providers.dart';
import 'package:storize_app/features/shared/session_banner_slot.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// S-11: the last 7 days of checks, downloads and problems, with filter chips.
/// Read-only apart from the links on gap, session and download entries.
class ActivityPage extends ConsumerWidget {
  /// Creates the page.
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(activityViewProvider);
    final filter = ref.watch(activityFilterProvider);
    final view = async.value;
    final ui = async.toUiState(
      isEmpty: (v) => v.itemCount == 0,
      emptyReason: view != null && view.inWindow > 0
          ? EmptyReason.filteredOut
          : EmptyReason.noData,
      retry: () {
        ref
          ..invalidate(activityEventsProvider)
          ..invalidate(activityTargetsProvider);
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.screenActivity)),
      body: Column(
        children: [
          const SessionBannerSlot(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              StorizeSpacing.s16,
              0,
              StorizeSpacing.s16,
              StorizeSpacing.s8,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.actSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StorizeSpacing.s16,
            ),
            child: Wrap(
              spacing: StorizeSpacing.s8,
              children: [
                for (final f in ActivityFilter.values)
                  FilterChip(
                    label: Text(_filterLabel(l10n, f)),
                    selected: filter == f,
                    onSelected: (_) =>
                        ref.read(activityFilterProvider.notifier).select(f),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ui is UiContent<ActivityView>
                ? _ActivityList(view: ui.value)
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: UiStateView<ActivityView>(
                          state: ui,
                          emptyBuilder: (context, reason) =>
                              _empty(context, l10n, reason),
                          builder: (context, v) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _filterLabel(AppLocalizations l10n, ActivityFilter f) =>
      switch (f) {
        ActivityFilter.all => l10n.actFilterAll,
        ActivityFilter.downloads => l10n.actFilterDownloads,
        ActivityFilter.errors => l10n.actFilterErrors,
        ActivityFilter.gaps => l10n.actFilterGaps,
      };

  static Widget _empty(
    BuildContext context,
    AppLocalizations l10n,
    EmptyReason reason,
  ) => switch (reason) {
    EmptyReason.noData => EmptyState(
      icon: Icons.history_rounded,
      title: l10n.actEmptyTitle,
      body: l10n.emptyNoDataBody,
    ),
    EmptyReason.filteredOut => EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: l10n.emptyFilteredTitle,
      body: l10n.emptyFilteredBody,
    ),
  };
}

/// One row of the flattened list: a day header or an entry.
class _Row {
  const _Row.header(this.day) : event = null;
  const _Row.entry(this.event) : day = null;

  final DateTime? day;
  final ActivityEvent? event;
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.view});

  final ActivityView view;

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[
      for (final g in view.groups) ...[
        _Row.header(g.day),
        for (final e in g.events) _Row.entry(e),
      ],
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final day = row.day;
        if (day != null) {
          return DateHeader(label: _dayLabel(context, day, view.now));
        }
        final event = row.event!;
        final entry = describeActivity(context, event, view.targetsById);
        return _EntryTile(
          entry: entry,
          time: MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(event.at.toLocal())),
        );
      },
    );
  }

  static String _dayLabel(BuildContext context, DateTime day, DateTime at) {
    final l10n = AppLocalizations.of(context);
    final now = at.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return l10n.actToday;
    if (day == yesterday) return l10n.actYesterday;
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.time});

  final ActivityEntry entry;
  final String time;

  @override
  Widget build(BuildContext context) {
    final location = entry.location;
    final item = ActivityItem(
      icon: entry.icon,
      tone: entry.tone,
      time: time,
      text: entry.text,
      actionLabel: entry.actionLabel,
      onAction: location == null
          ? null
          : () => unawaited(context.push(location)),
    );
    if (location == null) return item;
    return InkWell(
      onTap: () => unawaited(context.push(location)),
      child: item,
    );
  }
}
