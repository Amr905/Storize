import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

final DateTime _t0 = DateTime.utc(2026, 11, 24, 8);

typedef _Enq = ({Duration delay, bool fromHistoryTask});

final class _Enqueuer implements DownloadEnqueuer {
  final List<_Enq> history = [];

  @override
  Future<void> enqueueDownload({required bool wifiOnly}) async {}

  @override
  Future<void> enqueueHistory({
    required bool wifiOnly,
    required Duration delay,
    bool fromHistoryTask = false,
  }) async => history.add((delay: delay, fromHistoryTask: fromHistoryTask));
}

final class _Recorder implements TaskNotifier {
  final List<AccountStatus> sessions = [];

  @override
  Future<void> newItemsSaved(
    DownloadPendingResult downloads, {
    CheckRunResult? check,
  }) async {}

  @override
  Future<void> sessionChanged(AccountStatus status) async =>
      sessions.add(status);

  @override
  Future<void> storageFull() async {}

  @override
  Future<void> checkingStarted(int accounts) async {}

  @override
  Future<void> checkingDone() async {}
}

final class _Rig {
  final settings = FakeSettingsRepo();
  final clock = FakeClock(_t0);
  final enqueuer = _Enqueuer();
  final notifier = _Recorder();
  final order = <String>[];
  final policies = <ExtractionPolicy?>[];
  BackfillPassResult pass = const BackfillPassResult(
    running: 0,
    newContentIds: [],
  );
  bool probeResult = false;
  Duration? probeStale;
  HighlightsResult highlights = const HighlightsResult(
    HighlightsOutcome.synced,
  );
  Exception? highlightsThrow;

  late final TaskRouter router = TaskRouter(
    runCheck: ({required scope, required trigger, targetId, deadline}) async {
      order.add('check-${scope.name}');
      return CheckRunResult(
        run: CheckRun(
          id: 1,
          scope: scope,
          trigger: trigger,
          startedAt: _t0,
          result: CheckResult.ok,
        ),
        newContentIds: const [],
      );
    },
    download: ({deadline, policy = ExtractionPolicy.directOnly}) async {
      order.add('download');
      return DownloadPendingResult(
        stopReason: DownloadStopReason.completed,
        remaining: 0,
        counts: const [],
        failures: const [],
      );
    },
    retention: () async => null,
    updateCheck: () async => null,
    settings: settings,
    clock: clock,
    enqueuer: enqueuer,
    notifier: notifier,
    history: ({policy, deadline}) async {
      order.add('history');
      policies.add(policy);
      return pass;
    },
    historyProbe: ({staleFor}) async {
      probeStale = staleFor;
      return probeResult;
    },
    highlights: ({targetId, policy, deadline}) async {
      order.add('highlights');
      final e = highlightsThrow;
      if (e != null) throw e;
      return highlights;
    },
  );
}

void main() {
  group('history task', () {
    test('runs one pass, then the downloads', () async {
      final r = _Rig();
      expect(await r.router.route(TaskNames.history), isTrue);
      expect(r.order, ['history', 'download']);
      expect(r.policies.single, ExtractionPolicy.directOnly);
      expect(r.enqueuer.history, isEmpty);
    });

    test('re-enqueues itself with a short delay while running', () async {
      final r = _Rig()
        ..pass = const BackfillPassResult(running: 2, newContentIds: []);
      await r.router.route(TaskNames.history);
      expect(r.enqueuer.history, [
        (delay: TaskRouter.historyDelay, fromHistoryTask: true),
      ]);
    });

    test('waits longer after a rate limit', () async {
      final r = _Rig()
        ..pass = const BackfillPassResult(
          running: 1,
          newContentIds: [],
          rateLimited: true,
        );
      await r.router.route(TaskNames.history);
      expect(r.enqueuer.history.single.delay, TaskRouter.historyRateLimitDelay);
    });

    test('T-047: a deferred pass waits 30 min, not 1 min', () async {
      final r = _Rig()
        ..pass = const BackfillPassResult(
          running: 1,
          newContentIds: [],
          deferred: true,
        );
      await r.router.route(TaskNames.history);
      expect(r.enqueuer.history.single.delay, TaskRouter.historyDeferredDelay);
      expect(TaskRouter.historyDeferredDelay, const Duration(minutes: 30));
      expect(
        TaskRouter.historyDeferredDelay,
        greaterThan(TaskRouter.historyRateLimitDelay),
      );
    });

    test('a lost session ends the chain and notifies', () async {
      final r = _Rig()
        ..pass = const BackfillPassResult(
          running: 1,
          newContentIds: [],
          sessionStatus: AccountStatus.needsRelogin,
        );
      expect(await r.router.route(TaskNames.history), isTrue);
      expect(r.enqueuer.history, isEmpty);
      expect(r.notifier.sessions, [AccountStatus.needsRelogin]);
    });

    test('an inactive session does not re-enqueue', () async {
      final r = _Rig()
        ..pass = const BackfillPassResult(
          running: 1,
          newContentIds: [],
          sessionInactive: true,
        );
      await r.router.route(TaskNames.history);
      expect(r.enqueuer.history, isEmpty);
    });

    test('a network failure asks for back-off, not a second task', () async {
      final r = _Rig()
        ..pass = const BackfillPassResult(
          running: 1,
          newContentIds: [],
          network: true,
        );
      expect(await r.router.route(TaskNames.history), isFalse);
      expect(r.enqueuer.history, isEmpty);
    });

    test('page mode in background selects directThenPage', () async {
      final r = _Rig();
      await r.settings.update((s) => s.copyWith(pageModeInBackground: true));
      await r.router.route(TaskNames.history);
      expect(r.policies.single, ExtractionPolicy.directThenPage);
    });
  });

  group('check-posts (T-040)', () {
    test('syncs highlights, then downloads, then probes history', () async {
      final r = _Rig()..probeResult = true;
      expect(await r.router.route(TaskNames.checkPosts), isTrue);
      expect(r.order, ['check-posts', 'highlights', 'download']);
      expect(r.probeStale, TaskRouter.historyStale);
      expect(r.enqueuer.history, [
        (delay: TaskRouter.historyDelay, fromHistoryTask: false),
      ]);
    });

    test('no running backfill: no history task', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkPosts);
      expect(r.enqueuer.history, isEmpty);
    });

    test('the stories check neither syncs highlights nor kicks', () async {
      final r = _Rig()..probeResult = true;
      await r.router.route(TaskNames.checkStories);
      expect(r.order, ['check-stories', 'download']);
      expect(r.enqueuer.history, isEmpty);
    });

    test('a highlights failure does not lose the downloads', () async {
      final r = _Rig()..highlightsThrow = Exception('boom');
      expect(await r.router.route(TaskNames.checkPosts), isTrue);
      expect(r.order, ['check-posts', 'highlights', 'download']);
    });

    test('a highlights session failure notifies', () async {
      final r = _Rig()
        ..highlights = const HighlightsResult(
          HighlightsOutcome.sessionInvalid,
          sessionStatus: AccountStatus.needsRelogin,
        );
      await r.router.route(TaskNames.checkPosts);
      expect(r.notifier.sessions, [AccountStatus.needsRelogin]);
    });
  });
}
