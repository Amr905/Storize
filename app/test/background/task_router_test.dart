import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_model/storize_model.dart';

final DateTime _t0 = DateTime.utc(2026, 11, 20, 8);

CheckRunResult _checked({
  CheckResult result = CheckResult.ok,
  String? errorCode,
}) => CheckRunResult(
  run: CheckRun(
    id: 1,
    scope: CheckScope.stories,
    trigger: CheckTrigger.periodic,
    startedAt: _t0,
    result: result,
    errorCode: errorCode,
  ),
  newContentIds: const [],
);

DownloadPendingResult _downloaded(
  DownloadStopReason reason, {
  int remaining = 0,
}) => DownloadPendingResult(
  stopReason: reason,
  remaining: remaining,
  counts: const [],
  failures: const [],
);

final class _Enqueuer implements DownloadEnqueuer {
  final List<bool> calls = [];

  @override
  Future<void> enqueueDownload({required bool wifiOnly}) async =>
      calls.add(wifiOnly);

  final List<({Duration delay, bool wifiOnly, bool fromHistoryTask})> history =
      [];

  @override
  Future<void> enqueueHistory({
    required bool wifiOnly,
    required Duration delay,
    bool fromHistoryTask = false,
  }) async => history.add((
    delay: delay,
    wifiOnly: wifiOnly,
    fromHistoryTask: fromHistoryTask,
  ));
}

typedef _CheckCall = ({
  CheckScope scope,
  CheckTrigger trigger,
  int? targetId,
  DateTime? deadline,
});

typedef _DownloadCall = ({DateTime? deadline, ExtractionPolicy policy});

final class _Rig {
  _Rig({AppSettings settings = const AppSettings(), this.onCheck})
    : settings = FakeSettingsRepo(settings);

  final FakeSettingsRepo settings;
  final clock = FakeClock(_t0);
  final enqueuer = _Enqueuer();
  final log = FakeDiagnosticLog();
  final order = <String>[];
  final checks = <_CheckCall>[];
  final downloads = <_DownloadCall>[];
  int retentions = 0;
  int updateChecks = 0;

  CheckRunResult checkResult = _checked();
  DownloadPendingResult downloadResult = _downloaded(
    DownloadStopReason.completed,
  );
  Exception? checkThrows;
  final Future<void> Function()? onCheck;

  late final TaskRouter router = TaskRouter(
    runCheck: ({required scope, required trigger, targetId, deadline}) async {
      order.add('check-${scope.name}');
      checks.add((
        scope: scope,
        trigger: trigger,
        targetId: targetId,
        deadline: deadline,
      ));
      await onCheck?.call();
      final e = checkThrows;
      if (e != null) throw e;
      return checkResult;
    },
    download: ({deadline, policy = ExtractionPolicy.directOnly}) async {
      order.add('download');
      downloads.add((deadline: deadline, policy: policy));
      return downloadResult;
    },
    retention: () async {
      order.add('retention');
      retentions++;
      return null;
    },
    updateCheck: () async {
      order.add('update-check');
      updateChecks++;
      return null;
    },
    settings: settings,
    clock: clock,
    enqueuer: enqueuer,
    log: log,
    history: ({policy, deadline}) async {
      order.add('history');
      return const BackfillPassResult(running: 0, newContentIds: []);
    },
  );
}

void main() {
  unmeteredGroup();
  group('routing (AC3, AC6)', () {
    test(
      'check-stories runs RunCheck(stories, periodic) then downloads',
      () async {
        final r = _Rig();
        expect(await r.router.route(TaskNames.checkStories), isTrue);

        expect(r.order, ['check-stories', 'download']);
        expect(r.checks.single.scope, CheckScope.stories);
        expect(r.checks.single.trigger, CheckTrigger.periodic);
        expect(r.checks.single.targetId, isNull);
      },
    );

    test('check-posts runs RunCheck(posts) then downloads', () async {
      final r = _Rig();
      expect(await r.router.route(TaskNames.checkPosts), isTrue);

      expect(r.order, ['check-posts', 'download']);
      expect(r.checks.single.scope, CheckScope.posts);
    });

    test('download routes to DownloadPending only', () async {
      final r = _Rig();
      expect(await r.router.route(TaskNames.download), isTrue);

      expect(r.order, ['download']);
      expect(r.checks, isEmpty);
    });

    test('retention routes to ApplyRetention only', () async {
      final r = _Rig();
      expect(await r.router.route(TaskNames.retention), isTrue);
      expect(r.order, ['retention']);
    });

    test('update-check routes to the update checker only', () async {
      final r = _Rig();
      expect(await r.router.route(TaskNames.updateCheck), isTrue);
      expect(r.order, ['update-check']);
    });

    test('every known task name has a route', () async {
      for (final name in TaskNames.all) {
        final r = _Rig();
        await r.router.route(name);
        expect(r.order, isNotEmpty, reason: name);
      }
    });

    test('an unknown task does nothing and is not retried', () async {
      final r = _Rig();
      expect(await r.router.route('mystery'), isTrue);
      expect(r.order, isEmpty);
      expect(r.log.entries.map((e) => e.message), contains('unknown_task'));
    });
  });

  group('manual checks (AC2 input)', () {
    test('manual without a target is MANUAL_ALL', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkStories, {
        TaskNames.inputManual: true,
      });
      expect(r.checks.single.trigger, CheckTrigger.manualAll);
    });

    test('manual with a target is MANUAL_ONE and passes the ID', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkPosts, {
        TaskNames.inputManual: true,
        TaskNames.inputTargetId: 9,
      });
      expect(r.checks.single.trigger, CheckTrigger.manualOne);
      expect(r.checks.single.targetId, 9);
    });

    test('a target ID that is not an int is ignored', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkPosts, {
        TaskNames.inputManual: true,
        TaskNames.inputTargetId: '9',
      });
      expect(r.checks.single.targetId, isNull);
    });
  });

  group('the 9-minute budget and the download roll-over (AC3)', () {
    test(
      'RunCheck and DownloadPending share one deadline: 9 min minus a 30 s start margin',
      () async {
        final r = _Rig();
        await r.router.route(TaskNames.checkStories);

        final expected = _t0.add(const Duration(minutes: 8, seconds: 30));
        expect(r.checks.single.deadline, expected);
        expect(r.downloads.single.deadline, expected);
      },
    );

    test('a deadline stop with files left enqueues a download task', () async {
      final r = _Rig()
        ..downloadResult = _downloaded(
          DownloadStopReason.deadline,
          remaining: 4,
        );
      expect(await r.router.route(TaskNames.checkStories), isTrue);
      expect(r.enqueuer.calls, [false]);
    });

    test('the roll-over keeps Wi-Fi only from settings', () async {
      final r = _Rig(settings: const AppSettings(wifiOnly: true))
        ..downloadResult = _downloaded(
          DownloadStopReason.deadline,
          remaining: 1,
        );
      await r.router.route(TaskNames.download);
      expect(r.enqueuer.calls, [true]);
    });

    test(
      'a download task that hits the deadline again rolls over again',
      () async {
        final r = _Rig()
          ..downloadResult = _downloaded(
            DownloadStopReason.deadline,
            remaining: 2,
          );
        await r.router.route(TaskNames.download);
        expect(r.enqueuer.calls, hasLength(1));
      },
    );

    test(
      'no roll-over when nothing is left or the stop is not the deadline',
      () async {
        for (final result in [
          _downloaded(DownloadStopReason.deadline),
          _downloaded(DownloadStopReason.completed),
          _downloaded(DownloadStopReason.rateLimited, remaining: 3),
          _downloaded(DownloadStopReason.sessionProblem, remaining: 3),
          _downloaded(DownloadStopReason.storagePaused, remaining: 3),
          _downloaded(DownloadStopReason.busy, remaining: 3),
        ]) {
          final r = _Rig()..downloadResult = result;
          await r.router.route(TaskNames.download);
          expect(r.enqueuer.calls, isEmpty, reason: '${result.stopReason}');
        }
      },
    );
  });

  group('extraction policy of the downloads', () {
    test(
      'periodic is direct-only unless page mode in background is on',
      () async {
        final off = _Rig();
        await off.router.route(TaskNames.checkStories);
        expect(off.downloads.single.policy, ExtractionPolicy.directOnly);

        final on = _Rig(
          settings: const AppSettings(pageModeInBackground: true),
        );
        await on.router.route(TaskNames.checkStories);
        expect(on.downloads.single.policy, ExtractionPolicy.directThenPage);
      },
    );

    test('a manual check may use page mode', () async {
      final r = _Rig();
      await r.router.route(TaskNames.checkStories, {
        TaskNames.inputManual: true,
      });
      expect(r.downloads.single.policy, ExtractionPolicy.directThenPage);
    });
  });

  group('worker result', () {
    test('a network failure asks for a retry with back-off', () async {
      final r = _Rig()
        ..checkResult = _checked(
          result: CheckResult.failed,
          errorCode: 'network',
        );
      expect(await r.router.route(TaskNames.checkStories), isFalse);
      // The downloads still ran: they are not governed.
      expect(r.order, ['check-stories', 'download']);
    });

    test('expected failures are done, not retried', () async {
      for (final result in [
        _checked(result: CheckResult.skippedSession),
        _checked(result: CheckResult.rateLimited, errorCode: 'rate_limited'),
        _checked(result: CheckResult.failed, errorCode: 'schema_changed'),
        _checked(result: CheckResult.partial, errorCode: 'deadline'),
      ]) {
        final r = _Rig()..checkResult = result;
        expect(await r.router.route(TaskNames.checkPosts), isTrue);
      }
    });

    test('an unexpected error is a retry and logs only its type', () async {
      final r = _Rig()
        ..checkThrows = const FormatException('https://secret.invalid/x');
      expect(await r.router.route(TaskNames.checkStories), isFalse);

      final messages = r.log.entries.map((e) => e.message).join('\n');
      expect(messages, contains('task_failed task=check-stories'));
      expect(messages, contains('FormatException'));
      expect(messages, isNot(contains('secret')));
    });
  });
}

/// Whether a governed call inside the check callback is let through with an
/// empty bucket (the unmetered scope took effect).
Future<bool> _unmeteredHolds({
  required bool allowUnmetered,
  required bool flag,
}) async {
  final clock = FakeClock();
  final governor = RequestGovernor(
    leases: FakeGovernorLeaseRepo(clock),
    clock: clock,
    holder: 'test',
    config: const GovernorConfig(
      jitterMin: Duration.zero,
      jitterMax: Duration.zero,
    ),
    delay: (d) async => clock.set(clock.now().add(d)),
    allowUnmetered: allowUnmetered,
  );
  for (var i = 0; i < 6; i++) {
    await governor.run(
      accountId: 1,
      cost: RequestCost.api,
      call: () async => 1,
    );
  }
  var let = false;
  final r = _Rig(
    onCheck: () async {
      try {
        await governor.run(
          accountId: 1,
          cost: RequestCost.api,
          call: () async => 1,
          maxWait: const Duration(seconds: 5),
        );
        let = true;
      } on GovernorPaused {
        let = false;
      }
    },
  );
  await r.router.route(TaskNames.checkStories, {
    TaskNames.inputManual: true,
    if (flag) TaskRouter.inputManualUnmetered: true,
  });
  return let;
}

void unmeteredGroup() {
  group('debug "Check now, no limit" (T-050)', () {
    test('dev governor: the flag runs the check unmetered', () async {
      expect(await _unmeteredHolds(allowUnmetered: true, flag: true), isTrue);
    });
    test('without the flag the check is metered', () async {
      expect(await _unmeteredHolds(allowUnmetered: true, flag: false), isFalse);
    });
    test('prod governor: the flag changes nothing', () async {
      expect(await _unmeteredHolds(allowUnmetered: false, flag: true), isFalse);
    });
  });
}
