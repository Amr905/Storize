import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_model/storize_model.dart';
import 'package:workmanager/workmanager.dart';

final class _Call {
  _Call(this.kind, this.unique, this.task, this.constraints, this.extra);
  final String kind;
  final String unique;
  final String task;
  final Constraints? constraints;
  final Map<String, Object?> extra;
}

final class _FakeClient implements WorkmanagerClient {
  final List<_Call> calls = [];
  bool cancelled = false;

  _Call byUnique(String unique) => calls.lastWhere((c) => c.unique == unique);

  @override
  Future<void> registerPeriodic(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required Constraints constraints,
    Duration? initialDelay,
    ExistingPeriodicWorkPolicy policy = ExistingPeriodicWorkPolicy.update,
  }) async => calls.add(
    _Call('periodic', uniqueName, taskName, constraints, {
      'frequency': frequency,
      'initialDelay': initialDelay,
      'policy': policy,
    }),
  );

  @override
  Future<void> registerOneOff(
    String uniqueName,
    String taskName, {
    required Constraints constraints,
    required ExistingWorkPolicy policy,
    Map<String, dynamic>? inputData,
    bool expedited = false,
  }) async => calls.add(
    _Call('oneoff', uniqueName, taskName, constraints, {
      'policy': policy,
      'input': inputData,
      'expedited': expedited,
    }),
  );

  @override
  Future<void> cancelAll() async => cancelled = true;
}

void main() {
  late _FakeClient client;
  late WorkmanagerScheduler scheduler;

  setUp(() {
    client = _FakeClient();
    scheduler = WorkmanagerScheduler(client);
  });

  group('apply', () {
    test('registers the four periodic tasks with their frequencies', () async {
      await scheduler.apply(storyMin: 20, postMin: 90, wifiOnly: false);

      expect(client.calls.map((c) => c.unique), [
        'check-stories',
        'check-posts',
        'retention',
        'update-check',
      ]);
      expect(
        client.byUnique('check-stories').extra['frequency'],
        const Duration(minutes: 20),
      );
      expect(
        client.byUnique('check-posts').extra['frequency'],
        const Duration(minutes: 90),
      );
      expect(
        client.byUnique('retention').extra['frequency'],
        const Duration(hours: 24),
      );
      expect(
        client.byUnique('update-check').extra['frequency'],
        const Duration(hours: 24),
      );
    });

    test(
      'check tasks replace the old registration, daily tasks keep',
      () async {
        await scheduler.apply(storyMin: 15, postMin: 60, wifiOnly: false);

        expect(
          client.byUnique('check-stories').extra['policy'],
          ExistingPeriodicWorkPolicy.update,
        );
        expect(
          client.byUnique('check-posts').extra['policy'],
          ExistingPeriodicWorkPolicy.update,
        );
        expect(
          client.byUnique('retention').extra['policy'],
          ExistingPeriodicWorkPolicy.keep,
        );
        expect(
          client.byUnique('update-check').extra['policy'],
          ExistingPeriodicWorkPolicy.keep,
        );
      },
    );

    test(
      'check-posts has an offset start that check-stories does not',
      () async {
        await scheduler.apply(storyMin: 15, postMin: 60, wifiOnly: false);

        expect(client.byUnique('check-stories').extra['initialDelay'], isNull);
        final delay =
            client.byUnique('check-posts').extra['initialDelay']! as Duration;
        expect(delay, greaterThan(Duration.zero));
        expect(delay, lessThanOrEqualTo(const Duration(minutes: 30)));
      },
    );

    test('intervals below the minimum are raised to it', () async {
      await scheduler.apply(storyMin: 5, postMin: 10, wifiOnly: false);

      expect(
        client.byUnique('check-stories').extra['frequency'],
        const Duration(minutes: 15),
      );
      expect(
        client.byUnique('check-posts').extra['frequency'],
        const Duration(minutes: 60),
      );
    });

    test('network required, unmetered only if Wi-Fi only', () async {
      await scheduler.apply(storyMin: 15, postMin: 60, wifiOnly: false);
      expect(
        client.byUnique('check-stories').constraints!.networkType,
        NetworkType.connected,
      );
      expect(
        client.byUnique('check-posts').constraints!.networkType,
        NetworkType.connected,
      );

      client.calls.clear();
      await scheduler.apply(storyMin: 15, postMin: 60, wifiOnly: true);
      expect(
        client.byUnique('check-stories').constraints!.networkType,
        NetworkType.unmetered,
      );
      expect(
        client.byUnique('check-posts').constraints!.networkType,
        NetworkType.unmetered,
      );
      // update-check is tiny and never Wi-Fi only; retention needs no network.
      expect(
        client.byUnique('update-check').constraints!.networkType,
        NetworkType.connected,
      );
      expect(
        client.byUnique('retention').constraints!.networkType,
        NetworkType.notRequired,
      );
    });

    test(
      'calling apply twice registers the same unique names (replace)',
      () async {
        await scheduler.apply(storyMin: 15, postMin: 60, wifiOnly: false);
        await scheduler.apply(storyMin: 30, postMin: 120, wifiOnly: true);

        final names = client.calls.map((c) => c.unique).toList();
        expect(names.where((n) => n == 'check-stories'), hasLength(2));
        expect(names.toSet(), hasLength(4));
      },
    );
  });

  group('checkNow', () {
    test('enqueues an expedited one-off for a scope', () async {
      await scheduler.checkNow(scope: CheckScope.stories);

      final call = client.calls.single;
      expect(call.kind, 'oneoff');
      expect(call.unique, 'check-now-stories');
      expect(call.task, TaskNames.checkStories);
      expect(call.extra['expedited'], isTrue);
      expect(call.constraints!.networkType, NetworkType.connected);
      expect(call.extra['input'], {TaskNames.inputManual: true});
    });

    test('carries the target ID', () async {
      await scheduler.checkNow(scope: CheckScope.posts, targetId: 7);

      final call = client.calls.single;
      expect(call.unique, 'check-now-posts-7');
      expect(call.task, TaskNames.checkPosts);
      expect(call.extra['input'], {
        TaskNames.inputManual: true,
        TaskNames.inputTargetId: 7,
      });
    });

    test('scope all enqueues one task per scope', () async {
      await scheduler.checkNow();

      expect(client.calls.map((c) => c.task), [
        TaskNames.checkStories,
        TaskNames.checkPosts,
      ]);
      expect(client.calls.every((c) => c.extra['expedited'] == true), isTrue);
    });
  });

  group('download roll-over', () {
    test('appends a one-off download with a storage constraint', () async {
      await scheduler.enqueueDownload(wifiOnly: false);

      final call = client.calls.single;
      expect(call.unique, 'download');
      expect(call.task, TaskNames.download);
      expect(call.extra['policy'], ExistingWorkPolicy.append);
      expect(call.constraints!.requiresStorageNotLow, isTrue);
      expect(call.constraints!.networkType, NetworkType.connected);
    });

    test('is unmetered when Wi-Fi only is set', () async {
      await scheduler.enqueueDownload(wifiOnly: true);
      expect(
        client.calls.single.constraints!.networkType,
        NetworkType.unmetered,
      );
    });
  });

  test('cancelAll cancels everything', () async {
    await scheduler.cancelAll();
    expect(client.cancelled, isTrue);
  });

  test('forScope rejects all', () {
    expect(() => TaskNames.forScope(CheckScope.all), throwsArgumentError);
  });
}
