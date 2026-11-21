import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// One saved post and the account handle it belongs to (S-15).
@immutable
class PostViewerData {
  /// Creates the data.
  const PostViewerData({required this.item, required this.username});

  /// The post with its slides.
  final ContentWithMedia item;

  /// The account handle without "@".
  final String username;
}

/// Loads the post opened on S-15. Resolves to null when the row is gone or
/// is not a post.
final FutureProviderFamily<PostViewerData?, int> postViewerProvider =
    FutureProvider.family<PostViewerData?, int>((ref, contentId) async {
      final opened = await ref.watch(contentRepoProvider).getById(contentId);
      if (opened == null || opened.content.kind != ContentKind.post) {
        return null;
      }
      final target = await ref
          .watch(targetRepoProvider)
          .getById(opened.content.targetId);
      return PostViewerData(
        item: opened,
        username: target?.username ?? '',
      );
    });

/// Removes one slide from the library (EC-20 "Remove slide"). Returns true
/// when the slide is gone.
typedef PostSlideRemover = Future<bool> Function(int contentId, int slideIndex);

/// The use case behind "Remove slide" (EC-20).
final removeMediaFileProvider = Provider<RemoveMediaFile>(
  (ref) => RemoveMediaFile(
    content: ref.watch(contentRepoProvider),
    gallery: ref.watch(galleryStoreProvider),
    cache: ref.watch(mediaCacheProvider),
  ),
);

/// The per-slide remover: deletes the slide's gallery file, thumbnail and row
/// (the whole post when it was the last slide). Returns false when the slide
/// is unknown or its gallery file could not be deleted (the row is kept).
///
/// Override with null to hide the "Remove slide" action.
final postSlideRemoverProvider = Provider<PostSlideRemover?>((ref) {
  final remove = ref.watch(removeMediaFileProvider);
  final content = ref.watch(contentRepoProvider);
  return (contentId, slideIndex) async {
    final item = await content.getById(contentId);
    final file = item?.media
        .where((m) => m.slideIndex == slideIndex)
        .firstOrNull;
    if (file == null) return false;
    return (await remove(contentId, file.id)).removed;
  };
});
