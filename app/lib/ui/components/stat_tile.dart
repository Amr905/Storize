import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Value + label tile (S-09), e.g. "128" / "Saved".
class StatTile extends StatelessWidget {
  /// Creates a tile.
  const StatTile({required this.value, required this.label, super.key});

  /// Big value text.
  final String value;

  /// Caption under the value.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).statTileSemantics(label, value),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: StorizeRadii.cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(StorizeSpacing.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.headlineLarge),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
