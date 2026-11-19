# 0008 — Distribution: public GitHub repo + Releases; update check through the GitHub API (revised v0.2)

- Status: proposed (v0.2: the user offered a public repo, D-14)
- Date: 2026-11-19

## Context
- Google Play is likely to reject the app (R-3).
- Instagram changes need fast hotfixes (NFR-9).
- The user can create a public repo.

## Options considered
1. **Public GitHub repo; CI builds a signed APK on tag `v*` and publishes it as a GitHub Release; the app calls `releases/latest`**
   - ✅ Free CI minutes, no separate update manifest.
   - ✅ Simple install link for the team.
   - ❌ Code and APK are public, so anyone can use them.
   - ❌ A Meta takedown request to GitHub could remove the repo (R-7).
2. **Private repo + manifest elsewhere** (v0.1) — ✅ less exposure ❌ team members need GitHub access; extra manifest hosting.
3. **Firebase App Distribution** — ❌ Google sign-in and an SDK (conflicts with NFR-6).
4. **Google Play closed testing** — ❌ policy risk; review delays slow hotfixes.

## Decision
Option 1.

## Safeguards
- No secrets in the repo; gitleaks runs in CI.
- Sanitized fixtures.
- Signing keystore and passwords stored only in GitHub Actions secrets plus an offline backup.
- Branch protection on `main`; Dependabot.
- A local or private mirror backup of the repo, in case of a takedown.

## Consequences
- Losing the signing key forces every user to uninstall and reinstall. Gallery files survive, but the app's targets and
  library are lost, so the key backup is mandatory.
- The release notes must include `sha256:` and `min-supported:` lines (CI writes them).
- Repo: https://github.com/Amr905/Storize — update check calls `GET https://api.github.com/repos/Amr905/Storize/releases/latest`.
