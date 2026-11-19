import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/lock/biometric_auth.dart';
import 'package:storize_app/features/lock/lock_service.dart';
import 'package:storize_data/security/pin_vault.dart';

Never _unwired(String name) => throw UnimplementedError(
  '$name is not wired yet. Override it in main() or in the test.',
);

/// Test-only opt-out of the lock. Production never overrides it, so the
/// lock is fail-closed: until the settings, PIN store and biometric
/// providers are wired and the "lock on" setting is read, the app stays
/// locked (the lock screen shows a retry when a dependency is missing).
/// Tests of other screens override it with true through
/// `test/helpers/app_harness.dart`.
final appLockTestBypassProvider = Provider<bool>((ref) => false);

/// The PIN store ([PinVault] in production).
final pinStoreProvider = Provider<PinStore>(
  (ref) => _unwired('pinStoreProvider'),
);

/// The biometric prompt ([LocalAuthBiometric] in production).
final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => _unwired('biometricAuthProvider'),
);

/// App-lock operations for widgets.
final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(
    settings: ref.watch(settingsRepoProvider),
    pins: ref.watch(pinStoreProvider),
    biometric: ref.watch(biometricAuthProvider),
  ),
);

/// How long the app may stay in the background before it re-locks.
const Duration relockAfter = Duration(seconds: 60);

/// Where the lock gate is.
enum LockPhase {
  /// Cold start: the settings have not been read yet. Counts as locked.
  checking,

  /// The lock is on and the user has not unlocked yet.
  locked,

  /// Open (the lock is off, or the user unlocked).
  unlocked,

  /// The lock setting could not be read. Counts as locked.
  failed,
}

/// State of the lock gate.
@immutable
final class LockState {
  /// Creates the state.
  const LockState(this.phase, {this.enabled = false});

  /// Not locked and the lock is off.
  const LockState.off() : this(LockPhase.unlocked);

  /// Current phase.
  final LockPhase phase;

  /// The user turned the lock on (so a re-lock is due).
  final bool enabled;

  /// True in every phase except [LockPhase.unlocked]. Anything unknown
  /// stays locked.
  bool get locked => phase != LockPhase.unlocked;

  @override
  bool operator ==(Object other) =>
      other is LockState && other.phase == phase && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(phase, enabled);

  @override
  String toString() => 'LockState($phase, enabled: $enabled)';
}

/// Drives the lock gate (`appLockedProvider`).
///
/// - Cold start: locked until the setting is read; stays locked if the lock
///   is on.
/// - Re-locks when the app returns after 60 s or more in the background (a
///   clock that moved backwards also locks).
/// - Only [unlock] opens it, and only the lock screen calls that after a
///   successful PIN or biometric check.
class LockController extends Notifier<LockState> {
  DateTime? _backgroundedAt;

  @override
  LockState build() {
    if (ref.watch(appLockTestBypassProvider)) return const LockState.off();
    final listener = AppLifecycleListener(onStateChange: onLifecycle);
    ref.onDispose(listener.dispose);
    unawaited(Future.microtask(refresh));
    return const LockState(LockPhase.checking);
  }

  /// Reads the setting again. Used at start and by Retry.
  Future<void> refresh() async {
    final bool enabled;
    try {
      enabled = await ref.read(appLockServiceProvider).isEnabled();
    } on Object {
      state = const LockState(LockPhase.failed);
      return;
    }
    state = LockState(
      enabled ? LockPhase.locked : LockPhase.unlocked,
      enabled: enabled,
    );
  }

  /// Opens the gate. Call only after a successful check.
  void unlock() {
    if (state.locked && state.enabled) {
      state = const LockState(LockPhase.unlocked, enabled: true);
    }
  }

  // An unwired clock must not throw into the framework: the lock stays
  // closed instead.
  DateTime? _now() {
    try {
      return ref.read(clockProvider).now();
    } on Object {
      return null;
    }
  }

  /// App lifecycle input (public for tests).
  void onLifecycle(AppLifecycleState value) {
    switch (value) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Keep the first timestamp: hidden comes before paused.
        final at = _now();
        if (at == null) {
          // No clock: cannot time the absence, so lock at once.
          if (state.enabled) {
            state = const LockState(LockPhase.locked, enabled: true);
          }
        } else {
          _backgroundedAt ??= at;
        }
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null || !state.enabled || state.locked) return;
        final now = _now();
        if (now == null) {
          state = const LockState(LockPhase.locked, enabled: true);
          return;
        }
        final away = now.difference(since);
        if (away.isNegative || away >= relockAfter) {
          state = const LockState(LockPhase.locked, enabled: true);
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Turns the lock on with a PIN. The session stays unlocked.
  Future<void> enableWithPin(String pin) async {
    await ref.read(appLockServiceProvider).enableWithPin(pin);
    state = const LockState(LockPhase.unlocked, enabled: true);
  }

  /// Turns the lock on with biometrics only (already confirmed by the
  /// caller).
  Future<void> enableWithBiometric() async {
    await ref.read(appLockServiceProvider).enableWithBiometric();
    state = const LockState(LockPhase.unlocked, enabled: true);
  }

  /// Turns the lock off (the caller has authenticated).
  Future<void> disable() async {
    await ref.read(appLockServiceProvider).disable();
    state = const LockState.off();
  }

  /// Stores a new PIN in the reset state.
  Future<void> replacePin(String pin) =>
      ref.read(appLockServiceProvider).replacePin(pin);
}

/// The lock gate state.
final lockControllerProvider = NotifierProvider<LockController, LockState>(
  LockController.new,
);
