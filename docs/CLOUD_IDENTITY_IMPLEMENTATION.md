# Email identity and cloud saves — implementation

22 October 2026. Implements the first account/cloud-save release from
[CLOUD_IDENTITY_AND_SAVE_PLAN.md](CLOUD_IDENTITY_AND_SAVE_PLAN.md), in the Flutter
client and sibling `regun-server`. No production deployment or live email sending
has occurred in this pass.

## Player experience

Solo, Training and local Continue remain independent of identity/network checks.
Home's optional sync is background work, with a durable owner-scoped local profile
and outbox. Tests enter an actual offline game while the account request is hung
and the online policy endpoint is unavailable. Dismissing a code request remains
possible on compact phones and at larger text.

The invitation appears once on a safe eligible Home visit after Training/first
match, including existing installations with progression. It is deferred while
an update notice/check has priority and records its shown flag after rendering.
Settings always provides the account entry. The email/code/username notices use
GameNotice, existing fonts, brass/charcoal fields and pixel buttons. Returning
accounts reuse their verified email identity and existing username. News/offers
are separately Off by default.

Online entry requires a verified account and acceptable username in both client
and server; create/join/reconnect/membership and private views do not grant access
to anonymous guests. Room names are read-only and ignore supplied display-name
overrides. Changes are Settings-only, capped at two successful changes per server
UTC month, with transactional reservation/idempotency and reviewed name rules.
Moderation-required replacements are exempt from the quota. The versioned seed
list lives in `../regun-server/spacetimedb/src/username_policy.ts`; it needs ongoing
review and is not comprehensive abuse detection.

## Identity and recovery

Email is private recovery information. Stable account UUIDs own cloud saves and
canonical online totals. Login-session-scoped SpacetimeDB principals prevent a
new login from reviving an older revoked session. The Node identity service owns
signing/verification/email delivery, while all persistent account/challenge/
session/profile records remain in private SpacetimeDB tables. The module pins
its trusted issuer/audience and operator identity. No signing/email/admin secret
is packaged in Flutter or stored in SharedPreferences.

Numeric codes last 10 minutes and permit five committed attempts; resend/email/IP
windows are enforced in database transactions. Refresh secrets rotate and are
stored hashed on the server and in native secure storage on the device. Tokens
expire after 15 minutes, and the online socket renews before expiry. JWKS overlap
supports deliberate signing-key rotation. Failed account requests never hold a
local gameplay entry future.

Settings shows Account below Gameplay, with identity, concise backup status,
sync/setup, username changes, news preference, sign-out and deletion. Email is
fixed after account creation: both new requests and pending legacy email-change
codes are blocked by the server. Account deletion still verifies a fresh code
inside that action; there is no standalone re-verification or legacy-recovery row.
Rename allowance is shown only inside the rename flow. Offline sign-out retains
pending progress and an encrypted revocation queue for reconnection. Owner changes
wait until local play ends, so a dismissed network action cannot change the
profile underneath a running game. The loadout/game return future is carried
across route replacements so this boundary and first-return invitation are real.

Older online records have a two-proof claim: the host verifies the retained guest
bearer, and the trusted service confirms the verified target account. Claims
expire, cannot migrate the same guest to different accounts or repeat rewards,
and leave the original secure guest credential intact. First imports preserve
legacy totals; later potentially overlapping legacy totals use conservative
maxima, not added balances. Real pre-upgrade-history recovery still needs staged
acceptance with backed-up player data.

## Cloud progression

The existing schema-3 PlayerProfile is preserved, including earned currency,
unlocks, counters, discoveries, fusions, owned cosmetics and normal/assisted
records. It now also carries the selected normal-play survivor/weapon/arena.
Device controls/audio/accessibility and in-progress Continue stay local.

Each account's profile and pending snapshot are serialized atomically to local
storage before cloud upload. Cloud replacements carry revision, reset epoch and
idempotency ID. Conflicting devices get an explicit cloud/device choice rather
than automatic balance/counter addition. Lost acknowledgements with identical
payloads reconcile without a duplicate grant. Reset increments an epoch, preventing
old pending saves from resurrecting progress. Account switching preserves separate
profiles, backups and Continue files; a different account cannot import the
previous account's inventory. Deletion removes the account's local profile files,
preference records and checkpoint after server acknowledgement.

This first implementation uses conservative snapshot conflicts. It does not yet
merge independently earned offline runs as a full event ledger, or transfer active
runs between devices. Offline/client saves never grant paid or ranked authority.
Real-money billing/receipt restoration remains a separate feature because Regun
has no billing SDK/products yet; the UI does not advertise a fake restore action.

## Configure and validate

The full service setup and provider contract are documented in
[the sibling identity README](../../regun-server/identity/README.md).
The repository-root `regun-server/Dockerfile` now packages the account process
inside the existing server deployment; see `../../regun-server/deploy/ACCOUNTS.md`.
Use the same `https://regunserver.kiishi.space` origin in the app, with account
routes enabled on the server. Set `EMAIL_PROVIDER=sendbyte` or `resend`; the
adapter boundary is `EmailSender`.
Sendbyte uses its canonical `/v1/emails` API and body idempotency key; Resend uses
its own endpoint/header. Build the app with public `REGUN_IDENTITY_URL` only after
the HTTPS service, verified sending domain, signing/HMAC secrets and database
operator are provisioned. The integrated startup generates public issuer/operator pins from the persistent
publisher before building/publishing, without secrets in Docker build arguments.
Empty checked-in server pins close online admission in manual/unconfigured builds;
coordinate server/client rollout and capability policy before deployment.

Validation passes Flutter analyzer and 505 tests (five optional skips), backend type/tests/
module build, delivery adapter and key-overlap tests, service production compilation,
and a disposable actual SpacetimeDB OTP/JWKS/WebSocket test using both TypeScript
and the existing Flutter Dart SDK. Backend verification passes 97 tests and the
module build; the identity service passes four contract/key tests and production
compilation. The live proof also covers idempotent two-proof guest claims. The integration uses captured test email and
private temporary credentials; no production data or real recipients are used.

Before live rollout: provision secrets/domain/HTTPS and private operator networking;
verify proxy/IP limits, actual inbox delivery, native secure-storage/keyboard/
foreground behavior, pre-upgrade guest history and backup recovery. Check session
renewal and multiple-device conflicts with real builds. No phone installation or
physical/native acceptance is claimed by this source pass.

The account dialog ignores accidental barrier taps while dismissing the keyboard;
code, resend countdown and current step stay mounted until an explicit exit.
Verification messages always send a `Regun` display name while preserving the
configured mailbox, even if `EMAIL_FROM` uses a bare `hello@…` address. Existing
received email is unchanged; the backend update affects subsequent messages.
