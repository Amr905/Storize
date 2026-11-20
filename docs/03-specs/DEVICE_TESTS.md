# Device tests for page mode and the extraction spike

Status: draft v0.1 (T-014 round 2, 2026-11-20). Owner: the user, with the Lead.
Covers: T-014 AC9 (page mode on device), the old T-002 AC4 (phone hook check), the T-013 live probe (AC7) and the assumptions
that nothing off-device can test. ADR-0003 (Addendum) is the binding rule for seen-blocking, document-start and the WebView lease.

**How to use this file.** Each test has numbered steps and an **Expected** result. Write PASS or FAIL and one line of notes in the
"Result" column of the summary table at the end. Anything that does not match "Expected" is a FAIL: stop that test, do not retry
on a real account, and tell the Lead.

## 0. Before you start

### What you need
| Item | Why |
|---|---|
| Two Android phones (P-4): **Phone A** a Samsung, **Phone B** a Xiaomi or Oppo. If you can, one of them runs **Android 9 or lower** | Background behaviour differs by maker and Android version |
| The **test Instagram account** (P-3) logged in on both phones (the app's own login) | Never use your own personal account |
| A **second Instagram account that you own** ("Owner account") with a **photo story** and a **video story** posted in the last 24 hours | To see whether anyone "viewed" the story |
| The Owner account logged in on a third device (another phone, or the Instagram website on a PC) | To read the story's viewers list |
| A debug build of the app on each phone (`cd app && flutter run --flavor dev`), USB cable, a PC with Chrome | To start the build and to see the WebView |
| The phones on Wi-Fi, charged above 50 % | Stable start |

### Safety rules (read them)
1. **Test account only** for every step in this file. The only exception is the Owner account, which only *owns* stories.
2. Every Instagram request in the app goes through the request budget (the governor). Do **not** repeat a test quickly. Wait at
   least **10 minutes** between two page loads of the same user and **do not run more than 6 page loads per hour** in total.
3. If Instagram shows "Please wait", a login screen, a checkpoint or an "action blocked" message, **stop everything** and tell the
   Lead. Do not log in again on your own.
4. Never copy cookies, tokens, the full URL of a story file, or other people's content into a message, a screenshot, a bug report
   or this file. The repository is public. Screenshots may show only the app's own screens and the viewers list **count**.
5. Write results as status codes and key names only.

### Words used here
- **Page mode**: the app loads the real Instagram page in a hidden browser (WebView) and reads what the page itself fetched.
- **Hook**: the small script (`assets/hook.js`) injected into that page.
- **Seen**: Instagram marks a story as viewed by the account that opened it. The story's owner can see this. It cannot be undone.
- **Blocked**: the hook answers a "mark as seen" request itself and never sends it.
- **Lease**: a "do not touch" flag that stops page mode from using the browser while the login screen is open.

---

## 1. Phone hook check (old T-002 AC4)

Goal: the injected hook really runs in the phone's WebView and the app receives its messages.

1. On Phone A, install the debug inspector build: `cd app && flutter run --flavor dev -t lib/main_debug_inspector.dart`.
2. Log in inside the inspector with the **test account**.
3. In the address bar type `instagram.com` and open the page.
4. Wait 10 seconds without touching anything.
5. Open the inspector's log list.

**Expected:** the log shows several lines (status 200 and a list of top-level key names, **no values, no query strings**). At least
one line has the key name `data`. No line shows a cookie, a token or a full URL.

6. On the PC open `chrome://inspect`, choose the WebView, open the Console and type `window.__storizeHookInstalled`.

**Expected:** it prints `true`.

7. Repeat steps 1 to 6 on Phone B.

**Expected:** same as Phone A. If a phone shows nothing, that phone cannot use page mode: note the Android and WebView versions
(Settings, Apps, Android System WebView, version).

---

## 2. Document-start support (fail closed)

Goal: page mode refuses to load when the hook cannot be installed before the page's own scripts (QA-F5, ADR-0003 Addendum).

1. On each phone open Settings, Apps, **Android System WebView** and write down the version. (Document-start scripts need a
   reasonably recent WebView; the oldest phone is the one that matters.)
2. With the debug build of the app, run **one** story page load of the Owner account (see test 3 for how). Look at the app log.

**Expected on a modern WebView:** no `page_hook_unsupported` line; the load proceeds.

3. If one phone has an old WebView (or you can install an old one): repeat the load on that phone.

**Expected on an unsupported WebView:** the app log shows `page_hook_unsupported`, **no page opens**, and the Owner account's
viewers list stays unchanged. There must be **no** story load at all.

4. Write the result per phone in the summary table, with the WebView version.

---

## 3. The seen mutation is never sent (UD-3)

Goal: loading a story in page mode must not appear in the Owner account's viewers list. This is the most important device test.
It is repeated for a photo story and a video story, on both phones.

Preparation: the Owner account has one photo story and one video story, both posted in the last 24 hours. The test account follows
the Owner account. Open the Owner account's viewers list on the third device and write down the viewers **count** (not the names)
for each story. It must be **0** for both stories before you start (a count above 0 from before is fine, then it must **not
change**).

1. On Phone A start a page-mode story load for the Owner account (debug build: use the debug screen action "page-mode story
   load" when T-015/T-021 wiring exists; until then use the inspector build with the same hook configuration and open
   `instagram.com/stories/<owner username>/` in the inspector address bar).
2. Wait until the app log shows the end of the run (`op=fetchStories ok` or the inspector shows the story items).
3. In the app log read the line `accepted=... blocked=...`.

**Expected:** `blocked` is **1 or more**. There is **no** line containing `seen_block_leak`.

4. On the third device refresh the viewers list of **both** stories.

**Expected:** the test account is **not** in the viewers list of either story, and the count did not change. (Instagram can take a
minute to show viewers: wait 2 minutes and refresh again.)

5. Repeat steps 1 to 4 on Phone B.
6. Also try, on Phone A, a story that is a **video**, and a story with a **link sticker** or a **close-friends** story if the
   Owner account has one.

**Expected:** same as step 4 for each one.

7. Optional hardening check: in the inspector (Chrome DevTools console on the page) run
   `fetch('/api/v1/stories/reel/seen/', {method:'POST', body:'x=1'}).then(r => r.status)`.

**Expected:** it prints `200`, and the hook log shows a `blocked` notice. (The request never reached Instagram.)

If the test account **does** appear in the viewers list, it is a **FAIL (critical)**: stop all story loads in page mode, tell the
Lead, and note which phone, which story type and the app log lines around `blocked`.

---

## 4. Does the page tolerate the fake reply?

Goal: the hook answers the blocked request with a fake "ok" (HTTP 200, `{"data":{},...}`). The page must not retry in a loop,
show an error banner or fire a second mutation.

1. Repeat test 3 step 1 on Phone A with the Chrome DevTools open (`chrome://inspect`, Network tab, filter `graphql`).
2. Watch for 30 seconds.

**Expected:** at most **one** blocked notice per story page, no stream of repeated identical requests, no error toast on the page.
The count of `blocked` in the app log does not keep growing.

---

## 5. Unverified assumptions of the story page

These are guesses made from the T-002 capture. Each one is checked once and written down. Do not change code; report the result.

### 5a. A user without stories (redirect)
1. Pick a followed account of the test account that has **no** story right now.
2. Run one page-mode story load for it.
3. Read the app log (and, if possible, the inspector's `NavigationEvent` / address bar).

**Expected (assumption):** the page ends on the user's profile page (`/<username>/`) and the result is "no stories" after about
2 seconds, not a timeout after 20 seconds. Write what really happened: redirect to profile, redirect elsewhere, an error page, or
the page stays on `/stories/<username>/` with an empty reel list.

### 5b. Is the media id in the URL needed?
1. In the inspector open `instagram.com/stories/<owner username>/` (no number).
2. Then open `instagram.com/stories/<owner username>/<story media id>/` (copy the id from the address bar after step 1 lets
   the page move on).

**Expected (assumption):** both URLs load the story reel and fire the same reel query. Write down whether the first one (no id)
works. If it does not, page mode needs the media id and the plan must change (open a question for the Lead).

### 5c. Which way does the "seen" request travel?
1. Use a normal desktop Chrome (no hook) logged in as the **Owner account** and open its **own** story with DevTools open (Network tab,
   filter `graphql`). Viewing your own story does not add a viewer. **Never do this with the test account**, because without the
   hook the story would be marked as seen.
2. Find the request whose name contains `SeenMutation` and write down how it was sent: **fetch**, **XHR**, or **beacon**
   (DevTools shows the initiator column).

**Expected (assumption):** it is a `fetch` POST with a form body. The hook covers all three ways, so any answer is fine; the
answer tells us which test scenario matters most.

### 5d. Is the story query fired twice?
1. In the same DevTools session look at how many requests have `ReelPage` in the name.

**Expected (assumption):** one or two. If two, note whether the first one is empty (the app waits for the target's reel or for
the page to finish loading plus 2 seconds before it says "no stories").

---

## 6. Cookie cleanup after a run (QA-F10)

Goal: no Instagram cookie or web storage is left in the phone's browser after a page-mode run, even if the app is killed.

1. Do a page-mode load (any plan) on Phone A.
2. As soon as the app log shows the end of the run, open the inspector build's cookie check, or on the PC in `chrome://inspect`
   open the Application tab, Cookies for `instagram.com`.

**Expected:** no cookies, no local storage, no IndexedDB for `instagram.com`.

3. Start another page-mode load and, while it is running (before it ends), **swipe the app away** from the recent apps list.
4. Open the app again, do **not** start a load, and look at the cookie list as in step 2.

**Expected (known limitation):** cookies may still be there after a kill. Write what you see.

5. Now start one more page-mode load and let it finish.

**Expected:** the cookies from the killed run are gone after this run (the wipe happens at the start of every run). If the cookies
of the killed run stay after the next run, it is a FAIL.

---

## 7. The WebView lease against the login screen (QA-F7)

Goal: page mode must never wipe the login WebView's cookies while the user is logging in. The real lease is built in T-015 and
T-026; this test is run when both exist. Until then only steps 1 to 3 of the "design check" below apply.

1. Open the login screen of the app (S-02) and enter the test account's username. Do **not** finish the login.
2. While the login screen is open, trigger a page-mode load (a foreground retry, or force the background task from the debug
   menu).

**Expected:** the page-mode load returns `webview_busy` at once, **no** hidden browser opens, and the login screen keeps its cookies
(you can finish the login normally afterwards).

3. Finish the login. Trigger a page-mode load again.

**Expected:** the load runs normally now. (The lease is free again.)

4. Start a page-mode load, then open the login screen while it runs.

**Expected:** the login screen either waits or tells you to try again in a moment. It must not show a login that "fails for no
reason".

5. Kill the app while the login screen is open, reopen it, and trigger page mode after 5 minutes.

**Expected:** page mode runs (the lease expired by itself and a crash does not lock page mode forever).

---

## 8. The background isolate on two phones (T-014 AC9)

Goal: the hidden browser starts, receives hook messages and ends inside the background task, with the screen off, on both phones.
Needs T-015 and T-021 wiring. Setting "page mode in background" must be **on** in Settings for this test.

For each phone (A: Samsung, B: Xiaomi or Oppo; use the Android 9 phone as one of them if you have one):

### 8a. Screen on, foreground
1. Open the app, trigger one page-mode story load for a test user.

**Expected:** the run ends with `op=fetchStories ok`. The app log shows `accepted=` with 1 or more.

### 8b. Background, screen on
1. Start the background check from the debug menu ("run check now"). Leave the app on the home screen.

**Expected:** the log shows a page-mode run with `accepted=1` or more inside the background task, and it ends. No crash, no
`webview_unavailable`.

### 8c. Screen off and Doze
1. Plug the phone out of the charger. Turn the screen off and leave it for **30 minutes**.
2. Over USB debugging force Doze: `adb shell dumpsys deviceidle force-idle` (undo later with
   `adb shell dumpsys deviceidle unforce`).
3. Wait for the next scheduled check, or trigger it with
   `adb shell cmd jobscheduler run -f <package name> <job id>` (the debug menu shows the job id).
4. Wake the phone and read the app log.

**Expected:** either the check ran and ended (with `accepted=` 1 or more), or it was **deferred** by the system and ran later when
the phone woke up. A hung run (a log line `op=... start` without an end) or a crash is a FAIL.

### 8d. Battery saver
1. Turn on Battery saver (and, on Xiaomi, set the app's battery option to "No restrictions" for one run and to "Battery saver"
   for another run).
2. Trigger the background check as in 8c.

**Expected:** record whether page mode ran. If the system stops the task, the app must show it as "skipped" or "deferred", never as
a stuck "running" state.

### 8e. After the run
1. Look at the phone's memory and battery use of the app after 3 runs (Settings, Battery, App usage).

**Expected:** no leftover WebView process. The app does not stay in the foreground.

Write per phone: Android version, WebView version, and for 8a to 8e PASS or FAIL.

---

## 9. The 20 second timeout on a slow network

Goal: the 20 s timeout is right for a cold WebView and a slow network. (Also checks the 10 s open timeout.)

1. On Phone A turn on Wi-Fi throttling or use mobile data with weak signal (or Chrome DevTools "Slow 3G" on the inspector).
2. Reboot the phone (cold WebView), open the app, and start one page-mode profile load. Write down the time between the start and
   the result (the log has the start and end lines).
3. Repeat 5 times over an hour, keeping to the "6 page loads per hour" rule. Write down each time.

**Expected:** a normal load ends in 3 to 12 seconds on Wi-Fi. On slow data, write down the slowest time.

**Pass rule:** the slowest load must be **under 20 seconds**. If any load ends with `page_timeout` while the page would have
loaded a few seconds later, the 20 s value is too short: write the times and report. If you see `page_open_timeout` (the hidden
browser took more than 10 seconds to start) more than once, write it down with the phone model.

4. Turn the network off completely and start a load.

**Expected:** a network failure within about 20 seconds, not a hang. No session or hidden browser is left (check test 6).

---

## 10. Live probe of direct mode (T-013 AC7)

Goal: record which Instagram REST calls work for the account, and check that the story CDN files download with a plain GET.
Needs the T-015 wiring or the debug menu action that calls `IgProbe.run`.

1. Use the **test account** logged in on Phone A.
2. Run the probe once. It makes **5 calls** (IG-1 to IG-5), one each, through the request budget.
3. Copy only the printed table: for each call the **status** and the **top-level key names**. Do not copy anything else.

**Expected:** 5 lines like `IG-3 status=200 keys=[user]` with `proven` shown for those that work. No line holds a value, a URL or a
cookie. Write the table into `docs/03-specs/INSTAGRAM_EXTRACTION.md` section "Live probe" (the Lead does this).

4. Run the CDN check (`IgProbe.checkCdn`): it downloads the files of one photo story and one video story of the Owner account with a
   plain HTTPS GET and prints the status, content type and size.

**Expected:** status 200, content type `image/...` or `video/...`, size above 0 for both. Do **not** open or save the content outside
the app.

5. Wait 10 minutes. Do **not** run the probe a second time the same day.

If any call returns 401, 403, 429 or a checkpoint, write the status and stop: do not retry.

---

## 11. Other places a request could come from (worker, iframe)

Goal: the hook cannot see requests from a Web Worker, a service worker, or a frame the page creates itself. The app's canary
(`seen_block_leak`) is the safety net; this test looks for such a request on a real story page.

1. On the PC with DevTools open on the inspector's WebView, load the Owner account's story page (the Owner account viewing its
   own story is safe).
2. In the Network tab, filter `SeenMutation`. Look at the **Initiator** column and the frame/worker selector at the top of the
   Network or Sources panel.

**Expected:** the request comes from the page's main frame (a script on the page), not from a worker or an iframe.
If it comes from a worker or iframe, it is a FAIL: report it before any page-mode story load on a real account.

3. In the Sources tab, look for "Workers" or "Service workers" under the page.

**Expected:** none, or none that send GraphQL requests. Write what you see.

---

## Summary table

| # | Test | Phone A | Phone B | Result and notes |
|---|---|---|---|---|
| 1 | Phone hook check (old T-002 AC4) | | | |
| 2 | Document-start support | | | |
| 3 | Seen mutation never sent (photo and video) | | | |
| 4 | Page tolerates the fake reply | | | |
| 5a | User without stories | | | |
| 5b | Media id in the URL needed? | | | |
| 5c | Seen request: fetch, XHR or beacon? | | | |
| 5d | Reel query fired once or twice? | | | |
| 6 | Cookie cleanup after a run and after a kill | | | |
| 7 | WebView lease against the login screen | | | |
| 8 | Background isolate (screen off, Doze, battery saver) | | | |
| 9 | 20 s timeout on a slow network | | | |
| 10 | Live probe (5 calls) and story CDN plain GET | | | |
| 11 | Worker or iframe requests | | | |

## Open questions
- The debug menu actions mentioned in tests 3, 8 and 10 ("page-mode story load", "run check now", "run the probe") belong to the
  app wiring (T-015, T-021, T-037). Until they exist, use the inspector build (`app/lib/debug/**`, not part of T-014).
- Test 5c needs the Owner account to open its own story; Instagram does not list an owner as a viewer of their own story. Confirm
  this once before relying on it.
