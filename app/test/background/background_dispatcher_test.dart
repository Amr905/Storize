import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/background_dispatcher.dart';
import 'package:storize_app/core/composition.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_model/storize_model.dart';

import '../core/composition_rig.dart';

void main() {
  late CompositionRig rig;
  var prepared = 0;

  setUp(() {
    rig = CompositionRig(background: true, closeDbOnDispose: false);
    prepared = 0;
  });
  tearDown(() => rig.dispose());

  Future<bool> run(
    String task, {
    Map<String, dynamic>? input,
    BackgroundCompose? compose,
    OpenDiagnostics? openDiagnostics,
    Duration hardLimit = const Duration(seconds: 5),
  }) => runBackgroundTask(
    task,
    input,
    compose: compose ?? (_) async => rig.composition,
    openDiagnostics: openDiagnostics ?? () async => rig.diagnostics,
    prepareIsolate: () => prepared++,
    hardLimit: hardLimit,
  );

  test(
    'prepares the isolate, starts up, routes and closes at the end',
    () async {
      final (_, media) = await rig.addMedia();
      await rig.cache.writeThumbnail(media, [1]);
      await rig.cache.writeThumbnail(4242, [2]);

      final done = await run(TaskNames.download);

      expect(done, isTrue);
      expect(prepared, 1);
      // Start-up sweeps ran before the task.
      expect(rig.cache.thumbnailBytes(4242), isNull);
      expect(rig.cache.thumbnailBytes(media), isNotNull);
      // The composition was closed.
      expect(rig.closed, 1);
    },
  );

  test('gap detection runs at the start of a background task', () async {
    final started = await rig.composition.checkRuns.start(
      scope: CheckScope.stories,
      trigger: CheckTrigger.periodic,
      startedAt: t0.subtract(const Duration(days: 2)),
    );
    await rig.composition.checkRuns.finish(
      started.id,
      finishedAt: t0.subtract(const Duration(days: 2)),
      result: CheckResult.ok,
    );

    await run(TaskNames.retention);

    final events = await rig.composition.activity
        .watchRecent(types: {ActivityType.gap})
        .first;
    expect(events, hasLength(1));
  });

  test(
    'a check task with no account is done without any network call',
    () async {
      final done = await run(TaskNames.checkStories);

      expect(done, isTrue);
      expect(rig.network.sends, 0);
      final runs = rig.composition.checkRuns;
      expect(
        (await runs.lastFinished(CheckScope.stories))?.result,
        CheckResult.skippedSession,
      );
    },
  );

  test('a composition that cannot be built is a retry', () async {
    final done = await run(
      TaskNames.checkStories,
      compose: (_) async => throw StateError('database is locked'),
    );
    expect(done, isFalse);
  });

  test('a task that never ends is a retry at the hard limit', () async {
    final never = Completer<AppComposition>();
    final done = await run(
      TaskNames.checkStories,
      compose: (_) => never.future,
      hardLimit: const Duration(milliseconds: 50),
    );
    expect(done, isFalse);
  });

  test('diagnostics that cannot open do not stop the task', () async {
    var composed = 0;
    final done = await run(
      TaskNames.retention,
      openDiagnostics: () async => throw const FileSystemException('x'),
      compose: (_) async {
        composed++;
        return rig.composition;
      },
    );
    expect(done, isTrue);
    expect(composed, 1);
  });

  test(
    'an uncaught async error becomes an APP_CRASH event, not lost',
    () async {
      final done = await run(
        TaskNames.retention,
        compose: (_) async {
          unawaited(Future<void>.error(StateError('late failure')));
          return rig.composition;
        },
      );
      await pumpEventQueue();

      expect(done, isTrue);
      // The zone handler wrote the marker and start-up turned it into an event.
      final events = await rig.composition.activity
          .watchRecent(types: {ActivityType.appCrash})
          .first;
      expect(events, hasLength(1));
    },
  );
}
