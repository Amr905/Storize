import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Health states shown by [StatusBadge] (UX §5.3).
enum StorizeStatus {
  active,
  checking,
  paused,
  notVisible,
  unavailable,
  error,
  needsRelogin,
  restricted,
}

/// A pill (surface-container-high, ink text) with an icon and a label.
/// Status is never shown by colour alone: every variant has its own icon
/// and text.
class StatusBadge extends StatelessWidget {
  /// Creates a badge. [label] overrides the built-in text.
  const StatusBadge({required this.status, this.label, super.key});

  /// Which state to show.
  final StorizeStatus status;

  /// Optional replacement text.
  final String? label;

  static String defaultLabel(AppLocalizations l10n, StorizeStatus status) =>
      switch (status) {
        StorizeStatus.active => l10n.statusActive,
        StorizeStatus.checking => l10n.statusChecking,
        StorizeStatus.paused => l10n.statusPaused,
        StorizeStatus.notVisible => l10n.statusNotVisible,
        StorizeStatus.unavailable => l10n.statusUnavailable,
        StorizeStatus.error => l10n.statusError,
        StorizeStatus.needsRelogin => l10n.statusNeedsRelogin,
        StorizeStatus.restricted => l10n.statusRestricted,
      };

  static IconData iconFor(StorizeStatus status) => switch (status) {
    StorizeStatus.active => Icons.check_circle_rounded,
    StorizeStatus.checking => Icons.sync_rounded,
    StorizeStatus.paused => Icons.pause_circle_rounded,
    StorizeStatus.notVisible => Icons.visibility_off_rounded,
    StorizeStatus.unavailable => Icons.person_off_rounded,
    StorizeStatus.error => Icons.error_rounded,
    StorizeStatus.needsRelogin => Icons.warning_amber_rounded,
    StorizeStatus.restricted => Icons.report_rounded,
  };

  static StorizeTone toneFor(StorizeColors c, StorizeStatus status) =>
      switch (status) {
        StorizeStatus.active => c.success,
        StorizeStatus.checking => c.info,
        StorizeStatus.paused ||
        StorizeStatus.notVisible ||
        StorizeStatus.unavailable => c.neutralStatus,
        StorizeStatus.needsRelogin => c.warning,
        StorizeStatus.error || StorizeStatus.restricted => c.error,
      };

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(StorizeColors.of(context), status);
    final text = label ?? defaultLabel(AppLocalizations.of(context), status);
    return Semantics(
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: StorizeRadii.fullRadius,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              StorizeSpacing.s8,
              StorizeSpacing.s4,
              StorizeSpacing.s12,
              StorizeSpacing.s4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconFor(status), size: 14, color: tone.color),
                const SizedBox(width: StorizeSpacing.s4),
                Flexible(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
