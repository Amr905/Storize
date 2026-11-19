/// Limits on tracked targets.
abstract final class TargetLimits {
  /// The number of targets above which AddTarget warns the user (A-12,
  /// NFR-4). It is a recommendation, not a hard limit.
  static const int recommendedMax = 50;

  /// The maximum length of a target note (FR-16).
  static const int noteMaxLength = 200;
}
