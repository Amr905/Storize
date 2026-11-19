# 0002 — Layered architecture: Dart pub workspace with app + 5 packages (revised v0.2)

- Status: proposed
- Date: 2026-11-19

## Context
- Instagram will break things repeatedly (R-2), and more platforms are planned (NFR-8).
- Several implementer agents work in parallel and need clear file boundaries.
- The domain logic should be testable with plain `dart test`.

## Options considered
1. **Single Flutter app with folders**
   - ✅ Simplest.
   - ❌ Boundaries are only a convention, so Instagram code leaks into the UI and domain.
   - ❌ More merge conflicts between parallel agents.
2. **Pub workspace (`app/` + `packages/storize_model`, `storize_domain`, `storize_data`, `storize_instagram`, `storize_platform_android`) with Melos scripts**
   - ✅ Dependency rules are enforced by `pubspec.yaml` (domain can't import Flutter or Instagram).
   - ✅ The adapter can be tested in isolation.
   - ✅ A new platform is just a new package.
   - ❌ Some setup cost.
3. **A package per feature** — ❌ too much overhead for 15 screens.

## Decision
Option 2. Features live in `app/lib/features/<name>/`.

## Consequences
- Port interfaces in `storize_domain` (`ContentPlatform`, repos, `SessionStore`, `GalleryStore`, `Scheduler`) are contracts.
  Changing one needs Lead approval.
- The task-planner can assign packages or features to separate agents.
