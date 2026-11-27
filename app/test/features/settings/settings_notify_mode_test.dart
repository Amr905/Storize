import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/settings/settings_page.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_domain/storize_domain.dart';

import 'settings_rig.dart';

Finder _row(String title) => find.widgetWithText(ListTile, title);

void main() {
  group('FR-78 Notify me', () {
    testWidgets(
      'per item by default: the content toggles show, no summary time',
      (t) async {
        final rig = SettingsRig();
        await pumpSettings(t, rig);
        expect(find.text('Notify me'), findsOneWidget);
        expect(find.text('Per item'), findsOneWidget);
        expect(
          find.widgetWithText(SwitchListTile, 'New stories'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(SwitchListTile, 'New posts'),
          findsOneWidget,
        );
        expect(_row('Summary time'), findsNothing);
      },
    );

    testWidgets(
      'choosing Daily summary stores it, schedules it and shows the time row',
      (t) async {
        final rig = SettingsRig();
        await pumpSettings(t, rig);
        await t.tap(_row('Notify me'));
        await t.pumpAndSettle();
        await t.tap(
          find.widgetWithText(RadioListTile<NotificationMode>, 'Daily summary'),
        );
        await t.pumpAndSettle();

        expect(
          (await rig.settingsRepo.get()).notificationMode,
          NotificationMode.daily,
        );
        expect(rig.scheduler.summary.calls.last.mode, NotificationMode.daily);
        expect(rig.scheduler.summary.calls.last.time, SummaryTime.defaultTime);
        expect(_row('Summary time'), findsOneWidget);
        expect(
          find.widgetWithText(SwitchListTile, 'New stories'),
          findsNothing,
        );
        expect(find.widgetWithText(SwitchListTile, 'New posts'), findsNothing);
      },
    );

    testWidgets('Off hides the content toggles but keeps login problems', (
      t,
    ) async {
      final rig = SettingsRig(
        settings: const AppSettings(notificationMode: NotificationMode.daily),
      );
      await pumpSettings(t, rig);
      await t.tap(_row('Notify me'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(RadioListTile<NotificationMode>, 'Off'));
      await t.pumpAndSettle();

      expect(
        (await rig.settingsRepo.get()).notificationMode,
        NotificationMode.off,
      );
      expect(rig.scheduler.summary.calls.last.mode, NotificationMode.off);
      expect(_row('Summary time'), findsNothing);
      expect(find.widgetWithText(SwitchListTile, 'New stories'), findsNothing);
      expect(
        find.widgetWithText(SwitchListTile, 'Login problems'),
        findsOneWidget,
      );
    });

    testWidgets('a changed summary time re-schedules the run at that time', (
      t,
    ) async {
      final rig = SettingsRig(
        settings: const AppSettings(notificationMode: NotificationMode.daily),
      );
      await pumpSettings(t, rig);
      final container = ProviderScope.containerOf(
        t.element(find.byType(SettingsPage)),
      );
      await container
          .read(settingsActionsProvider)
          .setSummaryTime(const SummaryTime(7, 30));

      expect(
        (await rig.settingsRepo.get()).summaryTime,
        const SummaryTime(7, 30),
      );
      final last = rig.scheduler.summary.calls.last;
      expect(last.time, const SummaryTime(7, 30));
      expect(last.mode, NotificationMode.daily);
    });
  });
}
