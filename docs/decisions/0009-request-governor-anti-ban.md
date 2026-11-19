# 0009 — Central RequestGovernor for every Instagram call, shared by stories and posts (revised v0.2)

- Status: proposed
- Date: 2026-11-19

## Context
The ban risk (R-1) grows with request volume and with robotic timing. v0.2 adds post checks, which take one request per
account (R-8). Calls come from story runs, post runs, add-target, URL refreshes, manual checks and page mode.

## Options considered
1. **One governor in `storize_instagram` that every request (direct and page mode) must pass through** ✅
2. **Per-caller delays** — ❌ inconsistent; parallel tasks can exceed the limits.
3. **No throttling** — ❌ bursts look like a bot.

## Decision
- **Token bucket:** 60 Instagram calls per hour per login account (config value), burst of 6. CDN downloads aren't counted;
  each page-mode page load counts as 3 calls.
- **Jitter:** 1.5–6 s random gap between calls. Story and post periodic tasks start at offset times.
- **Budget at the defaults** (50 accounts, stories every 30 min, posts every 3 h): stories ≈ 3 calls per run → about 6/h;
  posts ≈ 50 calls per run → about 17/h; **total about 23/h**, well under 60/h.
- If a post run can't finish within the budget, the accounts left over carry to the next run (round-robin from where it stopped).
- **Back-off:** on `RateLimited`, pause `retryAfter` or 15 min, then use twice the intervals for 2 h; a repeat within 24 h → ×4.
- **Concurrency:** one call in flight per login account (a Dart `Mutex`/queue), across story and post runs in the same isolate.
  Cross-isolate safety comes from a DB lease row (`governor_lease`) with a 10-minute expiry.

## Clarifications (2026-11-19, Lead, from T-012)
- The ×2 multiplier applies for 2 h **counted from the end of the pause** (`backoffUntil`), not from the moment of the rate limit.
- "A repeat within 24 h" means a new rate limit before `previous backoffUntil + 24 h`. A limit that arrives during an active pause counts as a repeat (×4) and the longer pause wins.
- A `retryAfter` of zero or less is treated as "no hint" (15 min).
- While paused, `run` throws `GovernorPaused` immediately (it does not wait out the pause); the adapter maps it to `RateLimited` via `toFailure()`.
- The bucket's `lastRefillAt` doubles as the jitter reference across isolates (no extra schema field). Accepted to avoid a schema change; revisit if a `lastRateLimitedAt` field is ever needed.
- A single call must finish well under the 10-minute lease TTL (network timeouts are set far below it).

## Consequences
- A manual "Check now" across 50 accounts (stories and posts) can take about 2–5 minutes, so S-07 shows "Checking…" per row.
- The limits are guesses until field data exists. They're config values so a hotfix can change them.
