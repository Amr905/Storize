import 'dart:async';

import 'package:storize_app/notifications/notification_lookups.dart';
import 'package:storize_app/notifications/notification_port.dart';

/// Records what the service asked the plugin to do.
final class FakeNotificationPort implements NotificationPort {
  /// Whether the system allows notifications.
  bool enabled = true;

  /// Makes [show] throw (the no-throw path).
  bool failShow = false;

  /// The payload that launched the app, if any.
  String? launch;

  /// Created channels, in order.
  final List<NotificationChannelSpec> channels = [];

  /// Posted notifications, in order.
  final List<NotificationRequest> shown = [];

  final StreamController<String> _taps = StreamController<String>.broadcast();

  /// Simulates a tap while the app runs.
  void tap(String payload) => _taps.add(payload);

  @override
  Future<void> createChannel(NotificationChannelSpec spec) async =>
      channels.add(spec);

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<void> show(NotificationRequest request) async {
    if (failShow) throw StateError('plugin down');
    shown.add(request);
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Stream<String> get taps => _taps.stream;
}

/// Fixed names and items for the service tests.
final class FakeNotificationLookups implements NotificationLookups {
  /// Usernames by target id (missing ids mean a deleted target).
  final Map<int, String> usernames = {};

  /// Content rows that still exist.
  final List<NewItem> items = [];

  @override
  Future<String?> usernameOf(int targetId) async => usernames[targetId];

  @override
  Future<List<NewItem>> itemsOf(List<int> contentIds) async => [
    for (final id in contentIds)
      for (final i in items)
        if (i.id == id) i,
  ];
}
