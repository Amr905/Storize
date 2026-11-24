import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/internal.dart';
import 'package:storize_domain/src/entities/target_limits.dart';
import 'package:storize_model/storize_model.dart';

/// A tracked account (table `target`).
@immutable
final class Target {
  /// Creates a target. Use [unsavedId] for [id] before it is stored.
  const Target({
    required this.id,
    required this.platform,
    required this.remoteUserId,
    required this.username,
    required this.category,
    required this.postsWatermarkAt,
    required this.addedAt,
    this.displayName,
    this.avatarPath,
    this.note,
    this.status = TargetStatus.active,
    this.statusReason,
    this.isPrivate = false,
    this.trackStories = true,
    this.trackPosts = true,
    this.trackReels = true,
    this.loginAccountId,
    this.lastStoriesCheckAt,
    this.lastPostsCheckAt,
    this.lastNewStoryAt,
    this.lastNewPostAt,
    this.historyRange = HistoryRange.none,
    this.historySince,
    this.historyProgress,
    this.highlightsEnabled = false,
  }) : assert(
         trackStories || trackPosts || trackReels,
         'At least one track flag must be on (FR-65, FR-67)',
       );

  /// The [id] of an entity that has not been stored yet.
  static const int unsavedId = 0;

  /// The maximum length of [note].
  static const int maxNoteLength = TargetLimits.noteMaxLength;

  /// The database ID.
  final int id;

  /// The platform of the account.
  final PlatformId platform;

  /// The stable user ID. With [platform] it is unique (EC-16).
  final String remoteUserId;

  /// The current username. Refreshed on each check (EC-5).
  final String username;

  /// The full name, when known.
  final String? displayName;

  /// The cached avatar file path.
  final String? avatarPath;

  /// The consent category (BR-1).
  final TargetCategory category;

  /// A free-text note, at most [maxNoteLength] characters.
  final String? note;

  /// Health of the target.
  final TargetStatus status;

  /// A short reason for a non-active [status].
  final String? statusReason;

  /// Whether the account is private.
  final bool isPrivate;

  /// Whether stories are tracked.
  final bool trackStories;

  /// Whether regular posts are tracked.
  final bool trackPosts;

  /// Whether reels are tracked (FR-67).
  final bool trackReels;

  /// Only posts published after this instant are downloaded (FR-63).
  final DateTime postsWatermarkAt;

  /// The login that checks this target. Null after that login is deleted.
  final int? loginAccountId;

  /// When the target was added (UTC).
  final DateTime addedAt;

  /// When stories were last checked (UTC).
  final DateTime? lastStoriesCheckAt;

  /// When posts were last checked (UTC).
  final DateTime? lastPostsCheckAt;

  /// When a new story was last found (UTC).
  final DateTime? lastNewStoryAt;

  /// When a new post was last found (UTC).
  final DateTime? lastNewPostAt;

  /// How far back the post history reaches (FR-68).
  final HistoryRange historyRange;

  /// The start date when [historyRange] is [HistoryRange.since].
  final DateTime? historySince;

  /// Progress of the post-history backfill, or null if none was started.
  final HistoryProgress? historyProgress;

  /// Whether highlights are tracked (FR-71).
  final bool highlightsEnabled;

  /// Returns a copy with the given fields replaced. Pass null to clear a
  /// nullable field. `platform` cannot change; `remoteUserId` changes only
  /// when a pending lookup resolves (FR-73).
  Target copyWith({
    int? id,
    String? remoteUserId,
    String? username,
    Object? displayName = unset,
    Object? avatarPath = unset,
    TargetCategory? category,
    Object? note = unset,
    TargetStatus? status,
    Object? statusReason = unset,
    bool? isPrivate,
    bool? trackStories,
    bool? trackPosts,
    bool? trackReels,
    DateTime? postsWatermarkAt,
    Object? loginAccountId = unset,
    DateTime? addedAt,
    Object? lastStoriesCheckAt = unset,
    Object? lastPostsCheckAt = unset,
    Object? lastNewStoryAt = unset,
    Object? lastNewPostAt = unset,
    HistoryRange? historyRange,
    Object? historySince = unset,
    Object? historyProgress = unset,
    bool? highlightsEnabled,
  }) => Target(
    id: id ?? this.id,
    platform: platform,
    remoteUserId: remoteUserId ?? this.remoteUserId,
    username: username ?? this.username,
    displayName: pick<String>(displayName, this.displayName),
    avatarPath: pick<String>(avatarPath, this.avatarPath),
    category: category ?? this.category,
    note: pick<String>(note, this.note),
    status: status ?? this.status,
    statusReason: pick<String>(statusReason, this.statusReason),
    isPrivate: isPrivate ?? this.isPrivate,
    trackStories: trackStories ?? this.trackStories,
    trackPosts: trackPosts ?? this.trackPosts,
    trackReels: trackReels ?? this.trackReels,
    postsWatermarkAt: postsWatermarkAt ?? this.postsWatermarkAt,
    loginAccountId: pick<int>(loginAccountId, this.loginAccountId),
    addedAt: addedAt ?? this.addedAt,
    lastStoriesCheckAt: pick<DateTime>(
      lastStoriesCheckAt,
      this.lastStoriesCheckAt,
    ),
    lastPostsCheckAt: pick<DateTime>(lastPostsCheckAt, this.lastPostsCheckAt),
    lastNewStoryAt: pick<DateTime>(lastNewStoryAt, this.lastNewStoryAt),
    lastNewPostAt: pick<DateTime>(lastNewPostAt, this.lastNewPostAt),
    historyRange: historyRange ?? this.historyRange,
    historySince: pick<DateTime>(historySince, this.historySince),
    historyProgress: pick<HistoryProgress>(
      historyProgress,
      this.historyProgress,
    ),
    highlightsEnabled: highlightsEnabled ?? this.highlightsEnabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Target &&
          other.id == id &&
          other.platform == platform &&
          other.remoteUserId == remoteUserId &&
          other.username == username &&
          other.displayName == displayName &&
          other.avatarPath == avatarPath &&
          other.category == category &&
          other.note == note &&
          other.status == status &&
          other.statusReason == statusReason &&
          other.isPrivate == isPrivate &&
          other.trackStories == trackStories &&
          other.trackPosts == trackPosts &&
          other.trackReels == trackReels &&
          other.postsWatermarkAt == postsWatermarkAt &&
          other.loginAccountId == loginAccountId &&
          other.addedAt == addedAt &&
          other.lastStoriesCheckAt == lastStoriesCheckAt &&
          other.lastPostsCheckAt == lastPostsCheckAt &&
          other.lastNewStoryAt == lastNewStoryAt &&
          other.lastNewPostAt == lastNewPostAt &&
          other.historyRange == historyRange &&
          other.historySince == historySince &&
          other.historyProgress == historyProgress &&
          other.highlightsEnabled == highlightsEnabled);

  @override
  int get hashCode => Object.hashAll([
    id,
    platform,
    remoteUserId,
    username,
    displayName,
    avatarPath,
    category,
    note,
    status,
    statusReason,
    isPrivate,
    trackStories,
    trackPosts,
    trackReels,
    postsWatermarkAt,
    loginAccountId,
    addedAt,
    lastStoriesCheckAt,
    lastPostsCheckAt,
    lastNewStoryAt,
    lastNewPostAt,
    historyRange,
    historySince,
    historyProgress,
    highlightsEnabled,
  ]);

  /// Omits [note] and [displayName], which are personal content.
  @override
  String toString() =>
      'Target(id: $id, remoteUserId: $remoteUserId, username: $username, '
      'status: ${status.name})';
}
