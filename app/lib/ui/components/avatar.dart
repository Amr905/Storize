import 'package:material_ui/material_ui.dart';

/// Circular avatar showing [initial] on a warm gradient picked from the
/// initial. Pass real photos via [child] instead.
class StorizeAvatar extends StatelessWidget {
  /// Creates an avatar.
  const StorizeAvatar({this.initial, this.child, this.size = 40, super.key});

  /// Letter shown when [child] is null.
  final String? initial;

  /// Custom content (e.g. a cached image); clipped to a circle.
  final Widget? child;

  /// Diameter.
  final double size;

  static const List<List<Color>> _gradients = [
    [Color(0xFFF59E72), Color(0xFFC9481C)],
    [Color(0xFF8FA8F0), Color(0xFF4150B8)],
    [Color(0xFF6FC79B), Color(0xFF247F52)],
    [Color(0xFFD97FC0), Color(0xFF933B86)],
    [Color(0xFFE8B84E), Color(0xFFA8680C)],
    [Color(0xFF6DB6D6), Color(0xFF28708F)],
  ];

  @override
  Widget build(BuildContext context) {
    final text = (initial ?? '').toUpperCase();
    final pair = _gradients[text.isEmpty ? 0 : text.codeUnitAt(0) % 6];
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: pair,
              ),
            ),
            child: Center(
              child:
                  child ??
                  Text(
                    text,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontSize: size * 0.42,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
