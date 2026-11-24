import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/app.dart';
import 'package:storize_app/core/composition.dart';
import 'package:storize_app/core/composition_production.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/main.dart';
import 'package:storize_app/startup_error.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'composition_rig.dart';

void main() {
  late CompositionRig rig;

  setUp(() => rig = CompositionRig());
  tearDown(() => rig.dispose());

  AppComposition c() => rig.composition;

  group('start-up sweeps', () {
    test('a downloaded item thumbnail survives start-up', () async {
      final (_, media) = await rig.addMedia();
      await rig.cache.writeThumbnail(media, [1, 2, 3]);

      final report = await c().start();

      expect(rig.cache.thumbnailBytes(media), [1, 2, 3]);
      expect(report.thumbnailsRemoved, 0);
    });

    test('a thumbnail of no media file is removed', () async {
      final (_, media) = await rig.addMedia();
      await rig.cache.writeThumbnail(media, [1]);
      await rig.cache.writeThumbnail(9999, [9]);

      final report = await c().start();

      expect(rig.cache.thumbnailBytes(9999), isNull);
      expect(rig.cache.thumbnailBytes(media), isNotNull);
      expect(report.thumbnailsRemoved, 1);
    });

    test('thumbnails of pending and failed items are kept too', () async {
      final (_, pending) = await rig.addMedia(
        status: MediaFileStatus.pending,
        remoteId: 'p',
        remoteUserId: '1',
      );
      final (_, failed) = await rig.addMedia(
        status: MediaFileStatus.failed,
        remoteId: 'f',
        remoteUserId: '2',
      );
      await rig.cache.writeThumbnail(pending, [1]);
      await rig.cache.writeThumbnail(failed, [2]);

      await c().start();

      expect(rig.cache.thumbnailBytes(pending), isNotNull);
      expect(rig.cache.thumbnailBytes(failed), isNotNull);
    });

    test('orphan .part files go, the part of a pending item stays', () async {
      final (_, pending) = await rig.addMedia(status: MediaFileStatus.pending);
      await rig.cache.append(pending, Stream.value([1, 2]));
      await rig.cache.append(777, Stream.value([3]));

      final report = await c().start();

      expect(rig.cache.partIds, {pending});
      expect(report.partsRemoved, 1);
      expect(report.partSweepSkipped, isFalse);
    });

    test('the .part sweep waits while a download holds the lease', () async {
      await rig.cache.append(777, Stream.value([3]));
      final held = await c().leases.acquire(
        accountId: DownloadPending.leaseKey,
        holder: 'other-isolate-download',
        ttl: const Duration(minutes: 10),
        initialBucket: GovernorBucket(tokens: 0, lastRefillAt: t0),
      );
      expect(held, isNotNull);

      final report = await c().start();

      expect(report.partSweepSkipped, isTrue);
      expect(rig.cache.partIds, {777}, reason: 'a running download owns it');
    });

    test('the sweep lease is released afterwards', () async {
      await c().start();
      final lease = await c().leases.read(DownloadPending.leaseKey);
      expect(lease == null || !lease.expiresAt.isAfter(t0), isTrue);
      final again = await c().leases.acquire(
        accountId: DownloadPending.leaseKey,
        holder: 'next',
        ttl: const Duration(minutes: 1),
        initialBucket: GovernorBucket(tokens: 0, lastRefillAt: t0),
      );
      expect(again, isNotNull);
    });
  });

  group('gap detection at every start (AC4)', () {
    Future<void> storyRunAt(DateTime at) async {
      final run = await c().checkRuns.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: at,
      );
      await c().checkRuns.finish(
        run.id,
        finishedAt: at,
        result: CheckResult.ok,
      );
    }

    test('a long silence records a GAP event and returns it', () async {
      await storyRunAt(t0.subtract(const Duration(days: 1)));

      final report = await c().start();

      expect(report.gap, isNotNull);
      expect(report.gap!.recorded, isTrue);
      final events = await c().activity
          .watchRecent(types: {ActivityType.gap})
          .first;
      expect(events, hasLength(1));
    });

    test('each start runs it, and the same gap is recorded once', () async {
      await storyRunAt(t0.subtract(const Duration(days: 1)));

      await c().start();
      final second = await c().start();

      expect(second.gap, isNotNull);
      expect(second.gap!.recorded, isFalse);
      final events = await c().activity
          .watchRecent(types: {ActivityType.gap})
          .first;
      expect(events, hasLength(1));
    });

    test('on schedule means no gap', () async {
      await storyRunAt(t0.subtract(const Duration(minutes: 5)));
      expect((await c().start()).gap, isNull);
    });

    test(
      'a failing step is logged by type and does not stop the others',
      () async {
        final broken = CompositionRig(wrapCache: ThumbSweepFails.new);
        addTearDown(broken.dispose);
        final run = await broken.composition.checkRuns.start(
          scope: CheckScope.stories,
          trigger: CheckTrigger.periodic,
          startedAt: t0.subtract(const Duration(days: 1)),
        );
        await broken.composition.checkRuns.finish(
          run.id,
          finishedAt: t0.subtract(const Duration(days: 1)),
          result: CheckResult.ok,
        );

        final report = await broken.composition.start();

        expect(report.gap, isNotNull);
        final messages = broken.log.entries.map((e) => e.message).join('\n');
        expect(messages, contains('step_failed step=thumbnail_sweep'));
        expect(messages, contains('StateError'));
        expect(messages, isNot(contains('secret')));
      },
    );
  });

  group('crash report', () {
    test('a pending crash marker becomes one APP_CRASH event', () async {
      rig.diagnostics.marker.write(StateError('boom'), t0);

      final first = await c().start();
      final second = await c().start();

      expect(first.crashReported, isTrue);
      expect(second.crashReported, isFalse);
      final events = await c().activity
          .watchRecent(types: {ActivityType.appCrash})
          .first;
      expect(events, hasLength(1));
    });
  });

  group('wiring', () {
    test('each composition has its own holder and isolate kind', () async {
      final other = CompositionRig(background: true);
      addTearDown(other.dispose);

      expect(c().background, isFalse);
      expect(other.composition.background, isTrue);
      expect(other.composition.holder, startsWith('bg-'));
      expect(c().holder, startsWith('ui-'));
      expect(other.composition.holder, isNot(c().holder));
    });

    test('with no account every call fails closed and sends nothing', () async {
      final result = await c().platform.fetchStories(const [
        '1',
      ], policy: ExtractionPolicy.directOnly);

      expect(result.failureOrNull, isA<SessionInvalid>());
      expect(rig.network.sends, 0);
    });

    test('the hook script is loaded once for all accounts', () async {
      await c().platform.verifySession();
      await c().platform.verifySession();
      expect(rig.hookLoads, 1);
    });

    test('dispose closes the parts', () async {
      await c().dispose();
      expect(rig.closed, 1);
    });
  });

  group('schedule at start (AC1, AC5)', () {
    test('apply runs with the settings at start', () async {
      c().keepScheduleApplied();
      await pumpEventQueue();

      expect(rig.scheduler.applyCalls, hasLength(1));
      final call = rig.scheduler.applyCalls.single;
      const defaults = AppSettings();
      expect(call.storyMin, defaults.storyIntervalMin);
      expect(call.postMin, defaults.postIntervalMin);
      expect(call.wifiOnly, defaults.wifiOnly);
    });

    test('a change of interval or Wi-Fi only re-applies', () async {
      c().keepScheduleApplied();
      await pumpEventQueue();

      await rig.settings.update(
        (s) => s.copyWith(storyIntervalMin: 30, wifiOnly: true),
      );
      await pumpEventQueue();

      expect(rig.scheduler.applyCalls, hasLength(2));
      expect(rig.scheduler.applyCalls.last.storyMin, 30);
      expect(rig.scheduler.applyCalls.last.wifiOnly, isTrue);
    });

    test('an unrelated setting change does not re-apply', () async {
      c().keepScheduleApplied();
      await pumpEventQueue();

      await rig.settings.update((s) => s.copyWith(notifyPosts: false));
      await pumpEventQueue();

      expect(rig.scheduler.applyCalls, hasLength(1));
    });

    test('a failing scheduler is logged, not thrown', () async {
      final failing = CompositionRig();
      addTearDown(failing.dispose);
      // Replace the scheduler of a second composition with one that throws.
      final composition = AppComposition.assemble(
        CompositionParts(
          db: failing.db,
          settings: failing.settings,
          sessions: failing.sessions,
          gallery: failing.parts.gallery,
          cache: failing.cache,
          storage: failing.parts.storage,
          igHttp: failing.network,
          cdnHttp: failing.network,
          pageDriver: NoPages(),
          hookSource: () async => '',
          seenStore: failing.parts.seenStore,
          log: failing.log,
          scheduler: _ThrowingScheduler(),
          enqueuer: failing.enqueuer,
          updateChecker: failing.parts.updateChecker,
          currentVersion: '0.1.0',
          pins: failing.parts.pins,
          biometric: failing.parts.biometric,
          clock: failing.clock,
        ),
        background: false,
      )..keepScheduleApplied();
      await pumpEventQueue();

      expect(
        failing.log.entries.map((e) => e.message),
        contains(startsWith('apply_failed')),
      );
      await composition.dispose();
    });
  });

  group('provider overrides', () {
    test('every port is wired and the lock bypass is untouched', () async {
      final container = ProviderContainer(overrides: appOverrides(c()));
      addTearDown(container.dispose);

      expect(container.read(targetRepoProvider), same(c().targets));
      expect(container.read(contentRepoProvider), same(c().content));
      expect(container.read(settingsRepoProvider), same(c().settings));
      expect(container.read(contentPlatformProvider), same(c().platform));
      expect(container.read(schedulerProvider), same(c().scheduler));
      expect(container.read(sessionStoreProvider), same(rig.sessions));
      expect(container.read(galleryStoreProvider), same(rig.parts.gallery));
      expect(container.read(pinStoreProvider), same(rig.parts.pins));
      expect(container.read(appLockTestBypassProvider), isFalse);
    });

    test('no override targets appLockTestBypassProvider', () {
      final overrides = appOverrides(c());
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      expect(container.read(appLockTestBypassProvider), isFalse);
      // The same overrides plus an explicit bypass flip it: proof that only
      // an extra override could, and appOverrides adds none.
      final bypassed = ProviderContainer(
        overrides: [
          ...overrides,
          appLockTestBypassProvider.overrideWithValue(true),
        ],
      );
      addTearDown(bypassed.dispose);
      expect(bypassed.read(appLockTestBypassProvider), isTrue);
    });

    test('Check now calls the real scheduler', () async {
      final container = ProviderContainer(overrides: appOverrides(c()));
      addTearDown(container.dispose);

      final result = await container.read(checkNowActionProvider).call();

      expect(result.failed, isFalse);
      expect(rig.scheduler.checkNowCalls, [
        (scope: CheckScope.all, targetId: null),
      ]);
    });

    test('Check now for one target passes its id to the scheduler', () async {
      final container = ProviderContainer(overrides: appOverrides(c()));
      addTearDown(container.dispose);

      await container.read(checkNowActionProvider).call(targetId: 7);

      expect(rig.scheduler.checkNowCalls, [
        (scope: CheckScope.all, targetId: 7),
      ]);
    });

    test('Check now reports failure when enqueueing fails', () async {
      final action = SchedulerCheckNowAction(_ThrowingScheduler());
      expect((await action.call()).failed, isTrue);
    });
  });

  group('clearStagingSession', () {
    SessionBlob blob() => SessionBlob(
      cookies: const {'sessionid': 'S', 'ds_user_id': '1'},
      userAgent: 'UA',
      capturedAt: DateTime.utc(2026),
    );

    test('removes a leftover staging session, keeps real accounts', () async {
      await rig.sessions.save(LoginAccount.unsavedId, blob());
      await rig.sessions.save(5, blob());

      await c().clearStagingSession();

      expect(rig.sessions.accountIds, {5});
    });

    test('a failing store is ignored and logged without values', () async {
      final failing = CompositionRig();
      addTearDown(failing.composition.dispose);
      final composition = AppComposition.assemble(
        CompositionParts(
          db: failing.db,
          settings: failing.settings,
          sessions: _ThrowingSessions(),
          gallery: failing.parts.gallery,
          cache: failing.cache,
          storage: failing.parts.storage,
          igHttp: failing.network,
          cdnHttp: failing.network,
          pageDriver: NoPages(),
          hookSource: () async => '',
          seenStore: failing.parts.seenStore,
          log: failing.log,
          scheduler: failing.scheduler,
          enqueuer: failing.enqueuer,
          updateChecker: failing.parts.updateChecker,
          currentVersion: '0.1.0',
          pins: failing.parts.pins,
          biometric: failing.parts.biometric,
          clock: failing.clock,
        ),
        background: false,
      );

      await composition.clearStagingSession();

      final warns = failing.log.entries.where((e) => e.level == LogLevel.warn);
      expect(warns.any((e) => e.message.contains('StateError')), isTrue);
      expect(
        failing.log.entries.any((e) => e.message.contains('secret-value')),
        isFalse,
      );
    });
  });

  group('buildApp (main)', () {
    test(
      'wires the app, initialises WorkManager and starts the schedule',
      () async {
        var initialised = 0;
        final widget = await buildApp(
          diagnostics: rig.diagnostics,
          compose: (_) async => c(),
          initializeWorkmanager: () async => initialised++,
        );
        await pumpEventQueue();

        expect(widget, isA<StorizeApp>());
        expect((widget as StorizeApp).overrides, isNotEmpty);
        expect(initialised, 1);
        expect(rig.scheduler.applyCalls, hasLength(1));
      },
    );

    test('foreground start clears a leftover staging session', () async {
      await rig.sessions.save(
        LoginAccount.unsavedId,
        SessionBlob(
          cookies: const {'sessionid': 'S', 'ds_user_id': '1'},
          userAgent: 'UA',
          capturedAt: DateTime.utc(2026),
        ),
      );
      await buildApp(
        diagnostics: rig.diagnostics,
        compose: (_) async => c(),
        initializeWorkmanager: () async {},
      );
      await pumpEventQueue();

      expect(rig.sessions.accountIds, isEmpty);
    });

    test(
      'a failing composition shows the start-up error, not an unwired app',
      () async {
        final widget = await buildApp(
          diagnostics: rig.diagnostics,
          compose: (_) async => throw StateError('db'),
          initializeWorkmanager: () async {},
        );

        expect(widget, isA<StartupErrorApp>());
        final details = (widget as StartupErrorApp).details();
        expect(details, contains('type=StateError'));
        expect(details, contains('db'));
      },
    );
  });
}

final class _ThrowingScheduler implements Scheduler {
  @override
  Future<void> apply({
    required int storyMin,
    required int postMin,
    required bool wifiOnly,
  }) async => throw StateError('no workmanager');

  @override
  Future<void> checkNow({
    CheckScope scope = CheckScope.all,
    int? targetId,
    bool unmetered = false,
  }) async => throw StateError('no workmanager');

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> kickHistory() async {}
}

final class _ThrowingSessions implements SessionStore {
  @override
  Future<void> save(int accountId, SessionBlob session) async {}

  @override
  Future<SessionBlob?> load(int accountId) async => null;

  @override
  Future<void> clear(int accountId) async => throw StateError('secret-value');
}
