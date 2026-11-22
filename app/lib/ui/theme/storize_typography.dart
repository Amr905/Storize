import 'package:material_ui/material_ui.dart';

/// The Storize type scale (UX §5.2). No font family is set, so the platform
/// default (Roboto on Android) is used and no font is bundled.
///
/// Mapping onto Material roles:
/// - Display 28/36 Medium -> `displaySmall`
/// - Title 20/28 Medium -> `titleLarge`
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

  /// Display 28/36 Medium.
  static final TextStyle display = _style(28, 36, FontWeight.w500);

  /// Large page title (app bar of top-level screens) 24/32 Medium.
  static final TextStyle pageTitle = _style(24, 32, FontWeight.w500);

  /// Title 20/28 Medium.
  static final TextStyle title = _style(20, 28, FontWeight.w500);

  /// Body 15/22 Regular.
  static final TextStyle body = _style(15, 22, FontWeight.w400);

  /// Label 13/18 Medium.
  static final TextStyle label = _style(13, 18, FontWeight.w500);

  /// Caption 12/16 Regular.
  static final TextStyle caption = _style(12, 16, FontWeight.w400);

  /// The text theme (colours are applied by the theme).
  static TextTheme get textTheme => TextTheme(
    displaySmall: display,
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
