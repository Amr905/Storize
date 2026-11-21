import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_model/storize_model.dart';

/// Builds the Instagram adapter for one login account.
typedef PlatformFactory = Future<InstagramPlatform> Function(int accountId);

/// The content platform of the active login account.
///
/// `InstagramPlatform.assemble` is bound to one account ID (the session, the
/// lease and the request budget are per account), but the active account
/// changes at login and logout while the app runs. This wrapper asks
/// `AccountRepo.getActive` at each call and keeps one adapter per account ID,
/// so a new login is used at once and nothing is rebuilt per call.
///
/// With no active account the adapter of account `0` is used: it has no
/// stored session, so every call fails with `SessionInvalid` (BR-7) and sends
/// nothing.
final class ActiveAccountPlatform implements ContentPlatform, ContentSignals {
  /// Creates the wrapper.
  ActiveAccountPlatform({
    required this._accounts,
    required this._factory,
  });

  final AccountRepo _accounts;
  final PlatformFactory _factory;
  final Map<int, Future<InstagramPlatform>> _cache = {};
  InstagramPlatform? _last;

  Future<InstagramPlatform> _current() async {
    final account = await _accounts.getActive();
    final id = account?.id ?? 0;
    final platform = await _cache.putIfAbsent(id, () => _factory(id));
    return _last = platform;
  }

  @override
  PlatformId get id => PlatformId.instagram;

  /// The signals of the adapter used by the last call. RunCheck reads them
  /// right after a call, so this is that call's adapter.
  @override
  ContentSignalsSnapshot takeSignals() =>
      _last?.takeSignals() ?? const ContentSignalsSnapshot();

  @override
  Future<Result<RemoteUser>> resolveUser(String username) async =>
      (await _current()).resolveUser(username);

  @override
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  ) async => (await _current()).refreshUser(remoteUserId, lastUsername);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds, {
    required ExtractionPolicy policy,
  }) async => (await _current()).fetchStories(userIds, policy: policy);

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark, {
    required ExtractionPolicy policy,
  }) async =>
      (await _current()).fetchNewPosts(userId, watermark, policy: policy);

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) async =>
      (await _current()).latestPostTime(userId);

  @override
  Future<Result<RemoteUser>> verifySession() async =>
      (await _current()).verifySession();

  @override
  Stream<List<int>> openMedia(String url, {int fromByte = 0}) async* {
    yield* (await _current()).openMedia(url, fromByte: fromByte);
  }
}
