import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:storize_domain/storize_domain.dart';

/// Outcome of [PinVault.verify].
sealed class PinCheck {
  const PinCheck();
}

/// The PIN matched. Failure count and cooldown are cleared.
final class PinAccepted extends PinCheck {
  /// Creates the result.
  const PinAccepted();
}

/// The PIN did not match.
final class PinRejected extends PinCheck {
  /// Creates the result. [attemptsLeft] is how many more wrong PINs are
  /// allowed before a cooldown starts (0 when this failure started one).
  const PinRejected({required this.attemptsLeft, this.cooldown});

  /// Wrong attempts left before the cooldown.
  final int attemptsLeft;

  /// Set when this failure started a cooldown.
  final Duration? cooldown;
}

/// A cooldown is running: the PIN was not checked and not counted.
final class PinCoolingDown extends PinCheck {
  /// Creates the result.
  const PinCoolingDown(this.remaining);

  /// Time left, always in `(0, PinVault.cooldownDuration]`.
  final Duration remaining;
}

/// No usable PIN is stored (never set, wiped by a secure-storage reset, or
/// unreadable). The caller must treat this as a reset state, never as
/// "unlocked" (T-008 QA N-1).
final class PinNotSet extends PinCheck {
  /// Creates the result.
  const PinNotSet();
}

/// What the app lock needs from a PIN store. [PinVault] is the production
/// implementation; the app's tests use a fake.
abstract interface class PinStore {
  /// True when a well-formed PIN (hash and length) is stored.
  Future<bool> hasPin();

  /// The stored PIN's length (4 to 6), or null when there is no usable PIN.
  Future<int?> pinLength();

  /// Hashes and stores [pin] (4 to 6 digits); clears failures and cooldown.
  Future<void> setPin(String pin);

  /// Checks [pin].
  Future<PinCheck> verify(String pin);

  /// The running cooldown, or null.
  Future<Duration?> cooldownRemaining();

  /// Removes the PIN, the failure count and the cooldown.
  Future<void> clear();
}

/// Derives the PBKDF2-HMAC-SHA256 key (256 bit). Runs off the UI isolate by
/// default. Injected so tests can replace it.
typedef PinHasher = Future<List<int>> Function(
  String pin,
  List<int> salt,
  int iterations,
);

/// Stores the app-lock PIN as a PBKDF2 hash and enforces the failure
/// cooldown (TECH_SPEC section 5.2, UX S-14).
///
/// - Format: `v1:<iterations>:<salt base64>:<hash base64>`, so the iteration
///   count can change later: a stored hash is always checked with the count
///   written in it.
/// - The failure count and the cooldown deadline live in secure storage, so
///   killing the app does not reset them. A failure is written *before* the
///   hash is compared, so killing the app mid-check does not give a free try.
/// - The clock is injected. If it jumps backwards the cooldown restarts at
///   its full length (30 s) rather than lasting until the old deadline.
/// - Nothing here logs, and no exception or result carries the PIN or hash.
final class PinVault implements PinStore {
  /// Creates a vault over the given secure storage.
  ///
  /// [iterations] and [hasher] exist for tests; production uses the defaults.
  PinVault(
    this._storage, {
    Clock clock = const SystemClock(),
    this.iterations = defaultIterations,
    PinHasher? hasher,
    Random? random,
    // ignore: prefer_initializing_formals, a private field behind a public name.
  }) : _clock = clock,
       _hasher = hasher ?? _hashInIsolate,
       _random = random ?? Random.secure();

  /// PBKDF2 iteration count for new hashes (TECH_SPEC section 5.2).
  static const int defaultIterations = 210000;

  /// Wrong PINs that start a cooldown.
  static const int maxFailures = 5;

  /// Length of the cooldown.
  static const Duration cooldownDuration = Duration(seconds: 30);

  /// Shortest PIN.
  static const int minLength = 4;

  /// Longest PIN.
  static const int maxLength = 6;

  /// Salt length in bytes.
  static const int saltLength = 16;

  /// Storage key of the hash.
  static const String hashKey = 'storize.pin.hash';

  /// Storage key of the failure state.
  static const String attemptsKey = 'storize.pin.attempts';

  /// Storage key of the PIN length (needed to know when to auto-submit).
  static const String lengthKey = 'storize.pin.length';

  static const int _maxIterations = 10000000;

  /// Iterations used for new hashes.
  final int iterations;

  final FlutterSecureStorage _storage;
  final Clock _clock;
  final PinHasher _hasher;
  final Random _random;

  /// Whether [pin] is 4 to 6 ASCII digits.
  static bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  /// True when a well-formed hash and length are stored. A storage error
  /// counts as no PIN.
  @override
  Future<bool> hasPin() async =>
      await _readHash() != null && await pinLength() != null;

  @override
  Future<int?> pinLength() async {
    final String? raw;
    try {
      raw = await _storage.read(key: lengthKey);
    } on Object {
      return null;
    }
    final n = raw == null ? null : int.tryParse(raw);
    return n != null && n >= minLength && n <= maxLength ? n : null;
  }

  /// Hashes and stores [pin], and clears failures and cooldown.
  ///
  /// Throws [ArgumentError] when [pin] is not 4 to 6 digits.
  @override
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must be $minLength to $maxLength digits');
    }
    final salt = List<int>.generate(saltLength, (_) => _random.nextInt(256));
    final hash = await _hasher(pin, salt, iterations);
    await _storage.write(
      key: hashKey,
      value: 'v1:$iterations:${base64.encode(salt)}:${base64.encode(hash)}',
    );
    await _storage.write(key: lengthKey, value: '${pin.length}');
    await _storage.delete(key: attemptsKey);
  }

  /// Checks [pin].
  @override
  Future<PinCheck> verify(String pin) async {
    final stored = await _readHash();
    if (stored == null || await pinLength() == null) return const PinNotSet();

    final state = await _readAttempts();
    final remaining = _remaining(state);
    if (remaining != null) {
      if (remaining.restarted) {
        await _writeAttempts(0, remaining.until);
      }
      return PinCoolingDown(remaining.left);
    }

    // Count the try first; clear it on success.
    final failures = state.failures + 1;
    await _writeAttempts(failures, null);

    var matches = false;
    if (isValidPin(pin)) {
      final actual = await _hasher(pin, stored.salt, stored.iterations);
      matches = _constantTimeEquals(actual, stored.hash);
    }
    if (matches) {
      await _storage.delete(key: attemptsKey);
      return const PinAccepted();
    }
    if (failures >= maxFailures) {
      final until = _clock.now().add(cooldownDuration);
      await _writeAttempts(0, until);
      return const PinRejected(attemptsLeft: 0, cooldown: cooldownDuration);
    }
    return PinRejected(attemptsLeft: maxFailures - failures);
  }

  /// The running cooldown, or null. Safe to poll.
  @override
  Future<Duration?> cooldownRemaining() async {
    final remaining = _remaining(await _readAttempts());
    if (remaining == null) return null;
    if (remaining.restarted) await _writeAttempts(0, remaining.until);
    return remaining.left;
  }

  /// Removes the PIN, the failure count and the cooldown.
  @override
  Future<void> clear() async {
    await _storage.delete(key: hashKey);
    await _storage.delete(key: lengthKey);
    await _storage.delete(key: attemptsKey);
  }

  // Storage helpers.

  Future<_StoredHash?> _readHash() async {
    final String? raw;
    try {
      raw = await _storage.read(key: hashKey);
    } on Object {
      return null;
    }
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 4 || parts[0] != 'v1') return null;
    final iter = int.tryParse(parts[1]);
    if (iter == null || iter < 1 || iter > _maxIterations) return null;
    try {
      final salt = base64.decode(parts[2]);
      final hash = base64.decode(parts[3]);
      if (salt.isEmpty || hash.isEmpty) return null;
      return _StoredHash(iter, salt, hash);
    } on FormatException {
      return null;
    }
  }

  Future<_Attempts> _readAttempts() async {
    final String? raw;
    try {
      raw = await _storage.read(key: attemptsKey);
    } on Object {
      return _corrupt();
    }
    if (raw == null) return const _Attempts(0, null);
    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'v1') return _corrupt();
    final failures = int.tryParse(parts[1]);
    final untilMs = int.tryParse(parts[2]);
    if (failures == null || failures < 0 || untilMs == null || untilMs < 0) {
      return _corrupt();
    }
    return _Attempts(
      failures,
      untilMs == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(untilMs, isUtc: true),
    );
  }

  // An unreadable failure state must not be a way to reset the counter, so it
  // starts a cooldown.
  _Attempts _corrupt() => _Attempts(0, _clock.now().add(cooldownDuration));

  Future<void> _writeAttempts(int failures, DateTime? until) => _storage.write(
    key: attemptsKey,
    value: 'v1:$failures:${until?.millisecondsSinceEpoch ?? 0}',
  );

  _Remaining? _remaining(_Attempts state) {
    final until = state.until;
    if (until == null) return null;
    final now = _clock.now();
    final left = until.difference(now);
    if (left <= Duration.zero) return null;
    if (left > cooldownDuration) {
      // The clock moved back since the cooldown started: restart it at its
      // full length instead of waiting out the old deadline.
      final restarted = now.add(cooldownDuration);
      return _Remaining(cooldownDuration, restarted, restarted: true);
    }
    return _Remaining(left, until);
  }

  @override
  String toString() => 'PinVault()';
}

final class _StoredHash {
  const _StoredHash(this.iterations, this.salt, this.hash);

  final int iterations;
  final List<int> salt;
  final List<int> hash;
}

final class _Attempts {
  const _Attempts(this.failures, this.until);

  final int failures;
  final DateTime? until;
}

final class _Remaining {
  const _Remaining(this.left, this.until, {this.restarted = false});

  final Duration left;
  final DateTime until;
  final bool restarted;
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  var diff = a.length ^ b.length;
  final n = max(a.length, b.length);
  for (var i = 0; i < n; i++) {
    diff |= (i < a.length ? a[i] : 0) ^ (i < b.length ? b[i] : 0);
  }
  return diff == 0;
}

Future<List<int>> _pbkdf2(String pin, List<int> salt, int iterations) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: pin, nonce: salt);
  return key.extractBytes();
}

Future<List<int>> _hashInIsolate(String pin, List<int> salt, int iterations) =>
    Isolate.run(() => _pbkdf2(pin, salt, iterations));
