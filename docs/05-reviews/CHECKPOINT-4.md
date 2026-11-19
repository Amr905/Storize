# Checkpoint 4

- **Commit tested:** `8a621b4` (main, clean detached worktree `/home/claude/wt/checkpoint-4`)
- **Tasks covered (20 done):** the 16 from CP3 plus T-011, T-019, T-024b, T-019a (confirmed against `docs/implementation-status.md`: T-011 QA PASS r3, T-019 PASS r2, T-024b PASS, T-019a PASS r2).
- **Date:** 2026-11-19
- **Verdict: GREEN** (one load-sensitive timing flake observed in CI on a previous commit, see F-1)

## Results

| Step | Result |
|------|--------|
| `flutter pub get` | OK ("Got dependencies!") |
| `dart format --output=none --set-exit-if-changed .` | exit 0, "Formatted 298 files (0 changed)" |
| `flutter analyze` | "No issues found! (ran in 2.8s)" |
| `melos run gen` + `git status --porcelain` | build_runner SUCCESS; `git status --porcelain` empty |
| `melos run test` run 1 | exit 0, all 6 packages pass |
| `melos run test` run 2 | exit 0, identical counts, no failures |
| gitleaks `dir --redact .` (v8.24.2) | "scanned ~411189893 bytes ... no leaks found" |
| gitleaks `git --redact .` (full history) | "139 commits scanned ... no leaks found" |
| Debug APK locally | not attempted (Gradle download blocked in this sandbox, as in CP2/CP3); CI covers it |
| CI on main for 8a621b4 | run **44588301184**, completed, **success** (first poll showed in_progress, a later poll showed success) |

Pass lines (run 1, then run 2):

```
run 1
[storize_data]: 01:07 +1423 ~4: All tests passed!
[storize_domain]: 00:12 +210: All tests passed!
[storize_app]: 01:39 +458 ~1: All tests passed!
[storize_instagram]: 00:12 +108: All tests passed!
[storize_model]: 00:04 +73: All tests passed!
[storize_platform_android]: 00:01 +69: All tests passed!
run 2
[storize_data]: 00:59 +1423 ~4: All tests passed!
[storize_domain]: 00:09 +210: All tests passed!
[storize_instagram]: 00:10 +108: All tests passed!
[storize_app]: 01:28 +458 ~1: All tests passed!
[storize_model]: 00:03 +73: All tests passed!
[storize_platform_android]: 00:01 +69: All tests passed!
```

## Test counts, CP3 vs CP4

| Package | CP3 | CP4 | Delta | Source |
|---------|-----|-----|-------|--------|
| storize_model | 73 | 73 | 0 | |
| storize_domain | 118 | 210 | +92 | T-019 use cases, T-011 diagnostic_log port and fake, T-019a |
| storize_data | 1064 (~1) | 1423 (~4) | +359 | T-011 log/redactor, T-019a thumbnail delete and sweeps |
| storize_instagram | 108 | 108 | 0 | |
| storize_platform_android | 69 | 69 | 0 | |
| storize_app | 422 (~1) | 458 (~1) | +36 | T-024b l10n and goldens, T-011 crash hooks |

No count dropped. Run 1 and run 2 matched. Skipped tests in storize_data went from 1 to 4 (+3); I did not trace which tests they are (see F-5).

## Flake analysis

**Local:** two full melos runs, identical counts, no failures.

**ReDoS budgets** (`storize_data/test/log`, now 5000 ms), three runs, worst single test each run:

| Run | 1 | 2 | 3 |
|-----|---|---|---|
| "ReDoS (all suites combined, 100 KB inputs) worst case" (ms) | 2378 | 2269 | 2300 |
| "1 MB input stays under 5 s (linearity check)" (ms) | 1419 | 1446 | 1460 |

Worst local time is 2.4 s against a 5 s budget (about 2x margin for the combined test; 3.4x for the 1 MB test), on a machine with load average 1 to 2.

**CI evidence of a real flake:** CI run 44584991350 (commit 8f6d02c, a docs-only commit whose code equals the parent) failed in "Tests" with
`qa_round2_test.dart: ReDoS (round 2) worst case is reported 1 MB input stays under 5 s (linearity check)`, `Expected: a value less than <5000>  Actual: <5221>`.
Locally that test takes about 1.4 s, so the CI runner (running packages in parallel) was about 3.7x slower. The next main run (5e4135a, 44585800663) and the tested commit's run (8a621b4, 44588301184) both passed. So the 5 s budget can still be exceeded on a loaded runner. See F-1.

**`qa_perf_test` "library kind=POST"** (budget now 2000 ms, F-1 of CP3 applied), 3 runs: 166, 163, 159 ms (worst 166 ms). Margin about 12x. The slowest item in that file is `setUpAll` at 547 to 641 ms (seeding 2500 rows); the file as a whole runs in about 1 s.

The CP3 flake candidate `file_media_cache_test` "chunks reach the file before the stream ends" did not fail in the two full runs. I did not re-run it in isolation this time, so I cannot say whether the 100 ms wait was fixed.

## Cross-package checks

- **Pure-Dart guardrail:** no `package:flutter`, `dart:ui` or `dart:io` in `storize_model/lib` or in `storize_domain/lib`, with one exception: `packages/storize_domain/lib/src/testing/fake_gallery_store.dart` imports `dart:io` (exported only through `storize_domain/testing.dart`, not the main barrel; it dates from T-004/T-010 and was not introduced by the new work). The new use cases (`delete_content`, `remove_target`, `apply_retention`) and the diagnostic_log port have no `dart:io`. See F-2.
- **Barrels:** a scratch test in `app/test/` imported the data, domain, domain/testing, instagram, model and platform_android barrels unprefixed and referenced a type from four of them (DiagnosticLog, FakeGalleryStore, RequestGovernor, StorageInfo). It compiled and passed. A grep of top-level class, enum, mixin, typedef and extension-type names found 0 names declared in more than one package's `lib/`. The scratch file is deleted and `git status --porcelain` was empty afterwards. (Limit: name collisions in re-exported or private `src/` names are covered only by the declaration scan.)
- **`print(` and `debugPrint(` in `lib/`:** 1 hit, `packages/storize_data/lib/log/file_diagnostic_log.dart:43`, `_debugPrintLine(String line) => debugPrint(line)`. This is the diagnostics debug console sink (default `consoleSink`, only active when `console` is true); accepted. 0 other hits.
- **`appLockTestBypassProvider`:** only in `app/lib/features/lock/lock_controller.dart` at the definition (line 20, default `false`) and the single read (line 102). No override in `lib/`. Unchanged from CP3.
- **`package:storize_domain/src/` imports outside `storize_domain`:** 0 files.
- **Secrets:** gitleaks clean on the working tree and on all 139 commits.

## Findings

| ID | Severity | Finding |
|----|----------|---------|
| F-1 | Minor | The ReDoS wall-clock assertions in `storize_data/test/log/qa_round2_test.dart` (and the 5000 ms budgets in `qa_redactor_adversarial_test.dart`) failed once in CI (run 44584991350, 5221 ms vs 5000 ms) although they take 1.4 to 2.4 s locally. Recommendation: raise the budgets to about 15 s (catastrophic backtracking is orders of magnitude slower), or assert a time ratio between a 100 KB and 1 MB input instead of an absolute time. Not a product bug. The test files are outside this task's scope, so the fix belongs to the Lead or a developer. |
| F-2 | Info | `storize_domain/lib/src/testing/fake_gallery_store.dart` imports `dart:io`. It is only reachable from `storize_domain/testing.dart`, but it means the `testing` barrel is not pure Dart (it can not be used from a web or isolate-free target). Acceptable for an Android-only app; note it if the guardrail text is made stricter. |
| F-3 | Info | The one `debugPrint` in `lib/` is the accepted diagnostics console sink. |
| F-4 | Info | No local APK build (Gradle download blocked); CI run 44588301184 covers it. |
| F-5 | Info | storize_data skipped tests rose from 1 to 4 (`~4`). I did not trace them. The Lead may want to confirm they are intentional skips. |
| F-6 | Info | CI run 44584991350 (8f6d02c) failed, as described in F-1, and is superseded by two green runs on later commits. |

## Regressions

None. No task caused a regression in the full suite, format, analyze, codegen freshness or gitleaks. New tasks are not blocked. F-1 can be scheduled with any follow-up.

## Verdict

**GREEN.** Format, analyze and codegen are clean. The full suite passed twice with identical counts and no count drop (domain +92, data +359, app +36). Barrels compile together with no duplicate names, guardrail greps are clean apart from the known `dart:io` in the testing fake, gitleaks is clean on the tree and the history, and CI on 8a621b4 (run 44588301184) is success.
