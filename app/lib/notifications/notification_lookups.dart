import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// A content item the notifications point at.
final class NewItem {
  /// Creates the item.
  const NewItem({
    required this.id,
    required this.targetId,
    required this.kind,
  });

  /// The content id (the `storize://story/{id}` or `post/{id}` target).
  final int id;

  /// The tracked account it belongs to.
  final int targetId;

  /// Story or post.
  final ContentKind kind;
}

/// The data the notification texts and links need from the repos. A small
/// interface so the service is tested without the database.
abstract interface class NotificationLookups {
  /// The username of [targetId] (no `@`), or null when the target is gone.
  Future<String?> usernameOf(int targetId);

  /// The items among [contentIds] that still exist, in the order given.
  Future<List<NewItem>> itemsOf(List<int> contentIds);
}

/// The production lookups over the repos.
final class RepoNotificationLookups implements NotificationLookups {
  /// Creates the lookups.
  const RepoNotificationLookups({
    required this._targets,
    required this._content,
  });

  final TargetRepo _targets;
  final ContentRepo _content;

  @override
  Future<String?> usernameOf(int targetId) async =>
      (await _targets.getById(targetId))?.username;

  @override
  Future<List<NewItem>> itemsOf(List<int> contentIds) async {
    if (contentIds.isEmpty) return const [];
    final rows = await _content.getByIds(contentIds);
    final byId = {for (final r in rows) r.content.id: r.content};
    return [
      for (final id in contentIds)
        if (byId[id] case final c?)
          NewItem(id: c.id, targetId: c.targetId, kind: c.kind),
    ];
  }
}
