import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/account/account_providers.dart';
import 'package:storize_app/features/settings/app_lock_row.dart';
import 'package:storize_app/features/settings/settings_providers.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../features/account/account_rig.dart';
import '../features/settings/settings_rig.dart';

/// Delegates to a real fake but can fail `setStatus`.
class _FailingStatusRepo implements AccountRepo {
  _FailingStatusRepo(this.inner);
  final AccountRepo inner;

  @override
  Stream<LoginAccount?> watchActive() => inner.watchActive();
  @override
  Future<LoginAccount?> getActive() => inner.getActive();
  @override
  Future<LoginAccount> upsert(LoginAccount account) => inner.upsert(account);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('setStatus failed');
}

class _FailingScheduler implements Scheduler {
  @override
  Future<void> cancelAll() async => throw StateError('cancel failed');
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

ProviderContainer _base(SettingsRig rig) {
  final b = ProviderContainer(overrides: rig.overrides);
  addTearDown(b.dispose);
  return b;
}

SessionBlob _blob() => SessionBlob(
  cookies: const {'sessionid': 'SECRET-SID', 'ds_user_id': 'SECRET-UID'},
  userAgent: 'ua',
  capturedAt: rigNow,
);

Future<void> _openRetention(WidgetTester t) async {
  await t.tap(find.widgetWithText(ListTile, 'Keep downloads'));
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(RadioListTile<bool>, 'After'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), '30');
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
  await t.pumpAndSettle();
}

void main() {
  group('T-033 QA: log out', () {
    test('setStatus failure leaves no active-without-session', () async {
      final rig = SettingsRig();
      final account = await rig.addAccount();
      await rig.sessions.save(account.id, _blob());
      final c = ProviderContainer(
        parent: _base(rig),
        overrides: [
          accountActionsProvider.overrideWith(AccountActions.new),
          accountRepoProvider.overrideWithValue(
            _FailingStatusRepo(rig.accounts),
          ),
        ],
      );
      addTearDown(c.dispose);
      await expectLater(
        c.read(accountActionsProvider).logOut(account),
        throwsStateError,
      );
      final active = (await rig.accounts.getActive())!.status;
      final hasSession = rig.sessions.accountIds.contains(account.id);
      // Consistent means: (active and session kept) or (loggedOut and cleared).
      expect(
        active == AccountStatus.active ? hasSession : !hasSession,
        isTrue,
        reason: 'status=$active sessionPresent=$hasSession',
      );
    });

    test(
      'cancelAll failure must not leave status active with no session',
      () async {
        final rig = SettingsRig();
        final account = await rig.addAccount();
        await rig.sessions.save(account.id, _blob());
        final c = ProviderContainer(
          parent: _base(rig),
          overrides: [
            accountActionsProvider.overrideWith(AccountActions.new),
            schedulerProvider.overrideWithValue(_FailingScheduler()),
          ],
        );
        addTearDown(c.dispose);
        await expectLater(
          c.read(accountActionsProvider).logOut(account),
          throwsStateError,
        );
        final active = (await rig.accounts.getActive())!.status;
        expect(active, AccountStatus.loggedOut);
        expect(rig.sessions.accountIds, isEmpty);
      },
    );

    testWidgets('confirmed log out shows no session values; gallery kept', (
      t,
    ) async {
      final rig = SettingsRig();
      final target = await rig.addTarget('nour_k');
      final account = await rig.addAccount();
      await rig.sessions.save(account.id, _blob());
      await rig.addStory(
        target: target,
        remoteId: 's1',
        postedAt: rigNow,
        detectedAt: rigNow,
      );
      await pumpAccount(t, rig);
      await t.tap(find.widgetWithText(OutlinedButton, 'Log out'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(PrimaryButton, 'Log out'));
      await t.pumpAndSettle();
      expect(find.textContaining('SECRET'), findsNothing);
      expect(rig.gallery.files, isEmpty); // nothing deleted (none saved)
      expect(rig.sessions.accountIds, isEmpty);
    });
  });

  group('T-033 QA: retention', () {
    testWidgets('cancel in the confirmation leaves setting and content', (
      t,
    ) async {
      final rig = SettingsRig();
      final target = await rig.addTarget('a');
      final old = rigNow.subtract(const Duration(days: 90));
      final id = await rig.addStory(
        target: target,
        remoteId: 'old',
        postedAt: old,
        detectedAt: old,
        downloadedAt: old,
      );
      await pumpSettings(t, rig);
      await _openRetention(t);
      await t.tap(find.widgetWithText(StorizeTextButton, 'Cancel').last);
      await t.pumpAndSettle();
      expect((await rig.settingsRepo.get()).retentionDays, isNull);
      expect(await rig.content.getById(id), isNotNull);
    });

    testWidgets('turning retention off deletes nothing', (t) async {
      final rig = SettingsRig(settings: const AppSettings(retentionDays: 30));
      final target = await rig.addTarget('a');
      final old = rigNow.subtract(const Duration(days: 90));
      final id = await rig.addStory(
        target: target,
        remoteId: 'old',
        postedAt: old,
        detectedAt: old,
        downloadedAt: old,
      );
      await pumpSettings(t, rig);
      await t.tap(find.widgetWithText(ListTile, 'Keep downloads'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(RadioListTile<bool>, 'Forever'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await t.pumpAndSettle();
      expect((await rig.settingsRepo.get()).retentionDays, isNull);
      expect(await rig.content.getById(id), isNotNull);
    });

    test('preview count equals what ApplyRetention deletes (edges)', () async {
      final rig = SettingsRig();
      final target = await rig.addTarget('a');
      Future<int> add(String r, Duration age, {Duration? detectedAge}) =>
          rig.addStory(
            target: target,
            remoteId: r,
            postedAt: rigNow.subtract(age),
            detectedAt: rigNow.subtract(detectedAge ?? age),
            downloadedAt: rigNow.subtract(detectedAge ?? age),
            sizeBytes: 100,
          );
      await add('old', const Duration(days: 60));
      await add('exact', const Duration(days: 30)); // exactly N: kept
      await add('just', const Duration(days: 30, milliseconds: 1));
      // Posted long ago, detected yesterday: kept.
      await add(
        'late',
        const Duration(days: 90),
        detectedAge: const Duration(days: 1),
      );
      await add('new', const Duration(days: 1));
      // Future-dated detection (bad clock): delete skips it.
      await add(
        'future',
        const Duration(days: 90),
        detectedAge: const Duration(days: -2),
      );
      final c = ProviderContainer(overrides: rig.overrides);
      addTearDown(c.dispose);
      final preview = await c.read(retentionPreviewProvider(30).future);
      final before = (await rig.content.olderThan(rigNow)).length;
      await c.read(applyRetentionProvider).call();
      // retentionDays must be set for ApplyRetention to act.
      await rig.settingsRepo.update((s) => s.copyWith(retentionDays: 30));
      await c.read(applyRetentionProvider).call();
      final after = (await rig.content.olderThan(rigNow)).length;
      expect(before - after, preview.items);
      expect(preview.bytes, preview.items * 100);
    });
  });

  group('T-033 QA: intervals and lock row', () {
    test('each setter calls scheduler.apply once with new values', () async {
      final rig = SettingsRig();
      final c = ProviderContainer(overrides: rig.overrides);
      addTearDown(c.dispose);
      final a = c.read(settingsActionsProvider);
      await a.setStoryInterval(30);
      expect(rig.scheduler.applyCalls, [
        (storyMin: 30, postMin: 180, wifiOnly: false),
      ]);
      await a.setWifiOnly(on: true);
      expect(rig.scheduler.applyCalls.length, 2);
      expect(lastApply(rig), (storyMin: 30, postMin: 180, wifiOnly: true));
      await a.setPostInterval(60);
      expect(rig.scheduler.applyCalls.length, 3);
      expect(lastApply(rig), (storyMin: 30, postMin: 60, wifiOnly: true));
      // Notification toggles do not touch the schedule.
      await a.setNotifyPosts(on: false);
      expect(rig.scheduler.applyCalls.length, 3);
    });

    test('an out-of-set interval is rejected and does not schedule', () async {
      final rig = SettingsRig();
      final c = ProviderContainer(overrides: rig.overrides);
      addTearDown(c.dispose);
      await expectLater(
        c.read(settingsActionsProvider).setStoryInterval(7),
        throwsA(isA<SettingsValidationException>()),
      );
      expect(rig.scheduler.applyCalls, isEmpty);
    });

    testWidgets('app lock row is mounted with the gallery note', (t) async {
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
  });
}
