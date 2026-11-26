import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/history_range_picker.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The S-09 "Post history" block: range, progress, Pause/Resume/Cancel, and
/// the Highlights switch (FR-68 to FR-72, TECH_SPEC 17.3).
class TargetHistorySection extends ConsumerWidget {
  /// Creates the section for [target].
  const TargetHistorySection({required this.target, super.key});

  /// The target the section edits.
  final Target target;

  Future<void> _changeRange(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          final l10n = AppLocalizations.of(sheetContext);
          return Padding(
            padding: const EdgeInsetsDirectional.only(
              start: StorizeSpacing.screenMargin,
              end: StorizeSpacing.screenMargin,
              bottom: StorizeSpacing.s24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.tdtHistoryTitle,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StorizeSpacing.s8),
                  HistoryRangePicker(
                    range: target.historyRange,
                    since: target.historySince,
                    onChanged: (range, since) {
                      Navigator.of(sheetContext).pop();
                      unawaited(
                        ref
                            .read(targetHistoryActionsProvider)
                            .setRange(target.id, range, since: since),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final progress = target.historyProgress;
    final range = target.historyRange;
    final hasRange = range != HistoryRange.none;
    final state = progress?.state ?? HistoryState.idle;
    final actions = ref.read(targetHistoryActionsProvider);

    final statusText = switch (state) {
      HistoryState.running when progress != null =>
        progress.oldestSeenAt == null
            ? l10n.tdtHistoryRunningNoDate(progress.fetched)
            : l10n.tdtHistoryRunning(
                progress.fetched,
                DateFormat.yMMMd(locale)
                    .format(progress.oldestSeenAt!.toLocal()),
              ),
      HistoryState.paused => l10n.tdtHistoryPaused,
      HistoryState.done => l10n.tdtHistoryDone,
      HistoryState.failed => l10n.tdtHistoryFailed,
      _ => null,
    };

    // A Material, not a DecoratedBox: the Highlights switch tile paints its
    // ink on the nearest Material.
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: StorizeRadii.cardRadius,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s16,
          vertical: StorizeSpacing.s12,
        ),
        child: _content(
          context,
          ref,
          l10n: l10n,
          scheme: scheme,
          textTheme: textTheme,
          locale: locale,
          state: state,
          hasRange: hasRange,
          range: range,
          statusText: statusText,
          actions: actions,
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref, {
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required String locale,
    required HistoryState state,
    required bool hasRange,
    required HistoryRange range,
    required String? statusText,
    required TargetHistoryActions actions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.tdtHistoryTitle, style: textTheme.titleMedium),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tdtHistoryRange(
                  range == HistoryRange.since && target.historySince != null
                      ? l10n.tgtHistorySinceDate(
                          DateFormat.yMMMd(locale)
                              .format(target.historySince!.toLocal()),
                        )
                      : historyRangeLabel(l10n, range),
                ),
                style: textTheme.bodyLarge,
              ),
            ),
            TextButton(
              onPressed: () => unawaited(_changeRange(context, ref)),
              child: Text(l10n.tdtHistoryChange),
            ),
          ],
        ),
        if (statusText != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: StorizeSpacing.s8,
            ),
            child: Text(
              statusText,
              style: textTheme.bodyMedium?.copyWith(
                color: state == HistoryState.failed
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        // The mockup bar needs a known total, which the history job does not
        // have, and an indeterminate bar would animate forever. So the bar only
        // marks a finished history.
        if (hasRange && state == HistoryState.done)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: StorizeSpacing.s12,
            ),
            child: ClipRRect(
              borderRadius: StorizeRadii.fullRadius,
              child: LinearProgressIndicator(
                key: const ValueKey('history-progress-bar'),
                minHeight: 6,
                value: 1,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
            ),
          ),
        if (hasRange &&
            (state == HistoryState.running ||
                state == HistoryState.paused ||
                state == HistoryState.failed))
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => unawaited(
                    state == HistoryState.running
                        ? actions.pause(target.id)
                        : actions.resume(target.id),
                  ),
                  child: Text(
                    state == HistoryState.running
                        ? l10n.tdtHistoryPause
                        : l10n.tdtHistoryResume,
                  ),
                ),
              ),
              const SizedBox(width: StorizeSpacing.s16),
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => unawaited(actions.cancel(target.id)),
                  child: Text(l10n.tdtHistoryCancel),
                ),
              ),
            ],
          ),
        SwitchListTile(
          contentPadding: const EdgeInsetsDirectional.only(
            start: StorizeSpacing.s8,
            end: StorizeSpacing.s8,
          ),
          title: Text(l10n.tdtHighlightsLabel),
          subtitle: Text(l10n.tdtHighlightsHint),
          value: target.highlightsEnabled,
          onChanged: (on) =>
              unawaited(actions.setHighlights(target.id, on: on)),
        ),
      ],
    );
  }
}
