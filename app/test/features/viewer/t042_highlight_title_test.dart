import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../library/library_rig.dart' show testNow;
import 'story_rig.dart';

/// T-042 AC3: S-06 shows the title of a highlight item, and nothing extra for a
/// story.
void main() {
  Future<int> addHighlightItem(StoryRig rig, Target target) async {
    const uri = 'content://viewer/highlight-1';
    rig.gallery.files.add(uri);
    final result = await rig.content.insertIfNew(
      Content(
        id: Content.unsavedId,
        targetId: target.id,
        kind: ContentKind.highlight,
        remoteId: 'hl-item-1',
        slideCount: 1,
        postedAt: testNow.subtract(const Duration(days: 3)).toUtc(),
        detectedAt: testNow.toUtc(),
        extras: const {
          HighlightExtras.id: 'h1',
          HighlightExtras.title: 'Trip',
          HighlightExtras.order: 0,
        },
        status: ContentStatus.done,
      ),
      [
        MediaFile(
          id: MediaFile.unsavedId,
          contentId: MediaFile.unsavedContentId,
          slideIndex: 0,
          mediaType: MediaType.photo,
          sourceUrl: 'https://example.invalid/highlight-1',
          status: MediaFileStatus.done,
          contentUri: uri,
          relativePath: 'Pictures/Storize/${target.username}/Highlights/Trip/',
          displayName: 'hl-item-1',
          thumbPath: '/thumbs/hl-1.webp',
          sizeBytes: 512 * 1024,
          downloadedAt: testNow.toUtc(),
        ),
      ],
    );
    return result.contentId;
  }

  testWidgets('AC3: a highlight item shows its highlight title', (t) async {
    final rig = StoryRig();
    final target = await rig.addTarget('nour_k');
    final id = await addHighlightItem(rig, target);

    await pumpStoryViewer(t, rig, contentId: id);
    final l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    expect(find.text(l10n.storyHighlightTitle('Trip')), findsOneWidget);
  });

  testWidgets('AC3: a story shows no highlight title', (t) async {
    final rig = StoryRig();
    final target = await rig.addTarget('nour_k');
    final id = await rig.addStory(
      target,
      postedAt: testNow.subtract(const Duration(hours: 1)),
    );

    await pumpStoryViewer(t, rig, contentId: id);
    final l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    expect(find.text(l10n.storyHighlightTitle('Trip')), findsNothing);
  });
}
