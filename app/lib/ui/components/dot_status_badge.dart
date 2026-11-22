import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/components/status_badge.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Pill with a coloured dot and a text label (design mockups S-07, S-12,
/// S-13). Same states and colours as [StatusBadge]; the text still carries
/// the meaning, so status is never colour alone.
class DotStatusBadge extends StatelessWidget {
  /// Creates a badge. [label] overrides the built-in text.
  const DotStatusBadge({required this.status, this.label, super.key});

  /// Which state to show.
  final StorizeStatus status;

  /// Optional replacement text.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tone = StatusBadge.toneFor(StorizeColors.of(context), status);
    final text =
        label ?? StatusBadge.defaultLabel(AppLocalizations.of(context), status);
    return Semantics(
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tone.container,
            borderRadius: StorizeRadii.fullRadius,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StorizeSpacing.s12,
              vertical: StorizeSpacing.s4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tone.color,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 8),
                ),
                const SizedBox(width: StorizeSpacing.s8),
                Flexible(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: tone.onContainer),
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
