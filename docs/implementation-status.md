# Storize — Implementation Status

> Maintained by the **Lead Orchestrator**. Updated after every delegation, review, and checkpoint.
> Source of truth for task state. `TASKS.md` holds the specs; this file holds progress.
> Last update: 2026-11-19 06:05 (Cairo)

## Current state
- **Phase 5 running.** Toolchain is ready in the Claude workspace: Flutter 3.50.0 / Dart 3.14.0, melos 8.10.1, Android SDK 36. The repo `Amr905/Storize` is connected (push).
- Tasks done: **16 / 37** (+1 Could) · Checkpoint 1 GREEN · Checkpoint 2 GREEN · **Checkpoint 3 running** (after 15 done).

## Blockers
| ID | Blocker | Impact | Unblocks when |
|----|---------|--------|---------------|
| ~~ENV-1~~ | **Resolved 02:40** — network allowed; Flutter installed at `/opt/flutter`. (Was: no Flutter/Dart toolchain available.) The cloud workspace has no network for pub.dev or the Flutter SDK; the PC's device shell won't start (needs ~17 GB free) | Code can't be compiled or tested, so nothing can be verified | **Either** network access allows `storage.googleapis.com`, `pub.dev`, `pub.dartlang.org` (+ `dl.google.com`, `maven.google.com` for APK builds) **or** the PC has ~17 GB free and the device shell can install Flutter |
| ~~ENV-2~~ | **Resolved 02:35** — repo connected with push. (Was: pushing to `github.com/Amr905/Storize` was denied.) | No CI, no shared history | You explicitly authorize connecting the repo (with push access) for this session |
| P-3 | No dedicated Instagram test account yet | T-002 (critical path) can't start | You provide it (you log in yourself; never share the password with Claude) |
| P-4 / P-5 | Test phones / signing keystore | T-009, T-021, T-037 / T-036 | Later; not blocking the first tasks |

## Orchestration rules (from the user, 2026-11-19)
- Complexity → model: **Low (Tier S) → Haiku · Medium (M) and High (L) → Sonnet.** Review by the Lead (Opus).
- Specialists: **Backend Developer** (non-UI), **Frontend Developer** (UI), **QA Engineer** (independent verification, checkpoints, E2E).
- Each delegation carries: task ID, requirements, spec sections, acceptance criteria, file lock (relevant files).
- Implementation **and** automated tests are required. QA verifies, the Lead reviews, and then the task is `done`. A failure goes back to the developer with feedback, they fix it, and the tests are re-run.
- A task never starts until all its dependencies are `done`.
- **File locks:** a task may only touch the files in its lock. Two active tasks never share a file (see table below).
- **Full test-suite checkpoint after every 5 tasks marked done** (QA Engineer → `docs/05-reviews/CHECKPOINT-<n>.md`).

## Active file locks
| Task | Agent | Files / globs locked | Since |
|------|-------|----------------------|-------|
| (Lead) | — | `packages/storize_data/lib/storize_data.dart` barrel, all `pubspec.yaml` dependency changes, `pubspec.lock` | — |
| T-002 | backend-developer (sonnet) | `docs/03-specs/INSTAGRAM_EXTRACTION.md`, `docs/03-specs/CAPTURE_GUIDE.md`, `packages/storize_instagram/tool/**`, `packages/storize_instagram/test/fixtures/**`, `packages/storize_instagram/test/tool/**`, `packages/storize_instagram/assets/hook.js`, `app/lib/debug/**`, `app/lib/main_debug_inspector.dart`, `app/pubspec.yaml` + root `pubspec.lock` (**dependency owner this round**), `packages/storize_instagram/pubspec.yaml` | 03:10 |

## Task board
| ID | Title | Complexity | Model | Specialist | Depends on | Status | Attempts | Verified by / evidence |
|----|-------|-----------|-------|------------|------------|--------|----------|------------------------|
| T-001 | Workspace scaffold + CI | Medium | sonnet | Backend Developer | P-2 | **done** | 2 | QA PASS + CI [44431856003](https://github.com/Amr905/Storize/actions/runs/44431856003) · `05-reviews/T-001.md` |
| T-002 | Extraction spike: watch the real pages | High | sonnet | Backend Developer | T-001, P-3 | **blocked (UD-2: 2 failed QA rounds on a High task → user decides Sonnet vs Opus)** | 4 | — |
| T-003 | `storize_model`: entities, enums, Result/Failure | Low | haiku | Backend Developer | T-001 | **done** | 3 | QA PASS + CI [44455784605](https://github.com/Amr905/Storize/actions/runs/44455784605) · `05-reviews/T-003.md` |
| T-004 | `storize_domain` ports + test fakes | Medium | sonnet | Backend Developer | T-003 | **done** | 2 | QA PASS + CI [44458434199](https://github.com/Amr905/Storize/actions/runs/44458434199) · `05-reviews/T-004.md` |
| T-005 | drift schema v1 + DAOs + migration harness | High | sonnet | Backend Developer | T-004 | **done** | 1 | QA PASS + CI [44463661224](https://github.com/Amr905/Storize/actions/runs/44463661224) · `05-reviews/T-005.md` |
| T-006 | Repository implementations (streams) | Medium | sonnet | Backend Developer | T-005 | **done** | 2 | QA PASS (561 data tests) + CI [44512427485](https://github.com/Amr905/Storize/actions/runs/44512427485) · `05-reviews/T-006.md` |
| T-007 | SettingsRepo (shared_preferences, allowed values) | Low | haiku | Backend Developer | T-004 | **done** | 2 | QA PASS (after F-1 fix) + CI [44461140658](https://github.com/Amr905/Storize/actions/runs/44461140658) · `05-reviews/T-007.md` |
| T-008 | SessionVault (flutter_secure_storage) | High | sonnet | Backend Developer | T-004 | **done** | 2 | QA PASS + CI [44465551564](https://github.com/Amr905/Storize/actions/runs/44465551564) · `05-reviews/T-008.md` |
| T-009 | Native plugin `storize_platform_android` | High | sonnet | Backend Developer | T-001, P-4 | **done** (device checks → P-4) | 4 | QA PASS + CI [44510544819](https://github.com/Amr905/Storize/actions/runs/44510544819) · `05-reviews/T-009.md` |
| T-010 | GalleryStore + MediaCache (Dart side) | Medium | sonnet | Backend Developer | T-009, T-004 | **done** | 2 | QA PASS (+108 tests) + CI [44514083877](https://github.com/Amr905/Storize/actions/runs/44514083877) · `05-reviews/T-010.md` |
| T-010a | StorageInfo via plugin `storageStats` + T-010 minor fixes | Medium | sonnet | Backend Developer | T-010 | **done** | 1 | QA PASS + CI [44523285849](https://github.com/Amr905/Storize/actions/runs/44523285849) · `05-reviews/T-010a.md` |
| T-011 | DiagnosticLog + redaction + crash hooks | Medium | sonnet | Backend Developer | T-004 | todo | — | — |
| T-012 | RequestGovernor + `governor_lease` | High | sonnet | Backend Developer | T-005 | **done** | 2 | QA PASS r2 (+92 tests) + CI [44513670058](https://github.com/Amr905/Storize/actions/runs/44513670058) · `05-reviews/T-012.md` |
| T-012a | Lease clock-skew in repos + limit-record retry | Medium | sonnet | Backend Developer | T-012, T-006 | **done** | 1 | QA PASS + CI [44517651587](https://github.com/Amr905/Storize/actions/runs/44517651587) · `05-reviews/T-012a.md` |
| T-013 | DirectExtractor + mappers (user, stories, posts, session) | High | sonnet | Backend Developer | T-002, T-012 | todo | — | — |
| T-014 | PageExtractor (headless WebView fallback) | High | sonnet | Backend Developer | T-013 | todo | — | — |
| T-015 | InstagramPlatform: mode selection, failure map, openMedia | Medium | sonnet | Backend Developer | T-013, T-014 | todo | — | — |
| T-016 | Use case: AddTarget (validation, watermark) | Medium | sonnet | Backend Developer | T-006, T-015 | todo | — | — |
| T-017 | Use case: RunCheck (stories & posts) | High | sonnet | Backend Developer | T-006, T-015, T-012 | todo | — | — |
| T-018 | Use case: DownloadPending | High | sonnet | Backend Developer | T-010, T-006, T-015 | todo | — | — |
| T-019 | Use cases: DeleteContent, RemoveTarget, ApplyRetention | Medium | sonnet | Backend Developer | T-010, T-006 | todo | — | — |
| T-020 | Use cases: DetectGaps, ComputeStorage, VerifySession | Medium | sonnet | Backend Developer | T-006, T-015 | todo | — | — |
| T-021 | Scheduler + background dispatcher | High | sonnet | Backend Developer | T-017, T-018, T-019, T-020, T-007 | todo | — | — |
| T-022 | NotificationService (channels, grouping, deep links) | Medium | sonnet | Backend Developer | T-021, T-025 | todo | — | — |
| T-023 | UpdateChecker (GitHub Releases API) | Low | haiku | Backend Developer | T-006 | **done** | 2 | QA PASS + r2 (URL host pinning) + CI [44521600894](https://github.com/Amr905/Storize/actions/runs/44521600894) · `05-reviews/T-023.md` |
| T-024 | Design system: theme tokens + shared components + goldens | Medium | sonnet | Frontend Developer | T-001 | **done** | 2 | QA PASS + CI [44457715432](https://github.com/Amr905/Storize/actions/runs/44457715432) · `05-reviews/T-024.md` |
| T-025 | App shell: router, bottom nav, deep links, UiState pattern, l10n | Medium | sonnet | Frontend Developer | T-024, T-004 | **done** | 2 | QA PASS + CI [44464531584](https://github.com/Amr905/Storize/actions/runs/44464531584) · `05-reviews/T-025.md` |
| T-026 | Onboarding: S-01 risk, S-02 login + SessionCapture, S-03 setup | High | sonnet | Frontend Developer | T-025, T-008, T-009, T-020 | todo | — | — |
| T-027 | Library S-04 (stories/posts) + filters S-05 + selection/delete | Medium | sonnet | Frontend Developer | T-025, T-019 | todo | — | — |
| T-028 | Story viewer S-06 | Medium | sonnet | Frontend Developer | T-027 | todo | — | — |
| T-029 | Post viewer S-15 | Medium | sonnet | Frontend Developer | T-027 | todo | — | — |
| T-030 | Targets S-07 + Add target S-08 | Medium | sonnet | Frontend Developer | T-025, T-016, T-021 | todo | — | — |
| T-031 | Target detail S-09 + Remove dialog S-10 | Medium | sonnet | Frontend Developer | T-030, T-019 | todo | — | — |
| T-032 | Activity S-11 | Medium | sonnet | Frontend Developer | T-025, T-020 | todo | — | — |
| T-033 | Settings S-12 + Instagram account S-13 | Medium | sonnet | Frontend Developer | T-025, T-021, T-020, T-023 | todo | — | — |
| T-034 | App lock S-14 + PIN setup + lock gate | High | sonnet | Frontend Developer | T-025, T-008 | **done** | 2 | QA PASS r2 (3 majors fixed) + CI [44523291566](https://github.com/Amr905/Storize/actions/runs/44523291566) · `05-reviews/T-034.md` |
| T-035 | *(Could)* ExportZip | Medium | sonnet | Frontend Developer | T-031 | todo | — | — |
| T-036 | Release pipeline (`release.yml`) + README install guide | Medium | sonnet | Backend Developer | T-001, P-5 | todo | — | — |
| T-037 | End-to-end tests + device soak checklist | Medium | sonnet | QA Engineer | T-021…T-034 | todo | — | — |
| T-038 | Accessibility & RTL pass + string audit | Low | haiku | Frontend Developer | T-026…T-034 | todo | — | — |

## Carry-forward notes (from QA findings)
- **T-005:** enforce `CHECK (track_stories + track_posts + track_reels >= 1)` in SQL (T-004 F-1); `check_run.scope` only STORIES/POSTS, never ALL (T-003 F-3).
- **T-006:** keep target updates short / consider partial updates for watermark & last-checked (T-004 F-2); add `watchUnviewedCounts()` if NFR-12 needs it (F-3).
- **T-016/T-030:** validate ≥1 track flag in the use case and UI (F-1).
- **T-020:** DetectGaps de-dups GAP events itself via ActivityRepo.
- **T-025 (done):** UI guidance — call `watchX()` once per consumer (single-subscription streams, F-4).
- **T-006:** DAO→domain mapping duties from T-005 QA: leave `id` absent in companions; UTC ms dates; JSON encode `extras`/`payload`; `StateError` on 0-row updates; map SQLite extended code 2067 (UNIQUE) → `DuplicateEntityException`; derive `ActivityDao.watchRecent` `since` from the Clock (F-4); debounce/page the library stream (F-1).
- **T-021:** call `DartPluginRegistrant.ensureInitialized()` before `StorizeDatabase.open()` in the background isolate; `close()` at the end of the task; device-test `open()`.
- **T-034:** `resetOnError` in flutter_secure_storage wipes **all** entries incl. the PIN hash → treat "appLock = true but no PIN hash" as a reset state (force new PIN / clear flag + tell the user); never unlock silently (T-008 QA N-1).
- **T-010 / T-026:** request `WRITE_EXTERNAL_STORAGE` at runtime on API ≤ 28 (S-03 card); store `relativePath` from `insert` (video may fall back to `Movies/Storize/<dir>/` if MediaStore rejects `Pictures/` for video — T-009).
- **T-012a (follow-up, Medium):** lease clock-skew in the repos — a lease with `expiresAt > now + ttl` counts as expired; `release` sets `expiresAt` to the epoch. Touches the T-005 DAO, the T-006 drift repo and the T-004 fake (T-012 QA F2). Also: bounded retry when recording a rate limit fails (T-012 QA N2); swap `_SkewTolerantRepo` in the QA test for the plain fake.
- **T-013/T-014:** never start unawaited governed work inside `RequestGovernor.run`'s `call` (zone guard false positive, T-012 QA N1).
- **Watch:** `storize_data/test/db/qa_perf_test.dart` "library kind=POST" took 1019 ms vs 1000 ms under full-suite load once (T-012 QA N4); raise the budget if it recurs.
- **T-017/T-018:** `decodeJsonMap(null)` returns an unmodifiable map — copy before mutating (T-006 QA). `watchRecent` window is fixed at subscribe time (accepted).
- **T-010a (follow-up, Medium):** plugin `storageStats` method (StatFs) on `storize/media` + `PluginStorageInfo` in storize_data (T-010 gap). Also: add the 46 missing Cf code points to the test mirror `plugin_rules.dart` (T-010 QA F-1); align `GalleryStore.exists/size` docs + fake with the real error set (F-4).
- **T-018:** never `append` the same media id concurrently (T-010 QA F-2). **T-021:** call `MediaCache.cleanupOrphans()` at start.
- **T-010 (Lead-approved port change):** gallery exceptions (`GalleryPermissionDenied`, `GalleryStorageFull`, `GalleryWriteFailed`) move to `storize_domain`.
- **T-024b (new follow-up, Low):** move `app/lib/ui/storize_strings.dart` labels into ARB/AppLocalizations; delete the class; update `app/test/ui` goldens to use the l10n delegates (T-025 QA F-4).

## Pending user decisions
| ID | Decision | Options | Blocks |
|----|----------|---------|--------|
| UD-2 | T-002 sanitizer failed QA twice (round 1 value leaks → fixed; round 3: username-like object KEYS leak, QA-10; doc_id not shape-checked, QA-11) | continue on Sonnet with the precise fix spec (Lead rec.) · switch T-002 to Opus | T-002 → T-013/T-014 (critical path) |
| UD-1 | Light `primary` #D9481F fails WCAG AA (4.29:1 white-on, 4.05:1 as text) | keep · #C93F17 (rec.) · #C2410C · #BF3D16 | follow-up T-024a (token + UX.md + goldens) |

## Checkpoints
| # | After tasks | Result | Report |
|---|-------------|--------|--------|
| 1 | T-001, T-003, T-024, T-004, T-007 | **GREEN** — 0 regressions; counts = baselines; gen/goldens stable; +21 integration tests; coverage 89–98%; CI green | `05-reviews/CHECKPOINT-1.md` |
| 2 | (next 5 done) | — | — |

## Log
- 2026-11-19 01:50 — Phase 5 kicked off. Specialist agents defined (backend-developer, frontend-developer, qa-engineer).
  Environment check: no Flutter toolchain in the cloud workspace (pub.dev unreachable), device shell unavailable (disk space),
  repo connection denied → T-001 marked **blocked (ENV)**. No code written.
- 2026-11-19 02:45 — User allowed network + connected GitHub. Flutter 3.50.0 installed in the workspace; smoke test (pub get, analyze, test) passed. The repo was empty, so `main` is seeded with the approved docs and agent definitions. `gh` CLI has no auth, so CI results can't be read from here; **verification runs locally in the workspace**, and CI is an extra gate.
- 2026-11-19 02:50 — T-001 delegated to backend-developer (sonnet, Medium).
- 2026-11-19 02:55 — QA: PASS (AC3 pending; Gradle hosts are blocked in the workspace). CI run 1 failed at the APK build (AGP 9 resValues) → returned to the developer.
- 2026-11-19 03:05 — Round 2 fixed; CI run 2 all green (APK + gitleaks). **T-001 done**, merged to main. Note: APK builds are verified via GitHub Actions on `t-*` branches.
- 2026-11-19 03:10 — Wave 2 started in parallel (separate worktrees): T-003 (haiku), T-024 (sonnet), T-002 prep (sonnet; the capture itself needs the user's Instagram test account).
- 2026-11-19 03:20 — T-003 round 1 → Lead REQUEST_CHANGES (RemoteUser missing followedByViewer/blockedByViewer; replace ignore_for_file with @immutable + `meta`). Round 2 fixed; 61 tests pass.
- 2026-11-19 03:35 — T-003 QA: PASS with Medium F-1 (nested extras maps lose String key type). Lead requires the fix before merge (round 3).
- 2026-11-19 ~03:40 — T-024 and T-002 agents stopped by the account usage limit (5-hour window). Work saved uncommitted.
- 2026-11-19 06:05 — User: "continue". Resumed T-024 and T-002 in place; T-003 round 3 started.
- 2026-11-19 06:20 — T-003 round 3 fixed F-1; CI green → **T-003 done**, merged. T-024 delivered (66 app tests, 36 goldens) → QA started.
- 2026-11-19 06:25 — T-004 delegated (backend-developer, sonnet, Medium).
- 2026-11-19 06:40 — T-002 prep: CI APK failed (flutter_inappwebview 6.1.5 incompatible with AGP 9) → round 2 pins 6.2.0-beta.3 + INTERNET permission. Next CI failed on a transient plugins.gradle.org resolution error; re-run green.
- 2026-11-19 06:55 — T-024 round 2 (tag colours per mockup, contrast test) → CI green → **T-024 done**, merged. UD-1 raised to the user.
- 2026-11-19 06:55 — T-004 round 2 (StorageInfo/StoragePolicy, MediaCache, TargetLimits approved by the Lead) → QA started. T-002 prep → QA started (adversarial sanitizer tests).
- 2026-11-19 07:15 — T-004 QA PASS (107 tests), CI green → **T-004 done**, merged. T-002 prep QA **FAIL** (sanitizer leaks: URL-encoded/nested-JSON session ids, usernames in paths, PII fields) → round 3 default-deny redesign.
- 2026-11-19 07:25 — Lead added wave-3 dependencies centrally (drift 2.35, drift_flutter, shared_preferences, path_provider, flutter_secure_storage 11.2, logging, flutter_riverpod 3.5, go_router 18.1, flutter_localizations, intl) — CI green incl. APK.
- 2026-11-19 07:30 — Wave 3: T-005 (sonnet), T-007 (haiku), T-025 (sonnet).
- 2026-11-19 08:05 — T-007: developer stopped correctly at a lint needing a dev-dependency (out of lock); Lead added `shared_preferences_platform_interface` (dev) → analyze clean, 20 tests → QA started.
- 2026-11-19 08:10 — T-002 prep round 3 re-verification: **FAIL** (QA-10 blocker: username-like object keys survive; QA-11 medium: doc_id/query_hash shape). Second failed QA round on a High task → per protocol, **stopped and asked the user (UD-2)**.
- 2026-11-19 08:30 — T-007 QA FAIL (F-1 timestamp overflow) → round 2 fixed → CI green → **T-007 done**, merged; Lead wired `storize_data` barrel. T-005 and T-025 delivered → QA. **Checkpoint 1 started.**
- 2026-11-19 08:50 — **Checkpoint 1 GREEN** (commit ef64e0c): no regressions, +21 integration tests, CI green. Merged.
- 2026-11-19 08:55 — T-008 (vault) and T-009 (native gallery plugin) started (sonnet, High). T-009's on-device check (P-4) is deferred to the user.
- 2026-11-19 09:40 — T-005 QA PASS (41 QA tests, perf OK) → **done**. T-025 QA PASS → round 2 (unknown-route fallback, tab back) → **done**. Both merged; Lead wired `db/db.dart` into the storize_data barrel; main full suite green (795 tests). UX.md + TECH_SPEC §3 notes updated.
- 2026-11-19 09:40 — T-008 QA PASS (leak hunt clean) with Low F-1 (capturedAt range) → round 2 fixed + Lead-approved shared `SessionStore.requiredCookies` (fake parity). T-009 delivered; CI compiled the Kotlin first time → QA started.
- 2026-11-19 09:55 — T-008 round 2 CI green → **T-008 done**, merged; Lead wired `security/security.dart`; main suite green. T-009 round 2 (URI confinement F2 + F3–F8) delivered; Lead added a CI step for the plugin's Kotlin JVM tests → test sources failed to compile (`createTempDir` deprecated-as-error); main Kotlin compiled.
- 2026-11-19 ~10:00–12:40 — paused: account usage limit (5-hour window).
- 2026-11-19 12:50 — Resumed. T-009 round 3 sent. T-006 (repos) and T-012 (governor) started (sonnet).
- 2026-11-19 13:45 — T-009 round 4 (F9: strict item URIs + single scoped delete) → CI green (Kotlin tests run in CI) → QA PASS → **T-009 done**, merged; main green. Device checks tracked under P-4.
- 2026-11-19 13:45 — T-012 QA PASS with findings (clock skew, lost rate-limit report, starvation, uncapped retryAfter, double-report) → round 2. T-006 round 2 (fake fixes) → QA. T-010 started.
- 2026-11-19 14:20 — T-006 QA PASS + CI green → **T-006 done**, merged; Lead exported `repo/repo.dart`; main suite green (data 561, domain 110, model 73, plugin 59, app 283). **10/37 → Checkpoint 2** started. T-012 round 2 delivered (51bff80, pushed) → QA re-verify. T-010 delivered → round 2 (exceptions to domain, approved port change); StorageInfo split to T-010a.
- 2026-11-19 14:45 — **Checkpoint 2 GREEN** (`05-reviews/CHECKPOINT-2.md`): format/analyze/gen clean, all suites pass twice (no flakes), no count regressions, CI green. Info only: host `app/android` shell is outside the plugin (expected). T-010 round 2 → QA. T-012a started.
- 2026-11-19 15:05 — T-012 round 2 QA PASS + CI green → **T-012 done** (11/37), merged; Lead exported the governor from `storize_instagram.dart`; main green (instagram 92). Lead added deps `cryptography` (data, app) and `local_auth` (app) for T-034. T-010 → QA.
- 2026-11-19 15:20 — T-010 QA PASS (0 blocker/major, 4 minor) + CI green → **T-010 done** (12/37), merged; Lead exported `files/files.dart`; main green (data 750, domain 116). Lead added dep `dio` (storize_data) for T-023. Started T-012a, T-010a, T-023, T-034.
- 2026-11-19 16:40 — T-012a QA PASS + CI → **done**. T-023 QA PASS, r2 fixed html_url host pinning (Medium) → CI → **done**. T-010a QA PASS, Kotlin verified in CI → **done**. T-034 QA found 3 majors (fail-open default, AppCompat theme, reset state) → r2 → QA PASS + CI (APK) → **done**. All merged; Lead exported `update/update.dart` and `security/pin_vault.dart`; main green (data 1064, domain 118, instagram 108, model 73, plugin 69, app 422). **16/37 → Checkpoint 3.**
