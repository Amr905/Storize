import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

void main() {
  group('colour tokens (UX 5.2)', () {
    test('light scheme', () {
      final s = StorizeTheme.light().colorScheme;
      expect(s.primary, const Color(0xFFC93F17));
      expect(s.onPrimary, const Color(0xFFFFFFFF));
      expect(s.primaryContainer, const Color(0xFFFFE3D8));
      expect(s.surface, const Color(0xFFFBF8F5));
      expect(s.surfaceContainer, const Color(0xFFF1ECE7));
      expect(s.onSurface, const Color(0xFF1C1A18));
      expect(s.onSurfaceVariant, const Color(0xFF6B635C));
      // outline = token outline-strong, outlineVariant = token outline.
      expect(s.outline, const Color(0xFF8F867E));
      expect(s.outlineVariant, const Color(0xFFD8D0C8));
      expect(s.error, const Color(0xFFC62828));
      const x = StorizeColors.light;
      expect(x.success.color, const Color(0xFF1F7A4D));
      // T-038: darkened from B26A00 to reach 4.5:1 on surfaces (contrast).
      expect(x.warning.color, const Color(0xFF955A00));
      expect(x.error.color, const Color(0xFFC62828));
      expect(x.neutralStatus.color, const Color(0xFF6F6963));
      expect(x.accent.color, const Color(0xFF8A5200));
      expect(x.accent.container, const Color(0xFFFFF0D6));
      expect(x.brandPressed, const Color(0xFFA8320F));
      expect(s.surfaceContainerHigh, const Color(0xFFE8E1DA));
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
      expect(s.outline, const Color(0xFF6E6863));
      expect(s.outlineVariant, const Color(0xFF3A3836));
      expect(s.error, const Color(0xFFFF8A80));
      const x = StorizeColors.dark;
      expect(x.success.color, const Color(0xFF5BD69A));
      expect(x.warning.color, const Color(0xFFFFB74D));
      expect(x.neutralStatus.color, const Color(0xFF9A938D));
      expect(x.accent.color, const Color(0xFFF2B95A));
      expect(x.accent.container, const Color(0xFF3D2A06));
      expect(x.brandPressed, const Color(0xFFFFB08F));
      expect(s.surfaceContainerHigh, const Color(0xFF2A2A2E));
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

    check(t.displaySmall, 28, 36, FontWeight.w600);
    check(t.headlineMedium, 22, 28, FontWeight.w600);
    check(t.titleLarge, 17, 24, FontWeight.w500);
    check(t.headlineLarge, 24, 28, FontWeight.w600);
    check(t.bodyLarge, 15, 22, FontWeight.w400);
    check(t.labelLarge, 13, 18, FontWeight.w500);
    check(t.bodySmall, 12, 16, FontWeight.w400);
  });

  test('spacing and shapes', () {
    expect(StorizeRadii.card, 20);
    expect(StorizeRadii.chip, 10);
    expect(StorizeRadii.thumb, 12);
    expect(StorizeRadii.sheet, 20);
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

  test('every brand token in tokens.json is mapped in both themes', () {
    final json = jsonDecode(
      File(
        '../docs/02-design/v2/brand/tokens.json',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    final tokens =
        ((json['color']! as Map<String, Object?>)['tokens']! as List<Object?>)
            .cast<Map<String, Object?>>();
    Color hex(String v) {
      final h = v.substring(1);
      // #RRGGBB or #RRGGBBAA (CSS) to Flutter ARGB.
      final argb = h.length == 8
          ? int.parse('${h.substring(6)}${h.substring(0, 6)}', radix: 16)
          : int.parse('FF$h', radix: 16);
      return Color(argb);
    }

    for (final (id, theme) in [
      ('light', StorizeTheme.light()),
      ('dark', StorizeTheme.dark()),
    ]) {
      final s = theme.colorScheme;
      final x = theme.extension<StorizeColors>()!;
      final mapped = <String, Color>{
        'brand': s.primary,
        'on-brand': s.onPrimary,
        'brand-pressed': x.brandPressed,
        'brand-container': s.primaryContainer,
        'on-brand-container': s.onPrimaryContainer,
        'accent': x.accent.color,
        'accent-container': x.accent.container,
        'surface': s.surface,
        'surface-container': s.surfaceContainer,
        'surface-container-high': s.surfaceContainerHigh,
        'ink': s.onSurface,
        'ink-muted': s.onSurfaceVariant,
        'outline': s.outlineVariant,
        'outline-strong': s.outline,
        'media-scrim': x.mediaScrim,
        'success': x.success.color,
        'warning': x.warning.color,
        'error': s.error,
        'neutral-status': x.neutralStatus.color,
      };
      for (final t in tokens) {
        final name = t['name']! as String;
        final value = (t['value']! as Map<String, Object?>)[id]! as String;
        expect(mapped, contains(name), reason: 'unmapped token $name');
        expect(mapped[name], hex(value), reason: '$name ($id)');
      }
    }
  });
}
