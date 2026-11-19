import 'package:material_ui/material_ui.dart';

/// Circular avatar showing [initial]. Pass real photos via [child] instead.
class StorizeAvatar extends StatelessWidget {
  /// Creates an avatar.
  const StorizeAvatar({this.initial, this.child, this.size = 40, super.key});

  /// Letter shown when [child] is null.
  final String? initial;

  /// Custom content (e.g. a cached image); clipped to a circle.
  final Widget? child;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: ColoredBox(
            color: scheme.primaryContainer,
            child: Center(
              child:
                  child ??
                  Text(
                    (initial ?? '').toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
