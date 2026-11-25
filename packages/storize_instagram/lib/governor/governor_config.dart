/// What a call costs in the token bucket (ADR-9).
///
/// CDN media downloads are deliberately **not** governed: they are plain
/// HTTPS GETs of signed CDN URLs and do not count against the Instagram
/// budget (ADR-5, ADR-9). Only calls to Instagram itself use a cost.
/// Who a governed call is for (T-050). Interactive calls (the user is
/// waiting) may use every token; background calls leave
/// [GovernorConfig.interactiveReserve] tokens of the burst untouched.
enum RequestPriority {
  /// A foreground call the user waits for.
  interactive,

  /// A scheduled or background call.
  background,

  /// A background call inside an open in-page session (T-052): the page load
  /// was already charged with the full reserve, so its queries keep only one
  /// token for interactive work instead of [GovernorConfig.interactiveReserve].
  sessionBackground,
}

enum RequestCost {
  /// One direct API call (user lookup, stories, posts).
  api,

  /// One page-mode page load (headless WebView). Counts as several calls.
  pageLoad,
}

/// Every tunable of the governor. The defaults are the numbers of ADR-9, kept
/// as config values so a hotfix can change them.
final class GovernorConfig {
  /// Creates a config. Omitted values use the ADR-9 defaults.
  const GovernorConfig({
    this.callsPerHour = 60,
    this.burst = 6,
    this.apiCost = 1,
    this.pageLoadCost = 3,
    this.jitterMin = const Duration(milliseconds: 1500),
    this.jitterMax = const Duration(seconds: 6),
    this.leaseTtl = const Duration(minutes: 10),
    this.acquireTimeout = const Duration(minutes: 2),
    this.leasePollInitial = const Duration(milliseconds: 250),
    this.leasePollMax = const Duration(seconds: 5),
    this.defaultRetryAfter = const Duration(minutes: 15),
    this.maxPause = const Duration(hours: 24),
    this.firstMultiplier = 2,
    this.repeatMultiplier = 4,
    this.multiplierDuration = const Duration(hours: 2),
    this.repeatWindow = const Duration(hours: 24),
    this.interactiveReserve = 3,
  }) : assert(callsPerHour > 0, 'callsPerHour must be positive'),
       assert(burst > 0, 'burst must be positive'),
       assert(apiCost > 0, 'apiCost must be positive'),
       assert(pageLoadCost > 0, 'pageLoadCost must be positive');

  /// Sustained rate: tokens refilled per hour, continuously (default 60).
  final int callsPerHour;

  /// Bucket capacity, so the largest burst (default 6).
  final int burst;

  /// Tokens one [RequestCost.api] call takes (default 1).
  final int apiCost;

  /// Tokens one [RequestCost.pageLoad] call takes (default 3).
  final int pageLoadCost;

  /// Shortest random gap between two calls of one account (default 1.5 s).
  final Duration jitterMin;

  /// Longest random gap between two calls of one account (default 6 s).
  final Duration jitterMax;

  /// How long a lease lives without renewal (default 10 min).
  final Duration leaseTtl;

  /// How long `run` waits for another holder's lease before it throws
  /// `GovernorBusy` (default 2 min).
  final Duration acquireTimeout;

  /// First wait between lease polls; doubles up to [leasePollMax].
  final Duration leasePollInitial;

  /// Longest wait between lease polls.
  final Duration leasePollMax;

  /// Pause used when a rate limit carries no usable `retryAfter` (15 min).
  final Duration defaultRetryAfter;

  /// Longest pause a rate limit can cause, whatever `retryAfter` says
  /// (default 24 h). Also bounds a stored pause after a clock jump.
  final Duration maxPause;

  /// Interval multiplier after a rate limit (default 2).
  final double firstMultiplier;

  /// Interval multiplier after a repeat rate limit within [repeatWindow]
  /// (default 4).
  final double repeatMultiplier;

  /// How long the multiplier applies, counted from the end of the pause
  /// (default 2 h).
  final Duration multiplierDuration;

  /// A rate limit this soon after the previous pause ended is a repeat
  /// (default 24 h).
  final Duration repeatWindow;

  /// Tokens a background call leaves for interactive calls (T-050). A
  /// background call waits until the bucket holds its own weight plus this
  /// many tokens (cut so that it never exceeds the burst).
  final int interactiveReserve;

  /// The token weight of [cost].
  int weightOf(RequestCost cost) => switch (cost) {
    RequestCost.api => apiCost,
    RequestCost.pageLoad => pageLoadCost,
  };
}
