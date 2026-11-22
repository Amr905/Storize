import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/theme/storize_colors.dart';
import 'package:storize_app/ui/theme/storize_dimens.dart';
import 'package:storize_app/ui/theme/storize_typography.dart';

/// Builds the Storize light and dark [ThemeData] (UX §5.2).
abstract final class StorizeTheme {
  /// UX §5.2 tokens, light column. Roles the table does not define
  /// (secondary*, extra surface containers, errorContainer) are derived.
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFC93F17),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE3D8),
    onPrimaryContainer: Color(0xFF5A1D07),
    secondary: Color(0xFFC93F17),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFE3D8),
    onSecondaryContainer: Color(0xFF5A1D07),
    error: Color(0xFFC62828),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDE7E4),
    onErrorContainer: Color(0xFF8C1B1B),
    surface: Color(0xFFFBF8F5),
    onSurface: Color(0xFF1C1A18),
    onSurfaceVariant: Color(0xFF6B635C),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F2EE),
    surfaceContainer: Color(0xFFF1ECE7),
    surfaceContainerHigh: Color(0xFFEAE4DE),
    surfaceContainerHighest: Color(0xFFE3DCD5),
    outline: Color(0xFFD8D0C8),
    outlineVariant: Color(0xFFD8D0C8),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2F2C29),
    onInverseSurface: Color(0xFFF6F2EE),
    inversePrimary: Color(0xFFFF8A5C),
  );

  /// UX §5.2 tokens, dark column.
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF8A5C),
    onPrimary: Color(0xFF3A0E00),
    primaryContainer: Color(0xFF5A1D07),
    onPrimaryContainer: Color(0xFFFFE3D8),
    secondary: Color(0xFFFF8A5C),
    onSecondary: Color(0xFF3A0E00),
    secondaryContainer: Color(0xFF5A1D07),
    onSecondaryContainer: Color(0xFFFFE3D8),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF410002),
    errorContainer: Color(0xFF5C1A17),
    onErrorContainer: Color(0xFFFFC9C4),
    surface: Color(0xFF121214),
    onSurface: Color(0xFFECE6E1),
    onSurfaceVariant: Color(0xFFA69E97),
    surfaceContainerLowest: Color(0xFF0D0D0F),
    surfaceContainerLow: Color(0xFF19191B),
    surfaceContainer: Color(0xFF1E1E21),
    surfaceContainerHigh: Color(0xFF262629),
    surfaceContainerHighest: Color(0xFF2E2E32),
    outline: Color(0xFF3A3836),
    outlineVariant: Color(0xFF3A3836),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFECE6E1),
    onInverseSurface: Color(0xFF1E1E21),
    inversePrimary: Color(0xFFA8380F),
  );

  /// Light theme.
  static ThemeData light() => _build(lightScheme, StorizeColors.light);

  /// Dark theme.
  static ThemeData dark() => _build(darkScheme, StorizeColors.dark);

  static ThemeData _build(ColorScheme scheme, StorizeColors extra) {
    const minSize = Size(
      StorizeSpacing.minTouchTarget,
      StorizeSpacing.minTouchTarget,
    );
    const stadium = StadiumBorder();
    // Resolve against the platform typography so the default font family
    // (Roboto on Android) is part of every style, including button themes.
    final textTheme = ThemeData(
      brightness: scheme.brightness,
      useMaterial3: true,
      textTheme: StorizeTypography.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    ).textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: scheme.outline,
      textTheme: textTheme,
      extensions: [extra],
      splashFactory: InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        centerTitle: false,
        titleSpacing: StorizeSpacing.s16,
        titleTextStyle: StorizeTypography.pageTitle.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: StorizeRadii.cardRadius,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: scheme.shadow,
        shape: const RoundedRectangleBorder(
          borderRadius: StorizeRadii.cardRadius,
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: StorizeRadii.sheetRadius,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          shape: stadium,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: StorizeSpacing.s24,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minSize,
          shape: stadium,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          shape: stadium,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: StorizeSpacing.minRowHeight,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: StorizeSpacing.s16,
        ),
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        height: 80,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                )
              : textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
