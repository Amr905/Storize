import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/governor/governor.dart';
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
    this._fixedAccountId,
    this._interactiveMaxWait,
  });

  /// The adapter of one fixed account id, whatever the active account is.
  /// The login flow uses it for the staging id `0` (S-02 verifies a session
  /// before it belongs to any account).
  ActiveAccountPlatform.fixed({
    required AccountRepo accounts,
    required PlatformFactory factory,
    required int accountId,
    Duration? interactiveMaxWait,
  }) : this(
         accounts: accounts,
         factory: factory,
         fixedAccountId: accountId,
         interactiveMaxWait: interactiveMaxWait,
       );

  final AccountRepo _accounts;
  final int? _fixedAccountId;
  final PlatformFactory _factory;

  /// When set, the interactive ops (`resolveUser`, `refreshUser`,
  /// `verifySession`) refuse to wait longer than this for the request budget
  /// and return `RateLimited` instead (TECH_SPEC 17.3). Null for background.
  final Duration? _interactiveMaxWait;

  Future<T> _interactive<T>(Future<T> Function() op) {
    final maxWait = _interactiveMaxWait;
    return maxWait == null ? op() : RequestGovernor.withMaxWait(maxWait, op);
  }

  final Map<int, Future<InstagramPlatform>> _cache = {};
  InstagramPlatform? _last;

  Future<InstagramPlatform> _current() async {
    final id = _fixedAccountId ?? (await _accounts.getActive())?.id ?? 0;
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
      _interactive(() async => (await _current()).resolveUser(username));

  @override
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  ) async => _interactive(
    () async => (await _current()).refreshUser(remoteUserId, lastUsername),
  );

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
      _interactive(() async => (await _current()).verifySession());

  @override
  Stream<List<int>> openMedia(String url, {int fromByte = 0}) async* {
    yield* (await _current()).openMedia(url, fromByte: fromByte);
  }
}
