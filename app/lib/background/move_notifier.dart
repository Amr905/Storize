import 'package:flutter/widgets.dart' show Locale;
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/notifications/notification_port.dart';
import 'package:storize_app/notifications/notification_service.dart';
import 'package:storize_domain/storize_domain.dart';

/// Shows the progress of moving the saved files (FR-79) from the background
/// task. Never throws.
abstract interface class MoveNotifier {
  /// The move wrote [progress]. Called often; implementations throttle.
  Future<void> progress(MoveProgress progress);

  /// The run ended with [result]. Replaces the progress notice.
  Future<void> finished(MoveLibraryResult result);
}

/// [MoveNotifier] over the notification port: one silent notification on the
/// `background` channel, replaced as the move advances. No file names, paths
/// or usernames, only counts.
final class NotificationMoveNotifier implements MoveNotifier {
  /// Creates the notifier. [minInterval] is the shortest time between two
  /// progress updates.
  NotificationMoveNotifier({
    required this._port,
    required this._clock,
    this._log,
    this.minInterval = const Duration(seconds: 1),
  });

  /// The id of the move notification.
  static const int notificationId = 8;

  final NotificationPort _port;
  final Clock _clock;
  final DiagnosticLog? _log;

  /// The shortest time between two progress updates.
  final Duration minInterval;

  DateTime? _lastShown;

  static final AppLocalizations _strings = lookupAppLocalizations(
    const Locale('en'),
  );

  @override
  Future<void> progress(MoveProgress progress) async {
    final now = _clock.now();
    final last = _lastShown;
    if (last != null && now.difference(last) < minInterval) return;
    _lastShown = now;
    await _show(
      NotificationRequest(
        id: notificationId,
        channelId: NotificationChannels.background,
        title: _strings.ntfMoving(progress.handled, progress.total),
        silent: true,
      ),
    );
  }

  @override
  Future<void> finished(MoveLibraryResult result) async {
    _lastShown = null;
    final p = result.progress;
    switch (result.end) {
      case MoveEnd.deadline:
        // The task queues itself again: keep the progress notice.
        await _show(
          NotificationRequest(
            id: notificationId,
            channelId: NotificationChannels.background,
            title: _strings.ntfMoving(p.handled, p.total),
            silent: true,
          ),
        );
      case MoveEnd.cancelled:
        await _cancel();
      case MoveEnd.storageFull:
        await _show(
          NotificationRequest(
            id: notificationId,
            channelId: NotificationChannels.storage,
            title: _strings.ntfMoveStorageFull,
            payload: 'storize://settings/storage',
          ),
        );
      case MoveEnd.finished:
        await _show(
          NotificationRequest(
            id: notificationId,
            channelId: NotificationChannels.background,
            title: _strings.ntfMoveDone(p.moved),
            payload: 'storize://settings/storage',
            silent: true,
          ),
        );
    }
  }

  Future<void> _show(NotificationRequest request) async {
    try {
      if (!await _port.areEnabled()) return;
      await _port.show(request);
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> _cancel() async {
    try {
      await _port.cancel(notificationId);
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    // The type only.
    _log?.log(
      LogLevel.warn,
      'notifications',
      'move_notify_failed type=${error.runtimeType}',
    );
  }
}
