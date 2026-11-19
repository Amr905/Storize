# 0003 — Extraction: watch the real page, replay its requests, fall back to rendering the page (revised v0.2)

- Status: proposed
- Date: 2026-11-19

## Context
D-4 chose automation through a logged-in account. D-12 / FR-29 add a requirement: the method must be worked out by opening the
real story or post page and seeing where the image or video comes from, then downloading it the normal way. There must also be
a fallback that loads the page itself if the shortcut breaks.

## Options considered
1. **Direct mode only** — replay Instagram's internal JSON requests found by the spike.
   - ✅ Light, fast and background-safe.
   - ❌ When Instagram changes the JSON, everything stops until a hotfix ships.
2. **Page mode only** — a headless WebView loads each page and reads the media links.
   - ✅ Closest to "opening the page"; it survives some JSON changes.
   - ❌ Heavy on battery and data for every check.
   - ❌ Unclear whether a headless WebView runs inside a background isolate.
3. **Direct mode first, page mode as fallback; both built from what the spike observes** ✅
4. **Accessibility automation of the Instagram app / third-party scraping APIs** — rejected (fragile and invasive; breaks NFR-6). See v0.1 analysis.

## Decision
Option 3:
- **Spike T-002** observes the real story, profile and post pages (desktop DevTools plus the app's own WebView via remote
  debugging) and records the requests that carry media links. Output: `INSTAGRAM_EXTRACTION.md` plus sanitized fixtures.
- **Direct mode** replays those requests with the captured session and the same User-Agent.
- **Page mode** loads the same pages in `HeadlessInAppWebView` with the session cookies. It captures the same JSON through an
  injected fetch/XHR hook, or reads `img`/`video` sources as a last resort. It runs only when direct mode reports `SchemaChanged`.
  It's always allowed in the foreground; in the background only if the spike proves it works.
- **Media is always downloaded as a plain HTTPS GET of the CDN URL** (the normal file download).

## Consequences
- Two extractors share one mapper and one RequestGovernor.
- Fixtures must be sanitized because the repo is public.
- The ban risk remains (R-1). Page mode generates more traffic, so it's rate-limited by the same governor.
