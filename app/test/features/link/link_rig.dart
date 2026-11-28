import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/link/link_providers.dart';
import 'package:storize_app/features/link/save_from_link_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../preview/preview_rig.dart';

export '../preview/preview_rig.dart'
    show PreviewRig, previewNow, previewUser, remote, settleAsync;

const String storyLinkText =
    'https://www.instagram.com/stories/zed/3001/?igsh=ZZFAKE';
const String postLinkText = 'https://www.instagram.com/p/ZZFAKE_c1/';
const String highlightLinkText =
    'https://www.instagram.com/stories/highlights/1700001/';

/// A story item with pk [id].
RemoteContent storyItem(String id) => remote(id, kind: ContentKind.story);

/// A highlight item with pk [id].
RemoteContent highlightItem(String id) => RemoteContent(
  remoteId: id,
  kind: ContentKind.highlight,
  postedAt: previewNow,
  extras: const {HighlightExtras.title: 'Trip', HighlightExtras.id: '1700001'},
  slides: [
    RemoteMedia(
      index: 0,
      type: MediaType.photo,
      url: 'https://cdn.example.test/$id/0',
      width: 10,
      height: 10,
    ),
  ],
);

/// The link use case over the preview rig's fakes.
class LinkRig extends PreviewRig {
  LinkRig() {
    saveFromLink = SaveFromLink(
      platform: platform,
      source: fake,
      targets: targets,
      content: content,
      save: savePreview,
      log: log,
      onFinished: () async => closed++,
      stepTimeout: const Duration(seconds: 5),
    );
  }

  late final SaveFromLink saveFromLink;

  /// What the clipboard holds.
  String? clipboard;

  /// Scripts a story link: the user and these story pks.
  void scriptStory({List<String> pks = const ['3001']}) {
    final user = previewUser();
    fake.resolveUserResults.add(Ok(user));
    fake.fetchStoriesResults.add(
      Ok({
        user.remoteUserId: [for (final id in pks) storyItem(id)],
      }),
    );
  }

  void scriptPost({String id = 'p1'}) => fake.fetchPostByShortcodeResults.add(
    Ok(LinkedItems(user: previewUser(), items: [remote(id)])),
  );

  void scriptHighlight() => fake.fetchHighlightWithOwnerResults.add(
    Ok(
      LinkedItems(
        user: previewUser(),
        items: [
          highlightItem('3001'),
          highlightItem('3002'),
          highlightItem('3003'),
        ],
      ),
    ),
  );

  /// The overrides for a test that pumps the whole app (`pumpApp`), which
  /// wires the account repo itself.
  List<Override> get appOverrides => [
    for (final o in overrides)
      if (o.origin != accountRepoProvider) o,
  ];

  @override
  List<Override> get overrides => [
    ...super.overrides,
    saveFromLinkProvider.overrideWithValue(saveFromLink),
    clipboardTextReaderProvider.overrideWithValue(() async => clipboard),
  ];
}

/// Pumps Save from link above a stub home, with story and post stubs to show
/// where Open goes. [initialText] opens the screen with a shared link.
Future<GoRouter> pumpLink(
  WidgetTester tester, {
  required LinkRig rig,
  String? initialText,
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 900),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.saveFromLinkLocation(text: initialText),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home stub')),
      ),
      GoRoute(
        path: Routes.saveFromLinkPath,
        builder: (_, state) =>
            SaveFromLinkPage(initialText: state.uri.queryParameters['text']),
      ),
      GoRoute(
        path: '/story/:id',
        builder: (_, s) =>
            Scaffold(body: Text('story ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (_, s) =>
            Scaffold(body: Text('post ${s.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: rig.overrides,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: brightness == Brightness.light
            ? StorizeTheme.light()
            : StorizeTheme.dark(),
      ),
    ),
  );
  await settleAsync(tester, rounds: 4);
  return router;
}

AppLocalizations l10nOf(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(Scaffold).first));

Future<void> lookUp(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField), text);
  await t.pump();
  await t.tap(find.text(l10nOf(t).lnkLookUp));
  await settleAsync(t, rounds: 6);
}
