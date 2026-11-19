import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_model/storize_model.dart';

/// Access to tracked accounts (table `target`).
abstract interface class TargetRepo {
  /// Emits all targets now and after every change, ordered by username
  /// (case-insensitive), then ID.
  Stream<List<Target>> watchAll();

  /// Emits the target with [id] now and after every change. Emits null when it
  /// does not exist or is deleted.
  Stream<Target?> watchById(int id);

  /// The target with [id], or null.
  Future<Target?> getById(int id);

  /// The target with this identity, or null (FR-13, EC-16).
  Future<Target?> getByRemoteUserId(PlatformId platform, String remoteUserId);

  /// Stores [target] and returns it with its assigned ID. The ID of [target]
  /// is ignored.
  ///
  /// Throws [DuplicateEntityException] when a target with the same platform
  /// and remote user ID exists (EC-16).
  Future<Target> insert(Target target);

  /// Replaces the stored row that has the same ID as [target].
  ///
  /// Throws [StateError] when no such row exists.
  Future<void> update(Target target);

  /// Deletes the target and, by cascade, its content and media rows. Callers
  /// delete gallery files first (BR-6, BR-9). Does nothing if it is missing.
  Future<void> delete(int id);

  /// The targets a check of [scope] should look at: status ACTIVE and the
  /// matching track flag (FR-65, FR-67).
  ///
  /// - [CheckScope.stories]: `trackStories`.
  /// - [CheckScope.posts]: `trackPosts` or `trackReels`.
  /// - [CheckScope.all]: either of the above.
  ///
  /// Order: least recently checked first (`lastStoriesCheckAt` for stories,
  /// `lastPostsCheckAt` for posts, nulls first), then ID. This gives the
  /// round-robin carry-over of ADR-9. For [CheckScope.all] the order is by ID.
  Future<List<Target>> listActive(CheckScope scope);
}
