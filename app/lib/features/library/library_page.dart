import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
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
  /// A delete is running: Delete, Share and Cancel are disabled.
  bool _deleting = false;

  /// The day shown by the sticky header, or null while the first inline header
  /// is still on screen.
  final ValueNotifier<DateTime?> _stickyDay = ValueNotifier<DateTime?>(null);
  bool _stickyUpdateScheduled = false;

  _RowLayout? _layout;
  Widget? _sliver;
  Object? _sliverKey;

  @override
  void dispose() {
    _stickyDay.dispose();
    super.dispose();
  }

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

  /// The IDs that are on screen now.
  Set<int> _visibleIds() {
    final view = ref.read(libraryViewProvider).value;
    return view == null
        ? const {}
        : {for (final item in view.items) item.content.id};
  }

  Future<void> _delete(Set<int> ids) async {
    if (_deleting || ids.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.libDeleteTitle(ids.length),
      body: l10n.libDeleteBody,
      confirmLabel: l10n.libDelete,
      cancelLabel: l10n.libCancel,
      destructive: true,
    );
    if (!ok || !mounted || _deleting) return;
    setState(() => _deleting = true);
    String message;
    Set<int>? keep;
    try {
      final result = await ref.read(deleteContentProvider)(ids);
      final deleted = result.deletedContentIds.length;
      final failed = result.failures.length;
      message = failed == 0
          ? l10n.libDeleted(deleted)
          : deleted == 0
          ? l10n.libDeleteFailed(failed)
          : l10n.libDeletePartial(deleted, failed);
      keep = {for (final f in result.failures) f.contentId};
    } on Object {
      message = l10n.libDeleteFailed(ids.length);
    }
    if (!mounted) return;
    setState(() => _deleting = false);
    // Failed items stay selected so the user can retry; the selection never
    // holds anything that is not on screen.
    if (keep != null) {
      ref
          .read(librarySelectionProvider.notifier)
          .replace(keep.intersection(_visibleIds()));
    }
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
        item.content.kind != ContentKind.post
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

    // The selection must always be what the user can see (F3): a change of
    // kind or filters ends selection mode, and data changes drop IDs that left
    // the screen.
    ref
      ..listen(libraryKindProvider, (_, _) {
        ref.read(librarySelectionProvider.notifier).clear();
      })
      ..listen(libraryFiltersProvider, (prev, next) {
        if (prev != next) ref.read(librarySelectionProvider.notifier).clear();
      })
      ..listen(libraryViewProvider, (_, next) {
        if (next.value != null &&
            ref.read(librarySelectionProvider).isNotEmpty) {
          ref.read(librarySelectionProvider.notifier).retain(_visibleIds());
        }
      });

    final view = async.value;
    final selecting = selection.isNotEmpty;
    // Delete and Share act on exactly this set.
    final selected = selecting && view != null
        ? selection.intersection({for (final i in view.items) i.content.id})
        : selection;
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
        if (!didPop && !_deleting) {
          ref.read(librarySelectionProvider.notifier).clear();
        }
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
                  onPressed: _deleting
                      ? null
                      : ref.read(librarySelectionProvider.notifier).clear,
                ),
                title: Text(l10n.libSelectedCount(selected.length)),
                bottom: _deleting
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(4),
                        child: LinearProgressIndicator(
                          semanticsLabel: l10n.libDeleting,
                        ),
                      )
                    : null,
                actions: [
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: StorizeSpacing.minTouchTarget,
                      minHeight: StorizeSpacing.minTouchTarget,
                    ),
                    tooltip: l10n.libShare,
                    icon: const Icon(Icons.share_outlined),
                    onPressed: view == null || _deleting
                        ? null
                        : () => unawaited(_share(view, selected)),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: StorizeSpacing.minTouchTarget,
                      minHeight: StorizeSpacing.minTouchTarget,
                    ),
                    tooltip: l10n.libDeleteTooltip,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _deleting
                        ? null
                        : () => unawaited(_delete(selected)),
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
        body: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                semanticsLabel: l10n.libCheckRunning,
                onRefresh: ref.read(checkNowControllerProvider.notifier).run,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Everything scrolls together, so the page survives large
                    // text and short screens (empty and error states fill the
                    // rest).
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
                          onChanged: (k) {
                            ref.read(libraryKindProvider.notifier).select(k);
                            if (filters.highlightsOnly) {
                              ref
                                  .read(libraryFiltersProvider.notifier)
                                  .replace(
                                    filters.copyWith(highlightsOnly: false),
                                  );
                            }
                          },
                          highlightsLabel: l10n.libHighlightsTab,
                          highlightsSelected: filters.highlightsOnly,
                          onHighlights: () {
                            ref
                                .read(libraryKindProvider.notifier)
                                .select(LibraryKind.stories);
                            ref
                                .read(libraryFiltersProvider.notifier)
                                .replace(
                                  filters.copyWith(highlightsOnly: true),
                                );
                          },
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
                          selectedIds: {
                            for (final id in filters.targetIds) '$id',
                          },
                          maxVisible: 4,
                          onOverflowTap: () => unawaited(_openFilters(view)),
                          onChanged: (ids) => ref
                              .read(libraryFiltersProvider.notifier)
                              .replace(
                                filters.copyWith(
                                  targetIds: {
                                    for (final id in ids) int.parse(id),
                                  },
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
                      _rowsSliver(ui.value, kind, selection)
                    else if (ui is UiLoading<LibraryView>)
                      // The skeleton shrink-wraps its grid; a fill-remaining
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
            if (view != null)
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: _StickyDay(day: _stickyDay, now: view.now),
              ),
          ],
        ),
      ),
    );
  }

  /// The rows as one flat, lazily built list with known extents, so the open
  /// time does not depend on how many days there are (NFR-12). The sticky day
  /// header is an overlay driven by the scroll offset.
  Widget _rowsSliver(LibraryView view, LibraryKind kind, Set<int> selection) {
    final thumbBuilder = ref.watch(libraryThumbBuilderProvider);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final scale = MediaQuery.textScalerOf(context);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final layout = _layoutFor(view, kind, width, scale);
        _updateSticky(layout, view, constraints.scrollOffset);
        // The same widget instance is returned while nothing changed, so a
        // scroll frame does not rebuild the visible tiles.
        final key = Object.hash(
          identityHashCode(view),
          kind,
          identityHashCode(selection),
          width,
          scale,
          dpr,
          thumbBuilder,
        );
        if (_sliver != null && _sliverKey == key) return _sliver!;
        _sliverKey = key;
        return _sliver = SliverVariedExtentList.builder(
          itemCount: view.rows.length,
          itemExtentBuilder: (i, _) => layout.extents[i],
          itemBuilder: (context, i) => _buildRow(
            context,
            view.rows[i],
            view: view,
            kind: kind,
            selection: selection,
            layout: layout,
            thumbBuilder: thumbBuilder,
            cacheWidth: (layout.tileWidth * dpr).round(),
          ),
        );
      },
    );
  }

  _RowLayout _layoutFor(
    LibraryView view,
    LibraryKind kind,
    double width,
    TextScaler scale,
  ) {
    final old = _layout;
    if (old != null &&
        identical(old.view, view) &&
        old.kind == kind &&
        old.width == width &&
        old.scale == scale) {
      return old;
    }
    return _layout = _RowLayout.compute(view, kind, width, scale);
  }

  void _updateSticky(_RowLayout layout, LibraryView view, double offset) {
    final day = offset <= 0 || view.rows.isEmpty
        ? null
        : view.groups[view.rowDay[layout.rowAt(offset)]].day;
    if (day == _stickyDay.value || _stickyUpdateScheduled) return;
    _stickyUpdateScheduled = true;
    // Layout cannot notify listeners; apply after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stickyUpdateScheduled = false;
      if (mounted) _stickyDay.value = day;
    });
  }

  Widget _buildRow(
    BuildContext context,
    LibraryRow row, {
    required LibraryView view,
    required LibraryKind kind,
    required Set<int> selection,
    required _RowLayout layout,
    required LibraryThumbBuilder thumbBuilder,
    required int cacheWidth,
  }) {
    final selecting = selection.isNotEmpty;
    return switch (row) {
      DayHeaderRow(:final day) => DateHeader(
        label: libraryDayLabel(context, day, view.now),
      ),
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
                                .targetsById[items[c].content.targetId]
                                ?.username ??
                            '',
                        now: view.now,
                        kind: kind,
                        selected: selection.contains(items[c].content.id),
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
  }

  void _onTileTap(ContentWithMedia item, bool broken) {
    if (_deleting) return;
    if (ref.read(librarySelectionProvider).isNotEmpty) {
      ref.read(librarySelectionProvider.notifier).toggle(item.content.id);
    } else if (broken) {
      unawaited(_offerRemove(item.content.id));
    } else {
      _open(item);
    }
  }

  void _onTileLongPress(ContentWithMedia item) {
    if (_deleting) return;
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
        : MaterialLocalizations.of(context)
              .formatTimeOfDay(TimeOfDay.fromDateTime(last.toLocal()));
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
      ),
      child: Row(
        children: [
          StorizeAvatar(
            initial: name.isEmpty ? null : name.substring(0, 1),
            size: 28,
          ),
          const SizedBox(width: StorizeSpacing.s12),
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
                color: StorizeColors.of(context).accent.container,
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
                    color: StorizeColors.of(context).accent.color,
                    fontWeight: FontWeight.w600,
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

/// "Today", "Yesterday" or a date.
String libraryDayLabel(BuildContext context, DateTime day, DateTime now) {
  final l10n = AppLocalizations.of(context);
  final today = now.toLocal();
  final d = DateTime(today.year, today.month, today.day);
  if (day == d) return l10n.libDateToday;
  if (day == DateTime(d.year, d.month, d.day - 1)) {
    return l10n.libDateYesterday;
  }
  return MaterialLocalizations.of(context).formatMediumDate(day);
}

/// The extents of every row, known up front so the list can stay lazy.
class _RowLayout {
  _RowLayout._(
    this.view,
    this.kind,
    this.width,
    this.scale,
    this.extents,
    this.starts,
    this.tileWidth,
  );

  factory _RowLayout.compute(
    LibraryView view,
    LibraryKind kind,
    double width,
    TextScaler scale,
  ) {
    const gaps = (libraryColumns - 1) * StorizeSpacing.s8;
    final tileWidth = (width - 2 * StorizeSpacing.s16 - gaps) / libraryColumns;
    final tileHeight = tileWidth / (kind == LibraryKind.stories ? 9 / 16 : 1);
    final accountExtent = math.max<double>(40, scale.scale(28) + 12);
    final extents = List<double>.filled(view.rows.length, 0);
    final starts = List<double>.filled(view.rows.length + 1, 0);
    var at = 0.0;
    for (var i = 0; i < view.rows.length; i++) {
      final e = switch (view.rows[i]) {
        DayHeaderRow() => DateHeader.height,
        AccountHeaderRow() => accountExtent,
        TilesRow() => tileHeight + StorizeSpacing.s8,
      };
      extents[i] = e;
      starts[i] = at;
      at += e;
    }
    starts[view.rows.length] = at;
    return _RowLayout._(view, kind, width, scale, extents, starts, tileWidth);
  }

  final LibraryView view;
  final LibraryKind kind;
  final double width;
  final TextScaler scale;
  final List<double> extents;

  /// `starts[i]` is the offset of row `i`; the last entry is the total.
  final List<double> starts;
  final double tileWidth;

  /// The row that covers [offset] (binary search).
  int rowAt(double offset) {
    var lo = 0;
    var hi = extents.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}

/// The header that sticks to the top of the list.
class _StickyDay extends StatelessWidget {
  const _StickyDay({required this.day, required this.now});

  final ValueListenable<DateTime?> day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: day,
      builder: (context, value, _) {
        if (value == null) return const SizedBox.shrink();
        // The inline header carries the semantics; this one only paints.
        return ExcludeSemantics(
          child: IgnorePointer(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: DateHeader(label: libraryDayLabel(context, value, now)),
            ),
          ),
        );
      },
    );
  }
}
