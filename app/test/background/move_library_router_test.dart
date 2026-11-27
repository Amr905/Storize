import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/move_notifier.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_app/notifications/notification_service.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../notifications/fake_notifications.dart';

final DateTime _now = DateTime.utc(2026, 11, 27, 18);

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

final class _Notifier implements MoveNotifier {
  final List<MoveProgress> progress_ = [];
  final List<MoveLibraryResult> finished_ = [];

  @override
  Future<void> progress(MoveProgress progress) async => progress_.add(progress);

  @override
  Future<void> finished(MoveLibraryResult result) async =>
      finished_.add(result);
}

void main() {
  late FakeMoveScheduler scheduler;
  late _Notifier notifier;
  late List<StorageTarget> runs;
  late MoveEnd end;

  setUp(() {
    scheduler = FakeMoveScheduler();
    notifier = _Notifier();
    runs = [];
    end = MoveEnd.finished;
  });

  TaskRouter router({bool withMove = true}) => TaskRouter(
    runCheck: ({required scope, required trigger, targetId, deadline}) async =>
        throw StateError('not used'),
    download: ({deadline, policy = ExtractionPolicy.directOnly}) async =>
        throw StateError('not used'),
    retention: () async => null,
    updateCheck: () async => null,
    settings: FakeSettingsRepo(),
    clock: FakeClock(_now),
    enqueuer: _NoEnqueue(),
    move: withMove
        ? (target, {deadline, onProgress}) async {
            runs.add(target);
            final p = MoveProgress(
              status: MoveStatus.running,
              target: target,
              total: 3,
              moved: 1,
            );
            onProgress?.call(p);
            return MoveLibraryResult(end: end, progress: p);
          }
        : null,
    moveNotifier: notifier,
    moveScheduler: scheduler,
  );

  test('move-library runs the use case for the target in the input', () async {
    final ok = await router().route(TaskNames.moveLibrary, {
      TaskNames.inputMoveTarget: 'private',
    });
    expect(ok, isTrue);
    expect(runs, [StorageTarget.private]);
    expect(notifier.progress_, hasLength(1));
    expect(notifier.finished_.single.end, MoveEnd.finished);
    expect(scheduler.enqueued, isEmpty);
  });

  test('the gallery target is read from the input too', () async {
    await router().route(TaskNames.moveLibrary, {
      TaskNames.inputMoveTarget: 'gallery',
    });
    expect(runs, [StorageTarget.gallery]);
  });

  test('a run that hit the deadline queues itself again (roll-over)', () async {
    end = MoveEnd.deadline;
    await router().route(TaskNames.moveLibrary, {
      TaskNames.inputMoveTarget: 'private',
    });
    expect(scheduler.enqueued, [
      (target: StorageTarget.private, rollover: true),
    ]);
  });

  test('cancel, full storage and finish do not queue again', () async {
    for (final e in [
      MoveEnd.cancelled,
      MoveEnd.storageFull,
      MoveEnd.finished,
    ]) {
      end = e;
      await router().route(TaskNames.moveLibrary, {
        TaskNames.inputMoveTarget: 'private',
      });
    }
    expect(scheduler.enqueued, isEmpty);
    expect(notifier.finished_, hasLength(3));
  });

  test('a missing or unknown target does nothing and is not retried', () async {
    expect(await router().route(TaskNames.moveLibrary), isTrue);
    expect(
      await router().route(TaskNames.moveLibrary, {
        TaskNames.inputMoveTarget: 'cloud',
      }),
      isTrue,
    );
    expect(runs, isEmpty);
  });

  test('without the use case the task is a no-op', () async {
    expect(
      await router(withMove: false).route(TaskNames.moveLibrary, {
        TaskNames.inputMoveTarget: 'private',
      }),
      isTrue,
    );
    expect(runs, isEmpty);
  });

  group('NotificationMoveNotifier', () {
    late FakeNotificationPort port;
    late FakeClock clock;
    late NotificationMoveNotifier notify;

    setUp(() {
      port = FakeNotificationPort();
      clock = FakeClock(_now);
      notify = NotificationMoveNotifier(port: port, clock: clock);
    });

    MoveProgress p(int moved, {int total = 10}) => MoveProgress(
      status: MoveStatus.running,
      target: StorageTarget.private,
      total: total,
      moved: moved,
    );

    test('shows counts only, silently, and throttles', () async {
      await notify.progress(p(1));
      await notify.progress(p(2)); // within the interval: skipped
      clock.advance(const Duration(seconds: 2));
      await notify.progress(p(5));
      expect(port.shown.map((n) => n.title), [
        'Moving saved files… 1 of 10',
        'Moving saved files… 5 of 10',
      ]);
      expect(port.shown.every((n) => n.silent), isTrue);
      expect(port.shown.every((n) => n.id == 8), isTrue);
      expect(
        port.shown.first.channelId,
        NotificationChannels.background,
      );
    });

    test('finish replaces the notice; cancel removes it', () async {
      await notify.finished(
        MoveLibraryResult(end: MoveEnd.finished, progress: p(10)),
      );
      expect(port.shown.single.title, '10 saved files moved');
      await notify.finished(
        MoveLibraryResult(end: MoveEnd.cancelled, progress: p(4)),
      );
      expect(port.cancelled, [8]);
    });

    test('storage full uses the storage channel', () async {
      await notify.finished(
        MoveLibraryResult(end: MoveEnd.storageFull, progress: p(4)),
      );
      expect(port.shown.single.channelId, NotificationChannels.storage);
      expect(port.shown.single.silent, isFalse);
    });

    test('a failing port never throws and logs the type only', () async {
      port.failShow = true;
      final log = FakeDiagnosticLog();
      final n = NotificationMoveNotifier(port: port, clock: clock, log: log);
      await n.progress(p(1));
      expect(log.entries.single.message, contains('type='));
    });

    test('nothing is shown when notifications are off', () async {
      port.enabled = false;
      await notify.progress(p(1));
      expect(port.shown, isEmpty);
    });
  });
}
