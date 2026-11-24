# Instagram extraction: results of the T-002 spike

Status: **capture findings recorded (2026-11-20).** Schema only: no names, IDs, shortcodes, URLs, captions or `doc_id` values appear in this file.
Open items: AC2 story-media plain download and AC4 phone hook are **pending: next capture session (Lead to schedule)**; AC5 (headless WebView in the background) is **deferred to T-014** (the Lead adds it to T-014's acceptance criteria). See [Pending](#pending-and-open-items).

Related: [TECH_SPEC §4.1](TECH_SPEC.md) · [ADR-0003](../decisions/0003-instagram-access-webview-session-http.md) · [ADR-0010](../decisions/0010-change-detection-batched-reels-media.md) · [CAPTURE_GUIDE](CAPTURE_GUIDE.md) · task T-002 in [TASKS.md](../04-tasks/TASKS.md)

## How this was captured and how to read it
- **Capture:** 2026-11-20, desktop browser, the user's test login, a public account whose owners agreed. An in-page fetch/XHR hook recorded JSON responses; HAR files were built **without request/response headers and without cookies**. Five captures: `story`, `profile`, `post_photo`, `post_carousel`, `reel`. The account publishes videos as reels, so there is **no separate "video post"** capture.
- **Evidence:** sanitized fixtures in `packages/storize_instagram/test/fixtures/real/<capture>/` (only the bodies the extractors need, plus `report.md` and `summary.json`). The shape test `test/tool/real_fixtures_shape_test.dart` pins every JSON path below.
- **Status words:** **observed** = seen in the capture. **not observed** = not seen; any statement about it is a hypothesis.
- **Not captured, so unknown:** request headers and cookies (which of them the endpoints really need), logged-out behaviour, error responses (no 401/`login_required`/`checkpoint_required` was seen), rate-limit behaviour.
- **Sanitizer side effects visible in fixtures:** every URL is a placeholder (`<url host=... path_shape=...>`), IDs are `user_N`/`media_N`, and a few enum-like values not on the sanitizer's known list are redacted (for example the child `product_type` `carousel_item` shows as `<str:13>`). `docId` was removed from the committed `summary.json` copies by hand because the policy forbids committing `doc_id` values.
- **Sanitizer rules added in round 2 (visible in fixtures):** CDN hosts are reduced to `scontent.fbcdn.net` / `instagram.fbcdn.net` / `cdninstagram.com` form (every edge or region label is dropped, because it names the capturer's nearest city); floats are rounded to 2 decimals; every number under a location (key `location`, `location_*`, or an object whose `__typename` contains `Location`, and any `lat`/`lng`/`latitude`/`longitude`) becomes `null`; `latest_reel_media` is kept only at `data.user` (profile) and `reels_media[]` (story reel) and is `null` on every other user object. Consequence: **`node.user.latest_reel_media` and `owner.latest_reel_media` exist in the real responses but are null in the fixtures.**

## IG-1 to IG-5 status (TECH_SPEC §4.1 candidates)

None of the five REST candidates was seen. The web app uses GraphQL (`POST /api/graphql` with a `doc_id`) for stories, profile and timeline, and one REST endpoint (`/api/v1/media/<id>/info/`) for a single post.

| # | Purpose | Candidate | Status | What the web app does instead |
|---|---------|-----------|--------|-------------------------------|
| IG-1 | Username to user | `GET /api/v1/users/web_profile_info/?username=` | **not observed** | `PolarisProfilePostsQuery` takes `username` and its nodes carry the owner id; `PolarisProfilePageContentQuery` takes the `id` (see Lookup) |
| IG-2 | Stories (batched) | `GET /api/v1/feed/reels_media/?reel_ids=` | **not observed (replaced in the web UI)** | `PolarisStoriesV3ReelPageStandaloneQuery`, variable `reel_ids_arr` (an array, so batching is plausible; only one id was sent) |
| IG-3 | User by ID | `GET /api/v1/users/{id}/info/` | **not observed** | `PolarisProfilePageContentQuery`, variable `id` |
| IG-4 | Validate session | `GET /api/v1/accounts/current_user/?edit=true` | **not observed** | viewer root present in authenticated GraphQL responses (see Session) |
| IG-5 | Latest posts | `GET /api/v1/feed/user/{id}/?count=12` | **not observed** | `PolarisProfilePostsQuery`, variable `data.count` (12 seen) |

"Not observed" does **not** mean "removed": the REST endpoints may still work for a logged-in session. They simply never appeared in the web UI traffic, so nothing here proves or disproves them.

## Endpoints observed

| Need | Method + path | GraphQL friendly name | Root field(s) | Variables (names) | Status |
|------|---------------|-----------------------|---------------|-------------------|--------|
| Story items of a user | `POST /api/graphql` | `PolarisStoriesV3ReelPageStandaloneQuery` | `data.xdt_api__v1__feed__reels_media`, `data.xdt_viewer` | `reel_ids_arr` (array of user ids), one relay-provider flag | observed |
| Mark story seen (side effect) | `POST /api/graphql` | `PolarisStoriesV3SeenMutation` | `data.xdt_mark_story_reel_seen` | `reelId`, `reelMediaId`, `reelMediaOwnerId`, `reelMediaTakenAt`, `viewSeenAt` | observed, **fired by the page, not by the reel query** |
| User profile (by id) | `POST /api/graphql` | `PolarisProfilePageContentQuery` | `data.user`, `data.viewer` | `id`, `enable_integrity_filters`, relay-provider flags | observed |
| Posts of a user (by username) | `POST /api/graphql` | `PolarisProfilePostsQuery` | `data.xdt_api__v1__feed__user_timeline_graphql_connection`, `data.xdt_viewer` | `username`, `data.count`, `data.include_reel_media_seen_timestamp`, `data.include_relationship_info`, `data.latest_reel_media`, `data.latest_besties_reel_media`, relay-provider flags (no cursor variable seen: first page only) | observed |
| Single post, carousel or reel | `GET /api/v1/media/<media_pk>/info/` (no query string) | n/a (REST) | top-level `items[]` | path parameter only | observed |
| Comments | `GET /api/v1/media/<media_pk>/comments/` | n/a | n/a | n/a | observed, **not needed** |
| Unrelated GraphQL seen on the same pages | `POST /api/graphql` | highlights tray, note bubble, suggested users, quick promotion, nav badge, inbox picker, school badge, inbox eligibility | n/a | n/a | ignore |

**Request body of every GraphQL POST** (parameter names only, from `summary.json`): form-encoded; carries `doc_id`, `variables` (JSON text), `fb_api_req_friendly_name`, `fb_api_caller_class`, `server_timestamps`, and a set of page/session tokens (`fb_dtsg`, `lsd`, `jazoest`, `av`, `__user`, and Meta's `__a`, `__d`, `__comet_req`, `__csr`, `__dyn`, `__hs`, `__rev`, `__s`, `__spin_*`, `__req` and similar). The tokens come from the page HTML/bootstrap; whether a plain HTTP client can obtain them without a page load is **unknown**.

**`doc_id` handling.** Each friendly name maps to a numeric `doc_id` that is **per-deploy and rotates**. Never hard-code one. It must be discovered at runtime (read it off the page's own request through the hook, or from the page bundle). This document deliberately records no values.

## Response schemas (JSON paths)

`[]` = array element. Types are as seen. "All" = on every element in the capture.

### 1. Story items per user: `data.xdt_api__v1__feed__reels_media`
Observed on one video story (a photo story was not in the capture; photo items would have `media_type` 1 and no `video_versions`, **unverified**).

| Field | Path (under `reels_media[]`) | Notes |
|-------|------------------------------|-------|
| Reel id | `id` (string) | **equals the owner's user id** (`user.pk`) |
| Reel type | `reel_type` | `user_reel` seen (`highlight_reel`, `ad_reel` are on the sanitizer's known list, not seen) |
| Owner | `user.pk`, `user.id`, `user.user_id`, `user.username`, `user.is_private`, `user.friendship_status.following` | |
| Reel-level change signal | `latest_reel_media` (int, unix seconds), `seen` (int) | `latest_reel_media` equals the newest item's `taken_at` |
| Items | `items[]` | |
| Item id | `items[].pk` (string, the media id), `items[].id` (`<pk>_<owner id>`) | |
| Shortcode | `items[].code` (string, 11 chars) | present on stories |
| Media type | `items[].media_type` (int: 1 photo, 2 video) | only 2 seen |
| Kind | `items[].product_type` = `story` | |
| Taken / expires | `items[].taken_at`, `items[].expiring_at` (int, unix seconds) | `expiring_at - taken_at` = 86400 (24 h) in the capture |
| Image | `items[].image_versions2.candidates[]`: `url`, `width`, `height` | 11 candidates (640x1138 down to 150x150); for a video story these are the cover frames |
| Original size | `items[].original_width`, `items[].original_height` | |
| Video (progressive) | `items[].video_versions[]`: `type` (101, 102, 103), `url` | **no width/height on story versions** (the post/reel versions do have them) |
| Video (DASH) | `items[].video_dash_manifest` (XML string), `is_dash_eligible`, `number_of_qualities` | manifest had one video and one audio adaptation set |
| Audio flag | `items[].has_audio` (bool) | |
| Duration | `items[].video_duration` (int seconds here) | |
| Close friends | `items[].audience` | null in the capture; see sanitizer known values `besties`, `close_friends` |
| Link stickers | `items[].story_link_stickers` | null in the capture; **unverified shape** |
| Item owner | `items[].user.pk` | equals the reel's owner |
| Carousel | `items[].carousel_media`, `carousel_media_count` | null on stories |
| Extra | `items[].story_music_stickers[]`, `story_feed_media[]` (a re-shared post: `media_code`, `product_type`) | not needed |
| Viewer | `data.xdt_viewer.user.id` / `pk` / `user_id` | the logged-in user, not the story owner |
| Empty-result field | `data.xdt_api__v1__feed__reels_media.unviewable_authors_infos[]` | empty list seen |

### 2. Posts per user: `data.xdt_api__v1__feed__user_timeline_graphql_connection`
Observed: 12 nodes (photo, reel, carousel mix), `count` = 12.

| Field | Path (under `edges[].node`) | Notes |
|-------|-----------------------------|-------|
| Ids | `pk` (media id), `id` (`<pk>_<author id>`), `code` (11 chars) | |
| Author / owner | `user.pk`, `user.id`, `owner_id.pk`, `owner_id.id` | see collab caveat |
| Media type | `media_type` (1 photo, 2 video, 8 carousel) | |
| Kind | `product_type`: `feed` (photo), `clips` (reel/video), `carousel_container` | |
| Taken | `taken_at` (int, unix seconds) | no `expiring_at` on posts |
| Image | `image_versions2.candidates[]`: `url`, `width`, `height` (11 to 14 candidates) | for photo and carousel nodes (8 of 8) the largest candidate reached the original width (up to 3425 px); for **reels it did not** (3 of 4: cover frames 640 to 720 px wide against originals of 720, 1080 and 1020), so do not assume candidate width equals `original_width` |
| Original size | `original_width`, `original_height` | |
| Video | `video_versions[]`: `type` (101/102/103), `url`, `width`, `height`; `video_dash_manifest`, `is_dash_eligible`, `number_of_qualities` | every video node had 3 progressive versions |
| Audio | `has_audio` (bool for videos, null for photos) | `video_duration` is **absent** on timeline nodes |
| Carousel children | `carousel_media[]`, in slide order: `pk`, `id`, `code`, `media_type`, `product_type`, `image_versions2.candidates[]`, `original_width/height`, `video_versions`, `has_audio`, `carousel_parent_id`; `carousel_media_count` | children have **no `taken_at`**; use the parent's |
| Caption | `caption.text`, `caption.created_at` | null if no caption |
| Pinned | `timeline_pinned_user_ids[]` (non-empty = pinned) | 3 pinned nodes were first in the list |
| Collab | `coauthor_producers[]` (non-empty = collab post) | |
| Paging | `page_info.end_cursor` (string), `has_next_page`, `has_previous_page` | |
| Viewer | `data.xdt_viewer.user.id` | |
| Partial errors | top-level `errors[]` (`message`, `severity`, `path[]`, `debug_link`) next to a complete `data` | seen once: `severity` ERROR for a field **inside** a node's `location`, while the node itself was complete |

**Caveats that affect change detection (TECH_SPEC §4.1 "Pinned posts" rule stays correct):**
1. The list is **not in date order**: pinned posts come first. Never take `edges[0]` as the newest; use the max `taken_at` or the watermark rule over all nodes, and de-duplicate by `pk` (12 unique `pk` seen).
2. On a collab post, `node.user.pk` and `owner_id.pk` were **another author's id**, and the profile owner appeared under `coauthor_producers[]`. The extractor must not require `node.user.pk` to equal the tracked id.
3. `errors[]` can accompany good data. Treat an error as fatal only when its `path` points at a field the extractor needs (media fields), not for any entry.

### 3. Single post, carousel or reel: `GET /api/v1/media/<media_pk>/info/`
Top-level keys: `num_results`, `more_available`, `items[]` (1 element), `auto_load_more_enabled`, `status` (`ok`). The path id equals the item's `pk`.

| Field | Path (under `items[0]`) | Notes |
|-------|-------------------------|-------|
| Ids | `pk`, `id` (`<pk>_<owner id>`), `code`, `strong_id__`, `fbid` | |
| Owner | `owner.pk`, `owner.id`, `owner.username`, `owner.is_private`; `user.*` is the same account | `user.pk == owner.pk` |
| Media type / kind | `media_type` 1 `feed` (photo), 8 `carousel_container`, 2 `clips` (reel) | |
| Taken | `taken_at` | |
| Image | `image_versions2.candidates[]`: `url`, `width`, `height` | **only 2 candidates: 720 px wide and 240 px wide**, even when `original_width` is 2192 or 3425. This endpoint is **lower quality than the timeline** for images |
| Original size | `original_width`, `original_height` | |
| Carousel | `carousel_media[]` (slide order), `carousel_media_count`; each child has `media_type` (1 seen), `product_type` (`carousel_item`), `carousel_parent_id`, `taken_at`, `image_versions2.candidates[]` | children have `taken_at` here; no video slide was in the capture |
| Reel video | `video_versions[]`: `type` (101/102/103), `url`, `width`, `height`, `bandwidth`; `video_dash_manifest`; `has_audio`; `video_duration` (float); `play_count`; `clips_metadata.audio_type` | 3 progressive versions, all 720x1280 |
| Caption | `caption.text`, `caption.created_at`, `caption.created_at_utc` | |
| Pinned / collab | `timeline_pinned_user_ids`, `coauthor_producers` | |

### 4. User lookup by username (IG-1 purpose): **not directly observed**
- The web app calls `PolarisProfilePageContentQuery` with a variable `id`, so the username-to-id step happened **before the capture** (page HTML or route data); it was **not seen**.
- Responses that can answer it, with evidence:
  - **`PolarisProfilePostsQuery` (input `username`)**: node `owner_id.pk` / `user.pk` give the id (all 11 non-collab nodes agreed with the profile query's `data.user.id`). Fails for an account with no posts, and for a private account the viewer does not follow (**untested**).
  - **`PolarisProfilePageContentQuery` (input `id`)**: `data.user` gives `id`, `pk`, `username`, `full_name`, `is_private`, `is_verified`, `media_count`, `follower_count`, `following_count`, `latest_reel_media`, `reel_media_seen_timestamp`, `friendship_status.following`, `blocking`, `outgoing_request`, `followed_by`. This is the "user by id" (IG-3 purpose) and the refresh call.
- IG-1 (`web_profile_info`) remains the best untested candidate for a direct username lookup.

### 5. Session validation: **not directly observed**
- No logged-out request, no 401, no `login_required` and no `accounts/current_user` call was captured.
- Responses that can serve as validation: `data.xdt_viewer.user.id` (story and timeline responses) and `data.viewer.user.id` (profile response). All three were the **same id** (the logged-in user) and differed from the story owner and the profile owner. A successful response with a viewer id means "logged in"; that the viewer root disappears or errors when logged out is **assumed, not observed**.
- Cheapest validator is a call the app already needs, so validation can ride on a normal extraction call instead of an extra request. Check `viewer id == stored ds_user_id` (TECH_SPEC §5.1).

### How ids link
`user id` (11-digit string, shown as `user.pk`/`user.id`/`reels_media[].id`) → `media pk` (19-digit string) → `media id` = `<pk>_<user id>`; `code` is the 11-char shortcode of the same media. Story query input is the **user id**; profile query input is the **user id**; posts query input is the **username**; media info input is the **media pk** (the shortcode-to-pk conversion is not observed; the timeline and story responses give both `pk` and `code`, so it is not needed in the tracking flow).

## Video: progressive MP4 vs DASH (AC3)
- Every video seen (story, timeline reels, media info reel) has **both** `video_versions[]` (progressive, `type` 101 to 103, URL path ends `.mp4`, no `bytestart`/`byteend`) **and** a `video_dash_manifest`. No video was DASH-only (0 of 4 timeline videos, 0 of 1 story, 0 of 1 reel).
- Whether the progressive versions contain the **audio track** is **not verified**: `has_audio` is true and the DASH manifest has a separate audio set, but the plain-download test only confirmed `video/mp4`. Check by playing a saved file.
- The three types appear at the same resolution in the capture (the sizes were equal); how `type` 101/102/103 maps to quality is **unverified**. Rule for T-013: pick the largest `width*height` when present, else by `type` order, and verify against a live phone.
- Keep `FAILED(unsupported_stream)` for the case "no `video_versions`, only a manifest"; it was never seen.

## Plain CDN download (AC2)
Test run by the Lead with `fetch(url, {credentials: 'omit'})` and a `Range` header (no cookies):

| Item | Result | Notes |
|------|--------|-------|
| Post image | **206**, `image/jpeg` | works without cookies |
| Post video | **206**, `video/mp4` | URL had no `bytestart`/`byteend` |
| **Story image** | **NOT TESTED** | pending |
| **Story video** | **NOT TESTED** | pending |

URLs are signed (query parameters such as `oh`, `oe`, `efg`, `_nc_*`); they were not recorded. Expiry time (`oe`) and whether a 403 follows after expiry were not measured.

## Seen side effect (BR-8): **confirmed**
Opening the story page in the browser **also fired `PolarisStoriesV3SeenMutation`** (root `xdt_mark_story_reel_seen`; variables `reelId`, `reelMediaId`, `reelMediaOwnerId`, `reelMediaTakenAt`, `viewSeenAt`). So viewing a story through the **web page** marks it as seen for the owner. The reel query alone (`PolarisStoriesV3ReelPageStandaloneQuery`) is a read; the mutation is a separate request made by the page when the story renders.

Consequence for page mode (T-014): either do not open the story viewer, or block the mutation. Options, for the Lead to decide:
1. **Block in the hook:** the fetch/XHR wrapper drops any request whose `fb_api_req_friendly_name` is `PolarisStoriesV3SeenMutation` before it is sent (match the name, not the `doc_id`, which rotates). Risk: the name may change; mitigate by also matching the root `xdt_mark_story_reel_seen` in the response and by a canary test.
2. **Call the reel query ourselves** from the page context (a page that is not the story viewer), reusing the page's tokens. Needs the `doc_id` discovered at runtime.
3. **Accept it.** BR-8 already says "Viewing a story through Storize counts as a view ... Storize does not promise anonymous viewing". If accepted, the doc and the UX copy stay as they are; if not accepted, option 1 or 2 is needed.
This is an **open question for TECH_SPEC §4.1, ADR-0003 and T-014** (see Decisions).

## Recommendation for T-013 (direct mode), with uncertainty

| Need | Recommended call | Confidence |
|------|------------------|-----------|
| Single post, carousel or reel (and `openMedia`) | `GET /api/v1/media/<pk>/info/` | **High**: observed, plain REST, no query string. Images are only 720 px wide, so prefer the timeline/story image when you already have it |
| Posts of a user, change detection | GraphQL `PolarisProfilePostsQuery` (needs `doc_id` + page tokens) **or** IG-5 `feed/user/<id>/` | GraphQL: **observed but heavy** (about 320 KB for 12 nodes in the capture, token and `doc_id` discovery needed). IG-5: **not observed, unverified**; probe it first on the dev phone because it is a lighter REST call |
| Story items | IG-2 `feed/reels_media/` (batched) **or** GraphQL `PolarisStoriesV3ReelPageStandaloneQuery` | IG-2 **unverified**. GraphQL **observed** with an array input. IG-2 is the call that avoids the web page's seen mutation by construction |
| Cheap "anything new?" signals | `latest_reel_media` (profile `data.user`, story reel; also present on timeline `node.user` in the real responses but not in the fixtures) for stories; `media_count` (profile `data.user`) and the newest non-pinned `taken_at` for posts | **Medium**: field present and consistent in the capture; the use as a change signal is not tested over time |
| User by id / refresh | `PolarisProfilePageContentQuery` (or IG-3, unverified) | Medium |
| Username to id | `PolarisProfilePostsQuery` by `username` (observed) or IG-1 (unverified) | Low to medium |
| Session validation | viewer id from any of the above vs `ds_user_id` | Medium (logged-out behaviour unseen) |

**Uncertainty to state in T-013:** none of the REST candidates is proven; the only GraphQL calls are proven but need `doc_id` and page tokens that rotate. Suggested first step in T-013 is a **live probe tool** (debug, on the dev phone, through `RequestGovernor`) that tries IG-1, IG-2, IG-3, IG-4 and IG-5 once each with the session headers and records only status and top-level key names. If they work, direct mode is REST only. If they do not, direct mode is limited to `media/<pk>/info/` and the GraphQL calls move to page mode (T-014), where the page supplies `doc_id` and tokens.

## Media quality rule (input for §4.1)
- Images: choose the candidate with the largest `width*height` from the **timeline** or **story** response, not from `media/<pk>/info/` (capped at 720 px).
- Video: choose from `video_versions[]` (progressive MP4); sizes are on post/reel versions but not on story versions.
- Carousel: iterate `carousel_media[]` in order; slide type from `carousel_media[].media_type`.

## Pending and open items
| Item | Task / AC | State |
|------|-----------|-------|
| Plain download of a **story** image and video | AC2 | **pending: next capture session (Lead to schedule)** |
| Page-mode hook in the debug WebView on a phone | AC4 | **pending: next capture session (Lead to schedule)** (the capture used a desktop in-page hook; the hook source is `packages/storize_instagram/assets/hook.js`) |
| Headless WebView in a background isolate on both P-4 phones | AC5, sets `pageModeInBackground` (AQ-6) | **deferred to T-014** (Lead adds it to T-014's acceptance criteria); AQ-6 stays undecided until then |
| Minimal header set for REST calls | Decision 3 | unknown (headers were not captured) |
| **Photo story** (and close-friends and link-sticker story shapes) | T-013 mapping fixtures | **needed**, not in the capture |
| **Video slide in a carousel** (media info and timeline) | T-013 mapping fixtures | **needed**; timeline carousel children have `video_versions` and `has_audio` keys, but the only carousel had two image slides |
| **Logged-out and error responses** (401, `login_required`, `checkpoint_required`, rate limit) | T-013 failure-map fixtures (AC4) | **needed**, not captured |

## Proposed TECH_SPEC / ADR updates (for the Lead)
1. **§4.1 candidate table:** mark IG-1 to IG-5 "not observed; the web app uses GraphQL + `media/<id>/info`"; add the GraphQL rows above and the `doc_id` rotation rule.
2. **§4.1 steps / ADR-0003:** record the story "seen" side effect and the chosen answer (block in the hook, call the query ourselves, or accept under BR-8) and its consequence for page mode.
3. **§4.1 media quality:** images from the timeline/story response, not from `media/<pk>/info/` (720 px cap); progressive `video_versions` exist for every video seen.
4. **ADR-0010 (change detection):** add `latest_reel_media` (story) and `media_count` (posts) as cheap signals; keep the pinned-posts rule (timeline is not date ordered; collab nodes can carry another author's id).
5. **T-013 AC:** add a live probe as the first step; `SchemaChanged` must ignore non-fatal `errors[]`.
6. **T-014 AC:** the hook must identify GraphQL by `fb_api_req_friendly_name`, and block `PolarisStoriesV3SeenMutation` if the Lead chooses so.

## Decisions needed
1. Seen side effect: block, self-call or accept (BR-8 already accepts it)?
2. Direct mode scope for T-013 after the live probe.
3. Story-media plain download test (needs one more short capture).
4. `pageModeInBackground` default (AQ-6), after the phone test.
5. DASH-only videos: none seen; keep `FAILED(unsupported_stream)` unchanged.

## Fixtures
Sanitized fixtures: `packages/storize_instagram/test/fixtures/real/{story,profile,post_photo,post_carousel,reel}/`. Each folder holds only the bodies the extractors need, `report.md` and `summary.json` (`docId` removed). The synthetic `synthetic.har` there is fake data used only by the sanitizer tests. See `real/README.md` for how they were produced.

## v0.3 (unverified): post pages and highlights (T-041)

Everything in this section is an **assumption** written from the T-040/T-041 design. None of it was captured. Fixtures are synthetic (`test/fixtures/synthetic/timeline_page*.json`, `highlights_tray.json`, `highlight_reel.json`). Replace them with sanitized real captures after the device checks in [DEVICE_TESTS](DEVICE_TESTS.md).

| Item | Assumption | Fails closed how |
|------|-----------|------------------|
| Post paging variables | `PolarisProfilePostsQuery` accepts top-level `after` (the previous `page_info.end_cursor`) and `first` next to `data.count`. The capture saw the first page only. | A rejected request is a normal failure; a response without `page_info.has_next_page` is `SchemaChanged` (history is never cut short silently). |
| Paging response | Same connection root and node shape as the first page; `page_info.end_cursor` is a string, `has_next_page` a bool. | `SchemaChanged` to page mode. |
| Page-mode paging | Scrolling the profile makes the web app fetch more of the connection. The response may carry another friendly name (for example a `..._connection` suffix), so page mode matches the name prefix **or** the root `data.xdt_api__v1__feed__user_timeline_graphql_connection`. | After `maxScrollSteps` (30) or 60 s: what was collected, or `SchemaChanged('page_scroll_stalled')` if nothing older than the cursor was reached. |
| Cursor | Own text format `v1\|<taken_at>\|<ig end_cursor>`. Direct uses the Instagram part; page mode uses `taken_at` (older posts, so two posts with the same second can be missed). A page-mode cursor makes direct mode answer `SchemaChanged`. | n/a |
| Highlights tray query | Friendly name `PolarisProfileStoryHighlightsTrayContentQuery` (the T-002 capture saw a tray query but did not record its name); page mode also accepts any name holding `Highlights` and `Tray`. Variable `user_id`. | Missing `doc_id` is `SchemaChanged`, then page mode. |
| Tray response | `data.highlights.edges[].node` with `id` (`highlight:<id>`), `title`, `cover_media.cropped_image_version.url`, `latest_reel_media` (unix s), `media_count`. | Nodes without `id` are skipped; all broken is `SchemaChanged`. |
| Highlight items | The stories reel query with `reel_ids_arr` = `["highlight:<id>"]` answers reels with `id` `highlight:<id>`, `reel_type` `highlight_reel`, optional `title`, story-shaped `items[]` without a required `expiring_at`. | `SchemaChanged`. |
| Highlight page | `/stories/highlights/<id>/` fires the reel query for the highlight and (probably) `PolarisStoriesV3SeenMutation`. The mutation stays blocked by name in the hook; a reply to it trips the `SeenGuard`. | `seen_block_leak`, guard tripped. |
| REST | No REST paging or highlight call is guessed; `RestTransport` answers `SchemaChanged` (page mode). | n/a |

## v0.3 REST fallback (device-verify)

Found on device (2026-11-24): `PageDiscovery` (`doc_id`s and page tokens) lives in memory per isolate and only a page-mode run fills it. Page mode is off in the background, so background checks, today's content on add, history and highlights got `SchemaChanged` on every GraphQL call. A REST call on `www.instagram.com` with the session cookies, `X-IG-App-ID` and `X-Requested-With: XMLHttpRequest` worked (`accounts/edit/web_form_data/`). `current_user` gave 400.

**Order per call (`FallbackTransport`, the default in `selectTransport`):**
1. GraphQL only if the `doc_id` of every query the op needs and the page tokens are available now; otherwise REST straight away (no wasted request).
2. GraphQL `SchemaChanged`: REST once.
3. REST `SchemaChanged` or `UnknownFailure`: returned, so the platform still falls back to page mode where allowed.
4. Rate limit, session, private, not found, network: returned as they are, never retried on the other transport.

**REST endpoints (all read-only GET through `RequestGovernor`; the headers are the session headers `verifySession` uses). Shapes are assumptions until D5 passes:**

| Op | Request | Mapping |
|----|---------|---------|
| Stories | `feed/reels_media/?reel_ids=<userId>` | `reels{}` or `reels_media[]`, story mapper |
| First posts | `feed/user/{id}/?count=12` | `items[]` |
| Post page | `feed/user/{id}/?count=12&max_id=<cursor>` | `items[]`, `more_available` is `hasNextPage`, `next_max_id` is the cursor (absent at the end) |
| Highlights tray | `highlights/{userId}/highlights_tray/` | `tray[]`: `id` (`highlight:<n>`, prefix stripped), `title`, `latest_reel_media`, `cover_media.cropped_image_version.url` |
| Highlight items | `feed/reels_media/?reel_ids=highlight:<id>` (one `reel_ids` per id, at most 20) | `reels{}` items, story mapper, kind highlight, extras `highlightId`, `highlightTitle`, `highlightOrder` |
| Users | `users/web_profile_info/?username=`, `i.instagram.com/api/v1/users/{id}/info/` | unchanged |

The `seen` endpoints are never called. Logs carry the op, the transport and the failure type only.

**Risks:** the post-page and tray shapes are unobserved; a wrong shape is `SchemaChanged` (page mode). `users/{id}/info` and `current_user` may answer 400 as `current_user` did.
