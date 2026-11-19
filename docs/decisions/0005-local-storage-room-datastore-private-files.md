# 0005 — drift for records, shared_preferences for settings, media in the phone gallery (revised v0.2)

- Status: proposed (v0.2: media location changed by the user, D-10)
- Date: 2026-11-19

## Context
- Records (targets, stories/posts, slides, runs, activity) need relational queries.
- The user wants downloads **visible in the gallery, in a folder** (D-10).

## Options considered
**Records**
1. **drift (SQLite)**
   - ✅ Type-safe SQL, streams, tested migrations.
   - ✅ Works in a background isolate.
2. **Isar / Hive / ObjectBox** — ❌ weaker relational queries; Isar/Hive maintenance is uncertain.
3. **sqflite raw** — ❌ no compile-time safety or migration tooling.

**Media location**
1. **MediaStore `Pictures/Storize/<username>/`, inserted by the app**
   - ✅ Shows as a normal album in Gallery/Photos.
   - ✅ No permission needed on Android 10+.
   - ✅ The app owns its files, so it can delete them (BR-9).
   - ✅ Survives uninstall.
   - ❌ Visible to other apps and outside the app lock.
   - ❌ Ownership is lost after reinstall.
2. App-private files plus a "Save to gallery" copy (v0.1) — ❌ rejected by the user.
3. `Download/Storize` — ❌ not shown as an album by many gallery apps.

## Decision
drift + shared_preferences, with media inserted into MediaStore under `Pictures/Storize/<username>/` through the native plugin (ADR-11).
Temp files and thumbnails stay in the app cache.

## Consequences
- **A-15 (v0.2):** files survive uninstall, but they aren't re-imported after reinstall.
- **Gallery edits (EC-20):** if the user deletes a file in the gallery, the item becomes `FILE_MISSING`.
- **Android 8–9:** these need `WRITE_EXTERNAL_STORAGE`.
