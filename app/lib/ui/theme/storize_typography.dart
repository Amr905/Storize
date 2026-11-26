import 'package:material_ui/material_ui.dart';

/// The Storize type scale (UX §5.2). No font family is set, so the platform
/// default (Roboto on Android) is used and no font is bundled.
///
/// Brand v2 scale (`docs/02-design/v2/brand/tokens.json`). Mapping onto
/// Material roles:
/// - Display 28/36 Semibold -> `displaySmall`
/// - Headline 22/28 Semibold -> `headlineMedium` (app bar titles)
/// - Title 17/24 Medium -> `titleLarge`, `headlineSmall`
/// - Body 15/22 Regular -> `bodyLarge`, `bodyMedium`
/// - Label 13/18 Medium -> `labelLarge`, `labelMedium`
/// - Caption 12/16 Regular -> `bodySmall`, `labelSmall`
abstract final class StorizeTypography {
  static TextStyle _style(double size, double line, FontWeight weight) {
    return TextStyle(
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      letterSpacing: 0,
    );
  }

  /// Display 28/36 Semibold.
  static final TextStyle display = _style(28, 36, FontWeight.w600);

  /// Headline 22/28 Semibold (top app bar titles).
  static final TextStyle headline = _style(22, 28, FontWeight.w600);

  /// Title 17/24 Medium (section headers, card titles, usernames).
  static final TextStyle title = _style(17, 24, FontWeight.w500);

  /// Numeral 24/28 Semibold (stat tiles).
  static final TextStyle numeral = _style(24, 28, FontWeight.w600);

  /// Body 15/22 Regular.
  static final TextStyle body = _style(15, 22, FontWeight.w400);

  /// Label 13/18 Medium.
  static final TextStyle label = _style(13, 18, FontWeight.w500);

  /// Caption 12/16 Regular.
  static final TextStyle caption = _style(12, 16, FontWeight.w400);

  /// The text theme (colours are applied by the theme).
  static TextTheme get textTheme => TextTheme(
    displaySmall: display,
    headlineMedium: headline,
    headlineLarge: numeral,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: _style(15, 22, FontWeight.w500),
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: label,
    labelMedium: label,
    labelSmall: caption,
  );
}
