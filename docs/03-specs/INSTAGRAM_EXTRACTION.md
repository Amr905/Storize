# Instagram extraction: results of the T-002 spike

Status: **skeleton, pending capture.** Every "expected" value below is **UNVERIFIED**: it comes from TECH_SPEC §4.1 and from
general knowledge of open-source Instagram clients, not from watching the real pages. Nothing here is a fact until a row
says "confirmed" with a capture reference.

Related: [TECH_SPEC §4.1](TECH_SPEC.md) · [ADR-0003](../decisions/0003-instagram-access-webview-session-http.md) · [ADR-0010](../decisions/0010-change-detection-batched-reels-media.md) · [CAPTURE_GUIDE](CAPTURE_GUIDE.md) · task T-002 in [TASKS.md](../04-tasks/TASKS.md)

## Sources for the expected shapes (read-only references)
- TECH_SPEC §4.1, candidate table IG-1 to IG-5 (itself "known from open-source clients").
- Open-source clients that use these private web/mobile endpoints and are the intended places to verify field names:
  - instaloader: https://github.com/instaloader/instaloader (`instaloader/structures.py`, `instaloader/instaloadercontext.py`)
  - instagrapi: https://github.com/subzeroid/instagrapi (`instagrapi/extractors.py`, `instagrapi/mixins/user.py`, `instagrapi/mixins/story.py`)
- **Not fetched this round:** direct reads of those repositories were blocked by a permission timeout in the agent environment, and the web search returned only commercial scraper pages. So the field names below are **not backed by a fetched citation**. The next step (Lead or user) should open the files above and tick each field, or the real capture replaces them anyway.

## How to read this document
- Fill "Observed" columns from the sanitized `report.md` and `bodies/*.json` in the returned folders.
- Status values: `confirmed` (seen, matches), `replaced` (seen, different request or shape: describe), `missing` (not seen).
- Keep the placeholders from the sanitizer (`user_1`, `media_1`); never paste cookies, signed URLs or real names.

## IG-1 to IG-5 status

| # | Purpose | Candidate (unverified) | Status | Capture ref | Notes |
|---|---------|------------------------|--------|-------------|-------|
| IG-1 | Username to user | `GET /api/v1/users/web_profile_info/?username={u}` | pending capture | | |
| IG-2 | Stories (batched) | `GET /api/v1/feed/reels_media/?reel_ids={id}&reel_ids=...` | pending capture | | |
| IG-3 | User by ID | `GET https://i.instagram.com/api/v1/users/{id}/info/` | pending capture | | |
| IG-4 | Validate session | `GET /api/v1/accounts/current_user/?edit=true` | pending capture | | |
| IG-5 | Latest posts | `GET /api/v1/feed/user/{id}/?count=12` | pending capture | | |

## Expected response shapes (UNVERIFIED)

| Request | Expected fields (unverified) | Source |
|---------|------------------------------|--------|
| IG-1 | `data.user`: `id, username, full_name, is_private, followed_by_viewer, blocked_by_viewer, profile_pic_url`; possibly `edge_owner_to_timeline_media.edges[].node` (`shortcode, is_video, display_url, video_url, taken_at_timestamp, dimensions`) | TECH_SPEC §4.1; instaloader-style GraphQL shape |
| IG-2 | `reels.{userId}.items[]` and `reels_media[]`: `pk, id, taken_at, expiring_at, media_type (1 photo, 2 video), image_versions2.candidates[] (width, height, url), video_versions[] (type, width, height, url), video_duration, has_audio, audience, story_link_stickers`; `user.pk, user.username` | TECH_SPEC §4.1; instagrapi-style `extract_story_v1` |
| IG-3 | `user.pk, user.username, user.is_private`; 404 means gone | TECH_SPEC §4.1 |
| IG-4 | `user.pk` equals the `ds_user_id` cookie | TECH_SPEC §4.1, §5.1 |
| IG-5 | `items[]`: `pk, id, code, taken_at, media_type (1, 2, 8), product_type ("feed", "clips" for reels, "carousel_container"), carousel_media[] (each with image_versions2 / video_versions), caption.text, image_versions2, video_versions, has_audio`; paging via `more_available`, `next_max_id` | TECH_SPEC §4.1; instagrapi-style `extract_media_v1` |
| CDN-1 | Plain `GET` of `image_versions2.candidates[].url` / `video_versions[].url`; signed query parameters; 403 means expired | TECH_SPEC §4.1 |

Common request headers expected (unverified): session cookies, `User-Agent`, `X-IG-App-ID`, `X-CSRFToken`, `Referer: https://www.instagram.com/`. The sanitized summary shows header **names** for every request (known names only; anything else is `<hdr>`) plus the values of `x-ig-app-id` (digits only), `user-agent` (reduced to family, major version and OS, for example `Chrome/131 (Android, WebView)`), `content-type`, `accept` (known MIME types only). Query parameter names follow the same rule (`<name>` otherwise); object keys in bodies are default-deny too (only the code allowlist and `tool/keep_keys.txt` stay, everything else is `key_N`); `message`/`error_type` keep only the failure-map values (`login_required`, `checkpoint_required`, ...); `doc_id` is kept only as 6-20 digits and `query_hash` only as 16-64 lower-case hex.

## Page types (tables to fill after capture)

For each page: which request(s) carry the media links, and whether the page embeds its data in HTML instead (the sanitizer report has an "HTML documents" table for this).

### Stories: `/stories/<user>/`
| Request | Method + URL pattern | Required headers / cookies | Response fields used | Notes |
|---------|---------------------|----------------------------|----------------------|-------|
| _(pending)_ | | | | |

Expected (unverified): IG-2 returns the items. Record `expiring_at` and whether the story page itself also triggers a "seen" request (BR-8).

### Profile and posts: `/<user>/`
| Request | Method + URL pattern | Required headers / cookies | Response fields used | Notes |
|---------|---------------------|----------------------------|----------------------|-------|
| _(pending)_ | | | | |

Decision input: is IG-1 (embedded latest ~12 posts) lighter than IG-5 for change detection (ADR-0010)? Does paging cost one extra request?

### Single post (photo, video, carousel): `/p/<code>/`
| Kind | Request | Method + URL pattern | Response fields used | Notes |
|------|---------|---------------------|----------------------|-------|
| Photo | _(pending)_ | | | |
| Video | _(pending)_ | | | |
| Carousel | _(pending)_ | | | slide order, mixed photo/video slides |

### Reel: `/reel/<code>/`
| Request | Method + URL pattern | Response fields used | Notes |
|---------|---------------------|----------------------|-------|
| _(pending)_ | | | `product_type == "clips"`? same shape as a video post? |

## Auto-detected media field paths (from `report.md`)
| Field | Path observed | Page types | Notes |
|-------|---------------|------------|-------|
| `video_versions` | _(pending)_ | | |
| `image_versions2` | | | |
| `carousel_media` | | | |
| `expiring_at` | | | |
| `taken_at` | | | |
| `product_type` | | | |
| `dash_manifest` / `video_dash_manifest` | | | |

## CDN plain-download results (AC2)
| Item | Plain GET without cookies (incognito) | HTTP status | Notes |
|------|---------------------------------------|-------------|-------|
| Story or post image | pending | | |
| Video | pending | | `bytestart`/`byteend` needed? |

## Progressive MP4 vs DASH (AC3)
Pending. Expected (unverified): `video_versions[]` holds progressive MP4 URLs and `video_dash_manifest` may also exist. Record: which video qualities are in `video_versions`, whether any has audio (`has_audio`), and whether any video has **only** a DASH manifest. If DASH-only exists, TECH_SPEC §4.1 marks it `FAILED(unsupported_stream)` and needs an open question.

## Page-mode hook in the debug WebView (AC4)
Pending the optional phone check. Tool: `flutter run --flavor dev -t lib/main_debug_inspector.dart`; hook source `packages/storize_instagram/assets/hook.js`.
| Page | API paths seen by the hook | Same top-level keys as desktop? |
|------|----------------------------|----------------------------------|
| Stories | pending | |

## Background headless WebView (AC5)
Pending a phone test (needs T-014 plumbing and the two P-4 phones).
| Phone | Android version | `HeadlessInAppWebView` works in a workmanager isolate? | Notes |
|-------|-----------------|---------------------------------------------------------|-------|
| _(pending)_ | | | |

Result sets the `pageModeInBackground` default (AQ-6).

## Decisions needed (fill after capture)
1. Which request is the post change-detection call: IG-1 or IG-5 (lighter, pagination cost)?
2. Any IG-n marked `replaced` or `missing`: propose the replacement request and approve it (port changes need Lead approval).
3. Does direct mode work with only the observed headers, or does it need extra ones (`X-IG-WWW-Claim`, `X-ASBD-ID`, ...)? Record the minimal working set.
4. DASH-only videos: skip, or accept as `FAILED(unsupported_stream)`?
5. `pageModeInBackground` default (AQ-6).
6. Does fetching stories mark them as seen (BR-8), and is that acceptable?
7. Pages that embed data in HTML only: does page mode need a DOM fallback for them?

## Fixtures
Sanitized fixtures from the returned folders go to `packages/storize_instagram/test/fixtures/` (after a second sanitizer check and gitleaks). The synthetic test fixture `synthetic.har` there is fake data used only by the sanitizer tests.
