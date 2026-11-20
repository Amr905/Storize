import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/core/ui_state.dart';
import 'package:storize_app/core/ui_state_view.dart';
import 'package:storize_app/features/library/library_filter_sheet.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/library/library_tile.dart';
import 'package:storize_app/features/library/library_view.dart';
import 'package:storize_app/features/shared/session_banner_slot.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// S-04: the library of downloaded stories and posts, with the S-05 filters,
/// selection mode, delete and share, and pull-to-refresh.
class LibraryPage extends ConsumerStatefulWidget {
  /// Creates the page with the filters from the route's query parameters.
  const LibraryPage({this.kind, this.targetId, super.key});

  /// Kind filter from `?kind=`.
  final ContentKind? kind;

  /// Target filter from `?target=`.
  final int? targetId;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  @override
  void initState() {
    super.initState();
    _applyRoute();
  }

  @override
  void didUpdateWidget(LibraryPage old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind || old.targetId != widget.targetId) {
      _applyRoute();
    }
  }

  // Providers cannot change during build, so apply after the first frame.
  void _applyRoute() {
    final kind = widget.kind;
    final target = widget.targetId;
    if (kind == null && target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (kind != null) {
        ref
            .read(libraryKindProvider.notifier)
            .select(
              kind == ContentKind.story
                  ? LibraryKind.stories
                  : LibraryKind.posts,
            );
      }
      if (target != null) {
        final f = ref.read(libraryFiltersProvider);
        ref
            .read(libraryFiltersProvider.notifier)
            .replace(f.copyWith(targetIds: {target}));
      }
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openFilters(LibraryView view) async {
    final result = await LibraryFilterSheet.show(
      context,
      targets: view.targets,
      kind: ref.read(libraryKindProvider),
      filters: ref.read(libraryFiltersProvider),
      today: view.now.toLocal(),
    );
    if (result == null || !mounted) return;
    ref.read(libraryKindProvider.notifier).select(result.kind);
    ref.read(libraryFiltersProvider.notifier).replace(result.filters);
  }

  Future<void> _delete(Set<int> ids) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.libDeleteTitle(ids.length),
      body: l10n.libDeleteBody,
      confirmLabel: l10n.libDelete,
      cancelLabel: l10n.libCancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    String message;
    try {
      final result = await ref.read(deleteContentProvider)(ids);
      message = result.failures.isEmpty
          ? l10n.libDeleted(result.deletedContentIds.length)
          : l10n.libDeleteFailed(result.failures.length);
    } on Object {
      message = l10n.libDeleteFailed(ids.length);
    }
    if (!mounted) return;
    ref.read(librarySelectionProvider.notifier).clear();
    _snack(message);
  }

  Future<void> _share(LibraryView view, Set<int> ids) async {
    final l10n = AppLocalizations.of(context);
    final files = [
      for (final item in view.items)
        if (ids.contains(item.content.id))
          for (final m in item.media)
            if (m.status == MediaFileStatus.done && m.contentUri != null)
              ShareFile(contentUri: m.contentUri!, mediaType: m.mediaType),
    ];
    if (files.isEmpty) {
      _snack(l10n.libShareNothing);
      return;
    }
    try {
      await ref.read(shareServiceProvider).share(files);
      if (mounted) ref.read(librarySelectionProvider.notifier).clear();
    } on Object {
      if (mounted) _snack(l10n.libShareFailed);
    }
  }

  Future<void> _offerRemove(int contentId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.libMissingTitle,
      body: l10n.libMissingBody,
      confirmLabel: l10n.libRemoveFromLibrary,
      cancelLabel: l10n.libCancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(deleteContentProvider)([contentId]);
    } on Object {
      if (mounted) _snack(l10n.libDeleteFailed(1));
    }
  }

  void _open(ContentWithMedia item) {
    final id = item.content.id;
    unawaited(
      context.push(
        item.content.kind == ContentKind.story
            ? Routes.storyLocation(id)
            : Routes.postLocation(id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(libraryViewProvider);
    final selection = ref.watch(librarySelectionProvider);
    final kind = ref.watch(libraryKindProvider);
    final filters = ref.watch(libraryFiltersProvider);
    final checkNow = ref.watch(checkNowControllerProvider);

    ref.listen(checkNowControllerProvider, (_, next) {
      final result = next.result;
      if (result == null) return;
      _snack(
        result.failed
            ? l10n.libCheckFailed
            : l10n.libCheckDone(result.newItems),
      );
      ref.read(checkNowControllerProvider.notifier).consume();
    });

    final view = async.value;
    final selecting = selection.isNotEmpty;
    final ui = async.toUiState(
      isEmpty: (v) => v.itemCount == 0 || v.targets.isEmpty,
      emptyReason: view != null && view.totalOfKind > 0 && view.filtersActive
          ? EmptyReason.filteredOut
          : EmptyReason.noData,
      retry: () {
        ref
          ..invalidate(allContentProvider)
          ..invalidate(libraryTargetsProvider);
      },
    );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(librarySelectionProvider.notifier).clear();
      },
      child: Scaffold(
        appBar: selecting
            ? AppBar(
                leading: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: StorizeSpacing.minTouchTarget,
                    minHeight: StorizeSpacing.minTouchTarget,
                  ),
                  tooltip: l10n.libCancelSelection,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: ref.read(librarySelectionProvider.notifier).clear,
                ),
                title: Text(l10n.libSelectedCount(selection.length)),
                actions: [
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: StorizeSpacing.minTouchTarget,
                      minHeight: StorizeSpacing.minTouchTarget,
                    ),
                    tooltip: l10n.libShare,
                    icon: const Icon(Icons.share_outlined),
                    onPressed: view == null
                        ? null
                        : () => _share(view, selection),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: StorizeSpacing.minTouchTarget,
                      minHeight: StorizeSpacing.minTouchTarget,
                    ),
                    tooltip: l10n.libDeleteTooltip,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(selection),
                  ),
                ],
              )
            : AppBar(
                title: Text(l10n.screenLibrary),
                actions: [
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: StorizeSpacing.minTouchTarget,
                      minHeight: StorizeSpacing.minTouchTarget,
                    ),
                    tooltip: l10n.libFilterTooltip,
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: view == null ? null : () => _openFilters(view),
                  ),
                ],
              ),
        body: RefreshIndicator(
          semanticsLabel: l10n.libCheckRunning,
          onRefresh: ref.read(checkNowControllerProvider.notifier).run,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Everything scrolls together, so the page survives large text
              // and short screens (the empty and error states fill the rest).
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: StorizeSpacing.s16,
                  ),
                  child: SessionBannerSlot(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: StorizeSpacing.s16,
                    vertical: StorizeSpacing.s8,
                  ),
                  child: KindSwitch(
                    selected: kind,
                    onChanged: ref.read(libraryKindProvider.notifier).select,
                    storiesLabel: l10n.libStoriesTab,
                    postsLabel: l10n.libPostsTab,
                    storiesCount: _countOrNull(view?.unviewedStories),
                    postsCount: _countOrNull(view?.unviewedPosts),
                  ),
                ),
              ),
              if (view != null && view.targets.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: AccountChipRow(
                    items: [
                      for (final t in view.targets)
                        AccountChipItem(
                          id: '${t.id}',
                          label: '@${t.username}',
                        ),
                    ],
                    selectedIds: {for (final id in filters.targetIds) '$id'},
                    maxVisible: 4,
                    onOverflowTap: () => unawaited(_openFilters(view)),
                    onChanged: (ids) => ref
                        .read(libraryFiltersProvider.notifier)
                        .replace(
                          filters.copyWith(
                            targetIds: {for (final id in ids) int.parse(id)},
                          ),
                        ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ActiveFilterChips(
                    filters: filters,
                    kind: kind,
                    onChanged: ref
                        .read(libraryFiltersProvider.notifier)
                        .replace,
                  ),
                ),
              ],
              if (ui is UiContent<LibraryView>)
                ..._gridSlivers(context, ui.value, kind, selection)
              else if (ui is UiLoading<LibraryView>)
                // The skeleton shrink-wraps its grid, which a fill-remaining
                // sliver cannot measure.
                SliverToBoxAdapter(
                  child: UiStateView<LibraryView>(
                    state: ui,
                    loadingStyle: UiLoadingStyle.grid,
                    builder: (context, v) => const SizedBox.shrink(),
                  ),
                )
              else
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: UiStateView<LibraryView>(
                    state: ui,
                    emptyBuilder: (context, reason) => _empty(
                      context,
                      view,
                      kind,
                      reason,
                      checking: checkNow.running,
                    ),
                    builder: (context, v) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _gridSlivers(
    BuildContext context,
    LibraryView view,
    LibraryKind kind,
    Set<int> selection,
  ) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final thumbBuilder = ref.watch(libraryThumbBuilderProvider);
    final media = MediaQuery.of(context);
    // Decode at tile size, not at full size (NFR-12).
    final tileWidth =
        (media.size.width - 2 * StorizeSpacing.s16) / libraryColumns;
    final cacheWidth = (tileWidth * media.devicePixelRatio).round();
    final today = view.now.toLocal();

    String dayLabel(DateTime day) {
      final d = DateTime(today.year, today.month, today.day);
      if (day == d) return l10n.libDateToday;
      if (day == DateTime(d.year, d.month, d.day - 1)) {
        return l10n.libDateYesterday;
      }
      return loc.formatMediumDate(day);
    }

    final selecting = selection.isNotEmpty;
    return [
      for (final group in view.groups)
        SliverMainAxisGroup(
          slivers: [
            SliverDateHeader(label: dayLabel(group.day)),
            SliverList.builder(
              itemCount: group.rows.length,
              itemBuilder: (context, i) {
                final row = group.rows[i];
                return switch (row) {
                  AccountHeaderRow() => _AccountHeader(row: row),
                  TilesRow(:final items) => Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: StorizeSpacing.s16,
                      end: StorizeSpacing.s16,
                      bottom: StorizeSpacing.s8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var c = 0; c < libraryColumns; c++) ...[
                          if (c > 0) const SizedBox(width: StorizeSpacing.s8),
                          Expanded(
                            child: c < items.length
                                ? LibraryTile(
                                    key: ValueKey(items[c].content.id),
                                    item: items[c],
                                    account:
                                        view
                                            .targetsById[items[c]
                                                .content
                                                .targetId]
                                            ?.username ??
                                        '',
                                    now: view.now,
                                    kind: kind,
                                    selected: selection.contains(
                                      items[c].content.id,
                                    ),
                                    selectionMode: selecting,
                                    cacheWidth: cacheWidth,
                                    thumbBuilder: thumbBuilder,
                                    onTap: _onTileTap,
                                    onLongPress: _onTileLongPress,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                };
              },
            ),
          ],
        ),
      const SliverPadding(
        padding: EdgeInsetsDirectional.only(bottom: StorizeSpacing.s24),
      ),
    ];
  }

  void _onTileTap(ContentWithMedia item, bool broken) {
    if (ref.read(librarySelectionProvider).isNotEmpty) {
      ref.read(librarySelectionProvider.notifier).toggle(item.content.id);
    } else if (broken) {
      unawaited(_offerRemove(item.content.id));
    } else {
      _open(item);
    }
  }

  void _onTileLongPress(ContentWithMedia item) {
    if (ref.read(librarySelectionProvider).isEmpty) {
      ref.read(librarySelectionProvider.notifier).toggle(item.content.id);
    }
  }

  static int? _countOrNull(int? n) => n == null || n == 0 ? null : n;

  Widget _empty(
    BuildContext context,
    LibraryView? view,
    LibraryKind kind,
    EmptyReason reason, {
    required bool checking,
  }) {
    final l10n = AppLocalizations.of(context);
    final stories = kind == LibraryKind.stories;
    if (view == null || view.targets.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: l10n.libEmptyNoTargetsTitle,
        body: l10n.libEmptyNoTargetsBody,
        actionLabel: l10n.libAddAccount,
        onAction: () => context.push(Routes.addTargetPath),
      );
    }
    if (reason == EmptyReason.filteredOut) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: l10n.emptyFilteredTitle,
        body: stories ? l10n.libFilteredStories : l10n.libFilteredPosts,
        actionLabel: l10n.libClearFilters,
        onAction: ref.read(libraryFiltersProvider.notifier).clear,
      );
    }
    final last = view.lastCheck;
    final time = last == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(last.toLocal()));
    final body = switch ((stories, time)) {
      (true, null) => l10n.libWaitingStories,
      (true, final String t) => l10n.libWaitingStoriesAt(t),
      (false, null) => l10n.libWaitingPosts,
      (false, final String t) => l10n.libWaitingPostsAt(t),
    };
    return EmptyState(
      icon: Icons.hourglass_empty_rounded,
      title: stories ? l10n.libEmptyStoriesTitle : l10n.libEmptyPostsTitle,
      body: body,
      actionLabel: l10n.libCheckNow,
      onAction: checking
          ? null
          : ref.read(checkNowControllerProvider.notifier).run,
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.filters,
    required this.kind,
    required this.onChanged,
  });

  final LibraryFilters filters;
  final LibraryKind kind;
  final ValueChanged<LibraryFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final type = filters.effectiveType(kind);
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
    final typeLabel = switch (type) {
      TypeFilter.all => null,
      TypeFilter.photos => l10n.libTypePhotos,
      TypeFilter.videos => l10n.libTypeVideos,
      TypeFilter.carousels => l10n.libTypeCarousels,
      TypeFilter.reels => l10n.libTypeReels,
    };
    if (dateLabel == null && typeLabel == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StorizeSpacing.s16,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: StorizeSpacing.s8,
          children: [
            if (dateLabel != null)
              InputChip(
                key: const ValueKey('active-filter-date'),
                label: Text(dateLabel),
                deleteButtonTooltipMessage: l10n.libRemoveFilter,
                onDeleted: () =>
                    onChanged(filters.copyWith(date: DatePreset.any)),
              ),
            if (typeLabel != null)
              InputChip(
                key: const ValueKey('active-filter-type'),
                label: Text(typeLabel),
                deleteButtonTooltipMessage: l10n.libRemoveFilter,
                onDeleted: () =>
                    onChanged(filters.copyWith(type: TypeFilter.all)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.row});

  final AccountHeaderRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = row.target?.username ?? '';
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StorizeSpacing.s16,
        vertical: StorizeSpacing.s8,
      ),
      child: Row(
        children: [
          StorizeAvatar(
            initial: name.isEmpty ? null : name.substring(0, 1),
            size: 24,
          ),
          const SizedBox(width: StorizeSpacing.s8),
          Flexible(
            child: Text(
              isolateLtr('@$name'),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: StorizeSpacing.s8),
          if (row.newCount > 0)
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: StorizeRadii.fullRadius,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: StorizeSpacing.s8,
                  vertical: 2,
                ),
                child: Text(
                  l10n.libAccountNew(row.newCount),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            )
          else
            Text(
              l10n.libAccountCount(row.count),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
