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

### Amendment 2026-11-24 (2): REST stays gated; discovery is persisted (T-045)
Supersedes the REST part of "REST fallback per call (T-044)". On device, with no discovery: `fetchStories via=rest` returned `SchemaChanged where=response`, `fetchNewPosts via=rest` returned 404 (`feed/user/{id}`), and shortly after the app reported a 15 min rate limit. The unproven REST endpoints answered with 404 and a soft block ("Please wait a few minutes"), and they put the account at risk. GraphQL through the real page is proven.

Decision:
- **REST is used only for ops that a probe report proved** (`restProven` per candidate), plus the first-login `verifySession` bootstrap. Without proof and without discovery, direct mode sends **nothing** and returns `SchemaChanged`: page mode in the foreground, a clean skip in the background. The REST code and tests stay, gated.
- **`doc_id`s and page tokens are persisted per account in secure storage** and shared by all isolates (`DiscoveryStore`), so background isolates use the GraphQL that page mode discovered. Lifetimes: `doc_id` 6 h, tokens 12 h. Cleared with the session. A stale `doc_id` (GraphQL `SchemaChanged`) is dropped.
- **The foreground refreshes discovery** at open and resume with one governed page load per account per 6 h, never while paused.
- Rate limits are logged with op, transport, status and a letters-only hint, to find the offending call next time.

Consequence: until a page load has happened (first run after install or after 6 h without opening the app), background checks skip without a request. Open the app once and background checks work (DEVICE_TESTS D5).

### Amendment 2026-11-24 (3): discovery by in-page modules; REST is dead on www (T-048)
Found on device (log 20:23): a profile load never sends the posts or stories queries (the first page of posts is server-preloaded), so watching traffic could not find their `doc_id`s; every direct check ended `unavailable` and a manual "Check now" was refused page mode in the background.

Decision:
- **Discovery reads the page's own module system, with no network request.** After the page is ready (and again on a message) `hook.js` reads, for a fixed allowlist of operations, the `doc_id` (`<Name>_instagramRelayOperation`), the relay provided-variable values and the argument names (`<Name>.graphql`), plus `fb_dtsg` and `lsd`, through `window.require`. It posts one `discovery` message, strictly parsed in Dart. Provider values and argument names are stored with the `doc_id` in the persisted discovery (not secret); tokens as before. Traffic watching stays as a second source.
- **GraphQL requests are built from the discovered shape:** only the arguments in the discovered list, plus every discovered provider value, sent to `/api/graphql` with the form fields and headers the web app uses.
- **REST is dead on www** (`feed/user`, `highlights_tray`, `web_profile_info` answer a 404 page, `feed/reels_media` answers 500). It stays gated off; nothing here re-enables it.
- **A manual "Check now" may load pages** in the background isolate (a user-initiated run); scheduled checks still need `pageModeInBackground`.
Details and the ground truth: INSTAGRAM_EXTRACTION.md "2026-11-24 ground truth (web)". Verified on device by DEVICE_TESTS D6.

### Amendment 2026-11-25 (4): in-page fetch is primary; direct HTTP is a fallback (T-050)
Found on device (log 00:24): direct GraphQL from Dart with tokens copied out of the WebView answered `for (;;);` `fb_error=1357054` (tokens refused). Page loads cost 3 governor tokens each, the retries drained the budget, adds sat "Waiting to look up" and background tasks hit their deadline (`task_stopped reason=timeout`). The user's direction: mimic opening the Instagram page and take the data from it.

Decision:
- **Queries run inside the page.** One headless WebView session on `https://www.instagram.com/` (hook and seen block installed, WebView lease held, logged-out and challenge detection as in page mode) runs the web app's own GraphQL read queries from the page's JavaScript (`assets/inpage_query.js`, `callAsyncJavaScript`). The page has the right cookies, user agent and tokens, so the request is accepted.
- **Fixed script, hard allowlist.** The script builds the POST itself; Dart passes only `name` and a JSON `variables` string as arguments. Allowed: `PolarisProfilePostsQuery`, `PolarisProfilePostsTabContentQuery_connection`, `PolarisStoriesV3ReelPageStandaloneQuery`, `PolarisProfileStoryHighlightsTrayContentQuery`. Names containing `Mutation` or `Seen` are refused on both sides. The seen mutation stays blocked by the hook.
- **One session per run.** One governed page load (3 tokens) opens it; each query is one governed `api` call (1 token). It closes at the end of the run, or after 2 min idle. Ten targets cost about 3 + 10 tokens, not ten page loads.
- **Primary for every operation** (stories, new posts, post pages, highlights tray and items, `resolveUser`). `resolveUser` reads the user from the posts query; an account without posts is read from its profile page in the same session.
- **Direct HTTP (GraphQL, REST) and page mode stay in the code** and run only when in-page reports it is unavailable (no module, no token, no document-start script, page not ready in about 10 s, kill switch). Every other in-page result, including real failures, is final.
- **Background:** in-page runs in background tasks by default. `storize.inPageInBackground` (absent means on) is a kill switch; only an explicit `false` turns it off. Background calls leave 3 tokens of the burst for interactive calls (governor `priority`), so adding an account is not starved. Background task budget: 9 min, no new target in the last 30 s.
- **Debug only:** `RequestGovernor.runUnmetered` (dev builds) skips the hourly and burst budget with a 1 s spacing and still respects an active back-off.

Logs (no values): `[inpage] session_open ms= ready= modules=`, `[inpage] op=<name> status= items=` or `error=<code>`, `[inpage] session_close queries=`.

