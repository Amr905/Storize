import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/ui_state.dart';
import 'package:storize_app/core/ui_state_view.dart';
import 'package:storize_app/features/shared/session_banner_slot.dart';
import 'package:storize_app/features/targets/target_list_row.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// S-07: the tracked accounts, their health, and Check now.
class TargetsPage extends ConsumerWidget {
  /// Creates the page.
  const TargetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(targetsProvider);
    final sessionActive = ref.watch(targetsSessionActiveProvider);
    final checking = ref.watch(targetCheckRunningProvider);
    final rateLimited = ref.watch(targetsRateLimitedProvider);
    final ui = async.toUiState(
      isEmpty: (targets) => targets.isEmpty,
      retry: () => ref.invalidate(targetsProvider),
    );
    final count = async.value?.length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: count == null ? null : 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.screenTargets),
            if (count != null)
              Text(
                l10n.tgtCountLimit(count, TargetLimits.recommendedMax),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          _CheckNowButton(
            enabled: sessionActive && !checking,
            running: checking,
            onPressed: () => unawaited(_checkNow(context, ref)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        tooltip: l10n.tgtAddAccount,
        onPressed: () => unawaited(context.push(Routes.addTargetPath)),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.tgtAddShort),
      ),
      body: Column(
        children: [
          const SessionBannerSlot(),
          if (rateLimited) const _RateLimitBar(),
          Expanded(
            child: ui is UiContent<List<Target>>
                ? _TargetList(targets: ui.value, checking: checking)
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: UiStateView<List<Target>>(
                          state: ui,
                          emptyBuilder: (context, reason) => EmptyState(
                            icon: Icons.person_add_alt_1_rounded,
                            title: l10n.tgtEmptyTitle,
                            body: l10n.tgtEmptyBody,
                            actionLabel: l10n.tgtAddAccount,
                            onAction: () =>
                                unawaited(context.push(Routes.addTargetPath)),
                          ),
                          builder: (context, targets) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static Future<void> _checkNow(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(targetCheckRunningProvider.notifier)
        .checkAll();
    if (result == null || !context.mounted) return;
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
}

class _CheckNowButton extends StatelessWidget {
  const _CheckNowButton({
    required this.enabled,
    required this.running,
    required this.onPressed,
  });

  final bool enabled;
  final bool running;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final button = TextButton.icon(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        minimumSize: const Size(0, StorizeSpacing.minTouchTarget),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s20,
        ),
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
      icon: const Icon(Icons.sync_rounded, size: 22),
      label: Text(l10n.tgtCheckNow),
    );
    final sessionOk = enabled || running;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: StorizeSpacing.s16),
      child: sessionOk
          ? button
          : Tooltip(message: l10n.tgtCheckNowDisabled, child: button),
    );
  }
}

class _RateLimitBar extends StatelessWidget {
  const _RateLimitBar();

  @override
  Widget build(BuildContext context) {
    final tone = StorizeColors.of(context).warning;
    return ColoredBox(
      color: tone.container,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s16,
          vertical: StorizeSpacing.s8,
        ),
        child: Row(
          children: [
            Icon(Icons.speed_rounded, color: tone.color),
            const SizedBox(width: StorizeSpacing.s8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).tgtRateLimitBar,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: tone.onContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetList extends ConsumerWidget {
  const _TargetList({required this.targets, required this.checking});

  final List<Target> targets;
  final bool checking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedCountsProvider).value;
    return ListView.builder(
      padding: const EdgeInsetsDirectional.only(bottom: 88),
      itemCount: targets.length,
      itemBuilder: (context, i) {
        final target = targets[i];
        final paused = target.status == TargetStatus.paused;
        final pending = target.status == TargetStatus.pendingLookup;
        final l10n = AppLocalizations.of(context);
        return TargetListRow(
          username: target.username,
          category: _categoryKind(target.category),
          status: checking && target.status == TargetStatus.active
              ? StorizeStatus.checking
              : _status(target.status),
          statusLabel: pending ? l10n.tgtStatusPending : null,
          note: _note(context, target),
          checkedLine: _checkedLine(context, target, saved?[target.id]),
          onTap: () =>
              unawaited(context.push(Routes.targetDetailLocation(target.id))),
          swipeAction: pending
              ? null
              : TargetRowSwipeAction(
                  label: paused ? l10n.tgtActionResume : l10n.tgtActionPause,
                  icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  onTriggered: () => unawaited(
                    _setPaused(context, ref, target, paused: !paused),
                  ),
                ),
        );
      },
    );
  }

  static Future<void> _setPaused(
    BuildContext context,
    WidgetRef ref,
    Target target, {
    required bool paused,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(targetActionsProvider).setPaused(target, paused: paused);
    } on Object {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.tgtUpdateFailed)));
    }
  }

  static CategoryKind _categoryKind(TargetCategory c) => switch (c) {
    TargetCategory.ownClient => CategoryKind.ownClient,
    TargetCategory.consented => CategoryKind.consented,
    TargetCategory.public => CategoryKind.publicFigure,
  };

  static StorizeStatus _status(TargetStatus s) => switch (s) {
    TargetStatus.active => StorizeStatus.active,
    TargetStatus.pendingLookup => StorizeStatus.checking,
    TargetStatus.paused => StorizeStatus.paused,
    TargetStatus.notVisible => StorizeStatus.notVisible,
    TargetStatus.unavailable => StorizeStatus.unavailable,
    TargetStatus.error => StorizeStatus.error,
  };

  static String _time(BuildContext context, DateTime at) =>
      MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(at.toLocal()));

  /// The text beside the category tag (mockup S-07).
  static String? _note(BuildContext context, Target target) {
    final l10n = AppLocalizations.of(context);
    switch (target.status) {
      case TargetStatus.paused:
        return l10n.tgtMetaPausedByYou;
      case TargetStatus.notVisible:
        return l10n.tgtMetaPrivate;
      case TargetStatus.unavailable:
        return l10n.tgtMetaGone;
      case TargetStatus.pendingLookup:
        return null;
      case TargetStatus.active:
      case TargetStatus.error:
        final newAt = target.lastNewStoryAt;
        return newAt == null
            ? null
            : l10n.tgtMetaLastNew(_time(context, newAt));
    }
  }

  /// "Checked 10:42 · 128 saved".
  static String? _checkedLine(BuildContext context, Target target, int? saved) {
    final l10n = AppLocalizations.of(context);
    final checked = target.lastStoriesCheckAt;
    final parts = <String>[
      if (checked != null)
        l10n.tgtMetaChecked(_time(context, checked))
      else if (target.status != TargetStatus.paused)
        l10n.tgtMetaNever,
      if (saved != null) l10n.tgtMetaSaved(saved),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
