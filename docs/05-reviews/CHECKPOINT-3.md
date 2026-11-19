# Checkpoint 3

- **Commit tested:** `854e001` (main, clean detached worktree)
- **Tasks covered (16 done):** T-001, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-024, T-025 (CP2) plus T-012, T-010, T-012a, T-023, T-010a, T-034 (new since CP2). List confirmed against `docs/implementation-status.md` (log entries 2026-11-19 15:05 to 16:40).
- **Date:** 2026-11-19
- **Verdict: GREEN** (one minor timing flake found, see F-1)

## Results

| Step | Result |
|------|--------|
| `flutter pub get` | OK ("Got dependencies!") |
| `dart format --output=none --set-exit-if-changed .` | exit 0, "Formatted 261 files (0 changed)" |
| `flutter analyze` | "No issues found! (ran in 11.7s)" |
| `melos run gen` + `git status --porcelain` | build_runner SUCCESS; `git status --porcelain` empty |
| `melos run test` run 1 | exit 0, all 6 packages pass |
| `melos run test` run 2 | exit 0 (2m04s), identical counts, no failures |
| Debug APK locally | not attempted (Gradle download is blocked in this sandbox, as in CP2); CI covers it |
| CI on main for 854e001 | run **44525869942**, completed, **success** (includes APK build and Kotlin tests). The run before it (fd97dc8, 44525829360) was `cancelled`, superseded by the newer push; 32dbb05 (44515815993) success. |

Pass lines, identical in both runs:

```
[storize_data]: +1064 ~1: All tests passed!
[storize_domain]: +118: All tests passed!
[storize_instagram]: +108: All tests passed!
[storize_model]: +73: All tests passed!
[storize_platform_android]: +69: All tests passed!
[storize_app]: +422 ~1: All tests passed!
```

## Test counts, CP2 vs CP3

| Package | CP2 | CP3 | Delta | Source |
|---------|-----|-----|-------|--------|
| storize_model | 73 | 73 | 0 | |
| storize_domain | 110 | 118 | +8 | T-010 port/fake changes |
| storize_data | 561 | 1064 (+1 skipped) | +503 | T-010, T-010a, T-012a, T-023, T-034 vault |
| storize_instagram | 1 | 108 | +107 | T-012 governor |
| storize_platform_android | 59 | 69 | +10 | T-010a storageStats |
| storize_app | 283 (+1 skipped) | 422 (+1 skipped) | +139 | T-034 lock |

No count dropped. Run 1 and run 2 matched.

## Flake analysis

Each test was run alone, repeatedly, on a loaded machine (load average about 7, other agents running).

**`storize_data/test/db/qa_perf_test.dart` "library kind=POST"** (budget 1000 ms), 5 runs, measured with 2500 rows:

| Run | 1 | 2 | 3 | 4 | 5 |
|-----|---|---|---|---|---|
| ms | 242 | 220 | 509 | 257 | 262 |

Median 257 ms, worst 509 ms, so the margin is 2x to 4.5x. The one earlier failure (1019 ms) was under full-suite load. Recommendation: raise the budget to 2000 ms. The query plan uses `idx_content_kind_posted_at`, so the check still catches a real regression (a full scan would be an order of magnitude slower), while load noise stops failing it.

**`storize_data/test/files/file_media_cache_test.dart` "chunks reach the file before the stream ends"**, 13 isolated runs (5 plus 8): **12 passed, 1 failed** (run 5 of the first batch, load average about 5 to 7). The failure message was not captured. The test adds a chunk, waits a fixed 100 ms, then asserts the `.part` file already has 4 bytes, so a slow file write under load can miss that window. It is a real, reproducible timing flake, rate roughly 1 in 13 under load. The suite never failed in the two full melos runs. Recommendation: replace the fixed 100 ms delay with a bounded poll (for example up to 2 s, checking every 10 ms, until `lengthSync() == 4`). That keeps the kill-safety assertion and removes the race. The test file is in the T-010 scope, so the fix belongs to the Lead or a developer.

## Cross-package checks

- **Pure-Dart guardrail:** no `package:flutter`, `dart:ui`, `storize_instagram` or `storize_platform_android` in `storize_domain` or `storize_model` (lib and pubspec): 0 hits.
- **Native code:** every `.kt`/`.gradle`/`.kts`/manifest/xml file outside `packages/storize_platform_android/` is in the `app/android/` host shell: `MainActivity.kt`, the three `AndroidManifest.xml` files, `styles.xml` (x2), the two gradle files, `launch_background.xml` (x2), `backup_rules.xml`, `data_extraction_rules.xml`. No business or plugin native code. See F-2.
- **Barrels:** a scratch test importing the data, domain, domain/testing, instagram, model and platform_android barrels unprefixed, and using one type from each, compiled and passed. A script that expands each barrel's exports found 0 duplicate type names across the six barrels. The scratch files were deleted and the tree is clean.
- **Secrets grep** (`sessionid=`, `csrftoken=`, `Bearer `, `ds_user_id=`, `-----BEGIN`, AWS and GitHub token patterns, `*.jks`/`*.keystore`/`*.pem`/`*.env`): one hit, `storize_instagram/test/governor/qa_attack_test.dart:654`, the literal `...?sessionid=SECRET`. It is an obvious fake test input for the redaction check. No real secrets. gitleaks is not installed locally; it runs in CI and CI passed.
- **`appLockTestBypassProvider`:** in `app/lib` and `packages/*/lib` it appears only in `lock_controller.dart`, at the definition (line 20, default `false`) and at its single read in the same file (line 102). No other `lib/` references and no production override. See F-3.
- **`print(` and `debugPrint(`** in `packages/*/lib` and `app/lib`: 0 hits.

## Findings

| ID | Severity | Finding |
|----|----------|---------|
| F-1 | Minor | `file_media_cache_test.dart` "chunks reach the file before the stream ends" is flaky under load (1 failure in 13 isolated runs) because of a fixed 100 ms wait. Replace it with a bounded poll. Also raise the `qa_perf_test` "library kind=POST" budget from 1000 ms to 2000 ms (measured 220 to 509 ms). |
| F-2 | Info | `app/android/` host shell (MainActivity, manifests, styles.xml, gradle) is outside the plugin. This is the standard Flutter layout and was already noted in CP2 F-1. |
| F-3 | Info | `appLockTestBypassProvider` is read by `lock_controller.dart` itself (line 102), in the same file as its definition. The default is `false` and nothing in `lib/` overrides it. This is acceptable, but a future change that overrides it in `lib/` would break the guardrail. |
| F-4 | Info | CI run for fd97dc8 shows `cancelled` (superseded by the 854e001 push). Not a failure. |
| F-5 | Info | No local APK build (Gradle download blocked). CI run 44525869942 covers it. |

## Regressions

None. No task caused a regression. New tasks are not blocked. F-1 is a test-robustness fix that can be scheduled with any follow-up.

## Verdict

**GREEN.** Format, analyze and codegen freshness are clean. The full suite passed twice with identical counts and no count drop. Barrels compile together with no export conflicts, the guardrail greps are clean, and CI on 854e001 is green.
