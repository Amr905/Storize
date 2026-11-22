# Soak report (T-037 AC2, NFR-2, NFR-3)

Status: **template, not yet run.** The user runs the 24 h soak on both P-4 phones using Part C of
`docs/03-specs/DEVICE_TESTS.md` and fills this file. Record numbers and codes only: no cookies, tokens, URLs or other people's content.

## 1. Phones
| | Phone A | Phone B |
|---|---|---|
| Model | | |
| OEM and skin version | | |
| Android version | | |
| WebView version | | |
| App build (flavor, version) | | |
| Battery option set for Storize (Unrestricted / Optimized) | | |
| Page mode in background (on / off) | | |

## 2. Setup
| | Phone A | Phone B |
|---|---|---|
| Number of targets (about 20) | | |
| Story interval | | |
| Post interval | | |
| Start (date, time) | | |
| End (date, time) | | |
| Battery % at start / end | | |

## 3. Results against NFR-2 and NFR-3
| Metric | Target | Phone A | Phone B | PASS / FAIL |
|---|---|---|---|---|
| Owner stories posted (expected) | 6 | | | |
| Owner stories saved | 6 | | | |
| **Missed stories** (posted minus saved, phone online) | 0 | | | |
| Other targets' stories seen on the web but not saved | 0 | | | |
| **Gaps** over 2 h between successful story checks (count) | 0 | | | |
| Longest gap | under 2 h | | | |
| Checks run / failed | | | | |
| **Storize battery share per 24 h** (Settings, Battery) | under 3 % | | | |
| Total battery drop over 24 h | note | | | |
| Checkpoint, "please wait" or login-problem events | 0 | | | |
| Crashes or ANRs | 0 | | | |

## 4. Four-hour log
| Time | Battery % A | Battery % B | Errors or "skipped" in Activity | Notes |
|---|---|---|---|---|
| +0 h | | | | |
| +4 h | | | | |
| +8 h | | | | |
| +12 h | | | | |
| +16 h | | | | |
| +20 h | | | | |
| +24 h | | | | |

## 5. Missed stories in detail
| Phone | Target | Posted at | Why missed (offline, deferred, rate limit, other) | Seen in Activity? |
|---|---|---|---|---|
| | | | | |

## 6. Gaps in detail
| Phone | From | To | Length | Likely cause (Doze, battery saver, reboot, offline) |
|---|---|---|---|---|
| | | | | |

## 7. Verdict
- NFR-2 (no missed story while online): PASS / FAIL
- NFR-3 (under 3 % battery per day): PASS / FAIL
- Notes and follow-up tasks:
