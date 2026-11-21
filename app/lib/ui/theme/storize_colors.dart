import 'package:material_ui/material_ui.dart';

/// One semantic tone: a strong foreground (icons, dots), a tonal container and
/// the text colour to use on that container.
@immutable
class StorizeTone {
  /// Creates a tone.
  const StorizeTone({
    required this.color,
    required this.container,
    required this.onContainer,
  });

  /// Linear interpolation between two tones.
  factory StorizeTone.lerp(StorizeTone a, StorizeTone b, double t) {
    return StorizeTone(
      color: Color.lerp(a.color, b.color, t)!,
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
    );
  }

  /// Strong colour for icons, dots and outlines.
  final Color color;

  /// Tonal background.
  final Color container;

  /// Text/icon colour on [container].
  final Color onContainer;
}

/// Extra colour roles that Material's [ColorScheme] does not have (UX §5.2):
/// success / warning / error / neutral status tones and the category tags.
@immutable
class StorizeColors extends ThemeExtension<StorizeColors> {
  /// Creates the extension.
  const StorizeColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.neutralStatus,
    required this.info,
    required this.tagOwn,
    required this.tagConsented,
    required this.tagPublic,
    required this.mediaScrim,
    required this.onMediaScrim,
  });

  /// Light palette. Base colours are the UX §5.2 tokens; containers and
  /// on-container colours are derived to keep WCAG AA text contrast.
  static const light = StorizeColors(
    success: StorizeTone(
      color: Color(0xFF1F7A4D),
      container: Color(0xFFE0F2E8),
      onContainer: Color(0xFF14502F),
    ),
    warning: StorizeTone(
      color: Color(0xFF955A00),
      container: Color(0xFFFFEFD0),
      onContainer: Color(0xFF6B4300),
    ),
    error: StorizeTone(
      color: Color(0xFFC62828),
      container: Color(0xFFFDE7E4),
      onContainer: Color(0xFF8C1B1B),
    ),
    neutralStatus: StorizeTone(
      color: Color(0xFF8A847E),
      container: Color(0xFFE9E4DF),
      onContainer: Color(0xFF5E5852),
    ),
    info: StorizeTone(
      color: Color(0xFFC93F17),
      container: Color(0xFFFFE3D8),
      onContainer: Color(0xFF8A2E10),
    ),
    tagOwn: StorizeTone(
      color: Color(0xFF2F4C8A),
      container: Color(0xFFE3ECFB),
      onContainer: Color(0xFF2F4C8A),
    ),
    tagConsented: StorizeTone(
      color: Color(0xFF5B3DB0),
      container: Color(0xFFEDE6FA),
      onContainer: Color(0xFF5B3DB0),
    ),
    tagPublic: StorizeTone(
      color: Color(0xFF1E6E66),
      container: Color(0xFFE5F3F1),
      onContainer: Color(0xFF1E6E66),
    ),
    mediaScrim: Color(0xB3000000),
    onMediaScrim: Color(0xFFFFFFFF),
  );

  /// Dark palette (see [light]). Category tags keep the mockup hues
  /// (blue / purple / teal) with dark containers and light text, >= 4.5:1.
  static const dark = StorizeColors(
    success: StorizeTone(
      color: Color(0xFF5BD69A),
      container: Color(0xFF123826),
      onContainer: Color(0xFFA8EFCB),
    ),
    warning: StorizeTone(
      color: Color(0xFFFFB74D),
      container: Color(0xFF3D2A08),
      onContainer: Color(0xFFFFD99B),
    ),
    error: StorizeTone(
      color: Color(0xFFFF8A80),
      container: Color(0xFF5C1A17),
      onContainer: Color(0xFFFFC9C4),
    ),
    neutralStatus: StorizeTone(
      color: Color(0xFF8A847E),
      container: Color(0xFF2A2927),
      onContainer: Color(0xFFC2BBB4),
    ),
    info: StorizeTone(
      color: Color(0xFFFF8A5C),
      container: Color(0xFF5A1D07),
      onContainer: Color(0xFFFFB59A),
    ),
    tagOwn: StorizeTone(
      color: Color(0xFF8DB4F0),
      container: Color(0xFF1B2E4D),
      onContainer: Color(0xFFB9D0F7),
    ),
    tagConsented: StorizeTone(
      color: Color(0xFFB79DEB),
      container: Color(0xFF2E2347),
      onContainer: Color(0xFFD8C8F6),
    ),
    tagPublic: StorizeTone(
      color: Color(0xFF7FD3C9),
      container: Color(0xFF12332F),
      onContainer: Color(0xFFA6E0D8),
    ),
    mediaScrim: Color(0xB3000000),
    onMediaScrim: Color(0xFFFFFFFF),
  );

  /// Active / success tone.
  final StorizeTone success;

  /// Needs re-login, gaps, rate limit.
  final StorizeTone warning;

  /// Restricted, errors, destructive.
  final StorizeTone error;

  /// Paused, not visible, unavailable.
  final StorizeTone neutralStatus;

  /// Checking / informational (ember).
  final StorizeTone info;

  /// Category tag: own / client (blue, matches mockup S-07).
  final StorizeTone tagOwn;

  /// Category tag: consented / person who agreed (purple).
  final StorizeTone tagConsented;

  /// Category tag: public creator (teal).
  final StorizeTone tagPublic;

  /// Dark scrim behind badges that sit on top of media.
  final Color mediaScrim;

  /// Foreground on [mediaScrim].
  final Color onMediaScrim;

  /// Reads the extension from [context]'s theme.
  static StorizeColors of(BuildContext context) =>
      Theme.of(context).extension<StorizeColors>()!;

  @override
  StorizeColors copyWith({
    StorizeTone? success,
    StorizeTone? warning,
    StorizeTone? error,
    StorizeTone? neutralStatus,
    StorizeTone? info,
    StorizeTone? tagOwn,
    StorizeTone? tagConsented,
    StorizeTone? tagPublic,
    Color? mediaScrim,
    Color? onMediaScrim,
  }) {
    return StorizeColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      neutralStatus: neutralStatus ?? this.neutralStatus,
      info: info ?? this.info,
      tagOwn: tagOwn ?? this.tagOwn,
      tagConsented: tagConsented ?? this.tagConsented,
      tagPublic: tagPublic ?? this.tagPublic,
      mediaScrim: mediaScrim ?? this.mediaScrim,
      onMediaScrim: onMediaScrim ?? this.onMediaScrim,
    );
  }

  @override
  StorizeColors lerp(ThemeExtension<StorizeColors>? other, double t) {
    if (other is! StorizeColors) return this;
    return StorizeColors(
      success: StorizeTone.lerp(success, other.success, t),
      warning: StorizeTone.lerp(warning, other.warning, t),
      error: StorizeTone.lerp(error, other.error, t),
      neutralStatus: StorizeTone.lerp(neutralStatus, other.neutralStatus, t),
      info: StorizeTone.lerp(info, other.info, t),
      tagOwn: StorizeTone.lerp(tagOwn, other.tagOwn, t),
      tagConsented: StorizeTone.lerp(tagConsented, other.tagConsented, t),
      tagPublic: StorizeTone.lerp(tagPublic, other.tagPublic, t),
      mediaScrim: Color.lerp(mediaScrim, other.mediaScrim, t)!,
      onMediaScrim: Color.lerp(onMediaScrim, other.onMediaScrim, t)!,
    );
  }
}
