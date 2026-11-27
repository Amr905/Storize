import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/scheduler/task_names.dart';
import 'package:storize_data/scheduler/workmanager_client.dart';
import 'package:storize_data/scheduler/workmanager_scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:workmanager/workmanager.dart';

/// Records what the scheduler asks WorkManager to do.
final class _Client implements WorkmanagerClient {
  final List<
    ({String unique, String task, Duration? delay, ExistingWorkPolicy policy})
  >
  oneOffs = [];
  final List<String> cancelled = [];

  @override
  Future<void> registerPeriodic(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required Constraints constraints,
    Duration? initialDelay,
    ExistingPeriodicWorkPolicy policy = ExistingPeriodicWorkPolicy.update,
  }) async {}

  @override
  Future<void> registerOneOff(
    String uniqueName,
    String taskName, {
    required Constraints constraints,
    required ExistingWorkPolicy policy,
    Map<String, dynamic>? inputData,
    bool expedited = false,
    Duration? initialDelay,
  }) async {
    oneOffs.add((
      unique: uniqueName,
      task: taskName,
      delay: initialDelay,
      policy: policy,
    ));
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> cancelByUniqueName(String uniqueName) async =>
      cancelled.add(uniqueName);
}

void main() {
  late _Client client;
  late WorkmanagerScheduler scheduler;

  // 2026-11-27 18:00 UTC is 20:00 at UTC+02:00.
  final nowUtc = DateTime.utc(2026, 11, 27, 18);
  const plus2 = Duration(hours: 2);

  setUp(() {
    client = _Client();
    scheduler = WorkmanagerScheduler(client);
  });

  test(
    'daily mode registers one run at the next local time, replacing',
    () async {
      await scheduler.schedule(
        mode: NotificationMode.daily,
        time: SummaryTime.defaultTime,
        nowUtc: nowUtc,
        localOffset: plus2,
      );
      final call = client.oneOffs.single;
      expect(call.unique, TaskNames.dailySummary);
      expect(call.task, 'daily-summary');
      expect(call.policy, ExistingWorkPolicy.replace);
      expect(call.delay, const Duration(hours: 1));
      expect(client.cancelled, isEmpty);
    },
  );

  test('a time already passed today gives tomorrow', () async {
    await scheduler.schedule(
      mode: NotificationMode.daily,
      time: const SummaryTime(19, 30),
      nowUtc: nowUtc,
      localOffset: plus2,
    );
    expect(client.oneOffs.single.delay, const Duration(hours: 23, minutes: 30));
  });

  test('changing the time re-schedules under the same unique name', () async {
    await scheduler.schedule(
      mode: NotificationMode.daily,
      time: SummaryTime.defaultTime,
      nowUtc: nowUtc,
      localOffset: plus2,
    );
    await scheduler.schedule(
      mode: NotificationMode.daily,
      time: const SummaryTime(7, 0),
      nowUtc: nowUtc,
      localOffset: plus2,
    );
    expect(client.oneOffs.map((c) => c.unique).toSet(), {
      TaskNames.dailySummary,
    });
    expect(client.oneOffs.last.delay, const Duration(hours: 11));
    expect(
      client.oneOffs.every((c) => c.policy == ExistingWorkPolicy.replace),
      isTrue,
    );
  });

  test(
    'per item and off cancel the pending run and register nothing',
    () async {
      for (final mode in [NotificationMode.perItem, NotificationMode.off]) {
        await scheduler.schedule(
          mode: mode,
          time: SummaryTime.defaultTime,
          nowUtc: nowUtc,
          localOffset: plus2,
        );
      }
      expect(client.oneOffs, isEmpty);
      expect(client.cancelled, [
        TaskNames.dailySummary,
        TaskNames.dailySummary,
      ]);
    },
  );

  test('a failing WorkManager call propagates to the caller', () async {
    final failing = _FailingClient();
    final s = WorkmanagerScheduler(failing);
    await expectLater(
      s.schedule(
        mode: NotificationMode.daily,
        time: SummaryTime.defaultTime,
        nowUtc: nowUtc,
        localOffset: plus2,
      ),
      throwsStateError,
    );
  });
}

final class _FailingClient extends _Client {
  @override
  Future<void> registerOneOff(
    String uniqueName,
    String taskName, {
    required Constraints constraints,
    required ExistingWorkPolicy policy,
    Map<String, dynamic>? inputData,
    bool expedited = false,
    Duration? initialDelay,
  }) async {
    throw StateError('plugin down');
  }
}
