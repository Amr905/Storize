# Storize — Project Guide for Claude

This file is the source of truth for how work happens in this repo.
Every agent reads it first. The **Lead Engineer** (the main Claude session)
orchestrates; specialized subagents in `.claude/agents/` do the work.

## Current status
- **Phase:** 5 — Implementation **in progress**. Progress in `docs/implementation-status.md`. Requirements/UX/Spec v0.2 and Tasks v0.1a approved 2026-11-19.
- **Product (short):** Android-first Flutter app that auto-downloads Instagram **stories and new posts** of tracked accounts via a logged-in account (automation) into the phone gallery (`Pictures/Storize/<username>/`). MVP = Instagram only, phone-only, single role. See `docs/01-requirements/REQUIREMENTS.md`.
- **Stack (proposed):** Flutter + Dart 3, Riverpod, go_router, drift, shared_preferences, dio, flutter_inappwebview, workmanager, flutter_secure_storage, flutter_local_notifications, video_player, local_auth; in-repo Kotlin plugin `storize_platform_android`. Pub workspace: `app/` + `packages/storize_{model,domain,data,instagram,platform_android}` (TECH_SPEC §10). Public GitHub repo: https://github.com/Amr905/Storize.
- **Implementation:** NOT started. Do not write application code before Phase 4 is approved.

## Workflow (phase-gated)
Each phase produces an artifact in `docs/`. The Lead reviews it, then the
**user approves** before the next phase starts. Update "Current status" above at every gate.

| # | Phase | Agent | Model | Output |
|---|-------|-------|-------|--------|
| 1 | Requirements refinement | `requirements-analyst` | opus | `docs/01-requirements/REQUIREMENTS.md` |
| 2 | UI/UX design | `ux-designer` | opus | `docs/02-design/UX.md` |
| 3 | Technical specifications | `architect` | opus | `docs/03-specs/TECH_SPEC.md` + ADRs |
| 4 | Task breakdown | `task-planner` | opus | `docs/04-tasks/TASKS.md` |
| 5 | Implementation | `backend-developer` / `frontend-developer` | haiku (Low) / sonnet (Medium, High) | code in Gradle modules (TECH_SPEC §10), tests beside each module |
| 6 | Testing & review | `qa-engineer` + Lead review | sonnet / opus | `docs/05-reviews/<task-id>.md` |

**Rule:** All planning and design work (phases 1–4, plus code review) runs on **Opus**.

## Phase 5 orchestration (user rules, 2026-11-19)
**Complexity → model:** Low (Tier S) → **Haiku** · Medium (Tier M) and High (Tier L) → **Sonnet**. Planning and review → Opus (the Lead).

**Specialists** (`.claude/agents/`): `backend-developer` (all non-UI tasks), `frontend-developer` (UI tasks T-024…T-035, T-038),
`qa-engineer` (independent verification of each task, 5-task checkpoints, T-037). The Lead passes the model per task.
(`implementer-simple/-standard/-complex` and `test-engineer` are superseded by these roles and kept only for history.)

**Delegation protocol (Lead Orchestrator):**
1. Pick a task whose dependencies are all `done` in `docs/implementation-status.md`.
2. Read its spec, classify the complexity, choose the model and specialist, and **register its file lock** in the status file. Never overlap an active lock.
3. Delegate with: task ID, requirements, spec sections, acceptance criteria, files in scope. Implementation **and automated tests** are required.
4. QA Engineer verifies independently (`docs/05-reviews/<task>.md`). Then the Lead reviews the diff and the evidence.
5. FAIL → feedback to the same developer → fixes → re-run tests → re-verify. After 2 failed rounds on a High task, ask the user whether to use Opus.
6. Only after a verified PASS: mark it `done`, release the lock, and log it in the status file.
7. **After every 5 tasks marked done:** QA runs the full suite (checkpoint report). Regressions block new tasks until fixed.
8. Never mark a task done without real test output as evidence.

## Task status values (`TASKS.md`)
`todo` → `in_progress` → `in_review` → `done`  ·  also `changes_requested`, `blocked`

## Conventions
- Docs are Markdown; one source of truth per topic — link, don't duplicate.
- Architectural decisions → `docs/decisions/NNNN-title.md` (copy `0000-template.md`).
- Code style, lint and test commands are set in Phase 3 and recorded under **Commands** below.
- Never commit secrets; use `.env` (gitignored) and document variables in `.env.example`.
- Agents stay within their task's file scope; anything outside it is reported to the Lead first.
- Open questions go in the relevant doc's "Open questions" section, not buried in prose.

## Commands
Run from the repo root unless noted. (They work once T-001 creates the workspace.)
| Purpose | Command |
|---------|---------|
| Get dependencies | `flutter pub get` |
| Codegen (drift, riverpod) | `melos run gen` |
| Format check | `dart format --set-exit-if-changed .` |
| Static analysis | `flutter analyze` |
| All tests | `melos run test` |
| Golden update | `melos run golden:update` |
| Run on phone | `cd app && flutter run --flavor dev` |
| Release APK | `cd app && flutter build apk --release --flavor prod --obfuscate --split-debug-info=build/symbols` |

**Toolchain in the Claude workspace:** `export PATH=/opt/flutter/bin:$HOME/.pub-cache/bin:$PATH` and `ANDROID_HOME=/opt/android-sdk` (Flutter 3.50.0 / Dart 3.14.0). Agents must run format, analyze and tests here and paste the real output. GitHub Actions is an extra gate.

## Architecture guardrails (from TECH_SPEC / ADRs)
- `storize_domain` and `storize_model` are pure Dart: no Flutter, Android or Instagram imports. Instagram specifics live only in `storize_instagram`.
- Every Instagram call (direct and page mode) goes through `RequestGovernor` (ADR-0009). Never bypass it.
- Media is downloaded with a plain HTTPS GET of the CDN URL and saved only through `GalleryStore` (ADR-0005/0011).
- Never log or commit cookies, tokens, signed URLs, PINs or real people's content. **The repo is public**: fixtures must be sanitized; gitleaks must pass.
- Native Android code lives only in `packages/storize_platform_android`.
- Port interfaces in `storize_domain` are contracts: changing them needs Lead approval.
