import 'dart:async';
import 'dart:math';

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
  /// `Err`), the account is paused and backed off; do not report it again.
  ///
  /// Throws [GovernorPaused] while the account is paused and [GovernorBusy]
  /// when another isolate holds the lease for `acquireTimeout`. In both cases
  /// [call] was not made and no token was used.
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
    return _exclusive(accountId, (state) async {
      final queuedAt = _clock.now();
      await _prepare(accountId, state, weight);
      final waited = _clock.now().difference(queuedAt);
      T result;
      try {
        result = await call();
      } on Object catch (error) {
        final limited = error is RateLimited ? error : null;
        await _finish(accountId, state, limited);
        _logLine(
          accountId,
          cost,
          waited,
          limited == null ? 'error' : 'rate_limited',
        );
        rethrow;
      }
      final limited = _rateLimitOf(result);
      await _finish(accountId, state, limited);
      _logLine(
        accountId,
        cost,
        waited,
        limited == null ? 'ok' : 'rate_limited',
      );
      return result;
    });
  }

  /// Records a rate limit that the caller saw outside [run] (for example a
  /// 429 on a request made through another path). Do not call it for an
  /// outcome that [run] already handled.
  ///
  /// Queued behind running calls of the account. May throw [GovernorBusy].
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
  /// Frees the lease when the queue runs empty.
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
        if (state.pending == 0 && state.leaseHeld) {
          state.leaseHeld = false;
          await _leases.release(accountId: accountId, holder: _holder);
        }
      } finally {
        gate.complete();
      }
    }
  }

  // ------------------------------------------------------------- the gate

  /// Waits until a call of [weight] tokens may start, then takes the tokens.
  /// Holds the lease on return.
  Future<void> _prepare(int accountId, _AccountState state, int weight) async {
    final gap = _drawGap();
    final startedAt = _clock.now();
    while (true) {
      final lease = await _acquire(accountId, state, startedAt);
      final now = _clock.now();
      final bucket = _refill(lease.bucket, now);

      final until = bucket.backoffUntil;
      if (until != null && now.isBefore(until)) {
        _logLine(accountId, null, Duration.zero, 'paused');
        throw GovernorPaused(
          accountId: accountId,
          until: until,
          retryAfter: until.difference(now),
        );
      }

      final wait = _maxDuration(
        _jitterWait(state, lease.bucket, gap, now),
        _tokenWait(bucket, weight),
      );
      if (wait > Duration.zero) {
        // Wake up well inside the lease ttl so the next acquire renews it.
        await _delay(_minDuration(wait, _config.leaseTtl ~/ 2));
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
  /// has it. Throws [GovernorBusy] after `acquireTimeout`.
  Future<GovernorLease> _acquire(
    int accountId,
    _AccountState state,
    DateTime startedAt,
  ) async {
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
      if (waited >= _config.acquireTimeout) {
        _logLine(accountId, null, waited, 'busy');
        throw GovernorBusy(accountId: accountId, waited: waited);
      }
      await _delay(_minDuration(poll, _config.acquireTimeout - waited));
      poll = _minDuration(poll * 2, _config.leasePollMax);
    }
  }

  /// Stores the outcome of a call: refills, stamps the call end (the jitter
  /// reference) and applies a back-off when [limited] is set.
  Future<void> _finish(
    int accountId,
    _AccountState state,
    RateLimited? limited,
  ) async {
    while (true) {
      final lease = await _acquire(accountId, state, _clock.now());
      final now = _clock.now();
      var bucket = _refill(lease.bucket, now);
      if (limited != null) bucket = _withBackoff(bucket, limited, now);
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

  GovernorBucket _refill(GovernorBucket bucket, DateTime now) {
    final elapsed = now.difference(bucket.lastRefillAt);
    // Multiply before dividing so whole-minute refills are exact.
    final added = elapsed.isNegative
        ? 0
        : elapsed.inMicroseconds *
              _config.callsPerHour /
              Duration.microsecondsPerHour;
    return GovernorBucket(
      tokens: min(_config.burst.toDouble(), bucket.tokens + added),
      lastRefillAt: now,
      backoffUntil: bucket.backoffUntil,
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

  /// The jitter gap is measured from the end of the previous call: in memory
  /// for this isolate, and from the bucket stamp for calls of other isolates.
  Duration _jitterWait(
    _AccountState state,
    GovernorBucket stored,
    Duration gap,
    DateTime now,
  ) {
    var last = stored.lastRefillAt;
    final own = state.lastCallEnd;
    if (own != null && own.isAfter(last)) last = own;
    final remaining = last.add(gap).difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  GovernorBucket _withBackoff(
    GovernorBucket bucket,
    RateLimited limited,
    DateTime now,
  ) {
    final hint = limited.retryAfter;
    final pause = hint != null && hint > Duration.zero
        ? hint
        : _config.defaultRetryAfter;
    var until = now.add(pause);
    final previous = bucket.backoffUntil;
    if (previous != null && previous.isAfter(until)) until = previous;
    final isRepeat =
        previous != null &&
        bucket.backoffMultiplier > 1 &&
        now.isBefore(previous.add(_config.repeatWindow));
    return GovernorBucket(
      tokens: bucket.tokens,
      lastRefillAt: bucket.lastRefillAt,
      backoffUntil: until,
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
