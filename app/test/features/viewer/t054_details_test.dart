// FR-77 (T-054): caption, location and tags in the Info sheet; long-press
// copies the caption. Synthetic ZZFAKE_ data only.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/viewer/post_info_sheet.dart';
import 'package:storize_app/features/viewer/story_info_sheet.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import 'post_rig.dart';
import 'story_rig.dart';

const _caption = 'ZZFAKE_caption line one.\nZZFAKE_caption line two.';

String? _clip;

void _mockClipboard(WidgetTester t) {
  _clip = null;
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        _clip = (call.arguments as Map)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

Future<int> _seed(StoryRig rig, {bool details = true}) async {
  final target = await rig.addTarget('brandx');
  return addPost(
    rig,
    target,
    postType: PostType.photo,
    caption: details ? _caption : null,
    locationName: details ? 'ZZFAKE_place' : null,
    taggedUsernames: details ? const ['zzfake_a', 'zzfake_b'] : const [],
    slides: const [SlideSpec(MediaType.photo)],
  );
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('Info sheet shows caption, date, location, tags, saved on', (
    t,
  ) async {
    final rig = StoryRig();
    final id = await _seed(rig);
    await pumpPostViewer(t, rig, contentId: id);
    await t.tap(find.text('Info'));
    await t.pumpAndSettle();
    final sheet = find.byType(PostInfoSheet);
    expect(
      find.descendant(of: sheet, matching: find.text(_caption)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Copy caption')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('ZZFAKE_place')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('@zzfake_a')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('@zzfake_b')),
      findsOneWidget,
    );
    expect(find.text('Saved on'), findsOneWidget);
    expect(find.text('Posted'), findsOneWidget);
    expect(find.text('Gallery folder'), findsOneWidget);
  });

  testWidgets('Copy caption puts the caption on the clipboard', (t) async {
    _mockClipboard(t);
    final rig = StoryRig();
    final id = await _seed(rig);
    await pumpPostViewer(t, rig, contentId: id);
    await t.tap(find.text('Info'));
    await t.pumpAndSettle();
    await t.tap(find.text('Copy caption'));
    await t.pumpAndSettle();
    expect(_clip, _caption);
    expect(find.text('Caption copied'), findsOneWidget);
  });

  testWidgets('long-press on the caption copies it with a snackbar', (
    t,
  ) async {
    _mockClipboard(t);
    final rig = StoryRig();
    final id = await _seed(rig);
    await pumpPostViewer(t, rig, contentId: id);
    await t.longPress(find.text(_caption));
    await t.pumpAndSettle();
    expect(_clip, _caption);
    expect(find.text('Caption copied'), findsOneWidget);
  });

  testWidgets('without details the sheet has no caption, pin or chips', (
    t,
  ) async {
    final rig = StoryRig();
    final id = await _seed(rig, details: false);
    await pumpPostViewer(t, rig, contentId: id);
    await t.tap(find.text('Info'));
    await t.pumpAndSettle();
    expect(find.text('Copy caption'), findsNothing);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
    expect(find.byType(Chip), findsNothing);
    expect(find.text('Saved on'), findsOneWidget);
  });

  testWidgets('story info sheet shows location and tags', (t) async {
    final at = DateTime.utc(2026, 11, 20, 10);
    final item = ContentWithMedia(
      Content(
        id: 1,
        targetId: 1,
        kind: ContentKind.highlight,
        remoteId: 'ZZFAKE_s',
        postedAt: at,
        slideCount: 1,
        detectedAt: at,
        caption: 'ZZFAKE_hl_caption',
        locationName: 'ZZFAKE_place',
        taggedUsernames: const ['zzfake_a'],
      ),
      const [],
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StoryInfoSheet(item: item, username: 'brandx'),
        ),
      ),
    );
    expect(find.text('ZZFAKE_place'), findsOneWidget);
    expect(find.text('@zzfake_a'), findsOneWidget);
    expect(find.text('ZZFAKE_hl_caption'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('post info sheet golden (${b.name})', (t) async {
      final rig = StoryRig();
      final id = await _seed(rig);
      await pumpPostViewer(t, rig, contentId: id, brightness: b);
      await t.tap(find.text('Info'));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/post_info_${b.name}.png'),
      );
    });
  }
}
