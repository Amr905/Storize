# 0010 — Change detection for stories (batched) and posts (per account, watermark) (revised v0.2)

- Status: proposed
- Date: 2026-11-19

## Context
Each run must find new stories, and (v0.2) new posts, for every account it tracks, cheaply. Only posts published after an
account was added count (FR-63).

## Options considered — stories
1. **Batched reel request for ≤ 20 tracked IDs, diffed against the DB by `remote_id`** ✅ works for followed and public accounts; about 3 calls for 50 accounts.
2. **The login account's story tray first** — ❌ misses public accounts it doesn't follow.
3. **One request per account** — ❌ 50 calls per run.

## Options considered — posts
1. **Per-account "latest posts" request (IG-5 or the profile-info request, whichever the spike shows is lighter), filtered by a per-account watermark (`posts_watermark_at`) and the DB unique key** ✅
   - Simple and exact.
   - Pinned posts are ignored automatically (they're older than the watermark).
2. **Compare the profile's post count** — ❌ a deletion plus a new post cancels out; it still needs the list to download.
3. **Login account's home feed** — ❌ only followed accounts, ranked feed, misses posts.

## Decision
Stories: option 1. Posts: option 1. The watermark is set when the account is added (newest existing post time, or "now"
if the account has no posts) and moved forward after each successful run.

## Consequences
- Fetching stories can mark them as "seen" by the login account (BR-8).
- If more than 12 new posts appear between two post runs, only the latest 12 are seen. That's acceptable at a 3-hour interval;
  the spike checks whether pagination is cheap.
- A post edited later isn't re-downloaded (EC-22).
