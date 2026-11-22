import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'e2e_rig.dart';

/// The T-037 end-to-end flows, written once.
///
/// `test/e2e/e2e_flows_test.dart` runs them under `flutter test` (CI) and
/// `integration_test/e2e_flows_test.dart` runs the same bodies on a device.
/// Both use the real `StorizeApp`, the real use cases and the in-memory fakes.
void registerE2eFlows() {
  group('T-037 end-to-end', () {
    testWidgets('1 first run: S-01, S-02 fake login, S-03 Done, empty Library', (
      t,
    ) async {
      final rig = E2eRig(firstRun: true);
      final app = await rig.launch(t);
      expect(app.location, Routes.welcomePath);

      // S-01: Continue stays off until the risk box is ticked.
      await t.tap(find.byKey(const ValueKey('onb-risk-checkbox')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('onb-continue')));
      await t.pumpAndSettle();
      expect(app.location, Routes.loginPath);
      expect((await rig.settings.get()).riskAcknowledgedAt, isNotNull);

      // S-02: the fake WebView reports a logged-in page.
      rig.platform.verifySessionResults.addOk(
        E2eRig.remoteUser('loginacc', '42'),
      );
      rig.web.cookies = Map.of(E2eRig.cookies);
      rig.loginEvents!.onLoadStop(Uri.parse('https://www.instagram.com/'));
      await t.pump();
      await t.pump();
      expect(find.text('Connected as @loginacc'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(app.location, Routes.setupPath);
      final active = (await rig.accounts.getActive())!;
      expect(active.status, AccountStatus.active);
      expect(rig.sessions.accountIds, {active.id});

      // S-03: Done opens the Library.
      await t.ensureVisible(find.byKey(const ValueKey('onb-done')));
      await t.tap(find.byKey(const ValueKey('onb-done')));
      await t.pumpAndSettle();
      expect(app.location, Routes.libraryPath);
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect((await rig.settings.get()).onboardingDone, isTrue);
    });

    testWidgets('2 add a target: S-07, S-08 with valid input, it is listed', (
      t,
    ) async {
      final rig = E2eRig();
      await rig.addAccount();
      rig.platform
        ..resolveUserResults.addOk(E2eRig.remoteUser('nour_k', 'uid-nour_k'))
        ..latestPostTimeResults.fallback = const Ok<DateTime?>(null);
      final app = await rig.launch(t);
      final l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

      await app.go(Routes.targetsPath);
      expect(find.text(l10n.tgtEmptyTitle), findsOneWidget);
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      expect(app.location, Routes.addTargetPath);

      await t.enterText(find.byType(TextField).at(0), 'nour_k');
      await t.pump();
      await t.tap(find.text(l10n.categoryOwn));
      await t.pumpAndSettle();
      // The add use case reads repo streams with real async.
      await t.runAsync(() async {
        await t.tap(find.widgetWithText(FilledButton, l10n.tgtAddAndVerify));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pump();
      await t.pumpAndSettle();

      expect(app.location, Routes.targetsPath);
      expect(find.text(l10n.tgtAdded('nour_k')), findsOneWidget);
      final stored = await rig.targets.watchAll().first;
      expect(stored.map((e) => e.username), ['nour_k']);
      expect(stored.single.postsWatermarkAt, isNotNull);
      expect(find.textContaining('nour_k'), findsWidgets);
      expect(rig.scheduler.applyCalls, isNotEmpty);
    });

    testWidgets(
      '3 a check stores a story and a post; Library shows both; S-06 and S-15 open',
      (t) async {
        final rig = E2eRig();
        await rig.addAccount();
        final target = await rig.addTarget('nour_k');
        rig.scriptRemoteContent(target);
        final app = await rig.launch(t);
        expect(find.text('No stories yet'), findsOneWidget);

        await t.runAsync(rig.runChecks);
        await t.pumpAndSettle();

        // Downloads went through the fake gallery: 1 story file + 2 slides.
        expect(rig.gallery.files, hasLength(3));
        expect(
          rig.gallery.files.every(
            (f) => f.relativePath == 'Pictures/Storize/nour_k/',
          ),
          isTrue,
        );
        expect(rig.platform.callsTo('openMedia'), hasLength(3));

        // Stories tab.
        final stories = await rig.content.watchLibrary(_filter(ContentKind.story)).first;
        final posts = await rig.content.watchLibrary(_filter(ContentKind.post)).first;
        expect(stories, hasLength(1));
        expect(posts, hasLength(1));
        expect(posts.single.media, hasLength(2));
        expect(find.byKey(ValueKey(stories.single.content.id)), findsOneWidget);

        // Posts tab via the switch.
        await t.tap(find.text('Posts'));
        await t.pumpAndSettle();
        expect(find.byKey(ValueKey(posts.single.content.id)), findsOneWidget);
        expect(find.byKey(ValueKey(stories.single.content.id)), findsNothing);

        // Post tile opens S-15.
        await t.tap(find.byKey(ValueKey(posts.single.content.id)));
        await t.pumpAndSettle();
        expect(app.location, Routes.postLocation(posts.single.content.id));
        expect(find.text('1 / 2'), findsOneWidget);
        await app.go(Routes.libraryPath);

        // Story tile opens S-06.
        await t.tap(find.text('Stories'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(ValueKey(stories.single.content.id)));
        await t.pumpAndSettle();
        expect(app.location, Routes.storyLocation(stories.single.content.id));
      },
    );

    testWidgets('4 delete the story from S-06 and the post from S-15', (
      t,
    ) async {
      final rig = E2eRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      rig.scriptRemoteContent(target);
      final app = await rig.launch(t);
      await t.runAsync(rig.runChecks);
      await t.pumpAndSettle();
      final story = (await rig.content.watchLibrary(_filter(ContentKind.story)).first).single;
      final post = (await rig.content.watchLibrary(_filter(ContentKind.post)).first).single;
      expect(rig.gallery.files, hasLength(3));
      Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(text),
      );

      // Story, S-06.
      await app.push(Routes.storyLocation(story.content.id));
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(inDialog('Delete 1 item?'), findsOneWidget);
      expect(
        inDialog(
          "They'll also be removed from your gallery. This can't be undone.",
        ),
        findsOneWidget,
      );
      await t.tap(inDialog('Delete'));
      await t.pumpAndSettle();
      expect(await rig.content.getById(story.content.id), isNull);
      expect(rig.gallery.files, hasLength(2));

      // Post, S-15.
      await app.go(Routes.libraryPath);
      await app.push(Routes.postLocation(post.content.id));
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(inDialog('Delete this post (2 files)?'), findsOneWidget);
      expect(
        inDialog("Also removes them from your gallery. This can't be undone."),
        findsOneWidget,
      );
      await t.tap(inDialog('Delete'));
      await t.pumpAndSettle();
      expect(await rig.content.getById(post.content.id), isNull);
      expect(rig.gallery.files, isEmpty);

      // The Library shows neither.
      await app.go(Routes.libraryPath);
      expect(find.byKey(ValueKey(story.content.id)), findsNothing);
      await t.tap(find.text('Posts'));
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey(post.content.id)), findsNothing);
      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('5 log out keeps targets and downloads and stops checks', (
      t,
    ) async {
      final rig = E2eRig();
      final account = await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      rig.scriptRemoteContent(target);
      final app = await rig.launch(t);
      await t.runAsync(rig.runChecks);
      await t.pumpAndSettle();
      final story = (await rig.content.watchLibrary(_filter(ContentKind.story)).first).single;

      await app.push(Routes.accountPath);
      await t.tap(find.widgetWithText(OutlinedButton, 'Log out').evaluate().isNotEmpty
          ? find.widgetWithText(OutlinedButton, 'Log out')
          : find.text('Log out').first);
      await t.pumpAndSettle();
      await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Log out')));
      await t.pumpAndSettle();

      expect(rig.sessions.accountIds, isEmpty);
      expect(rig.scheduler.cancelAllCalls, 1);
      expect((await rig.accounts.getActive())?.status, AccountStatus.loggedOut);
      expect(account.id, isNonZero);
      expect(await rig.targets.getById(target.id), isNotNull);
      expect(await rig.content.getById(story.content.id), isNotNull);
      expect(rig.gallery.files, hasLength(3));
      expect(find.text('Not connected'), findsWidgets);
    });
  });
}

ContentFilter _filter(ContentKind kind) => ContentFilter(kind: kind);
