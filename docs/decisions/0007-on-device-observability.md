# 0007 — On-device observability only (activity log, diagnostic file, gap detection)

- Status: proposed (v0.2: tools updated for Flutter; the decision itself is unchanged)
- Date: 2026-11-19

## Context
NFR-6 says no analytics or cloud. But background failures (OEM kills, Instagram changes, bans) must be visible to the user
and debuggable by developers.

## Options considered
1. **On-device only: the user-facing activity log, a rotating redacted log file (`logging` package), `check_run` history and gap detection**
   - ✅ Meets NFR-6.
   - ❌ Developers only see logs from devices they can connect to.
2. **Firebase Crashlytics / Sentry** — ❌ breaks NFR-6, and the logs could contain sensitive URLs.
3. **Self-hosted crash endpoint** — ❌ breaks D-5 (no server).

## Decision
Option 1. Worker stop reasons come from the native plugin (`WorkInfo.stopReason`).

## Consequences
- Debugging field issues means connecting the phone (`flutter logs`, adb).
- A user-initiated "share diagnostics file" feature isn't in the requirements. It's noted for later.
