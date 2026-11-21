import 'package:storize_domain/src/usecases/detect_gaps.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

const Duration ms1 = Duration(milliseconds: 1);
final DateTime t0 = s.t0;

void main() {
  late FakeClock clock;
  late FakeCheckRunRepo runs;
  late FakeSettingsRepo settings;
  late FakeActivityRepo activity;
  late DetectGaps detect;

  // Finishes a stories run that started at [startedAt] and ended at [end].
  Future<CheckRun> storyRun(DateTime startedAt, {DateTime? end}) async {
    final run = await runs.start(
      scope: CheckScope.stories,
      trigger: CheckTrigger.periodic,
      startedAt: startedAt,
    );
    return runs.finish(
      run.id,
      finishedAt: end ?? startedAt.add(const Duration(minutes: 1)),
      result: CheckResult.ok,
    );
  }

  Future<List<ActivityEvent>> gapEvents() async =>
      (await activity.watchRecent(types: {ActivityType.gap}).first).toList();

  setUp(() {
    clock = FakeClock(t0);
    runs = FakeCheckRunRepo();
    settings = FakeSettingsRepo(const AppSettings(storyIntervalMin: 60));
    activity = FakeActivityRepo(clock);
    detect = DetectGaps(
      checkRuns: runs,
      settings: settings,
      activity: activity,
    );
  });

  group('threshold = max(2×interval, interval + 30 min)', () {
    test('60 min interval gives 120 min; 15 min interval gives 45 min', () {
      expect(
        DetectGaps.thresholdFor(const Duration(minutes: 60)),
        const Duration(minutes: 120),
      );
      expect(
        DetectGaps.thresholdFor(const Duration(minutes: 15)),
        const Duration(minutes: 45),
      );
    });
  });

  group('gap rule boundaries (60 min interval, threshold 120 min)', () {
    const threshold = Duration(minutes: 120);

    test('exactly at the threshold is not a gap', () async {
      final end = t0;
      await storyRun(t0, end: end);
      clock.set(end.add(threshold));
      expect(await detect(clock.now()), isNull);
      expect(await gapEvents(), isEmpty);
    });

    test('threshold minus 1 ms is not a gap', () async {
      await storyRun(t0, end: t0);
      clock.set(t0.add(threshold - ms1));
      expect(await detect(clock.now()), isNull);
    });

    test('threshold plus 1 ms is a gap and writes one GAP event', () async {
      await storyRun(t0, end: t0);
      final now = t0.add(threshold + ms1);
      clock.set(now);
      final gap = await detect(now);
      expect(gap, isNotNull);
      expect(gap!.recorded, isTrue);
      expect(gap.length, threshold + ms1);
      final events = await gapEvents();
      expect(events, hasLength(1));
      expect(events.single.type, ActivityType.gap);
      expect(events.single.severity, Severity.warn);
      expect(events.single.at, now);
    });

    test('the baseline is the end of the last run, not its start', () async {
      // Run started at t0 and ended 10 min later: the silence counts from the
      // end, so t0 + threshold + 1 ms is 10 min short of a gap.
      await storyRun(t0, end: t0.add(const Duration(minutes: 10)));
      clock.set(t0.add(threshold + ms1));
      expect(await detect(clock.now()), isNull);
    });
  });

  group('one GAP event per gap', () {
    test('repeated calls for the same gap do not write again', () async {
      await storyRun(t0, end: t0);
      final now = t0.add(const Duration(hours: 5));
      clock.set(now);

      final first = await detect(now);
      final second = await detect(now.add(const Duration(minutes: 30)));
      final third = await detect(now.add(const Duration(hours: 1)));

      expect(first!.recorded, isTrue);
      expect(second!.recorded, isFalse);
      expect(third!.recorded, isFalse);
      expect(await gapEvents(), hasLength(1));
    });

    test(
      'a new story run closes the gap; the next gap is recorded anew',
      () async {
        await storyRun(t0, end: t0);
        clock.set(t0.add(const Duration(hours: 5)));
        await detect(clock.now());

        // A fresh run, then a second silence.
        final later = t0.add(const Duration(hours: 6));
        await storyRun(later, end: later);
        clock.set(later.add(const Duration(hours: 3)));
        final second = await detect(clock.now());

        expect(second!.recorded, isTrue);
        expect(await gapEvents(), hasLength(2));
      },
    );

    test('no gap is written while checks are on schedule', () async {
      await storyRun(t0, end: t0);
      clock.set(t0.add(const Duration(minutes: 30)));
      expect(await detect(clock.now()), isNull);
      expect(await gapEvents(), isEmpty);
    });
  });

  group('no baseline or other scope', () {
    test('no finished story run means no gap and no event', () async {
      clock.set(t0.add(const Duration(days: 3)));
      expect(await detect(clock.now()), isNull);
      expect(await gapEvents(), isEmpty);
    });

    test('a recent posts run does not count as a story run', () async {
      await storyRun(t0, end: t0);
      final posts = await runs.start(
        scope: CheckScope.posts,
        trigger: CheckTrigger.periodic,
        startedAt: t0.add(const Duration(hours: 4)),
      );
      await runs.finish(
        posts.id,
        finishedAt: t0.add(const Duration(hours: 4)),
        result: CheckResult.ok,
      );
      clock.set(t0.add(const Duration(hours: 4)));
      expect((await detect(clock.now()))!.recorded, isTrue);
    });
  });
}
