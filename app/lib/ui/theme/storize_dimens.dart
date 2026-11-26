import 'package:material_ui/material_ui.dart';

/// Spacing constants on a 4-dp grid (UX §5.2).
abstract final class StorizeSpacing {
  /// 4 dp.
  static const double s4 = 4;

  /// 8 dp.
  static const double s8 = 8;

  /// 12 dp.
  static const double s12 = 12;

  /// 16 dp.
  static const double s16 = 16;

  /// 20 dp.
  static const double s20 = 20;

  /// 24 dp.
  static const double s24 = 24;

  /// 32 dp.
  static const double s32 = 32;

  /// 48 dp.
  static const double s48 = 48;

  /// Screen margin.
  static const double screenMargin = 16;

  /// Card padding.
  static const double cardPadding = 16;

  /// Minimum list-row height.
  static const double minRowHeight = 64;

  /// Minimum interactive target (Android guideline).
  static const double minTouchTarget = 48;
}

/// Corner radii (UX §5.2).
abstract final class StorizeRadii {
  /// Cards: 20.
  static const double card = 20;

  /// Chips, inputs, badges: 10.
  static const double chip = 10;

  /// Thumbnails: 12.
  static const double thumb = 12;

  /// Bottom sheets (top corners): 20.
  static const double sheet = 20;

  /// Fully rounded (buttons, pills).
  static const double full = 999;

  /// Card shape radius.
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );

  /// Chip radius.
  static const BorderRadius chipRadius = BorderRadius.all(
    Radius.circular(chip),
  );

  /// Thumbnail radius.
  static const BorderRadius thumbRadius = BorderRadius.all(
    Radius.circular(thumb),
  );

  /// Pill radius.
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );

  /// Bottom-sheet radius (top corners only).
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Motion constants (UX §5.2: 200 ms standard easing).
abstract final class StorizeMotion {
  /// Standard duration.
  static const Duration standard = Duration(milliseconds: 200);

  /// Standard easing.
  static const Curve curve = Curves.easeInOut;
}
