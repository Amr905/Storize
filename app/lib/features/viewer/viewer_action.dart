import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

/// Stacked icon-over-label action used in the viewer action bars.
class ViewerAction extends StatelessWidget {
  /// Creates the action.
  const ViewerAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  /// Leading icon.
  final IconData icon;

  /// Label text.
  final String label;

  /// Icon and label colour.
  final Color color;

  /// Tap handler; null disables.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, StorizeSpacing.minTouchTarget),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: StorizeSpacing.s4),
            Text(label),
          ],
        ),
      ),
    );
  }
}
