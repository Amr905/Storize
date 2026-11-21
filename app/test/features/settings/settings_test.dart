import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/settings/app_lock_row.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_app/router/deep_link.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_data/update/update.dart';
import 'package:storize_domain/storize_domain.dart';

import 'settings_rig.dart';

const _postOneHourHint = 'More requests increase the ban risk.';

Finder _sheetOption(String label) => find.descendant(
  of: find.byType(RadioListTile<int>),
  matching: find.text(label),
);

void main() {
  group('S-12 check intervals (AC1)', () {
    testWidgets('story picker offers the six story intervals and saves one', (
      t,
    ) async {
      final rig = SettingsRig();
      await pumpSettings(t, rig);
      await t.tap(find.widgetWithText(ListTile, 'Check stories every'));
      await t.pumpAndSettle();

      final values = t
          .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
          .map((w) => w.value)
          .toList();
      expect(values, [15, 30, 60, 120, 180, 360]);

      await t.tap(_sheetOption('2 h'));
      await t.pumpAndSettle();
      expect((await rig.settingsRepo.get()).storyIntervalMin, 120);
      expect(lastApply(rig), (storyMin: 120, postMin: 180, wifiOnly: false));
    });

    testWidgets(
      'post picker offers 1 h to 24 h; choosing 1 h saves and shows the hint',
      (t) async {
        final rig = SettingsRig();
        await pumpSettings(t, rig);
        await t.tap(find.widgetWithText(ListTile, 'Check posts every'));
        await t.pumpAndSettle();

        final values = t
            .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
            .map((w) => w.value)
            .toList();
        expect(values, [60, 120, 180, 360, 720, 1440]);
        // The hint is on the 1 h option in the sheet; the row has none yet.
        expect(find.text(_postOneHourHint), findsOneWidget);

        await t.tap(_sheetOption('1 h'));
        await t.pumpAndSettle();
        expect((await rig.settingsRepo.get()).postIntervalMin, 60);
        expect(lastApply(rig)!.postMin, 60);
        // Now the row itself carries the hint.
        expect(find.text(_postOneHourHint), findsOneWidget);
      },
    );
  });

  group('S-12 toggles and info rows (AC2)', () {
    testWidgets('Wi-Fi only toggles the setting and re-applies the schedule', (
      t,
    ) async {
      final rig = SettingsRig();
      await pumpSettings(t, rig);
      await t.tap(find.widgetWithText(SwitchListTile, 'Wi-Fi only'));
      await t.pumpAndSettle();
      expect((await rig.settingsRepo.get()).wifiOnly, isTrue);
      expect(lastApply(rig)!.wifiOnly, isTrue);
    });

    testWidgets(
      'New stories, New posts and Login problems toggle their flags',
      (
        t,
      ) async {
        final rig = SettingsRig();
        await pumpSettings(t, rig);
        await t.tap(find.widgetWithText(SwitchListTile, 'New posts'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(SwitchListTile, 'New stories'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(SwitchListTile, 'Login problems'));
        await t.pumpAndSettle();
        final s = await rig.settingsRepo.get();
        expect(s.notifyPosts, isFalse);
        expect(s.notifyStories, isFalse);
        expect(s.notifyLogin, isFalse);
      },
    );

    testWidgets(
      'turning Login problems off warns that checks may stop unnoticed',
      (t) async {
        final rig = SettingsRig();
        await pumpSettings(t, rig);
        expect(find.text('You may not notice when checks stop.'), findsNothing);
        await t.tap(find.widgetWithText(SwitchListTile, 'Login problems'));
        await t.pumpAndSettle();
        expect(
          find.text('You may not notice when checks stop.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('storage info row shows the fixed location', (t) async {
      final rig = SettingsRig();
      await pumpSettings(t, rig);
      expect(find.text('Saved to Pictures/Storize'), findsOneWidget);
    });

    testWidgets('app lock row is mounted with its gallery note', (t) async {
      final rig = SettingsRig();
      await pumpSettings(t, rig);
      expect(find.byType(AppLockRow), findsOneWidget);
      expect(
        find.text(
          'Files saved to your gallery are not protected by the app lock.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('usage row shows used and free space from the storage report', (
      t,
    ) async {
      final rig = SettingsRig();
      final nour = await rig.addTarget('nour_k');
      final client = await rig.addTarget('client_co');
      await rig.addStory(
        target: nour,
        remoteId: 's1',
        postedAt: rigNow.subtract(const Duration(days: 1)),
        detectedAt: rigNow.subtract(const Duration(days: 1)),
        downloadedAt: rigNow,
        sizeBytes: 3 * 1024 * 1024 * 1024,
      );
      await rig.addStory(
        target: client,
        remoteId: 's2',
        postedAt: rigNow.subtract(const Duration(days: 1)),
        detectedAt: rigNow.subtract(const Duration(days: 1)),
        downloadedAt: rigNow,
        sizeBytes: 512 * 1024 * 1024,
      );
      await pumpSettings(t, rig);
      expect(find.text('Used 3.5 GB · free 10.0 GB'), findsOneWidget);
    });

    testWidgets('usage row shows Calculating while figures load', (t) async {
      final rig = SettingsRig();
      await pumpSettings(
        t,
        rig,
        extra: [
          settingsStorageProvider.overrideWith(
            (ref) => Completer<StorageReport>().future,
          ),
        ],
      );
      expect(find.text('Calculating…'), findsOneWidget);
    });

    testWidgets('usage row shows Storage unknown when the figures fail', (
      t,
    ) async {
      final rig = SettingsRig();
      await pumpSettings(
        t,
        rig,
        extra: [
          settingsStorageProvider.overrideWith(
            (ref) => Future<StorageReport>.error(StateError('no storage')),
          ),
        ],
      );
      expect(find.text('Storage unknown'), findsOneWidget);
    });

    testWidgets('usage row opens the per-account list, largest first', (
      t,
    ) async {
      final rig = SettingsRig();
      final nour = await rig.addTarget('nour_k');
      final client = await rig.addTarget('client_co');
      await rig.addStory(
        target: client,
        remoteId: 's2',
        postedAt: rigNow.subtract(const Duration(days: 1)),
        detectedAt: rigNow.subtract(const Duration(days: 1)),
        downloadedAt: rigNow,
        sizeBytes: 512 * 1024 * 1024,
      );
      await rig.addStory(
        target: nour,
        remoteId: 's1',
        postedAt: rigNow.subtract(const Duration(days: 1)),
        detectedAt: rigNow.subtract(const Duration(days: 1)),
        downloadedAt: rigNow,
        sizeBytes: 3 * 1024 * 1024 * 1024,
      );
      await pumpSettings(t, rig);
      await t.tap(find.textContaining('Used 3.5 GB'));
      await t.pumpAndSettle();
      expect(find.text('Storage by account'), findsOneWidget);
      final nourY = t.getCenter(find.text('@nour_k')).dy;
      final clientY = t.getCenter(find.text('@client_co')).dy;
      expect(nourY, lessThan(clientY));
      expect(find.text('3.0 GB'), findsOneWidget);
      expect(find.text('512.0 MB'), findsOneWidget);
    });

    testWidgets('section=storage scrolls the storage section into view', (
      t,
    ) async {
      final rig = SettingsRig();
      await pumpSettings(t, rig, section: SettingsSection.storage);
      await t.pumpAndSettle();
      expect(find.text('Saved to Pictures/Storize'), findsOneWidget);
    });
  });

  group('S-12 Keep downloads and confirmation (AC2)', () {
    testWidgets('After N accepts only whole numbers from 1 to 3650', (t) async {
      final rig = SettingsRig();
      await pumpSettings(t, rig);
      await t.tap(find.widgetWithText(ListTile, 'Keep downloads'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(RadioListTile<bool>, 'After'));
      await t.pumpAndSettle();

      final field = find.byType(TextField);
      await t.enterText(field, '0');
      await t.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 3650.'), findsOneWidget);
      await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await t.pumpAndSettle();
      expect(find.text('Delete now'), findsNothing);
      expect((await rig.settingsRepo.get()).retentionDays, isNull);

      await t.enterText(field, '3651');
      await t.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 3650.'), findsOneWidget);

      await t.enterText(field, '30');
      await t.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 3650.'), findsNothing);
    });

    testWidgets(
      'saving After 30 days confirms the preview and deletes older items',
      (t) async {
        final rig = SettingsRig();
        final target = await rig.addTarget('nour_k');
        final oldId = await rig.addStory(
          target: target,
          remoteId: 'old',
          postedAt: rigNow.subtract(const Duration(days: 40)),
          detectedAt: rigNow.subtract(const Duration(days: 40)),
          downloadedAt: rigNow.subtract(const Duration(days: 40)),
          sizeBytes: 2 * 1024 * 1024,
        );
        final newId = await rig.addStory(
          target: target,
          remoteId: 'new',
          postedAt: rigNow.subtract(const Duration(days: 2)),
          detectedAt: rigNow.subtract(const Duration(days: 2)),
          downloadedAt: rigNow.subtract(const Duration(days: 2)),
          sizeBytes: 1024 * 1024,
        );
        await pumpSettings(t, rig);
        await t.tap(find.widgetWithText(ListTile, 'Keep downloads'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(RadioListTile<bool>, 'After'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), '30');
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
        await t.pumpAndSettle();

        expect(
          find.text(
            'Items older than 30 days (1 item, 2.0 MB) will be deleted now.',
          ),
          findsOneWidget,
        );
        await t.tap(find.widgetWithText(PrimaryButton, 'Delete now'));
        await t.pumpAndSettle();

        expect((await rig.settingsRepo.get()).retentionDays, 30);
        expect(await rig.content.getById(oldId), isNull);
        expect(await rig.content.getById(newId), isNotNull);
      },
    );

    testWidgets(
      'choosing Forever clears the retention without a confirmation',
      (
        t,
      ) async {
        final rig = SettingsRig(
          settings: const AppSettings(retentionDays: 30),
        );
        await pumpSettings(t, rig);
        expect(find.text('After 30 days'), findsOneWidget);
        await t.tap(find.widgetWithText(ListTile, 'Keep downloads'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(RadioListTile<bool>, 'Forever'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
        await t.pumpAndSettle();
        expect(find.text('Delete now'), findsNothing);
        expect((await rig.settingsRepo.get()).retentionDays, isNull);
      },
    );
  });

  group('S-12 Instagram account and about (AC4)', () {
    testWidgets('the account row shows the handle and opens S-13', (t) async {
      final rig = SettingsRig();
      await rig.addAccount();
      await pumpSettings(t, rig);
      expect(find.text('@storize_archive'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      await t.tap(find.widgetWithText(ListTile, '@storize_archive'));
      await t.pumpAndSettle();
      expect(find.text('S-13 account'), findsOneWidget);
    });

    testWidgets('the update row shows when a newer release exists', (t) async {
      final rig = SettingsRig(
        updateState: UpdateAvailable(
          version: '0.2.0',
          url: Uri.parse(
            'https://github.com/Amr905/Storize/releases/tag/v0.2.0',
          ),
        ),
      );
      await pumpSettings(t, rig);
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('v0.2.0'), findsOneWidget);
    });

    testWidgets('the update row is hidden when no update is offered', (
      t,
    ) async {
      final rig = SettingsRig();
      await pumpSettings(t, rig);
      expect(find.text('Update available'), findsNothing);
      expect(find.text('Version 0.1.0'), findsOneWidget);
    });
  });
}
