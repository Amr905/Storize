import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/add_target_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'preview_rig.dart';

void main() {
  late AppLocalizations l10n;
  late PreviewRig rig;

  setUp(() => rig = PreviewRig());

  Future<void> open(WidgetTester t, {bool settle = true}) async {
    await pumpPreview(t, rig: rig, settle: settle);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
  }

  Finder item(String key) => find.byKey(ValueKey('prv-item-$key'));

  testWidgets('shows a loading state per section until the load ends', (
    t,
  ) async {
    rig
      ..script()
      ..platform.resolveGate = Completer<void>();
    await open(t, settle: false);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('prv-stories-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('prv-posts-loading')), findsOneWidget);
    expect(find.text(l10n.prvCurrentStories), findsOneWidget);
    expect(find.text(l10n.prvRecentPosts), findsOneWidget);

    rig.platform.resolveGate!.complete();
    await settleAsync(t);
    expect(find.byKey(const ValueKey('prv-stories-loading')), findsNothing);
    expect(find.byKey(const ValueKey('prv-posts-loading')), findsNothing);
  });

  testWidgets('shows the header, the stories row and the posts grid', (
    t,
  ) async {
    rig.script(isPrivate: true);
    await open(t);
    expect(find.text('Zed Example'), findsOneWidget);
    expect(find.text('@zed'), findsOneWidget);
    expect(find.text(l10n.prvPrivateBadge), findsOneWidget);
    expect(item('story:s1'), findsOneWidget);
    expect(item('story:s2'), findsOneWidget);
    expect(item('post:p1'), findsOneWidget);
    expect(item('post:p2'), findsOneWidget);
    expect(item('post:p3'), findsOneWidget);
    // The video story, the video post and the carousel have badges.
    expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    // The session was closed once; the policy is the manual-check one.
    expect(rig.closed, 1);
    expect(
      rig.fake.callsTo('fetchPostPage').single.args.last,
      ExtractionPolicy.directThenPage,
    );
  });

  testWidgets('a stories failure shows its message, the posts stay', (
    t,
  ) async {
    final user = previewUser();
    rig.fake
      ..resolveUserResults.add(Ok(user))
      ..fetchStoriesResults.add(const Err(RateLimited(null)))
      ..fetchPostPageResults.add(Ok(PostPage(items: [remote('p1')])));
    await open(t);
    expect(find.text(l10n.errorRateLimitedTitle), findsOneWidget);
    expect(item('post:p1'), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
  });

  testWidgets('a posts failure shows its message, the stories stay', (t) async {
    final user = previewUser();
    rig.fake
      ..resolveUserResults.add(Ok(user))
      ..fetchStoriesResults.add(
        Ok({
          user.remoteUserId: [remote('s1', kind: ContentKind.story)],
        }),
      )
      ..fetchPostPageResults.add(const Err(NetworkFailure()));
    await open(t);
    expect(find.text(l10n.errorNetworkTitle), findsOneWidget);
    expect(item('story:s1'), findsOneWidget);
  });

  testWidgets('an empty account says so, in both sections', (t) async {
    rig.script(stories: const [], posts: const []);
    await open(t);
    expect(find.text(l10n.prvNoStories), findsOneWidget);
    expect(find.text(l10n.prvNoPosts), findsOneWidget);
  });

  testWidgets('a resolve failure shows its message and Retry reloads', (
    t,
  ) async {
    rig.fake.resolveUserResults.add(const Err(TargetNotFound()));
    await open(t);
    expect(find.text(l10n.tgtNotFound('@zed')), findsOneWidget);
    expect(find.text(l10n.prvSaveAll), findsNothing);

    rig.script();
    await t.tap(find.text(l10n.retry));
    await settleAsync(t);
    expect(item('post:p1'), findsOneWidget);
  });

  testWidgets('select items and Save selected puts them in the gallery', (
    t,
  ) async {
    rig
      ..script()
      ..fake.queueMedia(List<int>.filled(8, 1))
      ..fake.queueMedia(List<int>.filled(8, 2));
    await open(t);
    expect(find.text(l10n.prvSaveSelected(0)), findsOneWidget);
    final saveSelected = find.widgetWithText(
      FilledButton,
      l10n.prvSaveSelected(0),
    );
    expect(t.widget<FilledButton>(saveSelected).onPressed, isNull);

    await t.tap(item('post:p1'));
    await t.pump();
    await t.tap(item('story:s2'));
    await t.pump();
    expect(find.text(l10n.prvSaveSelected(2)), findsOneWidget);

    await t.tap(find.text(l10n.prvSaveSelected(2)));
    await settleAsync(t);

    expect(rig.gallery.files, hasLength(2));
    expect(
      rig.gallery.files.every((f) => f.relativePath == 'Pictures/Storize/zed'),
      isTrue,
    );
    expect(find.text(l10n.prvSaveDone(2)), findsOneWidget);
    // Saved items show the check badge and leave the selection.
    expect(find.byKey(const ValueKey('prv-saved-badge')), findsNWidgets(2));
    expect(find.text(l10n.prvSaveSelected(0)), findsOneWidget);
    // Nothing was tracked: the target exists but no check visits it.
    final stored = (await t.runAsync(() => rig.targets.watchAll().first))!;
    expect(stored.single.status, TargetStatus.paused);
  });

  testWidgets('Save all saves every item and disables itself', (
    t,
  ) async {
    rig.script();
    for (var i = 0; i < 7; i++) {
      rig.fake.queueMedia(List<int>.filled(8, i));
    }
    await open(t);
    await t.tap(find.text(l10n.prvSaveAll));
    await settleAsync(t);
    expect(rig.gallery.files, hasLength(7));
    expect(find.text(l10n.prvSaveDone(5)), findsOneWidget);
    expect(find.byKey(const ValueKey('prv-saved-badge')), findsNWidgets(5));
    final saveAll = find.widgetWithText(FilledButton, l10n.prvSaveAll);
    expect(t.widget<FilledButton>(saveAll).onPressed, isNull);
  });

  testWidgets('a failed download is reported, not hidden', (t) async {
    rig
      ..script(stories: const [], posts: [remote('p1')])
      ..fake.queueMediaError(StateError('boom'));
    await open(t);
    await t.tap(find.text(l10n.prvSaveAll));
    await settleAsync(t);
    expect(
      find.text(l10n.prvSaveFailed(l10n.prvReasonGeneric)),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('prv-saved-badge')), findsNothing);
  });

  testWidgets('Track opens the add form with the username filled in', (
    t,
  ) async {
    await rig.addAccount();
    rig.script();
    await open(t);
    await t.tap(find.text(l10n.prvTrack));
    await settleAsync(t);
    expect(find.byType(AddTargetPage), findsOneWidget);
    final field = t.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'zed');
  });

  testWidgets('Track after a save turns the preview-only target on', (
    t,
  ) async {
    rig
      ..script()
      ..fake.queueMedia(List<int>.filled(8, 1));
    await open(t);
    await t.tap(item('story:s2'));
    await t.pump();
    await t.tap(find.text(l10n.prvSaveSelected(1)));
    await settleAsync(t);
    await t.tap(find.text(l10n.prvTrack));
    await settleAsync(t);
    final stored = ((await t.runAsync(() => rig.targets.watchAll().first))!)
        .single;
    expect(stored.status, TargetStatus.active);
    expect(find.byType(AddTargetPage), findsNothing);
  });

  testWidgets('a tracked account shows no Track button', (t) async {
    await rig.addTarget('zed');
    rig.script();
    await open(t);
    expect(find.text(l10n.prvTrack), findsNothing);
    expect(find.text(l10n.prvTracking), findsOneWidget);
  });

  testWidgets('items already in the gallery start with the check badge', (
    t,
  ) async {
    final target = await rig.addTarget('zed');
    rig.script();
    await rig.content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: target.id,
        kind: ContentKind.post,
        remoteId: 'p1',
        postedAt: previewNow,
        detectedAt: previewNow,
        slideCount: 1,
        status: ContentStatus.done,
      ),
      [
        const MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: 0,
          mediaType: MediaType.photo,
          sourceUrl: 'https://cdn.example.test/p1/0',
          status: MediaFileStatus.done,
        ),
      ],
    );
    await open(t);
    expect(find.byKey(const ValueKey('prv-saved-badge')), findsOneWidget);
  });
}
