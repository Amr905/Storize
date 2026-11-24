import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

final class _Enqueuer implements DownloadEnqueuer {
  @override
  Future<void> enqueueDownload({required bool wifiOnly}) async {}

  @override
  Future<void> enqueueHistory({
    required bool wifiOnly,
    required Duration delay,
    bool fromHistoryTask = false,
  }) async {}
}

TaskRouter _router(List<String> order, {bool resolveThrows = false}) {
  final t0 = DateTime.utc(2026, 11, 24, 8);
  return TaskRouter(
    runCheck: ({required scope, required trigger, targetId, deadline}) async {
      order.add('check-${scope.name}');
      return CheckRunResult(
        run: CheckRun(
          id: 1,
          scope: scope,
          trigger: trigger,
          startedAt: t0,
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
    settings: FakeSettingsRepo(),
    clock: FakeClock(t0),
    enqueuer: _Enqueuer(),
    resolvePending: ({deadline}) async {
      order.add('resolve');
      if (resolveThrows) throw StateError('boom');
      return const ResolvePendingResult();
    },
  );
}

void main() {
  test('check-stories resolves pending targets before the check', () async {
    final order = <String>[];
    expect(await _router(order).route(TaskNames.checkStories), isTrue);
    expect(order.take(2), ['resolve', 'check-stories']);
  });

  test('check-posts resolves pending targets before the check', () async {
    final order = <String>[];
    await _router(order).route(TaskNames.checkPosts);
    expect(order.take(2), ['resolve', 'check-posts']);
  });

  test('download and retention tasks do not resolve', () async {
    final order = <String>[];
    await _router(order).route(TaskNames.download);
    expect(order, ['download']);
  });

  test('a failing resolve does not stop the check', () async {
    final order = <String>[];
    expect(
      await _router(order, resolveThrows: true).route(TaskNames.checkPosts),
      isTrue,
    );
    expect(order, containsAllInOrder(['resolve', 'check-posts', 'download']));
  });
}
