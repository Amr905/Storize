import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/features/library/library_page.dart';
import 'package:storize_app/features/link/link_preview_sheet.dart';
import 'package:storize_app/features/link/link_providers.dart';
import 'package:storize_app/features/targets/targets_page.dart';
import 'package:storize_app/router/routes.dart';

import '../../helpers/app_harness.dart';
import '../library/library_rig.dart';
import '../targets/targets_rig.dart';
import 'link_rig.dart';

void resume(WidgetTester t) =>
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

void main() {
  group('Android share target and cold start', () {
    testWidgets('text shared while the app runs opens the preview', (t) async {
      final rig = LinkRig()
        ..scriptPost()
        ..fake.queueMedia(List<int>.filled(8, 7));
      final shared = StreamController<String>.broadcast();
      addTearDown(shared.close);
      final h = await pumpApp(
        t,
        overrides: [
          ...rig.appOverrides,
          sharedTextProvider.overrideWith((ref) => shared.stream),
        ],
      );
      expect(h.location, '/library');
      shared.add('Look: $postLinkText');
      await t.pumpAndSettle();
      expect(h.location, startsWith(Routes.saveFromLinkPath));
      expect(h.router.state.uri.queryParameters['text'], 'Look: $postLinkText');
      expect(find.byType(LinkPreviewSheet), findsOneWidget);
      expect(find.text('@zed'), findsOneWidget);
      expect(rig.fake.callsTo('fetchPostByShortcode'), hasLength(1));
    });

    testWidgets('a cold start from "Share -> Storize" opens the same screen', (
      t,
    ) async {
      final rig = LinkRig()..scriptStory();
      await pumpApp(
        t,
        overrides: rig.appOverrides,
        initialLocation: Routes.saveFromLinkLocation(text: storyLinkText),
      );
      await t.pumpAndSettle();
      expect(find.byType(LinkPreviewSheet), findsOneWidget);
      expect(rig.fake.callsTo('fetchStories'), hasLength(1));
    });

    testWidgets('a share while the app is locked waits behind the lock', (
      t,
    ) async {
      final rig = LinkRig();
      final locked = gate(appLockedProvider, initial: true);
      final shared = StreamController<String>.broadcast();
      addTearDown(shared.close);
      final h = await pumpApp(
        t,
        bypassLock: false,
        overrides: [
          ...rig.appOverrides,
          ...locked.overrides,
          sharedTextProvider.overrideWith((ref) => shared.stream),
        ],
      );
      shared.add(postLinkText);
      await t.pumpAndSettle();
      expect(h.location, startsWith(Routes.lockPath));
      expect(find.byType(LinkPreviewSheet), findsNothing);
      expect(rig.fake.calls, isEmpty, reason: 'nothing is read while locked');
    });
  });

  group('entry points', () {
    testWidgets('Library app bar has Save from link', (t) async {
      final rig = LibraryRig();
      await pumpLibrary(t, rig);
      await t.tap(find.byIcon(Icons.link_rounded));
      await t.pumpAndSettle();
      final router = GoRouter.of(t.element(find.byType(Scaffold).first));
      expect(router.state.uri.path, Routes.saveFromLinkPath);
      expect(find.byType(LibraryPage), findsNothing);
    });

    testWidgets('the Accounts screen has a Save from link button next to Add', (
      t,
    ) async {
      final rig = TargetsRig();
      await rig.addAccount();
      final router = await pumpTargets(t, rig: rig);
      expect(find.byType(TargetsPage), findsOneWidget);
      await t.tap(find.byIcon(Icons.link_rounded));
      await t.pumpAndSettle();
      expect(router.state.uri.path, Routes.saveFromLinkPath);
    });
  });
}
