# Synthetic fixtures (T-013): synthetic, unverified

Hand-made JSON for shapes that the real capture does not contain: photo story, live item, close friends, link
stickers, DASH-only video, video slides in a carousel, a collab post, a pinned fresh post, REST envelopes (IG-1 to IG-5)
and the failure-map responses (login_required, checkpoint, rate limit and so on).

**Nothing here was observed from Instagram.** The shapes follow INSTAGRAM_EXTRACTION.md and the TECH_SPEC candidate
table; the failure bodies are the commonly reported ones. Replace them with real captures when they exist (the live
probe, T-013 AC7). All values are fake: ids and strings start with `ZZFAKE`, URLs use `cdn.example.test`.
