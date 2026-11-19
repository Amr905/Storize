// QA (T-024a): independent WCAG 2.x check of the UD-1 primary colour change,
// using its own luminance maths (not Color.computeLuminance) and token-
// consistency checks for the primary-derived tokens.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

double _lin(int c) {
  final v = c / 255;
  return v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(int rgb) =>
    0.2126 * _lin((rgb >> 16) & 0xFF) +
    0.7152 * _lin((rgb >> 8) & 0xFF) +
    0.0722 * _lin(rgb & 0xFF);

double _ratio(int a, int b) {
  final la = _lum(a);
  final lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

void main() {
  const ember = Color(0xFFC93F17);
  const s = StorizeTheme.lightScheme;
  const c = StorizeColors.light;

  test('independent WCAG ratios for the new primary', () {
    expect(_ratio(0xFFFFFF, 0xC93F17), closeTo(4.99, 0.01));
    expect(_ratio(0xC93F17, 0xFBF8F5), closeTo(4.72, 0.01));
    expect(
      _ratio(_rgb(s.onPrimary), _rgb(s.primary)),
      greaterThanOrEqualTo(4.5),
    );
    expect(_ratio(_rgb(s.primary), _rgb(s.surface)), greaterThanOrEqualTo(4.5));
  });

  test('container pairs where text is involved still pass AA', () {
    expect(
      _ratio(_rgb(s.onPrimaryContainer), _rgb(s.primaryContainer)),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _ratio(_rgb(c.info.onContainer), _rgb(c.info.container)),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('primary-derived tokens agree (primary == secondary == info)', () {
    expect(s.primary, ember);
    expect(s.secondary, ember);
    expect(c.info.color, ember);
    expect(StorizeTheme.darkScheme.inversePrimary, ember);
    expect(s.onSecondary, s.onPrimary);
    expect(s.secondaryContainer, s.primaryContainer);
  });

  test('dark primary and light inversePrimary are unchanged', () {
    expect(StorizeTheme.darkScheme.primary, const Color(0xFFFF8A5C));
    expect(s.inversePrimary, const Color(0xFFFF8A5C));
  });

  test('dark inversePrimary on inverseSurface is no worse than before', () {
    const d = StorizeTheme.darkScheme;
    final now = _ratio(_rgb(d.inversePrimary), _rgb(d.inverseSurface));
    final before = _ratio(0xD9481F, _rgb(d.inverseSurface));
    expect(now, greaterThan(before));
    // Informational: 4.03 is still below 4.5 (SnackBar action text).
    expect(now, greaterThanOrEqualTo(3.0));
  });
}
