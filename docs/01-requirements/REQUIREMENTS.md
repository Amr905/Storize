# Storize — Requirements

> Status: **v0.3 — Approved** · Owner: Lead · Date: 2026-11-24 · Approved by: user, 2026-11-24 (v0.2 approved 2026-11-19)
>
> **Change log v0.3 (2026-11-24, user feedback after the first phone test):**
> 1. **Today's posts and stories** are downloaded when an account is added (D-17): FR-63 changed.
> 2. **Post history** can be downloaded per account, by range (Today, 7 days, 30 days, from a date, All), slowly in the background (D-18): FR-68…FR-70.
> 3. **Highlights** (pinned stories) are downloaded per account: all of them once, then new items (D-19): FR-71…FR-72. A-16 and §12 changed.
>
> **Change log v0.2 (2026-11-19, user feedback on the tech spec):**
> 1. **New posts are tracked as well as stories** (D-11): new §6.3b, FR-60…FR-66, BR-9, EC-20…EC-22.
> 2. **Downloads go straight to the phone gallery** in a folder per account (D-10): FR-33 changed; A-8 and A-15 replaced; Q-5 answered.
> 3. **Media extraction must be based on watching the real page** (D-12): FR-29 added.
> 4. **Flutter, Android first** (D-13) and a **public GitHub repo** (D-14). These are technical decisions, recorded for traceability.
>
> Every statement marked **[A-n]** is an assumption I made without your confirmation.
> Every item in §12 is an open question. Please confirm, correct, or answer them when reviewing.

## 1. Product summary
Storize is an Android app for a small team. It automatically downloads Instagram **stories and new posts**
from specific accounts the team tracks. Stories are saved before they expire after 24 hours. The app logs in to
Instagram with an account the user provides and checks the tracked accounts regularly.
When a new story or post appears, it saves the photos and videos into the phone's gallery, in a `Storize/<account>` folder.
The MVP supports Instagram only. Facebook, TikTok and Snapchat are planned later.

## 2. Decisions confirmed so far
| # | Decision | Source |
|---|----------|--------|
| D-1 | Tracked accounts are: (a) the team's own or its clients' accounts, (b) people who agreed to be archived, (c) public creators and brands | Round 1 |
| D-2 | Users: a small team | Round 1 |
| D-3 | Platform: Android app | Round 1 |
| D-4 | Access: automation through a logged-in account, on every platform. The team accepts the terms-of-service, ban and maintenance risks (§11) | Round 2 |
| D-5 | Checking runs on the phone only, with no server | Round 2 |
| D-6 | Roles: everyone is equal, with a single role | Round 2 |
| D-7 | MVP platform: Instagram only | Round 2 |
| D-8 | "Snapshot" in the brief means Snapchat (post-MVP) | Assumed, not contradicted |
| D-10 | Downloads are visible in the phone gallery, in a folder (per account) | v0.2 feedback |
| D-11 | Track **new posts** as well as stories | v0.2 feedback |
| D-12 | Extraction is based on watching the real story/post page and downloading its media the normal way | v0.2 feedback |
| D-13 | Build with Flutter, Android first (iOS possible later, not in the MVP) | v0.2 feedback |
| D-14 | The source code lives in the public GitHub repo https://github.com/Amr905/Storize | v0.2 feedback |
| D-15 | Reels are a separate per-account option: the user decides whether new reels are downloaded | v0.2 approval |
| D-16 | Older posts are not downloaded by default; a backfill option may come in a later version | v0.2 approval |
| D-17 | When an account is added, its posts and stories from **today** are downloaded too (not only content published after it was added) | v0.3 feedback |
| D-18 | Post history is a **per-account** option with ranges Today / last 7 days / last 30 days / from a date / All; it runs in the background within the request budget | v0.3 feedback |
| D-19 | **Highlights** are a per-account option: when on, all current highlights are downloaded once, then items added later | v0.3 feedback |

## 3. Business goals
- **G-1** Never lose a story from a tracked account because it expired before anyone saved it.
- **G-5** Keep a copy of every new post from a tracked account, even if the owner later deletes or edits it.
- **G-2** Remove manual work: no opening Instagram and screen-recording or saving by hand.
- **G-3** Keep an organized archive per person that the team can browse, search and re-share.
- **G-4** Build the code so other platforms can be added later without a rewrite.

**Success metrics [A-1]:**
- At least 95% of stories posted by tracked accounts are downloaded, while the phone is online and logged in.
- A story is downloaded within 60 minutes of being posted.
- No more than one forced re-login per week for each Instagram account.

## 4. Target users
| Persona | Description | Needs |
|---------|-------------|-------|
| Team member | One of a few people (e.g. a social-media or marketing team) archiving client, brand or creator content | Set it up once and let it run; get reliable downloads; find a story quickly; share it onward |

**[A-2]** Team members are comfortable installing an APK and adjusting Android battery settings
when the app gives them instructions.

## 5. User roles & permissions
There is a single role: **Member** (D-6). Every member can do everything on their own device:

| Permission | Member |
|------------|--------|
| Connect or disconnect the Instagram login account | ✅ |
| Add, edit, pause or remove tracked accounts | ✅ |
| Browse, view, share, export and delete downloads | ✅ |
| Change settings | ✅ |

- **[A-3]** Because checking is phone-only (D-5), each phone is independent. Its tracked list,
  login and downloads stay on that device, and there is no syncing between team members.
  "Team" means several people each run their own copy. (See Q-1.)
- **[A-4]** The app has no Storize account or sign-up. An optional app lock (PIN or fingerprint)
  protects the archive.

## 6. Functional requirements (MVP)
Priority: **M** = Must, **S** = Should, **C** = Could.

### 6.1 Instagram login account
| ID | Requirement | Pri |
|----|-------------|-----|
| FR-1 | The user logs in to Instagram inside the app, through an embedded login screen, and must enter the 2FA code when one is required | M |
| FR-2 | The app stores only the session (cookies/tokens), encrypted on the device, never the password | M |
| FR-3 | The app detects an expired session or a security challenge, pauses checking, and notifies the user to log in again | M |
| FR-4 | The app shows the login account's health: active / needs re-login / possibly restricted | M |
| FR-5 | Before login, the app warns that the account may be challenged or banned and recommends a dedicated account **[A-5]** | M |
| FR-6 | The app supports more than one login account and lets the user pick one per tracked account | C |

### 6.2 Tracked accounts ("targets")
| ID | Requirement | Pri |
|----|-------------|-----|
| FR-10 | The user adds a target by Instagram username or profile link | M |
| FR-11 | When adding a target, the user must pick a category: *Own/Client*, *Consented person*, or *Public creator/brand* (see BR-1) | M |
| FR-12 | The app checks that the target exists and can be seen by the login account (public, or private and followed) | M |
| FR-13 | Targets are stored by their permanent Instagram user ID, so a username change doesn't break tracking | M |
| FR-14 | The user can pause or resume tracking for each target, and can remove a target with a choice to keep or delete its downloads | M |
| FR-15 | The target list shows each target's last check time, last new story time, story count and status | S |
| FR-16 | The user can add a note to each target (e.g. client name, consent reference) | S |

### 6.3 Detection & download
| ID | Requirement | Pri |
|----|-------------|-----|
| FR-20 | The app checks all active targets periodically in the background, by default every 30 min, configurable from 15 min to 6 h **[A-6]** | M |
| FR-21 | The user can start a "Check now" for all targets or for one target | M |
| FR-22 | Every new story item (photo or video) is downloaded in the best available quality, with audio | M |
| FR-23 | The app never downloads the same story item twice; it is identified by Instagram's story item ID | M |
| FR-24 | The app saves metadata: target, item ID, posted time, downloaded time, media type, duration, and stickers/links when available | M |
| FR-25 | Failed downloads are retried with backoff and resume from where they stopped where possible | M |
| FR-26 | Downloads can be limited to Wi-Fi only (default: off) **[A-7]** | S |
| FR-27 | Close Friends stories are downloaded only when the login account can see them | S |
| FR-28 | Live videos are **not** downloaded | — |
| FR-29 | Before any extraction method is built, it must be worked out by opening the real story/post page while logged in and seeing where the image or video comes from. The app then downloads that file the normal way (a plain file download at full quality). If the shortcut method breaks, the app must be able to fall back to loading the page itself and taking the media from it (D-12) | M |

### 6.3b Posts (new in v0.2)
| ID | Requirement | Pri |
|----|-------------|-----|
| FR-60 | Each check detects **new posts** by each tracked account and downloads all of their media at the best available quality: photo, video, carousel. New **reels** are downloaded only if the account's Reels option is on (D-15, FR-67) | M |
| FR-61 | A carousel is saved as all its slides, kept together as one post (in order) | M |
| FR-62 | The app saves post metadata: caption, post link, posted time, type, slide count | M |
| FR-63 | When an account is added, posts published **since the start of today** (device time) are downloaded, and so are its live stories; older posts follow the account's history option (FR-68) (D-17) | M |
| FR-68 | Each tracked account has a **post history** option, set on Add account and editable on Account detail: **None** (default), **Today**, **Last 7 days**, **Last 30 days**, **Since a date**, **All** (D-18) | M |
| FR-69 | History is fetched page by page in the **background** (workmanager), within the same request budget as checks and below them in priority; progress ("312 of ~1,200 posts") is shown on Account detail; it can be paused, resumed or cancelled, and survives app restarts | M |
| FR-70 | History respects the account's Posts/Reels toggles and never downloads a post twice (same dedupe as FR-60); a stop by rate limit or login problem resumes later from where it stopped | M |
| FR-64 | Posts are checked on their own interval, by default every 3 hours, configurable from 1 h to 24 h, to limit request volume and ban risk **[A-19]** | M |
| FR-65 | Each tracked account has toggles for **Stories**, **Posts** and **Reels** (all on by default); at least one must stay on | S |
| FR-67 | Each tracked account has a **Reels** toggle next to Stories and Posts (default **on**). When it's off, reels are skipped even though they appear on the profile grid (D-15) | M |
| FR-71 | Each tracked account has a **Highlights** toggle (default off). When turned on, every current highlight is downloaded once (in the background, like FR-69), then each check of that account's posts also picks up items newly added to its highlights (D-19) | S |
| FR-72 | Highlight items are saved in the account's gallery folder under `Highlights/<highlight title>/`, appear in the Library under their own filter, and keep their highlight title and order | S |
| FR-66 | New-post notifications follow FR-40 ("2 new posts from @x") and can be turned off separately (FR-42) | M |

### 6.4 Library
| ID | Requirement | Pri |
|----|-------------|-----|
| FR-30 | The library lists downloads (stories and posts) grouped by target and by date, newest first | M |
| FR-31 | The user can open a full-screen viewer for photos and videos and swipe through a target's stories. A post opens with its carousel slides and caption | M |
| FR-32 | The user can share a download to other apps with the Android share sheet | M |
| FR-33 | **Every download is saved automatically into the phone gallery**, in `Pictures/Storize/<username>/`, so it appears in the Gallery/Photos app as a normal album. The Storize library shows those same files (D-10) | M |
| FR-34 | The user can delete single items or many items at once | M |
| FR-35 | The user can filter by target, date range, kind (stories / posts) and media type | S |
| FR-36 | The user can export all of a target's downloads as a ZIP | C |

### 6.5 Notifications
| ID | Requirement | Pri |
|----|-------------|-----|
| FR-40 | Notify when new stories or posts are downloaded, grouped as "3 new stories from @x" / "1 new post from @x" | M |
| FR-41 | Notify when re-login is needed, or when the account appears restricted | M |
| FR-42 | Each notification type can be turned on or off | S |

### 6.6 Settings & diagnostics
| ID | Requirement | Pri |
|----|-------------|-----|
| FR-50 | Settings: story check interval, post check interval, Wi-Fi only, notifications, retention, app lock | M |
| FR-51 | A guided setup step asks the user to exclude Storize from battery optimization, with guides for Samsung, Xiaomi, Oppo and similar phones | M |
| FR-52 | An activity log shows checks, downloads and errors from the last 7 days | S |
| FR-53 | Storage usage is shown per target and in total | S |
| FR-54 | Retention: keep forever (default) or auto-delete after N days **[A-9]**. It deletes the gallery files too | S |

## 7. Non-functional requirements
| ID | Category | Requirement |
|----|----------|-------------|
| NFR-1 | Platform | Android 8.0 (API 26) and newer, phones only **[A-10]** |
| NFR-2 | Background | Uses Android's standard background scheduling. The design accepts that Android may delay checks during Doze and battery saver. A story is missed only if the phone is offline for its whole 24 hours |
| NFR-3 | Battery | Background checking uses less than 3% of the battery per day with 20 targets at a 30-minute interval **[A-11]** |
| NFR-4 | Anti-ban behaviour | Random jitter between requests and between checks; a cap on requests per hour **shared by story and post checks**; a recommended maximum of 50 targets per login account **[A-12]**; automatic slow-down after rate-limit responses |
| NFR-5 | Security | Session tokens are encrypted with the Android Keystore. Passwords are never stored. The optional app lock uses biometric or PIN |
| NFR-6 | Privacy | All data stays on the device. No analytics, no tracking and no cloud uploads. Downloaded media is in the shared gallery (D-10), so other gallery apps and anyone with the unlocked phone can see it; the app lock does not protect gallery files |
| NFR-7 | Reliability | No data loss if the app is killed mid-download; partial files are cleaned up or resumed |
| NFR-8 | Maintainability | Instagram access sits behind a platform-adapter interface, so (a) Instagram changes are fixed in one place and (b) Facebook, TikTok and Snapchat adapters can be added |
| NFR-9 | Updatability | Because Instagram changes often, the team must be able to push fixes quickly. An in-app "update available" check is recommended if the app isn't on Google Play (see Q-4) |
| NFR-10 | Localization | English UI; Arabic (RTL) is ready for later **[A-13]** |
| NFR-11 | Accessibility | Meets Android basics: content descriptions, 48dp touch targets, dynamic font size |
| NFR-12 | Performance | The library opens in under 1 s with 5,000 items; thumbnails load lazily |
| NFR-13 | Storage | Warns when free space drops below 1 GB, and pauses downloads below 200 MB **[A-14]** |

## 8. Business rules
| ID | Rule |
|----|------|
| BR-1 | Only these may be tracked: (a) the team's own or clients' accounts, (b) people who have agreed, (c) public creators and brands. The category is required when adding a target and is shown in the target list |
| BR-2 | A private target can be tracked only if the login account already follows it. Storize never tries to get around privacy settings |
| BR-3 | Each story item is stored once (FR-23) |
| BR-4 | Downloads stay after the original story expires or is deleted, until the user deletes them or retention removes them |
| BR-5 | The minimum check interval is 15 minutes. It cannot be set lower, to reduce ban risk |
| BR-6 | Removing a target always asks whether to keep or delete its media |
| BR-7 | When a session is invalid, all checking for that login account stops immediately. No automatic password re-entry or repeated login attempts are made |
| BR-8 | Viewing a story through Storize counts as a view by the login account. The person will see that account in their viewer list. Storize does not promise anonymous viewing |
| BR-9 | Storize and the gallery share one copy of each file. Deleting an item in Storize deletes it from the gallery (the confirmation says so). Each post's media is stored once (as BR-3) |

## 9. Edge cases
| ID | Case | Expected behaviour |
|----|------|--------------------|
| EC-1 | Session expires, or Instagram asks for verification | Pause checking, notify, mark the account "Needs re-login" (FR-3) |
| EC-2 | Login account is banned or restricted | Mark it restricted and stop all checks; the user must connect another account |
| EC-3 | A target makes its account private and the login account doesn't follow it | Mark the target "Not visible" and keep past downloads |
| EC-4 | A target blocks the login account | Treat it the same as EC-3 |
| EC-5 | A target changes username | Keep tracking through the user ID and update the shown username |
| EC-6 | A target deletes or deactivates the account | Mark it "Unavailable" and keep past downloads |
| EC-7 | A story is deleted between detection and download | Log it as "Removed before download"; it is not an error |
| EC-8 | A target posts many stories at once (e.g. 30 items) | Download them all and send one grouped notification |
| EC-9 | No network / metered network with Wi-Fi only on | Skip and retry at the next check; stories stay downloadable for up to 24h |
| EC-10 | Phone offline or off for more than 24h | Stories posted and expired in that window are lost. The app shows "Possible gap: offline from X to Y" |
| EC-11 | The phone maker's battery manager kills background work | Detect long gaps between checks and prompt the user to re-run the battery setup (FR-51) |
| EC-12 | Storage is full or nearly full | Follow NFR-13 |
| EC-13 | App is killed in the middle of a download | Resume or clean up (NFR-7) |
| EC-14 | Instagram changes its internal API and checks start failing | Show a clear "Instagram changed — update Storize" status, not silent failure |
| EC-15 | Rate-limit response from Instagram | Back off, slow the schedule, and show a warning |
| EC-16 | The same person is added twice | Block the duplicate, matched by user ID |
| EC-17 | Video with no audio track, or very long videos | Save as-is; don't fail |
| EC-18 | Time zones | Store UTC and show the phone's local time |
| EC-19 | App reinstall | Gallery files survive uninstall. Storize's list of targets and its library index don't, and old files aren't re-imported after reinstall **[A-15]** |
| EC-20 | The user deletes or moves a file using the gallery app | The Storize item shows "File missing" and can be removed from the library |
| EC-21 | A post is deleted between detection and download, or a carousel slide fails | Treated like EC-7, per slide; the post keeps the slides that succeeded |
| EC-22 | A post is edited later (caption changed, slide removed) | Storize keeps what it first saved; there are no re-downloads |

## 10. External integrations
| System | Use | Method | Phase |
|--------|-----|--------|-------|
| Instagram | Read stories of tracked accounts | Unofficial, through the logged-in session (private/web endpoints or an embedded WebView) | MVP |
| Facebook | Stories | Unofficial automation | Later |
| TikTok | Stories | Unofficial automation | Later |
| Snapchat | Stories (public profiles can be reached without login) | Public web plus automation | Later |
| Android OS | Background scheduling, notifications, media storage, Keystore, biometrics, share sheet | Platform APIs | MVP |

There are no backend, cloud or payment integrations in the MVP.

## 11. Risks (accepted by D-4, listed for the record)
| ID | Risk | Impact | Mitigation in scope |
|----|------|--------|---------------------|
| R-1 | Automating Instagram breaks Meta's terms of service | Login accounts get banned; possible legal letters | Dedicated accounts (FR-5), limits (NFR-4, BR-5) |
| R-2 | Instagram changes break the app, often without warning | Downtime until a fix ships | Adapter layer (NFR-8), clear error state (EC-14), fast updates (NFR-9) |
| R-3 | Google Play rejects or removes the app | Distribution has to use an APK | Q-4 |
| R-4 | Privacy and copyright of downloaded content (including data-protection laws where the targets live) | Legal exposure if content is misused | BR-1 category tracking, local-only storage. Not legal advice; consider a lawyer before commercial use |
| R-5 | Android background limits delay checks | Late or missed stories | 24h window, gap detection (EC-10/11), battery setup (FR-51) |
| R-6 | Tracked people see the login account in their story viewers | Loss of discretion | Documented (BR-8); consent-based tracking reduces this |
| R-7 | The public repo (D-14) makes the automation visible. Meta can file a takedown with GitHub, and anyone can download the APK | Repo or releases removed; more copies in circulation | No secrets in the repo; keep a private mirror or backup; signing key kept outside the repo |
| R-8 | Post checks add requests per run (one per account, no batching) | Higher ban risk | Separate, slower post interval (FR-64); shared request cap (NFR-4); per-account toggles (FR-65) |

## 12. Out of scope (MVP)
- iOS, web app, desktop app
- Server, cloud backup, or syncing between team members' phones
- Facebook, TikTok and Snapchat (post-MVP, D-7)
- Live videos, DMs and comments **[A-16]** (highlights moved in scope by D-19)
- ~~Backfilling older posts~~ — now in scope as the history option (D-18)
- iOS (Flutter keeps it possible later; D-13)
- Re-importing gallery files after a reinstall (EC-19)
- Posting, reposting, or scheduling content to any platform
- Analytics or insights on stories
- Anonymous viewing (BR-8)
- Getting around private accounts that the login account doesn't follow (BR-2)
- Team accounts, sign-up and user management (D-6, A-4)

## 13. Open questions (please answer during review)
| ID | Question | Current assumption |
|----|----------|--------------------|
| Q-1 | How does the team share? Each member has their own phone with a separate list / one shared phone / own phones plus manual sharing? | A-3: separate phones, no sync |
| Q-2 | Which Instagram account logs in: a dedicated dummy account, the user's real account, or the user chooses? | A-5: recommend a dummy account, warn if the real one is used |
| Q-3 | ~~Should highlights, posts or reels also be downloaded?~~ **Answered v0.2:** stories + new posts (D-11). Highlights stay out | — |
| Q-4 | How is the app installed: direct APK, Google Play, or not sure? | Direct APK from GitHub Releases (D-14) |
| Q-5 | ~~Gallery or inside Storize only?~~ **Answered v0.2:** gallery, folder per account (D-10) | — |
| Q-11 | ~~Do reels count as posts?~~ **Answered:** a per-account Reels option (D-15, FR-67) | — |
| Q-12 | ~~Older posts?~~ **Answered:** no by default; option later (D-16) | — |
| Q-13 | Is checking posts every 3 hours by default acceptable? | A-19: 3 h |
| Q-6 | Should media be kept forever, or deleted automatically after a number of days? | A-9: forever by default |
| Q-7 | Language: English only, or Arabic in the MVP? | A-13: English, RTL-ready |
| Q-8 | How many targets should one phone track at most? | A-12: up to 50 |
| Q-9 | Default check interval: is 30 minutes acceptable? | A-6: 30 min |
| Q-10 | Are the success metrics in §3 right? | A-1 |

## 14. Assumptions index
A-1 metrics · A-2 users can sideload/adjust battery · A-3 devices independent · A-4 no Storize account, optional app lock ·
A-5 dummy login recommended · A-6 30-min default story interval · A-7 Wi-Fi-only off by default · ~~A-8 storage location~~ (replaced by D-10) ·
A-9 keep forever · A-10 Android 8+ phones · A-11 battery target · A-12 50 targets/account · A-13 English + RTL-ready ·
A-14 storage thresholds · A-15 reinstall: gallery files kept, app index lost (v0.2) · A-16 no highlights/live/DMs ·
~~A-17~~ (replaced by D-15) · A-18 no post backfill · A-19 3-h default post interval
