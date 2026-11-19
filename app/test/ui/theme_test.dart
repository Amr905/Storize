import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

void main() {
  group('colour tokens (UX 5.2)', () {
    test('light scheme', () {
      final s = StorizeTheme.light().colorScheme;
      expect(s.primary, const Color(0xFFD9481F));
      expect(s.onPrimary, const Color(0xFFFFFFFF));
      expect(s.primaryContainer, const Color(0xFFFFE3D8));
      expect(s.surface, const Color(0xFFFBF8F5));
      expect(s.surfaceContainer, const Color(0xFFF1ECE7));
      expect(s.onSurface, const Color(0xFF1C1A18));
      expect(s.onSurfaceVariant, const Color(0xFF6B635C));
      expect(s.outline, const Color(0xFFD8D0C8));
      expect(s.error, const Color(0xFFC62828));
      const x = StorizeColors.light;
      expect(x.success.color, const Color(0xFF1F7A4D));
      expect(x.warning.color, const Color(0xFFB26A00));
      expect(x.error.color, const Color(0xFFC62828));
      expect(x.neutralStatus.color, const Color(0xFF8A847E));
    });

    test('dark scheme', () {
      final s = StorizeTheme.dark().colorScheme;
      expect(s.primary, const Color(0xFFFF8A5C));
      expect(s.onPrimary, const Color(0xFF3A0E00));
      expect(s.primaryContainer, const Color(0xFF5A1D07));
      expect(s.surface, const Color(0xFF121214));
      expect(s.surfaceContainer, const Color(0xFF1E1E21));
      expect(s.onSurface, const Color(0xFFECE6E1));
      expect(s.onSurfaceVariant, const Color(0xFFA69E97));
      expect(s.outline, const Color(0xFF3A3836));
      expect(s.error, const Color(0xFFFF8A80));
      const x = StorizeColors.dark;
      expect(x.success.color, const Color(0xFF5BD69A));
      expect(x.warning.color, const Color(0xFFFFB74D));
      expect(x.neutralStatus.color, const Color(0xFF8A847E));
    });

    test('themes carry the StorizeColors extension', () {
      expect(StorizeTheme.light().extension<StorizeColors>(), isNotNull);
      expect(StorizeTheme.dark().extension<StorizeColors>(), isNotNull);
      final mid = StorizeColors.light.lerp(StorizeColors.dark, 0.5);
      expect(mid.success.color, isNot(StorizeColors.light.success.color));
    });
  });

  test('type scale (UX 5.2)', () {
    final t = StorizeTheme.light().textTheme;
    void check(TextStyle? s, double size, double line, FontWeight w) {
      expect(s!.fontSize, size);
      expect(s.height! * s.fontSize!, closeTo(line, 0.001));
      expect(s.fontWeight, w);
    }

    check(t.displaySmall, 28, 36, FontWeight.w500);
    check(t.titleLarge, 20, 28, FontWeight.w500);
    check(t.bodyLarge, 15, 22, FontWeight.w400);
    check(t.labelLarge, 13, 18, FontWeight.w500);
    check(t.bodySmall, 12, 16, FontWeight.w400);
  });

  test('spacing and shapes', () {
    expect(StorizeRadii.card, 16);
    expect(StorizeRadii.chip, 8);
    expect(StorizeRadii.thumb, 10);
    expect(StorizeRadii.sheet, 24);
    expect(StorizeSpacing.screenMargin, 16);
    for (final s in [
      StorizeSpacing.s4,
      StorizeSpacing.s8,
      StorizeSpacing.s12,
      StorizeSpacing.s16,
      StorizeSpacing.s24,
      StorizeSpacing.s32,
      StorizeSpacing.s48,
    ]) {
      expect(s % 4, 0);
    }
  });
}
