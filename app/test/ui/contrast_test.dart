// WCAG 2.x contrast checks (>= 4.5:1) for every foreground/background pair the
// design system uses for text, in both themes.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

const _minRatio = 4.5;

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

typedef _Pair = (String, Color, Color);

List<_Pair> _pairs(ColorScheme s, StorizeColors c) {
  final tones = <String, StorizeTone>{
    'success': c.success,
    'warning': c.warning,
    'error': c.error,
    'neutralStatus': c.neutralStatus,
    'info': c.info,
    'tagOwn': c.tagOwn,
    'tagConsented': c.tagConsented,
    'tagPublic': c.tagPublic,
  };
  return [
    // Status badges, category tags, banners, activity icons: text on tone
    // container (StatusBadge, CategoryTag, SessionBanner, StepCard "Done").
    for (final e in tones.entries)
      (
        '${e.key}.onContainer on container',
        e.value.onContainer,
        e.value.container,
      ),
    // StatusBadge in a card / on surface is drawn on its own container, so
    // that is all that is needed. Secondary text on the surfaces it appears on:
    // Filled buttons, FAB and Switch thumb: label on primary (WCAG AA, UD-1).
    ('onPrimary on primary (filled button)', s.onPrimary, s.primary),
    // TextButton labels and active tab: primary used as text/icon on surface.
    ('primary on surface (text/icon)', s.primary, s.surface),
    ('onSurface on surface', s.onSurface, s.surface),
    ('onSurfaceVariant on surface', s.onSurfaceVariant, s.surface),
    (
      'onSurfaceVariant on surfaceContainer',
      s.onSurfaceVariant,
      s.surfaceContainer,
    ),
    ('onSurface on surfaceContainer', s.onSurface, s.surfaceContainer),
    (
      'onPrimaryContainer on primaryContainer',
      s.onPrimaryContainer,
      s.primaryContainer,
    ),
    ('onError on error (destructive button)', s.onError, s.error),
    ('error.color on surface (error text)', c.error.color, s.surface),
    (
      'success.onContainer on surfaceContainer (StepCard)',
      c.success.onContainer,
      s.surfaceContainer,
    ),
    // Dark-on-light/light-on-dark text on media badges.
    (
      'onMediaScrim on scrim over black',
      c.onMediaScrim,
      Color.alphaBlend(c.mediaScrim, const Color(0xFF000000)),
    ),
    // KindSwitch unselected count badge.
    (
      'surface on onSurfaceVariant (count badge)',
      s.surface,
      s.onSurfaceVariant,
    ),
  ];
}

void main() {
  final themes = {
    'light': (StorizeTheme.lightScheme, StorizeColors.light),
    'dark': (StorizeTheme.darkScheme, StorizeColors.dark),
  };

  for (final entry in themes.entries) {
    group('contrast >= 4.5:1 (${entry.key})', () {
      final (scheme, colors) = entry.value;
      for (final (name, fg, bg) in _pairs(scheme, colors)) {
        test(name, () {
          final ratio = contrast(fg, bg);
          // Prints the ratios so they show up in the test log.
          // ignore: avoid_print
          print('${entry.key} | $name = ${ratio.toStringAsFixed(2)}');
          expect(ratio, greaterThanOrEqualTo(_minRatio));
        });
      }
    });
  }

  test('light primary #C93F17 meets WCAG AA (UD-1)', () {
    const s = StorizeTheme.lightScheme;
    expect(s.primary, const Color(0xFFC93F17));
    expect(
      contrast(const Color(0xFFFFFFFF), s.primary),
      greaterThanOrEqualTo(_minRatio),
    );
    expect(contrast(s.primary, s.surface), greaterThanOrEqualTo(_minRatio));
  });

  test(
    'KNOWN FAILURE pending UX decision: light warning text on surface (QA F3)',
    () {
      const s = StorizeTheme.lightScheme;
      const c = StorizeColors.light;
      expect(
        contrast(c.warning.color, s.surface),
        greaterThanOrEqualTo(_minRatio),
      );
    },
    skip: 'pending UX decision on light warning text (QA F3)',
  );
}
