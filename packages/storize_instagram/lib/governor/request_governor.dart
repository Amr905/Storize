import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/governor/governor_config.dart';
import 'package:storize_instagram/governor/governor_exceptions.dart';
import 'package:storize_model/storize_model.dart';

/// Rounding slack when comparing fractional tokens.
const double _tokenEpsilon = 1e-9;

/// Waits for a duration. Injected so tests run on fake time.
typedef Delay = Future<void> Function(Duration duration);

/// Receives one log line. Lines carry only the account id, cost, wait time
/// and outcome, never URLs, headers or cookies.
typedef GovernorLog = void Function(String message);

/// Zone key: the set of account ids with a `run` call in progress in this
/// zone. Used to refuse a nested `run` for the same account.
final Object _runningKey = Object();

Future<void> _realDelay(Duration duration) => Future<void>.delayed(duration);

/// The single gate for every Instagram call, direct or page mode (ADR-9).
///
/// - **Token bucket** per login account: `callsPerHour` refilled continuously,
///   capacity `burst`. A call takes `RequestCost` tokens and waits for them.
/// - **Jitter**: a random gap between consecutive calls of one account.
/// - **One call in flight per account**: a FIFO queue inside the isolate and a
///   lease (`GovernorLeaseRepo`) across isolates.
/// - **Back-off**: a `RateLimited` outcome pauses the account and raises the
///   interval multiplier for a while.
///
/// CDN downloads are not governed: do not wrap them.
///
/// The bucket and back-off state live in the lease row, so the UI isolate and
/// the background isolate share one budget. Each isolate needs its own unique
/// `holder` id; two governors with the same holder act as one.
class RequestGovernor {
  /// Creates a governor.
  ///
  /// `holder` names this isolate or task in the lease row. `delay`, `random`
  /// and `log` are injected for tests and diagnostics.
  RequestGovernor({
    required this._leases,
    required this._clock,
    required this._holder,
    this._config = const GovernorConfig(),
    this._delay = _realDelay,
    Random? random,
    this._log,
  }) : _random = random ?? Random();

  final GovernorLeaseRepo _leases;
  final Clock _clock;
  final String _holder;
  final GovernorConfig _config;
  final Delay _delay;
  final Random _random;
  final GovernorLog? _log;

  final Map<int, _AccountState> _states = {};

  /// The config in use.
  GovernorConfig get config => _config;

  /// Runs [call] when the budget, the jitter, the pause and the lease allow.
  ///
  /// Calls of one account run strictly one at a time, in the order of the
  /// `run` calls. If [call] throws, the error is rethrown after the slot is
  /// freed. If [call] throws or returns a `RateLimited` (also inside an
  /// `Err`), the account is paused and backed off. The limit is always
  /// recorded, and the original error or result is always the one returned.
  ///
  /// The lease is held only while a call runs and is released after each
  /// call (and during waits), so another isolate can interleave. The
  /// persisted bucket keeps the budget shared.
  ///
  /// Throws [GovernorPaused] while the account is paused and [GovernorBusy]
  /// when another isolate holds the lease for `acquireTimeout`. In both cases
  /// [call] was not made and no token was used.
  ///
  /// **Do not nest.** Calling `run` for the same account from inside [call]
  /// would wait behind itself forever, so it throws a [StateError]. Run a
  /// page-mode fallback after the direct `run` has returned.
  Future<T> run<T>({
    required int accountId,
    required RequestCost cost,
    required Future<T> Function() call,
  }) {
    final weight = _config.weightOf(cost);
    if (weight > _config.burst) {
      throw ArgumentError.value(
        cost,
        'cost',
        'costs $weight tokens, more than the burst of ${_config.burst}',
      );
    }
    final running = Zone.current[_runningKey] as Set<int>?;
    if (running != null && running.contains(accountId)) {
      throw StateError(
        'RequestGovernor.run is not re-entrant: a nested run for account '
        '$accountId would wait for itself. Call it after the outer run '
        'returns.',
      );
    }
    return _exclusive(accountId, (state) async {
      final queuedAt = _clock.now();
      await _prepare(accountId, state, weight);
      final waited = _clock.now().difference(queuedAt);
      T result;
      try {
        result = await runZoned(
          call,
          zoneValues: {
            _runningKey: <int>{...?running, accountId},
          },
        );
      } on Object catch (error) {
        final limited = error is RateLimited ? error : null;
        await _finishSafely(accountId, state, limited);
        _logLine(
          accountId,
          cost,
          waited,
          limited == null ? 'error' : 'rate_limited',
        );
        rethrow;
      }
      final limited = _rateLimitOf(result);
      await _finishSafely(accountId, state, limited);
      _logLine(
        accountId,
        cost,
        waited,
        limited == null ? 'ok' : 'rate_limited',
      );
      return result;
    });
  }

  /// Records a rate limit that the caller saw outside [run].
  ///
  /// Normal code never needs it: [run] records the limit of its own call, and
  /// the extractors go through [run] (TECH_SPEC section 4.1). It exists for
  /// tests.
  ///
  /// Safe against double reports: a limit that arrives while the account is
  /// already paused is the same event and is ignored (no x4, no longer
  /// pause). The limit is never dropped: this waits as long as it takes to
  /// get the lease, queued behind running calls of the account.
  @visibleForTesting
  Future<void> reportRateLimited(int accountId, RateLimited limited) =>
      _exclusive(accountId, (state) async {
        await _finish(accountId, state, limited);
        _logLine(accountId, null, Duration.zero, 'rate_limited_reported');
      });

  /// Whether calls of [accountId] are paused by a rate limit.
  Future<bool> isPaused(int accountId) async =>
      (await pausedUntil(accountId)) != null;

  /// When the pause of [accountId] ends (UTC), or null when not paused. For
  /// the S-07 bar and the S-13 count.
  Future<DateTime?> pausedUntil(int accountId) async {
    final bucket = await _snapshot(accountId);
    final until = bucket.backoffUntil;
    if (until != null && _clock.now().isBefore(until)) return until;
    return null;
  }

  /// The factor the Scheduler multiplies its intervals by: 1 normally, ×2 for
  /// 2 h after a rate limit, ×4 after a repeat within 24 h. Decays to 1.
  Future<double> effectiveIntervalMultiplier(int accountId) async {
    final bucket = await _snapshot(accountId);
    return _multiplierOf(bucket, _clock.now());
  }

  /// Tokens left for [accountId], refilled up to now. A snapshot: another
  /// isolate may use tokens right after.
  Future<double> remainingTokens(int accountId) async =>
      (await _snapshot(accountId)).tokens;

  /// Whether [calls] calls of [cost] fit into the tokens left right now and
  /// the account is not paused. RunCheck uses it to end a post round early
  /// and carry the rest over.
  Future<bool> canAfford(
    int accountId,
    RequestCost cost, {
    int calls = 1,
  }) async {
    if (await isPaused(accountId)) return false;
    final need = _config.weightOf(cost) * calls;
    return (await remainingTokens(accountId)) >= need;
  }

  // ---------------------------------------------------------------- queue

  /// Runs [body] as the only operation of [accountId] in this isolate, FIFO.
  /// Frees the lease after each operation so other isolates can interleave.
  Future<R> _exclusive<R>(
    int accountId,
    Future<R> Function(_AccountState state) body,
  ) async {
    final state = _states.putIfAbsent(accountId, _AccountState.new);
    state.pending++;
    final previous = state.tail;
    final gate = Completer<void>();
    state.tail = gate.future;
    try {
      await previous;
      return await body(state);
    } finally {
      state.pending--;
      try {
        await _releaseLease(accountId, state);
      } finally {
        gate.complete();
      }
    }
  }

  Future<void> _releaseLease(int accountId, _AccountState state) async {
    if (!state.leaseHeld) return;
    state.leaseHeld = false;
    await _leases.release(accountId: accountId, holder: _holder);
  }

  // ------------------------------------------------------------- the gate

  /// Waits until a call of [weight] tokens may start, then takes the tokens.
  /// Holds the lease on return.
  Future<void> _prepare(int accountId, _AccountState state, int weight) async {
    final gap = _drawGap();
    DateTime? readyAt; // When the jitter gap is satisfied.
    while (true) {
      final lease = await _acquire(
        accountId,
        state,
        _clock.now(),
        timeout: _config.acquireTimeout,
      );
      final now = _clock.now();
      final bucket = _refill(lease.bucket, now);

      // Repair state that a clock jump made impossible, once, so that the
      // jitter reference below is real and the wait ends.
      final raw = lease.bucket;
      if (raw.lastRefillAt.isAfter(now) ||
          raw.backoffUntil != bucket.backoffUntil) {
        final repaired = await _leases.writeBucket(
          accountId: accountId,
          holder: _holder,
          bucket: GovernorBucket(
            tokens: raw.tokens,
            lastRefillAt: raw.lastRefillAt.isAfter(now)
                ? now
                : raw.lastRefillAt,
            backoffUntil: bucket.backoffUntil,
            backoffMultiplier: raw.backoffMultiplier,
          ),
        );
        if (!repaired) {
          state.leaseHeld = false;
          continue;
        }
      }
      final until = bucket.backoffUntil;
      if (until != null && now.isBefore(until)) {
        _logLine(accountId, null, Duration.zero, 'paused');
        throw GovernorPaused(
          accountId: accountId,
          until: until,
          retryAfter: until.difference(now),
        );
      }

      // Same repair for this isolate's own memory (once, or the clamp would
      // move forward with `now` and the wait would never end).
      final own = state.lastCallEnd;
      if (own != null && own.isAfter(now)) state.lastCallEnd = now;
      final last = _lastActivity(state, raw.lastRefillAt, now);
      // The first look draws the random gap. If another isolate called while
      // we slept, we only owe it the minimum gap, so a busy peer cannot push
      // us back by a fresh random gap each time.
      final ready = readyAt == null
          ? last.add(gap)
          : _later(readyAt, last.add(_config.jitterMin));
      readyAt = ready;
      final jitter = ready.difference(now);
      final wait = _maxDuration(
        jitter.isNegative ? Duration.zero : jitter,
        _tokenWait(bucket, weight),
      );
      if (wait > Duration.zero) {
        // Do not hold the lease while sleeping: another isolate may call.
        await _releaseLease(accountId, state);
        await _delay(wait);
        continue;
      }

      final stored = await _leases.writeBucket(
        accountId: accountId,
        holder: _holder,
        bucket: GovernorBucket(
          tokens: max(0, bucket.tokens - weight),
          lastRefillAt: now,
          backoffUntil: bucket.backoffUntil,
          backoffMultiplier: bucket.backoffMultiplier,
        ),
      );
      if (stored) return;
      state.leaseHeld = false; // Lost the lease meanwhile: start over.
    }
  }

  /// Takes (or renews) the lease, polling with back-off while another holder
  /// has it. Throws [GovernorBusy] after [timeout]; null waits for as long as
  /// it takes.
  Future<GovernorLease> _acquire(
    int accountId,
    _AccountState state,
    DateTime startedAt, {
    Duration? timeout,
  }) async {
    var poll = _config.leasePollInitial;
    while (true) {
      final now = _clock.now();
      final lease = await _leases.acquire(
        accountId: accountId,
        holder: _holder,
        ttl: _config.leaseTtl,
        // A fresh row starts full, with "no recent call" so no jitter wait.
        initialBucket: GovernorBucket(
          tokens: _config.burst.toDouble(),
          lastRefillAt: now.subtract(_config.jitterMax),
        ),
      );
      if (lease != null) {
        state.leaseHeld = true;
        return lease;
      }
      final waited = _clock.now().difference(startedAt);
      if (timeout != null && waited >= timeout) {
        _logLine(accountId, null, waited, 'busy');
        throw GovernorBusy(accountId: accountId, waited: waited);
      }
      await _delay(
        timeout == null ? poll : _minDuration(poll, timeout - waited),
      );
      poll = _minDuration(poll * 2, _config.leasePollMax);
    }
  }

  /// [_finish] for use after a call: it must never replace the call's own
  /// result or error, so nothing escapes from here.
  Future<void> _finishSafely(
    int accountId,
    _AccountState state,
    RateLimited? limited,
  ) async {
    try {
      await _finish(accountId, state, limited);
    } on Object {
      _logLine(accountId, null, Duration.zero, 'record_failed');
    }
  }

  /// Stores the outcome of a call: refills, stamps the call end (the jitter
  /// reference) and applies a back-off when [limited] is set.
  ///
  /// A rate limit is never dropped: its write waits for the lease without a
  /// timeout. Without a limit the write is best effort and gives up with
  /// [GovernorBusy] swallowed after `acquireTimeout`.
  Future<void> _finish(
    int accountId,
    _AccountState state,
    RateLimited? limited,
  ) async {
    try {
      while (true) {
        final lease = await _acquire(
          accountId,
          state,
          _clock.now(),
          timeout: limited == null ? _config.acquireTimeout : null,
        );
        final now = _clock.now();
        var bucket = _refill(lease.bucket, now);
        if (limited != null) {
          bucket = _withBackoff(accountId, bucket, limited, now);
        }
        final stored = await _leases.writeBucket(
          accountId: accountId,
          holder: _holder,
          bucket: bucket,
        );
        if (stored) {
          state.lastCallEnd = now;
          return;
        }
        state.leaseHeld = false;
      }
    } on GovernorBusy {
      return; // Only reachable without a limit to record.
    }
  }

  // ----------------------------------------------------------- bucket math

  Future<GovernorBucket> _snapshot(int accountId) async {
    final now = _clock.now();
    final lease = await _leases.read(accountId);
    final bucket =
        lease?.bucket ??
        GovernorBucket(tokens: _config.burst.toDouble(), lastRefillAt: now);
    return _refill(bucket, now);
  }

  /// Refills up to [now] and repairs state that a clock jump made
  /// impossible: a `lastRefillAt` in the future counts as [now], and a
  /// `backoffUntil` further away than `maxPause` is cut to `now + maxPause`
  /// (the multiplier window follows it).
  GovernorBucket _refill(GovernorBucket bucket, DateTime now) {
    final last = bucket.lastRefillAt.isAfter(now) ? now : bucket.lastRefillAt;
    final elapsed = now.difference(last);
    // Multiply before dividing so whole-minute refills are exact.
    final added =
        elapsed.inMicroseconds *
        _config.callsPerHour /
        Duration.microsecondsPerHour;
    var until = bucket.backoffUntil;
    final latest = now.add(_config.maxPause);
    if (until != null && until.isAfter(latest)) until = latest;
    return GovernorBucket(
      tokens: min(_config.burst.toDouble(), bucket.tokens + added),
      lastRefillAt: now,
      backoffUntil: until,
      backoffMultiplier: bucket.backoffMultiplier,
    );
  }

  Duration _tokenWait(GovernorBucket refilled, int weight) {
    final missing = weight - refilled.tokens;
    if (missing <= _tokenEpsilon) return Duration.zero;
    final micros =
        missing * Duration.microsecondsPerHour / _config.callsPerHour;
    return Duration(microseconds: micros.ceil());
  }

  Duration _drawGap() {
    final min = _config.jitterMin.inMicroseconds;
    final span = _config.jitterMax.inMicroseconds - min;
    return Duration(microseconds: min + (_random.nextDouble() * span).round());
  }

  /// The end of the previous call: in memory for this isolate, and from the
  /// bucket stamp for calls of other isolates. A time in the future (clock
  /// moved back) counts as [now].
  DateTime _lastActivity(_AccountState state, DateTime stamp, DateTime now) {
    var last = stamp.isAfter(now) ? now : stamp;
    final own = state.lastCallEnd;
    if (own != null && own.isAfter(last)) last = own.isAfter(now) ? now : own;
    return last;
  }

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// Applies a rate limit. Ignored while the account is already paused: a
  /// limit that arrives then is the same event seen twice (for example a
  /// failure fed back after the governor handled it), and counting it would
  /// jump the multiplier to x4. No call runs during a pause, so a second real
  /// limit cannot happen inside one.
  GovernorBucket _withBackoff(
    int accountId,
    GovernorBucket bucket,
    RateLimited limited,
    DateTime now,
  ) {
    final previous = bucket.backoffUntil;
    if (previous != null && now.isBefore(previous)) return bucket;
    final hint = limited.retryAfter;
    var pause = hint != null && hint > Duration.zero
        ? hint
        : _config.defaultRetryAfter;
    if (pause > _config.maxPause) {
      pause = _config.maxPause;
      _logLine(accountId, null, Duration.zero, 'pause_capped');
    }
    final isRepeat =
        previous != null &&
        bucket.backoffMultiplier > 1 &&
        now.isBefore(previous.add(_config.repeatWindow));
    return GovernorBucket(
      tokens: bucket.tokens,
      lastRefillAt: bucket.lastRefillAt,
      backoffUntil: now.add(pause),
      backoffMultiplier: isRepeat
          ? _config.repeatMultiplier
          : _config.firstMultiplier,
    );
  }

  double _multiplierOf(GovernorBucket bucket, DateTime now) {
    final until = bucket.backoffUntil;
    if (until == null || bucket.backoffMultiplier <= 1) return 1;
    return now.isBefore(until.add(_config.multiplierDuration))
        ? bucket.backoffMultiplier
        : 1;
  }

  RateLimited? _rateLimitOf(Object? result) => switch (result) {
    final RateLimited limited => limited,
    Err<Object?>(:final failure) when failure is RateLimited => failure,
    _ => null,
  };

  void _logLine(int accountId, RequestCost? cost, Duration waited, String out) {
    _log?.call(
      'governor account=$accountId cost=${cost?.name ?? '-'} '
      'waited_ms=${waited.inMilliseconds} outcome=$out',
    );
  }

  static Duration _minDuration(Duration a, Duration b) => a <= b ? a : b;
  static Duration _maxDuration(Duration a, Duration b) => a >= b ? a : b;
}

/// Per-account state of one isolate.
class _AccountState {
  /// Completes when the last queued operation is done (the FIFO chain).
  Future<void> tail = Future<void>.value();

  /// Queued plus running operations.
  int pending = 0;

  /// Whether this isolate believes it holds the lease.
  bool leaseHeld = false;

  /// When this isolate's last call ended.
  DateTime? lastCallEnd;
}
