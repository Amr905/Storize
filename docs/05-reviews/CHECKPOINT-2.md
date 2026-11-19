# Checkpoint 2

- **Commit tested:** `51932bcb6372d2dbb512a49093329a52e6665f8e` (main, clean detached worktree)
- **Tasks covered (10 done):** T-001, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-024, T-025 (list confirmed in `docs/implementation-status.md`)
- **Date:** 2026-11-19
- **Verdict: GREEN**

## Results

| Step | Result |
|------|--------|
| `flutter pub get` | OK ("Got dependencies!") |
| `dart format --output=none --set-exit-if-changed .` | exit 0, 208 files, 0 changed |
| `flutter analyze` | No issues found |
| `melos run gen` + `git status --porcelain` | build_runner wrote 121 outputs; `git status` empty (generated code up to date) |
| `melos run test` (run 1) | exit 0, all 6 packages pass |
| `melos run test` (run 2, flake check) | exit 0, identical counts, no flaky test seen |
| Debug APK `flutter build apk --debug --flavor dev` | Not feasible here: Gradle wrapper cannot download the distribution (network blocked, `GradleWrapperMain` download exception). Used CI instead. |
| CI on main for 51932bc | run 44513898175, completed, **success** (previous main run 44512107469 `ef39c70` also success) |

## Test counts versus Checkpoint 1

| Package | Checkpoint 1 | Checkpoint 2 | Note |
|---------|--------------|--------------|------|
| storize_model | 73 | 73 | match |
| storize_domain | 107 | 110 | +3 (T-006 port/fake additions) |
| storize_data | 101 (122 with integration file) | 561 | +T-005 DAOs/migrations, T-006 repos, T-007, T-008 vault |
| storize_app | 105 (+1 skipped) | 283 (+1 skipped) | +T-025 shell/router/l10n; the skip is unchanged |
| storize_platform_android | 3 | 59 | +T-009 plugin Dart tests |
| storize_instagram | 1 | 1 | match |

No count dropped. Run 1 and run 2 gave the same numbers.

## Cross-package checks

- **Pure-Dart guardrail:** no `package:flutter`, `dart:ui`, `storize_instagram` or `storize_platform_android` import or dependency in `storize_domain` or `storize_model` (lib and pubspec). The only "instagram" hits are doc comments and the `PlatformId.instagram` enum value, which is allowed.
- **Native code:** all `.kt`/`.java`/gradle/manifest files outside `packages/storize_platform_android` are the standard Flutter host shell in `app/android/` (`build.gradle.kts`, `settings.gradle.kts`, manifests, a `MainActivity.kt` host stub). No plugin or business native code. See F-1.
- **Barrels:** a scratch test importing `storize_data`, `storize_domain`, `storize_domain/testing.dart` and `storize_model` (all prefixed) compiled and passed. It was deleted afterwards and the tree is clean.
- **Secrets grep** (`sessionid=`, `csrftoken=`, `Bearer `, `ds_user_id=`, `-----BEGIN`, `*.jks`/`*.keystore`) over tracked files: 0 matches. gitleaks is also a CI step and CI passed.

## Findings

| ID | Severity | Finding |
|----|----------|---------|
| F-1 | Info | `app/android/` contains the Flutter host shell Kotlin/Gradle files. This is the standard `flutter create` layout and not a guardrail breach. If the Lead wants a strict reading of "native code only in the plugin", clarify the guardrail wording in CLAUDE.md. |
| F-2 | Info | The local debug APK build cannot run in this sandbox (Gradle distribution download blocked). APK coverage rests on CI. |

## Regressions

None. No task caused a regression. New tasks are not blocked.

## Verdict

**GREEN.** Format, analyze, codegen freshness, the full suite (twice, stable), barrel compilation, guardrail greps and CI all pass. No test count decreased.
