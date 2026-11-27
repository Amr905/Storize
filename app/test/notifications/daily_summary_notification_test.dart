import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/notifications/notification_port.dart';
import 'package:storize_app/notifications/notification_service.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import 'fake_notifications.dart';

DownloadPendingResult _saved(List<DownloadCounts> counts) =>
    DownloadPendingResult(
      stopReason: DownloadStopReason.completed,
      remaining: 0,
      counts: counts,
      failures: const [],
    );

DownloadCounts _counts(int targetId, ContentKind kind, {int contents = 1}) =>
    DownloadCounts(
      targetId: targetId,
      kind: kind,
      files: contents,
      contents: contents,
      failed: 0,
      removed: 0,
    );

final class _Rig {
  _Rig(AppSettings settings) : settings = FakeSettingsRepo(settings) {
    service = NotificationService(
      port: port,
      settings: this.settings,
      lookups: lookups,
      log: log,
    );
  }

  final FakeSettingsRepo settings;
  final FakeNotificationPort port = FakeNotificationPort();
  final FakeNotificationLookups lookups = FakeNotificationLookups()
    ..usernames.addAll({1: 'nour_k', 2: 'brandx'});
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  late final NotificationService service;

  Iterable<NotificationRequest> get shown => port.shown;
}

void main() {
  group('FR-78 gating of per-item notifications', () {
    final saved = _saved([_counts(1, ContentKind.story, contents: 2)]);

    test('per item (the default) shows the per-item notifications', () async {
      final r = _Rig(const AppSettings());
      await r.service.newItemsSaved(saved);
      expect(r.shown, isNotEmpty);
    });

    test('daily and off show no per-item content notification', () async {
      for (final mode in [NotificationMode.daily, NotificationMode.off]) {
        final r = _Rig(AppSettings(notificationMode: mode));
        await r.service.newItemsSaved(saved);
        expect(r.shown, isEmpty, reason: mode.name);
      }
    });

    test('the per-item toggles do not matter outside per item', () async {
      final r = _Rig(
        const AppSettings(
          notificationMode: NotificationMode.daily,
        ),
      );
      await r.service.newItemsSaved(saved);
      expect(r.shown, isEmpty);
    });

    test('problem notifications still fire in daily and off', () async {
      for (final mode in [NotificationMode.daily, NotificationMode.off]) {
        final r = _Rig(AppSettings(notificationMode: mode));
        await r.service.sessionChanged(AccountStatus.needsRelogin);
        await r.service.storageFull();
        expect(
          [for (final n in r.shown) n.id],
          [NotificationIds.login, NotificationIds.storage],
          reason: mode.name,
        );
      }
    });
  });

  group('FR-78 daily summary text and delivery', () {
    Future<String> textFor(SavedCounts counts) async {
      final r = _Rig(
        const AppSettings(notificationMode: NotificationMode.daily),
      );
      await r.service.dailySummary(counts);
      return r.shown.single.title;
    }

    test('stories and posts from accounts', () async {
      expect(
        await textFor(
          const SavedCounts(stories: 5, posts: 2, highlights: 0, accounts: 3),
        ),
        'Today: 5 stories and 2 posts saved from 3 accounts',
      );
    });

    test('singular forms', () async {
      expect(
        await textFor(
          const SavedCounts(stories: 1, posts: 1, highlights: 0, accounts: 1),
        ),
        'Today: 1 story and 1 post saved from 1 account',
      );
    });

    test('a single kind names only that kind', () async {
      expect(
        await textFor(
          const SavedCounts(stories: 4, posts: 0, highlights: 0, accounts: 2),
        ),
        'Today: 4 stories saved from 2 accounts',
      );
      expect(
        await textFor(
          const SavedCounts(stories: 0, posts: 2, highlights: 0, accounts: 1),
        ),
        'Today: 2 posts saved from 1 account',
      );
    });

    test('highlights are added when there are other items', () async {
      expect(
        await textFor(
          const SavedCounts(stories: 5, posts: 2, highlights: 1, accounts: 3),
        ),
        'Today: 5 stories and 2 posts saved from 3 accounts, and 1 highlight',
      );
    });

    test('highlights alone get their own line', () async {
      expect(
        await textFor(
          const SavedCounts(stories: 0, posts: 0, highlights: 3, accounts: 1),
        ),
        'Today: 3 highlights saved from 1 account',
      );
    });

    test('uses its own id, the daily channel and opens the Library', () async {
      final r = _Rig(
        const AppSettings(notificationMode: NotificationMode.daily),
      );
      await r.service.initialize();
      await r.service.dailySummary(
        const SavedCounts(stories: 1, posts: 0, highlights: 0, accounts: 1),
      );
      final n = r.shown.single;
      expect(n.id, NotificationIds.dailySummary);
      expect(n.channelId, NotificationChannels.dailySummary);
      expect(n.payload, 'storize://library');
      expect(locationForPayload(n.payload!), isNotNull);
      expect(
        {
          for (final c in r.port.channels) c.id: c.importance,
        }[NotificationChannels.dailySummary],
        NotificationImportance.low,
      );
    });

    test('zero items shows nothing', () async {
      final r = _Rig(
        const AppSettings(notificationMode: NotificationMode.daily),
      );
      await r.service.dailySummary(
        const SavedCounts(stories: 0, posts: 0, highlights: 0, accounts: 0),
      );
      expect(r.shown, isEmpty);
    });

    test('no permission shows nothing', () async {
      final r = _Rig(
        const AppSettings(notificationMode: NotificationMode.daily),
      );
      r.port.enabled = false;
      await r.service.dailySummary(
        const SavedCounts(stories: 1, posts: 0, highlights: 0, accounts: 1),
      );
      expect(r.shown, isEmpty);
    });

    test('a failing plugin never throws and is logged by type', () async {
      final r = _Rig(
        const AppSettings(notificationMode: NotificationMode.daily),
      );
      r.port.failShow = true;
      await expectLater(
        r.service.dailySummary(
          const SavedCounts(stories: 1, posts: 0, highlights: 0, accounts: 1),
        ),
        completes,
      );
      expect(
        r.log.entries.any((e) => e.message.contains('daily_summary')),
        isTrue,
      );
    });
  });
}
