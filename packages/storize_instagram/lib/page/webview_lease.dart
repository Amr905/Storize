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
/// loads are refused until the process restarts. Share one instance between
/// extractors so the breaker is process-wide.
final class SeenGuard {
  /// Creates a guard that has not tripped. Tests make their own.
  SeenGuard();

  /// The process-wide guard, the default of every `PageExtractor`. It stays
  /// tripped until the process restarts.
  static final SeenGuard shared = SeenGuard();

  bool _tripped = false;

  /// Whether the guard has tripped.
  bool get tripped => _tripped;

  /// Trips the breaker.
  void trip() => _tripped = true;
}
