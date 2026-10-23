# Regun Admin and live balance

23 October 2026. Approved direction: a separate Flutter administration app, backed
by the existing Regun server/SpacetimeDB. No Supabase and no network requirement
for offline play. This document spans three independently buildable repositories:
`regun`, `regun-server`, and sibling `regun-admin`.

## Delivery boundary

The first delivery is a real local authoring application: current-data catalogue,
validated numeric editing, precise change review, persistent drafts, immutable
local candidates, import/export and an explicit local-only status. It does not
claim to publish to production. Subsequent phases introduce privileged publishing
and consuming the published data; those are separate integration milestones.
The existing game release and live server are unaffected by opening the admin app.

## Current architecture and consequences

- `regun/lib/data/loadout.dart` owns 21 weapons' base damage, cadence, range,
  speed, magazine and reload, plus 10 survivors' health, speed and damage scale.
- `WeaponPowerBalance` revision2 owns the latest damage baseline, Spore tick/
  geometry/control bounds and Mortar/Rivet/Anchor payload values. Legacy revision1
  is preserved for Continue. All of this currently ships as code.
- `GameNotifier.resetRun`, `changeTrainingWeapon`, `ArsenalSystem`,
  `EndgameArsenal`, `RegunGame` and reload presentation read those values at
  different points. Replacing only the enum damage getter would leave mixed runs.
- The server currently admits five weapons and three survivors; its combat,
  progression and survival modules have their own authoritative constants.
  A configuration cannot make an unsupported weapon playable online.
- The account service and SpacetimeDB identity tables already exist. A verified
  player account is not an administrator. The identity delivery operator is not
  an admin credential and must never be embedded in Flutter/web builds.
- The menu already has a passive update-check lifecycle. Balance refresh needs
  a separate nonmodal, best-effort service; it must never inherit a forced binary
  update gate or touch account admission.

## Admin application

Audience: the creator and explicitly authorized game operators. Desktop/web first,
with a usable narrow-screen layout. Charcoal/olive surfaces, restrained brass,
Orbitron headings, readable body type, tables/forms rather than a game HUD.

Workspace: `../regun-admin`, independent Flutter package, platforms web/macOS/iOS/
Android, its own lockfile, README, AGENTS, tests, configuration example and Makefile.
A workspace file links the three folders for convenient development without moving
source or copying game secrets. No game assets beyond reusable brand fonts are
needed; the admin app must not initialize Flame, SoLoud, player saves or purchases.

Initial flows:
1. Browse weapons, survivors and field/payload values; search by name/key.
2. Edit typed values with explicit units and bounds; preserve invalid input visibly
   and block candidate creation until all fields are valid.
3. Review old/new values and percentage changes; enter a required change reason.
4. Save an immutable, timestamped local candidate; later load it as a draft.
5. Export complete JSON or import a compatible document with atomic validation.
   Unknown keys, missing keys, wrong catalogue, nonfinite values and invalid types
   fail without changing the existing draft.
6. Persist drafts/candidates on-device. Storage errors must be visible; do not
   report a save that failed. Provide export as a recovery path.

The local catalogue is generated from the real Dart enum/profile sources with
source hashes and exact expected roster counts. The generator fails on changed
source shapes instead of silently dropping entries. It defines proposed editing
bounds, not a claim of game-side support. The app clearly labels the installed
baseline and local-only status. The review is the publication payload, not a live
connection. Cadence/range/reload/survivor changes remain proposals until their
runtime readers are integrated and verified.

## Contract and server storage (phase 2)

Move the reviewed contract into `regun-server/shared/balance` as the canonical
machine-readable schema/catalogue; generate or verify Dart/TypeScript adapters
against it. Every editable key has stable identity, units, finite range, integer
rules, default, support capability and owner. Restrict fields to an allowlist.
Schema1 includes weapon base metrics, survivor base metrics and existing weapon
field/payload scalars. Follow-on schemas may add ability, XP, encounter and enemy
values after reader coverage and compatible bounds are demonstrated. Never accept
arbitrary scripts, reducer names, asset URLs, entitlement prices or free-form keys.

Tables:
- `balance_admin`: private admin subject/role (`owner`, `editor`, `publisher`), revocation.
- `balance_draft`: private payload, base revision, author, optimistic edit version.
- `balance_release`: immutable payload, schema/capabilities, monotonic revision,
  content hash, base revision, author, reason, creation/publish timestamps.
- `balance_channel`: active staging/production revision and generation counter.
- `balance_audit`: append-only draft/publish/rollback events with actor and reason.

Only safe active release content/metadata is publicly readable. Drafts, admins and
audit history use server-filtered views; hiding an admin button is not authorization.
The creator has selected a separate email/password login for the administrator,
instead of the player email OTP flow. Initial owner email: `aktiv@ac.com`.
Use the password supplied privately in the planning conversation; do not reproduce
it in this document, source, fixtures, logs, screenshots or Flutter configuration.

Server-only environment configuration:
- `REGUN_ADMIN_EMAIL=aktiv@ac.com`
- `REGUN_ADMIN_PASSWORD_HASH`: a salted Argon2id hash of the supplied password,
  generated during secure server setup. Store the hash, not the plaintext password.
- `REGUN_ADMIN_SESSION_SECRET`: an independently generated session-signing secret;
  never derive it from or reuse the admin password or identity operator credentials.

Configure these through the server deployment's secret/environment settings.
Committed `.env.example` files contain placeholders only. Missing/invalid admin
configuration disables admin login and privileged operations, while public balance
reads, player accounts and offline gameplay remain independent.

The gateway verifies the submitted email/password over HTTPS, rate-limits attempts,
returns generic login failures, and issues an expiring administrator session.
Require explicit administrator membership at every privileged operation; the
configured initial account receives the owner role through server-side bootstrap.
The browser cannot mint a privileged SpacetimeDB identity or receive an operator
credential. The gateway authenticates/rechecks admin sessions and performs only
allowlisted server operations with a server-only principal whose privileges are
restricted to balance administration, separate from identity delivery.

Provide sign-out and session revocation. Password rotation must invalidate existing
admin sessions. Require fresh authentication for publishing and rollback. Use
Secure/HttpOnly/SameSite cookies and CSRF protection for the web session; native
clients keep any session credential in platform secure storage. Never persist the
password in browser storage or preferences. Bootstrap/revoke through an operator
CLI on the server; never expose the identity operator or mail/API keys to Flutter.
Web build/runtime configuration contains only public endpoint/database/channel IDs.
This is a planning requirement; deployment credentials have not been configured.

Server operations: fetch catalogue/current, save draft with compare-and-swap,
validate preview, publish expected-base, list release history, rollback expected-
current. Server revalidates the entire payload, role, schema and all cross-field
constraints. Publish writes the immutable release and channel pointer atomically;
a stale editor receives a conflict and must rebase/review, never silently overwrite.
Rollback creates a new monotonic release using an old known-good payload; do not
reuse an old revision or mutate a running room's configuration. Enforce body-size,
rate and history limits. Use a server-derived actor/time and content hash.

Prefer a thin HTTP gateway under the existing server origin for Flutter portability,
using SpacetimeDB as persistence/authority. It can also deliver a small public
GET `/balance/v1/current?channel=production&capability=...` with ETag/hash and bounded
cache headers. This route is a proposed API, not an endpoint currently deployed.
Use exact CORS origins and HTTPS in production. Admin operations require verified
short-lived sessions and CSRF protection if cookie-authenticated. Do not add another
standalone database/service merely for configuration.

## Game adoption (phase 3)

Introduce immutable `BalanceSnapshot` and `BalanceRepository`. A snapshot includes
schema, revision, capability set, hash and the complete validated numeric payload.
Ship the current values as the bundled baseline. On startup, synchronously make a
valid cached snapshot available, then run one deduplicated background refresh at
home/startup/foreground with a short timeout and retry backoff. Do not poll each
frame, await it during Start, show a loading modal, or require an account.

Validate size, schema, exact keys, types, ranges, cross-field rules, hash and
capability compatibility before committing an atomic cache replacement. A failed,
malformed or unsupported response retains the last valid cache/bundled values.
The public payload has no secrets. A hash checks integrity/caching, not authorship;
TLS and server publication permissions establish authority. Add signatures only
with a defined key-rotation/trust policy if delivery architecture requires them.

Capture one snapshot at fresh run creation. Route every integrated base reader,
upgrade calculation, training weapon swap, magazine/reload clock, projectile/
payload creation and value-dependent presentation through that snapshot. Separate
raw base numbers from upgrade effects and survivor multipliers to avoid applying
bonuses twice. Display descriptions derive from the same snapshot when numerical.

Checkpoint the complete small snapshot (or an immutable locally retained blob plus
hash with durable reference), not only a server revision requiring a later fetch.
Continue and offline restore use that exact snapshot. Migrate missing markers to
legacy revision1 and existing marker2 to the bundled revision2 baseline. Reject
unknown/mismatched snapshots safely. Preserve already-paid projectile/payload
amounts without recalculation. Training weapon changes stay within the captured
snapshot. Account/cloud saves retain the pinned snapshot too.

Downloaded changes become available only for a future new run; never mutate an
active run, paused run, checkpoint, current projectile or combat clock. Refresh
completion must not recreate a run, switch a profile or steal input/focus.
Cache unavailable/corrupt: recover to bundled defaults for new runs without blocking
play; existing checkpoints need a valid embedded snapshot or explicit safe recovery.

## Authoritative online integration (phase 4)

Pin an accepted snapshot on room/match start and persist it with server match state.
The server owns PvE/PvP outcomes; client sends intent, never base damage or a trusted
configuration. Announce revision/hash/capabilities in the handshake and snapshots.
A publication changes future matches only. Old clients either match an explicitly
supported configuration or receive a clear online-only update requirement; offline
play stays available. Never let a client-supplied JSON activate a server revision.

Keep PvP damage a distinct supported parameter from PvE, preserving the existing
separation introduced in the power pass. Shared fixtures must include effective
snapshot values, distance, armor, pierce, chain/proc and reload outcomes. Balance
staging/production channels and protocol capabilities are separate from binary
build numbers. Do not repurpose `COMBAT_VERSION` for every numerical adjustment.

## Rollout and acceptance

1. **Authoring foundation (this delivery):** separate app; generated current data;
   persistence/edit/validation/review/import/export/candidates; model and UI tests;
   desktop/narrow render review; production web build. Nothing publishes live.
2. **Secure server publishing:** contract parity, private tables/views, administrator
   bootstrap, environment-configured email/password login, conflict-safe staging
   publish/rollback, audit history.
   Prove unauthorized, revoked and stale sessions cannot read drafts or publish.
3. **Offline game reader:** complete snapshot plumbing, cache lifecycle, checkpoint/
   cloud migration. Prove airplane-mode first launch/Start/Continue, server timeout,
   invalid config, mid-run foreground refresh, old save and corrupted cache cases.
4. **Online authority:** room pinning, capabilities, shared combat fixtures and
   disconnect/reconnect tests; no PvP values inherited accidentally from PvE.
5. **Staging rehearsal:** change one damage value, verify new offline/online runs,
   preserve active/Continue runs, rollback, compare admin audit and client/server
   revision/hash. Then review a concrete production deployment for approval.

Future useful admin areas: enemy/boss/upgrade tuning, player support, economy,
announcements, reports and release controls. They need distinct permissions and
plans; the initial balance app must not invent destructive player-account tools.
