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

/// Zone key: the default `maxWait` of every `run` started in this zone (see
/// [RequestGovernor.withMaxWait]).
final Object _maxWaitKey = Object();

/// Zone key: the default [RequestPriority] of every `run` started in this
/// zone (see [RequestGovernor.withPriority]).
final Object _priorityKey = Object();

/// Zone key: the scope of [RequestGovernor.runUnmetered] (T-050 debug).
final Object _unmeteredKey = Object();

/// The marker of one `runUnmetered` scope; remembers that it was logged.
final class _UnmeteredScope {
  bool logged = false;
}

/// The spacing between calls of an unmetered run.
const Duration _unmeteredGap = Duration(seconds: 1);

/// Attempts to record a rate limit before giving up (N2).
const int _limitRecordAttempts = 3;

/// Wait before the first retry of a failed limit record; doubles each time.
const Duration _limitRecordBackoff = Duration(milliseconds: 200);

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
    this.allowUnmetered = false,
  }) : _random = random ?? Random();

  final GovernorLeaseRepo _leases;
  final Clock _clock;
  final String _holder;
  final GovernorConfig _config;
  final Delay _delay;
  final Random _random;
  final GovernorLog? _log;

  /// Whether [runUnmetered] has an effect. Only dev builds set it (T-050); in
  /// production `runUnmetered` is a normal run.
  final bool allowUnmetered;

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
  /// [maxWait] bounds the wait (TECH_SPEC 17.3). When the tokens, the jitter
  /// gap or an active pause would need longer than [maxWait] (counted from
  /// this call's turn), the call is refused at once with [GovernorPaused]
  /// (`toFailure()` is a `RateLimited` with the computed `retryAfter`) and
  /// **no token is used**. Null falls back to the zone default of
  /// [withMaxWait], and then to waiting as long as it takes.
  ///
  /// **Do not nest.** Calling `run` for the same account from inside [call]
  /// would wait behind itself forever, so it throws a [StateError]. Run a
  /// page-mode fallback after the direct `run` has returned.
  Future<T> run<T>({
    required int accountId,
    required RequestCost cost,
    required Future<T> Function() call,
    Duration? maxWait,
    RequestPriority? priority,
  }) {
    maxWait ??= Zone.current[_maxWaitKey] as Duration?;
    priority ??=
        Zone.current[_priorityKey] as RequestPriority? ??
        RequestPriority.interactive;
    final weight = _config.weightOf(cost);
    final scope = allowUnmetered
        ? Zone.current[_unmeteredKey] as _UnmeteredScope?
        : null;
    final unmetered = scope != null;
    if (scope != null && !scope.logged) {
      scope.logged = true;
      _log?.call('unmetered=yes');
    }
    // A background call keeps tokens for interactive work (T-050), as far as
    // the burst allows.
    final reserve = !unmetered && priority == RequestPriority.background
        ? max(0, min(_config.interactiveReserve, _config.burst - weight))
        : 0;
    if (!unmetered && weight > _config.burst) {
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
      await _prepare(accountId, state, weight, maxWait, reserve, unmetered);
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

  /// Debug "Check now without the hourly limit" (T-050). Inside [body], when
  /// the governor was built with `allowUnmetered` (dev builds only), calls
  /// skip the hourly and burst token budget and the random jitter: they keep
  /// a fixed 1 s spacing and still respect an active back-off (the pause
  /// after a rate limit). `unmetered=yes` is logged once per scope. On a
  /// governor without `allowUnmetered` (production) this is just [body].
  static Future<T> runUnmetered<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_unmeteredKey: _UnmeteredScope()});

  /// Runs [body] so that every `run` started inside it (and not given its own
  /// `priority`) uses [priority]. Background isolates wrap their work in it
  /// with [RequestPriority.background].
  static Future<T> withPriority<T>(
    RequestPriority priority,
    Future<T> Function() body,
  ) => runZoned(body, zoneValues: {_priorityKey: priority});

  /// Runs [body] so that every `run` started inside it (and not given its own
  /// `maxWait`) uses [maxWait]. For interactive paths: the user must not
  /// stare at a spinner while the budget refills (TECH_SPEC 17.3).
  static Future<T> withMaxWait<T>(
    Duration maxWait,
    Future<T> Function() body,
  ) => runZoned(body, zoneValues: {_maxWaitKey: maxWait});

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
  Future<void> _prepare(
    int accountId,
    _AccountState state,
    int weight,
    Duration? maxWait,
    int reserve,
    bool unmetered,
  ) async {
    final startedAt = _clock.now();
    final gap = unmetered ? _unmeteredGap : _drawGap();
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
          : _later(
              readyAt,
              last.add(unmetered ? _unmeteredGap : _config.jitterMin),
            );
      readyAt = ready;
      final jitter = ready.difference(now);
      final wait = _maxDuration(
        jitter.isNegative ? Duration.zero : jitter,
        unmetered ? Duration.zero : _tokenWait(bucket, weight + reserve),
      );
      if (maxWait != null && wait > Duration.zero) {
        final left = maxWait - now.difference(startedAt);
        if (wait > left) {
          // Refuse before taking a token (nothing was written).
          _logLine(accountId, null, Duration.zero, 'would_wait');
          throw GovernorPaused(
            accountId: accountId,
            until: now.add(wait),
            retryAfter: wait,
          );
        }
      }
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
          tokens: unmetered ? bucket.tokens : max(0, bucket.tokens - weight),
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
  ///
  /// Recording a rate limit is retried when the repo write throws: up to
  /// [_limitRecordAttempts] attempts, waiting 200 ms and then 400 ms on the
  /// injected delay. Without a limit there is one best-effort attempt. If
  /// every attempt fails, `record_failed` is logged.
  Future<void> _finishSafely(
    int accountId,
    _AccountState state,
    RateLimited? limited,
  ) async {
    final attempts = limited == null ? 1 : _limitRecordAttempts;
    var backoff = _limitRecordBackoff;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _finish(accountId, state, limited);
        return;
      } on Object {
        if (attempt == attempts) break;
        try {
          await _delay(backoff);
        } on Object {
          break;
        }
        backoff *= 2;
      }
    }
    _logLine(accountId, null, Duration.zero, 'record_failed');
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
