import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/username_cache.dart';
import 'package:storize_model/storize_model.dart';

/// A [UsernameCache] that survives an isolate restart, backed by the target
/// repo (T-014 QA-F12, T-013 note on call cost).
///
/// - **Read:** a name learned in this process wins; otherwise the username
///   stored on the target row with that remote user id. So after a restart
///   `fetchNewPosts` costs 1 call instead of 2, and page mode knows the
///   username of every tracked target.
/// - **Write: memory only.** `TargetRepo.update` replaces a whole row, and
///   RunCheck (T-017) owns the username change: it calls `refreshUser`,
///   compares the answer with `Target.username` and records the rename (EC-5).
///   If this cache wrote the new name into the row first, that comparison
///   would see no rename and the activity entry would be lost; a read, change,
///   write cycle could also overwrite a concurrent update of the watermark.
///   So a remembered name lives in an overlay in memory (also used for a user
///   who is not a target yet, for example while adding one) and the repo stays
///   the single place RunCheck changes.
///
/// A repo that throws is not an error for the caller: the extractors already
/// treat a failing cache as a miss.
final class TargetRepoUsernameCache implements UsernameCache {
  /// Creates the cache over `targets` for `platform`.
  TargetRepoUsernameCache(
    this._targets, {
    this.platform = PlatformId.instagram,
  });

  /// The platform whose targets are read.
  final PlatformId platform;

  final TargetRepo _targets;
  final Map<String, String> _overlay = {};

  @override
  Future<String?> usernameOf(String userId) async {
    final fresh = _overlay[userId];
    if (fresh != null) return fresh;
    final target = await _targets.getByRemoteUserId(platform, userId);
    final stored = target?.username;
    return stored == null || stored.isEmpty ? null : stored;
  }

  @override
  Future<void> remember(String userId, String username) async {
    _overlay[userId] = username;
  }
}
