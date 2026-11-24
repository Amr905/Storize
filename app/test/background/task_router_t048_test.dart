import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/page/user_initiated.dart';
import 'package:storize_model/storize_model.dart';

final DateTime _t0 = DateTime.utc(2026, 11, 24, 8);

final class _Enqueuer implements DownloadEnqueuer {
  int history = 0;

  @override
  Future<void> enqueueDownload({required bool wifiOnly}) async {}

  @override
  Future<void> enqueueHistory({
    required bool wifiOnly,
    required Duration delay,
    bool fromHistoryTask = false,
  }) async => history++;
}

final class _Rig {
  _Rig({this.errorCode});

  final String? errorCode;
  final settings = FakeSettingsRepo();
  final enqueuer = _Enqueuer();
  final userInitiated = <String, bool>{};

  late final TaskRouter router = TaskRouter(
    runCheck: ({required scope, required trigger, targetId, deadline}) async {
      userInitiated['check'] = isUserInitiatedRun;
      return CheckRunResult(
        run: CheckRun(
          id: 1,
          scope: scope,
          trigger: trigger,
          startedAt: _t0,
          result: errorCode == null ? CheckResult.ok : CheckResult.failed,
          errorCode: errorCode,
        ),
        newContentIds: const [],
      );
    },
    download: ({deadline, policy = ExtractionPolicy.directOnly}) async {
      // A real await first: the zone must survive it.
      await Future<void>.delayed(Duration.zero);
      userInitiated['download'] = isUserInitiatedRun;
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
    clock: FakeClock(_t0),
    enqueuer: enqueuer,
    historyProbe: ({staleFor}) async => true,
  );
}

void main() {
  group('T-048 manual checks may load pages', () {
    test('a manual check runs as a user-initiated run', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkPosts, {TaskNames.inputManual: true});
      expect(r.userInitiated, {'check': true, 'download': true});
    });

    test('a scheduled check does not', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkPosts);
      expect(r.userInitiated, {'check': false, 'download': false});
    });

    test('the flag does not leak out of the manual run', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkStories, {
        TaskNames.inputManual: true,
      });
      expect(isUserInitiatedRun, isFalse);
    });
  });

  group('T-048 check storm', () {
    test('N quick failed checks cause no history re-kicks', () async {
      for (final code in ['schema_changed', 'unknown']) {
        final r = _Rig(errorCode: code);
        for (var i = 0; i < 12; i++) {
          await r.router.route(TaskNames.checkPosts, {
            TaskNames.inputManual: true,
          });
          await r.router.route(TaskNames.checkPosts);
        }
        expect(r.enqueuer.history, 0, reason: code);
      }
    });

    test('a clean posts check still kicks a stale history once', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkPosts);
      expect(r.enqueuer.history, 1);
    });
  });
}
