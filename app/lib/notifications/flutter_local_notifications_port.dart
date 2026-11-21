import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:storize_app/notifications/notification_port.dart';

/// The [NotificationPort] over `flutter_local_notifications` (Android).
///
/// Every call is guarded: the plugin's failures are swallowed here so a
/// notification can never break a check or a screen.
final class FlutterLocalNotificationsPort implements NotificationPort {
  /// Creates the port. [plugin] is injectable for the plugin's own tests only.
  FlutterLocalNotificationsPort([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The launcher icon, used as the small icon.
  static const String _icon = '@mipmap/ic_launcher';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _taps = StreamController<String>.broadcast();
  Future<void>? _initialized;

  Future<void> _init() => _initialized ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      )
      .then<void>((_) {})
      .catchError((Object _) {});

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty && !_taps.isClosed) {
      _taps.add(payload);
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> createChannel(NotificationChannelSpec spec) async {
    try {
      await _init();
      await _android?.createNotificationChannel(
        AndroidNotificationChannel(
          spec.id,
          spec.name,
          importance: _importance(spec.importance),
          playSound: spec.importance != NotificationImportance.low,
          enableVibration: spec.importance != NotificationImportance.low,
        ),
      );
    } on Object {
      // Channels are retried on the next call; nothing else to do.
    }
  }

  @override
  Future<bool> areEnabled() async {
    try {
      await _init();
      return await _android?.areNotificationsEnabled() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> show(NotificationRequest request) async {
    try {
      await _init();
      await _plugin.show(
        id: request.id,
        title: request.title,
        payload: request.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            request.channelId,
            request.channelId,
            groupKey: request.groupKey,
            setAsGroupSummary: request.isGroupSummary,
            silent: request.silent,
          ),
        ),
      );
    } on Object {
      // Never throw from a notification (T-022 AC6).
    }
  }

  @override
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      final payload = details?.notificationResponse?.payload;
      return (payload == null || payload.isEmpty) ? null : payload;
    } on Object {
      return null;
    }
  }

  @override
  Stream<String> get taps => _taps.stream;

  static Importance _importance(NotificationImportance i) => switch (i) {
    NotificationImportance.normal => Importance.defaultImportance,
    NotificationImportance.high => Importance.high,
    NotificationImportance.low => Importance.low,
  };
}
