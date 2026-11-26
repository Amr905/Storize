import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';

/// S-12 Appearance: a System / Light / Dark segmented control and its hint.
/// Picking a segment saves the setting; the app theme follows live.
class AppearanceControl extends ConsumerWidget {
  /// Creates the control.
  const AppearanceControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current =
        ref.watch(settingsStreamProvider).value?.themeMode ??
        AppThemeMode.system;
    final segments = <(AppThemeMode, IconData, String)>[
      (AppThemeMode.system, Icons.smartphone_rounded, l10n.setThemeSystem),
      (AppThemeMode.light, Icons.light_mode_rounded, l10n.setThemeLight),
      (AppThemeMode.dark, Icons.dark_mode_rounded, l10n.setThemeDark),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: StorizeSpacing.s12,
          ),
          child: Semantics(
            container: true,
            label: l10n.setThemeSemantics,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: StorizeRadii.fullRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    for (final (i, seg) in segments.indexed) ...[
                      if (i > 0) const SizedBox(width: StorizeSpacing.s4),
                      Expanded(
                        child: _Segment(
                          key: ValueKey('appearance-${seg.$1.name}'),
                          icon: seg.$2,
                          label: seg.$3,
                          selected: seg.$1 == current,
                          onTap: () => unawaited(
                            ref
                                .read(settingsActionsProvider)
                                .setThemeMode(seg.$1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            StorizeSpacing.s20,
            6,
            StorizeSpacing.s20,
            0,
          ),
          child: Text(
            l10n.setThemeHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: StorizeMotion.standard,
          curve: StorizeMotion.curve,
          constraints: const BoxConstraints(
            minHeight: StorizeSpacing.minTouchTarget - 4,
          ),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: StorizeRadii.fullRadius,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: StorizeSpacing.s8,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
