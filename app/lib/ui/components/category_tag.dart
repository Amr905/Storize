import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Why an account is tracked (UX §5.3).
enum CategoryKind { ownClient, consented, publicFigure }

/// Small rounded tag naming the target's category.
class CategoryTag extends StatelessWidget {
  /// Creates a tag. [label] overrides the built-in text.
  const CategoryTag({required this.kind, this.label, super.key});

  /// Category.
  final CategoryKind kind;

  /// Optional replacement text.
  final String? label;

  static String defaultLabel(AppLocalizations l10n, CategoryKind kind) =>
      switch (kind) {
        CategoryKind.ownClient => l10n.categoryOwn,
        CategoryKind.consented => l10n.categoryConsented,
        CategoryKind.publicFigure => l10n.categoryPublic,
      };

  @override
  Widget build(BuildContext context) {
    final c = StorizeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final tone = switch (kind) {
      CategoryKind.ownClient => c.tagOwn,
      CategoryKind.consented => c.tagConsented,
      CategoryKind.publicFigure => c.tagPublic,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.container,
        borderRadius: StorizeRadii.chipRadius,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s8,
          vertical: StorizeSpacing.s4,
        ),
        child: Text(
          label ?? defaultLabel(l10n, kind),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: tone.onContainer),
        ),
      ),
    );
  }
}
