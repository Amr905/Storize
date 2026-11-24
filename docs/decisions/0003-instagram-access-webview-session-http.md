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

## Addendum (2026-11-20, after T-002 / T-013 / T-014)
- **The web app uses GraphQL, not the planned REST calls.** IG-1…IG-5 were not observed in the T-002 capture. Direct mode defaults to the observed GraphQL queries (`doc_id` and page tokens discovered at runtime, never hard-coded); a REST transport is used only where the T-013 live probe proves it (`restProven=true`).
- **Viewing a story through the web page marks it seen** (`PolarisStoriesV3SeenMutation`). Decision UD-3 (Lead default, reversible by the user): page mode **always blocks** this mutation in the injected hook, for every request shape; configuration can add names to the block list but never remove it. A captured reply to a blocked name is treated as a block failure (`seen_block_leak`) and trips a breaker. Page mode never interacts with the story viewer UI.
- **Fail closed without document-start injection.** If the WebView cannot inject the hook at document start, page mode refuses to load (`page_hook_unsupported`) rather than race the page.
- **WebView lease.** Page mode wipes the app-wide WebView cookie jar after each run, so it must never run while the S-02 login WebView is open. A cross-isolate `WebViewLease` (T-015) is held by S-02 for its lifetime; page mode only `tryAcquire`s it and returns `webview_busy` otherwise.

### Amendment 2026-11-22: first-login session check (IG-4 bootstrap)
Found on device: on the first login nothing has been discovered by a page load yet, so the GraphQL session check has no `doc_id` or page tokens (`SchemaChanged('doc_id:…')`/`page_tokens`), and S-02 showed "Couldn't connect this account".

`DirectExtractor.verifySession` now makes **one** IG-4 call (`GET /api/v1/accounts/current_user/?edit=true`) in exactly that case. It is a read-only GET through the same governor, with the same session headers and the same `user.pk == ds_user_id` check. Every content operation stays on GraphQL, with page mode as the fallback. REST for content still needs `restProven`.

Update the same day: on device, `current_user` returned HTTP 400 to the web session (it belongs to the mobile API). The bootstrap now falls back to the web client's own `GET /api/v1/accounts/edit/web_form_data/` (`form_data.username`, with the id taken from `ds_user_id`). Diagnostics carry a secret-free reason taken from the error body (`http_400:<letters only>`).

### Amendment 2026-11-24: REST fallback per call (T-044)
Found on device: discovered `doc_id`s and page tokens exist only after a page-mode run in the same isolate, and page mode is off in the background, so every direct GraphQL call failed with `SchemaChanged` and nothing was fetched in background checks, on add, for history or for highlights. The web REST endpoints work with the session cookies.

Direct mode now uses GraphQL when its `doc_id` and tokens are available and REST otherwise, per call (`FallbackTransport`). A GraphQL `SchemaChanged` is retried once on REST; a REST `SchemaChanged` or `UnknownFailure` still goes to page mode where allowed; rate-limit, session, private and not-found failures are never retried on the other transport. Every call stays a governed read-only GET (no `seen` endpoint). This supersedes "REST only where `restProven`" for the default; a proven probe can still pin REST. Details and endpoints: INSTAGRAM_EXTRACTION.md "v0.3 REST fallback". Verified on device by DEVICE_TESTS D5.
