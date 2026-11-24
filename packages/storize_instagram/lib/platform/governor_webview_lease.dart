import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/page/page_driver.dart';
import 'package:storize_instagram/page/webview_lease.dart';

/// Creates the periodic timer that renews a held lease.
typedef LeaseTicker = Timer Function(Duration interval, void Function() tick);

Timer _periodic(Duration interval, void Function() tick) =>
    Timer.periodic(interval, (_) => tick());

/// A [WebViewLease] shared by every isolate, built on [GovernorLeaseRepo]
/// (T-014 R2-F2, R2-F3; ADR-0003 addendum).
///
/// The WebView cookie jar is app-wide, and page mode wipes it. So page mode
/// (`page_mode:<account>`) and the S-02 login WebView must never overlap, in
/// the same isolate or in another one. This adapter stores the lease in the
/// `governor_lease` table under the **reserved account id** [reservedAccountId]
/// (-1): no real login account has that id, and the table has no foreign key
/// to `login_account`, so the row cannot collide with a governor lease.
///
/// - **Holder** is `instanceId` (unique per isolate, for example the
///   governor's holder id), not the owner name: two isolates would otherwise
///   both be `page_mode:1` and the repo would let both in. Different owners in
///   one isolate exclude each other here.
/// - **TTL and renewal.** The row lives [ttl] (default 2 min) and a timer
///   renews it every [renewEvery] while it is held, so a crashed process frees
///   it by itself and a healthy long holder (S-02 login) keeps it. If a renewal
///   finds the row lost, it re-acquires; if that fails the loss is logged.
/// - **`tryAcquire` never waits longer than [acquireTimeout]** (default 3 s,
///   which must stay below the page extractor's 5 s `cleanupTimeout`). If the
///   repo answers after that with a lease nobody here asked for any more, the
///   lease is released at once (R2-F3): a late `true` is never leaked.
/// - **Holds (R2-F2).** [beginHold] keeps the lease alive after the owner
///   released it, for work that is still running behind the owner's back: a
///   WebView whose `open` finished after `page_open_timeout`. Use
///   [LeaseHoldingPageDriver]. While a hold is live no owner can acquire. A
///   hold ends when released, or after [maxHold] at the latest.
///
/// S-02 (T-026) calls `tryAcquire('login')` when its WebView opens and
/// `release('login')` when it closes; the renewal keeps the row alive in
/// between.
final class GovernorWebViewLease implements WebViewLease {
  /// Creates the lease over `repo`.
  GovernorWebViewLease({
    required this._repo,
    required this._clock,
    required this.instanceId,
    this.ttl = const Duration(minutes: 2),
    Duration? renewEvery,
    this.acquireTimeout = const Duration(seconds: 3),
    this.maxHold = const Duration(seconds: 60),
    this._log,
    this._ticker = _periodic,
  }) : renewEvery =
           renewEvery ?? Duration(milliseconds: ttl.inMilliseconds ~/ 3);

  /// The `governor_lease` key of the WebView lease. Governor leases use real
  /// (non-negative) login account ids.
  static const int reservedAccountId = -1;

  /// Names this isolate in the lease row. Unique per isolate.
  final String instanceId;

  /// How long a lease row lives without renewal.
  final Duration ttl;

  /// How often a held lease is renewed.
  final Duration renewEvery;

  /// The longest `tryAcquire` waits for the repo.
  final Duration acquireTimeout;

  /// The longest a hold keeps the lease after its owner released it.
  final Duration maxHold;

  final GovernorLeaseRepo _repo;
  final Clock _clock;
  final DiagnosticLog? _log;
  final LeaseTicker _ticker;

  final Set<String> _owners = {};
  final Set<_Hold> _holds = {};
  bool _held = false;
  bool _acquiring = false;
  bool _ticking = false;
  Timer? _timer;
  int _generation = 0;
  DateTime? _lastRenewedAt;
  final StreamController<void> _lost = StreamController<void>.broadcast();

  /// Whether this isolate currently holds the row (owner or hold). False at
  /// once after a detected loss.
  bool get isHeld => _held;

  /// Fires once each time the lease is **lost** while it was held (T-015a F2):
  /// a renewal found the row gone and it could not be taken back, or renewals
  /// kept failing for [ttl] so the row has expired and another isolate may
  /// own it. S-02 (T-026) listens and closes its login WebView, because page
  /// mode in another isolate may now wipe the app-wide cookie jar.
  ///
  /// At that moment [isHeld] is already false, every owner and hold of this
  /// isolate has been dropped (a stale owner never blocks the others) and the
  /// renewal timer is stopped. [tryAcquire] then really asks the repo again.
  /// A broadcast stream: subscribe before you acquire.
  Stream<void> get onLost => _lost.stream;

  /// Why the last [tryAcquire] returned false, or null after a success. A
  /// short code for diagnostics (`held_by_other`, `busy_here`,
  /// `acquire_timeout`, `acquire_failed type=...`); no ids or values.
  String? get lastFailure => _lastFailure;
  String? _lastFailure;

  /// The owners that hold the lease in this isolate.
  Set<String> get owners => Set.unmodifiable(_owners);

  int get _liveHolds {
    final now = _clock.now();
    _holds.removeWhere((h) => !h.expiresAt.isAfter(now));
    return _holds.length;
  }

  GovernorBucket get _emptyBucket =>
      GovernorBucket(tokens: 0, lastRefillAt: _clock.now());

  @override
  Future<bool> tryAcquire(String owner) async {
    if (_held && _owners.contains(owner)) {
      _lastFailure = null;
      return true;
    }
    if (_owners.isNotEmpty || _liveHolds > 0 || _acquiring) {
      _lastFailure = 'busy_here';
      return false;
    }
    _acquiring = true;
    // F5: a later attempt makes the late answer of an earlier one irrelevant.
    final generation = ++_generation;
    final attempt = _repo.acquire(
      accountId: reservedAccountId,
      holder: instanceId,
      ttl: ttl,
      initialBucket: _emptyBucket,
    );
    try {
      final lease = await attempt.timeout(acquireTimeout);
      if (lease == null) {
        _lastFailure = 'held_by_other';
        return false;
      }
      _lastFailure = null;
      _owners.add(owner);
      _held = true;
      _lastRenewedAt = _clock.now();
      _startTimer();
      return true;
    } on TimeoutException {
      // The answer may still arrive. If it is a lease and nobody here holds
      // the row by then, give it back (R2-F3).
      unawaited(
        attempt.then<void>((late) async {
          // Only the newest attempt may give the row back: an older late
          // answer must not release what a newer attempt just won (F5).
          if (late != null &&
              generation == _generation &&
              !_acquiring &&
              _owners.isEmpty &&
              _liveHolds == 0) {
            await _releaseRow();
          }
        }, onError: (Object _) {}),
      );
      _log?.log(LogLevel.warn, 'webview_lease', 'acquire_timeout');
      _lastFailure = 'acquire_timeout';
      return false;
    } on Object catch (error) {
      _log?.log(
        LogLevel.warn,
        'webview_lease',
        'acquire_failed type=${error.runtimeType}',
      );
      _lastFailure = 'acquire_failed type=${error.runtimeType}';
      return false;
    } finally {
      _acquiring = false;
    }
  }

  @override
  Future<void> release(String owner) async {
    if (!_owners.remove(owner)) return;
    await _releaseIfIdle();
  }

  /// Keeps the lease alive for work that outlives its owner (R2-F2). Returns a
  /// no-op hold when the lease is not held. Call [LeaseHold.release] when the
  /// work has ended; the hold lapses by itself after [maxHold].
  LeaseHold beginHold() {
    if (!_held) return const _NoHold();
    final hold = _Hold(this, _clock.now().add(maxHold));
    _holds.add(hold);
    return hold;
  }

  void _endHold(_Hold hold) {
    if (_holds.remove(hold)) unawaited(_releaseIfIdle());
  }

  Future<void> _releaseIfIdle() async {
    if (_owners.isNotEmpty || _liveHolds > 0 || !_held) return;
    await _releaseRow();
  }

  Future<void> _releaseRow() async {
    _lastRenewedAt = null;
    _timer?.cancel();
    _timer = null;
    _held = false;
    try {
      await _repo
          .release(accountId: reservedAccountId, holder: instanceId)
          .timeout(acquireTimeout);
    } on Object catch (error) {
      // The row then expires by its TTL.
      _log?.log(
        LogLevel.warn,
        'webview_lease',
        'release_failed type=${error.runtimeType}',
      );
    }
  }

  void _declareLost() {
    _held = false;
    _owners.clear();
    _holds.clear();
    _timer?.cancel();
    _timer = null;
    _log?.log(LogLevel.warn, 'webview_lease', 'lease_lost');
    if (!_lost.isClosed) _lost.add(null);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = _ticker(renewEvery, () => unawaited(_tick()));
  }

  Future<void> _tick() async {
    if (_ticking || !_held) return;
    _ticking = true;
    try {
      if (_owners.isEmpty && _liveHolds == 0) {
        await _releaseRow();
        return;
      }
      try {
        final renewed = await _repo.renew(
          accountId: reservedAccountId,
          holder: instanceId,
          ttl: ttl,
        );
        if (renewed) {
          _lastRenewedAt = _clock.now();
          return;
        }
        final again = await _repo.acquire(
          accountId: reservedAccountId,
          holder: instanceId,
          ttl: ttl,
          initialBucket: _emptyBucket,
        );
        if (again == null) {
          _declareLost();
        } else {
          _lastRenewedAt = _clock.now();
        }
      } on Object catch (error) {
        _log?.log(
          LogLevel.warn,
          'webview_lease',
          'renew_failed type=${error.runtimeType}',
        );
        // Try again at the next tick while the row still has its TTL. Once the
        // last good renewal is a full TTL old the row has expired and may be
        // owned elsewhere: that is a loss.
        final last = _lastRenewedAt;
        if (last != null && _clock.now().difference(last) >= ttl) {
          _declareLost();
        }
      }
    } finally {
      _ticking = false;
    }
  }
}

/// A claim on the WebView lease that outlives its owner. See
/// `GovernorWebViewLease.beginHold`.
// ignore: one_member_abstracts, a port that tests replace.
abstract interface class LeaseHold {
  /// Ends the hold. Safe to call twice.
  void release();
}

final class _NoHold implements LeaseHold {
  const _NoHold();

  @override
  void release() {}
}

final class _Hold implements LeaseHold {
  _Hold(this._lease, this.expiresAt);

  final GovernorWebViewLease _lease;
  final DateTime expiresAt;

  @override
  void release() => _lease._endHold(this);
}

/// A [PageDriver] that holds the WebView lease while a session exists, from
/// the start of `open` until the session is disposed (T-014 R2-F2).
///
/// `PageExtractor` releases the lease when `open` times out, but the open may
/// still finish later and then wipes the app-wide cookie jar while closing the
/// late session. The hold keeps the lease through that late open and its
/// clean-up, so the login WebView cannot be hit by it. A hold that is never
/// released ends after `GovernorWebViewLease.maxHold`.
final class LeaseHoldingPageDriver implements PageDriver {
  /// Wraps [inner] with holds on [lease].
  const LeaseHoldingPageDriver(this.inner, this.lease);

  /// The real driver.
  final PageDriver inner;

  /// The lease to hold.
  final GovernorWebViewLease lease;

  @override
  Future<PageSession> open(PageSessionConfig config) async {
    final hold = lease.beginHold();
    final PageSession session;
    try {
      session = await inner.open(config);
    } on Object {
      hold.release();
      rethrow;
    }
    return _HoldingSession(session, hold);
  }
}

final class _HoldingSession implements PageSession {
  _HoldingSession(this._inner, this._hold);

  final PageSession _inner;
  final LeaseHold _hold;

  @override
  Stream<PageEvent> get events => _inner.events;

  @override
  Future<void> load(Uri url) => _inner.load(url);

  @override
  Future<Object?> collectDomMedia() => _inner.collectDomMedia();

  @override
  Future<void> clearData() => _inner.clearData();

  @override
  Future<void> dispose() async {
    try {
      await _inner.dispose();
    } finally {
      _hold.release();
    }
  }
}
