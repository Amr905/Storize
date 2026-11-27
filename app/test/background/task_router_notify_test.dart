import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

final DateTime _t0 = DateTime.utc(2026, 11, 22, 9);

CheckRunResult _checked({String? errorCode, List<int> ids = const []}) =>
    CheckRunResult(
      run: CheckRun(
        id: 1,
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: _t0,
        result: errorCode == null ? CheckResult.ok : CheckResult.failed,
        errorCode: errorCode,
      ),
      newContentIds: ids,
    );

DownloadPendingResult _downloaded(
  DownloadStopReason reason, {
  List<DownloadCounts> counts = const [],
}) => DownloadPendingResult(
  stopReason: reason,
  remaining: 0,
  counts: counts,
  failures: const [],
);

final class _RecordingNotifier implements TaskNotifier {
  final List<String> calls = [];
  final List<SavedCounts> summaries = [];

  @override
  Future<void> dailySummary(SavedCounts counts) async {
    summaries.add(counts);
    calls.add('daily_summary');
  }

  final List<CheckRunResult?> checksSeen = [];
  AccountStatus? status;
  bool throws = false;
  bool failChecking = false;

  @override
  Future<void> newItemsSaved(
    DownloadPendingResult downloads, {
    CheckRunResult? check,
  }) async {
    calls.add('items');
    checksSeen.add(check);
    if (throws) throw StateError('notifier');
  }

  @override
  Future<void> sessionChanged(AccountStatus status) async {
    calls.add('session');
    this.status = status;
  }

  @override
  Future<void> storageFull() async => calls.add('storage');

  @override
  Future<void> checkingStarted(int accounts) async {
    calls.add('start:$accounts');
    if (failChecking) throw StateError('notifier');
  }

  @override
  Future<void> checkingDone() async {
    calls.add('done');
    if (failChecking) throw StateError('notifier');
  }
}

final class _Rig {
  _Rig({this.notifier = true, this.active});

  final bool notifier;

  /// Active targets of the scope; null leaves the notice unwired.
  final int? active;
  Exception? checkThrows;
  final recorder = _RecordingNotifier();
  final log = FakeDiagnosticLog();
  CheckRunResult checkResult = _checked();
  DownloadPendingResult downloadResult = _downloaded(
    DownloadStopReason.completed,
  );

  late final TaskRouter router = TaskRouter(
    runCheck: ({required scope, required trigger, targetId, deadline}) async {
      if (active != null) recorder.calls.add('check');
      final e = checkThrows;
      if (e != null) throw e;
      return checkResult;
    },
    activeTargets: active == null ? null : (scope, targetId) async => active!,
    download: ({deadline, policy = ExtractionPolicy.directOnly}) async =>
        downloadResult,
    retention: () async => null,
    updateCheck: () async => null,
    settings: FakeSettingsRepo(),
    clock: FakeClock(_t0),
    enqueuer: _NoEnqueue(),
    log: log,
    notifier: notifier ? recorder : null,
  );
}

final class _NoEnqueue implements DownloadEnqueuer {
  @override
  Future<void> enqueueDownload({required bool wifiOnly}) async {}

  @override
  Future<void> enqueueHistory({
    required bool wifiOnly,
    required Duration delay,
    bool fromHistoryTask = false,
  }) async {}
}

void main() {
  group('new items hook (EC-8)', () {
    test('a check notifies the saved items with its check result', () async {
      final r = _Rig()
        ..downloadResult = _downloaded(
          DownloadStopReason.completed,
          counts: const [
            DownloadCounts(
              targetId: 1,
              kind: ContentKind.story,
              files: 2,
              contents: 2,
              failed: 0,
              removed: 0,
            ),
          ],
        )
        ..checkResult = _checked(ids: const [5, 6]);

      expect(await r.router.route(TaskNames.checkStories), isTrue);

      expect(r.recorder.calls, ['items']);
      expect(r.recorder.checksSeen.single?.newContentIds, [5, 6]);
    });

    test('a download-only task notifies without a check', () async {
      final r = _Rig();
      expect(await r.router.route(TaskNames.download), isTrue);
      expect(r.recorder.calls, ['items']);
      expect(r.recorder.checksSeen.single, isNull);
    });
  });

  group('checking notice (T-043)', () {
    test('wraps the check, then the downloads follow', () async {
      final r = _Rig(active: 4);
      await r.router.route(TaskNames.checkStories);
      expect(r.recorder.calls, ['start:4', 'check', 'done', 'items']);
    });

    test('no active targets: no notice', () async {
      final r = _Rig(active: 0);
      await r.router.route(TaskNames.checkPosts);
      expect(r.recorder.calls, ['check', 'items']);
    });

    test('is cancelled when the check throws', () async {
      final r = _Rig(active: 2)..checkThrows = Exception('boom');
      expect(await r.router.route(TaskNames.checkStories), isFalse);
      expect(r.recorder.calls, ['start:2', 'check', 'done']);
    });

    test('a failing notifier never breaks the check', () async {
      final r = _Rig(active: 1);
      r.recorder.failChecking = true;
      expect(await r.router.route(TaskNames.checkStories), isTrue);
      expect(r.recorder.calls, contains('check'));
    });
  });

  group('session hook', () {
    test('needs_relogin from the check sends the login alert', () async {
      final r = _Rig()
        ..checkResult = _checked(errorCode: 'session_needs_relogin');
      await r.router.route(TaskNames.checkStories);
      expect(r.recorder.status, AccountStatus.needsRelogin);
    });

    test('restricted from the check sends the login alert', () async {
      final r = _Rig()..checkResult = _checked(errorCode: 'session_restricted');
      await r.router.route(TaskNames.checkPosts);
      expect(r.recorder.status, AccountStatus.restricted);
    });

    test('an inactive account (no status change) sends nothing', () async {
      final r = _Rig()..checkResult = _checked(errorCode: 'session_not_active');
      await r.router.route(TaskNames.checkStories);
      expect(r.recorder.calls, isNot(contains('session')));
    });
  });

  group('storage hook', () {
    for (final reason in [
      DownloadStopReason.storagePaused,
      DownloadStopReason.galleryStorageFull,
    ]) {
      test('${reason.name} sends the storage alert', () async {
        final r = _Rig()..downloadResult = _downloaded(reason);
        await r.router.route(TaskNames.download);
        expect(r.recorder.calls, contains('storage'));
      });
    }

    test('a completed run sends no storage alert', () async {
      final r = _Rig();
      await r.router.route(TaskNames.download);
      expect(r.recorder.calls, isNot(contains('storage')));
    });
  });

  group('failure and absence', () {
    test(
      'a throwing notifier never breaks the task, and is logged by type',
      () async {
        final r = _Rig()
          ..recorder.throws = true
          ..downloadResult = _downloaded(DownloadStopReason.storagePaused);
        expect(await r.router.route(TaskNames.download), isTrue);
        final entries = r.log.at(LogLevel.warn);
        expect(entries.single.message, contains('StateError'));
      },
    );

    test('without a notifier the task runs as before', () async {
      final r = _Rig(notifier: false);
      expect(await r.router.route(TaskNames.checkStories), isTrue);
    });
  });
}
