/// Built-in labels used by shared components.
///
/// Components never need app-specific text; this class only holds the generic
/// labels (badge names, "Fix", "Delete", ...).
// TODO(T-025): Move every string here into the ARB files and read them via
// the generated localizations.
abstract final class StorizeStrings {
  // Status badges.
  static const String statusActive = 'Active';
  static const String statusChecking = 'Checking';
  static const String statusPaused = 'Paused';
  static const String statusNotVisible = 'Not visible';
  static const String statusUnavailable = 'Unavailable';
  static const String statusError = 'Error';
  static const String statusNeedsRelogin = 'Needs re-login';
  static const String statusRestricted = 'Restricted';

  // Category tags.
  static const String categoryOwn = 'Own / client';
  static const String categoryConsented = 'Consented';
  static const String categoryPublic = 'Public';

  // Session banner.
  static const String bannerFix = 'Fix';
  static const String bannerReloginTitle = 'Instagram login needs attention';
  static const String bannerReloginBody = 'Checks are paused.';
  static const String bannerRestrictedTitle = 'Instagram account restricted';
  static const String bannerRestrictedBody = 'Checks are paused.';

  // Thumbnails.
  static const String thumbNew = 'new';
  static const String thumbBroken = "Can't load";
  static const String thumbSelected = 'selected';

  // Steps.
  static const String stepDone = 'Done';
  static const String stepPending = 'To do';

  // Misc.
  static const String all = 'All';
  static const String loading = 'Loading';
  static const String expand = 'Expand';
  static const String collapse = 'Collapse';

  // PIN pad.
  static const String pinDelete = 'Delete';
  static const String pinBiometric = 'Use biometrics';

  /// "3 of 4 digits entered".
  static String pinProgress(int filled, int length) =>
      '$filled of $length digits entered';

  /// "Try again in 0:30".
  static String pinCooldown(String time) => 'Try again in $time';
}
