# 0001 — Flutter, Android first (revised v0.2)

- Status: proposed (v0.2: changed from Kotlin + Compose at the user's request)
- Date: 2026-11-19
- Deciders: user (D-13), Lead

## Context
Storize is Android-first, and iOS may follow later. The hard parts are platform integrations: WebView cookie capture,
background work, the MediaStore gallery, Keystore, biometrics and OEM battery intents. The user prefers Flutter
(also used for VOX Seat Watch).

## Options considered
1. **Flutter (Dart), Android first, a small native Kotlin plugin for gaps**
   - ✅ The user's preferred stack.
   - ✅ One codebase if iOS comes later.
   - ✅ Mature plugins exist for WebView (flutter_inappwebview, including cookie access and headless mode), WorkManager
     (workmanager), secure storage, notifications, biometrics and video.
   - ❌ Background tasks run in a separate Dart isolate, so plugins must be background-safe.
   - ❌ MediaStore ownership/delete and OEM intents need native code (ADR-11).
2. **Kotlin + Jetpack Compose** (v0.1 proposal)
   - ✅ Direct access to every Android API.
   - ❌ Not the user's choice; no iOS path.
3. **React Native** — the same bridging cost as Flutter, and nobody on the team has used it.

## Decision
Flutter. Android-specific needs go into one in-repo Kotlin plugin, `storize_platform_android`. That keeps native code small,
isolated and reviewable.

## Consequences
- Implementer agents write Dart, plus some Kotlin for the plugin only.
- Background code must avoid Flutter UI and Android-only APIs outside the plugin. The background isolate gets its own minimal provider container.
- iOS later needs: an iOS gallery implementation (Photos framework) and a BGTaskScheduler strategy. iOS background limits are
  much stricter, so the feature set there may differ.
- *(File name kept for history; the decision is Flutter.)*
