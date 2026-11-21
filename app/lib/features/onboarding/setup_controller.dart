import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_app/features/onboarding/setup_ops.dart';

/// State of one S-03 step.
enum SetupStepState {
  /// Being re-checked (short spinner).
  checking,

  /// Not done.
  pending,

  /// Done.
  done,
}

/// UI state of S-03.
@immutable
class SetupState {
  /// Creates a state.
  const SetupState({
    this.notifications = SetupStepState.checking,
    this.battery = SetupStepState.checking,
    this.storage = SetupStepState.checking,
    this.manufacturer = 'other',
    this.sdkInt = 34,
    this.notificationDenials = 0,
    this.storageDenials = 0,
    this.permanentlyDenied = false,
  });

  /// Notification permission.
  final SetupStepState notifications;

  /// Battery exemption.
  final SetupStepState battery;

  /// Storage permission (Android 8-9 only).
  final SetupStepState storage;

  /// Normalised manufacturer.
  final String manufacturer;

  /// Android API level.
  final int sdkInt;

  /// How many times the notification prompt was denied.
  final int notificationDenials;

  /// How many times the storage prompt was denied.
  final int storageDenials;

  /// The system says a prompt will not show again.
  final bool permanentlyDenied;

  /// The storage card shows on Android 8-9 only (API 26-28).
  bool get showStorage => sdkInt <= 28;

  /// Denied twice, or for good: offer "Open app settings".
  bool get notificationsNeedSettings =>
      notifications == SetupStepState.pending &&
      (notificationDenials >= 2 || permanentlyDenied);

  /// Same for storage.
  bool get storageNeedsSettings =>
      storage == SetupStepState.pending && storageDenials >= 2;

  /// The warning under the cards (UX: step 2 not done).
  bool get showBatteryWarning => battery == SetupStepState.pending;

  /// A copy with changes.
  SetupState copyWith({
    SetupStepState? notifications,
    SetupStepState? battery,
    SetupStepState? storage,
    String? manufacturer,
    int? sdkInt,
    int? notificationDenials,
    int? storageDenials,
    bool? permanentlyDenied,
  }) => SetupState(
    notifications: notifications ?? this.notifications,
    battery: battery ?? this.battery,
    storage: storage ?? this.storage,
    manufacturer: manufacturer ?? this.manufacturer,
    sdkInt: sdkInt ?? this.sdkInt,
    notificationDenials: notificationDenials ?? this.notificationDenials,
    storageDenials: storageDenials ?? this.storageDenials,
    permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
  );
}

/// Drives S-03. [refresh] runs on open and on every app resume.
class SetupController extends Notifier<SetupState> {
  SetupOps get _ops => ref.read(setupOpsProvider);

  @override
  SetupState build() => const SetupState();

  SetupStepState _of(bool ok) =>
      ok ? SetupStepState.done : SetupStepState.pending;

  /// Re-checks every step.
  Future<void> refresh() async {
    state = state.copyWith(
      notifications: SetupStepState.checking,
      battery: SetupStepState.checking,
      storage: SetupStepState.checking,
    );
    final sdk = await _guard(_ops.sdkInt, 34);
    final oem = await _guard(_ops.manufacturer, 'other');
    final notif = await _guard(_ops.notificationsAllowed, false);
    final battery = await _guard(_ops.batteryUnrestricted, false);
    final storage = sdk <= 28 ? await _guard(_ops.storageGranted, false) : true;
    state = state.copyWith(
      sdkInt: sdk,
      manufacturer: oem,
      notifications: _of(notif),
      battery: _of(battery),
      storage: _of(storage),
    );
  }

  Future<T> _guard<T>(Future<T> Function() f, T fallback) async {
    try {
      return await f();
    } on Object {
      return fallback;
    }
  }

  /// Taps Allow on the notification card.
  Future<void> allowNotifications() async {
    final outcome = await _guard(
      _ops.requestNotifications,
      PermissionOutcome.denied,
    );
    state = switch (outcome) {
      PermissionOutcome.granted => state.copyWith(
        notifications: SetupStepState.done,
      ),
      PermissionOutcome.denied => state.copyWith(
        notificationDenials: state.notificationDenials + 1,
      ),
      PermissionOutcome.permanentlyDenied => state.copyWith(
        notificationDenials: state.notificationDenials + 1,
        permanentlyDenied: true,
      ),
    };
  }

  /// Taps Allow on the storage card (Android 8-9).
  Future<void> allowStorage() async {
    final outcome = await _guard(
      _ops.requestStorage,
      PermissionOutcome.denied,
    );
    state = outcome == PermissionOutcome.granted
        ? state.copyWith(storage: SetupStepState.done)
        : state.copyWith(
            storageDenials:
                state.storageDenials +
                (outcome == PermissionOutcome.permanentlyDenied ? 2 : 1),
          );
  }

  /// Opens the system battery screen. The status re-checks on resume.
  Future<void> openBattery() => _guard(_ops.openBatterySettings, null);

  /// Opens the app's system settings.
  Future<void> openAppSettings() => _guard(_ops.openAppSettings, null);
}

/// The S-03 controller.
final setupControllerProvider = NotifierProvider<SetupController, SetupState>(
  SetupController.new,
);
