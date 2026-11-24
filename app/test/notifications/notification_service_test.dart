import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/notifications/notification_lookups.dart';
import 'package:storize_app/notifications/notification_port.dart';
import 'package:storize_app/notifications/notification_service.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import 'fake_notifications.dart';

final DateTime _t0 = DateTime.utc(2026, 11, 22, 9);

DownloadCounts _counts(
  int targetId,
  ContentKind kind, {
  int contents = 1,
  int files = 1,
}) => DownloadCounts(
  targetId: targetId,
  kind: kind,
  files: files,
  contents: contents,
  failed: 0,
  removed: 0,
);

DownloadPendingResult _saved(List<DownloadCounts> counts) =>
    DownloadPendingResult(
      stopReason: DownloadStopReason.completed,
      remaining: 0,
      counts: counts,
      failures: const [],
    );

CheckRunResult _check(List<int> ids, {String? errorCode}) => CheckRunResult(
  run: CheckRun(
    id: 1,
    scope: CheckScope.stories,
    trigger: CheckTrigger.periodic,
    startedAt: _t0,
    result: CheckResult.ok,
    errorCode: errorCode,
  ),
  newContentIds: ids,
);

final class _Rig {
  _Rig({AppSettings settings = const AppSettings()})
    : settings = FakeSettingsRepo(settings);

  final FakeSettingsRepo settings;
  final port = FakeNotificationPort();
  final lookups = FakeNotificationLookups();
  final log = FakeDiagnosticLog();

  late final service = NotificationService(
    port: port,
    settings: settings,
    lookups: lookups,
    log: log,
  );

  Iterable<NotificationRequest> get shown => port.shown;
}

void main() {
  group('channels (AC1)', () {
    test('creates the six channels with their importance', () async {
      final r = _Rig();
      await r.service.initialize();

      expect(
        {for (final c in r.port.channels) c.id: c.importance},
        {
          'new_stories': NotificationImportance.normal,
          'new_posts': NotificationImportance.normal,
          'login_problems': NotificationImportance.high,
          'storage': NotificationImportance.high,
          'background': NotificationImportance.low,
          'export': NotificationImportance.normal,
        },
      );
    });

    test('a failing channel creation does not throw', () async {
      final port = _ThrowingChannelPort();
      final service = NotificationService(
        port: port,
        settings: FakeSettingsRepo(),
        lookups: FakeNotificationLookups(),
      );
      await expectLater(service.initialize(), completes);
    });
  });

  group('grouped stories and posts (AC2, EC-8)', () {
    test('one notification per target plus a summary', () async {
      final r = _Rig()..lookups.usernames.addAll({1: 'nour_k', 2: 'brandx'});
      await r.service.newItemsSaved(
        _saved([
          _counts(1, ContentKind.story, contents: 3),
          _counts(2, ContentKind.story, contents: 5),
        ]),
      );

      final texts = [for (final n in r.shown) n.title];
      expect(texts, [
        '3 new stories from @nour_k',
        '5 new stories from @brandx',
        '8 new stories from 2 accounts',
      ]);
      final summary = r.shown.last;
      expect(summary.isGroupSummary, isTrue);
      expect(summary.groupKey, 'stories');
      expect(summary.id, NotificationIds.storiesSummary);
    });

    test(
      'highlights get their own group and ids on the stories channel',
      () async {
        final r = _Rig()..lookups.usernames.addAll({1: 'nour_k'});
        await r.service.newItemsSaved(
          _saved([
            _counts(1, ContentKind.story),
            _counts(1, ContentKind.highlight, contents: 4),
          ]),
        );
        final lines = r.shown.where((n) => !n.isGroupSummary).toList();
        expect(lines, hasLength(2));
        expect(lines[0].id, isNot(lines[1].id));
        expect(lines[1].groupKey, 'highlights');
        expect(lines[1].channelId, lines[0].channelId);
        final summaries = r.shown.where((n) => n.isGroupSummary).toList();
        expect(summaries.map((n) => n.id).toSet(), {
          NotificationIds.storiesSummary,
          NotificationIds.highlightsSummary,
        });
        expect(
          NotificationIds.forTarget(1, ContentKind.highlight),
          isNot(NotificationIds.forTarget(1, ContentKind.post)),
        );
      },
    );

    test('a single post target uses the singular texts', () async {
      final r = _Rig()..lookups.usernames[7] = 'brandx';
      await r.service.newItemsSaved(_saved([_counts(7, ContentKind.post)]));

      expect(r.shown.map((n) => n.title), [
        '1 new post from @brandx',
        '1 new post from 1 account',
      ]);
      expect(r.shown.first.channelId, 'new_posts');
    });

    test('a count of zero items posts nothing', () async {
      final r = _Rig()..lookups.usernames[1] = 'nour_k';
      await r.service.newItemsSaved(
        _saved([_counts(1, ContentKind.story, contents: 0, files: 0)]),
      );
      expect(r.shown, isEmpty);
    });

    test('a deleted target is left out of its per-target line', () async {
      final r = _Rig()..lookups.usernames[2] = 'brandx';
      await r.service.newItemsSaved(
        _saved([_counts(1, ContentKind.story), _counts(2, ContentKind.story)]),
      );
      expect(r.shown.map((n) => n.title), contains('1 new story from @brandx'));
      expect(
        r.shown.map((n) => n.title),
        isNot(contains('1 new story from @null')),
      );
    });
  });

  group('payloads per type (AC4)', () {
    test('the first new story opens S-06, the summary S-04', () async {
      final r = _Rig()..lookups.usernames[1] = 'nour_k';
      r.lookups.items.addAll([
        const NewItem(id: 41, targetId: 1, kind: ContentKind.story),
        const NewItem(id: 42, targetId: 1, kind: ContentKind.story),
      ]);
      await r.service.newItemsSaved(
        _saved([_counts(1, ContentKind.story, contents: 2)]),
        check: _check([41, 42]),
      );

      expect(r.shown.first.payload, 'storize://story/41');
      expect(r.shown.last.payload, 'storize://library?kind=stories');
    });

    test('the first new post opens S-15', () async {
      final r = _Rig()..lookups.usernames[3] = 'brandx';
      r.lookups.items.add(
        const NewItem(id: 9, targetId: 3, kind: ContentKind.post),
      );
      await r.service.newItemsSaved(
        _saved([_counts(3, ContentKind.post)]),
        check: _check([9]),
      );
      expect(r.shown.first.payload, 'storize://post/9');
      expect(r.shown.last.payload, 'storize://library?kind=posts');
    });

    test('without a known item it opens the target in S-04', () async {
      final r = _Rig()..lookups.usernames[3] = 'brandx';
      await r.service.newItemsSaved(_saved([_counts(3, ContentKind.post)]));
      expect(r.shown.first.payload, 'storize://library?kind=posts&target=3');
    });

    test('login and storage alerts open S-13 and S-12', () async {
      final r = _Rig();
      await r.service.sessionChanged(AccountStatus.needsRelogin);
      await r.service.storageFull();
      expect(r.shown.map((n) => n.payload), [
        'storize://account',
        'storize://settings/storage',
      ]);
    });
  });

  group('toggles (AC5, FR-42)', () {
    test('notifyStories off silences stories, not posts', () async {
      final r = _Rig(settings: const AppSettings(notifyStories: false))
        ..lookups.usernames.addAll({1: 'a', 2: 'b'});
      await r.service.newItemsSaved(
        _saved([_counts(1, ContentKind.story), _counts(2, ContentKind.post)]),
      );
      expect(r.shown.map((n) => n.channelId), everyElement('new_posts'));
    });

    test('notifyPosts off silences posts', () async {
      final r = _Rig(settings: const AppSettings(notifyPosts: false))
        ..lookups.usernames[2] = 'b';
      await r.service.newItemsSaved(_saved([_counts(2, ContentKind.post)]));
      expect(r.shown, isEmpty);
    });

    test('notifyLogin off silences the login alert', () async {
      final r = _Rig(settings: const AppSettings(notifyLogin: false));
      await r.service.sessionChanged(AccountStatus.restricted);
      expect(r.shown, isEmpty);
    });

    test('the storage alert has no toggle', () async {
      final r = _Rig(settings: const AppSettings(notifyLogin: false));
      await r.service.storageFull();
      expect(r.shown.single.channelId, 'storage');
    });
  });

  group('login and storage alerts (AC3)', () {
    test('needsRelogin and restricted post the high login alert', () async {
      final r = _Rig();
      await r.service.sessionChanged(AccountStatus.needsRelogin);
      await r.service.sessionChanged(AccountStatus.restricted);
      expect(r.shown.map((n) => n.channelId), [
        'login_problems',
        'login_problems',
      ]);
      expect(
        r.shown.first.title,
        'Instagram login needs attention — checks are paused',
      );
    });

    test('an active status posts nothing', () async {
      final r = _Rig();
      await r.service.sessionChanged(AccountStatus.active);
      expect(r.shown, isEmpty);
    });

    test('storage posts the storage alert text', () async {
      final r = _Rig();
      await r.service.storageFull();
      expect(r.shown.single.title, 'Storage almost full — downloads paused');
      expect(r.shown.single.channelId, 'storage');
    });
  });

  group('permission and failure paths (AC6)', () {
    test('disabled notifications post nothing, for every type', () async {
      final r = _Rig()..port.enabled = false;
      r.lookups.usernames[1] = 'a';
      await r.service.newItemsSaved(_saved([_counts(1, ContentKind.story)]));
      await r.service.sessionChanged(AccountStatus.needsRelogin);
      await r.service.storageFull();
      expect(r.shown, isEmpty);
    });

    test('a failing show never throws and is logged by type only', () async {
      final r = _Rig()..port.failShow = true;
      r.lookups.usernames[1] = 'nour_k';
      await expectLater(
        r.service.newItemsSaved(_saved([_counts(1, ContentKind.story)])),
        completes,
      );
      await expectLater(r.service.storageFull(), completes);
      final entries = r.log.at(LogLevel.warn);
      expect(entries, isNotEmpty);
      for (final e in entries) {
        expect(e.message, isNot(contains('nour_k')));
        expect(e.message, contains('StateError'));
      }
    });

    test('a failing settings read never throws', () async {
      final service = NotificationService(
        port: FakeNotificationPort(),
        settings: _BrokenSettings(),
        lookups: FakeNotificationLookups(),
      );
      await expectLater(
        service.newItemsSaved(_saved([_counts(1, ContentKind.story)])),
        completes,
      );
    });
  });

  group('tap routing and cold start (AC4)', () {
    test('every payload type maps to its in-app location', () {
      expect(locationForPayload('storize://story/41'), '/story/41');
      expect(locationForPayload('storize://post/9'), '/post/9');
      expect(locationForPayload('storize://account'), '/account');
      expect(
        locationForPayload('storize://library?kind=posts&target=3'),
        '/library?kind=posts&target=3',
      );
      expect(
        locationForPayload('storize://settings/storage'),
        '/settings?section=storage',
      );
    });

    test('a foreign or broken URI maps to nothing or to the Library', () {
      expect(locationForPayload('https://example.com/x'), isNull);
      expect(locationForPayload('storize://story/abc'), '/library');
    });

    test('a tap while running emits the location', () async {
      final r = _Rig();
      final next = r.service.taps.first;
      r.port.tap('storize://post/9');
      expect(await next, '/post/9');
    });

    test('the launch payload becomes the start location', () async {
      final r = _Rig()..port.launch = 'storize://story/41';
      expect(await r.service.launchLocation(), '/story/41');
    });

    test('no launch payload means no start location', () async {
      final r = _Rig();
      expect(await r.service.launchLocation(), isNull);
    });
  });
}

final class _ThrowingChannelPort implements NotificationPort {
  @override
  Future<void> createChannel(NotificationChannelSpec spec) async =>
      throw StateError('channel');

  @override
  Future<bool> areEnabled() async => true;

  @override
  Future<void> show(NotificationRequest request) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Stream<String> get taps => const Stream.empty();
}

final class _BrokenSettings implements SettingsRepo {
  @override
  Future<AppSettings> get() async => throw StateError('prefs');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
