// Fakes for the InstagramPlatform tests: scripted extraction modes, a scripted
// CDN client and small builders.
import 'dart:async';

import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_model/storize_model.dart';

const secretName = 'zz_secret_name';
const secretUrl = 'https://scontent.fbcdn.net/ZZFAKE_signed_path?sig=ZZFAKE';

RemoteUser aUser([String name = secretName]) => RemoteUser(
  remoteUserId: 'user_1',
  username: name,
  followedByViewer: true,
  blockedByViewer: false,
);

/// A scripted [DirectOps] and [PageOps] in one: records every call.
final class FakeMode implements DirectOps, PageOps {
  FakeMode(this.label, this.calls);

  final String label;
  final List<String> calls;

  Result<RemoteUser> Function() user = () => Ok(aUser());
  Result<RemoteUser> Function() verify = () => Ok(aUser());
  Result<Map<String, List<RemoteContent>>> Function(List<String> ids) stories =
      (_) => const Ok({});
  Result<List<RemoteContent>> Function() posts = () => const Ok([]);
  Result<DateTime?> Function() latest = () => const Ok(null);
  Exception? throwWith;

  Future<T> _answer<T>(String method, T Function() make) async {
    calls.add('$label.$method');
    if (throwWith case final Exception error) throw error;
    return make();
  }

  @override
  Future<Result<RemoteUser>> resolveUser(String username) =>
      _answer('resolveUser', user);

  @override
  Future<Result<RemoteUser>> refreshUser(String id, String last) =>
      _answer('refreshUser', user);

  @override
  Future<Result<RemoteUser>> verifySession() =>
      _answer('verifySession', verify);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds,
  ) => _answer('fetchStories', () => stories(userIds));

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  ) => _answer('fetchNewPosts', posts);

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) =>
      _answer('latestPostTime', latest);
}

/// A [CdnHttp] with a scripted reply that records every request.
final class FakeCdnHttp implements CdnHttp {
  FakeCdnHttp(this.reply);

  FutureOr<CdnResponse> Function(Uri uri, Map<String, String> headers) reply;
  final List<Uri> uris = [];
  final List<Map<String, String>> headers = [];

  @override
  Future<CdnResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    uris.add(uri);
    this.headers.add(Map.of(headers));
    return reply(uri, headers);
  }
}

/// A body stream that emits [chunks] and then ends, errors or stalls.
Stream<List<int>> bodyOf(
  List<List<int>> chunks, {
  Object? errorAfter,
  bool stall = false,
  void Function()? onCancel,
}) {
  late StreamController<List<int>> c;
  c = StreamController<List<int>>(
    onListen: () {
      chunks.forEach(c.add);
      if (errorAfter != null) c.addError(errorAfter);
      if (!stall) c.close().ignore();
    },
    onCancel: onCancel,
  );
  return c.stream;
}

/// Counts how often the store is read and written.
final class CountingSeenStore implements SeenBreakerStore {
  CountingSeenStore({this.value = false});

  bool value;
  int reads = 0;
  int writes = 0;
  int clears = 0;
  bool throwOnRead = false;
  bool throwOnWrite = false;
  bool throwOnClear = false;

  @override
  Future<bool> isTripped() async {
    reads++;
    if (throwOnRead) throw StateError('read failed ZZFAKE');
    return value;
  }

  @override
  Future<void> markTripped() async {
    writes++;
    if (throwOnWrite) throw StateError('write failed ZZFAKE');
    value = true;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (throwOnClear) throw StateError('clear failed ZZFAKE');
    value = false;
  }
}

/// Everything a log holds, as one string.
String logText(FakeDiagnosticLog log) =>
    log.entries.map((e) => '$e ${e.error ?? ''}').join('\n');
