import 'package:drift/drift.dart';
import 'package:storize_data/db/storize_database.dart';
import 'package:storize_data/db/tables.dart';
import 'package:storize_model/storize_model.dart';

part 'targets_dao.g.dart';

/// Raw queries for `target`.
///
/// A duplicate `(platform, remote_user_id)` makes [insert] throw a
/// `SqliteException` (constraint UNIQUE); T-006 maps it to the domain's
/// `DuplicateEntityException`.
@DriftAccessor(tables: [Targets])
class TargetsDao extends DatabaseAccessor<StorizeDatabase>
    with _$TargetsDaoMixin {
  TargetsDao(super.attachedDatabase);

  /// All targets by username (case-insensitive), then id.
  Stream<List<TargetRow>> watchAll() =>
      (select(targets)..orderBy([
            (t) => OrderingTerm.asc(t.username.lower()),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();

  Stream<TargetRow?> watchById(int id) =>
      (select(targets)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<TargetRow?> getById(int id) =>
      (select(targets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<TargetRow?> getByRemoteUserId(
    PlatformId platform,
    String remoteUserId,
  ) =>
      (select(targets)..where(
            (t) =>
                t.platform.equalsValue(platform) &
                t.remoteUserId.equals(remoteUserId),
          ))
          .getSingleOrNull();

  /// Inserts and returns the new id.
  Future<int> insert(TargetsCompanion target) => into(targets).insert(target);

  /// Writes every column of [target] (full replace by id). Returns rows
  /// changed.
  Future<int> updateRow(TargetRow target) =>
      (update(targets)..where((t) => t.id.equals(target.id))).write(
        target.toCompanion(false),
      );

  /// Writes only the present fields of [changes]. Use this for short updates
  /// such as the watermark or last-checked time. Returns rows changed.
  Future<int> updatePartial(int id, TargetsCompanion changes) =>
      (update(targets)..where((t) => t.id.equals(id))).write(changes);

  /// Deletes the target. Content and media cascade; activity events keep
  /// their row with a null `target_id`.
  Future<int> deleteById(int id) =>
      (delete(targets)..where((t) => t.id.equals(id))).go();

  /// Active targets that track something relevant to [scope], least recently
  /// checked first (never checked first), then by id.
  Future<List<TargetRow>> listActive(CheckScope scope) {
    final query = select(targets)
      ..where((t) {
        final wanted = switch (scope) {
          CheckScope.stories => t.trackStories.equals(true),
          CheckScope.posts =>
            t.trackPosts.equals(true) | t.trackReels.equals(true),
          CheckScope.all =>
            t.trackStories.equals(true) |
                t.trackPosts.equals(true) |
                t.trackReels.equals(true),
        };
        return t.status.equalsValue(TargetStatus.active) & wanted;
      })
      ..orderBy([
        // NULLs sort first in SQLite ascending order.
        if (scope == CheckScope.stories)
          (t) => OrderingTerm.asc(t.lastStoriesCheckAt),
        if (scope == CheckScope.posts)
          (t) => OrderingTerm.asc(t.lastPostsCheckAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return query.get();
  }
}
