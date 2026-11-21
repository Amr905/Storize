import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../settings/settings_rig.dart';
import 'account_rig.dart';

void main() {
  group('S-13 health states (AC3)', () {
    testWidgets(
      'active: badge, last check, rate-limit count and Log out only',
      (
        t,
      ) async {
        final rig = SettingsRig();
        await rig.addAccount(lastSuccessAt: rigNow);
        await rig.activity.add(
          ActivityEvent(
            id: ActivityEvent.unsavedId,
            at: rigNow.subtract(const Duration(days: 1)),
            type: ActivityType.rateLimited,
            severity: Severity.warn,
          ),
        );
        await pumpAccount(t, rig);
        expect(find.text('@storize_archive'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.textContaining('Connected'), findsOneWidget);
        expect(find.textContaining('Last successful check'), findsOneWidget);
        expect(find.text('Rate-limit events (7 days): 1'), findsOneWidget);
        expect(find.widgetWithText(TonalButton, 'Log out'), findsOneWidget);
        expect(find.text('Log in again'), findsNothing);
      },
    );

    testWidgets('needs re-login: amber message and Log in again goes to S-02', (
      t,
    ) async {
      final rig = SettingsRig();
      await rig.addAccount(status: AccountStatus.needsRelogin);
      await pumpAccount(t, rig);
      expect(find.text('Needs re-login'), findsOneWidget);
      expect(
        find.text(
          'Instagram ended the session or asked for verification. '
          'Checks are paused.',
        ),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(PrimaryButton, 'Log in again'));
      await t.pumpAndSettle();
      expect(find.text('S-02 login'), findsOneWidget);
    });

    testWidgets('restricted: red message and Log in with another account', (
      t,
    ) async {
      final rig = SettingsRig();
      await rig.addAccount(status: AccountStatus.restricted);
      await pumpAccount(t, rig);
      expect(find.text('Restricted'), findsOneWidget);
      expect(
        find.text(
          'Instagram may have restricted this account. Checks are stopped. '
          'Consider logging in with a different dedicated account.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PrimaryButton, 'Log in with another account'),
        findsOneWidget,
      );
    });

    testWidgets('no login: gray Not connected with Log in and no Log out', (
      t,
    ) async {
      final rig = SettingsRig();
      await pumpAccount(t, rig);
      expect(find.text('Not connected'), findsWidgets);
      expect(find.widgetWithText(PrimaryButton, 'Log in'), findsOneWidget);
      expect(find.widgetWithText(TonalButton, 'Log out'), findsNothing);
    });

    testWidgets('a logged-out login is shown as Not connected', (t) async {
      final rig = SettingsRig();
      await rig.addAccount(status: AccountStatus.loggedOut);
      await pumpAccount(t, rig);
      expect(find.widgetWithText(PrimaryButton, 'Log in'), findsOneWidget);
      expect(find.widgetWithText(TonalButton, 'Log out'), findsNothing);
    });
  });

  group('S-13 Log out keeps targets and downloads (AC3)', () {
    testWidgets('cancel keeps the session', (t) async {
      final rig = SettingsRig();
      final account = await rig.addAccount();
      await rig.sessions.save(
        account.id,
        SessionBlob(
          cookies: const {'sessionid': 'x', 'ds_user_id': 'y'},
          userAgent: 'ua',
          capturedAt: rigNow,
        ),
      );
      await pumpAccount(t, rig);
      await t.tap(find.widgetWithText(TonalButton, 'Log out'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Stop all checks and remove the saved session? '
          'Your downloads and targets are kept.',
        ),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(StorizeTextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(rig.sessions.accountIds, {account.id});
      expect(rig.scheduler.cancelAllCalls, 0);
    });

    testWidgets(
      'confirm clears the session, stops checks, and keeps targets and content',
      (t) async {
        final rig = SettingsRig();
        final target = await rig.addTarget('nour_k');
        final account = await rig.addAccount();
        await rig.sessions.save(
          account.id,
          SessionBlob(
            cookies: const {'sessionid': 'x', 'ds_user_id': 'y'},
            userAgent: 'ua',
            capturedAt: rigNow,
          ),
        );
        final storyId = await rig.addStory(
          target: target,
          remoteId: 's1',
          postedAt: rigNow,
          detectedAt: rigNow,
        );
        await pumpAccount(t, rig);
        await t.tap(find.widgetWithText(TonalButton, 'Log out'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(PrimaryButton, 'Log out'));
        await t.pumpAndSettle();

        expect(rig.sessions.accountIds, isEmpty);
        expect(rig.scheduler.cancelAllCalls, 1);
        final stored = await rig.accounts.getActive();
        expect(stored?.status, AccountStatus.loggedOut);
        expect(await rig.targets.getById(target.id), isNotNull);
        expect(await rig.content.getById(storyId), isNotNull);
        expect(find.text('Not connected'), findsWidgets);
      },
    );
  });
}
