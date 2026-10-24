# Account sync recovery —24 October2026

The reported phone showed a pending cloud backup and blocked Solo revive. Signing
out/in made it show Saved to cloud again. That supports a saved-session problem,
but the screenshots do not expose the failed endpoint/status. A public server
health request returned200 during this audit; that does not prove an authenticated
save succeeded at the time of the phone failure.

Confirmed source defects and corrections:

1. Access JWTs last15 minutes. Refresh rotated its token once, before the client
   had durably received the new token. A lost reply left the old token unusable.
   The app now journals a refresh operation in secure storage before requesting
   rotation. Gateway derives the replacement deterministically from the original
   secret token and that operation using the existing server hash secret. Retrying
   recovers the same still-current rotation, without storing plaintext tokens in
   the database. Revoked/expired/deleted sessions and different operations fail.
   Later rotations invalidate older recovery attempts. No fresh-code authority is
   granted by refresh. Old clients still perform their original one-time rotation.
2. A failed background sync had no timed retry. The controller now backs off at
   2/5/15/30/60 seconds while foreground, pauses retries in background and resumes
   safely. Offline play is never blocked. Genuine conflicts/required sign-in stop
   retries; purchase recovery checks receipts and never auto-buys.
3. A lost save acknowledgement plus a newer local save could look like another
   device's conflict: the outgoing operation was replaced by the newer one. The
   original upload is now journaled before sending and retried with the same
   existing idempotent /save key. The latest queued profile is uploaded afterward.
   A real remote revision/reset mismatch still requires an explicit choice.
4. A cached access token rejected before its local expiry now gets one renewal
   attempt. A genuine expired/revoked session keeps local progress and offers
   same-account re-verification; sign-out is not required. Failed secure storage
   of renewed tokens retains the recoverable old-token/operation pair.
5. Healthy Settings no longer has a permanent Sync now button. Failures show the
   actual curated issue and Retry backup/Sign in again/Resolve progress as needed.
   Revive errors no longer replace every root error with a vague sync instruction.

No new ENV variable, issuer, key, session secret or database schema is required.
Deploy the updated identity gateway and matching app for durable rotation replay;
an old gateway ignores the new operation and cannot provide this recovery promise.
The public API remains compatible with old clients. Do not rotate existing signing
or hash secrets to try to fix a player's session. Already-stranded legacy refresh
credentials may need one re-verification; the new protocol prevents that specific
failure for future renewals.

Focused tests cover outage recovery without manual sync, background/resume,
overlapping newer play plus lost upload acknowledgement, restart during refresh,
secure-storage failure after rotation, JWT rejection, true conflict protection,
revocation and HTTP operation forwarding. Existing wallet/revive/offline-entry
checks pass. App analyzer is clean; the full suite passed639 tests with5 opt-in skips.
Gateway verification passed17 tests and its compiled HTTP smoke test.
No phone installation or production deployment is implied.
