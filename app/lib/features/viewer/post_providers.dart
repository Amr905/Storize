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

/// The per-slide remover. Null until a port removes a single media file
/// (follow-up T-029a); while null the "Remove slide" action is hidden and the
/// whole post can still be deleted.
final postSlideRemoverProvider = Provider<PostSlideRemover?>((ref) => null);
