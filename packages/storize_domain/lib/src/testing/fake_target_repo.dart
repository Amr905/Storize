import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_domain/src/testing/change_feed.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [TargetRepo] with the UNIQUE `(platform, remoteUserId)` rule.
final class FakeTargetRepo implements TargetRepo {
  final Map<int, Target> _rows = {};
  final ChangeFeed _feed = ChangeFeed();
  final List<void Function(int id)> _deleteListeners = [];
  int _nextId = 1;

  /// Registers [listener] to run after a target is deleted. `FakeContentRepo`
  /// uses it to cascade the delete.
  void onDelete(void Function(int id) listener) =>
      _deleteListeners.add(listener);

  List<Target> _all() {
    final list = _rows.values.toList()
      ..sort((a, b) {
        final byName = a.username.toLowerCase().compareTo(
          b.username.toLowerCase(),
        );
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
    return list;
  }

  @override
  Stream<List<Target>> watchAll() => _feed.watch(_all);

  @override
  Stream<Target?> watchById(int id) => _feed.watch(() => _rows[id]);

  @override
  Future<Target?> getById(int id) async => _rows[id];

  @override
  Future<Target?> getByRemoteUserId(
    PlatformId platform,
    String remoteUserId,
  ) async => _rows.values
      .where((t) => t.platform == platform && t.remoteUserId == remoteUserId)
      .firstOrNull;

  @override
  Future<Target> insert(Target target) async {
    final duplicate = _rows.values.any(
      (t) =>
          t.platform == target.platform &&
          t.remoteUserId == target.remoteUserId,
    );
    if (duplicate) {
      throw const DuplicateEntityException(
        'target',
        '(platform, remote_user_id)',
      );
    }
    final stored = target.copyWith(id: _nextId++);
    _rows[stored.id] = stored;
    _feed.notify();
    return stored;
  }

  @override
  Future<void> update(Target target) async {
    if (!_rows.containsKey(target.id)) {
      throw StateError('No target with id ${target.id}');
    }
    _rows[target.id] = target;
    _feed.notify();
  }

  @override
  Future<void> delete(int id) async {
    if (_rows.remove(id) == null) return;
    for (final listener in List.of(_deleteListeners)) {
      listener(id);
    }
    _feed.notify();
  }

  @override
  Future<List<Target>> listActive(CheckScope scope) async {
    bool wanted(Target t) => switch (scope) {
      CheckScope.stories => t.trackStories,
      CheckScope.posts => t.trackPosts || t.trackReels,
      CheckScope.all => t.trackStories || t.trackPosts || t.trackReels,
    };
    final list = _rows.values
        .where((t) => t.status == TargetStatus.active && wanted(t))
        .toList();
    DateTime? checkedAt(Target t) => switch (scope) {
      CheckScope.stories => t.lastStoriesCheckAt,
      CheckScope.posts => t.lastPostsCheckAt,
      CheckScope.all => null,
    };
    list.sort((a, b) {
      final x = checkedAt(a);
      final y = checkedAt(b);
      if (x != y) {
        if (x == null) return -1;
        if (y == null) return 1;
        return x.compareTo(y);
      }
      return a.id.compareTo(b.id);
    });
    return list;
  }
}
