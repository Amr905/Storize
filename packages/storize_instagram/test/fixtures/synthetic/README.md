# Synthetic fixtures (T-013): synthetic, unverified

Hand-made JSON for shapes that the real capture does not contain: photo story, live item, close friends, link
stickers, DASH-only video, video slides in a carousel, a collab post, a pinned fresh post, REST envelopes (IG-1 to IG-5)
and the failure-map responses (login_required, checkpoint, rate limit and so on).

**Nothing here was observed from Instagram.** The shapes follow INSTAGRAM_EXTRACTION.md and the TECH_SPEC candidate
table; the failure bodies are the commonly reported ones. Replace them with real captures when they exist (the live
probe, T-013 AC7). All values are fake: ids and strings start with `ZZFAKE`, URLs use `cdn.example.test`.

## T-041 additions (history and highlights): synthetic, **unverified**
`timeline_page1..3.json` (a three-page connection: cursor in `page_info.end_cursor`, `has_next_page` true, true, false;
page 1 has an old pinned post), `highlights_tray.json` (`data.highlights.edges[].node`, one id with the `highlight:`
prefix, one without, one broken node) and `highlight_reel.json` (reels query answer for `highlight:<id>`, `reel_type`
`highlight_reel`, no `expiring_at`). Shapes are assumptions: see INSTAGRAM_EXTRACTION.md "v0.3 (unverified)".
