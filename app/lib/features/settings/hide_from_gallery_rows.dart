import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// The "Hide from phone gallery" switch of S-12 (FR-79), its App lock tip and
/// the progress of moving the saved files.
///
/// Turning the switch changes where new downloads go at once. When saved files
/// are not yet where the switch says, a dialog offers to move them now
/// ("Move N saved files now?"). Moving never loses a file (copy, verify, then
/// remove the original), so it is safe to stop or to close the app.
class HideFromGalleryRows extends ConsumerWidget {
  /// Creates the rows for [settings].
  const HideFromGalleryRows({required this.settings, super.key});

  /// The current settings.
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow.toggle(
          title: l10n.setHideFromGallery,
          subtitle: l10n.setHideFromGalleryHint,
          leadingIcon: Icons.visibility_off_outlined,
          switchValue: settings.hideFromGallery,
          onChanged: (on) => unawaited(_toggle(context, ref, on: on)),
        ),
        if (settings.hideFromGallery && !settings.appLockEnabled)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: StorizeSpacing.s16,
              end: StorizeSpacing.s16,
              bottom: StorizeSpacing.s8,
            ),
            child: Text(
              l10n.setHideLockTip,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const _MoveProgressRow(),
      ],
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required bool on,
  }) async {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(settingsActionsProvider);
    final count = await actions.setHideFromGallery(on: on);
    if (count == 0 || !context.mounted) return;
    final move = await ConfirmDialog.show(
      context,
      title: on ? l10n.hideMoveHideTitle(count) : l10n.hideMoveShowTitle(count),
      body: on ? l10n.hideMoveHideBody : l10n.hideMoveShowBody,
      confirmLabel: l10n.hideMoveAction,
      cancelLabel: l10n.hideMoveOnlyNew,
    );
    if (!move) return;
    await actions.startMove(
      on ? StorageTarget.private : StorageTarget.gallery,
      total: count,
    );
  }
}

/// The progress, stopped or finished state of the move.
class _MoveProgressRow extends ConsumerWidget {
  const _MoveProgressRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(moveProgressProvider).value;
    if (progress == null || progress.status == MoveStatus.idle) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final actions = ref.read(settingsActionsProvider);
    final stale = progress.isStale(ref.read(clockProvider).now());
    final running = progress.status == MoveStatus.running && !stale;
    final target = progress.target;

    final message = switch (progress.status) {
      MoveStatus.running when !stale => l10n.hideMoveProgress(
        progress.handled,
        progress.total,
      ),
      MoveStatus.running => l10n.hideMoveInterrupted(
        progress.moved,
        progress.total,
      ),
      MoveStatus.cancelled => l10n.hideMoveCancelled(
        progress.moved,
        progress.total,
      ),
      MoveStatus.storageFull => l10n.hideMoveStorageFull(
        progress.moved,
        progress.total,
      ),
      MoveStatus.done || MoveStatus.idle => l10n.hideMoveDone(progress.moved),
    };
    final canResume =
        target != null &&
        !running &&
        (progress.status != MoveStatus.done || progress.failed > 0);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StorizeSpacing.s16,
        vertical: StorizeSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (running)
            LinearProgressIndicator(
              value: progress.total > 0
                  ? (progress.handled / progress.total).clamp(0.0, 1.0)
                  : null,
            ),
          const SizedBox(height: StorizeSpacing.s8),
          Text(message, style: theme.textTheme.bodyMedium),
          if (progress.status == MoveStatus.done && progress.missing > 0)
            Text(
              l10n.hideMoveMissing(progress.missing),
              style: theme.textTheme.bodySmall,
            ),
          if (!running && progress.failed > 0)
            Text(
              l10n.hideMoveFailed(progress.failed),
              style: theme.textTheme.bodySmall,
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: StorizeSpacing.s8,
              children: [
                if (running)
                  StorizeTextButton(
                    label: l10n.hideMoveCancel,
                    onPressed: () => unawaited(actions.cancelMove()),
                  )
                else ...[
                  if (canResume)
                    StorizeTextButton(
                      label: l10n.hideMoveResume,
                      onPressed: () => unawaited(
                        actions.startMove(
                          target,
                          total: progress.total - progress.moved,
                        ),
                      ),
                    ),
                  StorizeTextButton(
                    label: l10n.hideMoveDismiss,
                    onPressed: () => unawaited(actions.dismissMove()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
