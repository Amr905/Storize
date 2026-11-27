import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

Content _content(int targetId, String remoteId, ContentKind kind) => Content(
  id: Content.unsavedId,
  targetId: targetId,
  kind: kind,
  remoteId: remoteId,
  postedAt: DateTime.utc(2026, 11, 20),
  slideCount: 1,
  detectedAt: DateTime.utc(2026, 11, 20),
);

/// Stores one content item with one DONE file downloaded at [at].
Future<void> _saved(
  FakeContentRepo repo,
  int targetId,
  String remoteId,
  ContentKind kind,
  DateTime at,
) async {
  await repo.insertIfNew(_content(targetId, remoteId, kind), [
    MediaFile(
      id: MediaFile.unsavedId,
      contentId: MediaFile.unsavedContentId,
      slideIndex: 0,
      mediaType: MediaType.photo,
      sourceUrl: 'https://cdn.example.invalid/$remoteId',
      status: MediaFileStatus.done,
      downloadedAt: at,
    ),
  ]);
}

/// A content repo whose count fails, to check the reschedule still happens.
final class _BrokenContent implements ContentRepo {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #savedSince) throw StateError('db down');
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('SummaryWindow.localMidnightUtc', () {
    test('UTC: midday gives that day midnight', () {
      expect(
        SummaryWindow.localMidnightUtc(
          DateTime.utc(2026, 11, 27, 9, 30),
          Duration.zero,
        ),
        DateTime.utc(2026, 11, 27),
      );
    });

    test('UTC+02:00: 23:30 UTC is already the next local day', () {
      // 23:30 UTC on the 27th is 01:30 on the 28th at UTC+2.
      expect(
        SummaryWindow.localMidnightUtc(
          DateTime.utc(2026, 11, 27, 23, 30),
          const Duration(hours: 2),
        ),
        DateTime.utc(2026, 11, 27, 22),
      );
    });

    test('UTC-05:00: early UTC is still the previous local day', () {
      // 04:00 UTC on the 27th is 23:00 on the 26th at UTC-5.
      expect(
        SummaryWindow.localMidnightUtc(
          DateTime.utc(2026, 11, 27, 4),
          const Duration(hours: -5),
        ),
        DateTime.utc(2026, 11, 26, 5),
      );
    });

    test('the exact local midnight and one second before it', () {
      const plus2 = Duration(hours: 2);
      expect(
        SummaryWindow.localMidnightUtc(DateTime.utc(2026, 11, 27, 22), plus2),
        DateTime.utc(2026, 11, 27, 22),
      );
      expect(
        SummaryWindow.localMidnightUtc(
          DateTime.utc(2026, 11, 27, 21, 59, 59),
          plus2,
        ),
        DateTime.utc(2026, 11, 26, 22),
      );
    });
  });

  group('SummaryWindow.delayUntilNext', () {
    const plus2 = Duration(hours: 2);

    test('later today, then exactly now gives the full day', () {
      final now = DateTime.utc(2026, 11, 27, 18); // 20:00 local
      expect(
        SummaryWindow.delayUntilNext(SummaryTime.defaultTime, now, plus2),
        const Duration(hours: 1),
      );
      final atNine = DateTime.utc(2026, 11, 27, 19); // 21:00 local
      expect(
        SummaryWindow.delayUntilNext(SummaryTime.defaultTime, atNine, plus2),
        const Duration(hours: 24),
      );
    });

    test('a time already passed gives tomorrow', () {
      final now = DateTime.utc(2026, 11, 27, 18); // 20:00 local
      expect(
        SummaryWindow.delayUntilNext(const SummaryTime(7, 0), now, plus2),
        const Duration(hours: 11),
      );
    });
  });

  group('CountSavedToday', () {
    test('counts from local midnight, not UTC midnight (UTC+02:00)', () async {
      final repo = FakeContentRepo();
      // Local midnight of the 27th at UTC+2 is 26th 22:00 UTC.
      await _saved(
        repo,
        1,
        'before',
        ContentKind.story,
        DateTime.utc(2026, 11, 26, 21, 59),
      );
      await _saved(
        repo,
        1,
        'at-midnight',
        ContentKind.story,
        DateTime.utc(2026, 11, 26, 22),
      );
      await _saved(
        repo,
        2,
        'post',
        ContentKind.post,
        DateTime.utc(2026, 11, 27, 10),
      );
      final count = CountSavedToday(
        content: repo,
        clock: FakeClock(DateTime.utc(2026, 11, 27, 18)),
        localOffset: () => const Duration(hours: 2),
      );
      final counts = await count();
      expect(counts.stories, 1);
      expect(counts.posts, 1);
      expect(counts.accounts, 2);
    });

    test('UTC-05:00 counts from the earlier local midnight', () async {
      final repo = FakeContentRepo();
      await _saved(
        repo,
        1,
        'yesterday-late',
        ContentKind.story,
        DateTime.utc(2026, 11, 26, 4, 59),
      );
      await _saved(
        repo,
        1,
        'today',
        ContentKind.story,
        DateTime.utc(2026, 11, 26, 5),
      );
      final count = CountSavedToday(
        content: repo,
        clock: FakeClock(DateTime.utc(2026, 11, 27, 4)),
        localOffset: () => const Duration(hours: -5),
      );
      expect((await count()).stories, 1);
    });

    test(
      'highlights and reels: reels are posts, highlights count apart',
      () async {
        final repo = FakeContentRepo();
        final at = DateTime.utc(2026, 11, 27, 9);
        await _saved(repo, 1, 'reel', ContentKind.post, at);
        await _saved(repo, 1, 'hl', ContentKind.highlight, at);
        final count = CountSavedToday(
          content: repo,
          clock: FakeClock(DateTime.utc(2026, 11, 27, 10)),
          localOffset: () => Duration.zero,
        );
        final counts = await count();
        expect(counts.posts, 1);
        expect(counts.highlights, 1);
        expect(counts.total, 2);
        expect(counts.accounts, 1);
      },
    );
  });

  group('DailySummaryTask', () {
    late FakeContentRepo content;
    late FakeClock clock;
    late FakeDailySummaryScheduler scheduler;
    late SettingsRepo settings;

    DailySummaryTask task() => DailySummaryTask(
      settings: settings,
      content: content,
      clock: clock,
      scheduler: scheduler,
      localOffset: () => const Duration(hours: 2),
    );

    setUp(() {
      content = FakeContentRepo();
      clock = FakeClock(DateTime.utc(2026, 11, 27, 18)); // 20:00 local
      scheduler = FakeDailySummaryScheduler();
    });

    test('per item and off show nothing; reschedule cancels', () async {
      for (final mode in [NotificationMode.perItem, NotificationMode.off]) {
        settings = FakeSettingsRepo(AppSettings(notificationMode: mode));
        await _saved(content, 1, 'x$mode', ContentKind.story, clock.now());
        expect(await task().countToday(), isNull);
        await task().reschedule();
      }
      expect(scheduler.calls.map((c) => c.mode), [
        NotificationMode.perItem,
        NotificationMode.off,
      ]);
    });

    test(
      'daily with nothing saved gives null; reschedule keeps daily',
      () async {
        settings = FakeSettingsRepo(
          const AppSettings(notificationMode: NotificationMode.daily),
        );
        expect(await task().countToday(), isNull);
        await task().reschedule();
        final call = scheduler.calls.single;
        expect(call.mode, NotificationMode.daily);
        expect(call.time, SummaryTime.defaultTime);
        expect(call.nowUtc, clock.now());
        expect(call.localOffset, const Duration(hours: 2));
      },
    );

    test(
      'daily with items gives the counts; counting never schedules',
      () async {
        settings = FakeSettingsRepo(
          const AppSettings(notificationMode: NotificationMode.daily),
        );
        await _saved(content, 1, 's', ContentKind.story, clock.now());
        final counts = await task().countToday();
        expect(counts?.stories, 1);
        expect(scheduler.calls, isEmpty);
      },
    );

    test(
      'a failing count propagates; reschedule still works after it',
      () async {
        settings = FakeSettingsRepo(
          const AppSettings(notificationMode: NotificationMode.daily),
        );
        final broken = DailySummaryTask(
          settings: settings,
          content: _BrokenContent(),
          clock: clock,
          scheduler: scheduler,
          localOffset: () => Duration.zero,
        );
        await expectLater(broken.countToday(), throwsStateError);
        await broken.reschedule();
        expect(scheduler.calls.single.mode, NotificationMode.daily);
      },
    );
  });
}
