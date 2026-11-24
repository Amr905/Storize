import 'dart:collection';

import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_model/storize_model.dart';

/// A queue of scripted [Result]s for one method of [FakeContentPlatform].
///
/// Each call takes the next queued result. When the queue is empty the
/// [fallback] is returned (and kept); with no fallback the call fails with a
/// [StateError] so a missing script never passes silently.
final class ScriptedResults<T> {
  final Queue<Result<T>> _queue = Queue<Result<T>>();

  /// Returned, without being consumed, when the queue is empty.
  Result<T>? fallback;

  /// Queues [result] for a later call.
  void add(Result<T> result) => _queue.add(result);

  /// Queues `Ok(value)`.
  void addOk(T value) => _queue.add(Ok<T>(value));

  /// Queues `Err(failure)`.
  void addFailure(Failure failure) => _queue.add(Err<T>(failure));

  /// How many results are still queued.
  int get queued => _queue.length;

  /// Takes the next result for the method called [method].
  Result<T> take(String method) {
    if (_queue.isNotEmpty) return _queue.removeFirst();
    final fallback = this.fallback;
    if (fallback != null) return fallback;
    throw StateError('FakeContentPlatform: no scripted result for $method');
  }
}

/// One recorded call to [FakeContentPlatform].
final class PlatformCall {
  /// Creates a record.
  PlatformCall(this.method, List<Object?> args)
    : args = List<Object?>.unmodifiable(args);

  /// The method name, for example `fetchStories`.
  final String method;

  /// The positional and named arguments, in declaration order.
  final List<Object?> args;

  @override
  String toString() => 'PlatformCall($method, $args)';
}

class _MediaScript {
  _MediaScript(this.bytes, this.chunkSize, this.error);

  final List<int> bytes;
  final int chunkSize;
  final Object? error;
}

/// A scriptable in-memory [ContentPlatform].
///
/// Queue results per method (`resolveUser.addOk(...)`,
/// `fetchStories.addFailure(...)`) and inspect [calls] afterwards.
final class FakeContentPlatform implements ContentPlatform {
  /// Creates a fake for [id] (Instagram by default).
  FakeContentPlatform({this.id = PlatformId.instagram});

  @override
  final PlatformId id;

  /// Scripted results of `resolveUser`.
  final ScriptedResults<RemoteUser> resolveUserResults = ScriptedResults();

  /// Scripted results of `refreshUser`.
  final ScriptedResults<RemoteUser> refreshUserResults = ScriptedResults();

  /// Scripted results of `fetchStories`.
  final ScriptedResults<Map<String, List<RemoteContent>>> fetchStoriesResults =
      ScriptedResults();

  /// Scripted results of `fetchNewPosts`.
  final ScriptedResults<List<RemoteContent>> fetchNewPostsResults =
      ScriptedResults();

  /// Scripted results of `latestPostTime`.
  final ScriptedResults<DateTime?> latestPostTimeResults = ScriptedResults();

  /// Scripted results of `fetchPostPage`.
  final ScriptedResults<PostPage> fetchPostPageResults = ScriptedResults();

  /// Scripted results of `fetchHighlights`.
  final ScriptedResults<List<RemoteHighlight>> fetchHighlightsResults =
      ScriptedResults();

  /// Scripted results of `fetchHighlightItems`.
  final ScriptedResults<Map<String, List<RemoteContent>>>
  fetchHighlightItemsResults = ScriptedResults();

  /// Scripted results of `verifySession`.
  final ScriptedResults<RemoteUser> verifySessionResults = ScriptedResults();

  final Queue<_MediaScript> _media = Queue<_MediaScript>();
  final List<PlatformCall> _calls = [];

  /// Every call so far, in order.
  List<PlatformCall> get calls => List.unmodifiable(_calls);

  /// The calls to [method], in order.
  List<PlatformCall> callsTo(String method) =>
      _calls.where((c) => c.method == method).toList();

  /// Queues a successful `openMedia` that streams [bytes] in chunks of
  /// [chunkSize]. The stream honours `fromByte` by skipping that many bytes.
  void queueMedia(List<int> bytes, {int chunkSize = 64 * 1024}) =>
      _media.add(_MediaScript(List<int>.of(bytes), chunkSize, null));

  /// Queues an `openMedia` that streams [bytesBeforeError] and then fails with
  /// [error], for example `const ExpiredMediaUrl()`.
  void queueMediaError(
    Object error, {
    List<int> bytesBeforeError = const [],
    int chunkSize = 64 * 1024,
  }) => _media.add(
    _MediaScript(List<int>.of(bytesBeforeError), chunkSize, error),
  );

  @override
  Future<Result<RemoteUser>> resolveUser(String username) async {
    _calls.add(PlatformCall('resolveUser', [username]));
    return resolveUserResults.take('resolveUser');
  }

  @override
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  ) async {
    _calls.add(PlatformCall('refreshUser', [remoteUserId, lastUsername]));
    return refreshUserResults.take('refreshUser');
  }

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds, {
    required ExtractionPolicy policy,
  }) async {
    _calls.add(
      PlatformCall('fetchStories', [List<String>.of(userIds), policy]),
    );
    return fetchStoriesResults.take('fetchStories');
  }

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark, {
    required ExtractionPolicy policy,
  }) async {
    _calls.add(PlatformCall('fetchNewPosts', [userId, watermark, policy]));
    return fetchNewPostsResults.take('fetchNewPosts');
  }

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) async {
    _calls.add(PlatformCall('latestPostTime', [userId]));
    return latestPostTimeResults.take('latestPostTime');
  }

  @override
  Future<Result<PostPage>> fetchPostPage(
    String userId, {
    required ExtractionPolicy policy,
    String? cursor,
  }) async {
    _calls.add(PlatformCall('fetchPostPage', [userId, cursor, policy]));
    return fetchPostPageResults.take('fetchPostPage');
  }

  @override
  Future<Result<List<RemoteHighlight>>> fetchHighlights(
    String userId, {
    required ExtractionPolicy policy,
  }) async {
    _calls.add(PlatformCall('fetchHighlights', [userId, policy]));
    return fetchHighlightsResults.take('fetchHighlights');
  }

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchHighlightItems(
    List<String> highlightIds, {
    required ExtractionPolicy policy,
  }) async {
    _calls.add(
      PlatformCall('fetchHighlightItems', [
        List<String>.of(highlightIds),
        policy,
      ]),
    );
    return fetchHighlightItemsResults.take('fetchHighlightItems');
  }

  @override
  Future<Result<RemoteUser>> verifySession() async {
    _calls.add(PlatformCall('verifySession', const []));
    return verifySessionResults.take('verifySession');
  }

  @override
  Stream<List<int>> openMedia(String url, {int fromByte = 0}) {
    _calls.add(PlatformCall('openMedia', [url, fromByte]));
    if (_media.isEmpty) {
      return Stream<List<int>>.error(
        StateError('FakeContentPlatform: no scripted media for openMedia'),
      );
    }
    final script = _media.removeFirst();
    return _stream(script, fromByte);
  }

  Stream<List<int>> _stream(_MediaScript script, int fromByte) async* {
    final start = fromByte.clamp(0, script.bytes.length);
    for (var i = start; i < script.bytes.length; i += script.chunkSize) {
      final end = (i + script.chunkSize).clamp(0, script.bytes.length);
      yield script.bytes.sublist(i, end);
    }
    final error = script.error;
    // ignore: only_throw_errors, the test scripts any error object.
    if (error != null) throw error;
  }
}
