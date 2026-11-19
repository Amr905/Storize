import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/components/buttons.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Centered icon + title + body + optional primary action, for empty lists
/// and error screens (S-00).
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Illustration icon.
  final IconData icon;

  /// Title.
  final String title;

  /// Body.
  final String body;

  /// Primary action text.
  final String? actionLabel;

  /// Primary action.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(StorizeSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 40, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: StorizeSpacing.s12),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: StorizeSpacing.s8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: StorizeSpacing.s24),
              PrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
