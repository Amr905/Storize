import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

final DateTime t0 = DateTime.utc(2026, 11, 19, 10);

Target target({
  int id = Target.unsavedId,
  String remoteUserId = '100',
  String username = 'alice',
  TargetStatus status = TargetStatus.active,
  bool trackStories = true,
  bool trackPosts = true,
  bool trackReels = true,
  DateTime? lastStoriesCheckAt,
  DateTime? lastPostsCheckAt,
}) => Target(
  id: id,
  platform: PlatformId.instagram,
  remoteUserId: remoteUserId,
  username: username,
  category: TargetCategory.public,
  postsWatermarkAt: t0,
  addedAt: t0,
  status: status,
  trackStories: trackStories,
  trackPosts: trackPosts,
  trackReels: trackReels,
  lastStoriesCheckAt: lastStoriesCheckAt,
  lastPostsCheckAt: lastPostsCheckAt,
);

Content content({
  required int targetId,
  String remoteId = 'r1',
  ContentKind kind = ContentKind.story,
  DateTime? postedAt,
  DateTime? detectedAt,
  ContentStatus status = ContentStatus.pending,
}) => Content(
  id: Content.unsavedId,
  targetId: targetId,
  kind: kind,
  remoteId: remoteId,
  postedAt: postedAt ?? t0,
  slideCount: 1,
  detectedAt: detectedAt ?? t0,
  status: status,
);

MediaFile media({
  int slideIndex = 0,
  MediaType type = MediaType.photo,
  MediaFileStatus status = MediaFileStatus.pending,
  int? sizeBytes,
}) => MediaFile(
  id: MediaFile.unsavedId,
  contentId: MediaFile.unsavedContentId,
  slideIndex: slideIndex,
  mediaType: type,
  sourceUrl: 'https://example.invalid/m$slideIndex',
  status: status,
  sizeBytes: sizeBytes,
);
