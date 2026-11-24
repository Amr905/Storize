import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/viewer/story_info_sheet.dart';
import 'package:storize_app/features/viewer/story_media.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_app/features/viewer/viewer_action.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// S-06: full-screen viewer for one account's stories. Swipe or tap the edges
/// to move between them; share, info and delete act on the current one.
class StoryViewerPage extends ConsumerStatefulWidget {
  /// Creates the viewer for [contentId].
  const StoryViewerPage({required this.contentId, super.key});

  /// The story that was opened.
  final int contentId;

  @override
  ConsumerState<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends ConsumerState<StoryViewerPage> {
  List<ContentWithMedia>? _items;
  int _index = 0;
  PageController? _pages;
  bool _muted = false;
  bool _busy = false;

  /// Playback fraction of the current video (position bar).
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _pages?.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.libraryPath);
    }
  }

  void _markViewed(int index) {
    final items = _items;
    if (items == null || index < 0 || index >= items.length) return;
    unawaited(
      ref
          .read(storyViewerActionsProvider)
          .markViewed(items[index].content.id)
          .catchError((Object _) {}),
    );
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _progress.value = 0;
    _markViewed(index);
  }

  void _go(int index) {
    final items = _items;
    if (items == null || index < 0 || index >= items.length) return;
    _pages?.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Deletes the current story after the user confirms.
  Future<void> _delete({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final items = _items;
    if (_busy || items == null || items.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final ok = await ConfirmDialog.show(
      context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: l10n.storyCancel,
      destructive: true,
    );
    if (!ok || !mounted || _busy) return;
    final index = _index;
    final id = items[index].content.id;
    setState(() => _busy = true);
    var deleted = false;
    try {
      deleted = await ref.read(storyViewerActionsProvider).delete(id);
    } on Object {
      deleted = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!deleted) {
      _snack(l10n.storyDeleteFailed);
      return;
    }
    _snack(l10n.storyDeleted);
    final remaining = [..._items!]..removeAt(index);
    if (remaining.isEmpty) {
      _close();
      return;
    }
    final next = index.clamp(0, remaining.length - 1);
    setState(() {
      _items = remaining;
      _index = next;
    });
    _progress.value = 0;
    _pages?.jumpToPage(next);
    _markViewed(next);
  }

  Future<void> _share(ContentWithMedia item) async {
    final l10n = AppLocalizations.of(context);
    final files = [
      for (final m in item.media)
        if (m.status == MediaFileStatus.done && m.contentUri != null)
          ShareFile(contentUri: m.contentUri!, mediaType: m.mediaType),
    ];
    if (files.isEmpty) {
      _snack(l10n.storyShareNothing);
      return;
    }
    try {
      await ref.read(shareServiceProvider).share(files);
    } on Object {
      if (mounted) _snack(l10n.storyShareFailed);
    }
  }

  List<String> _links(ContentWithMedia item) {
    final raw = item.content.extras['link_stickers'];
    if (raw is! List<Object?>) return const [];
    return [
      for (final e in raw)
        if (e is Map && e['url'] is String) e['url']! as String,
    ];
  }

  String _ago(AppLocalizations l10n, DateTime postedAt, DateTime now) {
    final d = now.difference(postedAt);
    if (d.inMinutes < 1) return l10n.storyAgoJustNow;
    if (d.inHours < 1) return l10n.storyAgoMinutes(d.inMinutes);
    if (d.inDays < 1) return l10n.storyAgoHours(d.inHours);
    return l10n.storyAgoDays(d.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = StorizeColors.of(context);
    final async = ref.watch(storyViewerSetProvider(widget.contentId));

    final set = async.value;
    if (_items == null && set != null) {
      if (set.items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _close();
        });
        return const Scaffold(body: SizedBox.shrink());
      }
      _items = set.items;
      _index = set.initialIndex;
      _pages = PageController(initialPage: _index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markViewed(_index);
      });
    }

    final items = _items;
    if (items == null) {
      return Scaffold(
        backgroundColor: scheme.scrim,
        body: async.hasError
            ? Center(
                child: IconButton(
                  tooltip: l10n.storyClose,
                  icon: Icon(Icons.close_rounded, color: colors.onMediaScrim),
                  onPressed: _close,
                ),
              )
            : Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.storyLoading,
                ),
              ),
      );
    }

    final item = items[_index];
    final media = item.media.isEmpty ? null : item.media.first;
    final isVideo = media?.mediaType == MediaType.video;
    final username = set?.username ?? '';
    final links = _links(item);
    final now = ref.watch(clockProvider).now();
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();
    final onScrim = colors.onMediaScrim;

    return Scaffold(
      backgroundColor: scheme.scrim,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) _close();
        },
        child: SafeArea(
          child: Column(
            children: [
              // Position bars: one per story; the current one follows the
              // video position (photos count as full).
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  StorizeSpacing.s8,
                  StorizeSpacing.s8,
                  StorizeSpacing.s8,
                  0,
                ),
                child: ValueListenableBuilder<double>(
                  valueListenable: _progress,
                  builder: (context, progress, _) => Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: StorizeSpacing.s4 / 2,
                            ),
                            child: ClipRRect(
                              borderRadius: StorizeRadii.fullRadius,
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                value: i < _index
                                    ? 1
                                    : i == _index
                                    ? (isVideo ? progress : 1)
                                    : 0,
                                color: onScrim,
                                backgroundColor: onScrim.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Header: account, posted time, mute (video) and close.
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: StorizeSpacing.s16,
                  vertical: StorizeSpacing.s8,
                ),
                child: Row(
                  children: [
                    CircleAvatar(child: Text(initial)),
                    const SizedBox(width: StorizeSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.storyAccount(username),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: onScrim),
                          ),
                          if (item.content.extras[HighlightExtras.title]
                              case final String highlightTitle)
                            Text(
                              l10n.storyHighlightTitle(highlightTitle),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: onScrim),
                            ),
                          Text(
                            l10n.storyPostedLine(
                              MaterialLocalizations.of(context).formatTimeOfDay(
                                TimeOfDay.fromDateTime(
                                  item.content.postedAt.toLocal(),
                                ),
                              ),
                              _ago(l10n, item.content.postedAt, now),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: onScrim.withValues(alpha: 0.85),
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (isVideo)
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: StorizeSpacing.minTouchTarget,
                          minHeight: StorizeSpacing.minTouchTarget,
                        ),
                        tooltip: _muted ? l10n.storyUnmute : l10n.storyMute,
                        color: onScrim,
                        icon: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                        onPressed: () => setState(() => _muted = !_muted),
                      ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: StorizeSpacing.minTouchTarget,
                        minHeight: StorizeSpacing.minTouchTarget,
                      ),
                      tooltip: l10n.storyClose,
                      color: onScrim,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _close,
                    ),
                  ],
                ),
              ),
              // Media pager. Edge taps are handled per page.
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) => StoryMediaView(
                    key: ValueKey(items[i].content.id),
                    item: items[i],
                    active: i == _index,
                    muted: _muted,
                    onPrevious: () => _go(i - 1),
                    onNext: () => _go(i + 1),
                    onRemove: () => unawaited(
                      _delete(
                        title: l10n.storyMissingTitle,
                        body: l10n.storyMissingBody,
                        confirmLabel: l10n.storyRemoveFromLibrary,
                      ),
                    ),
                    onProgress: (p) {
                      if (i == _index) _progress.value = p;
                    },
                  ),
                ),
              ),
              // Link stickers, when the story has any.
              for (final url in links)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    StorizeSpacing.s16,
                    StorizeSpacing.s8,
                    StorizeSpacing.s16,
                    0,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.mediaScrim,
                      borderRadius: StorizeRadii.chipRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: StorizeSpacing.s16,
                        vertical: StorizeSpacing.s12,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded, color: onScrim),
                          const SizedBox(width: StorizeSpacing.s8),
                          Expanded(
                            child: Text(
                              l10n.storyLinkSticker(url),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: onScrim),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Action bar: Share, Info, Delete. There is no Save button; the
              // file is already in the gallery (FR-33).
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: StorizeSpacing.s8,
                ),
                child: Row(
                  children: [
                    ViewerAction(
                      icon: Icons.share_outlined,
                      label: l10n.storyShare,
                      color: onScrim,
                      onPressed: _busy ? null : () => _share(item),
                    ),
                    ViewerAction(
                      icon: Icons.info_outline_rounded,
                      label: l10n.storyInfo,
                      color: onScrim,
                      onPressed: () => unawaited(
                        showStoryInfoSheet(
                          context,
                          item: item,
                          username: username,
                        ),
                      ),
                    ),
                    ViewerAction(
                      icon: Icons.delete_outline_rounded,
                      label: l10n.storyDelete,
                      color: onScrim,
                      onPressed: _busy
                          ? null
                          : () => unawaited(
                              _delete(
                                title: l10n.storyDeleteTitle,
                                body: l10n.storyDeleteBody,
                                confirmLabel: l10n.storyDelete,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
