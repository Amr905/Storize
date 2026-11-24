import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

import 'targets_rig.dart';

void main() {
  late AppLocalizations l10n;

  Future<void> openForm(WidgetTester t, TargetsRig rig) async {
    await pumpTargets(t, rig: rig, initial: '/targets/add');
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
  }

  Finder usernameField() => find.byType(TextField).at(0);
  Finder noteField() => find.byType(TextField).at(1);
  Finder submitButton() =>
      find.widgetWithText(FilledButton, l10n.tgtAddAndVerify);

  /// Taps submit and lets the add use case finish. The use case reads the
  /// repo streams with real async, so the tap runs in `runAsync`.
  Future<void> submit(WidgetTester t) async {
    await t.ensureVisible(submitButton());
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await t.tap(submitButton());
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await t.pump();
    await t.pumpAndSettle();
  }

  Future<void> pickOwn(WidgetTester t) async {
    await t.ensureVisible(find.text(l10n.tgtCatOwnTitle));
    await t.tap(find.text(l10n.tgtCatOwnTitle));
    await t.pumpAndSettle();
  }

  Future<void> addOkUser(
    TargetsRig rig, {
    String username = 'nour_k',
    String remoteUserId = 'uid-1',
    bool isPrivate = false,
    bool followedByViewer = false,
  }) async {
    rig.platform.resolveUserResults.addOk(
      RemoteUser(
        remoteUserId: remoteUserId,
        username: username,
        followedByViewer: followedByViewer,
        blockedByViewer: false,
        isPrivate: isPrivate,
      ),
    );
    rig.platform.latestPostTimeResults.fallback = const Ok<DateTime?>(null);
  }

  testWidgets('AC3: invalid username shows an inline error as you type', (
    t,
  ) async {
    final rig = TargetsRig();
    await openForm(t, rig);

    await t.enterText(usernameField(), 'a..b');
    await t.pump();
    expect(find.text(l10n.tgtUsernameInvalid), findsOneWidget);

    await t.enterText(usernameField(), 'nour_k');
    await t.pump();
    expect(find.text(l10n.tgtUsernameInvalid), findsNothing);
  });

  testWidgets('AC3: submit with nothing chosen shows required errors', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await openForm(t, rig);

    await submit(t);
    expect(find.text(l10n.tgtUsernameInvalid), findsOneWidget);
    expect(find.text(l10n.tgtCategoryRequired), findsOneWidget);
    expect(rig.platform.callsTo('resolveUser'), isEmpty);
  });

  testWidgets('AC3: choosing a category clears the category error', (t) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await openForm(t, rig);

    await submit(t);
    expect(find.text(l10n.tgtCategoryRequired), findsOneWidget);

    await pickOwn(t);
    expect(find.text(l10n.tgtCategoryRequired), findsNothing);
  });

  testWidgets('AC3: the last track chip cannot be turned off (F-1)', (t) async {
    final rig = TargetsRig();
    await openForm(t, rig);

    await t.tap(find.widgetWithText(FilterChip, l10n.tgtTrackStories));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilterChip, l10n.tgtTrackPosts));
    await t.pumpAndSettle();
    expect(find.text(l10n.tgtTrackRequired), findsNothing);

    await t.tap(find.widgetWithText(FilterChip, l10n.tgtTrackReels));
    await t.pumpAndSettle();
    expect(find.text(l10n.tgtTrackRequired), findsOneWidget);
    expect(
      t
          .widget<FilterChip>(
            find.widgetWithText(FilterChip, l10n.tgtTrackReels),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('AC3: the backfill hint is always shown', (t) async {
    final rig = TargetsRig();
    await openForm(t, rig);
    expect(find.text(l10n.tgtTrackHint), findsOneWidget);
  });

  testWidgets('AC3: the note stops at 200 characters', (t) async {
    final rig = TargetsRig();
    await openForm(t, rig);

    await t.enterText(noteField(), 'x' * 250);
    await t.pump();
    expect(find.text('200/200'), findsOneWidget);
  });

  testWidgets('AC5: the over-50 warning shows at the recommended limit', (
    t,
  ) async {
    final rig = TargetsRig();
    for (var i = 0; i < 50; i++) {
      await rig.addTarget('user_$i');
    }
    await openForm(t, rig);
    expect(find.text(l10n.tgtOverLimit(50)), findsOneWidget);
    expect(submitButton(), findsOneWidget);
  });

  testWidgets('no over-50 warning below the limit', (t) async {
    final rig = TargetsRig();
    await rig.addTarget('user_1');
    await openForm(t, rig);
    expect(find.text(l10n.tgtOverLimit(50)), findsNothing);
  });

  testWidgets('AC4: without a session the button is disabled with a message', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount(status: AccountStatus.needsRelogin);
    await openForm(t, rig);
    expect(find.text(l10n.tgtSessionInactive), findsOneWidget);
    final button = t.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'AC4: a valid add stores the target, schedules a check and pops',
    (t) async {
      final rig = TargetsRig();
      await rig.addAccount();
      await addOkUser(rig);
      await openForm(t, rig);

      await t.enterText(usernameField(), '@Nour_K');
      await pickOwn(t);
      await submit(t);

      final stored = (await t.runAsync(() => rig.targets.watchAll().first))!;
      expect(stored.map((e) => e.username), ['nour_k']);
      expect(rig.scheduler.checkNowCalls, hasLength(1));
      expect(find.text(l10n.tgtAdded('nour_k')), findsOneWidget);
    },
  );

  testWidgets('AC4: a profile link is normalized before the call', (t) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await addOkUser(rig);
    await openForm(t, rig);

    await t.enterText(
      usernameField(),
      'https://www.instagram.com/nour_k/?hl=en',
    );
    await pickOwn(t);
    await submit(t);

    final calls = rig.platform.callsTo('resolveUser');
    expect(calls.single.args.first, 'nour_k');
  });

  testWidgets('AC4: a missing account shows the inline not-found error', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount();
    rig.platform.resolveUserResults.addFailure(const TargetNotFound());
    await openForm(t, rig);

    await t.enterText(usernameField(), 'nour_k');
    await pickOwn(t);
    await submit(t);
    expect(find.text(l10n.tgtNotFound('@nour_k')), findsOneWidget);
  });

  testWidgets('AC4: a private account not followed shows the BR-2 message', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await addOkUser(rig, isPrivate: true);
    await openForm(t, rig);

    await t.enterText(usernameField(), 'nour_k');
    await pickOwn(t);
    await submit(t);
    expect(
      find.text(l10n.tgtNotVisiblePrivate('@nour_k', '@loginacc')),
      findsOneWidget,
    );
    expect(rig.scheduler.checkNowCalls, isEmpty);
  });

  testWidgets('AC4: a duplicate shows Already tracked with Open', (t) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await rig.addTarget('nour_k', remoteUserId: 'uid-1');
    await addOkUser(rig);
    await openForm(t, rig);

    await t.enterText(usernameField(), 'nour_k');
    await pickOwn(t);
    await submit(t);
    expect(find.text(l10n.tgtDuplicate('@nour_k')), findsOneWidget);
    expect(find.widgetWithText(TextButton, l10n.tgtOpen), findsOneWidget);
  });

  testWidgets('AC4: a network failure shows a snackbar with Retry', (t) async {
    final rig = TargetsRig();
    await rig.addAccount();
    rig.platform.resolveUserResults.addFailure(const NetworkFailure());
    await openForm(t, rig);

    await t.enterText(usernameField(), 'nour_k');
    await pickOwn(t);
    await submit(t);
    expect(find.text(l10n.errorNetworkTitle), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, l10n.retry), findsOneWidget);
  });

  testWidgets('AC4: a rate limit shows the minutes inline, form editable', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount();
    rig.platform.resolveUserResults.addFailure(
      const RateLimited(Duration(minutes: 7, seconds: 10)),
    );
    await openForm(t, rig);

    await t.enterText(usernameField(), 'nour_k');
    await pickOwn(t);
    await submit(t);
    expect(find.text(l10n.tgtErrRateLimited(8)), findsOneWidget);
    // Not verifying any more: the field accepts input again.
    await t.enterText(usernameField(), 'other_user');
    expect(find.text('other_user'), findsOneWidget);
  });

  testWidgets('AC4: while verifying the button spins and the fields lock', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await pumpTargets(
      t,
      rig: rig,
      initial: '/targets/add',
      settle: false,
      extra: [
        addTargetFormProvider.overrideWith(
          () => FixedAddForm(
            const AddTargetForm(username: 'nour_k', verifying: true),
          ),
        ),
      ],
    );
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
    expect(find.text(l10n.tgtVerifying), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.widget<TextField>(usernameField()).enabled, isFalse);
    expect(t.widget<TextField>(noteField()).enabled, isFalse);
  });
}
