import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/library/library_tile.dart';
import 'package:storize_app/features/settings/settings_format.dart';
import 'package:storize_app/features/targets/remove_target_dialog.dart';
import 'package:storize_app/features/targets/target_detail_providers.dart';
import 'package:storize_app/features/targets/target_history_section.dart';
import 'package:storize_app/features/targets/target_list_row.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// S-09: one tracked account, its stats, its settings and its recent items.
class TargetDetailPage extends ConsumerStatefulWidget {
  /// Creates the page for [targetId].
  const TargetDetailPage({required this.targetId, super.key});

  /// The target to show.
  final int targetId;

  @override
  ConsumerState<TargetDetailPage> createState() => _TargetDetailPageState();
}

enum _MenuAction { remove }

class _TargetDetailPageState extends ConsumerState<TargetDetailPage> {
  LibraryKind _kind = LibraryKind.stories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(targetDetailTargetProvider(widget.targetId));
    return async.when(
      loading: () => _frame(
        l10n.screenTargetDetail,
        const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _frame(
        l10n.screenTargetDetail,
        Center(child: Text(l10n.errorUnknownBody)),
      ),
      data: (target) => target == null
          ? _frame(
              l10n.screenTargetDetail,
              Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(
                    StorizeSpacing.screenMargin,
                  ),
                  child: Text(l10n.tdtNotFound, textAlign: TextAlign.center),
                ),
              ),
            )
          : _detail(context, target),
    );
  }

  Widget _frame(String title, Widget body) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: body,
  );

  Widget _detail(BuildContext context, Target target) {
    final l10n = AppLocalizations.of(context);
    final checking = ref.watch(targetCheckRunningProvider);
    final sessionActive = ref.watch(targetsSessionActiveProvider);
    final status = _statusOf(target, checking: checking);
    final contentAsync = ref.watch(targetDetailContentProvider(target.id));
    final storageAsync = ref.watch(targetDetailStorageProvider(target.id));
    final items = contentAsync.value ?? const <ContentWithMedia>[];
    final storyCount = items
        .where((i) => i.content.kind != ContentKind.post)
        .length;
    final postCount = items
        .where((i) => i.content.kind == ContentKind.post)
        .length;
    final loaded = contentAsync.hasValue;
    final paused = target.status == TargetStatus.paused;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${target.username}'),
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: l10n.tdtMenuTooltip,
            onSelected: (action) {
              if (action == _MenuAction.remove) {
                unawaited(
                  _remove(target, storyCount: storyCount, postCount: postCount),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.remove,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: StorizeSpacing.s12),
                    Text(
                      l10n.tdtRemove,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.screenMargin,
          vertical: StorizeSpacing.s8,
        ),
        children: [
          _Header(target: target, status: status),
          const SizedBox(height: StorizeSpacing.s16),
          if (_explanation(context, target) case final text?)
            _StatusCard(status: status, text: text),
          _EditRow(
            label: l10n.tdtCategoryLabel,
            value: CategoryTag(
              kind: _categoryKind(target.category),
              label: TargetListRow.categoryLabel(
                l10n,
                _categoryKind(target.category),
              ),
            ),
            editTooltip: l10n.tdtEditCategory,
            onEdit: () => unawaited(_editCategory(target)),
          ),
          _EditRow(
            label: l10n.tdtNoteLabel,
            value: Text(
              target.note ?? l10n.tdtNoteNone,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: target.note == null
                  ? TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
            editTooltip: l10n.tdtEditNote,
            onEdit: () => unawaited(_editNote(target)),
          ),
          _EditRow(
            label: l10n.tgtTrackLabel,
            value: Wrap(
              alignment: WrapAlignment.end,
              spacing: StorizeSpacing.s8,
              runSpacing: StorizeSpacing.s4,
              children: [
                for (final kind in TrackKind.values)
                  FilterChip(
                    label: Text(_trackLabel(l10n, kind)),
                    selected: _isOn(target, kind),
                    onSelected: (on) =>
                        unawaited(_toggleTrack(target, kind, on)),
                  ),
              ],
            ),
            divider: false,
          ),
          TargetHistorySection(target: target),
          const SizedBox(height: StorizeSpacing.s16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: loaded ? '$storyCount' : '—',
                  label: l10n.tdtStatStories,
                ),
              ),
              const SizedBox(width: StorizeSpacing.s8),
              Expanded(
                child: StatTile(
                  value: loaded ? '$postCount' : '—',
                  label: l10n.tdtStatPosts,
                ),
              ),
              const SizedBox(width: StorizeSpacing.s8),
              Expanded(
                child: StatTile(
                  value: storageAsync.hasValue
                      ? formatBytes(l10n, storageAsync.value!)
                      : '—',
                  label: l10n.tdtStatSpace,
                ),
              ),
            ],
          ),
          const SizedBox(height: StorizeSpacing.s12),
          Text(
            _metaLine(context, target),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: StorizeSpacing.s12),
          Row(
            children: [
              Expanded(
                child: sessionActive || checking
                    ? TonalButton(
                        label: l10n.tgtCheckNow,
                        icon: Icons.sync_rounded,
                        loading: checking,
                        expand: true,
                        onPressed: sessionActive && !checking
                            ? () => unawaited(_checkNow())
                            : null,
                      )
                    : Tooltip(
                        message: l10n.tgtCheckNowDisabled,
                        child: TonalButton(
                          label: l10n.tgtCheckNow,
                          icon: Icons.sync_rounded,
                          expand: true,
                          onPressed: null,
                        ),
                      ),
              ),
              const SizedBox(width: StorizeSpacing.s16),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  ),
                  label: Text(
                    paused ? l10n.tgtActionResume : l10n.tgtActionPause,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    textStyle: Theme.of(context).textTheme.titleMedium,
                  ),
                  onPressed: () => unawaited(_setPaused(target, !paused)),
                ),
              ),
            ],
          ),
          const SizedBox(height: StorizeSpacing.s24),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: StorizeSpacing.s8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.libStoriesTab),
                      selected: _kind == LibraryKind.stories,
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _kind = LibraryKind.stories),
                    ),
                    ChoiceChip(
                      label: Text(l10n.libPostsTab),
                      selected: _kind == LibraryKind.posts,
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _kind = LibraryKind.posts),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded),
                label: Text(l10n.tdtSeeAll),
                onPressed: () => unawaited(
                  context.push(
                    Routes.libraryLocation(
                      kind: _kind == LibraryKind.stories
                          ? ContentKind.story
                          : ContentKind.post,
                      targetId: target.id,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: StorizeSpacing.s12),
          _recent(context, target, contentAsync),
        ],
      ),
    );
  }

  Widget _recent(
    BuildContext context,
    Target target,
    AsyncValue<List<ContentWithMedia>> contentAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    if (contentAsync.isLoading && !contentAsync.hasValue) {
      return const Padding(
        padding: EdgeInsetsDirectional.all(StorizeSpacing.s24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!contentAsync.hasValue) {
      return Center(child: Text(l10n.errorUnknownBody));
    }
    final isStories = _kind == LibraryKind.stories;
    final shown = [
      for (final item in contentAsync.requireValue)
        if ((item.content.kind != ContentKind.post) == isStories) item,
    ].take(_recentLimit).toList();
    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: StorizeSpacing.s24,
        ),
        child: Center(
          child: Text(
            isStories ? l10n.tdtEmptyStories : l10n.tdtEmptyPosts,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final now = ref.watch(clockProvider).now();
    final thumbBuilder = ref.watch(libraryThumbBuilderProvider);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: StorizeSpacing.s8,
      crossAxisSpacing: StorizeSpacing.s8,
      childAspectRatio: isStories ? 9 / 16 : 1,
      children: [
        for (final item in shown)
          LibraryTile(
            item: item,
            account: target.username,
            now: now,
            kind: _kind,
            selected: false,
            selectionMode: false,
            cacheWidth: 240,
            thumbBuilder: thumbBuilder,
            onTap: (item, _) => unawaited(
              context.push(
                isStories
                    ? Routes.storyLocation(item.content.id)
                    : Routes.postLocation(item.content.id),
              ),
            ),
            onLongPress: (_) {},
          ),
      ],
    );
  }

  static const int _recentLimit = 9;

  // ---- Actions -----------------------------------------------------------

  Future<void> _checkNow() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(targetCheckRunningProvider.notifier)
        .checkAll(targetId: widget.targetId);
    if (result == null || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? l10n.tgtCheckFailed
              : l10n.tgtCheckDone(result.newItems),
        ),
      ),
    );
  }

  Future<void> _setPaused(Target target, bool paused) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(targetActionsProvider).setPaused(target, paused: paused);
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.tgtUpdateFailed)));
    }
  }

  Future<void> _toggleTrack(Target target, TrackKind kind, bool on) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref
          .read(targetDetailActionsProvider)
          .setTrack(target, kind, on: on);
      if (!saved && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.tgtTrackRequired)));
      }
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.tgtUpdateFailed)));
    }
  }

  Future<void> _editCategory(Target target) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<TargetCategory>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CategorySheet(current: target.category),
    );
    if (picked == null || picked == target.category || !mounted) return;
    try {
      await ref.read(targetDetailActionsProvider).setCategory(target, picked);
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.tgtUpdateFailed)));
    }
  }

  Future<void> _editNote(Target target) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoteSheet(initial: target.note ?? ''),
    );
    if (text == null || !mounted) return;
    try {
      await ref.read(targetDetailActionsProvider).setNote(target, text);
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.tgtUpdateFailed)));
    }
  }

  Future<void> _remove(
    Target target, {
    required int storyCount,
    required int postCount,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final removed = await RemoveTargetDialog.show(
      context,
      target: target,
      storyCount: storyCount,
      postCount: postCount,
    );
    if (!removed || !mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.targetsPath);
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.tdtRemoved(target.username))),
    );
  }

  // ---- Mapping helpers ---------------------------------------------------

  static StorizeStatus _statusOf(Target t, {required bool checking}) {
    if (checking && t.status == TargetStatus.active) {
      return StorizeStatus.checking;
    }
    return switch (t.status) {
      TargetStatus.active => StorizeStatus.active,
      TargetStatus.paused => StorizeStatus.paused,
      TargetStatus.notVisible => StorizeStatus.notVisible,
      TargetStatus.unavailable => StorizeStatus.unavailable,
      TargetStatus.error => StorizeStatus.error,
    };
  }

  /// The S-09 explanation card text, or null when no card is shown.
  String? _explanation(BuildContext context, Target target) {
    final l10n = AppLocalizations.of(context);
    final login = ref.watch(targetsLoginNameProvider).value;
    return switch (target.status) {
      TargetStatus.notVisible => l10n.tdtStatusNotVisible(
        login == null ? l10n.tdtLoginFallback : '@$login',
      ),
      TargetStatus.unavailable => l10n.tdtStatusUnavailable,
      TargetStatus.error => _errorText(context, target),
      TargetStatus.active || TargetStatus.paused => null,
    };
  }

  String _errorText(BuildContext context, Target target) {
    final l10n = AppLocalizations.of(context);
    final reason = target.statusReason?.trim();
    final at = target.lastStoriesCheckAt ?? target.lastPostsCheckAt;
    if (reason == null || reason.isEmpty || at == null) {
      return l10n.tdtStatusErrorNone;
    }
    return l10n.tdtStatusErrorBody(reason, _time(context, at));
  }

  String _metaLine(BuildContext context, Target target) {
    final l10n = AppLocalizations.of(context);
    final checked = target.lastStoriesCheckAt;
    var line = checked == null
        ? l10n.tgtMetaNever
        : l10n.tgtMetaChecked(_time(context, checked));
    final newStory = target.lastNewStoryAt;
    if (newStory != null) {
      line = l10n.tgtMetaLine(
        line,
        l10n.tgtMetaLastNew(_time(context, newStory)),
      );
    }
    final newPost = target.lastNewPostAt;
    if (newPost != null) {
      final date = MaterialLocalizations.of(context)
          .formatMediumDate(newPost.toLocal());
      line = l10n.tgtMetaLine(line, l10n.tdtMetaNewPost(date));
    }
    return line;
  }

  static String _time(BuildContext context, DateTime at) =>
      MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(at.toLocal()));

  static bool _isOn(Target t, TrackKind kind) => switch (kind) {
    TrackKind.stories => t.trackStories,
    TrackKind.posts => t.trackPosts,
    TrackKind.reels => t.trackReels,
  };

  static String _trackLabel(AppLocalizations l10n, TrackKind kind) =>
      switch (kind) {
        TrackKind.stories => l10n.tgtTrackStories,
        TrackKind.posts => l10n.tgtTrackPosts,
        TrackKind.reels => l10n.tgtTrackReels,
      };

  static CategoryKind _categoryKind(TargetCategory c) => switch (c) {
    TargetCategory.ownClient => CategoryKind.ownClient,
    TargetCategory.consented => CategoryKind.consented,
    TargetCategory.public => CategoryKind.publicFigure,
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.target, required this.status});

  final Target target;
  final StorizeStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = target.displayName?.trim();
    final hasName = name != null && name.isNotEmpty;
    return Row(
      children: [
        StorizeAvatar(initial: target.username[0], size: 56),
        const SizedBox(width: StorizeSpacing.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasName ? name : '@${target.username}',
                style: theme.textTheme.titleLarge,
              ),
              if (hasName)
                Text(
                  '@${target.username}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: StorizeSpacing.s4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DotStatusBadge(status: status),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.text});

  final StorizeStatus status;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = StatusBadge.toneFor(StorizeColors.of(context), status);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: StorizeSpacing.s16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.container,
          borderRadius: StorizeRadii.cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(StorizeSpacing.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(StatusBadge.iconFor(status), color: tone.color),
              ),
              const SizedBox(width: StorizeSpacing.s12),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: tone.onContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.label,
    required this.value,
    this.editTooltip,
    this.onEdit,
    this.divider = true,
  });

  final String label;
  final Widget value;
  final String? editTooltip;
  final VoidCallback? onEdit;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? BorderDirectional(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              )
            : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: StorizeSpacing.s12),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: value,
              ),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: editTooltip,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              )
            else
              const SizedBox(width: StorizeSpacing.s8),
          ],
        ),
      ),
    );
  }
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.current});

  final TargetCategory current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              StorizeSpacing.screenMargin,
              0,
              StorizeSpacing.screenMargin,
              StorizeSpacing.s8,
            ),
            child: Text(
              l10n.tdtCategoryLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<TargetCategory>(
            groupValue: current,
            onChanged: (value) {
              if (value != null) Navigator.of(context).pop(value);
            },
            child: Column(
              children: [
                for (final c in TargetCategory.values)
                  RadioListTile<TargetCategory>(
                    value: c,
                    title: Text(
                      TargetListRow.categoryLabel(
                        l10n,
                        _TargetDetailPageState._categoryKind(c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.initial});

  final String initial;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        StorizeSpacing.screenMargin,
        0,
        StorizeSpacing.screenMargin,
        StorizeSpacing.screenMargin + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: Target.maxNoteLength,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.tgtNoteLabel,
              hintText: l10n.tgtNoteHint,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StorizeTextButton(
                label: l10n.setCancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: StorizeSpacing.s8),
              PrimaryButton(
                label: l10n.setSave,
                onPressed: () => Navigator.of(context).pop(_controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
