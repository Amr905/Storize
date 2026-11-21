import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/settings/settings_format.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';

/// Opens the interval picker. Resolves to the chosen minutes, or null when
/// the sheet is dismissed. [oneHourHint] adds the ban-risk hint to the 1 h
/// option (post interval).
Future<int?> showIntervalSheet(
  BuildContext context, {
  required String title,
  required Set<int> options,
  required int current,
  bool oneHourHint = false,
}) => showModalBottomSheet<int>(
  context: context,
  showDragHandle: true,
  builder: (_) => _IntervalSheet(
    title: title,
    options: options,
    current: current,
    oneHourHint: oneHourHint,
  ),
);

class _IntervalSheet extends StatelessWidget {
  const _IntervalSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.oneHourHint,
  });

  final String title;
  final Set<int> options;
  final int current;
  final bool oneHourHint;

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
              StorizeSpacing.s16,
              0,
              StorizeSpacing.s16,
              StorizeSpacing.s8,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          RadioGroup<int>(
            groupValue: current,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              children: [
                for (final minutes in options)
                  RadioListTile<int>(
                    value: minutes,
                    title: Text(intervalLabel(l10n, minutes)),
                    subtitle: oneHourHint && minutes == 60
                        ? Text(l10n.setPostOneHourWarning)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Keep downloads" sheet: Forever, or After N days (1 to 3650). Saving
/// N days first shows the confirmation with the preview (FR-54).
class RetentionSheet extends ConsumerStatefulWidget {
  /// Creates the sheet. [current] is the stored number of days, or null for
  /// Forever.
  const RetentionSheet({this.current, super.key});

  /// The stored retention, or null when keeping forever.
  final int? current;

  @override
  ConsumerState<RetentionSheet> createState() => _RetentionSheetState();
}

class _RetentionSheetState extends ConsumerState<RetentionSheet> {
  late bool _forever = widget.current == null;
  late final TextEditingController _days = TextEditingController(
    text: widget.current?.toString() ?? '',
  );

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  int? get _parsedDays => parseRetentionDays(_days.text);

  bool get _canSave => _forever || _parsedDays != null;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final actions = ref.read(settingsActionsProvider);
    if (_forever) {
      await actions.keepForever();
      if (mounted) navigator.pop();
      return;
    }
    final days = _parsedDays;
    if (days == null) return;
    final preview = await ref.read(retentionPreviewProvider(days).future);
    if (!mounted) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.setRetentionConfirmTitle,
      body: l10n.setRetentionConfirmBody(
        days,
        preview.items,
        formatBytes(l10n, preview.bytes),
      ),
      confirmLabel: l10n.setRetentionConfirm,
      cancelLabel: l10n.setCancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await actions.keepAfterDays(days);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showError = !_forever && _days.text.isNotEmpty && _parsedDays == null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                StorizeSpacing.s16,
                0,
                StorizeSpacing.s16,
                StorizeSpacing.s8,
              ),
              child: Text(
                l10n.setKeepDownloads,
                style: theme.textTheme.titleMedium,
              ),
            ),
            RadioGroup<bool>(
              groupValue: _forever,
              onChanged: (value) => setState(() => _forever = value ?? true),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    title: Text(l10n.setKeepForever),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    title: Text(l10n.setRetentionAfter),
                  ),
                ],
              ),
            ),
            if (!_forever)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  StorizeSpacing.s16,
                  0,
                  StorizeSpacing.s16,
                  StorizeSpacing.s8,
                ),
                child: TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.setRetentionDaysLabel,
                    errorText: showError ? l10n.setRetentionDaysError : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                StorizeSpacing.s16,
                0,
                StorizeSpacing.s16,
                StorizeSpacing.s16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  StorizeTextButton(
                    label: l10n.setCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: StorizeSpacing.s8),
                  PrimaryButton(
                    label: l10n.setSave,
                    onPressed: _canSave ? () => unawaited(_save()) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The per-account storage list, largest first (FR-53).
class StorageSheet extends ConsumerWidget {
  /// Creates the sheet.
  const StorageSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final storage = ref.watch(settingsStorageProvider);
    final targets = ref.watch(settingsTargetsProvider).value ?? const [];
    final bytesByTarget = storage.value?.bytesByTarget ?? const <int, int>{};
    final rows = [
      for (final t in targets)
        if ((bytesByTarget[t.id] ?? 0) > 0) t,
    ]..sort((a, b) => bytesByTarget[b.id]!.compareTo(bytesByTarget[a.id]!));

    const edge = EdgeInsetsDirectional.symmetric(
      horizontal: StorizeSpacing.s16,
    );
    final Widget body;
    if (storage.hasError) {
      body = Padding(padding: edge, child: Text(l10n.setStorageUnknown));
    } else if (!storage.hasValue) {
      body = Padding(padding: edge, child: Text(l10n.setStorageCalculating));
    } else if (rows.isEmpty) {
      body = Padding(padding: edge, child: Text(l10n.setStorageNone));
    } else {
      body = Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: edge,
          children: [
            for (final t in rows)
              ListTile(
                title: Text(l10n.actAccountHandle(t.username)),
                trailing: Text(formatBytes(l10n, bytesByTarget[t.id]!)),
              ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              StorizeSpacing.s16,
              0,
              StorizeSpacing.s16,
              StorizeSpacing.s8,
            ),
            child: Text(
              l10n.setStorageByAccount,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          body,
          const SizedBox(height: StorizeSpacing.s16),
        ],
      ),
    );
  }
}
