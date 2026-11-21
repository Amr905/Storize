import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// One tracked account, live. Null when the target no longer exists.
final StreamProviderFamily<Target?, int> targetDetailTargetProvider =
    StreamProvider.autoDispose.family<Target?, int>(
      (ref, id) => ref.watch(targetRepoProvider).watchById(id),
    );

/// Every stored item of one target, newest first. One subscription feeds the
/// counts and the Recent grid.
final StreamProviderFamily<List<ContentWithMedia>, int>
targetDetailContentProvider = StreamProvider.autoDispose
    .family<List<ContentWithMedia>, int>(
      (ref, id) => ref
          .watch(contentRepoProvider)
          .watchLibrary(ContentFilter(targetIds: {id})),
    );

/// Stored bytes of one target (FR-53), through [ComputeStorage].
final FutureProviderFamily<int, int> targetDetailStorageProvider =
    FutureProvider.autoDispose.family<int, int>(
      (ref, id) async {
        final report = await ComputeStorage(
          content: ref.watch(contentRepoProvider),
          storage: ref.watch(storageInfoProvider),
        ).call();
        return report.bytesByTarget[id] ?? 0;
      },
    );

/// The S-10 use case (BR-6). The only way to remove a target from the UI.
final removeTargetUseCaseProvider = Provider<RemoveTarget>(
  (ref) => RemoveTarget(
    targets: ref.watch(targetRepoProvider),
    content: ref.watch(contentRepoProvider),
    deleteContent: ref.watch(deleteContentProvider),
  ),
);

/// Edits on S-09: category, note and tracks.
final targetDetailActionsProvider = Provider<TargetDetailActions>(
  (ref) => TargetDetailActions(ref.watch(targetRepoProvider)),
);

/// Saves the S-09 edits. Pause and resume live in `targetActionsProvider`.
class TargetDetailActions {
  /// Creates the actions over [_targets].
  const TargetDetailActions(this._targets);

  final TargetRepo _targets;

  /// Turns [kind] on or off. Returns false, and changes nothing, when that
  /// would leave no track on (F-1). Throws when the repository fails.
  Future<bool> setTrack(
    Target target,
    TrackKind kind, {
    required bool on,
  }) async {
    final current = await _targets.getById(target.id);
    if (current == null) return true;
    final tracks = {
      TrackKind.stories: current.trackStories,
      TrackKind.posts: current.trackPosts,
      TrackKind.reels: current.trackReels,
    }..[kind] = on;
    if (!tracks.containsValue(true)) return false;
    await _targets.update(
      current.copyWith(
        trackStories: tracks[TrackKind.stories],
        trackPosts: tracks[TrackKind.posts],
        trackReels: tracks[TrackKind.reels],
      ),
    );
    return true;
  }

  /// Saves a new category.
  Future<void> setCategory(Target target, TargetCategory category) async {
    final current = await _targets.getById(target.id);
    if (current == null) return;
    await _targets.update(current.copyWith(category: category));
  }

  /// Saves the note. Blank text clears it. Throws when the repository fails.
  Future<void> setNote(Target target, String text) async {
    final current = await _targets.getById(target.id);
    if (current == null) return;
    final trimmed = text.trim();
    await _targets.update(
      current.copyWith(note: trimmed.isEmpty ? null : trimmed),
    );
  }
}
