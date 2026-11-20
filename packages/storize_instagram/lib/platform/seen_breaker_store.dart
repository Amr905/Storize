/// Where the story "seen" breaker keeps its state (T-014 R2-F5).
///
/// The breaker trips when a reply to the blocked `PolarisStoriesV3SeenMutation`
/// was captured, which means the block failed and opening a story page would
/// mark stories as seen (BR-8). The state must survive a process restart and be
/// shared with the background isolate, so a restart cannot silently re-arm
/// page-mode story loads.
///
/// **Composition root (T-021 / app):** inject an implementation backed by
/// `SharedPreferences` (one bool key, for example `seen_breaker_tripped`), so
/// both isolates read the same value. Create one `SeenGuard` per isolate with
/// that store and give the same instance to `PageExtractor` and
/// `InstagramPlatform`. The in-memory default is only for tests and for a
/// process that never restarts.
///
/// Rules for implementations:
/// - [isTripped] and [markTripped] may throw; `SeenGuard` fails closed.
/// - Only [clear] may turn the value back to false. It is called by an
///   explicit `SeenGuard.reset()` (a developer or a settings action after the
///   cause is fixed), never by a timer or a restart.
abstract interface class SeenBreakerStore {
  /// Whether the breaker has been tripped (in any isolate).
  Future<bool> isTripped();

  /// Persists "tripped".
  Future<void> markTripped();

  /// Persists "not tripped". Only an explicit reset calls it.
  Future<void> clear();
}

/// A [SeenBreakerStore] in memory. Lost when the process ends.
final class InMemorySeenBreakerStore implements SeenBreakerStore {
  bool _tripped = false;

  @override
  Future<bool> isTripped() async => _tripped;

  @override
  Future<void> markTripped() async => _tripped = true;

  @override
  Future<void> clear() async => _tripped = false;
}
