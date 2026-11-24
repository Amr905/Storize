import 'package:meta/meta.dart';
import 'package:storize_domain/src/entities/target.dart';
import 'package:storize_domain/src/entities/target_limits.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/ports/clock.dart';
import 'package:storize_domain/src/ports/content_platform.dart';
import 'package:storize_domain/src/ports/scheduler.dart';
import 'package:storize_domain/src/repos/target_repo.dart';
import 'package:storize_model/storize_model.dart';

/// Why a target cannot be seen (BR-2, EC-4).
enum NotVisibleReason {
  /// The account is private and the login does not follow it.
  privateNotFollowed,

  /// The account blocked the login.
  blocked,
}

/// The outcome of [AddTarget] (TECH_SPEC §4.3). Exhaustive with `switch`.
@immutable
sealed class AddTargetResult {
  const AddTargetResult();
}

/// The target was stored.
final class AddTargetAdded extends AddTargetResult {
  /// Creates the result.
  const AddTargetAdded({
    required this.target,
    required this.overLimitWarning,
    required this.firstCheckScheduled,
    this.schedulerError,
  });

  /// The stored target, with its ID.
  final Target target;

  /// True when the user already tracked [TargetLimits.recommendedMax] or more
  /// targets (A-12, NFR-4). A warning only.
  final bool overLimitWarning;

  /// Whether the first check was enqueued. False when the scheduler failed;
  /// the target is stored anyway.
  final bool firstCheckScheduled;

  /// The runtime type name of the scheduler error, or null. No message, so
  /// nothing sensitive can leak.
  final String? schedulerError;

  @override
  String toString() =>
      'AddTargetAdded(id: ${target.id}, overLimit: $overLimitWarning, '
      'firstCheckScheduled: $firstCheckScheduled)';
}

/// The target was saved as "waiting to look up" because Instagram asked us
/// to slow down or the network failed (FR-73). It is looked up later by
/// `ResolvePendingTargets`.
final class AddTargetPending extends AddTargetResult {
  /// Creates the result.
  const AddTargetPending({
    required this.target,
    required this.overLimitWarning,
    this.schedulerError,
  });

  /// The stored target (status pending lookup).
  final Target target;

  /// Same meaning as [AddTargetAdded.overLimitWarning].
  final bool overLimitWarning;

  /// The runtime type name of the scheduler error, or null.
  final String? schedulerError;

  @override
  String toString() => 'AddTargetPending(id: ${target.id})';
}

/// The input is not a valid username or profile link (S-08).
final class AddTargetInvalidUsername extends AddTargetResult {
  /// Creates the result.
  const AddTargetInvalidUsername();
}

/// No category was chosen (BR-1).
final class AddTargetMissingCategory extends AddTargetResult {
  /// Creates the result.
  const AddTargetMissingCategory();
}

/// Every track flag is off (FR-65, FR-67).
final class AddTargetNoTrackFlag extends AddTargetResult {
  /// Creates the result.
  const AddTargetNoTrackFlag();
}

/// The note is longer than [Target.maxNoteLength] (FR-16).
final class AddTargetNoteTooLong extends AddTargetResult {
  /// Creates the result.
  const AddTargetNoteTooLong();
}

/// The account does not exist.
final class AddTargetNotFound extends AddTargetResult {
  /// Creates the result.
  const AddTargetNotFound();
}

/// The account exists but cannot be seen (BR-2, EC-4).
final class AddTargetNotVisible extends AddTargetResult {
  /// Creates the result.
  const AddTargetNotVisible(this.reason);

  /// Why it cannot be seen.
  final NotVisibleReason reason;
}

/// The account is already tracked, matched by user ID (EC-16, EC-5).
final class AddTargetDuplicate extends AddTargetResult {
  /// Creates the result.
  const AddTargetDuplicate({
    required this.existingId,
    required this.existingUsername,
  });

  /// The ID of the stored target.
  final int existingId;

  /// The username stored for it (may differ from what the user typed).
  final String existingUsername;
}

/// The session is not usable; the user must log in again (BR-7).
final class AddTargetSessionNotActive extends AddTargetResult {
  /// Creates the result.
  const AddTargetSessionNotActive(this.reason);

  /// Login required or challenge.
  final SessionReason reason;
}

/// The login account is restricted by Instagram (EC-6).
final class AddTargetAccountRestricted extends AddTargetResult {
  /// Creates the result.
  const AddTargetAccountRestricted();
}

/// Instagram asked us to slow down.
final class AddTargetRateLimited extends AddTargetResult {
  /// Creates the result.
  const AddTargetRateLimited(this.retryAfter);

  /// The server hint, if any.
  final Duration? retryAfter;
}

/// The network failed.
final class AddTargetNetwork extends AddTargetResult {
  /// Creates the result.
  const AddTargetNetwork();
}

/// Instagram's response changed shape (EC-14).
final class AddTargetSchemaChanged extends AddTargetResult {
  /// Creates the result.
  const AddTargetSchemaChanged(this.where);

  /// Where the unexpected response was found.
  final String where;
}

/// Any other failure.
final class AddTargetUnknown extends AddTargetResult {
  /// Creates the result.
  const AddTargetUnknown({this.code, this.message});

  /// The HTTP status code, if any.
  final int? code;

  /// A short diagnostic message.
  final String? message;
}

/// Adds a tracked account (FR-10…FR-16, FR-63, FR-65, FR-67, BR-1, BR-2,
/// EC-16).
///
/// Steps: validate the input locally (no network), reject a known username,
/// resolve the user (a rate limit or network failure saves a pending target
/// instead, FR-73), check visibility and duplicates (by user ID), store with
/// `posts_watermark_at` at the start of today (device local time), then
/// enqueue a first check. A scheduler error never undoes the add. Posts from
/// before today are not downloaded (FR-63).
final class AddTarget {
  /// Creates the use case.
  AddTarget({
    required this._platform,
    required this._targets,
    required this._scheduler,
    required this._clock,
  });

  final ContentPlatform _platform;
  final TargetRepo _targets;
  final Scheduler _scheduler;
  final Clock _clock;

  static const int _maxUsernameLength = 30;
  static final RegExp _usernameRegex = RegExp(
    r'^(?!\.)(?!.*\.\.)(?!.*\.$)[a-z0-9._]{1,30}$',
  );
  static final RegExp _scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*://');
  static final RegExp _host = RegExp(
    r'^(?:www\.|m\.)?instagram\.com(?=[/?#]|$)',
    caseSensitive: false,
  );

  /// Page names that are not profiles. `stories/<name>` is handled apart.
  static const Set<String> _reservedPaths = {
    'p',
    'reel',
    'reels',
    'tv',
    'explore',
    'accounts',
    'direct',
    'about',
    'developer',
    'legal',
  };

  /// Turns [raw] into a canonical username, or null when it is invalid.
  ///
  /// Accepts `name`, `@name` and `instagram.com/name` (any scheme, `www.` or
  /// `m.` host, trailing path, query or fragment). The result is lower case
  /// and matches `a-z 0-9 . _`, 1 to 30 characters, no leading or trailing
  /// dot, no `..` (UX S-08). Pure; usable for inline validation.
  static String? normalizeUsername(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    final hadScheme = _scheme.hasMatch(s);
    if (hadScheme) s = s.replaceFirst(_scheme, '');
    final hostMatch = _host.firstMatch(s);
    String candidate;
    if (hostMatch != null) {
      var rest = s.substring(hostMatch.end);
      final cut = rest.indexOf(RegExp('[?#]'));
      if (cut >= 0) rest = rest.substring(0, cut);
      final segments = rest.split('/').where((e) => e.isNotEmpty).toList();
      if (segments.isEmpty) return null;
      var first = segments.first.toLowerCase();
      if (first == 'stories' && segments.length > 1) first = segments[1];
      if (_reservedPaths.contains(first.toLowerCase()) ||
          first.toLowerCase() == 'stories') {
        return null;
      }
      candidate = first;
    } else if (hadScheme) {
      return null; // another host
    } else {
      candidate = s.startsWith('@') ? s.substring(1) : s;
    }
    final lower = _asciiLower(candidate);
    if (lower.length > _maxUsernameLength) return null;
    return _usernameRegex.hasMatch(lower) ? lower : null;
  }

  /// Lower-cases only ASCII letters, so look-alikes such as the Kelvin sign
  /// stay non-ASCII and fail the regex.
  static String _asciiLower(String s) => String.fromCharCodes(
    s.codeUnits.map((c) => c >= 0x41 && c <= 0x5A ? c + 0x20 : c),
  );

  /// The placeholder `remoteUserId` of a pending target (FR-73). The column
  /// is UNIQUE, so it carries the username; the real ID replaces it when the
  /// lookup succeeds. Never sent to Instagram.
  static String pendingRemoteUserId(String username) => 'pending:$username';

  /// Adds the account typed as [raw].
  ///
  /// [historyRange], [historySince] and [highlights] are kept on a pending
  /// target only; a normal add leaves them to the caller (S-08).
  Future<AddTargetResult> call(
    String raw, {
    required TargetCategory? category,
    bool trackStories = true,
    bool trackPosts = true,
    bool trackReels = true,
    String? note,
    HistoryRange historyRange = HistoryRange.none,
    DateTime? historySince,
    bool highlights = false,
  }) async {
    final username = normalizeUsername(raw);
    if (username == null) return const AddTargetInvalidUsername();
    if (category == null) return const AddTargetMissingCategory();
    if (!(trackStories || trackPosts || trackReels)) {
      return const AddTargetNoTrackFlag();
    }
    final cleanNote = note?.trim();
    if (cleanNote != null && cleanNote.length > Target.maxNoteLength) {
      return const AddTargetNoteTooLong();
    }

    final platformId = _platform.id;
    final all = await _targets.watchAll().first;
    for (final t in all) {
      if (t.platform == platformId && _asciiLower(t.username) == username) {
        return _duplicate(t);
      }
    }

    // FR-73: the add never waits for Instagram. The watermark is the start
    // of today in device local time (FR-63, D-17); no network call is needed
    // (TECH_SPEC 17.4).
    final now = _clock.now();
    final local = now.toLocal();
    final watermark = DateTime(local.year, local.month, local.day).toUtc();
    final storedNote = (cleanNote == null || cleanNote.isEmpty)
        ? null
        : cleanNote;

    final resolved = await _platform.resolveUser(username);
    final RemoteUser user;
    switch (resolved) {
      case Ok(:final value):
        user = value;
      case Err(failure: RateLimited() || NetworkFailure()):
        return _addPending(
          Target(
            id: Target.unsavedId,
            platform: platformId,
            remoteUserId: pendingRemoteUserId(username),
            username: username,
            category: category,
            note: storedNote,
            status: TargetStatus.pendingLookup,
            trackStories: trackStories,
            trackPosts: trackPosts,
            trackReels: trackReels,
            postsWatermarkAt: watermark,
            addedAt: now,
            historyRange: historyRange,
            historySince: historyRange == HistoryRange.since
                ? historySince?.toUtc()
                : null,
            highlightsEnabled: highlights,
          ),
          count: all.length,
        );
      case Err(:final failure):
        return _fromFailure(failure);
    }

    if (user.blockedByViewer) {
      return const AddTargetNotVisible(NotVisibleReason.blocked);
    }
    if (user.isPrivate && !user.followedByViewer) {
      return const AddTargetNotVisible(NotVisibleReason.privateNotFollowed);
    }

    final existing = await _targets.getByRemoteUserId(
      platformId,
      user.remoteUserId,
    );
    if (existing != null) return _duplicate(existing);

    // A-12: the warning counts targets before this one.
    final count = all.length;

    final Target stored;
    try {
      stored = await _targets.insert(
        Target(
          id: Target.unsavedId,
          platform: platformId,
          remoteUserId: user.remoteUserId,
          username: user.username,
          displayName: user.displayName,
          category: category,
          note: storedNote,
          isPrivate: user.isPrivate,
          trackStories: trackStories,
          trackPosts: trackPosts,
          trackReels: trackReels,
          postsWatermarkAt: watermark,
          addedAt: now,
        ),
      );
    } on DuplicateEntityException {
      final winner = await _targets.getByRemoteUserId(
        platformId,
        user.remoteUserId,
      );
      if (winner != null) return _duplicate(winner);
      rethrow;
    }

    var scheduled = true;
    String? schedulerError;
    try {
      await _scheduler.checkNow(targetId: stored.id);
    } on Object catch (e) {
      scheduled = false;
      schedulerError = e.runtimeType.toString();
    }

    return AddTargetAdded(
      target: stored,
      overLimitWarning: count >= TargetLimits.recommendedMax,
      firstCheckScheduled: scheduled,
      schedulerError: schedulerError,
    );
  }

  /// Stores [pending] and asks for a soon lookup. A scheduler error never
  /// undoes the add.
  Future<AddTargetResult> _addPending(
    Target pending, {
    required int count,
  }) async {
    final Target stored;
    try {
      stored = await _targets.insert(pending);
    } on DuplicateEntityException {
      final winner = await _targets.getByRemoteUserId(
        pending.platform,
        pending.remoteUserId,
      );
      if (winner != null) return _duplicate(winner);
      rethrow;
    }
    String? schedulerError;
    try {
      await _scheduler.checkNow(scope: CheckScope.posts, targetId: stored.id);
    } on Object catch (e) {
      schedulerError = e.runtimeType.toString();
    }
    return AddTargetPending(
      target: stored,
      overLimitWarning: count >= TargetLimits.recommendedMax,
      schedulerError: schedulerError,
    );
  }

  AddTargetDuplicate _duplicate(Target t) =>
      AddTargetDuplicate(existingId: t.id, existingUsername: t.username);

  AddTargetResult _fromFailure(Failure failure) => switch (failure) {
    TargetNotFound() => const AddTargetNotFound(),
    TargetNotVisible() => const AddTargetNotVisible(
      NotVisibleReason.privateNotFollowed,
    ),
    SessionInvalid(:final reason) => AddTargetSessionNotActive(reason),
    AccountRestricted() => const AddTargetAccountRestricted(),
    RateLimited(:final retryAfter) => AddTargetRateLimited(retryAfter),
    NetworkFailure() => const AddTargetNetwork(),
    SchemaChanged(:final where) => AddTargetSchemaChanged(where),
    // The platform resolved a different account than asked (T-013).
    UnknownFailure(message: 'username_mismatch') => const AddTargetNotFound(),
    UnknownFailure(:final code, :final message) => AddTargetUnknown(
      code: code,
      message: message,
    ),
  };
}
