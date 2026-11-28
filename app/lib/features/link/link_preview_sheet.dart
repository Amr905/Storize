import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/link/link_providers.dart';
import 'package:storize_app/features/preview/preview_page.dart'
    show PreviewImage;
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The "Link preview" sheet (FR-80): a thumbnail, the account and the kind,
/// with Save. Saving goes through `SaveFromLink` (rows, download now, hide
/// from gallery, a paused preview-only target for an untracked account).
class LinkPreviewSheet extends ConsumerStatefulWidget {
  /// Creates the sheet content for [preview].
  const LinkPreviewSheet({required this.preview, super.key});

  /// What the link points at.
  final LinkPreview preview;

  /// Shows the sheet above [context].
  static Future<void> show(BuildContext context, LinkPreview preview) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => LinkPreviewSheet(preview: preview),
      );

  @override
  ConsumerState<LinkPreviewSheet> createState() => _LinkPreviewSheetState();
}

enum _Stage { ready, saving, saved, failed }

class _LinkPreviewSheetState extends ConsumerState<LinkPreviewSheet> {
  _Stage _stage = _Stage.ready;
  String? _message;
  int? _openContentId;
  ContentKind? _openKind;

  LinkPreview get _p => widget.preview;

  /// The item the sheet shows and opens.
  RemoteContent get _shown => _p.focus ?? _p.items.first;

  bool get _allSaved => _p.focus != null ? _p.focusSaved : _p.unsavedCount == 0;

  Future<void> _save({required bool all}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _stage = _Stage.saving);
    PreviewSaveResult? result;
    try {
      result = await ref.read(saveFromLinkProvider).save(_p, all: all);
    } on Object {
      result = null;
    }
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _stage = _Stage.failed;
        _message = l10n.prvSaveFailed(l10n.prvReasonGeneric);
      });
      return;
    }
    final first = result.items.where((i) => i.contentId != null).firstOrNull;
    if (result.saved > 0 || (result.failed == 0 && result.alreadySaved > 0)) {
      setState(() {
        _stage = _Stage.saved;
        _openContentId = first?.contentId;
        _openKind = first?.kind;
        _message = result!.failed > 0
            ? l10n.prvSavePartial(result.saved, result.failed)
            : (result.saved == 0
                  ? l10n.lnkAlreadySaved
                  : l10n.prvSaveDone(result.saved));
      });
      return;
    }
    final reason = result.items.map((i) => i.reason).whereType<String>();
    setState(() {
      _stage = _Stage.failed;
      _message = l10n.prvSaveFailed(_reasonText(l10n, reason.firstOrNull));
    });
  }

  void _open(int contentId, ContentKind kind) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(
      router.push(
        kind == ContentKind.post
            ? Routes.postLocation(contentId)
            : Routes.storyLocation(contentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = _p;
    final saving = _stage == _Stage.saving;
    final savedId = p.focus != null
        ? p.savedContentIds[p.focus!.remoteId]
        : null;
    final isHighlight = p.link.kind == LinkKind.highlight;
    final kindText = switch (p.link.kind) {
      LinkKind.story => l10n.lnkKindStory,
      LinkKind.post => l10n.lnkKindPost,
      LinkKind.reel => l10n.lnkKindReel,
      LinkKind.highlight => l10n.lnkKindHighlight(p.items.length),
    };
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          StorizeSpacing.screenMargin,
          0,
          StorizeSpacing.screenMargin,
          StorizeSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.lnkSheetTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: StorizeSpacing.s16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: _Thumb(item: _shown),
                  ),
                ),
                const SizedBox(width: StorizeSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${p.user.username}',
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: StorizeSpacing.s4),
                      Text(
                        kindText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (isHighlight && (p.title ?? '').isNotEmpty)
                        Text(
                          p.title!,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_allSaved && _stage == _Stage.ready) ...[
                        const SizedBox(height: StorizeSpacing.s8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: StorizeSpacing.s4),
                            Text(
                              l10n.lnkAlreadySaved,
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: StorizeSpacing.s16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _stage == _Stage.failed
                        ? scheme.error
                        : scheme.onSurface,
                  ),
                ),
              ),
            ],
            const SizedBox(height: StorizeSpacing.s24),
            if (_stage == _Stage.saved) ...[
              if (_openContentId != null)
                PrimaryButton(
                  label: l10n.lnkOpen,
                  icon: Icons.open_in_new_rounded,
                  expand: true,
                  onPressed: () => _open(_openContentId!, _openKind!),
                ),
              StorizeTextButton(
                label: l10n.lnkDone,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else if (_allSaved) ...[
              if (savedId != null)
                PrimaryButton(
                  label: l10n.lnkOpen,
                  icon: Icons.open_in_new_rounded,
                  expand: true,
                  onPressed: () => _open(savedId, p.focus!.kind),
                ),
            ] else ...[
              PrimaryButton(
                label: p.focus != null
                    ? l10n.lnkSave
                    : l10n.lnkSaveAll(p.unsavedCount),
                icon: Icons.download_rounded,
                loading: saving,
                expand: true,
                onPressed: () => unawaited(_save(all: p.focus == null)),
              ),
              if (p.focus != null && p.unsavedCount > 1) ...[
                const SizedBox(height: StorizeSpacing.s8),
                StorizeTextButton(
                  label: l10n.lnkSaveAll(p.unsavedCount),
                  onPressed: saving ? null : () => unawaited(_save(all: true)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The save failure reason as a phrase for "Couldn't save: …".
String _reasonText(AppLocalizations l10n, String? reason) => switch (reason) {
  'busy' => l10n.prvReasonBusy,
  'storage_paused' => l10n.prvReasonStorage,
  'gallery_permission' => l10n.prvReasonPermission,
  'session' => l10n.prvReasonSession,
  _ => l10n.prvReasonGeneric,
};

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});

  final RemoteContent item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slide = item.slides.isEmpty ? null : item.slides.first;
    // The model has no poster URL for a video: only a photo has a picture.
    if (slide == null || slide.type == MediaType.video) {
      return ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: Center(
          child: Icon(
            Icons.play_circle_outline_rounded,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return PreviewImage(url: slide.url);
  }
}
