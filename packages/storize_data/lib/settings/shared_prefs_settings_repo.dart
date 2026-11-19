import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:storize_domain/storize_domain.dart';

/// The shared_preferences keys for [AppSettings] (TECH_SPEC §3 "Settings").
///
/// Every key has the `storize.` prefix followed by the field name. The keys
/// are stable: renaming one orphans the stored value, so a rename needs a
/// migration.
abstract final class SettingsKeys {
  /// Story check interval in minutes (int).
  static const String storyIntervalMin = 'storize.storyIntervalMin';

  /// Post check interval in minutes (int).
  static const String postIntervalMin = 'storize.postIntervalMin';

  /// Download only on an unmetered network (bool).
  static const String wifiOnly = 'storize.wifiOnly';

  /// Notify about new stories (bool).
  static const String notifyStories = 'storize.notifyStories';

  /// Notify about new posts (bool).
  static const String notifyPosts = 'storize.notifyPosts';

  /// Notify about login problems (bool).
  static const String notifyLogin = 'storize.notifyLogin';

  /// Retention in days (int), absent when content is kept forever.
  static const String retentionDays = 'storize.retentionDays';

  /// Whether the app lock is on (bool).
  static const String appLockEnabled = 'storize.appLockEnabled';

  /// Whether onboarding is finished (bool).
  static const String onboardingDone = 'storize.onboardingDone';

  /// When the risk notice was accepted, epoch milliseconds UTC (int).
  static const String riskAcknowledgedAt = 'storize.riskAcknowledgedAt';

  /// Whether page mode may run in the background (bool).
  static const String pageModeInBackground = 'storize.pageModeInBackground';

  /// When the update check last ran, epoch milliseconds UTC (int).
  static const String lastUpdateCheckAt = 'storize.lastUpdateCheckAt';

  /// The key of every [AppSettings] field, keyed by the field name.
  static const Map<String, String> byField = {
    'storyIntervalMin': storyIntervalMin,
    'postIntervalMin': postIntervalMin,
    'wifiOnly': wifiOnly,
    'notifyStories': notifyStories,
    'notifyPosts': notifyPosts,
    'notifyLogin': notifyLogin,
    'retentionDays': retentionDays,
    'appLockEnabled': appLockEnabled,
    'onboardingDone': onboardingDone,
    'riskAcknowledgedAt': riskAcknowledgedAt,
    'pageModeInBackground': pageModeInBackground,
    'lastUpdateCheckAt': lastUpdateCheckAt,
  };
}

/// Largest epoch value `DateTime` accepts, in milliseconds.
const int _maxEpochMs = 8640000000000000;

/// A [SettingsRepo] backed by shared_preferences (TECH_SPEC §3).
///
/// Reads never throw. A stored value that has the wrong type, or that breaks
/// an [AppSettings] rule, is ignored and the field falls back to its default.
/// Instants are stored with millisecond precision and read back in UTC.
final class SharedPrefsSettingsRepo implements SettingsRepo {
  /// Creates the repo. [prefs] defaults to the platform store; tests inject
  /// one backed by `InMemorySharedPreferencesAsync`.
  SharedPrefsSettingsRepo({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// Open watch streams, notified after every successful update.
  final List<StreamController<AppSettings>> _watchers = [];

  /// Tail of the operation queue. Reads and writes run one at a time so an
  /// update never reads a half-written state and two updates never lose each
  /// other's changes.
  Future<void> _queue = Future<void>.value();

  @override
  Stream<AppSettings> watch() {
    late final StreamController<AppSettings> controller;
    var cancelled = false;
    controller = StreamController<AppSettings>(
      onListen: () {
        unawaited(
          _serialized(() async {
            // Registered inside the queue: an update queued after this point
            // is always delivered, and one queued before it is already in the
            // value read below.
            if (cancelled) return;
            _watchers.add(controller);
            try {
              controller.add(await _read());
            } on Object catch (error, stack) {
              controller.addError(error, stack);
            }
          }),
        );
      },
      onCancel: () {
        cancelled = true;
        _watchers.remove(controller);
      },
    );
    return controller.stream;
  }

  @override
  Future<AppSettings> get() => _serialized(_read);

  @override
  Future<AppSettings> update(
    AppSettings Function(AppSettings current) change,
  ) => _serialized(() async {
    final current = await _read();
    final next = change(current);
    final problems = next.validationErrors;
    if (problems.isNotEmpty) throw SettingsValidationException(problems);
    await _write(from: current, to: next);
    for (final watcher in List.of(_watchers)) {
      if (!watcher.isClosed) watcher.add(next);
    }
    return next;
  });

  /// Runs [task] after every operation queued before it. A failing task does
  /// not stop the queue.
  Future<T> _serialized<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<AppSettings> _read() async {
    final stored = await _prefs.getAll(
      allowList: SettingsKeys.byField.values.toSet(),
    );
    return _decode(stored);
  }

  /// Builds settings from raw stored values. Anything unusable falls back to
  /// the [AppSettings] default of that field.
  AppSettings _decode(Map<String, Object?> stored) {
    const defaults = AppSettings();
    return AppSettings(
      storyIntervalMin: _validInt(
        stored[SettingsKeys.storyIntervalMin],
        defaults.storyIntervalMin,
        (value) => AppSettings(storyIntervalMin: value),
      ),
      postIntervalMin: _validInt(
        stored[SettingsKeys.postIntervalMin],
        defaults.postIntervalMin,
        (value) => AppSettings(postIntervalMin: value),
      ),
      wifiOnly: _bool(stored[SettingsKeys.wifiOnly], defaults.wifiOnly),
      notifyStories: _bool(
        stored[SettingsKeys.notifyStories],
        defaults.notifyStories,
      ),
      notifyPosts: _bool(
        stored[SettingsKeys.notifyPosts],
        defaults.notifyPosts,
      ),
      notifyLogin: _bool(
        stored[SettingsKeys.notifyLogin],
        defaults.notifyLogin,
      ),
      retentionDays: _validRetention(stored[SettingsKeys.retentionDays]),
      appLockEnabled: _bool(
        stored[SettingsKeys.appLockEnabled],
        defaults.appLockEnabled,
      ),
      onboardingDone: _bool(
        stored[SettingsKeys.onboardingDone],
        defaults.onboardingDone,
      ),
      riskAcknowledgedAt: _instant(stored[SettingsKeys.riskAcknowledgedAt]),
      pageModeInBackground: _bool(
        stored[SettingsKeys.pageModeInBackground],
        defaults.pageModeInBackground,
      ),
      lastUpdateCheckAt: _instant(stored[SettingsKeys.lastUpdateCheckAt]),
    );
  }

  /// Writes only the fields that differ between [from] and [to].
  Future<void> _write({
    required AppSettings from,
    required AppSettings to,
  }) async {
    if (from.storyIntervalMin != to.storyIntervalMin) {
      await _prefs.setInt(SettingsKeys.storyIntervalMin, to.storyIntervalMin);
    }
    if (from.postIntervalMin != to.postIntervalMin) {
      await _prefs.setInt(SettingsKeys.postIntervalMin, to.postIntervalMin);
    }
    if (from.wifiOnly != to.wifiOnly) {
      await _prefs.setBool(SettingsKeys.wifiOnly, to.wifiOnly);
    }
    if (from.notifyStories != to.notifyStories) {
      await _prefs.setBool(SettingsKeys.notifyStories, to.notifyStories);
    }
    if (from.notifyPosts != to.notifyPosts) {
      await _prefs.setBool(SettingsKeys.notifyPosts, to.notifyPosts);
    }
    if (from.notifyLogin != to.notifyLogin) {
      await _prefs.setBool(SettingsKeys.notifyLogin, to.notifyLogin);
    }
    if (from.retentionDays != to.retentionDays) {
      await _setOrRemoveInt(SettingsKeys.retentionDays, to.retentionDays);
    }
    if (from.appLockEnabled != to.appLockEnabled) {
      await _prefs.setBool(SettingsKeys.appLockEnabled, to.appLockEnabled);
    }
    if (from.onboardingDone != to.onboardingDone) {
      await _prefs.setBool(SettingsKeys.onboardingDone, to.onboardingDone);
    }
    if (from.riskAcknowledgedAt != to.riskAcknowledgedAt) {
      await _setOrRemoveInstant(
        SettingsKeys.riskAcknowledgedAt,
        to.riskAcknowledgedAt,
      );
    }
    if (from.pageModeInBackground != to.pageModeInBackground) {
      await _prefs.setBool(
        SettingsKeys.pageModeInBackground,
        to.pageModeInBackground,
      );
    }
    if (from.lastUpdateCheckAt != to.lastUpdateCheckAt) {
      await _setOrRemoveInstant(
        SettingsKeys.lastUpdateCheckAt,
        to.lastUpdateCheckAt,
      );
    }
  }

  Future<void> _setOrRemoveInt(String key, int? value) =>
      value == null ? _prefs.remove(key) : _prefs.setInt(key, value);

  Future<void> _setOrRemoveInstant(String key, DateTime? value) => value == null
      ? _prefs.remove(key)
      : _prefs.setInt(key, value.toUtc().millisecondsSinceEpoch);
}

/// The stored int when it is an int and [asSettings] accepts it, else
/// [fallback]. The rules come from `AppSettings.validationErrors`.
int _validInt(
  Object? raw,
  int fallback,
  AppSettings Function(int value) asSettings,
) {
  if (raw is int && asSettings(raw).isValid) return raw;
  return fallback;
}

/// The stored retention when it is an int that `AppSettings` accepts, else
/// null (keep forever).
int? _validRetention(Object? raw) {
  if (raw is int && AppSettings(retentionDays: raw).isValid) return raw;
  return null;
}

bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;

/// The stored instant as UTC, or null when absent or out of range.
DateTime? _instant(Object? raw) {
  if (raw is! int || raw.abs() > _maxEpochMs) return null;
  return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
}
