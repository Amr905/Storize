import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/page/discovery_store.dart';
import 'package:storize_model/storize_model.dart';

/// Loads the profile of [username] for [accountId] in page mode, so the
/// page's `doc_id`s and tokens reach the shared `PageDiscovery`.
typedef DiscoveryLoad = Future<Result<RemoteUser>> Function(
  int accountId,
  String username,
);

/// When the newest story of [remoteUserId] was posted, as the profile page
/// just loaded showed it (no request), or null when it showed none (T-047).
typedef ProfileStoryTime = DateTime? Function(
  int accountId,
  String remoteUserId,
);

/// One governed page-mode stories load of [target] (through the platform's
/// `fetchStories`, so the SeenGuard and the seen block apply), which lets the
/// stories page's `doc_id` reach the shared discovery (T-047).
typedef DiscoveryStoriesLoad = Future<Result<Object?>> Function(
  int accountId,
  Target target,
);

/// What one [DiscoveryRefresher.refresh] did.
enum DiscoveryRefreshOutcome {
  /// No active account.
  noAccount,

  /// The stored discovery is younger than the interval.
  fresh,

  /// A load was started less than the interval ago (it may have failed).
  throttled,

  /// The governor is paused for the account: nothing was loaded.
  paused,

  /// Nothing to load a profile of (no target and no own username).
  nothingToLoad,

  /// One page load ran (its result is logged by type).
  loaded,

  /// A refresh is already running.
  busy,
}

/// Refills the persisted discovery of the logged-in account from the
/// foreground (T-045).
///
/// Background isolates never load pages, so without this they would have no
/// `doc_id`s and fall back to page mode (refused) on every run. In the
/// foreground, at app start and on resume, [refresh] does **one** governed
/// page-mode profile load per account when its stored discovery is missing,
/// incomplete or older than [interval]. It is skipped while the governor is
/// paused for the account, and it never loads more than once per [interval]
/// per account in this isolate (a failed load counts: no retry storm).
///
/// The page load itself is governed (`RequestCost.pageLoad`) by the platform
/// behind [load]; the refresher sends nothing else. It logs outcomes by
/// type only: no username, id, token or URL.
final class DiscoveryRefresher {
  /// Creates the refresher.
  DiscoveryRefresher({
    required this.accounts,
    required this.targets,
    required this.store,
    required this.governor,
    required this.load,
    required this.clock,
    this.log,
    this.profileStoryTime,
    this.loadStories,
    this.interval = const Duration(hours: 6),
    this.maxWait = const Duration(seconds: 8),
    this.tokenLife = const Duration(hours: 12),
  });

  /// Where the active account comes from.
  final AccountRepo accounts;

  /// Where a tracked profile to load comes from.
  final TargetRepo targets;

  /// The persisted discovery.
  final DiscoveryStore store;

  /// The request governor (pause check and bounded wait).
  final RequestGovernor governor;

  /// The page-mode profile load.
  final DiscoveryLoad load;

  /// The clock.
  final Clock clock;

  /// The diagnostic log, or null.
  final DiagnosticLog? log;

  /// What the last profile load showed of a user's story, or null (then no
  /// extra stories load is made).
  final ProfileStoryTime? profileStoryTime;

  /// The one extra stories load, or null (then none is made). It runs only
  /// for a tracked target whose profile showed a story newer than 24 h, only
  /// after a successful profile load, and inside the same [interval]
  /// throttle: never more than once per refresh.
  final DiscoveryStoriesLoad? loadStories;

  /// The refresh period: stored discovery older than this is refilled.
  final Duration interval;

  /// How long stored tokens stay usable (the persisted token lifetime).
  final Duration tokenLife;

  /// The longest a load may wait for the request budget.
  final Duration maxWait;

  final Map<int, DateTime> _lastAttempt = {};
  bool _running = false;

  /// Refreshes the discovery of the active account if it needs it.
  Future<DiscoveryRefreshOutcome> refresh() async {
    if (_running) return DiscoveryRefreshOutcome.busy;
    _running = true;
    try {
      return await _refresh();
    } on Object catch (error) {
      log?.log(
        LogLevel.warn,
        'discovery',
        'refresh_failed type=${error.runtimeType}',
      );
      return DiscoveryRefreshOutcome.nothingToLoad;
    } finally {
      _running = false;
    }
  }

  Future<DiscoveryRefreshOutcome> _refresh() async {
    final account = await accounts.getActive();
    if (account == null || account.status != AccountStatus.active) {
      return DiscoveryRefreshOutcome.noAccount;
    }
    final id = account.id;
    final now = clock.now();
    final attempts = store is DiscoveryAttemptStore
        ? store as DiscoveryAttemptStore
        : null;
    var last = _lastAttempt[id];
    if (last == null && attempts != null) {
      // Another process (or an earlier start) may have tried: not secret, and
      // it stops a failing load from repeating at every app start.
      try {
        last = await attempts.lastAttempt(id);
      } on Object {
        last = null;
      }
    }
    if (last != null && now.difference(last) < interval) {
      return DiscoveryRefreshOutcome.throttled;
    }
    final snap = await store.load(id);
    DateTime? newestDocId;
    if (snap != null) {
      for (final e in snap.docIds.values) {
        if (newestDocId == null || e.at.isAfter(newestDocId)) {
          newestDocId = e.at;
        }
      }
    }
    final tokensAt = snap?.tokensAt;
    // Expired tokens are as good as none: background GraphQL needs them.
    final complete =
        newestDocId != null &&
        snap?.tokens != null &&
        tokensAt != null &&
        now.difference(tokensAt) < tokenLife;
    if (complete && now.difference(newestDocId) < interval) {
      return DiscoveryRefreshOutcome.fresh;
    }
    if (await governor.isPaused(id)) {
      log?.log(LogLevel.info, 'discovery', 'refresh_skipped reason=paused');
      return DiscoveryRefreshOutcome.paused;
    }
    final username = await _usernameToLoad(account);
    if (username == null) return DiscoveryRefreshOutcome.nothingToLoad;

    _lastAttempt[id] = now;
    if (attempts != null) {
      try {
        await attempts.markAttempt(id, now);
      } on Object {
        // Memory still throttles this process.
      }
    }
    final result = await RequestGovernor.withMaxWait(
      maxWait,
      () => load(id, username),
    );
    final failure = result.failureOrNull;
    final outcome = failure == null ? 'ok' : 'failure=${failure.runtimeType}';
    log?.log(LogLevel.info, 'discovery', 'refresh_done $outcome');
    final user = result.valueOrNull;
    if (user != null) await _extraStories(id, user, now);
    await _logState(id);
    return DiscoveryRefreshOutcome.loaded;
  }

  /// The extra stories load: a profile page does not necessarily run the
  /// stories query, so its `doc_id` may be missing. Only for a tracked target
  /// with a current story; otherwise nothing is sent.
  Future<void> _extraStories(int id, RemoteUser user, DateTime now) async {
    final load = loadStories;
    final storyTime = profileStoryTime;
    if (load == null || storyTime == null) return;
    final at = storyTime(id, user.remoteUserId);
    if (at == null || now.difference(at) >= const Duration(hours: 24)) return;
    Target? target;
    for (final t in await targets.listActive(CheckScope.all)) {
      if (t.remoteUserId == user.remoteUserId && t.trackStories) {
        target = t;
        break;
      }
    }
    if (target == null) return;
    if (await governor.isPaused(id)) return;
    final r = await RequestGovernor.withMaxWait(
      maxWait,
      () => load(id, target!),
    );
    final f = r.failureOrNull;
    log?.log(
      LogLevel.info,
      'discovery',
      'stories_load ${f == null ? 'ok' : 'failure=${f.runtimeType}'}',
    );
  }

  /// Which queries have a doc_id and whether tokens exist, by name only.
  Future<void> _logState(int id) async {
    try {
      final snap = await store.load(id);
      final names = [
        for (final q in GraphqlQuery.values)
          if (snap?.docIds.containsKey(q.name) ?? false) q.name,
      ];
      log?.log(
        LogLevel.info,
        'discovery',
        'state doc_ids=${names.join(',')} '
            'missing=${[
              for (final q in GraphqlQuery.values)
                if (!names.contains(q.name)) q.name,
            ].join(',')} tokens=${snap?.tokens != null}',
      );
    } on Object catch (error) {
      log?.log(
        LogLevel.warn,
        'discovery',
        'state_failed type=${error.runtimeType}',
      );
    }
  }

  /// A tracked profile (its page shows the story and post queries), else the
  /// account's own.
  Future<String?> _usernameToLoad(LoginAccount account) async {
    final active = await targets.listActive(CheckScope.all);
    for (final t in active) {
      if (t.username.isNotEmpty) return t.username;
    }
    return account.username.isEmpty ? null : account.username;
  }
}
