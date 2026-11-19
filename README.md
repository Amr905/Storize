# Storize

_Product description pending — see `docs/01-requirements/REQUIREMENTS.md` once Phase 1 is complete._

## Repository layout
```
.claude/agents/     Subagent definitions (one per role)
docs/
  01-requirements/  Refined requirements & user stories
  02-design/        UX flows, screens, design notes
  03-specs/         Technical specification
  04-tasks/         Task breakdown with complexity tiers
  05-reviews/       Per-task test + code review reports
  decisions/        Architecture Decision Records (ADRs)
src/                Application code (Phase 5+)
tests/              Automated tests (Phase 5+)
CLAUDE.md           Workflow rules for Claude agents
```

See `CLAUDE.md` for the development workflow.

## Development

Toolchain: Flutter 3.50.0 (Dart 3.14), JDK 17, Android SDK 36. The repo is a Dart pub workspace (`app/` + `packages/*`).

```sh
flutter pub get                       # resolve the whole workspace (repo root)
dart format --set-exit-if-changed .   # format check
flutter analyze                       # static analysis
dart pub global activate melos        # once
melos run test                        # tests in every member
melos run gen                         # code generation (no-op until build_runner is used)
cd app && flutter run --flavor dev    # run the dev flavor on a phone
```
