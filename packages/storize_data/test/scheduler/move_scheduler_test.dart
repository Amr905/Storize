import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:storize_data/scheduler/task_names.dart';
import 'package:storize_data/scheduler/workmanager_client.dart';
import 'package:storize_data/scheduler/workmanager_scheduler.dart';
import 'package:storize_data/settings/settings.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:workmanager/workmanager.dart';

final class _Client implements WorkmanagerClient {
  final List<
    ({
      String unique,
      String task,
      ExistingWorkPolicy policy,
      Map<String, dynamic>? input,
    })
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
  }) async => oneOffs.add((
    unique: uniqueName,
    task: taskName,
    policy: policy,
    input: inputData,
  ));

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> cancelByUniqueName(String uniqueName) async =>
      cancelled.add(uniqueName);
}

void main() {
  group('FR-79 move-library task', () {
    test('a user start replaces any run and carries the target', () async {
      final client = _Client();
      await WorkmanagerScheduler(client).enqueueMove(StorageTarget.private);
      final call = client.oneOffs.single;
      expect(call.unique, 'move-library');
      expect(call.task, 'move-library');
      expect(call.policy, ExistingWorkPolicy.replace);
      expect(call.input, {TaskNames.inputMoveTarget: 'private'});
      expect(TaskNames.all, contains(TaskNames.moveLibrary));
    });

    test('a roll-over appends after the running task', () async {
      final client = _Client();
      await WorkmanagerScheduler(
        client,
      ).enqueueMove(StorageTarget.gallery, rollover: true);
      expect(client.oneOffs.single.policy, ExistingWorkPolicy.append);
      expect(client.oneOffs.single.input, {
        TaskNames.inputMoveTarget: 'gallery',
      });
    });

    test('cancel removes the work by its unique name', () async {
      final client = _Client();
      await WorkmanagerScheduler(client).cancelMove();
      expect(client.cancelled, ['move-library']);
    });
  });

  group('SharedPrefsMoveStateStore', () {
    late SharedPrefsMoveStateStore store;
    late SharedPreferencesAsync prefs;
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = SharedPreferencesAsync();
      store = SharedPrefsMoveStateStore(prefs: prefs);
    });

    test('reads none when nothing is stored', () async {
      expect(await store.read(), MoveProgress.none);
      expect(await store.cancelRequested(), isFalse);
    });

    test('round-trips progress', () async {
      final p = MoveProgress(
        status: MoveStatus.running,
        target: StorageTarget.private,
        total: 10,
        moved: 4,
        missing: 1,
        failed: 2,
        updatedAt: DateTime.utc(2026, 11, 27, 10),
      );
      await store.write(p);
      expect(await store.read(), p);
    });

    test('a cancel request is set and cleared', () async {
      await store.setCancelRequested(value: true);
      expect(await store.cancelRequested(), isTrue);
      await store.setCancelRequested(value: false);
      expect(await store.cancelRequested(), isFalse);
    });

    test('garbage reads as no move', () async {
      await prefs.setString('storize.move.status', 'sideways');
      expect(await store.read(), MoveProgress.none);
      await prefs.setInt('storize.move.status', 3);
      expect(await store.read(), MoveProgress.none);
    });

    test('negative or wrong-typed counts read as zero', () async {
      await prefs.setString('storize.move.status', 'running');
      await prefs.setInt('storize.move.total', -5);
      await prefs.setString('storize.move.moved', 'x');
      final p = await store.read();
      expect(p.total, 0);
      expect(p.moved, 0);
    });

    test('only counts, names and a time are stored', () async {
      await store.write(
        const MoveProgress(
          status: MoveStatus.done,
          target: StorageTarget.gallery,
          total: 1,
          moved: 1,
        ),
      );
      final all = await prefs.getAll(allowList: SharedPrefsMoveStateStore.keys);
      for (final v in all.values) {
        expect(v.toString(), isNot(contains('/')));
        expect(v.toString(), isNot(contains('content:')));
      }
    });
  });
}
