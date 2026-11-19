# 0006 — Session in flutter_secure_storage (Keystore); PIN as a PBKDF2 hash (revised v0.2)

- Status: proposed
- Date: 2026-11-19

## Context
The Instagram session cookies give full access to the login account. FR-2 and NFR-5 require them to be encrypted at rest.
The optional app lock needs a PIN.

## Options considered
1. **flutter_secure_storage (Android Keystore-backed)**
   - ✅ Standard; works in a background isolate.
   - ❌ Keys can be invalidated on some OEMs, which forces a re-login.
2. **Hand-rolled AES-GCM with a key in the Keystore through a plugin** — ❌ more code and easy to get wrong.
3. **Plain shared_preferences** — ❌ breaks NFR-5.

PIN: **PBKDF2-HMAC-SHA256** (`cryptography` package, 210k iterations, random salt) vs Argon2 (stronger, but needs native code).

## Decision
flutter_secure_storage for the session blob and the PIN hash. PBKDF2 for the PIN, with a 30-second cooldown after 5 failures.
Backups are disabled entirely.

## Consequences
- If decryption fails, Storize treats the account as logged out and asks for a new login. Nothing else is lost.
- Never log the decrypted session (redaction tests).
- *(File name kept for history.)*
