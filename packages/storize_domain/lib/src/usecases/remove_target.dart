import 'package:meta/meta.dart';
import 'package:storize_domain/src/repos/content_repo.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_domain/src/usecases/delete_content.dart';

/// The outcome of [RemoveTarget].
@immutable
final class RemoveTargetResult {
  /// Creates a result.
  const RemoveTargetResult({
    required this.targetFound,
    required this.targetRemoved,
    this.deletion,
  });

  /// Whether the target existed when the use case started.
  final bool targetFound;

  /// Whether the target row is gone now. False when [targetFound] is false
  /// (nothing to do) or when some media could not be deleted.
  final bool targetRemoved;

  /// The media deletion outcome. Null when media was kept.
  final DeleteContentResult? deletion;

  /// True when the target is gone or never existed.
  bool get isComplete => !targetFound || targetRemoved;

  @override
  String toString() =>
      'RemoveTargetResult(found: $targetFound, removed: $targetRemoved, '
      'deletion: $deletion)';
}

/// Removes a target, keeping or deleting its downloaded media (BR-6).
///
/// - **Keep media** (`deleteMedia: false`, the S-10 default): the target row is
///   deleted. `ON DELETE CASCADE` removes its content and media rows
///   (TECH_SPEC §3). The gallery files are not touched; they stay in
///   `Pictures/Storize/<username>/` but Storize no longer lists them.
/// - **Delete media** (`deleteMedia: true`): files go first through
///   [DeleteContent] (BR-9), then the target. If any item fails, the target is
///   **kept** (`targetRemoved` false) so the rows that still own undeleted
///   files are not cascaded away. Items already deleted stay deleted.
///
/// Files are deleted in passes (at most [maxPasses]) until the target has no
/// content left, so content that arrives meanwhile is not orphaned. The target
/// is removed only when nothing is left; otherwise `targetRemoved` is false and
/// a re-run continues.
///
/// Idempotent: media is deleted in chunks, the target last. After a crash the
/// re-run finds fewer items (missing files count as deleted) and finishes.
/// A missing target is a no-op.
final class RemoveTarget {
  /// Creates the use case.
  RemoveTarget({
    required this._targets,
    required this._content,
    required this._deleteContent,
  });

  /// The most list-and-delete passes per call, so a steady stream of new
  /// content cannot keep the call spinning.
  static const int maxPasses = 10;

  final TargetRepo _targets;
  final ContentRepo _content;
  final DeleteContent _deleteContent;

  /// Removes the target [targetId].
  Future<RemoveTargetResult> call(
    int targetId, {
    required bool deleteMedia,
  }) async {
    final target = await _targets.getById(targetId);
    if (target == null) {
      return const RemoveTargetResult(
        targetFound: false,
        targetRemoved: false,
      );
    }
    if (!deleteMedia) {
      await _targets.delete(targetId);
      return const RemoveTargetResult(targetFound: true, targetRemoved: true);
    }
    // Content can arrive while files are being deleted (a download finishing).
    // List again until nothing new is left, so no late file is orphaned by the
    // cascade. Items that failed once are not retried within this call.
    final deleted = <int>[];
    final failures = <DeleteFailure>[];
    var filesDeleted = 0;
    var filesMissing = 0;
    var settled = false;
    for (var pass = 0; pass < maxPasses && !settled; pass++) {
      final failedIds = {for (final f in failures) f.contentId};
      final items = [
        for (final i in await _content.listByTarget(targetId))
          if (!failedIds.contains(i.content.id)) i,
      ];
      if (items.isEmpty) {
        settled = true;
        break;
      }
      final r = await _deleteContent.deleteLoaded(items);
      deleted.addAll(r.deletedContentIds);
      failures.addAll(r.failures);
      filesDeleted += r.filesDeleted;
      filesMissing += r.filesMissing;
    }
    final deletion = DeleteContentResult(
      deletedContentIds: deleted,
      failures: failures,
      notFoundIds: const [],
      filesDeleted: filesDeleted,
      filesMissing: filesMissing,
    );
    if (!deletion.isComplete || !settled) {
      return RemoveTargetResult(
        targetFound: true,
        targetRemoved: false,
        deletion: deletion,
      );
    }
    await _targets.delete(targetId);
    return RemoveTargetResult(
      targetFound: true,
      targetRemoved: true,
      deletion: deletion,
    );
  }
}
