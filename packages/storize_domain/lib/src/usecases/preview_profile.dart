import 'dart:async';

import 'package:meta/meta.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/ports/diagnostic_log.dart';
import 'package:storize_model/storize_model.dart';

/// What [PreviewProfile] loaded for one account (FR-74).
///
/// A failure in one part never hides the other: [stories] and [posts] are
/// empty and the matching failure is set when that part failed.
@immutable
final class ProfilePreview {
  /// Creates a preview. The lists are copied into unmodifiable lists.
  ProfilePreview({
    required this.user,
    required List<RemoteContent> stories,
    required List<RemoteContent> posts,
    this.storiesFailure,
    this.postsFailure,
  }) : stories = List.unmodifiable(stories),
       posts = List.unmodifiable(posts);

  /// The resolved account.
  final RemoteUser user;

  /// The current stories (may be empty).
  final List<RemoteContent> stories;

  /// The first page of posts (newest first, may be empty).
  final List<RemoteContent> posts;

  /// Why the stories could not be loaded, or null.
  final Failure? storiesFailure;

  /// Why the posts could not be loaded, or null.
  final Failure? postsFailure;

  @override
  String toString() =>
      'ProfilePreview(stories: ${stories.length}, posts: ${posts.length}, '
      'storiesFailure: ${storiesFailure.runtimeType}, '
      'postsFailure: ${postsFailure.runtimeType})';
}

/// The outcome of [PreviewProfile.run]: the preview, or why the account could
/// not be resolved.
typedef PreviewResult = Result<ProfilePreview>;

/// Loads the current stories and the first posts page of an account, in the
/// foreground, so the user can look and save by hand (FR-74).
///
/// The calls are user-initiated: they use [ExtractionPolicy.directThenPage]
/// (the policy of manual checks) and the platform runs them in one in-page
/// session. [onFinished] runs at the end of every run, also after an error:
/// the composition closes the session there (`closeInPage`).
///
/// Logs `[preview]` lines: counts and failure types only, never names, URLs
/// or ids.
final class PreviewProfile {
  /// Creates the use case.
  PreviewProfile({
    required this._platform,
    this._log,
    this._onFinished,
    this.stepTimeout = const Duration(seconds: 90),
  });

  final ContentPlatform _platform;
  final DiagnosticLog? _log;
  final Future<void> Function()? _onFinished;

  /// The longest one platform call may take before it counts as a network
  /// failure, so the screen never spins for ever.
  final Duration stepTimeout;

  static const String _tag = 'preview';

  /// The policy of a user-initiated foreground load.
  static const ExtractionPolicy policy = ExtractionPolicy.directThenPage;

  /// Loads the preview of [username].
  Future<PreviewResult> run(String username) async {
    _info('start');
    try {
      final resolved = await _step(() => _platform.resolveUser(username));
      switch (resolved) {
        case Err(:final failure):
          _info('resolve failure=${_name(failure)}');
          return Err(failure);
        case Ok(:final value):
          _info('resolve ok');
          return Ok(await _load(value));
      }
    } finally {
      await _finish();
    }
  }

  /// Loads the preview of an account that is already resolved (the S-09
  /// entry point knows the user id and username). Same calls as [run] from
  /// the user on.
  Future<ProfilePreview> runFor(RemoteUser user) async {
    _info('start');
    try {
      return await _load(user);
    } finally {
      await _finish();
    }
  }

  Future<ProfilePreview> _load(RemoteUser user) async {
    final id = user.remoteUserId;
    final stories = await _step(
      () => _platform.fetchStories([id], policy: policy),
    );
    var storyItems = const <RemoteContent>[];
    Failure? storiesFailure;
    switch (stories) {
      case Ok(:final value):
        storyItems = [
          for (final c in value[id] ?? const <RemoteContent>[])
            if (c.kind == ContentKind.story) c,
        ];
        _info('stories n=${storyItems.length}');
      case Err(:final failure):
        storiesFailure = failure;
        _info('stories failure=${_name(failure)}');
    }

    final page = await _step(
      () => _platform.fetchPostPage(id, cursor: null, policy: policy),
    );
    var postItems = const <RemoteContent>[];
    Failure? postsFailure;
    switch (page) {
      case Ok(:final value):
        postItems = [
          for (final c in value.items)
            if (c.kind == ContentKind.post) c,
        ];
        _info('posts n=${postItems.length}');
      case Err(:final failure):
        postsFailure = failure;
        _info('posts failure=${_name(failure)}');
    }
    return ProfilePreview(
      user: user,
      stories: storyItems,
      posts: postItems,
      storiesFailure: storiesFailure,
      postsFailure: postsFailure,
    );
  }

  Future<Result<T>> _step<T>(Future<Result<T>> Function() call) async {
    try {
      return await call().timeout(stepTimeout);
    } on TimeoutException {
      return const Err(NetworkFailure());
    } on Object {
      return const Err(UnknownFailure(null, 'platform_threw'));
    }
  }

  Future<void> _finish() async {
    try {
      await _onFinished?.call();
    } on Object {
      // Clean-up only.
    }
  }

  String _name(Failure failure) => failure.runtimeType.toString();

  void _info(String message) => _log?.log(LogLevel.info, _tag, message);
}
