import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/viewer/content_details.dart';
import 'package:storize_app/features/viewer/post_info_sheet.dart';
import 'package:storize_app/features/viewer/post_providers.dart';
import 'package:storize_app/features/viewer/post_slide.dart';
import 'package:storize_app/features/viewer/story_providers.dart';
import 'package:storize_app/features/viewer/viewer_action.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// S-15: full-screen viewer for one saved post. Swipe between its slides,
/// read the caption, and share, inspect or delete the post.
class PostViewerPage extends ConsumerStatefulWidget {
  /// Creates the page for [contentId].
  const PostViewerPage({required this.contentId, super.key});

  /// The post to open.
  final int contentId;

  @override
  ConsumerState<PostViewerPage> createState() => _PostViewerPageState();
}

class _PostViewerPageState extends ConsumerState<PostViewerPage> {
  final PageController _pages = PageController();
  final GlobalKey _moreKey = GlobalKey();
  int _index = 0;
  bool _busy = false;
  bool _captionOpen = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.libraryPath);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Shares the slides in [media] that are in the gallery.
  Future<void> _share(List<MediaFile> media) async {
    final l10n = AppLocalizations.of(context);
    final files = [
      for (final m in media)
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

  Future<void> _showMore(List<MediaFile> media) async {
    final l10n = AppLocalizations.of(context);
    final box = _moreKey.currentContext!.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      Offset.zero & overlay.size,
    );
    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'share_all',
          child: Text(l10n.postShareAll),
        ),
      ],
    );
    if (choice == 'share_all' && mounted) {
      await _share(media);
    }
  }

  /// Deletes the whole post after the user confirms (BR-9).
  Future<void> _delete(ContentWithMedia item) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final count = item.media.length;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.postDeleteTitle(count),
      body: l10n.postDeleteBody,
      confirmLabel: l10n.storyDelete,
      cancelLabel: l10n.storyCancel,
      destructive: true,
    );
    if (!ok || !mounted || _busy) return;
    setState(() => _busy = true);
    var deleted = false;
    try {
      deleted = await ref
          .read(storyViewerActionsProvider)
          .delete(item.content.id);
    } on Object {
      deleted = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!deleted) {
      _snack(l10n.postDeleteFailed);
      return;
    }
    _snack(l10n.postDeleted);
    _close();
  }

  Future<void> _removeSlide(int slideIndex) async {
    final l10n = AppLocalizations.of(context);
    final remover = ref.read(postSlideRemoverProvider);
    if (remover == null) return;
    final removed = await remover(widget.contentId, slideIndex);
    if (!mounted) return;
    if (removed) {
      ref.invalidate(postViewerProvider(widget.contentId));
    } else {
      _snack(l10n.postSlideRemoveFailed);
    }
  }

  String _when(DateTime utc) {
    final loc = MaterialLocalizations.of(context);
    final local = utc.toLocal();
    return '${loc.formatMediumDate(local)} · '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = StorizeColors.of(context);
    final text = Theme.of(context).textTheme;
    final onSurface = scheme.onSurface;
    final onMedia = colors.onMediaScrim;
    final async = ref.watch(postViewerProvider(widget.contentId));
    final data = async.value;

    if (data == null) {
      if (async.hasError) {
        return Scaffold(
          backgroundColor: scheme.scrim,
          body: Center(
            child: IconButton(
              tooltip: l10n.storyClose,
              icon: Icon(Icons.close_rounded, color: onMedia),
              onPressed: _close,
            ),
          ),
        );
      }
      if (!async.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _close();
        });
        return Scaffold(backgroundColor: scheme.scrim, body: const SizedBox());
      }
      return Scaffold(
        backgroundColor: scheme.scrim,
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.storyLoading),
        ),
      );
    }

    final item = data.item;
    final media = item.media;
    final total = media.length;
    final username = data.username;
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();
    final caption = item.content.caption;
    final typeLabel = postTypeLabel(l10n, item.content, media);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: back, account, slide counter, more.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                StorizeSpacing.s4,
                StorizeSpacing.s8,
                StorizeSpacing.s8,
                StorizeSpacing.s8,
              ),
              child: Row(
                children: [
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: StorizeSpacing.minTouchTarget,
                      minHeight: StorizeSpacing.minTouchTarget,
                    ),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    color: onSurface,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _close,
                  ),
                  CircleAvatar(child: Text(initial)),
                  const SizedBox(width: StorizeSpacing.s8),
                  Expanded(
                    child: Text(
                      l10n.storyAccount(username),
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(color: onSurface),
                    ),
                  ),
                  if (total > 0)
                    Text(
                      l10n.postCounter(_index + 1, total),
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  IconButton(
                    key: _moreKey,
                    constraints: const BoxConstraints(
                      minWidth: StorizeSpacing.minTouchTarget,
                      minHeight: StorizeSpacing.minTouchTarget,
                    ),
                    tooltip: l10n.postMoreTooltip,
                    color: onSurface,
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => unawaited(_showMore(media)),
                  ),
                ],
              ),
            ),
            // Media pager.
            Expanded(
              child: ColoredBox(
                color: scheme.scrim,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => Semantics(
                    label: l10n.postSlideSemantics(i + 1, total),
                    child: PostSlideView(
                      key: ValueKey('slide-${media[i].id}'),
                      contentId: item.content.id,
                      media: media[i],
                      onRemove: ref.watch(postSlideRemoverProvider) == null
                          ? null
                          : () => unawaited(_removeSlide(media[i].slideIndex)),
                    ),
                  ),
                ),
              ),
            ),
            // Page dots.
            if (total > 1)
              ExcludeSemantics(
                key: const ValueKey('post-dots'),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: StorizeSpacing.s8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < total; i++)
                        Container(
                          width: StorizeSpacing.s8,
                          height: StorizeSpacing.s8,
                          margin: const EdgeInsetsDirectional.symmetric(
                            horizontal: StorizeSpacing.s4 / 2,
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index
                                ? scheme.primary
                                : scheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Meta line and expandable caption. Scrolls when long.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: StorizeSpacing.s16,
                    vertical: StorizeSpacing.s8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.postPostedOn(
                          _when(item.content.postedAt),
                          typeLabel,
                        ),
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (caption != null && caption.isNotEmpty) ...[
                        const SizedBox(height: StorizeSpacing.s4),
                        GestureDetector(
                          onLongPress: () async {
                            await copyCaption(caption);
                            if (mounted) _snack(l10n.infoCaptionCopied);
                          },
                          child: Text(
                            caption,
                            maxLines: _captionOpen ? null : 3,
                            overflow: _captionOpen
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(color: onSurface),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.onSurfaceVariant,
                            minimumSize: const Size(
                              0,
                              StorizeSpacing.minTouchTarget,
                            ),
                          ),
                          onPressed: () =>
                              setState(() => _captionOpen = !_captionOpen),
                          child: Text(
                            _captionOpen
                                ? l10n.postCaptionLess
                                : l10n.postCaptionMore,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Action bar: share this slide, info, delete the post.
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outline)),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: StorizeSpacing.s8,
                  vertical: StorizeSpacing.s8,
                ),
                child: Row(
                  children: [
                    ViewerAction(
                      icon: Icons.share_outlined,
                      label: l10n.storyShare,
                      color: onSurface,
                      onPressed: _busy || total == 0
                          ? null
                          : () => unawaited(
                              _share([media[_index.clamp(0, total - 1)]]),
                            ),
                    ),
                    ViewerAction(
                      icon: Icons.info_outline_rounded,
                      label: l10n.storyInfo,
                      color: onSurface,
                      onPressed: () => unawaited(
                        showPostInfoSheet(
                          context,
                          item: item,
                          username: username,
                        ),
                      ),
                    ),
                    ViewerAction(
                      icon: Icons.delete_outline_rounded,
                      label: l10n.storyDelete,
                      color: onSurface,
                      onPressed: _busy ? null : () => unawaited(_delete(item)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
