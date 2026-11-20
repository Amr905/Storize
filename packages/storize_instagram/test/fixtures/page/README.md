# Fake page fixtures (T-014)

Invented data only (`ZZFAKE_*`, `example.test`). No real account, id, URL, token or `doc_id`. They are the shapes
page mode needs besides the real sanitized captures in `../real/`.

- `reels_empty.json`: a story reel reply with no reels (the user has no story).
- `reels_other_user.json`: a reel reply for another user id (not the one asked for).
- `dom_result.json`: the JSON string the read-only DOM script returns (CDN and non-CDN URLs, placeholders).
- `unrelated_graphql.json`: a GraphQL reply that page mode must ignore.
