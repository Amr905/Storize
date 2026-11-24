import 'package:flutter/widgets.dart' show Locale;
import 'package:storize_app/background/task_router.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/notifications/notification_lookups.dart';
import 'package:storize_app/notifications/notification_port.dart';
import 'package:storize_app/router/deep_link.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Channel ids (TECH_SPEC section 4.3).
abstract final class NotificationChannels {
  /// New stories, grouped per target (default importance).
  static const String newStories = 'new_stories';

  /// New posts, grouped per target (default importance).
  static const String newPosts = 'new_posts';

  /// Login problems (high).
  static const String loginProblems = 'login_problems';

  /// Storage (high).
  static const String storage = 'storage';

  /// Silent progress.
  static const String background = 'background';

  /// Exports (T-035).
  static const String export = 'export';
}

/// Fixed notification ids. Per-target ids sit above [targetBase].
abstract final class NotificationIds {
  /// Summary of the story group.
  static const int storiesSummary = 1;

  /// Summary of the post group.
  static const int postsSummary = 2;

  /// Login alert.
  static const int login = 3;

  /// Storage alert.
  static const int storage = 4;

  /// Silent check progress.
  static const int checking = 5;

  /// Summary of the highlight group.
  static const int highlightsSummary = 6;

  /// First id of the per-target notifications.
  static const int targetBase = 1000;

  /// The id of the notification of [targetId] and [kind] (one per target and
  /// kind, so a newer run replaces the older one).
  static int forTarget(int targetId, ContentKind kind) =>
      targetBase +
      (targetId & 0x3fffffff) * 3 +
      switch (kind) {
        ContentKind.story => 0,
        ContentKind.post => 1,
        ContentKind.highlight => 2,
      };
}

/// The location a notification payload opens (for the router).
///
/// Returns null for anything that is not a `storize://` link.
String? locationForPayload(String payload) {
  final uri = Uri.tryParse(payload);
  if (uri == null) return null;
  return DeepLink.parse(uri)?.location;
}

/// Shows the app's notifications (T-022, FR-40…FR-42, FR-66, EC-8).
///
/// Every public method is guarded: a failure is logged by type only and never
/// thrown, so a notification cannot break a check or a download. Usernames
/// appear in the notification text only, never in the log.
final class NotificationService implements TaskNotifier {
  /// Creates the service.
  NotificationService({
    required this._port,
    required this._settings,
    required this._lookups,
    this._log,
  });

  final NotificationPort _port;
  final SettingsRepo _settings;
  final NotificationLookups _lookups;
  final DiagnosticLog? _log;

  /// The English strings. Background isolates have no BuildContext, so the
  /// strings are looked up directly (the app ships English only in MVP).
  static final AppLocalizations _strings = lookupAppLocalizations(
    const Locale('en'),
  );

  /// The channels of TECH_SPEC section 4.3, with their localised names.
  List<NotificationChannelSpec> get channels => [
    NotificationChannelSpec(
      id: NotificationChannels.newStories,
      name: _strings.ntfChannelNewStories,
      importance: NotificationImportance.normal,
    ),
    NotificationChannelSpec(
      id: NotificationChannels.newPosts,
      name: _strings.ntfChannelNewPosts,
      importance: NotificationImportance.normal,
    ),
    NotificationChannelSpec(
      id: NotificationChannels.loginProblems,
      name: _strings.ntfChannelLoginProblems,
      importance: NotificationImportance.high,
    ),
    NotificationChannelSpec(
      id: NotificationChannels.storage,
      name: _strings.ntfChannelStorage,
      importance: NotificationImportance.high,
    ),
    NotificationChannelSpec(
      id: NotificationChannels.background,
      name: _strings.ntfChannelBackground,
      importance: NotificationImportance.low,
    ),
    NotificationChannelSpec(
      id: NotificationChannels.export,
      name: _strings.ntfChannelExport,
      importance: NotificationImportance.normal,
    ),
  ];

  /// Payloads of notifications tapped while the app runs, as in-app locations.
  Stream<String> get taps => _port.taps
      .map(locationForPayload)
      .where((location) => location != null)
      .cast<String>();

  /// The in-app location of the notification that launched the app, or null.
  Future<String?> launchLocation() async {
    try {
      final payload = await _port.launchPayload();
      return payload == null ? null : locationForPayload(payload);
    } on Object catch (error) {
      _logFailure('launch', error);
      return null;
    }
  }

  /// Creates the channels. Safe to call more than once; never throws.
  Future<void> initialize() async {
    try {
      for (final spec in channels) {
        await _port.createChannel(spec);
      }
    } on Object catch (error) {
      _logFailure('initialize', error);
    }
  }

  @override
  Future<void> newItemsSaved(
    DownloadPendingResult downloads, {
    CheckRunResult? check,
  }) async {
    try {
      final counts = [
        for (final c in downloads.counts)
          if (c.contents > 0) c,
      ];
      if (counts.isEmpty) return;
      final settings = await _settings.get();
      final wanted = [
        for (final c in counts)
          if (c.kind != ContentKind.post
              ? settings.notifyStories
              : settings.notifyPosts)
            c,
      ];
      if (wanted.isEmpty || !await _port.areEnabled()) return;

      final items = await _lookups.itemsOf(check?.newContentIds ?? const []);
      for (final kind in ContentKind.values) {
        final group = [
          for (final c in wanted)
            if (c.kind == kind) c,
        ];
        if (group.isEmpty) continue;
        // A highlight uses the stories channel and texts, with its own group
        // and ids.
        final isStory = kind != ContentKind.post;
        final channel = isStory
            ? NotificationChannels.newStories
            : NotificationChannels.newPosts;
        final groupKey = switch (kind) {
          ContentKind.story => 'stories',
          ContentKind.post => 'posts',
          ContentKind.highlight => 'highlights',
        };

        for (final c in group) {
          final username = await _lookups.usernameOf(c.targetId);
          if (username == null) continue;
          final first = items.where(
            (i) => i.targetId == c.targetId && i.kind == kind,
          );
          final payload = first.isEmpty
              ? _libraryPayload(kind, c.targetId)
              : (isStory ? _storyPayload : _postPayload)(first.first.id);
          final title = isStory
              ? _strings.ntfStoriesFromAccount(c.contents, username)
              : _strings.ntfPostsFromAccount(c.contents, username);
          await _port.show(
            NotificationRequest(
              id: NotificationIds.forTarget(c.targetId, kind),
              channelId: channel,
              title: title,
              payload: payload,
              groupKey: groupKey,
            ),
          );
        }

        final total = group.fold<int>(0, (a, c) => a + c.contents);
        final accounts = group.map((c) => c.targetId).toSet().length;
        final summary = isStory
            ? _strings.ntfStoriesSummary(total, accounts)
            : _strings.ntfPostsSummary(total, accounts);
        await _port.show(
          NotificationRequest(
            id: switch (kind) {
              ContentKind.story => NotificationIds.storiesSummary,
              ContentKind.post => NotificationIds.postsSummary,
              ContentKind.highlight => NotificationIds.highlightsSummary,
            },
            channelId: channel,
            title: summary,
            payload: _libraryPayload(kind, null),
            groupKey: groupKey,
            isGroupSummary: true,
          ),
        );
      }
    } on Object catch (error) {
      _logFailure('new_items', error);
    }
  }

  @override
  Future<void> sessionChanged(AccountStatus status) async {
    try {
      if (status != AccountStatus.needsRelogin &&
          status != AccountStatus.restricted) {
        return;
      }
      if (!(await _settings.get()).notifyLogin) return;
      if (!await _port.areEnabled()) return;
      await _port.show(
        NotificationRequest(
          id: NotificationIds.login,
          channelId: NotificationChannels.loginProblems,
          title: _strings.ntfLoginNeeded,
          payload: 'storize://account',
        ),
      );
    } on Object catch (error) {
      _logFailure('login', error);
    }
  }

  @override
  Future<void> storageFull() async {
    try {
      if (!await _port.areEnabled()) return;
      await _port.show(
        NotificationRequest(
          id: NotificationIds.storage,
          channelId: NotificationChannels.storage,
          title: _strings.ntfStorageFull,
          payload: 'storize://settings/storage',
        ),
      );
    } on Object catch (error) {
      _logFailure('storage', error);
    }
  }

  /// Shows the silent "Checking N accounts" notification (channel
  /// `background`). `TaskRouter` posts it through [checkingStarted] while a
  /// check runs and removes it with [checkingDone].
  Future<void> showChecking(int accounts) async {
    try {
      if (!await _port.areEnabled()) return;
      await _port.show(
        NotificationRequest(
          id: NotificationIds.checking,
          channelId: NotificationChannels.background,
          title: _strings.ntfChecking(accounts),
          silent: true,
        ),
      );
    } on Object catch (error) {
      _logFailure('checking', error);
    }
  }

  /// Removes the "Checking N accounts" notification. Never throws.
  Future<void> hideChecking() async {
    try {
      await _port.cancel(NotificationIds.checking);
    } on Object catch (error) {
      _logFailure('checking_hide', error);
    }
  }

  @override
  Future<void> checkingStarted(int accounts) => showChecking(accounts);

  @override
  Future<void> checkingDone() => hideChecking();

  static String _storyPayload(int id) => 'storize://story/$id';

  static String _postPayload(int id) => 'storize://post/$id';

  static String _libraryPayload(ContentKind kind, int? targetId) {
    final kindName = kind == ContentKind.story ? 'stories' : 'posts';
    final target = targetId == null ? '' : '&target=$targetId';
    return 'storize://library?kind=$kindName$target';
  }

  void _logFailure(String step, Object error) {
    // The type only: messages can carry usernames or URLs.
    _log?.log(
      LogLevel.warn,
      'notifications',
      'notify_failed step=$step type=${error.runtimeType}',
    );
  }
}
