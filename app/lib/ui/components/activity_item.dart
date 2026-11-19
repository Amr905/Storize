import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/theme/theme.dart';

/// Tone of an [ActivityItem] icon.
enum ActivityTone { neutral, info, success, warning, error }

/// One entry of the activity feed (S-11).
class ActivityItem extends StatelessWidget {
  /// Creates an item.
  const ActivityItem({
    required this.icon,
    required this.tone,
    required this.time,
    required this.text,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Type icon.
  final IconData icon;

  /// Tone of the icon container.
  final ActivityTone tone;

  /// Pre-formatted time, e.g. "10:15".
  final String time;

  /// Description.
  final String text;

  /// Optional action text (e.g. "Fix", "Retry").
  final String? actionLabel;

  /// Action tapped.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = StorizeColors.of(context);
    final t = switch (tone) {
      ActivityTone.neutral => c.neutralStatus,
      ActivityTone.info => c.info,
      ActivityTone.success => c.success,
      ActivityTone.warning => c.warning,
      ActivityTone.error => c.error,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: StorizeSpacing.minRowHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s16,
          vertical: StorizeSpacing.s8,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.container,
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, size: 20, color: t.onContainer),
                ),
              ),
            ),
            const SizedBox(width: StorizeSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: theme.textTheme.bodyLarge),
                  Text(
                    time,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
