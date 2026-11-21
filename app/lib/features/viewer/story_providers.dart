import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/viewer/story_video_player.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// The stories of one target, newest first, and where the opened one sits.
@immutable
class StoryViewerSet {
  /// Creates a set. [items] is copied.
  StoryViewerSet({
    required List<ContentWithMedia> items,
    required this.username,
    required this.initialIndex,
  }) : items = List.unmodifiable(items);

  /// Nothing to show (the item is gone or is not a story).
  static final StoryViewerSet empty = StoryViewerSet(
    items: const [],
    username: '',
    initialIndex: 0,
  );

  /// The stories of the same account.
  final List<ContentWithMedia> items;

  /// The account handle without "@".
  final String username;

  /// The index of the opened story in [items].
  final int initialIndex;
}

/// Loads the stories of the account that owns the content (S-06 swipes
/// between them).
final FutureProviderFamily<StoryViewerSet, int> storyViewerSetProvider =
    FutureProvider.family<StoryViewerSet, int>((
      ref,
      contentId,
    ) async {
      final repo = ref.watch(contentRepoProvider);
      final opened = await repo.getById(contentId);
      if (opened == null || opened.content.kind != ContentKind.story) {
        return StoryViewerSet.empty;
      }
      final targetId = opened.content.targetId;
      final all = await repo.listByTarget(targetId);
      final stories = [
        for (final c in all)
          if (c.content.kind == ContentKind.story) c,
      ];
      final target = await ref.watch(targetRepoProvider).getById(targetId);
      final index = stories.indexWhere((c) => c.content.id == contentId);
      return StoryViewerSet(
        items: stories,
        username: target?.username ?? '',
        initialIndex: index < 0 ? 0 : index,
      );
    });

/// Whether the gallery file at a `contentUri` still exists (EC-20).
final FutureProviderFamily<bool, String> storyFileExistsProvider =
    FutureProvider.family<bool, String>(
      (ref, contentUri) => ref.watch(galleryStoreProvider).exists(contentUri),
    );

/// Writes to the content repo and runs the delete, for the S-06 page.
final storyViewerActionsProvider = Provider<StoryViewerActions>(
  StoryViewerActions.new,
);

/// The S-06 actions that do I/O. Widgets call these; they call the providers.
class StoryViewerActions {
  /// Creates the actions over [_ref].
  const StoryViewerActions(this._ref);

  final Ref _ref;

  /// Marks the content with [contentId] as viewed (FR-34).
  Future<void> markViewed(int contentId) =>
      _ref.read(contentRepoProvider).markViewed([contentId]);

  /// Deletes the gallery file and the row of [contentId] (BR-9). Returns
  /// true when the row is gone.
  Future<bool> delete(int contentId) async {
    final result = await _ref.read(deleteContentProvider)([contentId]);
    return result.deletedContentIds.contains(contentId);
  }
}

/// Builds the photo of a slide. Replace it in tests.
///
/// The default shows the cached preview; `FullPhoto` shows the full-size
/// photo over it once it is read.
typedef StoryPhotoBuilder = Widget Function(
  BuildContext context,
  MediaFile media,
);

/// The default photo builder: the cached preview file.
final storyPhotoBuilderProvider = Provider<StoryPhotoBuilder>(
  (ref) => (context, media) {
    final path = media.thumbPath;
    if (path == null) return const SizedBox.expand();
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  },
);

/// Reads the bytes of a gallery photo for the full-size view (null when it
/// cannot be read or is too big). Never throws for expected failures.
typedef FullPhotoReader = Future<Uint8List?> Function(String contentUri);

/// The full-size photo reader. The default reads nothing, so the viewers keep
/// showing the thumbnail; production wires `StorizePlatformAndroid.readBytes`.
final fullPhotoReaderProvider = Provider<FullPhotoReader>(
  (ref) =>
      (contentUri) async => null,
);

/// The bytes of the full-size photo at a `contentUri`, or null. A read error
/// is treated as null (the thumbnail stays on screen). Freed when the slide
/// leaves the screen.
final FutureProviderFamily<Uint8List?, String> fullPhotoBytesProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((
      ref,
      contentUri,
    ) async {
      try {
        return await ref.watch(fullPhotoReaderProvider)(contentUri);
      } on Object {
        return null;
      }
    });

/// Makes the video player for a gallery URI. Replace it in tests.
final storyVideoPlayerFactoryProvider = Provider<StoryVideoPlayerFactory>(
  (ref) => VideoPlayerStoryPlayer.new,
);
