# Capture guide (T-002): watch the real Instagram pages

Status: ready for the user · Spec: [TECH_SPEC §4.1](TECH_SPEC.md), [ADR-0003](../decisions/0003-instagram-access-webview-session-http.md) · Results go into [INSTAGRAM_EXTRACTION.md](INSTAGRAM_EXTRACTION.md)

You do this once, with your **dedicated Instagram test account** (task P-3). It takes about 30 minutes.
Storize never logs in for you and never sees your password. The tools below only read what Chrome already saved.

> **NEVER SHARE**
> - Your **password**, or a screenshot of the login page after typing it.
> - The **raw `.har` files**. They contain your session cookies; anyone with them can act as your account.
> - Any **cookie value** (`sessionid`, `csrftoken`, `ds_user_id`, `mid`, `ig_did`, `rur`, anything starting `fbsr_`), or a screenshot of DevTools showing them.
> - Any **CDN link** copied from Chrome (they carry signed parameters). Describe the result, don't paste the link.
>
> Send only what step 10 lists. If you are unsure whether a file is safe, don't send it and ask.

Be gentle with the account: do each step once, wait a few seconds between pages, don't click around.

## 0. Prepare

1. **Pick the target.** `<test_target>` = one of your own test accounts (or a consenting one) that has a photo story, a video story, and a photo post, video post, carousel and reel. Note one post code for each kind (the part after `/p/` or `/reel/` in the post URL).
2. **Get the sanitizer on the PC.** It is one standalone file that needs only the Dart SDK (no Flutter). Pick one:
   - **Clone:** in PowerShell, `git clone https://github.com/Amr905/Storize.git D:\projects\Storize-capture`, then `cd D:\projects\Storize-capture` and `git checkout t-002-spike` (the Lead pushes this branch before you start).
   - **Existing copy:** `cd D:\projects\Storize`, then `git fetch origin` and `git checkout t-002-spike`.
   - **Check Dart works:** `dart --version`. If it is missing, install the Dart SDK (https://dart.dev/get-dart) and reopen PowerShell.
3. Make a folder for raw files **outside the repo**, for example `D:\capture\raw`. Sanitized output goes to `D:\capture\out`. Never put raw HARs inside the repo folder.

## 1. Desktop Chrome: set up DevTools

4. Open Chrome, go to `https://www.instagram.com/`, and **log in with the test account** yourself.
5. Press **F12** to open DevTools and click the **Network** tab. Tick **Preserve log** and **Disable cache**. Click the **All** filter (not Fetch/XHR: the page's own HTML must be in the HAR too, because Instagram sometimes embeds its data there).

## 2. Visit the pages, one HAR each

For **each** page below: click the **clear** button (circle with a line) in the Network tab, load the page, **wait until it fully loads** (for stories: let the first story play), then export:
right-click any request → **Save all as HAR with content** → save into `D:\capture\raw` with the name shown.

6. In this order:

| # | Page | Save as |
|---|------|---------|
| 1 | `https://www.instagram.com/stories/<test_target>/` | `story.har` |
| 2 | `https://www.instagram.com/<test_target>/` | `profile.har` |
| 3 | A **photo** post: `https://www.instagram.com/p/<code>/` | `post_photo.har` |
| 4 | A **video** post: `/p/<code>/` | `post_video.har` |
| 5 | A **carousel** post: `/p/<code>/` | `post_carousel.har` |
| 6 | A **reel**: `https://www.instagram.com/reel/<code>/` | `reel.har` |

## 3. Plain download test (no cookies)

7. Still on a post page:
   1. Right-click an **image** → **Copy image address**. Open a **new Incognito window** (Ctrl+Shift+N), paste it in the address bar, press Enter. Write down: **loads / downloads? yes or no** (and "403" or "expired" if it says so).
   2. For a **video**: right-click it → **Copy video address**. If Chrome gives a `blob:` link, that is normal (the page streams it): instead, in the Network tab filter **Media**, right-click the `.mp4` request → **Copy** → **Copy URL**. Paste into Incognito. Write down **yes or no**. If the URL has `bytestart=` or `byteend=`, also try it once with those two parameters deleted and note which worked.
   3. Repeat both for a **story**: open `https://www.instagram.com/stories/<test_target>/`, right-click the story image (or, for a video story, use the Network tab **Media** filter as above), and test the link in Incognito. Write down **story image: yes / no** and **story video: yes / no**.
   4. Do all of these within a few minutes (links expire). Close the Incognito window afterwards.

## 4. Sanitize on your PC (before sharing anything)

8. For **each** HAR, run this in PowerShell **from the repo folder** (the one you cloned or checked out in step 2):

```powershell
dart packages\storize_instagram\tool\sanitize_har.dart D:\capture\raw\story.har D:\capture\out\story
dart packages\storize_instagram\tool\sanitize_har.dart D:\capture\raw\profile.har D:\capture\out\profile
dart packages\storize_instagram\tool\sanitize_har.dart D:\capture\raw\post_photo.har D:\capture\out\post_photo
dart packages\storize_instagram\tool\sanitize_har.dart D:\capture\raw\post_video.har D:\capture\out\post_video
dart packages\storize_instagram\tool\sanitize_har.dart D:\capture\raw\post_carousel.har D:\capture\out\post_carousel
dart packages\storize_instagram\tool\sanitize_har.dart D:\capture\raw\reel.har D:\capture\out\reel
```

- It prints `Wrote N files to ...` on success.
- If it prints **`REFUSING TO WRITE`**, it found something that looks like a secret and wrote nothing. Do not send that HAR. Tell the Lead which finding it printed (it prints only the kind, never the secret).
- Use plain `dart <file>` as shown. It needs no package setup, so it works with the Dart SDK alone. (`dart run <file>` also works from the repo root if Flutter is installed, but may fail on a Dart-only PC because it first resolves the workspace, which lists Flutter packages.)
- The tool keeps the **shape** of every response and hides its **content**: all text becomes `<str:12>` (the number is only the length), links become `<url host=... path_shape=...>`, ids become `user_1` / `media_1`. Request bodies are not copied at all. So the files will look empty of words; that is expected.
- Open `D:\capture\out\story\report.md` in Notepad. Check: the candidate table lists what it saw, and skim one file in `bodies\`: if you can read any real name, caption, email, phone number or link, don't send it and tell the Lead.
- If a path contains spaces, put it in double quotes, for example `"D:\my capture\story.har"`.

## 5. Optional: phone check (about 10 minutes)

9. (Optional, skip if short on time.) This proves the page-mode hook sees the same JSON inside Storize's own WebView.
   1. Phone: enable USB debugging and connect it.
   2. In the repo folder: `cd app` then `flutter run --flavor dev -t lib\main_debug_inspector.dart` (needs Flutter).
   3. The app shows an address bar and Instagram on top, and a live list below. **Log in yourself** with the test account, then type `/stories/<test_target>/` into the address bar and tap **Go** (only instagram.com addresses are accepted).
   4. Look at the list: you should see lines such as `200 www.instagram.com/api/v1/feed/reels_media/` with their top-level keys. Write down which API paths appear and whether the keys match the desktop `report.md`.
   5. Optional: on the PC open `chrome://inspect` to inspect the WebView.
   The list shows paths (without query strings), status, size and key names only, never bodies or cookies. If you send a screenshot, blur the username and ids.

## Not covered in this round

TECH_SPEC §4.1 step 6 (does `HeadlessInAppWebView` run inside the background workmanager isolate on two phones) is **deferred to T-014**. Nothing in this guide tests it.

## 6. What to send back

10. Send **only**:
    - The **sanitized folders** in `D:\capture\out\` (`story`, `profile`, `post_photo`, `post_video`, `post_carousel`, `reel`): zip that folder.
    - A short text with the **yes/no answers**:
      - Post image link in Incognito: yes / no (+ error)
      - Post video link in Incognito: yes / no (+ error, and whether `bytestart`/`byteend` mattered)
      - Story image link in Incognito: yes / no
      - Story video link in Incognito: yes / no
      - Phone check (if done): which API paths showed up, same keys as desktop yes / no
      - Anything odd: login challenge, "try again later" message, rate limit

**Do not send** the `raw` folder, any `.har`, or screenshots of DevTools.
After sending, delete `D:\capture\raw` and log out of Chrome's Instagram session if you want (the test account's password is untouched by any of this).
