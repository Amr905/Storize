import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/target_detail_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// S-10: stop tracking a target. "Keep downloads" is the default and the safe
/// choice; "Delete downloads too" removes the gallery files first (BR-6).
class RemoveTargetDialog extends ConsumerStatefulWidget {
  /// Creates the dialog for [target].
  const RemoveTargetDialog({
    required this.target,
    required this.storyCount,
    required this.postCount,
    super.key,
  });

  /// The target to remove.
  final Target target;

  /// Stories saved for the target, for the counts line.
  final int storyCount;

  /// Posts saved for the target, for the counts line.
  final int postCount;

  /// Shows the dialog. Resolves to true only when the target is removed.
  static Future<bool> show(
    BuildContext context, {
    required Target target,
    required int storyCount,
    required int postCount,
  }) async {
    final removed = await showDialog<bool>(
      context: context,
      builder: (_) => RemoveTargetDialog(
        target: target,
        storyCount: storyCount,
        postCount: postCount,
      ),
    );
    return removed ?? false;
  }

  @override
  ConsumerState<RemoveTargetDialog> createState() => _RemoveTargetDialogState();
}

enum _Failure { partial, failed }

class _RemoveTargetDialogState extends ConsumerState<RemoveTargetDialog> {
  bool _deleteMedia = false;
  bool _running = false;
  _Failure? _failure;

  Future<void> _remove() async {
    if (_running) return;
    setState(() {
      _running = true;
      _failure = null;
    });
    try {
      final result = await ref
          .read(removeTargetUseCaseProvider)
          .call(widget.target.id, deleteMedia: _deleteMedia);
      if (!mounted) return;
      if (result.isComplete) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _running = false;
        _failure = _Failure.partial;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _running = false;
        _failure = _Failure.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failure = _failure;
    return AlertDialog(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
      ),
      title: Text(l10n.tdtRemoveTitle('@${widget.target.username}')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tdtRemoveCounts(widget.storyCount, widget.postCount),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: StorizeSpacing.s16),
          RadioGroup<bool>(
            groupValue: _deleteMedia,
            onChanged: _running
                ? (_) {}
                : (value) {
                    if (value != null) setState(() => _deleteMedia = value);
                  },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  isThreeLine: false,
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  title: Text(l10n.tdtRemoveKeep),
                  subtitle: Text(
                    l10n.tdtRemoveKeepHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                RadioListTile<bool>(
                  isThreeLine: false,
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  title: Text(l10n.tdtRemoveDelete),
                  subtitle: Text(
                    l10n.tdtRemoveDeleteHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (failure != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: StorizeSpacing.s8),
              child: Text(
                failure == _Failure.partial
                    ? l10n.tdtRemovePartial
                    : l10n.tdtRemoveFailed,
                style: TextStyle(color: scheme.error),
              ),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        StorizeTextButton(
          label: l10n.libCancel,
          onPressed: _running ? null : () => Navigator.of(context).pop(false),
        ),
        PrimaryButton(
          label: _deleteMedia ? l10n.tdtRemoveConfirmDelete : l10n.tdtRemove,
          destructive: _deleteMedia,
          loading: _running,
          onPressed: _running ? null : () => unawaited(_remove()),
        ),
      ],
    );
  }
}
