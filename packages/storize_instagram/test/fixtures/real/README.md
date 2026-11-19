# Real capture fixtures (T-002, 2026-11-20, regenerated in round 2)

Sanitized output of `tool/sanitize_har.dart` (with `tool/keep_keys.txt`, no extra flags) for five captures of a public
account whose owners agreed. Placeholders only: no names, IDs, URLs or captions.

- `bodies/` holds only the responses the extractors need (story reel page, profile user, timeline connection, media info).
  `report.md` and `summary.json` describe the full capture, so they mention bodies that are not committed.
- `summary.json`: the `docId` field was removed by hand after sanitizing (per-deploy query ids are not committed). This
  is the only manual edit; redo it whenever the fixtures are regenerated.
- Round 2 sanitizer rules (all visible here): CDN hosts reduced to `scontent.fbcdn.net` style (no edge or region label);
  floats rounded to 2 decimals; numbers under a location object are `null`; `latest_reel_media` kept only at the profile
  `data.user` and the story reel, `null` elsewhere.
- Guards: `test/tool/real_fixtures_{shape,host_guard,float_guard}_test.dart`. Findings: `docs/03-specs/INSTAGRAM_EXTRACTION.md`.
- Never add a raw HAR here.
