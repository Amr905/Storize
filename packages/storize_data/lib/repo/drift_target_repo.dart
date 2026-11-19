import 'package:drift/drift.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo_support.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// [TargetRepo] over [TargetsDao].
final class DriftTargetRepo implements TargetRepo {
  /// Creates the repo over [db].
  DriftTargetRepo(StorizeDatabase db) : _dao = db.targetsDao;

  final TargetsDao _dao;

  static const _duplicateKey = '(platform, remote_user_id)';

  @override
  Stream<List<Target>> watchAll() =>
      freshStream(_dao.watchAll().map((rows) => rows.map(_toTarget).toList()));

  @override
  Stream<Target?> watchById(int id) => freshStream(
    _dao.watchById(id).map((row) => row == null ? null : _toTarget(row)),
  );

  @override
  Future<Target?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toTarget(row);
  }

  @override
  Future<Target?> getByRemoteUserId(
    PlatformId platform,
    String remoteUserId,
  ) async {
    final row = await _dao.getByRemoteUserId(platform, remoteUserId);
    return row == null ? null : _toTarget(row);
  }

  @override
  Future<Target> insert(Target target) async {
    // `id` stays absent: an explicit 0 would be stored as row 0.
    final id = await mapUniqueViolation(
      'target',
      _duplicateKey,
      () => _dao.insert(_toCompanion(target)),
    );
    return target.copyWith(id: id);
  }

  @override
  Future<void> update(Target target) async {
    // One short UPDATE statement; no read-modify-write window.
    final rows = await mapUniqueViolation(
      'target',
      _duplicateKey,
      () => _dao.updatePartial(target.id, _toCompanion(target)),
    );
    requireRowChanged(rows, 'target', target.id);
  }

  @override
  Future<void> delete(int id) async {
    await _dao.deleteById(id);
  }

  @override
  Future<List<Target>> listActive(CheckScope scope) async =>
      (await _dao.listActive(scope)).map(_toTarget).toList();
}

Target _toTarget(TargetRow r) => Target(
  id: r.id,
  platform: r.platform,
  remoteUserId: r.remoteUserId,
  username: r.username,
  displayName: r.displayName,
  avatarPath: r.avatarPath,
  category: r.category,
  note: r.note,
  status: r.status,
  statusReason: r.statusReason,
  isPrivate: r.isPrivate,
  trackStories: r.trackStories,
  trackPosts: r.trackPosts,
  trackReels: r.trackReels,
  postsWatermarkAt: r.postsWatermarkAt,
  loginAccountId: r.loginAccountId,
  addedAt: r.addedAt,
  lastStoriesCheckAt: r.lastStoriesCheckAt,
  lastPostsCheckAt: r.lastPostsCheckAt,
  lastNewStoryAt: r.lastNewStoryAt,
  lastNewPostAt: r.lastNewPostAt,
);

/// Every column except `id`, which stays absent.
TargetsCompanion _toCompanion(Target t) => TargetsCompanion(
  platform: Value(t.platform),
  remoteUserId: Value(t.remoteUserId),
  username: Value(t.username),
  displayName: Value(t.displayName),
  avatarPath: Value(t.avatarPath),
  category: Value(t.category),
  note: Value(t.note),
  status: Value(t.status),
  statusReason: Value(t.statusReason),
  isPrivate: Value(t.isPrivate),
  trackStories: Value(t.trackStories),
  trackPosts: Value(t.trackPosts),
  trackReels: Value(t.trackReels),
  postsWatermarkAt: Value(t.postsWatermarkAt),
  loginAccountId: Value(t.loginAccountId),
  addedAt: Value(t.addedAt),
  lastStoriesCheckAt: Value(t.lastStoriesCheckAt),
  lastPostsCheckAt: Value(t.lastPostsCheckAt),
  lastNewStoryAt: Value(t.lastNewStoryAt),
  lastNewPostAt: Value(t.lastNewPostAt),
);
