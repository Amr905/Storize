# Device tests and soak checklist

Status: v0.2 (T-037, 2026-11-22). Owner: the user. Everything here needs a real phone; nothing off-device can check it.
Consolidates: T-002 AC4, T-014 AC9, T-013 AC7, T-005 F-6, T-021 AC5, T-022, T-026, T-029a, T-027 and T-037 AC2.
Binding rules: ADR-0003 Addendum (seen is always blocked, document-start hook, WebView lease), ADR-0009 (governor).

**How to use it.** Do the parts in order (A, B, C). Write PASS or FAIL plus one line in the table at the end. Any mismatch with
**Expected** is a FAIL: stop that test, do not retry on a real account, and tell the Lead. Each test starts with **Needs:** (what must
exist first). If a "Needs" is missing, skip the test and write "blocked".

## 0. Before you start
| Item | Why |
|---|---|
| Two Android phones (P-4): **A** Samsung, **B** Xiaomi or Oppo; one on Android 9 or lower if you can | Background rules differ by maker and version |
| The **test Instagram account** (P-3), logged in inside the app, on both phones | Never use a personal account |
| An **Owner account** you own, with one photo and one video story posted in the last 24 h, plus a third device or PC to read its viewers list | To see whether the test account "viewed" |
| Debug builds: `cd app && flutter run --flavor dev` (inspector: `-t lib/main_debug_inspector.dart`), USB, a PC with Chrome | Build and WebView debugging |
| Wi-Fi, battery above 50 % | Stable start |

**Safety rules.**
1. Test account only. The Owner account only owns stories.
2. Every Instagram request goes through the governor. Wait **10 minutes** between two page loads of one user; at most **6 page loads per hour**.
3. If Instagram shows "Please wait", a login screen, a checkpoint or "action blocked": stop everything and tell the Lead. Do not log in again.
4. Never copy cookies, tokens, full story-file URLs or other people's content into a message, screenshot, bug report or this file (the repo is public). Record status codes and key names only.

Words: **page mode** = the app loads the real Instagram page in a hidden WebView and reads what the page fetched. **Hook** = the script
(`assets/hook.js`) injected into it. **Seen** = Instagram tells the story owner who viewed (cannot be undone). **Blocked** = the hook
answers the "mark as seen" request itself, so it never leaves the phone.

---

## Part A. Page mode and extraction (T-002, T-013, T-014)

### A1. Hook runs in the phone WebView (old T-002 AC4)
**Needs:** inspector build (visible WebView). This proves the hook, not the headless adapter.
1. Phone A: log in inside the inspector with the test account, open `instagram.com`, wait 10 s, open the log list.
2. PC: `chrome://inspect`, open the WebView console, type `window.__storizeHookInstalled`.

**Expected:** several log lines with status 200 and top-level key names (one has `data`), **no values, query strings, cookies or tokens**; the console prints `true`. Repeat on Phone B. If a phone shows nothing, note its Android and WebView versions (Settings, Apps, Android System WebView).

### A2. Document-start support fails closed
**Needs:** a page-mode story trigger (debug action "page-mode story load", T-015/T-021 wiring).
1. Note the Android System WebView version on each phone. Run one story load of the Owner account.

**Expected:** no `page_hook_unsupported` log line; the load proceeds.
2. *Optional, developer only:* on an emulator or old phone with an old WebView, repeat. **Expected:** `page_hook_unsupported`, no page opens, viewers list unchanged.

### A3. The seen mutation is never sent (UD-3, most important)
**Needs:** the real page-mode trigger (the inspector alone does not exercise `webview.dart`). Run for a photo and a video story, on both phones.
1. On the third device write down the viewers **count** of both stories (no names).
2. Phone A: trigger a page-mode story load of the Owner account. Wait for `op=fetchStories ok`.
3. Read the log line `accepted=... blocked=...`.

**Expected:** `blocked` is 1 or more; no `seen_block_leak` line. After 2 minutes the viewers list of both stories is unchanged and the test account is not in it.
4. Repeat on Phone B, and for a link-sticker or close-friends story if available.
5. *Optional:* in the inspector console run `fetch('/api/v1/stories/reel/seen/', {method:'POST', body:'x=1'}).then(r => r.status)`. **Expected:** `200` and a `blocked` notice.

If the test account **is** in the viewers list: **FAIL (critical)**. Stop all page-mode story loads and tell the Lead (phone, story type, log lines around `blocked`).

### A4. The page tolerates the fake reply
**Needs:** A3 trigger. Watch Chrome DevTools (Network, filter `graphql`) for 30 s during one load.

**Expected:** at most one blocked notice per story page; no stream of repeated requests; no error toast on the page.

### A5. Unverified assumptions of the story page (report only, do not change code)
**Needs:** inspector build and, for 5c, desktop Chrome logged in as the **Owner** account (never the test account, which would mark the story seen).
- **5a** A followed account with no story: one page-mode load. Expected: ends on the profile page, "no stories" after about 2 s (not a 20 s timeout). Write what really happened.
- **5b** Open `instagram.com/stories/<owner>/` without a media id. Expected: it loads the reel. If not, page mode needs the id: ask the Lead.
- **5c** Owner views its own story with DevTools open; find the `SeenMutation` request. Write how it was sent: fetch, XHR or beacon. Confirm the owner is not listed as its own viewer.
- **5d** Count `ReelPage` requests. Expected: one or two. If two, is the first empty?

### A6. Cookie cleanup
**Needs:** A3 trigger and a debug action that prints the `instagram.com` cookie **count** (names and values must not be shown; the headless WebView is gone after a run so DevTools cannot attach). If that action does not exist: blocked.
1. After one finished load: count must be 0 (and no web storage).
2. Start a load, swipe the app away mid-run, reopen, check the count. Known limitation: it may be above 0.
3. Run one more load to the end. **Expected:** the count is 0 again (the wipe happens at the start of each run). If the killed run's cookies survive this run: FAIL.

### A7. WebView lease against the login screen
**Needs:** T-015 and T-026 wiring.
1. Open the login screen (S-02), do not finish. Trigger a page-mode load. **Expected:** `webview_busy` at once, no hidden browser, login keeps working.
2. Finish the login, trigger again. **Expected:** runs normally.
3. Start a load, then open S-02. **Expected:** it waits or says try again, never a login that fails for no reason.
4. Kill the app on S-02, reopen, trigger page mode after 5 minutes. **Expected:** runs (the lease expired).

### A8. Headless WebView in the workmanager isolate (T-014 AC9)
**Needs:** T-021 wiring, Settings "page mode in background" **on**, a debug "run check now". Both phones (one on Android 9 if possible).
- **8a** Screen on, app open, one page-mode load. **Expected:** `op=fetchStories ok`, `accepted=` 1 or more.
- **8b** Start "run check now", go to the home screen. **Expected:** a page-mode run inside the background task that ends; no crash, no `webview_unavailable`.
- **8c** Unplug, screen off 30 min, then `adb shell dumpsys deviceidle force-idle`; run the job with `adb shell cmd jobscheduler run -f <dev package id> <job id>` (the debug menu shows both) or wait for the schedule; later `adb shell dumpsys deviceidle unforce`. **Expected:** the check ran and ended, or the system deferred it and it ran later. A log line `op=... start` with no end, or a crash, is a FAIL.
- **8d** Battery saver on (Xiaomi: app battery option "No restrictions" once, "Battery saver" once). **Expected:** record whether it ran; if stopped, the app shows "skipped" or "deferred", never a stuck "running".
- **8e** After 3 runs check Settings, Battery, App usage. **Expected:** no leftover WebView process; app not in the foreground.

### A9. The 20 s timeout on a slow network
**Needs:** A3 trigger. Phone A, cold start (reboot first), weak or throttled network.
1. Start one page-mode profile load; note the time from the start to the result lines. Repeat up to 5 times in an hour (6 loads per hour limit).

**Expected:** 3 to 12 s on Wi-Fi; the slowest load is under 20 s. A `page_timeout` for a page that would have loaded seconds later means 20 s is too short: report the times. More than one `page_open_timeout`: report with the phone model.
2. Network off, start a load. **Expected:** a failure within about 20 s, no hang, no hidden browser left.

### A10. Live probe (direct mode) and the story media plain GET (T-013 AC7)
**Needs:** the debug action that calls `IgProbe.run` and `IgProbe.checkCdn`. Phone A, test account. Run each **once** per day.
1. Probe: 5 calls IG-1 to IG-5. **Expected:** 5 lines like `IG-3 status=200 keys=[user]`; no value, URL or cookie. Give the Lead the table (it goes into INSTAGRAM_EXTRACTION.md "Live probe").
2. CDN check: one photo and one video story file of the Owner account via a plain HTTPS GET. **Expected:** status 200, `image/...` or `video/...`, size above 0 for both. Do not open or save the content outside the app.
3. Also confirm the discovered `doc_id` and tokens let direct mode work.

On 401, 403, 429 or a checkpoint: write the status, stop, do not retry.

### A11. Requests from a worker or iframe
**Needs:** inspector build and Chrome DevTools. Owner account viewing its own story is safe.
1. Network tab, filter `SeenMutation`, check the **Initiator** and the frame selector. **Expected:** main frame, not a worker or iframe (otherwise FAIL, report before any real story load).
2. Sources tab, look for Workers and Service workers. Write what you see.

---

## Part B. Background, storage and system (T-005, T-021, T-022, T-026, T-029a, T-027)

### B1. Database opens in the background isolate (T-005 F-6)
**Needs:** T-021 wiring. 1. Install the dev build, add one target, close the app. 2. Run "run check now" from the debug menu (or wait for the schedule) with the app **not** running. 3. Open the app, then Activity.

**Expected:** the check appears in Activity (its row was written by the background isolate and read by the UI without a "database locked" error); no crash log from `StorizeDatabase.open`. Repeat 3 times while using the app at the same time.

### B2. Schedules survive reboot and force-stop (T-021 AC5)
**Needs:** T-021 wiring, one active target, story interval 15 min (Settings). Both phones.
1. Reboot the phone and do **not** open the app. After 30 min check Activity or the log. **Expected:** at least one periodic check ran after boot.
2. Settings, Apps, Storize, Force stop. Open the app once. After 30 min check again. **Expected:** the schedule is back and checks run. (Some makers block background starts after a force-stop until the app is opened: write which.)
3. Log out (S-13). **Expected:** no checks run afterwards.

### B3. Notifications and deep links (T-022)
**Needs:** T-022 wiring, Settings notifications on, POST_NOTIFICATIONS granted, a target that gets a new story and one that gets a new post (use the Owner account as a target).
1. Let a check find 3 or more new items for one target. **Expected:** one grouped notification (summary plus items), not a flood.
2. **Cold start:** swipe the app away, tap a story notification. **Expected:** opens S-06 (or S-15 for a post) on that item, back goes to the Library.
3. **Warm start:** app in the background, tap again. **Expected:** same destination, no duplicate screens.
4. Session problem notification (log the test account out on the web, wait for a check). **Expected:** a login-problem notification that opens Account (S-13).
5. Turn each notification type off in Settings. **Expected:** no notification of that type.

### B4. Permission prompts and battery settings (T-026)
**Needs:** T-026 wiring. A freshly installed build on each phone (one on Android 13+ for notifications, one on Android 8 or 9 for storage if available).
1. S-03 "Allow" for notifications. **Expected:** the system prompt (Android 13+); deny twice, then "Open app settings" appears and works.
2. Android 8 or 9 only: the Storage card appears, the prompt works, and the first download then lands in `Pictures/Storize/<username>/` in the gallery app.
3. "Open battery settings": **Expected:** the right system page for the maker. Per OEM, follow the steps shown (Samsung: Never sleeping apps; Xiaomi: Autostart on and No restrictions; Oppo: allow background activity and auto-launch). Return to the app. **Expected:** the warning clears after Unrestricted is set.

### B5. Full-size photo and owner scoping (T-029a)
**Needs:** T-029a wiring and at least one saved story photo, one Android 10+ phone and one on Android 9 or lower.
1. Open a saved photo story (S-06) and a post slide (S-15); pinch to zoom. **Expected:** sharp full-size image (not the thumbnail), no crash on a 4000 px photo.
2. Put a copy of a photo you took yourself into `Pictures/Storize/<username>/` with a file manager and try to open it through the app's code path if a debug action exists. **Expected:** the app refuses files it does not own (owner scoping); if no debug action exists write "not testable".
3. Delete a saved file in the gallery app, reopen the item. **Expected:** "This file is missing" with Remove from library.

### B6. Library timing with real drift (T-027)
**Needs:** around 2,000 saved items (the soak produces some; otherwise use the debug seed action if present). 1. Cold-start the app and open the Library; time to the first tiles and to smooth scrolling. 2. Switch Stories and Posts. **Expected:** first tiles under about 1 s, no dropped-frame stutter while scrolling, no ANR. Write the item count and times.

### B7. The automated end-to-end flows on a device (T-037 AC1)
**Needs:** a connected phone or emulator. Run `cd app && flutter test integration_test --flavor dev -d <device id>`.
**Expected:** all 6 tests pass (they use fakes only, so no Instagram traffic).

---

## Part C. 24 h soak (T-037 AC2, NFR-2, NFR-3)
**Needs:** Parts A8, B1 to B4 passed, about **20 test targets** (public accounts that post stories often; do not use people who did not agree to be tracked; the Owner account is one of them), story interval 30 min, page mode in background per your A8 result, notifications on, battery Unrestricted. Both phones, same targets.

**Start.**
1. Charge to 100 %, unplug, note the start time and battery %. Settings, Battery: reset or note the Storize usage.
2. Add the targets (S-08). Use the phone normally. Do not open the app more than 3 times a day.
3. Post 1 test story from the Owner account every 4 hours (6 in total, photo and video mixed) so you know the expected count.

**During (check each 4 hours, 30 s each).** Note battery %, and in Activity any error or "skipped" lines. Do not retry on Instagram problems: stop and tell the Lead.

**End (after 24 h).**
1. Missed stories: of the Owner stories you posted, how many are in the Library? Missed = posted minus saved. Also count other targets' stories you saw on the web but not in the Library.
2. Gaps: Activity or Settings gap list (more than 2 h between successful story checks). Write the longest.
3. Battery: Storize share of battery in Settings, Battery, App usage (target: under 3 % per day), and total drop.
4. Number of checks run, number of failures, any checkpoint or "login problem" event, any crash.

**Expected (NFR-2, NFR-3):** no story missed while the phone was online; battery use under 3 % per day; no checkpoint. Fill `docs/05-reviews/SOAK.md`.

---

## Summary table
| # | Test | Phone A | Phone B | Result and notes |
|---|---|---|---|---|
| A1 | Hook check (inspector) | | | |
| A2 | Document-start fails closed | | | |
| A3 | Seen mutation never sent | | | |
| A4 | Page tolerates the fake reply | | | |
| A5 | Story page assumptions (5a to 5d) | | | |
| A6 | Cookie cleanup | | | |
| A7 | WebView lease vs login | | | |
| A8 | Headless WebView in background (8a to 8e) | | | |
| A9 | 20 s timeout | | | |
| A10 | Live probe and story media GET | | | |
| A11 | Worker or iframe requests | | | |
| B1 | Database in the background isolate | | | |
| B2 | Reboot and force-stop | | | |
| B3 | Notifications and deep links | | | |
| B4 | Permissions and battery settings | | | |
| B5 | Full-size photo and owner scoping | | | |
| B6 | Library timing | | | |
| B7 | integration_test on a device | | | |
| D1 | Post paging, direct: confirm `after`/`first` on `PolarisProfilePostsQuery` return the next page; record `page_info` shape (INSTAGRAM_EXTRACTION v0.3) | | | |
| D2 | Post paging, page mode: scroll the profile in the headless WebView; which friendly name the extra pages carry; how many posts 30 steps reach; page-size cost | | | |
| D3 | Highlights tray: real friendly name, variable name, response paths; update the matcher and fixtures | | | |
| D4 | Highlight items: reel query with `highlight:<id>`; `/stories/highlights/<id>/` in page mode; confirm the seen mutation is blocked (0 leaks) and the highlight is not marked seen | | | |
| C | 24 h soak (see SOAK.md) | | | |

## Open questions
- The debug actions named above ("page-mode story load", "run check now", "run the probe", cookie count, Library seed) belong to the app wiring. Any that do not exist yet make their tests "blocked"; the Lead decides whether to add them before the soak.
- A5c: confirm once that Instagram does not list an owner as a viewer of their own story.
