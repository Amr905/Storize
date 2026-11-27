import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// A fixed base time with whole-millisecond precision, in UTC.
final DateTime t0 = DateTime.utc(2026, 3, 10, 12);

DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

Target aTarget({
  int id = Target.unsavedId,
  String remoteUserId = 'u-1',
  String username = 'alpha',
  TargetStatus status = TargetStatus.active,
  bool trackStories = true,
  bool trackPosts = true,
  bool trackReels = true,
  DateTime? lastStoriesCheckAt,
  DateTime? lastPostsCheckAt,
  int? loginAccountId,
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
  loginAccountId: loginAccountId,
);

/// A target with every optional field set.
Target aFullTarget({int? loginAccountId}) => Target(
  id: Target.unsavedId,
  platform: PlatformId.instagram,
  remoteUserId: 'u-full',
  username: 'Full_User',
  displayName: 'Full User',
  avatarPath: 'avatars/full.jpg',
  category: TargetCategory.consented,
  note: 'a note',
  status: TargetStatus.paused,
  statusReason: 'because',
  isPrivate: true,
  trackPosts: false,
  postsWatermarkAt: at(1),
  loginAccountId: loginAccountId,
  addedAt: at(2),
  lastStoriesCheckAt: at(3),
  lastPostsCheckAt: at(4),
  lastNewStoryAt: at(5),
  lastNewPostAt: at(6),
);

Content aContent(
  int targetId, {
  String remoteId = 'r-1',
  ContentKind kind = ContentKind.story,
  DateTime? postedAt,
  DateTime? detectedAt,
  ContentStatus status = ContentStatus.pending,
  bool viewed = false,
  Map<String, Object?> extras = const {},
}) => Content(
  id: Content.unsavedId,
  targetId: targetId,
  kind: kind,
  remoteId: remoteId,
  postedAt: postedAt ?? t0,
  slideCount: 1,
  detectedAt: detectedAt ?? t0,
  status: status,
  viewed: viewed,
  extras: extras,
);

/// A content row with every optional field set.
Content aFullContent(int targetId) => Content(
  id: Content.unsavedId,
  targetId: targetId,
  kind: ContentKind.post,
  remoteId: 'r-full',
  shortcode: 'Abc123',
  postType: PostType.carousel,
  postedAt: at(10),
  expiresAt: at(20),
  caption: 'caption',
  locationName: 'ZZFAKE_place',
  taggedUsernames: const ['zzfake_a', 'zzfake_b'],
  slideCount: 2,
  isCloseFriends: true,
  extras: const {
    'n': 1,
    'flag': true,
    'nothing': null,
    'nested': {
      'list': [1, 'two', 3.5],
    },
  },
  detectedAt: at(11),
  status: ContentStatus.partial,
  viewed: true,
);

MediaFile aMedia({
  int slideIndex = 0,
  MediaType type = MediaType.photo,
  MediaFileStatus status = MediaFileStatus.pending,
  int? sizeBytes,
  String url = 'https://cdn.example.invalid/m',
}) => MediaFile(
  id: MediaFile.unsavedId,
  contentId: MediaFile.unsavedContentId,
  slideIndex: slideIndex,
  mediaType: type,
  sourceUrl: '$url$slideIndex',
  status: status,
  sizeBytes: sizeBytes,
);

/// A media file with every optional field set.
MediaFile aFullMedia() => MediaFile(
  id: MediaFile.unsavedId,
  contentId: MediaFile.unsavedContentId,
  slideIndex: 3,
  mediaType: MediaType.video,
  sourceUrl: 'https://cdn.example.invalid/full',
  status: MediaFileStatus.done,
  attempts: 2,
  contentUri: 'content://media/external/1',
  relativePath: 'Pictures/Storize/x/',
  displayName: 'x_1.mp4',
  thumbPath: 'thumbs/1.jpg',
  width: 720,
  height: 1280,
  durationMs: 9500,
  sizeBytes: 1234,
  downloadedAt: at(30),
);

/// Records every value of a stream and waits for conditions on it.
///
/// Drift streams emit asynchronously and the fakes synchronously, so tests
/// poll instead of counting emissions.
final class Watch<T> {
  Watch(Stream<T> stream) {
    _subscription = stream.listen(_values.add, onError: _errors.add);
  }

  late final StreamSubscription<T> _subscription;
  final List<T> _values = [];
  final List<Object> _errors = [];
  int _from = 0;

  List<T> get values => List.unmodifiable(_values);
  List<Object> get errors => List.unmodifiable(_errors);
  T? get latest => _values.isEmpty ? null : _values.last;

  /// Only values that arrive after this call count for [until].
  void mark() => _from = _values.length;

  /// Resolves with the first value (since [mark]) that satisfies [test].
  Future<T> until(
    bool Function(T value) test, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      for (final v in _values.skip(_from)) {
        if (test(v)) return v;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure(
          'Stream never matched. Values since mark: '
          '${_values.skip(_from).toList()}; errors: $_errors',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> cancel() async => _subscription.cancel();
}
