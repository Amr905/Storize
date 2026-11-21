import 'package:storize_platform_android/storize_platform_android.dart';

/// Result of asking for a runtime permission.
enum PermissionOutcome {
  /// Granted.
  granted,

  /// Denied; may be asked again.
  denied,

  /// Denied for good; only app settings can change it.
  permanentlyDenied,
}

/// Device operations S-03 needs. A seam so widget tests use a fake.
abstract interface class SetupOps {
  /// Whether notifications are allowed.
  Future<bool> notificationsAllowed();

  /// Shows the system notification prompt (Android 13+).
  Future<PermissionOutcome> requestNotifications();

  /// Whether Storize is exempt from battery optimization.
  Future<bool> batteryUnrestricted();

  /// Opens the best battery screen for this phone.
  Future<void> openBatterySettings();

  /// `samsung`, `xiaomi`, `oppo`, `vivo`, `huawei` or `other`.
  Future<String> manufacturer();

  /// The Android API level (26 = Android 8).
  Future<int> sdkInt();

  /// Whether storage access is granted (only used on Android 8-9).
  Future<bool> storageGranted();

  /// Shows the storage permission prompt (Android 8-9).
  Future<PermissionOutcome> requestStorage();

  /// Opens the app's system settings page.
  Future<void> openAppSettings();
}

/// [SetupOps] over `StorizePlatformAndroid` for battery and manufacturer. The
/// permission prompts and the API level come from callbacks, because those
/// plugins are wired by the composition root.
final class PlatformSetupOps implements SetupOps {
  /// Creates the adapter.
  PlatformSetupOps({
    required StorizePlatformAndroid platform,
    required Future<bool> Function() notificationsAllowed,
    required Future<PermissionOutcome> Function() requestNotifications,
    required Future<int> Function() sdkInt,
    required Future<bool> Function() storageGranted,
    required Future<PermissionOutcome> Function() requestStorage,
    required Future<void> Function() openAppSettings,
  }) : _platform = platform,
       _notificationsAllowed = notificationsAllowed,
       _requestNotifications = requestNotifications,
       _sdkInt = sdkInt,
       _storageGranted = storageGranted,
       _requestStorage = requestStorage,
       _openAppSettings = openAppSettings;

  final StorizePlatformAndroid _platform;
  final Future<bool> Function() _notificationsAllowed;
  final Future<PermissionOutcome> Function() _requestNotifications;
  final Future<int> Function() _sdkInt;
  final Future<bool> Function() _storageGranted;
  final Future<PermissionOutcome> Function() _requestStorage;
  final Future<void> Function() _openAppSettings;

  @override
  Future<bool> notificationsAllowed() => _notificationsAllowed();

  @override
  Future<PermissionOutcome> requestNotifications() => _requestNotifications();

  @override
  Future<bool> batteryUnrestricted() =>
      _platform.isIgnoringBatteryOptimizations();

  @override
  Future<void> openBatterySettings() async {
    await _platform.openBatterySettings();
  }

  @override
  Future<String> manufacturer() => _platform.manufacturer();

  @override
  Future<int> sdkInt() => _sdkInt();

  @override
  Future<bool> storageGranted() => _storageGranted();

  @override
  Future<PermissionOutcome> requestStorage() => _requestStorage();

  @override
  Future<void> openAppSettings() => _openAppSettings();
}
