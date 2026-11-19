# 0004 — Background scheduling with the `workmanager` plugin (Android WorkManager) (revised v0.2)

- Status: proposed
- Date: 2026-11-19

## Context
- Story checks run every 15 min to 6 h; post checks every 1 h to 24 h.
- There's no server. Checks must survive reboots and respect Doze and OEM battery managers.

## Options considered
1. **`workmanager` plugin: periodic tasks for stories and posts, one-off tasks for manual checks and download roll-over**
   - ✅ Android WorkManager underneath, so it's persistent and handles constraints.
   - ✅ The 15-minute minimum matches BR-5.
   - ❌ Runs in a background Dart isolate. Each task stops after about 8 minutes (WorkManager's 10-minute limit), with the rest rolled over.
2. **android_alarm_manager_plus (exact alarms)** — ❌ needs the exact-alarm permission, drains battery, and still needs a long-running executor.
3. **Permanent foreground service** (e.g. flutter_foreground_task) — ❌ a permanent notification, a battery cost (NFR-3), and Android 14/15 type limits.
4. **A native Kotlin worker that calls Dart** — ✅ full control (expedited and foreground info) ❌ more native code. Kept as a fallback if the plugin falls short.

## Decision
Option 1, with separate unique periodic tasks `check-stories` and `check-posts` (offset start), plus `download`, `retention` and `update-check`.

## Consequences
- Some delay is expected. Gap detection and the S-03 battery setup cover it.
- Every plugin used in the background must work in a background isolate: drift, dio, flutter_secure_storage,
  flutter_local_notifications and the in-repo plugin are fine. The headless WebView must be verified (ADR-3).
