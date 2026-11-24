/// The thin seam between the notification service and the plugin.
///
/// Nothing above this file imports `flutter_local_notifications`, so the
/// service and the background code are tested with a fake port.
library;

/// The importance of a channel, mapped to the plugin's levels.
enum NotificationImportance {
  /// Shows with sound (new stories, new posts, exports).
  normal,

  /// Login and storage alerts (TECH_SPEC section 4.3, "high").
  high,

  /// Silent progress (`background`).
  low,
}

/// One notification channel of the app (TECH_SPEC section 4.3).
final class NotificationChannelSpec {
  /// Creates a channel spec.
  const NotificationChannelSpec({
    required this.id,
    required this.name,
    required this.importance,
  });

  /// The channel id: `new_stories`, `new_posts`, `login_problems`, `storage`,
  /// `background` or `export`.
  final String id;

  /// The name the user sees in the system settings (already localised).
  final String name;

  /// How loud the channel is.
  final NotificationImportance importance;
}

/// One notification to show. Carries no plugin types.
final class NotificationRequest {
  /// Creates a request.
  const NotificationRequest({
    required this.id,
    required this.channelId,
    required this.title,
    this.payload,
    this.groupKey,
    this.isGroupSummary = false,
    this.silent = false,
  });

  /// The notification id. The same id replaces the earlier notification.
  final int id;

  /// The channel id (one of the [NotificationChannelSpec] ids).
  final String channelId;

  /// The text shown.
  final String title;

  /// A `storize://` URI opened on tap, or null for no tap action.
  final String? payload;

  /// The Android group this notification belongs to, if any.
  final String? groupKey;

  /// True for the summary of [groupKey].
  final bool isGroupSummary;

  /// True for a notification without sound or vibration.
  final bool silent;
}

/// The operations the service needs from the notification plugin.
abstract interface class NotificationPort {
  /// Creates the channels (idempotent). Never throws.
  Future<void> createChannel(NotificationChannelSpec spec);

  /// Whether the system lets this app post notifications (POST_NOTIFICATIONS,
  /// requested at S-03). Returns false when unknown.
  Future<bool> areEnabled();

  /// Posts or replaces a notification.
  Future<void> show(NotificationRequest request);

  /// Removes the notification with [id], if it is showing. Never throws.
  Future<void> cancel(int id);

  /// The payload of the notification that launched the app, or null.
  Future<String?> launchPayload();

  /// Payloads of notifications tapped while the app runs.
  Stream<String> get taps;
}
