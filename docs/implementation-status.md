# Storize — Implementation Status

> Maintained by the **Lead Orchestrator**. Updated after every delegation, review, and checkpoint.
> Source of truth for task state. `TASKS.md` holds the specs; this file holds progress.
> Last update: 2026-11-19 06:05 (Cairo)

## Current state
- **Phase 5 running.** Toolchain is ready in the Claude workspace: Flutter 3.50.0 / Dart 3.14.0, melos 8.10.1, Android SDK 36. The repo `Amr905/Storize` is connected (push).
- Tasks done: **2 / 37** (+1 Could) · Next checkpoint: after 5 verified tasks (3 to go).

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
| T-024 | frontend-developer (sonnet) | `app/lib/ui/**`, `app/test/ui/**` (incl. goldens). **No pubspec changes** (ask the Lead) | 03:10 |
| T-004 | backend-developer (sonnet) | `packages/storize_domain/**` (incl. a package-level `analysis_options.yaml`) | 06:25 |
| T-002 | backend-developer (sonnet) | `docs/03-specs/INSTAGRAM_EXTRACTION.md`, `docs/03-specs/CAPTURE_GUIDE.md`, `packages/storize_instagram/tool/**`, `packages/storize_instagram/test/fixtures/**`, `packages/storize_instagram/test/tool/**`, `packages/storize_instagram/assets/hook.js`, `app/lib/debug/**`, `app/lib/main_debug_inspector.dart`, `app/pubspec.yaml` + root `pubspec.lock` (**dependency owner this round**), `packages/storize_instagram/pubspec.yaml` | 03:10 |

## Task board
| ID | Title | Complexity | Model | Specialist | Depends on | Status | Attempts | Verified by / evidence |
|----|-------|-----------|-------|------------|------------|--------|----------|------------------------|
| T-001 | Workspace scaffold + CI | Medium | sonnet | Backend Developer | P-2 | **done** | 2 | QA PASS + CI [44431856003](https://github.com/Amr905/Storize/actions/runs/44431856003) · `05-reviews/T-001.md` |
| T-002 | Extraction spike: watch the real pages | High | sonnet | Backend Developer | T-001, P-3 | in_progress | 1 | — |
| T-003 | `storize_model`: entities, enums, Result/Failure | Low | haiku | Backend Developer | T-001 | **done** | 3 | QA PASS + CI [44455784605](https://github.com/Amr905/Storize/actions/runs/44455784605) · `05-reviews/T-003.md` |
| T-004 | `storize_domain` ports + test fakes | Medium | sonnet | Backend Developer | T-003 | in_progress | 1 | — |
| T-005 | drift schema v1 + DAOs + migration harness | High | sonnet | Backend Developer | T-004 | todo | — | — |
| T-006 | Repository implementations (streams) | Medium | sonnet | Backend Developer | T-005 | todo | — | — |
| T-007 | SettingsRepo (shared_preferences, allowed values) | Low | haiku | Backend Developer | T-004 | todo | — | — |
| T-008 | SessionVault (flutter_secure_storage) | High | sonnet | Backend Developer | T-004 | todo | — | — |
| T-009 | Native plugin `storize_platform_android` | High | sonnet | Backend Developer | T-001, P-4 | todo | — | — |
| T-010 | GalleryStore + MediaCache (Dart side) | Medium | sonnet | Backend Developer | T-009, T-004 | todo | — | — |
| T-011 | DiagnosticLog + redaction + crash hooks | Medium | sonnet | Backend Developer | T-004 | todo | — | — |
| T-012 | RequestGovernor + `governor_lease` | High | sonnet | Backend Developer | T-005 | todo | — | — |
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
| T-023 | UpdateChecker (GitHub Releases API) | Low | haiku | Backend Developer | T-006 | todo | — | — |
| T-024 | Design system: theme tokens + shared components + goldens | Medium | sonnet | Frontend Developer | T-001 | in_review | 1 | — |
| T-025 | App shell: router, bottom nav, deep links, UiState pattern, l10n | Medium | sonnet | Frontend Developer | T-024, T-004 | todo | — | — |
| T-026 | Onboarding: S-01 risk, S-02 login + SessionCapture, S-03 setup | High | sonnet | Frontend Developer | T-025, T-008, T-009, T-020 | todo | — | — |
| T-027 | Library S-04 (stories/posts) + filters S-05 + selection/delete | Medium | sonnet | Frontend Developer | T-025, T-019 | todo | — | — |
| T-028 | Story viewer S-06 | Medium | sonnet | Frontend Developer | T-027 | todo | — | — |
| T-029 | Post viewer S-15 | Medium | sonnet | Frontend Developer | T-027 | todo | — | — |
| T-030 | Targets S-07 + Add target S-08 | Medium | sonnet | Frontend Developer | T-025, T-016, T-021 | todo | — | — |
| T-031 | Target detail S-09 + Remove dialog S-10 | Medium | sonnet | Frontend Developer | T-030, T-019 | todo | — | — |
| T-032 | Activity S-11 | Medium | sonnet | Frontend Developer | T-025, T-020 | todo | — | — |
| T-033 | Settings S-12 + Instagram account S-13 | Medium | sonnet | Frontend Developer | T-025, T-021, T-020, T-023 | todo | — | — |
| T-034 | App lock S-14 + PIN setup + lock gate | High | sonnet | Frontend Developer | T-025, T-008 | todo | — | — |
| T-035 | *(Could)* ExportZip | Medium | sonnet | Frontend Developer | T-031 | todo | — | — |
| T-036 | Release pipeline (`release.yml`) + README install guide | Medium | sonnet | Backend Developer | T-001, P-5 | todo | — | — |
| T-037 | End-to-end tests + device soak checklist | Medium | sonnet | QA Engineer | T-021…T-034 | todo | — | — |
| T-038 | Accessibility & RTL pass + string audit | Low | haiku | Frontend Developer | T-026…T-034 | todo | — | — |

## Checkpoints
| # | After tasks | Result | Report |
|---|-------------|--------|--------|
| 1 | (first 5 done) | — | — |

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
