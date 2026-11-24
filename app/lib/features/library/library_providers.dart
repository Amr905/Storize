import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/library/library_view.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The current Stories/Posts switch value.
final libraryKindProvider =
    NotifierProvider<LibraryKindController, LibraryKind>(
      LibraryKindController.new,
    );

/// Holds the kind switch.
class LibraryKindController extends Notifier<LibraryKind> {
  @override
  LibraryKind build() => LibraryKind.stories;

  /// Selects [kind].
  // ignore: use_setters_to_change_properties, keeps call sites uniform.
  void select(LibraryKind kind) => state = kind;
}

/// The active S-05 filters.
final libraryFiltersProvider =
    NotifierProvider<LibraryFiltersController, LibraryFilters>(
      LibraryFiltersController.new,
    );

/// Holds the filters.
class LibraryFiltersController extends Notifier<LibraryFilters> {
  @override
  LibraryFilters build() => LibraryFilters.none;

  /// Replaces the filters.
  // ignore: use_setters_to_change_properties, keeps call sites uniform.
  void replace(LibraryFilters filters) => state = filters;

  /// Clears every filter.
  void clear() => state = LibraryFilters.none;
}

/// The IDs of the selected items. Empty means selection mode is off.
final librarySelectionProvider =
    NotifierProvider<LibrarySelectionController, Set<int>>(
      LibrarySelectionController.new,
    );

/// Holds the selection.
class LibrarySelectionController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  /// Starts selection mode with [id] selected, or toggles it when on.
  void toggle(int id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  /// Leaves selection mode.
  void clear() => state = const {};

  /// Replaces the selection.
  void replace(Set<int> ids) => state = Set.unmodifiable(ids);

  /// Drops every selected ID that is not in [visible]. Keeps the same state
  /// object when nothing changes.
  void retain(Set<int> visible) {
    if (state.isEmpty || visible.containsAll(state)) return;
    state = Set.unmodifiable(state.intersection(visible));
  }
}

/// Every stored item, newest first. One repo subscription feeds the grid, the
/// unviewed counts and the empty states (TECH_SPEC: `watchLibrary` once).
final allContentProvider = StreamProvider<List<ContentWithMedia>>(
  (ref) => ref.watch(contentRepoProvider).watchLibrary(ContentFilter()),
);

/// All targets.
final libraryTargetsProvider = StreamProvider<List<Target>>(
  (ref) => ref.watch(targetRepoProvider).watchAll(),
);

/// What the page renders. Errors from either stream (or from an unwired
/// provider) surface as [AsyncError].
final libraryViewProvider = Provider<AsyncValue<LibraryView>>((ref) {
  try {
    final all = ref.watch(allContentProvider);
    final targets = ref.watch(libraryTargetsProvider);
    final kind = ref.watch(libraryKindProvider);
    final filters = ref.watch(libraryFiltersProvider);
    final error = all.error ?? targets.error;
    if (error != null && (!all.hasValue || !targets.hasValue)) {
      return AsyncError(error, all.stackTrace ?? targets.stackTrace!);
    }
    if (!all.hasValue || !targets.hasValue) return const AsyncLoading();
    final now = ref.watch(clockProvider).now();
    return AsyncData(
      buildLibraryView(
        all: all.requireValue,
        targets: targets.requireValue,
        kind: kind,
        filters: filters,
        now: now,
      ),
    );
  } on Object catch (e, s) {
    return AsyncError(e, s);
  }
});

/// Pure view builder (tested directly).
LibraryView buildLibraryView({
  required List<ContentWithMedia> all,
  required List<Target> targets,
  required LibraryKind kind,
  required LibraryFilters filters,
  required DateTime now,
}) {
  final wanted = kind == LibraryKind.stories
      ? ContentKind.story
      : ContentKind.post;
  final filter = filters.toContentFilter(kind, now);
  var unviewedStories = 0;
  var unviewedPosts = 0;
  var totalOfKind = 0;
  final shown = <ContentWithMedia>[];
  for (final item in all) {
    final c = item.content;
    if (!c.viewed) {
      // A highlight counts and shows like a story until T-042.
      if (c.kind != ContentKind.post) {
        unviewedStories++;
      } else {
        unviewedPosts++;
      }
    }
    if ((c.kind == ContentKind.post) != (wanted == ContentKind.post)) continue;
    totalOfKind++;
    if (filter.matches(c, item.media) && filters.matchesShape(item, kind)) {
      shown.add(item);
    }
  }
  final byId = {for (final t in targets) t.id: t};
  DateTime? lastCheck;
  for (final t in targets) {
    final at = kind == LibraryKind.stories
        ? t.lastStoriesCheckAt
        : t.lastPostsCheckAt;
    if (at != null && (lastCheck == null || at.isAfter(lastCheck))) {
      lastCheck = at;
    }
  }
  final groups = groupLibrary(shown, byId);
  final flat = flattenGroups(groups);
  return LibraryView(
    groups: groups,
    rows: flat.rows,
    rowDay: flat.rowDay,
    itemCount: shown.length,
    targets: targets,
    targetsById: byId,
    unviewedStories: unviewedStories,
    unviewedPosts: unviewedPosts,
    totalOfKind: totalOfKind,
    filtersActive: filters.isActive,
    now: now,
    lastCheck: lastCheck,
  );
}

/// Builds the thumbnail image of a tile. Replace it in tests: the default
/// decodes a real file.
typedef LibraryThumbBuilder = Widget Function(
  BuildContext context,
  String thumbPath,
  int cacheWidth,
);

/// The default decodes the cached thumbnail at tile size (`cacheWidth`).
final libraryThumbBuilderProvider = Provider<LibraryThumbBuilder>(
  (ref) =>
      (context, path, cacheWidth) => Image.file(
        File(path),
        cacheWidth: cacheWidth,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        excludeFromSemantics: true,
        errorBuilder: (context, _, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Icon(
            Icons.broken_image_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
);

/// State of a "check now" run.
@immutable
class CheckNowState {
  /// Creates a state.
  const CheckNowState({this.running = false, this.result});

  /// A check is running.
  final bool running;

  /// The last finished result; consumed by the page.
  final CheckNowResult? result;
}

/// Runs [CheckNowAction] and tracks progress and the result.
final checkNowControllerProvider =
    NotifierProvider<CheckNowController, CheckNowState>(CheckNowController.new);

/// Controller behind pull-to-refresh and the "Check now" button.
class CheckNowController extends Notifier<CheckNowState> {
  @override
  CheckNowState build() => const CheckNowState();

  /// Runs a check. Calls while one runs share nothing and return at once.
  Future<void> run() async {
    if (state.running) return;
    state = const CheckNowState(running: true);
    CheckNowResult result;
    try {
      result = await ref.read(checkNowActionProvider)();
    } on Object {
      result = const CheckNowResult(failed: true);
    }
    state = CheckNowState(result: result);
  }

  /// Marks the result as shown.
  void consume() => state = const CheckNowState();
}
