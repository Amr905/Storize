import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/link/link_preview_sheet.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'link_rig.dart';

void main() {
  late LinkRig rig;
  setUp(() => rig = LinkRig());

  Finder sheet() => find.byType(LinkPreviewSheet);
  Finder fieldText(String t) => find.widgetWithText(TextField, t);

  group('the field and the clipboard prefill', () {
    testWidgets('an Instagram link on the clipboard fills the field only', (
      t,
    ) async {
      rig.clipboard = 'copied: $postLinkText ok';
      await pumpLink(t, rig: rig);
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'copied: $postLinkText ok');
      expect(rig.fake.calls, isEmpty, reason: 'nothing is looked up by itself');
      expect(sheet(), findsNothing);
    });

    testWidgets('other clipboard text and an empty clipboard leave it empty', (
      t,
    ) async {
      rig.clipboard = 'just some words';
      await pumpLink(t, rig: rig);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
      final look = find.widgetWithText(FilledButton, l10nOf(t).lnkLookUp);
      expect(t.widget<FilledButton>(look).onPressed, isNull);
    });
  });

  group('lookup and save', () {
    testWidgets('a story: preview, Save, saved, Open', (t) async {
      rig
        ..scriptStory()
        ..fake.queueMedia(List<int>.filled(8, 7));
      final router = await pumpLink(t, rig: rig);
      await lookUp(t, storyLinkText);
      final l10n = l10nOf(t);
      expect(sheet(), findsOneWidget);
      expect(find.text(l10n.lnkSheetTitle), findsOneWidget);
      expect(find.text('@zed'), findsOneWidget);
      expect(find.text(l10n.lnkKindStory), findsOneWidget);
      expect(rig.gallery.files, isEmpty, reason: 'looking saves nothing');
      expect(rig.closed, 1, reason: 'the in-page session is closed');

      await t.tap(find.text(l10n.lnkSave));
      await settleAsync(t);
      expect(find.text(l10n.prvSaveDone(1)), findsOneWidget);
      expect(rig.gallery.files.single.relativePath, 'Pictures/Storize/zed');
      final target = (await rig.targets.getByRemoteUserId(
        PlatformId.instagram,
        'uid-zed',
      ))!;
      expect(SavePreviewItems.isPreviewOnly(target), isTrue);

      await t.tap(find.text(l10n.lnkOpen));
      await settleAsync(t, rounds: 4);
      expect(router.state.uri.path, startsWith('/story/'));
    });

    testWidgets('a post and a reel use the shortcode query', (t) async {
      rig
        ..scriptPost()
        ..fake.queueMedia(List<int>.filled(8, 7));
      final router = await pumpLink(t, rig: rig);
      await lookUp(t, postLinkText);
      expect(find.text(l10nOf(t).lnkKindPost), findsOneWidget);
      expect(
        rig.fake.callsTo('fetchPostByShortcode').single.args.first,
        'ZZFAKE_c1',
      );
      await t.tap(find.text(l10nOf(t).lnkSave));
      await settleAsync(t);
      await t.tap(find.text(l10nOf(t).lnkOpen));
      await settleAsync(t);
      expect(router.state.uri.path, startsWith('/post/'));

      router.pop();
      await settleAsync(t);
      rig.scriptPost(id: 'p2');
      await t.enterText(
        find.byType(TextField),
        'https://www.instagram.com/reel/ZZFAKE_c2/',
      );
      await t.pump();
      await t.tap(find.text(l10nOf(t).lnkLookUp));
      await settleAsync(t, rounds: 6);
      expect(find.text(l10nOf(t).lnkKindReel), findsOneWidget);
      expect(rig.fake.callsTo('fetchPostByShortcode'), hasLength(2));
    });

    testWidgets('a highlight: Save all N saves every item', (t) async {
      rig
        ..scriptHighlight()
        ..fake.queueMedia(List<int>.filled(8, 1))
        ..fake.queueMedia(List<int>.filled(8, 2))
        ..fake.queueMedia(List<int>.filled(8, 3));
      await pumpLink(t, rig: rig);
      await lookUp(t, highlightLinkText);
      final l10n = l10nOf(t);
      expect(find.text(l10n.lnkKindHighlight(3)), findsOneWidget);
      expect(find.text('Trip'), findsOneWidget);
      await t.tap(find.text(l10n.lnkSaveAll(3)));
      await settleAsync(t, rounds: 14);
      expect(find.text(l10n.prvSaveDone(3)), findsOneWidget);
      expect(rig.gallery.files, hasLength(3));
    });

    testWidgets('a highlight link with story_media_id saves that item', (
      t,
    ) async {
      rig
        ..scriptHighlight()
        ..fake.queueMedia(List<int>.filled(8, 1));
      await pumpLink(t, rig: rig);
      await lookUp(t, '$highlightLinkText?story_media_id=3002_42');
      final l10n = l10nOf(t);
      // Save (the one item) and, below it, Save all 3.
      expect(find.text(l10n.lnkSave), findsOneWidget);
      expect(find.text(l10n.lnkSaveAll(3)), findsOneWidget);
      await t.tap(find.text(l10n.lnkSave));
      await settleAsync(t);
      expect(rig.gallery.files, hasLength(1));
    });

    testWidgets('a saved item is "Already saved" with Open, no Save', (
      t,
    ) async {
      rig
        ..scriptPost()
        ..scriptPost()
        ..fake.queueMedia(List<int>.filled(8, 7));
      final router = await pumpLink(t, rig: rig);
      await lookUp(t, postLinkText);
      await t.tap(find.text(l10nOf(t).lnkSave));
      await settleAsync(t);
      await t.tap(find.text(l10nOf(t).lnkDone));
      await settleAsync(t, rounds: 10);
      expect(sheet(), findsNothing);

      await t.tap(find.text(l10nOf(t).lnkLookUp));
      await settleAsync(t, rounds: 6);
      final l10n = l10nOf(t);
      expect(find.text(l10n.lnkAlreadySaved), findsOneWidget);
      expect(find.text(l10n.lnkSave), findsNothing);
      expect(
        rig.gallery.files,
        hasLength(1),
        reason: 'nothing downloads again',
      );
      await t.tap(find.text(l10n.lnkOpen));
      await settleAsync(t, rounds: 4);
      expect(router.state.uri.path, startsWith('/post/'));
    });

    testWidgets('a download that fails is shown in the sheet', (t) async {
      rig
        ..scriptPost()
        ..fake.queueMediaError(
          const ExpiredMediaUrl(),
        );
      await pumpLink(t, rig: rig);
      await lookUp(t, postLinkText);
      await t.tap(find.text(l10nOf(t).lnkSave));
      await settleAsync(t, rounds: 14);
      expect(find.textContaining("Couldn't save"), findsOneWidget);
      expect(find.text(l10nOf(t).lnkSave), findsOneWidget, reason: 'retry');
    });
  });

  group('messages', () {
    testWidgets('an unsupported link', (t) async {
      await pumpLink(t, rig: rig);
      await lookUp(t, 'https://example.com/nothing');
      final l10n = l10nOf(t);
      expect(find.text(l10n.lnkUnsupported), findsOneWidget);
      expect(find.text(l10n.lnkUnsupportedHint), findsOneWidget);
      expect(rig.fake.calls, isEmpty);
      expect(sheet(), findsNothing);
    });

    testWidgets('an expired story', (t) async {
      rig.scriptStory(pks: ['9999']);
      await pumpLink(t, rig: rig);
      await lookUp(t, storyLinkText);
      expect(find.text(l10nOf(t).lnkStoryGone), findsOneWidget);
      expect(sheet(), findsNothing);
    });

    testWidgets('a removed post', (t) async {
      rig.fake.fetchPostByShortcodeResults.addFailure(const TargetNotFound());
      await pumpLink(t, rig: rig);
      await lookUp(t, postLinkText);
      expect(find.text(l10nOf(t).lnkPostGone), findsOneWidget);
    });

    testWidgets('private, rate limited and session invalid', (t) async {
      await pumpLink(t, rig: rig);
      rig.fake.fetchPostByShortcodeResults.addFailure(const TargetNotVisible());
      await lookUp(t, postLinkText);
      expect(find.text(l10nOf(t).prvNotVisible), findsOneWidget);

      rig.fake.fetchPostByShortcodeResults.addFailure(const RateLimited(null));
      await t.tap(find.text(l10nOf(t).lnkLookUp));
      await settleAsync(t, rounds: 6);
      expect(find.text(l10nOf(t).errorRateLimitedTitle), findsOneWidget);

      rig.fake.fetchPostByShortcodeResults.addFailure(
        const SessionInvalid(SessionReason.loginRequired),
      );
      await t.tap(find.text(l10nOf(t).lnkLookUp));
      await settleAsync(t, rounds: 6);
      expect(find.text(l10nOf(t).tgtSessionInactive), findsOneWidget);
    });
  });

  group('a shared link', () {
    testWidgets('opens the preview at once, no tap', (t) async {
      rig
        ..scriptPost()
        ..fake.queueMedia(List<int>.filled(8, 7));
      await pumpLink(t, rig: rig, initialText: postLinkText);
      await settleAsync(t, rounds: 6);
      expect(sheet(), findsOneWidget);
      expect(fieldText(postLinkText), findsOneWidget);
      expect(rig.fake.callsTo('fetchPostByShortcode'), hasLength(1));
    });

    testWidgets('the link survives the query encoding of the route', (t) async {
      const text = 'https://www.instagram.com/p/ZZFAKE_c1/?igsh=a%20b&x=1#f';
      rig.scriptPost();
      final router = await pumpLink(t, rig: rig, initialText: text);
      expect(router.state.uri.queryParameters['text'], text);
    });

    testWidgets('a shared text that is no link shows the message', (t) async {
      await pumpLink(t, rig: rig, initialText: 'hello there');
      await settleAsync(t, rounds: 4);
      expect(find.text(l10nOf(t).lnkUnsupported), findsOneWidget);
    });
  });
}
