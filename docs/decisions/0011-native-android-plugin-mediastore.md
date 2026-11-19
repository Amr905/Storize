# 0011 — In-repo Kotlin plugin `storize_platform_android` for MediaStore and system integration

- Status: proposed
- Date: 2026-11-19

## Context
FR-33 / D-10 need files in `Pictures/Storize/<username>/` that the app can later **delete** (BR-9), check for existence (EC-20)
and size (FR-53). We also need OEM battery-settings intents (FR-51), `WorkInfo.stopReason` (ADR-7) and video thumbnails.

## Options considered
1. **Existing pub packages**
   - `gal` / `saver_gallery`: ✅ save to an album ❌ no delete or ownership.
   - `photo_manager`: ✅ save, delete and query ❌ a large API with broad media permissions, and delete can trigger system dialogs.
2. **A small in-repo Flutter plugin (Kotlin, MethodChannel) with exactly the calls we need** ✅
   - `insert(sourcePath, relativeDir, displayName, mime)` uses IS_PENDING; on API ≤ 28 it writes the file and runs a scan.
   - `delete(uri)`, `exists(uri)`, `size(uri)`.
   - `videoThumbnail(uri)`, `openBatterySettings(oem)`, `isIgnoringBatteryOptimizations()`, `lastStopReasons()`.
   - Least permissions, fully testable.

## Decision
Option 2. It's about 300–500 lines of Kotlin with instrumentation tests on Android 9, 10 and 14.

## Consequences
- This is the only native code in the project; reviewers need basic Kotlin.
- iOS would need its own implementation of the same channel later (D-13).
