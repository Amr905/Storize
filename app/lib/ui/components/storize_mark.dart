import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The Storize logo mark (`brand/storize-mark.svg`): an ember rounded square
/// holding a three-part story ring with a save arrow dropping through the gap
/// at the bottom. Drawn with a [CustomPainter] so no SVG dependency is needed.
///
/// [dark] picks `storize-mark-dark.svg`; null follows the theme brightness.
/// The logo is decorative: it is excluded from semantics, and screens add
/// their own label where one is needed.
class StorizeMark extends StatelessWidget {
  /// Creates the mark at [size] dp.
  const StorizeMark({this.dark, this.size = 72, super.key});

  /// Use the dark-ground variant. Null follows the theme.
  final bool? dark;

  /// Edge length in dp.
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _MarkPainter(dark: isDark)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.dark});

  final bool dark;

  // Logo colours are fixed brand assets, not theme roles.
  static const _lightField = Color(0xFFC93F17);
  static const _lightRing = Color(0xFFFFE3D8);
  static const _lightArrow = Color(0xFFFFFFFF);
  static const _darkField = Color(0xFFFF8A5C);
  static const _darkRing = Color(0xFF5A1D07);
  static const _darkArrow = Color(0xFF3A0E00);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 96;
    canvas.scale(k);
    final field = Paint()..color = dark ? _darkField : _lightField;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 96, 96),
        const Radius.circular(24),
      ),
      field,
    );
    // Ring: dash 50.65 / gap 8 on a circle of radius 28, starting 4 units into
    // a gap at 6 o'clock so the opening is centred under the arrow.
    const radius = 28.0;
    const dash = 50.65;
    const period = dash + 8;
    final ring = Paint()
      ..color = dark ? _darkRing : _lightRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const bounds = Rect.fromLTWH(
      48 - radius,
      48 - radius,
      2 * radius,
      2 * radius,
    );
    for (var i = 0; i < 3; i++) {
      final start = math.pi / 2 + (4 + i * period) / radius;
      canvas.drawArc(bounds, start, dash / radius, false, ring);
    }
    final arrow = Paint()
      ..color = dark ? _darkArrow : _lightArrow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawLine(const Offset(48, 32), const Offset(48, 58), arrow)
      ..drawPath(
        Path()
          ..moveTo(37, 49)
          ..lineTo(48, 60)
          ..lineTo(59, 49),
        arrow,
      );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.dark != dark;
}
