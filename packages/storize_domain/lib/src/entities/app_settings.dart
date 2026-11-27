import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/internal.dart';

/// Which theme the app shows (Settings -> Appearance). [system] follows the
/// phone's light or dark setting.
enum AppThemeMode {
  /// Follow the phone setting. The default.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// How the app notifies about saved content (FR-78, Settings -> Notify me).
enum NotificationMode {
  /// One notification per item or group (the default, as before FR-78).
  perItem,

  /// One summary notification a day at [AppSettings.summaryTime].
  daily,

  /// No content notifications. Problem notifications still show.
  off,
}

/// A time of day in the user's local time (FR-78 summary time).
@immutable
final class SummaryTime {
  /// Creates a time. Throws [RangeError] outside 00:00 to 23:59.
  const SummaryTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24, 'hour must be 0..23'),
      assert(minute >= 0 && minute < 60, 'minute must be 0..59');

  /// Creates the time of [minuteOfDay] (0 to 1439). Throws [RangeError]
  /// outside that range.
  factory SummaryTime.fromMinuteOfDay(int minuteOfDay) {
    if (minuteOfDay < 0 || minuteOfDay > 1439) {
      throw RangeError.range(minuteOfDay, 0, 1439, 'minuteOfDay');
    }
    return SummaryTime(minuteOfDay ~/ 60, minuteOfDay % 60);
  }

  /// The default summary time, 21:00.
  static const SummaryTime defaultTime = SummaryTime(21, 0);

  /// The hour, 0 to 23.
  final int hour;

  /// The minute, 0 to 59.
  final int minute;

  /// Minutes after local midnight, 0 to 1439 (the stored form).
  int get minuteOfDay => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is SummaryTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      'SummaryTime($hour:${minute.toString().padLeft(2, '0')})';
}

/// The user settings (TECH_SPEC §3 "Settings", stored in shared_preferences).
@immutable
final class AppSettings {
  /// Creates settings. Every argument defaults to the value in the spec.
  const AppSettings({
    this.storyIntervalMin = defaultStoryIntervalMin,
    this.postIntervalMin = defaultPostIntervalMin,
    this.wifiOnly = false,
    this.notifyStories = true,
    this.notifyPosts = true,
    this.notifyLogin = true,
    this.retentionDays,
    this.appLockEnabled = false,
    this.onboardingDone = false,
    this.riskAcknowledgedAt,
    this.pageModeInBackground = false,
    this.lastUpdateCheckAt,
    this.themeMode = AppThemeMode.system,
    this.notificationMode = NotificationMode.perItem,
    this.summaryTime = SummaryTime.defaultTime,
    this.hideFromGallery = false,
  });

  /// Allowed story check intervals in minutes (BR-5).
  static const Set<int> storyIntervalOptions = {15, 30, 60, 120, 180, 360};

  /// Allowed post check intervals in minutes (BR-5).
  static const Set<int> postIntervalOptions = {60, 120, 180, 360, 720, 1440};

  /// The default story interval in minutes.
  static const int defaultStoryIntervalMin = 30;

  /// The default post interval in minutes.
  static const int defaultPostIntervalMin = 180;

  /// How often stories are checked, in minutes. One of
  /// [storyIntervalOptions].
  final int storyIntervalMin;

  /// How often posts are checked, in minutes. One of [postIntervalOptions].
  final int postIntervalMin;

  /// Download only on an unmetered network.
  final bool wifiOnly;

  /// Notify about new stories.
  final bool notifyStories;

  /// Notify about new posts.
  final bool notifyPosts;

  /// Notify about login problems.
  final bool notifyLogin;

  /// Delete content older than this many days, or null to keep forever
  /// (FR-54). The spec lists no fixed set, so any positive number is valid.
  final int? retentionDays;

  /// Whether the app lock is on.
  final bool appLockEnabled;

  /// Whether onboarding is finished.
  final bool onboardingDone;

  /// When the user accepted the risk notice (UTC), or null.
  final DateTime? riskAcknowledgedAt;

  /// Whether page mode may run in the background. Off unless the spike proved
  /// it works (§4.1).
  final bool pageModeInBackground;

  /// When the update check last ran (UTC), or null.
  final DateTime? lastUpdateCheckAt;

  /// The appearance: follow the phone, or force light or dark.
  final AppThemeMode themeMode;

  /// How content is notified (FR-78). [NotificationMode.perItem] keeps the
  /// previous behaviour; the New stories / New posts toggles apply to it only.
  final NotificationMode notificationMode;

  /// The local time of the daily summary (FR-78). Used in daily mode only.
  final SummaryTime summaryTime;

  /// Save new downloads to Storize's private storage instead of the phone
  /// gallery (FR-79). Files already saved stay where they are until the user
  /// moves them.
  final bool hideFromGallery;

  /// The rule violations of these settings, one message each. Empty when the
  /// settings are valid. `SettingsRepo` implementations reject invalid
  /// settings with these messages.
  List<String> get validationErrors => [
    if (!storyIntervalOptions.contains(storyIntervalMin))
      'storyIntervalMin must be in $storyIntervalOptions: $storyIntervalMin',
    if (!postIntervalOptions.contains(postIntervalMin))
      'postIntervalMin must be in $postIntervalOptions: $postIntervalMin',
    if (retentionDays != null && retentionDays! <= 0)
      'retentionDays must be null or positive (was $retentionDays)',
  ];

  /// Whether [validationErrors] is empty.
  bool get isValid => validationErrors.isEmpty;

  /// Returns a copy with the given fields replaced. Pass null to clear a
  /// nullable field. The copy is not validated.
  AppSettings copyWith({
    int? storyIntervalMin,
    int? postIntervalMin,
    bool? wifiOnly,
    bool? notifyStories,
    bool? notifyPosts,
    bool? notifyLogin,
    Object? retentionDays = unset,
    bool? appLockEnabled,
    bool? onboardingDone,
    Object? riskAcknowledgedAt = unset,
    bool? pageModeInBackground,
    Object? lastUpdateCheckAt = unset,
    AppThemeMode? themeMode,
    NotificationMode? notificationMode,
    SummaryTime? summaryTime,
    bool? hideFromGallery,
  }) => AppSettings(
    storyIntervalMin: storyIntervalMin ?? this.storyIntervalMin,
    postIntervalMin: postIntervalMin ?? this.postIntervalMin,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    notifyStories: notifyStories ?? this.notifyStories,
    notifyPosts: notifyPosts ?? this.notifyPosts,
    notifyLogin: notifyLogin ?? this.notifyLogin,
    retentionDays: pick<int>(retentionDays, this.retentionDays),
    appLockEnabled: appLockEnabled ?? this.appLockEnabled,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    riskAcknowledgedAt: pick<DateTime>(
      riskAcknowledgedAt,
      this.riskAcknowledgedAt,
    ),
    pageModeInBackground: pageModeInBackground ?? this.pageModeInBackground,
    lastUpdateCheckAt: pick<DateTime>(
      lastUpdateCheckAt,
      this.lastUpdateCheckAt,
    ),
    themeMode: themeMode ?? this.themeMode,
    notificationMode: notificationMode ?? this.notificationMode,
    summaryTime: summaryTime ?? this.summaryTime,
    hideFromGallery: hideFromGallery ?? this.hideFromGallery,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettings &&
          other.storyIntervalMin == storyIntervalMin &&
          other.postIntervalMin == postIntervalMin &&
          other.wifiOnly == wifiOnly &&
          other.notifyStories == notifyStories &&
          other.notifyPosts == notifyPosts &&
          other.notifyLogin == notifyLogin &&
          other.retentionDays == retentionDays &&
          other.appLockEnabled == appLockEnabled &&
          other.onboardingDone == onboardingDone &&
          other.riskAcknowledgedAt == riskAcknowledgedAt &&
          other.pageModeInBackground == pageModeInBackground &&
          other.lastUpdateCheckAt == lastUpdateCheckAt &&
          other.themeMode == themeMode &&
          other.notificationMode == notificationMode &&
          other.summaryTime == summaryTime &&
          other.hideFromGallery == hideFromGallery);

  @override
  int get hashCode => Object.hash(
    storyIntervalMin,
    postIntervalMin,
    wifiOnly,
    notifyStories,
    notifyPosts,
    notifyLogin,
    retentionDays,
    appLockEnabled,
    onboardingDone,
    riskAcknowledgedAt,
    pageModeInBackground,
    lastUpdateCheckAt,
    themeMode,
    notificationMode,
    summaryTime,
    hideFromGallery,
  );

  @override
  String toString() =>
      'AppSettings(storyIntervalMin: $storyIntervalMin, '
      'postIntervalMin: $postIntervalMin, wifiOnly: $wifiOnly, '
      'retentionDays: $retentionDays)';
}
