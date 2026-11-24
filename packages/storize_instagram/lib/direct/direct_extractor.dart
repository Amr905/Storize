import 'dart:math';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/failure_classifier.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/direct/ig_session.dart';
import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/direct/rest_requests.dart';
import 'package:storize_instagram/direct/rest_transport.dart';
import 'package:storize_instagram/direct/username_cache.dart';
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
/// **Call cost.** `resolveUser` over GraphQL costs 2 calls (posts, then
/// profile). `fetchNewPosts` and `latestPostTime` cost **1** call when the
/// username of the user is known to the [UsernameCache] and 2 when it is not
/// (the profile is read first). The default cache is in memory, so after an
/// isolate restart every target costs 2 once; inject a persistent cache
/// (T-015: the target repo, which stores the username) to avoid that.
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
    UsernameCache? usernames,
  }) : _usernames = usernames ?? InMemoryUsernameCache();

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

  /// Usernames per user id, so the GraphQL posts query needs no lookup.
  final UsernameCache _usernames;

  // ----------------------------------------------------------------- users

  /// Looks up [username] (IG-1 purpose). Visibility is left to the caller:
  /// the result carries `isPrivate`, `followedByViewer` and `blockedByViewer`.
  Future<Result<RemoteUser>> resolveUser(String username) =>
      _op('resolveUser', (call) async {
        final clean = username.trim().replaceFirst(RegExp('^@'), '');
        if (clean.isEmpty) return const Err(TargetNotFound());
        final r = await transport.userByUsername(clean, call);
        if (r is Ok<UserProfile> &&
            r.value.user.username.toLowerCase() != clean.toLowerCase()) {
          // The profile of the id we found is not the user we asked for.
          return const Err(UnknownFailure(null, 'username_mismatch'));
        }
        return _rememberResult(r);
      });

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
    if (!retry) return _rememberResult(byId);
    final byName = await transport.userByUsername(lastUsername.trim(), call);
    switch (byName) {
      case Ok(:final value) when value.user.remoteUserId == remoteUserId:
        return _rememberResult(byName);
      case Ok():
        return const Err(TargetNotFound());
      case Err(:final failure):
        return Err(failure);
    }
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
    var r = await transport.viewer(own, call);
    // Bootstrap: GraphQL needs a `doc_id` and page tokens that only a page
    // load discovers, and on the very first login nothing has been loaded
    // yet. The session check then uses IG-4 (REST `accounts/current_user`)
    // once; every other operation stays on GraphQL (ADR-0003 addendum,
    // amendment 2026-11-22).
    if (r case Err(failure: SchemaChanged(:final where))
        when where.startsWith('doc_id:') || where == 'page_tokens') {
      _log?.log(LogLevel.info, 'direct', 'op=verifySession rest_bootstrap');
      r = await const RestTransport().viewer(own, call);
      // `current_user` belongs to the mobile API, so the web session may be
      // refused (HTTP 400, seen on device). The web "Edit profile" form data
      // is the web client's own source for the logged-in username.
      if (r case Err(failure: UnknownFailure())) {
        _log?.log(LogLevel.info, 'direct', 'op=verifySession web_form_data');
        r = await _webFormViewer(own, call);
      }
    }
    switch (r) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.viewerId != own) {
          return const Err(SessionInvalid(SessionReason.loginRequired));
        }
        final profile = value.profile;
        if (profile != null) return _rememberResult(Ok(profile));
        return _rememberResult(await transport.userById(own, call));
    }
  });

  /// The viewer from `accounts/edit/web_form_data`: `form_data.username`
  /// and `first_name`; the id is the session's own `ds_user_id`.
  Future<Result<Viewer>> _webFormViewer(String own, IgCall call) async {
    if (own.isEmpty) {
      return const Err(SessionInvalid(SessionReason.loginRequired));
    }
    final reply = await call(RestRequests.webFormData());
    switch (reply) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final form = value['form_data'];
        final username = form is Map<String, Object?> ? form['username'] : null;
        if (username is! String || username.isEmpty) {
          return const Err(SchemaChanged('form_data.username'));
        }
        final name = form is Map<String, Object?> ? form['first_name'] : null;
        return Ok(
          Viewer(
            viewerId: own,
            profile: UserProfile(
              user: RemoteUser(
                remoteUserId: own,
                username: username,
                displayName: name is String && name.isNotEmpty ? name : null,
                followedByViewer: false,
                blockedByViewer: false,
              ),
            ),
          ),
        );
    }
  }

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
        await _rememberResult(r);
        return r.map((p) => p.latestReelMedia);
      });

  // ----------------------------------------------------------------- posts

  /// Posts of [userId] published after [watermark] (by `taken_at`, so the
  /// pinned-first order does not matter), newest first, one entry per post.
  ///
  /// Only the first page is read (12 posts, ADR-0010). Collab posts that list
  /// the user in `coauthor_producers` count. A pinned post has
  /// `extras['pinned'] == true` (pinned by any user). Posts that are not
  /// newer are not mapped, so a malformed old post cannot fail the run; an
  /// edge without a usable `pk` or `taken_at` is skipped and counted in the
  /// log, and the page fails only if every edge is malformed. Costs 1 call
  /// when the username is cached, else 2.
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  ) => _op('fetchNewPosts', (call) async {
    final r = await transport.timeline(
      userId,
      call,
      usernameHint: await _usernameOf(userId),
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
        await _cacheUsername(userId, value.usernameUsed);
        _logSkipped('fetchNewPosts', value.skippedMalformed);
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
  /// downloaded later as "new". Costs 1 call when the username is cached,
  /// else 2.
  Future<Result<DateTime?>> latestPostTime(String userId) =>
      _op('latestPostTime', (call) async {
        final r = await transport.timeline(
          userId,
          call,
          usernameHint: await _usernameOf(userId),
        );
        if (r is Ok<Timeline>) {
          await _cacheUsername(userId, r.value.usernameUsed);
          _logSkipped('latestPostTime', r.value.skippedMalformed);
        }
        return r.map((t) {
          DateTime? latest;
          for (final e in t.entries) {
            if (!e.belongsTo(userId)) continue;
            if (latest == null || e.takenAt.isAfter(latest)) latest = e.takenAt;
          }
          return latest;
        });
      });

  /// One page of the posts of [userId], newest first (FR-68). [cursor] is the
  /// `nextCursor` of the previous page; null is the first page.
  ///
  /// Reads `page_info`: a page that does not say whether more follows is
  /// `SchemaChanged` (ending silently would cut the history short). A cursor
  /// made by page mode (no Instagram cursor in it) is `SchemaChanged`, which
  /// lets the platform continue in page mode. The next cursor holds the
  /// oldest unpinned `taken_at` of the page. Costs 1 call when the username
  /// is cached, else 2.
  Future<Result<PostPage>> fetchPostPage(String userId, {String? cursor}) =>
      _op('fetchPostPage', (call) async {
        String? igCursor;
        PostCursor? parsed;
        if (cursor != null) {
          parsed = PostCursor.parse(cursor);
          if (parsed == null) {
            return const Err(UnknownFailure(null, 'bad_cursor'));
          }
          if (parsed.igCursor.isEmpty) {
            return const Err(SchemaChanged('cursor_from_page_mode'));
          }
          igCursor = parsed.igCursor;
        }
        final r = await transport.timelinePage(
          userId,
          call,
          cursor: igCursor,
          usernameHint: await _usernameOf(userId),
        );
        switch (r) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            await _cacheUsername(userId, value.usernameUsed);
            _logSkipped('fetchPostPage', value.skippedMalformed);
            final hasNext = value.hasNextPage;
            if (hasNext == null) {
              return const Err(SchemaChanged('page_info.has_next_page'));
            }
            final end = value.endCursor;
            if (hasNext && end == null) {
              return const Err(SchemaChanged('page_info.end_cursor'));
            }
            final seen = <String>{};
            final mine = [
              for (final e in value.entries)
                if (e.belongsTo(userId) && seen.add(e.pk)) e,
            ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
            DateTime? oldest;
            for (final e in mine) {
              if (e.pinned) continue;
              if (oldest == null || e.takenAt.isBefore(oldest)) {
                oldest = e.takenAt;
              }
            }
            oldest ??= mine.isEmpty ? null : mine.last.takenAt;
            oldest ??=
                parsed?.takenAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
            return guardMapping(
              () => PostPage(
                items: [
                  for (final e in mine)
                    _media.post(
                      e.node,
                      pinned: e.pinned,
                      collab: e.isCollabOf(userId),
                    ),
                ],
                nextCursor: hasNext
                    ? PostCursor(takenAt: oldest!, igCursor: end!).encode()
                    : null,
              ),
            );
        }
      });

  // ------------------------------------------------------------ highlights

  /// The highlights tray of [userId], in tray order (FR-71). One call.
  Future<Result<List<RemoteHighlight>>> fetchHighlights(String userId) =>
      _op('fetchHighlights', (call) => transport.highlights(userId, call));

  /// The items of the highlights [highlightIds], in chunks of at most
  /// [storyChunkSize]; keyed by highlight id. [orderStart] is added to each
  /// `highlightOrder`. Any failing chunk fails the call.
  Future<Result<Map<String, List<RemoteContent>>>> fetchHighlightItems(
    List<String> highlightIds, {
    int orderStart = 0,
  }) => _op('fetchHighlightItems', (call) async {
    final ids = {
      for (final id in highlightIds)
        if (id.trim().isNotEmpty) id.trim(),
    }.toList();
    final out = <String, List<RemoteContent>>{};
    for (var i = 0; i < ids.length; i += storyChunkSize) {
      final chunk = ids.sublist(i, min(i + storyChunkSize, ids.length));
      final r = await transport.highlightItems(chunk, call);
      switch (r) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          for (final e in value.entries) {
            out[e.key] = [
              for (final c in e.value)
                withHighlightOrder(c, orderStart + ids.indexOf(e.key)),
            ];
          }
      }
    }
    return Ok(out);
  });

  // --------------------------------------------------------------- plumbing

  /// Remembers the username of a successful profile and returns the user.
  Future<Result<RemoteUser>> _rememberResult(Result<UserProfile> result) async {
    if (result is Ok<UserProfile>) {
      final user = result.value.user;
      await _cacheUsername(user.remoteUserId, user.username);
    }
    return result.map((p) => p.user);
  }

  /// A cache that fails must not fail the operation.
  Future<String?> _usernameOf(String userId) async {
    try {
      return await _usernames.usernameOf(userId);
    } on Object {
      return null;
    }
  }

  Future<void> _cacheUsername(String userId, String? username) async {
    if (username == null) return;
    try {
      await _usernames.remember(userId, username);
    } on Object {
      // Only an optimisation.
    }
  }

  void _logSkipped(String op, int skipped) {
    if (skipped > 0) {
      _log?.log(LogLevel.warn, 'direct', 'op=$op skipped_malformed=$skipped');
    }
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
      } on Object catch (error) {
        // A resolver, a cache or a transport that throws: no Result contract
        // breach, and only the type is logged.
        _log?.log(
          LogLevel.warn,
          'direct',
          'op=$name unexpected_error type=${error.runtimeType}',
        );
        return const Err(UnknownFailure(null, 'unexpected_error'));
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
    } on Object catch (error) {
      // Never rethrow: the extractor returns a Result. Only the type is
      // logged, because the text of an exception can carry a request value.
      _log?.log(
        LogLevel.warn,
        'direct',
        'unexpected_error type=${error.runtimeType}',
      );
      return const Err(UnknownFailure(null, 'unexpected_error'));
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
