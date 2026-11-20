import 'package:storize_instagram/platform/seen_breaker_store.dart';

/// Who may use the app's WebView (QA-F7).
///
/// The WebView cookie jar and web storage are **app-wide and shared across
/// isolates**. Page mode wipes them before and after every run, so it must
/// never run while another part of the app (the login WebView of S-02) holds
/// them. A Dart mutex does not help: the background task is another isolate.
///
/// Contract for implementations (T-015 / T-026 own the real one, for example
/// a row like `governor_lease` or a lock file in the app's private folder):
/// - [tryAcquire] never waits. It returns false when another owner holds a
///   live lease, and true when `owner` now holds it.
/// - A lease expires by itself (a TTL of a few minutes) so a crashed process
///   cannot lock page mode forever.
/// - [release] by the owner is idempotent and never throws for a missing
///   lease. Releasing a lease held by another owner does nothing.
/// - The login WebView holds the lease for its whole lifetime.
abstract interface class WebViewLease {
  /// Tries to take the lease for [owner]. Does not wait.
  Future<bool> tryAcquire(String owner);

  /// Gives the lease of [owner] back.
  Future<void> release(String owner);
}

/// A lease that is always free. The default for tests and single-user setups.
final class NoopWebViewLease implements WebViewLease {
  /// Creates the lease.
  const NoopWebViewLease();

  @override
  Future<bool> tryAcquire(String owner) async => true;

  @override
  Future<void> release(String owner) async {}
}

/// Remembers that the story "seen" guard failed (a reply to a blocked name
/// was captured, so the block did not hold). Once tripped, page-mode story
/// loads are refused until an explicit [reset]. Share one instance between
/// extractors so the breaker is process-wide.
///
/// **Persistence (T-014 R2-F5).** The state lives in a [SeenBreakerStore], so
/// it survives a restart and is shared with the other isolate:
/// - [tripped] stays a cheap synchronous read of this isolate's memory (the
///   extractor needs it synchronously).
/// - [refresh] reads the store and latches a stored "tripped" into memory. It
///   must be awaited **before each page-mode story load**
///   (`InstagramPlatform` does). If the store cannot be read the guard fails
///   closed: it counts as tripped in memory (nothing is written).
/// - [trip] latches memory at once and writes the store; [flush] waits for
///   that write. A failed write is swallowed: memory stays tripped, but the
///   store keeps its old value, so another isolate or a restart would not see
///   the trip. Call [trip] again to retry the write.
/// - Only [reset] clears the breaker, in memory and in the store.
final class SeenGuard {
  /// Creates a guard that has not tripped. Tests make their own.
  SeenGuard({SeenBreakerStore? store})
    : _store = store ?? InMemorySeenBreakerStore();

  /// The process-wide guard, the default of every `PageExtractor`. It is
  /// backed by memory only; the app replaces it with a guard on a persistent
  /// store (see [SeenBreakerStore]).
  static final SeenGuard shared = SeenGuard();

  final SeenBreakerStore _store;
  bool _tripped = false;
  Future<void> _pendingWrite = Future<void>.value();

  /// Whether the guard has tripped in this isolate's memory.
  bool get tripped => _tripped;

  /// Reads the store and returns whether the breaker is tripped. A stored
  /// "tripped" is latched into memory; a stored "not tripped" never clears a
  /// memory trip. A store that throws counts as tripped (fail closed).
  Future<bool> refresh() async {
    try {
      if (await _store.isTripped()) _tripped = true;
    } on Object {
      _tripped = true;
    }
    return _tripped;
  }

  /// Trips the breaker now and persists it in the background. Await [flush]
  /// to know the write finished.
  void trip() {
    _tripped = true;
    final previous = _pendingWrite;
    _pendingWrite = () async {
      await previous;
      try {
        await _store.markTripped();
      } on Object {
        // Memory stays tripped; the write is best effort.
      }
    }();
  }

  /// Completes when every write started by [trip] has finished. Never throws.
  Future<void> flush() => _pendingWrite;

  /// Clears the breaker in memory and in the store. The only way back.
  /// Throws if the store cannot be cleared (the breaker then stays tripped in
  /// the store, and memory is cleared only after the store was).
  Future<void> reset() async {
    await flush();
    await _store.clear();
    _tripped = false;
  }
}
