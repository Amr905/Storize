# T-002 (preparation half) — QA review

Branch `t-002-spike` (60b8f4b, 2e70165, empty 8605328) · QA by independent verification · 2026-11-19

## Verdict: **FAIL** (sanitizer leaks; blocker QA-1 and QA-2)

The sanitizer fails closed for many inputs and handles cookies, headers, Set-Cookie, POST bodies, Bearer, nested signed URLs, unicode and 20k-item arrays correctly.
But it leaks a **URL-encoded `sessionid%3D<value>`** and a **`sessionid` inside JSON text held in a string**, and the final leak scanner does not catch either. Both were named as blockers in the brief. Several PII/username leaks (QA-4, QA-5) also matter because the user is going to send sanitized output to a public repo.
Capture guide, inspector, hook.js and hygiene are fine, with small notes.

## Acceptance criteria

| AC | Result | Evidence |
|----|--------|----------|
| Sanitizer runs with plain Dart | PASS | Clean `git archive HEAD` copy with no `pub get`: `dart packages/storize_instagram/tool/sanitize_har.dart .../synthetic.har /tmp/clean_out` printed `Wrote 7 files`, exit 0. Imports are only `dart:convert`, `dart:io`. |
| Proven by tests on synthetic data incl. fail-closed | PASS for the developer's tests (17 pass); **FAIL against adversarial input** | see table below |
| Capture guide complete, Windows-friendly, never-share box | PASS with notes (G-1..G-4) | `docs/03-specs/CAPTURE_GUIDE.md` |
| Inspector builds, parser tests pass | PASS | `flutter test test/debug` in `app`: `+10: All tests passed!`; CI debug APK green (per Lead). |
| Extraction doc skeleton + unverified expectations | PASS | Status line says "skeleton, pending capture"; all values marked UNVERIFIED; fetch failure of sources disclosed. |
| Repo contains no real data | PASS | See hygiene. |

## Standard checks (real output)

```
dart format --output=none --set-exit-if-changed .   -> Formatted 22 files (0 changed), exit 0
flutter analyze                                     -> No issues found!
melos run test                                      -> storize_data/domain/model/platform_android/app: All tests passed
                                                       storize_instagram: +38 ~19: All tests passed!  (19 = skipped QA known-leak probes)
                                                       melos exec flutter test -> SUCCESS
```
gitleaks is not installed in this workspace; CI gitleaks is green per the Lead. My new fixtures contain only `ZZFAKE...` values; re-check CI after pushing them.

## Adversarial tests (CLI = `dart <path>`, not `dart run`)

Fixtures: `packages/storize_instagram/test/tool/fixtures/adv_*.har`; tests: `test/tool/sanitize_har_adversarial_test.dart`. Invariant checked per fixture: exit 0 with no marker anywhere in output, or exit 1 with no files and no secret echoed.

| Input | Expected | Actual |
|-------|----------|--------|
| `cookies[]`, `Cookie`/`cookie`/`COOKIE` headers, `X-CSRFToken`, `Set-Cookie`, response `cookies[]` (adv_cookies) | no values | exit 0, zero leaks |
| `sessionid=` in body prose, nested in list, `"sessionid"` key | redacted | redacted |
| `sessionid%3D<val>` in body string (adv_body_sessionid, probe) | redacted or exit 1 | **LEAK**, exit 0, value verbatim (QA-1) |
| signed CDN URL inside JSON-in-JSON string, escaped slashes, `_nc_*` query (adv_nested_json) | `?<redacted>` | zero leaks |
| `csrftoken`, `enc_password`, `lsd` in form POST; JSON POST; multipart params (adv_post_body) | no values | exit 1, nothing written (false positive: the key name `csrftoken` in `postParams` trips the scanner; safe but this HAR cannot be shared) |
| `/stories/<name>/<id>/`, `/<name>/`, `?username=`, `/feed/user/<name>/username/`, `?q=` (adv_usernames) | placeholders | zero leaks |
| `/api/v1/users/<name>/usernameinfo/`, `/feed/user/<name>/`, `/users/<name>/info/`, `/friendships/show/<name>/` | placeholder | **LEAK** in `summary.json`, `report.md` and body filename (QA-4) |
| `Authorization: Bearer`, `X-IG-WWW-Claim`, `ig-set-authorization`, `ds_user_id` as int and string (adv_auth_ids) | removed | zero leaks |
| 40+ char base64/hex in unknown fields, list items, keys (adv_base64) | `<token>` or exit 1 | exit 1 (embedded-in-prose run caught by scanner); each other form individually becomes `<token>` |
| HTML/JS/text/broken-JSON/`for (;;);` bodies containing `"sessionid"` (adv_html) | not copied | zero leaks, only marker names reported |
| Unicode usernames (CJK, accented), captions (Arabic, Cyrillic, Greek, emoji), `/用户名/` path (adv_unicode) | placeholders | zero leaks |
| 20,000-item array (in-test) | clean, fast | clean, ~2.5 s via CLI (6 MB HAR) |
| Query `sessionid=`/`csrftoken=` on a request URL (adv_extra) | no values | exit 1, nothing written |
| JSON text in string: `{"sessionid":"<realistic>", "x": 1}` and escaped form | redacted or exit 1 | **LEAK** (QA-2) |
| `Cookie: SessionID=<val>` (case) | redacted | **LEAK** (QA-3) |
| `business_email`, `business_phone_number`, `public_email`, `contact_phone_number`, `business_address_json`, `biography_with_entities.raw_text`, `bio_links[].url` on non-IG host, story hashtag/location `name`, poll/question text | redacted | **LEAK**, verbatim (QA-5) |
| JSON keys `X-CSRFToken` / `x-csrftoken` with short value | redacted | **LEAK** (QA-6) |

The 17 leak probes are committed as **skipped** tests (`QA-1`..`QA-6`, `QA-7`) so CI stays green. I confirmed they fail when un-skipped (`-17: Some tests failed`). Un-skip them when fixing.

## Findings

| ID | Severity | Where | Problem and fix |
|----|----------|-------|-----------------|
| QA-1 | **Blocker** | `sanitize_har.dart` `_scrubString` (~l.405) and `_cookieAssign` (~l.172) | Cookie names are only matched followed by a literal `=`. `sessionid%3D5252525252%3A...` passes through and the scanner also misses it. Repro: `_har({'a':'x sessionid%3D5252525252%3AZZFAKEaBc%3A27%3AZZFAKEdEf now'})`. Fix: URL-decode (and JSON-unescape) a copy of every string and every output file before scanning; match `(name)(=|%3[dD]|:)`; redact the whole value. |
| QA-2 | **Blocker** | `_secretJsonKey` (~l.176), `_scrubString` | Only a quoted `"sessionid":` key in the walked JSON is handled. JSON held as text inside a string value (`{"sessionid":"..."}`, also `{\"sessionid\":\"...\"}`) is kept. Strings of 32+ chars with no whitespace are rescued only by the generic token heuristic, so spaced or short values leak. Fix: try `jsonDecode` on string values that start with `{`/`[` and walk the result, and make the scanner accept optional backslashes/quotes between name and value. |
| QA-3 | Medium | `_cookieAssign`, `_scrubString` | Case-sensitive. Add `caseSensitive: false`. |
| QA-4 | High (username of a third party in a public repo) | `_scrubSegments` | Username redaction is by position rules (`stories/`, first path segment, `user/<x>/username`). Any other IG path with a non-numeric segment is kept, including real endpoints like `/api/v1/users/{username}/usernameinfo/`. Also leaks via the body filename. Fix: for instagram hosts under `/api/` and `/graphql/`, keep only an allowlist of segments (`api, v1, feed, users, reels_media, ...`) and replace all others with `<seg>`. |
| QA-5 | High | `_secretKeys` / `_redactKeys` | Missing keys: `business_email`, `public_email`, `business_phone_number`, `contact_phone_number`, `public_phone_number`, `business_address_json`, `raw_text`; `name`/`short_name` under `hashtag`/`location`; `question` in stickers; `bio_links[].url` (non-IG host path kept; `linktr.ee/<name>` is identifying). Fix: replace every string value of keys containing `email|phone|address|raw_text|question|bio` and every URL value on non-IG hosts down to host only. Also consider a default-deny mode: keep only strings for known-structural keys and replace others with `<str>`. |
| QA-6 | Low | `_secretKeys` | Add `x-csrftoken`, `x-instagram-ajax`, `x-asbd-id`, `x-fb-lsd`, `ig-set-authorization`. |
| QA-7 | Low | `hook.js` `report()` | The message `url` includes the query string (signed params, `sessionid` if ever present). The inspector shows only `shortUrl` and nothing is persisted, so no exposure today. Fix: send `origin + pathname` unless the query is needed (T-014 will need it, so split the fields). Probe is skipped in `hook_js_test.dart`. |
| QA-8 | Low (usability) | scanner `_cookieAssign`/`_secretJsonKey` | A request that merely has a *parameter name* `csrftoken`/`sessionid` (POST form, query) makes `summary.json` trip the scanner and the whole HAR is refused (fail-closed, safe, but the user is stuck). Fix: do not print raw key names for those two keys, or exempt `postParams`/`query` keys from the JSON-key scan. |
| QA-9 | Low | scanner message | OK as is: refusal prints only kinds. Note it does not name which file/URL, so the user cannot fix it; acceptable. |
| G-1 | Low | CAPTURE_GUIDE §5 step 9.3 | "type it in the page's address route" — the inspector screen has no address bar (only `initialUrlRequest` = `https://www.instagram.com/`). The user can only navigate by tapping. Fix: say "open the story by tapping the avatar in the page", or add a URL field. |
| G-2 | Low | CAPTURE_GUIDE step 5 | Chrome's **Fetch/XHR** filter hides the HTML document. The sanitizer has an "HTML documents" section, and TECH_SPEC says pages may embed data in HTML. Chrome may export only filtered entries in some versions. Fix: tell the user to use the **All** filter before exporting. |
| G-3 | Low | CAPTURE_GUIDE | TECH_SPEC §4.1 step 6 (HeadlessInAppWebView in the workmanager isolate on 2 phones) is not covered. Acceptable for the prep half (extraction doc says pending T-014); add a line saying it is deferred. |
| G-4 | Info | CAPTURE_GUIDE step 7 | The plain-download test covers post media; the story media is not tested. Add "also do it for a story image and video" (AC2). |

## Capture guide review (non-expert Windows user)

- Commands use `dart packages\storize_instagram\tool\sanitize_har.dart <in> <out>`: correct for PowerShell, no quoting problems (paths have no spaces; tell users to quote paths with spaces: add this).
- Does not use `dart run`; explains why. Verified it works without `pub get` in a clean checkout.
- Branch: `git clone ... ; git checkout t-002-spike` and an "existing copy" path (`git fetch origin; git checkout t-002-spike`). Branch is pushed, so this works.
- NEVER SHARE box: first thing after the intro, blockquote, bold heading, lists password, raw HAR, cookie values (named), CDN links. Good. Add "screenshots of the phone inspector list with usernames" is already in step 9.5.
- TECH_SPEC §4.1 steps 1-5 covered; step 6 deferred (G-3).

## Inspector and hook.js

- Parser tests: 8 in `hook_message_test.dart` plus the screen tests: `+10: All tests passed!`.
- `inspector_screen.dart` `_InspectorWebView`: handler uses `JavaScriptHandlerFunctionData.origin` (native-reported) and passes `'${o.scheme}://${o.host}'` to `parseHookMessage`, which requires exactly `https://www.instagram.com` and then also checks the payload `origin`, https scheme and an instagram.com host. UserScript uses `allowedOriginRules: {allowedHookOrigin}`. `allowFileAccess`/`allowContentAccess` false. Port is dropped from the origin (`:8443` would pass); low, not exploitable since the scheme must be https and host exact.
- `hook.js` run under Node with a mocked browser (`test/tool/hook_js_test.dart`, skipped when Node is absent): with `includeBody:false` the message has exactly `url,status,bodyLength,topLevelKeys,origin,via`; no `body`; neither `document.cookie` values nor the body's `sessionid` appear; a non-instagram fetch is not reported. With `includeBody:true` the body is the only addition and cookies are still absent. Only QA-7 (query in url).

## Repo hygiene

- Grepped all 2,919 added lines (`git diff main...HEAD`) for `sessionid=`, `csrftoken=`, `Bearer`, `ds_user_id=`, signed CDN URLs, 40+ char tokens: every hit is `FAKE...`, `fakeuser_*`, `scontent-xxx.cdninstagram.com`, `9999999999`-style IDs. No real hosts with signatures. `synthetic.har` is marked FAKE.
- `storize_domain` / `storize_model` untouched, no Instagram or webview imports.
- `app/pubspec.yaml`: `flutter_inappwebview: 6.2.0-beta.3` exact pin with an explanatory comment. PASS.
- `AndroidManifest.xml` main has `<uses-permission android:name="android.permission.INTERNET"/>`. PASS.
- No governor bypass: the spike touches no Instagram HTTP client code.

## Files added by QA
- `packages/storize_instagram/test/tool/sanitize_har_adversarial_test.dart`
- `packages/storize_instagram/test/tool/hook_js_test.dart`, `hook_harness.js`
- `packages/storize_instagram/test/tool/fixtures/adv_*.har` (10 FAKE HARs)

## Re-verify when fixed
Un-skip the `QA-1`..`QA-7` tests, re-run `melos run test`, and re-run the CLI on `adv_body_sessionid.har` and `adv_usernames.har`. Add a copy of each new leak the developer finds to the probe table.
