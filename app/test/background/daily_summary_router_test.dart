import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/background/task_router.dart';
import 'package:storize_data/scheduler/scheduler.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

final DateTime _now = DateTime.utc(2026, 11, 27, 18); // 20:00 at UTC+2

/// Records the order of notify and schedule calls in one list.
final class _Order {
  final List<String> steps = [];
}

final class _Notifier implements TaskNotifier {
  _Notifier(this.order);

  final _Order order;
  final List<SavedCounts> summaries = [];
  bool throws = false;

  @override
  Future<void> dailySummary(SavedCounts counts) async {
    order.steps.add('notify');
    if (throws) throw StateError('no notifier');
    summaries.add(counts);
  }

  @override
  Future<void> newItemsSaved(
    DownloadPendingResult downloads, {
    CheckRunResult? check,
  }) async {}

  @override
  Future<void> sessionChanged(AccountStatus status) async {}

  @override
  Future<void> storageFull() async {}

  @override
  Future<void> checkingStarted(int accounts) async {}

  @override
  Future<void> checkingDone() async {}
}

final class _Scheduler implements DailySummaryScheduler {
  _Scheduler(this.order);

  final _Order order;
  final List<NotificationMode> modes = [];

  @override
  Future<void> schedule({
    required NotificationMode mode,
    required SummaryTime time,
    required DateTime nowUtc,
    required Duration localOffset,
  }) async {
    order.steps.add('schedule');
    modes.add(mode);
  }
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

/// A content repo whose count fails.
final class _BrokenContent implements ContentRepo {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #savedSince) throw StateError('db down');
    return super.noSuchMethod(invocation);
  }
}

Future<void> _saveStory(FakeContentRepo content) async {
  await content.insertIfNew(
    Content(
      id: Content.unsavedId,
      targetId: 1,
      kind: ContentKind.story,
      remoteId: 's1',
      postedAt: _now,
      slideCount: 1,
      detectedAt: _now,
    ),
    [
      MediaFile(
        id: MediaFile.unsavedId,
        contentId: MediaFile.unsavedContentId,
        slideIndex: 0,
        mediaType: MediaType.photo,
        sourceUrl: 'https://cdn.example.invalid/s1',
        status: MediaFileStatus.done,
        downloadedAt: _now,
      ),
    ],
  );
}

void main() {
  late _Order order;
  late _Notifier notifier;
  late _Scheduler scheduler;
  late FakeContentRepo content;
  late FakeSettingsRepo settings;

  setUp(() {
    order = _Order();
    notifier = _Notifier(order);
    scheduler = _Scheduler(order);
    content = FakeContentRepo();
    settings = FakeSettingsRepo(
      const AppSettings(notificationMode: NotificationMode.daily),
    );
  });

  TaskRouter router({ContentRepo? repo, bool withTask = true}) => TaskRouter(
    runCheck: ({required scope, required trigger, targetId, deadline}) async =>
        throw StateError('not used'),
    download: ({deadline, policy = ExtractionPolicy.directOnly}) async =>
        throw StateError('not used'),
    retention: () async => null,
    updateCheck: () async => null,
    settings: settings,
    clock: FakeClock(_now),
    enqueuer: _NoEnqueue(),
    notifier: notifier,
    dailySummary: withTask
        ? DailySummaryTask(
            settings: settings,
            content: repo ?? content,
            clock: FakeClock(_now),
            scheduler: scheduler,
            localOffset: () => const Duration(hours: 2),
          )
        : null,
  );

  test('daily with items notifies once, then re-schedules last', () async {
    await _saveStory(content);
    final ok = await router().route(TaskNames.dailySummary);
    expect(ok, isTrue);
    expect(notifier.summaries.single.stories, 1);
    expect(order.steps, ['notify', 'schedule']);
  });

  test(
    'daily with nothing saved shows nothing and still re-schedules',
    () async {
      expect(await router().route(TaskNames.dailySummary), isTrue);
      expect(notifier.summaries, isEmpty);
      expect(scheduler.modes, [NotificationMode.daily]);
    },
  );

  test('per item mode shows no summary and cancels the pending run', () async {
    settings = FakeSettingsRepo();
    await _saveStory(content);
    expect(await router().route(TaskNames.dailySummary), isTrue);
    expect(notifier.summaries, isEmpty);
    expect(scheduler.modes, [NotificationMode.perItem]);
  });

  test('a failed count asks for a retry and still re-schedules', () async {
    final ok = await router(repo: _BrokenContent())
        .route(TaskNames.dailySummary);
    expect(ok, isFalse);
    expect(order.steps, ['schedule']);
  });

  test('a failing notifier does not stop the re-schedule', () async {
    await _saveStory(content);
    notifier.throws = true;
    expect(await router().route(TaskNames.dailySummary), isTrue);
    expect(order.steps, ['notify', 'schedule']);
  });

  test('without a daily task the run does nothing', () async {
    await _saveStory(content);
    expect(
      await router(withTask: false).route(TaskNames.dailySummary),
      isTrue,
    );
    expect(order.steps, isEmpty);
  });
}
