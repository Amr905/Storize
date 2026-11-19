import 'package:flutter/foundation.dart';
import 'package:storize_platform_android/src/storize_platform_exception.dart';

/// Result of `insert`: where the file landed.
@immutable
class InsertedMedia {
  const InsertedMedia({
    required this.uri,
    required this.size,
    this.relativePath,
  });

  /// `content://media/...` URI (or `file://` on Android 8-9 if the media scan
  /// did not answer in time). Accepted by delete, exists and size.
  final String uri;

  /// Size in bytes.
  final int size;

  /// The folder actually used, for example `Pictures/Storize/nour_k/`.
  /// Videos can land in `Movies/Storize/...` if the system refuses `Pictures`.
  final String? relativePath;
}

/// Which screen `openBatterySettings` ended up opening.
enum BatterySettingsTarget {
  /// The system "allow this app to ignore battery optimizations" dialog.
  requestIgnore,

  /// A manufacturer screen (autostart / battery).
  oemScreen,

  /// The app details settings page (last resort).
  appDetails,

  /// Nothing could be opened.
  none,
}

/// Outcome of `openBatterySettings`.
@immutable
class BatterySettingsOutcome {
  const BatterySettingsOutcome(this.target, [this.raw]);

  /// Decodes the native string: `request_ignore`, `oem_<name>`, `app_details`
  /// or `none`.
  factory BatterySettingsOutcome.parse(String? raw) {
    if (raw == 'request_ignore') {
      return BatterySettingsOutcome(BatterySettingsTarget.requestIgnore, raw);
    }
    if (raw != null && raw.startsWith('oem_')) {
      return BatterySettingsOutcome(BatterySettingsTarget.oemScreen, raw);
    }
    if (raw == 'app_details') {
      return BatterySettingsOutcome(BatterySettingsTarget.appDetails, raw);
    }
    if (raw == 'none') {
      return BatterySettingsOutcome(BatterySettingsTarget.none, raw);
    }
    throw StorizePlatformException(
      StorizePlatformErrorKind.badResponse.code,
      'Unexpected openBatterySettings result: $raw',
    );
  }

  final BatterySettingsTarget target;

  /// The raw native value, for example `oem_xiaomi`.
  final String? raw;

  /// True if some screen was opened.
  bool get opened => target != BatterySettingsTarget.none;
}

/// One entry of `lastStopReasons`.
@immutable
class StopReason {
  const StopReason({
    required this.workName,
    required this.reason,
    this.timestampMs,
  });

  /// The work this reason belongs to. The current native implementation reads
  /// process exit info (API 30+), so this is always `process`.
  final String workName;

  /// For example `LOW_MEMORY`, `USER_REQUESTED`, `EXCESSIVE_RESOURCE_USAGE`.
  final String reason;

  /// When the process ended, in milliseconds since the epoch.
  final int? timestampMs;
}
