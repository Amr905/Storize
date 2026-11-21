import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/activity/activity_entry.dart';
import 'package:storize_app/features/activity/activity_model.dart';
import 'package:storize_app/features/activity/activity_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'activity_rig.dart';

void main() {
  group('AC1 entry types get the right tone and icon', () {
    testWidgets('every ActivityType maps to an entry', (t) async {
      final rig = ActivityRig();
      final target = await rig.addTarget('nour_k');
      final out = <ActivityType, ActivityEntry>{};
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: StorizeTheme.light(),
          home: Builder(
            builder: (context) {
              for (final type in ActivityType.values) {
                out[type] = describeActivity(
                  context,
                  ActivityEvent(
                    id: 1,
                    at: activityNow,
                    type: type,
                    targetId: target.id,
                  ),
                  {target.id: target},
                );
              }
              return const SizedBox();
            },
          ),
        ),
      );
      expect(out.keys.toSet(), ActivityType.values.toSet());
      for (final e in out.values) {
        expect(e.text, isNotEmpty);
      }
      expect(out[ActivityType.gap]!.tone, ActivityTone.warning);
      expect(out[ActivityType.gap]!.icon, Icons.warning_amber_rounded);
      expect(out[ActivityType.appCrash]!.tone, ActivityTone.error);
      expect(out[ActivityType.storagePaused]!.tone, ActivityTone.error);
      expect(out[ActivityType.sessionProblem]!.tone, ActivityTone.error);
      expect(
        out[ActivityType.removedBeforeDownload]!.tone,
        ActivityTone.neutral,
        reason: 'EC-7: shown as info, not an error',
      );
      expect(out[ActivityType.checkDone]!.tone, ActivityTone.success);
      expect(out[ActivityType.pageModeUsed]!.tone, ActivityTone.info);
      expect(out[ActivityType.rateLimited]!.tone, ActivityTone.warning);
      expect(out[ActivityType.storageLow]!.tone, ActivityTone.warning);
    });
  });

  group('AC2 filter chips', () {
    testWidgets('shows All / Downloads / Errors / Gaps, All selected', (
      t,
    ) async {
      final rig = ActivityRig();
      await seedActivity(rig);
      await pumpActivity(t, rig);
      for (final label in ['All', 'Downloads', 'Errors', 'Gaps']) {
        expect(find.widgetWithText(FilterChip, label), findsOneWidget);
      }
      expect(
        t.widget<FilterChip>(find.widgetWithText(FilterChip, 'All')).selected,
        isTrue,
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('Downloads shows only download entries', (t) async {
      final rig = ActivityRig();
      await seedActivity(rig);
      await pumpActivity(t, rig);
      await t.tap(find.widgetWithText(FilterChip, 'Downloads'));
      await t.pumpAndSettle();
      expect(find.textContaining('stories downloaded'), findsOneWidget);
      expect(find.textContaining('posts downloaded'), findsOneWidget);
      expect(find.textContaining('Checked 12 accounts'), findsNothing);
      expect(find.textContaining('Gap:'), findsNothing);
    });

    testWidgets('Errors shows problems only', (t) async {
      final rig = ActivityRig();
      await seedActivity(rig);
      await pumpActivity(t, rig);
      await t.tap(find.widgetWithText(FilterChip, 'Errors'));
      await t.pumpAndSettle();
      expect(
        find.text('Instagram slowed us down · checks slowed'),
        findsOneWidget,
      );
      expect(find.text('Instagram login needs attention'), findsOneWidget);
      expect(find.text('Instagram changed — update Storize'), findsOneWidget);
      expect(find.textContaining('downloaded'), findsNothing);
      expect(find.textContaining('Gap:'), findsNothing);
    });

    testWidgets('Gaps shows gap entries only', (t) async {
      final rig = ActivityRig();
      await seedActivity(rig);
      await pumpActivity(t, rig);
      await t.tap(find.widgetWithText(FilterChip, 'Gaps'));
      await t.pumpAndSettle();
      expect(find.textContaining('Gap:'), findsOneWidget);
      expect(find.textContaining('downloaded'), findsNothing);
      expect(
        find.text('Yesterday'),
        findsNothing,
        reason: 'no header for a day without entries',
      );
    });

    testWidgets('a filter with no matches shows the filtered empty state', (
      t,
    ) async {
      final rig = ActivityRig();
      final nour = await rig.addTarget('nour_k');
      await rig.add(ActivityType.downloadedStories, activityNow, target: nour);
      await pumpActivity(t, rig);
      await t.tap(find.widgetWithText(FilterChip, 'Gaps'));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
    });
  });

  group('AC3 actions', () {
    testWidgets('gap action opens S-03', (t) async {
      final rig = ActivityRig();
      await seedActivity(rig);
      await pumpActivity(t, rig);
      await t.tap(find.text('Fix battery settings'));
      await t.pumpAndSettle();
      expect(find.text('S-03 setup'), findsOneWidget);
    });

    testWidgets('session entry opens S-13', (t) async {
      final rig = ActivityRig();
      await seedActivity(rig);
      await pumpActivity(t, rig);
      await t.tap(find.text('Instagram login needs attention'));
      await t.pumpAndSettle();
      expect(find.text('S-13 account'), findsOneWidget);
    });

    testWidgets('a download that names its item opens the viewer', (t) async {
      final rig = ActivityRig();
      final nour = await rig.addTarget('nour_k');
      await rig.add(
        ActivityType.downloadedStories,
        activityNow,
        target: nour,
        payload: {'contentId': 42},
      );
      await pumpActivity(t, rig);
      await t.tap(find.textContaining('stories downloaded'));
      await t.pumpAndSettle();
      expect(find.text('S-06 story 42'), findsOneWidget);
    });

    testWidgets(
      'a download without an item ID opens the Library for its account',
      (t) async {
        final rig = ActivityRig();
        await seedActivity(rig);
        await pumpActivity(t, rig);
        await t.tap(find.textContaining('stories downloaded'));
        await t.pumpAndSettle();
        expect(find.text('S-04 library'), findsOneWidget);
      },
    );

    testWidgets('read-only entries do not navigate', (t) async {
      final rig = ActivityRig();
      await seedActivity(rig);
      await pumpActivity(t, rig);
      await t.tap(find.textContaining('not an error'));
      await t.pumpAndSettle();
      expect(
        find.text(
          AppLocalizations.of(t.element(find.byType(Scaffold).first))
              .screenActivity,
        ),
        findsOneWidget,
      );
    });
  });

  group('AC4 7-day window', () {
    test('buildActivityView drops entries older than 7 days', () {
      final nour = Target(
        id: 1,
        platform: PlatformId.instagram,
        remoteUserId: 'u',
        username: 'nour_k',
        category: TargetCategory.ownClient,
        postsWatermarkAt: DateTime.utc(2026),
        addedAt: DateTime.utc(2026),
      );
      final now = activityNow;
      final view = buildActivityView(
        events: [
          ActivityEvent(
            id: 1,
            at: now.subtract(const Duration(days: 6)),
            type: ActivityType.checkDone,
          ),
          ActivityEvent(
            id: 2,
            at: now.subtract(const Duration(days: 8)),
            type: ActivityType.checkDone,
          ),
        ],
        filter: ActivityFilter.all,
        now: now,
        targetsById: {1: nour},
      );
      expect(view.inWindow, 1);
      expect(view.itemCount, 1);
    });

    testWidgets('the page never shows an entry older than 7 days', (t) async {
      final rig = ActivityRig();
      await seedActivity(rig);
      await pumpActivity(t, rig);
      expect(find.textContaining('9 posts downloaded'), findsNothing);
      expect(find.textContaining('2 posts downloaded'), findsOneWidget);
    });
  });

  group('AC5 loading, empty and error states', () {
    testWidgets('loading shows the skeleton', (t) async {
      final rig = ActivityRig();
      await pumpActivity(
        t,
        rig,
        settle: false,
        extra: [
          activityEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('no activity shows the empty state', (t) async {
      final rig = ActivityRig();
      await pumpActivity(t, rig);
      expect(find.text('No activity yet.'), findsOneWidget);
    });

    testWidgets('an error shows the error state with Retry', (t) async {
      final rig = ActivityRig();
      await pumpActivity(
        t,
        rig,
        extra: [
          activityEventsProvider.overrideWith(
            (ref) => Stream.error(StateError('boom')),
          ),
        ],
      );
      final l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
      expect(find.text(l10n.errorUnknownTitle), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      await t.tap(find.text(l10n.retry));
      await t.pump();
    });
  });

  test('filter controller starts at All and selects', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(activityFilterProvider), ActivityFilter.all);
    container.read(activityFilterProvider.notifier).select(ActivityFilter.gaps);
    expect(container.read(activityFilterProvider), ActivityFilter.gaps);
  });
}
