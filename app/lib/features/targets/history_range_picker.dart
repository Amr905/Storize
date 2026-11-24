import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

/// The label of a history range, without a date.
String historyRangeLabel(AppLocalizations l10n, HistoryRange r) => switch (r) {
  HistoryRange.none => l10n.tgtHistoryNone,
  HistoryRange.today => l10n.tgtHistoryToday,
  HistoryRange.days7 => l10n.tgtHistory7Days,
  HistoryRange.days30 => l10n.tgtHistory30Days,
  HistoryRange.since => l10n.tgtHistorySince,
  HistoryRange.all => l10n.tgtHistoryAll,
};

/// The post-history range picker shared by S-08 and S-09 (FR-68).
///
/// Shows None, Today, Last 7 days, Last 30 days, Since a date… and All. Picking
/// "Since a date…" opens a date picker; cancelling it keeps the old choice.
/// "All" shows a hint about the time it can take (TECH_SPEC 17.1).
class HistoryRangePicker extends StatelessWidget {
  /// Creates the picker.
  const HistoryRangePicker({
    required this.range,
    required this.onChanged,
    this.since,
    this.enabled = true,
    this.today,
    super.key,
  });

  /// The chosen range.
  final HistoryRange range;

  /// The chosen start date when [range] is [HistoryRange.since].
  final DateTime? since;

  /// Called with the new range and, for [HistoryRange.since], the date.
  final void Function(HistoryRange range, DateTime? since) onChanged;

  /// Whether the choices can be changed.
  final bool enabled;

  /// "Now" for the date picker bounds. Defaults to the device clock.
  final DateTime? today;

  static const List<HistoryRange> _presets = [
    HistoryRange.none,
    HistoryRange.today,
    HistoryRange.days7,
    HistoryRange.days30,
    HistoryRange.since,
    HistoryRange.all,
  ];

  Future<void> _pickDate(BuildContext context) async {
    final now = today ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: since ?? now,
      firstDate: DateTime(2005),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null || !context.mounted) return;
    onChanged(
      HistoryRange.since,
      DateTime(picked.year, picked.month, picked.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<HistoryRange>(
          groupValue: range,
          onChanged: !enabled
              ? (_) {}
              : (value) {
                  if (value == null) return;
                  if (value == HistoryRange.since) {
                    unawaited(_pickDate(context));
                  } else {
                    onChanged(value, null);
                  }
                },
          child: Column(
            children: [
              for (final r in _presets)
                RadioListTile<HistoryRange>(
                  key: ValueKey('history-${r.name}'),
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: StorizeSpacing.s8,
                    end: StorizeSpacing.s16,
                  ),
                  value: r,
                  title: Text(
                    historyRangeLabel(l10n, r),
                    style: textTheme.titleMedium,
                  ),
                  subtitle: r == HistoryRange.since && since != null
                      ? Text(
                          l10n.tgtHistorySinceDate(
                            DateFormat.yMMMd(locale).format(since!),
                          ),
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ),
        if (range == HistoryRange.all)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: StorizeSpacing.s16,
              end: StorizeSpacing.s16,
              bottom: StorizeSpacing.s8,
            ),
            child: Text(
              l10n.tgtHistoryAllHint,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
