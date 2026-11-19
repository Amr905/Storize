# Checkpoint 1

- **Commit tested:** `ef64e0c6291952858263aefabfb547e1fa45c892` (main, detached worktree, clean `.dart_tool/` and `build/`)
- **Tasks covered:** T-001, T-003, T-024, T-004, T-007
- **Date:** 2026-11-19
- **Verdict: GREEN**

## Results

| Step | Result |
|------|--------|
| `flutter pub get` | OK |
| `dart format --output=none --set-exit-if-changed .` | OK, 112 files, 0 changed |
| `flutter analyze` | No issues found |
| `melos run gen` + `git status` | build_runner wrote 12 outputs; `git status` clean (generated code is up to date) |
| `melos run test` | exit 0, all 6 packages pass |
| `melos run golden:update` + `git status` | SUCCESS; `git status` clean (no golden changed) |
| Integration tests (new) | 21 / 21 pass |
| CI on GitHub (main, run 44461744450, `ef64e0c6`) | completed, **success** |

## Test counts versus baseline

| Package | Baseline | Actual | Note |
|---------|----------|--------|------|
| storize_model | 73 | 73 | match |
| storize_domain | 107 | 107 | match |
| storize_data | 101 | 101 (122 with the new integration file) | match; +21 are this checkpoint's tests |
| storize_app | 105 (+1 skipped) | 105 (+1 skipped) | match; the skip is the known pending UX decision |
| storize_platform_android | 3 | 3 | match |
| storize_instagram | 1 | 1 | match |

No differences to explain.

## Coverage (line, `flutter test --coverage`)

| Package | Lines | Coverage |
|---------|-------|----------|
| storize_model | 201/226 | 88.9% |
| storize_domain | 823/916 | 89.8% |
| storize_data | 104/106 | 98.1% (before the integration tests were added) |
| storize_app | 875/910 | 96.2% |
| storize_instagram | 0/0 | no executable lines yet (version constant only) |
| storize_platform_android | 0/0 | no executable lines yet |

Files below 80%, for later attention (no action needed now):
- model: `failure.dart` 35/53, `gallery_file.dart` 8/13.
- domain: `media_file.dart` 41/59, `content_with_media.dart` 3/17, `governor_lease.dart` 25/33, `exceptions.dart` 3/14, `clock.dart` 2/3, `content_repo.dart` 1/9.
- app: `date_header.dart` 13/27, `storize_colors.dart` 22/34, `main.dart` 2/3.

## Regressions

None. No task caused a regression.

## Cross-task integration

Test file: `packages/storize_data/test/integration/checkpoint1_test.dart`. 21 tests, all pass, analyze clean.

- **(a) Settings defaults.** `SharedPrefsSettingsRepo` (T-007, in-memory prefs) and `FakeSettingsRepo` (T-004) return equal `AppSettings` and agree on all 12 fields. Both match the spec defaults (30 / 180 min, notify flags true, others false or null). Both reject `storyIntervalMin: 10` with identical `problems`, and neither stores it. PASS.
- **(b) Enums.** All 15 model enums used by domain code (PlatformId, ContentKind, PostType, MediaType, TargetCategory, TargetStatus, AccountStatus, ContentStatus, MediaFileStatus, CheckScope, CheckTrigger, CheckResult, ExtractionMode, ActivityType, Severity) have a non-empty SCREAMING_SNAKE `dbValue`. The values are unique and round-trip through `fromDb`, and unknown or empty input throws `ArgumentError`. PASS.
  - `ExtractionPolicy` and `SessionReason` are intentionally Dart-only and have no `dbValue`. They are excluded.
- **(c) Barrel.** `package:storize_data/storize_data.dart` exports `SharedPrefsSettingsRepo` and `SettingsKeys` (12 keys). It imports unprefixed together with `storize_domain`, `storize_domain/testing.dart` and `storize_model` with no name clashes. PASS.

## CI

The latest main run is `ef64e0c6` (the tested commit): https://github.com/Amr905/Storize/actions/runs/44461744450. It was in progress at the first query and had completed with **success** by the first poll. The previous four main runs were also successes.

## Verdict

**GREEN.** Format, analyze, codegen freshness, golden stability, the full suite, the integration tests and CI all pass. All counts match their baselines.
