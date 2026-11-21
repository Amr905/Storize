import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/username_cache.dart';
import 'package:storize_model/storize_model.dart';

/// A [UsernameCache] that survives an isolate restart, backed by the target
/// repo (T-014 QA-F12, T-013 note on call cost).
///
/// - **Read:** the repo is read first. A name learned in this process is used
///   only while the row still says what it said when the name was learned (or
///   has no username); if the row changed since, the row is newer (another
///   isolate recorded a rename) and wins, and the overlay entry is dropped
///   (T-015a F7). Otherwise the username
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
  final Map<String, _Learned> _overlay = {};

  Future<String?> _stored(String userId) async {
    final target = await _targets.getByRemoteUserId(platform, userId);
    final stored = target?.username;
    return stored == null || stored.isEmpty ? null : stored;
  }

  @override
  Future<String?> usernameOf(String userId) async {
    final learned = _overlay[userId];
    if (learned == null) return _stored(userId);
    final String? stored;
    try {
      stored = await _stored(userId);
    } on Object {
      // The repo cannot be read: the name learned here is the best we have.
      return learned.name;
    }
    if (!learned.baselineKnown) {
      // `remember` could not read the row; this first good read is the base.
      learned
        ..baseline = stored
        ..baselineKnown = true;
    }
    if (stored != null && stored != learned.baseline) {
      // The row changed after we learned the name: it is the newer value.
      _overlay.remove(userId);
      return stored;
    }
    return learned.name;
  }

  @override
  Future<void> remember(String userId, String username) async {
    final learned = _Learned(username);
    try {
      learned
        ..baseline = await _stored(userId)
        ..baselineKnown = true;
    } on Object {
      // The base is taken at the next successful read.
    }
    _overlay[userId] = learned;
  }
}

/// A name learned in this process and the row value it was learned against.
final class _Learned {
  _Learned(this.name);

  final String name;
  String? baseline;
  bool baselineKnown = false;
}
