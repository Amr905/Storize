import 'dart:math';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/failure_classifier.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/direct/ig_session.dart';
import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

/// The most users in one stories request (ADR-0010).
const int storyChunkSize = 20;

/// Direct mode: asks Instagram with plain HTTP and the stored session (ADR-3).
///
/// - Every request goes through [RequestGovernor.run] as `RequestCost.api`.
///   The governed closure only sends and classifies one request; the next
///   request starts after `run` has returned, so governed calls never nest.
/// - The protocol is a strategy: an [IgTransport] (REST or GraphQL). Mapping
///   is shared and transport-independent.
/// - It returns `Result`, never throws for expected failures. Missing fields
///   give `SchemaChanged(where)`, the signal to use page mode (T-015).
/// - The log gets operation names, outcome and failure type only: no URLs,
///   query values, headers, cookies, tokens or content.
///
/// The method set follows `ContentPlatform` without `policy` and `openMedia`;
/// T-015 adapts it.
final class DirectExtractor {
  /// Creates the extractor for the login account [accountId].
  DirectExtractor({
    required this.accountId,
    required this._governor,
    required this._sessions,
    required this._http,
    required this.transport,
    this._log,
    this.appId,
    this.classifier = const FailureClassifier(),
  });

  /// The login account whose session and request budget are used.
  final int accountId;

  /// The protocol in use.
  final IgTransport transport;

  /// `X-IG-App-ID`, when known (not hard-coded).
  final String? appId;

  /// Maps replies to failures.
  final FailureClassifier classifier;

  final RequestGovernor _governor;
  final SessionStore _sessions;
  final IgHttp _http;
  final DiagnosticLog? _log;
  final MediaMapper _media = const MediaMapper();

  /// Usernames seen per user id, so the GraphQL posts query needs no lookup.
  final Map<String, String> _usernames = {};

  // ----------------------------------------------------------------- users

  /// Looks up [username] (IG-1 purpose). Visibility is left to the caller:
  /// the result carries `isPrivate`, `followedByViewer` and `blockedByViewer`.
  Future<Result<RemoteUser>> resolveUser(String username) => _op(
    'resolveUser',
    (call) async {
      final clean = username.trim().replaceFirst(RegExp('^@'), '');
      if (clean.isEmpty) return const Err(TargetNotFound());
      final r = await transport.userByUsername(clean, call);
      return r.map(_remember);
    },
  );

  /// Reloads a user by id to detect a rename (IG-3 purpose). If the id lookup
  /// finds nothing (or fails in an unknown way), [lastUsername] is tried; the
  /// answer counts only if it has the same id.
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  ) => _op('refreshUser', (call) async {
    final byId = await transport.userById(remoteUserId, call);
    final failure = byId.failureOrNull;
    final retry =
        (failure is TargetNotFound || failure is UnknownFailure) &&
        lastUsername.trim().isNotEmpty;
    if (!retry) return byId.map(_remember);
    final byName = await transport.userByUsername(lastUsername.trim(), call);
    return switch (byName) {
      Ok(:final value) when value.user.remoteUserId == remoteUserId => Ok(
        _remember(value),
      ),
      Ok() => const Err(TargetNotFound()),
      Err(:final failure) => Err(failure),
    };
  });

  /// Checks the session and returns the logged-in user (IG-4 purpose).
  ///
  /// The viewer id in the response must equal the stored `ds_user_id`;
  /// anything else is `SessionInvalid(loginRequired)`.
  Future<Result<RemoteUser>> verifySession() => _op('verifySession', (
    call,
  ) async {
    final session = await IgSession.load(_sessions, accountId, appId: appId);
    final own = session?.userId ?? '';
    final r = await transport.viewer(own, call);
    switch (r) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.viewerId != own) {
          return const Err(SessionInvalid(SessionReason.loginRequired));
        }
        final profile = value.profile;
        if (profile != null) return Ok(_remember(profile));
        return (await transport.userById(own, call)).map(_remember);
    }
  });

  // --------------------------------------------------------------- stories

  /// The stories of [userIds], in chunks of at most [storyChunkSize] users.
  ///
  /// The map is keyed by user id; users without story items are left out.
  /// Live items are dropped. If any chunk fails the whole call fails with
  /// that failure: stories live 24 h, so the next run finds them.
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds,
  ) => _op('fetchStories', (call) async {
    final ids = {
      for (final id in userIds)
        if (id.trim().isNotEmpty) id.trim(),
    }.toList();
    final out = <String, List<RemoteContent>>{};
    for (var i = 0; i < ids.length; i += storyChunkSize) {
      final chunk = ids.sublist(i, min(i + storyChunkSize, ids.length));
      final r = await transport.storyReels(chunk, call);
      switch (r) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          for (final reel in value.values) {
            if (reel.items.isNotEmpty) out[reel.userId] = reel.items;
          }
      }
    }
    return Ok(out);
  });

  /// The time of the newest story item of [userId] (`latest_reel_media`), or
  /// null when there is no story. One cheap profile call: RunCheck compares it
  /// with the last story it saw and skips [fetchStories] when nothing is new.
  Future<Result<DateTime?>> latestStoryTime(String userId) =>
      _op('latestStoryTime', (call) async {
        final r = await transport.userById(userId, call);
        return r.map((p) {
          _remember(p);
          return p.latestReelMedia;
        });
      });

  // ----------------------------------------------------------------- posts

  /// Posts of [userId] published after [watermark] (by `taken_at`, so the
  /// pinned-first order does not matter), newest first, one entry per post.
  ///
  /// Only the first page is read (12 posts, ADR-0010). Collab posts that list
  /// the user in `coauthor_producers` count. A pinned post has
  /// `extras['pinned'] == true`. Posts that are not newer are not mapped, so
  /// a malformed old post cannot fail the run.
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  ) => _op('fetchNewPosts', (call) async {
    final r = await transport.timeline(
      userId,
      call,
      usernameHint: _usernames[userId],
    );
    switch (r) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final seen = <String>{};
        final fresh = [
          for (final e in value.entries)
            if (e.belongsTo(userId) &&
                e.takenAt.isAfter(watermark) &&
                seen.add(e.pk))
              e,
        ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
        _cacheUsername(userId, value.usernameUsed);
        return guardMapping(
          () => [
            for (final e in fresh)
              _media.post(
                e.node,
                pinned: e.pinned,
                collab: e.isCollabOf(userId),
              ),
          ],
        );
    }
  });

  /// The publish time of the newest post of [userId], or null if there is
  /// none. It is the largest `taken_at` of the posts that belong to the user,
  /// never the first entry, because pinned posts come first. A pinned post
  /// counts by its time like any other, so a freshly pinned new post is not
  /// downloaded later as "new".
  Future<Result<DateTime?>> latestPostTime(String userId) => _op(
    'latestPostTime',
    (call) async {
      final r = await transport.timeline(
        userId,
        call,
        usernameHint: _usernames[userId],
      );
      return r.map((t) {
        _cacheUsername(userId, t.usernameUsed);
        DateTime? latest;
        for (final e in t.entries) {
          if (!e.belongsTo(userId)) continue;
          if (latest == null || e.takenAt.isAfter(latest)) latest = e.takenAt;
        }
        return latest;
      });
    },
  );

  // --------------------------------------------------------------- plumbing

  RemoteUser _remember(UserProfile profile) {
    _usernames[profile.user.remoteUserId] = profile.user.username;
    return profile.user;
  }

  void _cacheUsername(String userId, String? username) {
    if (username != null) _usernames[userId] = username;
  }

  /// Runs one operation: checks the session, hands the transport a governed
  /// [IgCall], turns schema problems into `Err`, and logs the outcome.
  Future<Result<T>> _op<T>(
    String name,
    Future<Result<T>> Function(IgCall call) body,
  ) async {
    final session = await IgSession.load(_sessions, accountId, appId: appId);
    final Result<T> result;
    if (session == null) {
      result = const Err(SessionInvalid(SessionReason.loginRequired));
    } else {
      final headers = session.headers();
      try {
        result = await body((request) => _governed(request, headers));
      } on SchemaException catch (e) {
        _log?.log(LogLevel.warn, 'direct', 'op=$name schema_changed');
        return Err(e.toFailure());
      }
    }
    _logResult(name, result);
    return result;
  }

  /// One governed request. Network errors and failure-map rows come back as
  /// `Err`; a `RateLimited` also reaches the governor through the closure's
  /// result, so the account is paused.
  Future<Result<Map<String, Object?>>> _governed(
    IgRequest request,
    Map<String, String> headers,
  ) async {
    final authed = request.withHeaders(headers);
    try {
      return await _governor.run<Result<Map<String, Object?>>>(
        accountId: accountId,
        cost: RequestCost.api,
        call: () async {
          final IgReply reply;
          try {
            reply = await _http.send(authed);
          } on TransportException {
            return const Err(NetworkFailure());
          }
          final failure = classifier.classify(reply);
          if (failure != null) return Err(failure);
          return Ok(reply.json! as Map<String, Object?>);
        },
      );
    } on GovernorPaused catch (paused) {
      return Err(paused.toFailure());
    } on GovernorBusy {
      return const Err(UnknownFailure(null, 'governor_busy'));
    }
  }

  void _logResult<T>(String name, Result<T> result) {
    final failure = result.failureOrNull;
    if (failure == null) {
      _log?.log(LogLevel.info, 'direct', 'op=$name via=${transport.name} ok');
      return;
    }
    final detail = switch (failure) {
      SchemaChanged(:final where) => ' where=$where',
      UnknownFailure(:final code, :final message) =>
        ' code=$code message=$message',
      _ => '',
    };
    _log?.log(
      LogLevel.warn,
      'direct',
      'op=$name via=${transport.name} failure=${failure.runtimeType}$detail',
    );
  }
}
