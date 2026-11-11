# Regun Push Notifications — OneSignal Implementation Plan

Status: **Draft for review**
Date: 10 November 2026
Scope: mobile game (`../regun`), identity/admin server (`../regun-server`), admin app (`../regun-admin`)
Decision owner: Regun maintainer

---

## 1. Recommendation in one page

Use **OneSignal as the delivery provider only**. Regun remains the source of truth
for accounts, consent, audience rules, and send history.

- The Flutter game initialises the OneSignal SDK on **iOS and Android only**.
- A signed-in player's OneSignal `external_id` is `acct_<account-uuid>`.
- A guest's `external_id` is `guest_<device-uuid>` (the existing `PlayerRegistry`
  device id, which is not a secret).
- The game reports its OneSignal subscription state to the Regun identity service.
- The server stores subscriptions, consent, campaigns, and delivery audit rows in
  SpacetimeDB, and calls the OneSignal REST API from `identity/`.
- The admin app gets a new **Notifications** tab that composes, previews, tests,
  schedules, cancels, and audits sends.
- The OneSignal REST key and app id live only in server runtime environment. They
  never enter Flutter builds, Dart defines, Git, or admin local storage.

Why this shape:

1. OneSignal already solves APNs/FCM plumbing, token refresh, opt-out, and
   delivery analytics. Rebuilding that is not the job.
2. Regun's existing identity service already owns account authentication, device
   reports, admin sessions, audit, and SpacetimeDB access. Push is a natural
   extension, not a fourth service.
3. Server-side audience rules let the admin target real Regun facts
   (`signed in`, `marketing opt-in`, `last seen`, `platform`) instead of
   maintaining a duplicate segment model in the OneSignal dashboard.
4. A server-side registry makes account deletion, consent withdrawal, audit, and
   "why did/didn't this player get a push?" answerable.

**Phasing:** ship the plumbing and one transactional notification first
(`account_security` / welcome), then admin campaigns. Do not begin with
re-engagement blasts.

---

## 2. Current state (what exists today)

### 2.1 Mobile game (`../regun`)

| Area | Current behaviour | Relevant files |
|---|---|---|
| Entry point | `main()` initialises audio, preferences, account controller, player registry, then `runApp` | `lib/main.dart` |
| Navigation | `MaterialApp` with `navigatorKey`; internal screens are pushed manually, `go_router` is only `/menu` and `/game` | `lib/main.dart:29`, `lib/navigation/router.dart`, `lib/views/menu_view.dart` |
| Account | Email OTP → username; secure refresh session; 15-minute access tokens | `lib/services/account/account_controller.dart`, `lib/services/account/account_api.dart`, `lib/models/account/account_session.dart` |
| Guest identity | Stable device UUID + secret in secure storage; optional account link | `lib/services/player_registry.dart` |
| Server endpoint | `REGUN_IDENTITY_URL`, default `https://regunserver.kiishi.space` | `AccountApi._configuredEndpoint`, `PlayerRegistry` |
| Settings UI | Sections for Display, Audio, Gameplay, Account | `lib/views/settings_view.dart`, `lib/widgets/account_settings.dart`, `lib/widgets/settings_section.dart` |
| Platforms shipped | iOS, Android, macOS, web (desktop input path); macOS/web must be guarded | `pubspec.yaml`, `lib/desktop/`, `lib/views/base_view.dart` |
| App ids | Android/iOS `dev.kiishi.regun`; iOS build approved on the App Store | `android/app/build.gradle`, `ios/Runner.xcodeproj` |
| Push today | None | — |

### 2.2 Identity / admin server (`../regun-server`)

| Area | Current behaviour | Relevant files |
|---|---|---|
| Runtime | Node 22 + TypeScript, one process on loopback `:3200`, Nginx fronts `:3000` | `identity/src/main.ts`, `deploy/ACCOUNTS.md` |
| HTTP router | Public discovery, `/request`, `/verify`, `/refresh`, `/account`, `/leaderboards/v1/*`, `/players/v1/*`, `/admin/*`, `/economy/v1/*`, `/balance/v1/*` | `identity/src/http.ts` |
| Admin auth | Argon2id password, HMAC session digest, 30-day sessions, per-IP limits | `identity/src/admin_auth.ts`, `identity/src/admin.ts` |
| Database bridge | Operator-token SQL/reducer bridge; no direct DB credentials in clients | `identity/src/database.ts` |
| Accounts | `identity_account` has `email`, `username`, `marketing`, `deleted`; sessions/challenges/limits separate | `spacetimedb/src/schema.ts:170+` |
| Device reports | `player_device` keyed by device UUID, `secret_digest`, optional `account_id`, last seen, payload | `spacetimedb/src/schema.ts:440+`, reducer `player_report` in `spacetimedb/src/admin.ts:183+` |
| Admin API | `/admin/login`, `/admin/users`, `/admin/users/:id`, `/admin/audit`, releases, economy, armory, guide | `identity/src/admin.ts:177+` |
| Outbound HTTP pattern | Bounded `fetch` with `AbortSignal.timeout`, sanitised failures | `identity/src/mail.ts` |
| Deployment env | Server-only secrets in Dokploy runtime; never Dart defines | `identity/.env.example`, `deploy/ACCOUNTS.md` |

### 2.3 Admin app (`../regun-admin`)

| Area | Current behaviour | Relevant files |
|---|---|---|
| Frameworks | Flutter, macOS/iPhone/web, 30-day server sessions | `lib/services/admin_connection.dart` |
| Navigation | Five destinations: Balance, Review, Drafts/Candidates, Players, Releases | `lib/screens/workbench.dart` |
| Server calls | `AdminConnection.request()` with bearer session, 1 MB response cap | `lib/services/admin_connection.dart` |
| Players | Searchable account/guest directory with stats and presence | `lib/screens/server_screens.dart`, `lib/screens/leaderboard_records_page.dart` |
| Existing pattern | Dedicated page + explicit load/report/commit states, visible errors, no silent failure | `lib/screens/economy_page.dart`, `lib/screens/help_page.dart` |

### 2.4 What is explicitly absent

- No push SDK dependency, no notification permission flow, no device token
  handling.
- No server-side OneSignal credentials or HTTP client.
- No push subscription table, consent flags, send log, or admin composer.
- No deep-link router for notification taps.
- No push-specific tests or deployment documentation.

---

## 3. Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ Player device (iOS / Android)                                        │
│  Flutter game                                                        │
│   └─ PushService                                                     │
│       ├─ OneSignal.initialize(appId)                                 │
│       ├─ login(external_id) / logout()                               │
│       ├─ tags: platform, app_version, account_kind, consent          │
│       ├─ click listener ──► NotificationRouter ──► in-app screen    │
│       └─ subscription observer ──► POST /notifications/subscription  │
└──────────────────────────────────────────────────────────────────────┘
                                    │ HTTPS
┌───────────────────────────────────▼──────────────────────────────────┐
│ Regun identity service (`identity/`, Node 22)                        │
│  ├─ PushRegistry  ── SpacetimeDB: push_subscription, push_preference │
│  ├─ PushSender    ── OneSignal REST API (server-side key only)        │
│  ├─ PushEvents    ── account/purchase/leaderboard/admin triggers     │
│  └─ Admin routes  ── /admin/notifications/*                          │
└───────────────────────────────────┬──────────────────────────────────┘
                                    │ HTTPS
┌───────────────────────────────────▼──────────────────────────────────┐
│ OneSignal                                                            │
│  └─ APNs (iOS) / FCM v1 (Android) ──► device notification tray       │
└──────────────────────────────────────────────────────────────────────┘
                                    ▲
┌───────────────────────────────────┴──────────────────────────────────┐
│ Regun Admin (`../regun-admin`)                                       │
│  └─ Notifications tab ── /admin/notifications/*                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.1 Identity graph

| Player state | OneSignal `external_id` | Server owner key | Targetable by admin |
|---|---|---|---|
| Guest, no account | `guest_<device-uuid>` | `guest:<device-uuid>` | Yes, via subscription/device |
| Signed in | `acct_<account-uuid>` | `account:<account-uuid>` | Yes, all devices on that account |
| Guest later signs in | Switch `login()` to `acct_...`; old guest alias becomes empty | Subscription re-linked to account | Yes |
| Signs out | `OneSignal.logout()`, then optionally `login(guest_...)` | Subscription unlinked to guest | Guest targeting only |
| Deletes account | Server deletes registry rows and OneSignal user | Rows removed; OneSignal user deleted | No |
| Multiple devices, one account | Same `external_id` on each device | Multiple subscriptions under one account | Yes, fan-out |

Rules:

- Never use email, username, or raw account UUID without the `acct_` namespace.
- Never put a secret in `external_id` or tags.
- The account UUID is already used by `AccountLocalStore` and is not secret.
- Guests remain targetable only for non-promotional, local-value messages until
  they opt in; marketing requires an account and marketing consent.

### 3.2 Why keep a server-side subscription registry if OneSignal has aliases?

Because the product needs to answer questions that OneSignal alone cannot answer
safely:

- Which Regun account owns this subscription, and is the account deleted?
- Did this player withdraw consent, and when?
- Which admin sent which message to which audience, with what result?
- How many reachable subscriptions match "signed-in, iOS, seen in 7 days,
  marketing opt-in"?
- How do we remove all traces on account deletion?

OneSignal remains authoritative for *delivery*. Regun is authoritative for
*eligibility*.

---

## 4. Data model (SpacetimeDB)

Add these tables to `spacetimedb/src/schema.ts`. Keep all rows private; expose only
through server routes and admin-authenticated endpoints. Do not add client
subscriptions to these tables.

### 4.1 `push_subscription`

One row per OneSignal subscription (device install).

| Column | Type | Notes |
|---|---|---|
| `id` | `t.string().primaryKey()` | OneSignal subscription UUID |
| `owner` | `t.string().index("btree")` | `account:<uuid>` or `guest:<uuid>` |
| `accountId` | `t.string().index("btree")` | Empty for guests |
| `deviceId` | `t.string().index("btree")` | Existing `player_device.id` |
| `externalId` | `t.string().index("btree")` | `acct_...` / `guest_...` |
| `platform` | `t.string()` | `ios` / `android` |
| `appVersion` | `t.string()` | e.g. `1.0.1+44` |
| `locale` | `t.string()` | BCP-47, capped |
| `timezone` | `t.string()` | IANA, capped |
| `permission` | `t.string()` | `granted` / `denied` / `default` |
| `optedIn` | `t.bool()` | App-level master switch |
| `createdAt` | `t.u64()` | ms |
| `updatedAt` | `t.u64()` | ms |
| `lastSeenAt` | `t.u64()` | ms |
| `disabledAt` | `t.u64()` | 0 when active |
| `lastError` | `t.string()` | Sanitised, capped |

Indexes: `owner`, `accountId`, `externalId`, `deviceId`, `platform`.

Retention: delete rows 90 days after `disabledAt`, or immediately on account
deletion. Never keep a subscription id after OneSignal user deletion succeeds.

### 4.2 `push_preference`

One row per owner (`account:` or `guest:`).

| Column | Type | Notes |
|---|---|---|
| `owner` | `t.string().primaryKey()` | |
| `master` | `t.bool()` | App-level switch; OS permission still wins |
| `security` | `t.bool()` | Sign-in/purchase/account safety; default true |
| `leaderboards` | `t.bool()` | Rank/reset notices; default false |
| `events` | `t.bool()` | Seasonal/event campaigns; default false |
| `reengagement` | `t.bool()` | Inactivity nudges; default false |
| `updatedAt` | `t.u64()` | |

Promotional categories (`events`, `reengagement`) additionally require
`identity_account.marketing = true` for signed-in accounts. Transactional
categories do not.

### 4.3 `push_message`

One row per composed message (admin campaign or server event template).

| Column | Type | Notes |
|---|---|---|
| `id` | `t.string().primaryKey()` | Server UUID |
| `kind` | `t.string()` | `transactional` / `campaign` |
| `category` | `t.string()` | `security`, `events`, `leaderboards`, `reengagement` |
| `title` | `t.string()` | ≤ 60 chars, validated |
| `body` | `t.string()` | ≤ 180 chars, validated |
| `route` | `t.string()` | Allowlisted deep-link key |
| `routeParam` | `t.string()` | Optional id (e.g. board key) |
| `audience` | `t.string()` | JSON, server-validated, no raw SQL |
| `createdBy` | `t.string()` | Admin email/actor |
| `createdAt` | `t.u64()` | |
| `scheduledAt` | `t.u64()` | 0 = immediate |
| `status` | `t.string()` | `draft`, `scheduled`, `sending`, `sent`, `partial`, `failed`, `cancelled` |
| `onesignalId` | `t.string()` | OneSignal message id when accepted |
| `recipientCount` | `t.u32()` | Requested target count |
| `deliveredCount` | `t.u32()` | From OneSignal stats where available |
| `error` | `t.string()` | Sanitised, capped |

### 4.4 `push_delivery` (optional, phase 2)

Per-recipient audit only when needed for support. Avoid storing every fan-out for
large campaigns by default.

| Column | Type |
|---|---|
| `key` | `t.string().primaryKey()` (`messageId:subscriptionId`) |
| `messageId` | `t.string().index("btree")` |
| `subscriptionId` | `t.string().index("btree")` |
| `owner` | `t.string().index("btree")` |
| `status` | `t.string()` |
| `createdAt` | `t.u64()` |

Network egress and OneSignal API failures are logged without message bodies,
subscription ids, or account emails.

---

## 5. API contracts

All routes are added to `identity/src/http.ts`. Client routes accept JSON with a
bounded body already enforced by `http.ts`. Admin routes use the existing bearer
session and admin rate limiting.

### 5.1 Client — register/update subscription

`POST /notifications/subscription`

Auth: optional bearer. Guests must prove device ownership using the existing
device credential.

```json
{
  "subscriptionId": "0d1f...",
  "externalId": "acct_<uuid>",
  "deviceId": "<uuid>",
  "deviceSecret": "<43-char base64url>",
  "platform": "ios",
  "appVersion": "1.0.1+44",
  "locale": "en-NG",
  "timezone": "Africa/Lagos",
  "permission": "granted",
  "optedIn": true
}
```

Server rules:

- Validate UUIDs, lengths, enum values, and `externalId` prefix.
- If bearer is present, resolve `accountId` with `IdentityService.status(token)`
  and derive `externalId = acct_<accountId>`; ignore a conflicting client value.
- If bearer is absent, require `deviceId` + `deviceSecret`; verify
  `sha(deviceSecret)` against `player_device.secret_digest`.
- Upsert by `subscriptionId`; never allow a subscription to move from one account
  to another without a fresh authenticated registration.
- Cap registration attempts per IP/device.
- Return `{ ok: true, owner, categoryPrefs }`.

`DELETE /notifications/subscription`

Body: `{ subscriptionId, deviceId?, deviceSecret? }` or bearer. Marks the row
disabled and clears tags. App uninstall cannot be detected reliably, so also rely
on OneSignal's inactive-subscription state.

### 5.2 Client — read/update preferences

`GET /notifications/preferences` (bearer or guest credential)

`POST /notifications/preferences`

```json
{
  "deviceId": "<uuid>",
  "deviceSecret": "<secret>",
  "master": true,
  "security": true,
  "leaderboards": false,
  "events": false,
  "reengagement": false
}
```

The game must also call `OneSignal.User.pushSubscription.optIn()` / `optOut()` so
the provider stops delivering when the master switch is off. Preferences alone do
not guarantee suppression for server-side sends; `PushSender` must filter by
preference before calling OneSignal.

### 5.3 Admin — audience preview

`POST /admin/notifications/audience`

```json
{
  "signedIn": true,
  "platforms": ["ios", "android"],
  "minAppVersion": "1.0.0",
  "lastSeenWithinDays": 30,
  "inactiveForDays": 0,
  "marketingOptIn": true,
  "categories": ["events"]
}
```

Response: `{ reachable, accounts, guests, byPlatform, sample: [...] }` where
sample contains masked owner ids only (e.g. last 6 chars) and never emails.

Hard limits: audience previews are capped (e.g. 50,000 rows scanned) and return
`truncated: true` rather than a misleading exact count.

### 5.4 Admin — test send

`POST /admin/notifications/test`

Body: `{ title, body, route, category, accountId? }`.

Sends only to the admin's own registered subscription (or a specific test account
explicitly configured in server env). Test sends are labelled in OneSignal and
bypass campaign caps, never production audiences.

### 5.5 Admin — create/schedule/cancel

- `POST /admin/notifications` — create draft or immediate send.
- `POST /admin/notifications/:id/send` — explicit send; production requires a
  second confirmation field (`confirm: "SEND"`).
- `POST /admin/notifications/:id/cancel` — cancels a scheduled message before
  OneSignal accepts it; after acceptance, use OneSignal cancel API and record the
  partial result.
- `GET /admin/notifications` — cursor list, newest first.
- `GET /admin/notifications/:id` — status, counts, errors, audit.
- `GET /admin/notifications/audit` — append-only send history.

All admin writes call `admin_audit` with actor, kind, detail, timestamp. The
audit detail stores the message id and audience hash, not full recipient lists.

### 5.6 Server internal — send

`PushSender.send(message, audience)`:

1. Re-check `push_message.status` is `scheduled`/`draft` and not cancelled.
2. Resolve eligible subscriptions from `push_subscription` and
   `push_preference` (and `identity_account.marketing` for promotional).
3. Drop disabled/deleted owners, denied OS permission, opted-out master.
4. Chunk targets to 20,000 per OneSignal request.
5. Call `POST https://api.onesignal.com/notifications?c=push` with:
   - `app_id`
   - `include_aliases: { external_id: [...] }` and `target_channel: "push"`
   - or `include_subscription_ids` when targeting exact subs
   - `headings`, `contents`
   - `data: { route, routeParam, messageId, category }`
   - `idempotency_key` (one per chunk; stored for retry)
   - `collapse_id` for replaceable nudges
   - `ttl` (e.g. 86400 for campaigns, 3600 for time-sensitive)
6. Aggregate `id` and `errors`; treat falsy `id` as "no notification created".
7. Update `push_message` with counts/status/error.
8. Never retry a non-idempotent send without the same idempotency key.

---

## 6. Mobile implementation plan (`../regun`)

### 6.1 Dependency

Add `onesignal_flutter` (latest 5.x compatible with the pinned Flutter SDK) to
`pubspec.yaml`. Run `flutter pub get` and commit `pubspec.lock`.

Do **not** add Firebase packages unless OneSignal setup requires a local config
file. OneSignal's Android setup uses the dashboard FCM service account; only add
`google-services.json` if the chosen OneSignal version requires it.

### 6.2 New service files

```
lib/services/push/push_service.dart        // SDK lifecycle + identity sync
lib/services/push/push_api.dart            // subscription/preferences HTTP
lib/services/push/push_router.dart         // tap payload → screen
lib/services/push/push_preferences.dart    // local mirror and UI state
```

`PushService` responsibilities:

- `initialize()` — call once after `WidgetsFlutterBinding.ensureInitialized()`,
  before `runApp` and only on `ios`/`android`.
- Read app id from `--dart-define=ONESIGNAL_APP_ID` (public config, not secret).
  If empty, no-op; the game must still start.
- `OneSignal.initialize(appId)`.
- `OneSignal.Notifications.requestPermission(false)` only after an in-app
  explanation, not on first frame.
- `OneSignal.Notifications.addClickListener(handleTap)`.
- `OneSignal.Notifications.addForegroundWillDisplayListener(...)` to decide
  whether to show a banner while playing (recommended: suppress during active
  runs, show on home).
- Observe `OneSignal.User.pushSubscription` changes and POST them to
  `PushApi.reportSubscription`.
- Observe permission changes and update local/remote preference state.
- `loginForAccount(accountId)`, `loginForGuest(deviceId)`, `logout()`.

`PushApi` mirrors `AccountApi`:

- same `REGUN_IDENTITY_URL`
- same HTTPS/localhost guard
- 12-second timeout
- bounded body, bounded response
- no retry loop that blocks gameplay; use a small durable outbox like
  `PlayerRegistry`
- guest requests include the existing device id/secret from
  `RegistrySecrets`; do not log the secret

### 6.3 Startup order

In `lib/main.dart`:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. existing audio/preferences initialisation
3. `await PushService.shared.initialize()` (non-fatal; catch and log)
4. existing `runApp`

The app must never wait on the network for push setup. If OneSignal or the
identity service is unavailable, gameplay and account flows proceed unchanged.

### 6.4 Identity sync matrix

Hook into `AccountController`. Prefer explicit calls over listening to arbitrary
state changes.

| Event | Mobile action |
|---|---|
| App start, signed in session restored | `OneSignal.login('acct_<accountId>')`, then report subscription |
| App start, guest | `OneSignal.login('guest_<deviceId>')` only after guest id exists |
| Successful `verifyCode` | `login('acct_...')`, report subscription, clear guest tags |
| `attach`/guest claim completes | `login('acct_...')`, re-report; old guest alias stops receiving |
| `signOut` | `OneSignal.logout()`, then `login('guest_...')` if the device remains |
| `deleteAccount` | call `DELETE /notifications/subscription`; `OneSignal.logout()`; clear local cache |
| Account switch | login new account; never keep old account tags |
| App resume | report subscription if id/permission changed; refresh prefs from server |

Implementation point: `AccountController` already owns `_saveSession`,
`_clearSession`, `signOut`, `deleteAccount`, and `verifyCode`. Add a single
`PushService.syncIdentity()` call after those state transitions, guarded by
`kIsWeb`/desktop checks. Do not add push calls inside the local gameplay path.

### 6.5 Permission UX

Do not request notification permission on first launch. Ask when there is an
obvious benefit:

- after the first completed run, or
- when the player opens Settings → Notifications, or
- when the player first signs in (for account security notices).

Flow:

1. In-app explanation using the existing `GameNotice` / settings style:
   "Get notified when a run reward is ready, a leaderboard resets, or your
   account needs attention. You can turn this off any time."
2. "Enable notifications" button → `requestPermission(true)`.
3. "Not now" persists a local `asked` flag so we do not nag every launch.
4. If OS permission is denied, show "Notifications are off in system settings"
   with a deep link to app settings (via `url_launcher` or platform channel).

Settings UI: add a `SettingsSection(title: 'Notifications')` in
`lib/views/settings_view.dart` with:

- master toggle
- category toggles (Leaderboards, Events, Re-engagement)
- status line: "On", "Off in system settings", or "Not enabled"
- "Open system settings" when denied

Persist locally in `LocalPreferences` (or a dedicated `PushPreferences` store)
for instant UI response; sync to server in the background.

### 6.6 Deep links and tap routing

Add `lib/services/push/push_router.dart`:

```dart
abstract final class PushRoute {
  static const home = 'home';
  static const collection = 'collection';
  static const leaderboards = 'leaderboards';
  static const settings = 'settings';
  static const store = 'store';
  static const account = 'account';
  static const online = 'online';
}
```

Rules:

- Allowlist route keys server-side and client-side. Unknown routes open Home.
- Validate `routeParam` (length, character set) before use.
- Cold start: `handleTap` may fire before `runApp`; queue the payload in
  `PushService` and flush after the first `navigatorKey` frame.
- Warm start: push the target page with `GamePageRoute`, matching `MenuView._open`
  (`lib/views/menu_view.dart:175`).
- If the player must sign in for the target (online/account), route to the Home
  menu with a `GameNoticeStrip` explaining the required sign-in; do not open a
  protected screen directly.
- Do not auto-start a run from a notification. A tap can open Home, Collection,
  Settings, Leaderboards, Store, or the online gate, never a live combat state.
- Clear the notification/badge after handling.
- In-app foreground display: suppress banners during an active run; show on menu
  screens. Use `addForegroundWillDisplayListener` and `event.preventDefault()`
  when suppressing.

### 6.7 Desktop/web guard

OneSignal push is scoped to iOS and Android in this plan.

- On macOS, web, Linux, and Windows, `PushService.initialize()` must return
  immediately and never add plugin channels. The existing desktop path uses
  `desktopInputAvailable` and `kIsWeb`.
- The settings Notifications section should be hidden or explain "Push is
  available on the mobile app" on desktop/web.
- Do not add APNs entitlements to the macOS target unless a later macOS push
  milestone is approved.

---

## 7. Server implementation plan (`../regun-server`)

### 7.1 Dependencies and configuration

No new npm dependency is required; use global `fetch` like `identity/src/mail.ts`.
Optionally adopt `@onesignal/node-onesignal` later, but a small typed client keeps
the surface auditable and avoids generated-SDK churn.

Add server-only runtime variables:

```dotenv
# OneSignal — server only. Never a Flutter Dart define.
ONESIGNAL_APP_ID=
ONESIGNAL_REST_API_KEY=
ONESIGNAL_ENABLED=false
ONESIGNAL_TEST_ACCOUNT_ID=
ONESIGNAL_TEST_SUBSCRIPTION_ID=
# Optional guardrails
ONESIGNAL_MAX_RECIPIENTS=20000
ONESIGNAL_DAILY_CAMPAIGN_LIMIT=3
ONESIGNAL_QUIET_HOURS=22:00-08:00
```

Deployment: add them to the existing Dokploy application in
`deploy/ACCOUNTS.md` style. If `ONESIGNAL_ENABLED=false` or credentials are
missing, all push routes return `503` with a clear admin message; gameplay and
other account functions are unaffected.

Never print the key. Redact `Authorization` and response bodies in logs.

### 7.2 New modules

```
identity/src/push.ts             // PushService: audience, consent, registry
identity/src/onesignal.ts        // bounded REST client
identity/src/push_events.ts      // transactional triggers
identity/src/push_admin.ts       // admin route handlers (or extend admin.ts)
```

`onesignal.ts` contract:

```ts
export interface OneSignalClient {
  sendPush(input: {
    appId: string;
    title: string;
    body: string;
    externalIds?: string[];
    subscriptionIds?: string[];
    data: Record<string, string>;
    idempotencyKey: string;
    ttl?: number;
    collapseId?: string;
  }): Promise<{
    id: string | null;
    errors: unknown;
    status: number;
  }>;
}
```

Implementation requirements:

- `Authorization: Key ${key}` header.
- `AbortSignal.timeout(10_000)`.
- Max response size (e.g. 256 KB).
- Do not retry on 4xx; retry once on timeout/5xx only with the same idempotency
  key.
- Normalise the two documented 200 shapes; a falsy `id` means nothing was sent.
- Sanitise `errors` before storing/returning; never relay the raw request.

### 7.3 Database bridge

Extend `identity/src/database.ts` usage with reducers:

- `push_subscription_upsert`
- `push_subscription_disable`
- `push_preference_set`
- `push_message_create`
- `push_message_status`
- `push_message_finish`
- `push_admin_audit` (or reuse `admin_audit`)

Add TypeScript reducers in `spacetimedb/src/push.ts` and register tables in
`schema.ts`. Follow the existing operator-only reducer pattern (`player_report`):
validate every argument, cap payload size, reject ownership mismatches, use
`now(ctx)`.

Audit rows: reuse `admin_audit` with `kind = "push.send"`, `detail` containing
message id, category, audience hash, and counts. Do not store recipient lists.

### 7.4 Routing

In `identity/src/http.ts`, before the generic token branch:

- `POST /notifications/subscription`
- `DELETE /notifications/subscription`
- `GET/POST /notifications/preferences`

These must be reachable without a bearer token (guest), but still rate-limited by
IP/device and validation-hardened. Signed-in requests pass the existing access
token and are resolved with `service.status(token)`.

Admin routes in `AdminService.route` (`identity/src/admin.ts`):

- `/admin/notifications` (GET list, POST create)
- `/admin/notifications/audience` (POST preview)
- `/admin/notifications/test` (POST)
- `/admin/notifications/:id` (GET)
- `/admin/notifications/:id/send` (POST)
- `/admin/notifications/:id/cancel` (POST)
- `/admin/notifications/audit` (GET)

All are behind `session(token)` already used by the admin service. Add an explicit
`enabled` check and a per-admin rate limit (e.g. 30 sends/hour).

### 7.5 Transactional event triggers (phase 1)

Start with events that are already authoritative in the server and have clear
user value:

| Event | Trigger point | Category | Payload route |
|---|---|---|---|
| Account verified / first sign-in | `IdentityService.verify` success | `security` | `account` |
| New device sign-in | `identity_session` created on a new device | `security` | `account` |
| Purchase completed | after `purchase-status` confirms receipt | `security` | `store` |
| Weapon purchase completed | after `weapon-purchase-status` confirms | `security` | `collection` |
| Scrap delivered (Apple/Bachs webhook) | webhook handler success | `security` | `store` |
| Leaderboard reset / rank change | leaderboard publish or periodic job | `leaderboards` | `leaderboards` |
| Admin balance/economy release | `admin_publish` / `adminEconomyPublish` | `events` | `home` |

Important: send after the transaction commits, never inside a reducer that can
roll back. Use an outbox row (`push_message` with `status='scheduled'`) and a
small worker loop, or fire-and-forget after the HTTP response with error
isolation. Do not block the account response on OneSignal availability.

Phase 2 (only after phase 1 is stable): inactivity re-engagement, boss/event
reminders, seasonal campaigns. These require scheduled jobs and stricter consent.

### 7.6 Audience resolution

Do not accept raw OneSignal filters from the admin app. Build a typed audience
object and translate it server-side:

```ts
type PushAudience = {
  signedIn?: boolean;
  platforms?: ("ios" | "android")[];
  minAppVersion?: string;
  lastSeenWithinDays?: number;
  inactiveForDays?: number;
  marketingOptIn?: boolean;
  categories?: PushCategory[];
  owners?: string[]; // internal/test only, capped
};
```

Resolution joins `push_subscription` + `push_preference` + `identity_account`
(only for `deleted`, `marketing`) and applies:

- active subscription (`disabledAt = 0`, `optedIn = true`, `permission = granted`)
- category preference
- marketing consent for promotional categories
- frequency cap and quiet hours
- dedupe by owner (one push per account, not per device, for campaigns)

Cap the resolved set; return counts and `truncated` to the admin. If the set
exceeds 20,000, chunk requests and use a distinct idempotency key per chunk.

### 7.7 Scheduling and worker

SpacetimeDB scheduled reducers are already used (`tick_timer`). For v1, keep the
worker in the identity service:

- A 60-second interval scans `push_message` where `scheduledAt <= now` and
  `status='scheduled'`.
- Claim a row by atomically setting `status='sending'` (the reducer enforces the
  state transition).
- Send, then set `sent`/`partial`/`failed`.
- On process restart, rows stuck in `sending` older than 5 minutes are retried
  only if the idempotency key is preserved.
- Do not run duplicate workers: use the single identity process, or a DB claim.

Quiet hours: for campaigns, defer until the next allowed window in the
recipient's timezone where practical. If OneSignal handles per-user delivery
windows, prefer that over server-side fan-out complexity.

### 7.8 Account deletion and sign-out

- `account_delete` must also enqueue `push_subscription_disable` for all owner
  rows and call OneSignal's user-deletion endpoint (verify the current API)
  before clearing local rows.
- If OneSignal deletion fails, keep a tombstone row with `disabledAt` and retry;
  never resurrect the subscription.
- `account_sign_out` does not delete the subscription; the mobile app re-links it
  to the guest owner. Server-side, unlink `accountId` and set owner to
  `guest:<deviceId>` only after a valid guest registration.
- Guest deletion follows the same pattern if it is added later.

---

## 8. Admin app implementation (`../regun-admin`)

### 8.1 Navigation and page

Add a sixth destination to `Workbench`:

```
Notifications  (Icons.notifications_outlined)
```

Files:

```
lib/screens/notifications_page.dart        // list + composer + detail
lib/models/push_message.dart               // typed DTOs, validation
lib/widgets/audience_builder.dart          // reusable audience controls
lib/widgets/message_preview.dart           // device-preview card
```

Keep the existing responsive pattern: `NavigationBar` on narrow screens, side
rail on wide screens (`lib/screens/workbench.dart`).

### 8.2 Composer fields

| Field | Rule |
|---|---|
| Title | required, 1–60 characters, plain text |
| Body | required, 1–180 characters, plain text |
| Category | `security`, `events`, `leaderboards`, `reengagement` |
| Tap route | dropdown from allowlist; optional param validated |
| Audience | typed builder, never raw JSON/SQL |
| Schedule | immediate or date/time with server timezone displayed |
| Test | "Send test to me" always available before production send |

Preview must show exactly what the user will see, including the route label and
category consent requirement. Do not render HTML.

### 8.3 Audience builder

Controls:

- All reachable / Signed-in accounts / Guests only
- Platform: iOS, Android, or both
- Minimum app version
- Last seen within N days
- Inactive for at least N days
- Marketing opt-in required (forced for `events` / `reengagement`)
- Category preference match
- Optional specific account/device search (reuse `/admin/users` results)

Every change triggers an explicit "Preview audience" request; never show a stale
count as current. Display `truncated` prominently.

### 8.4 Safety rails

- Production sends require a second confirmation dialog and typing `SEND`.
- The server enforces daily campaign limits and per-admin rate limits; the UI
  surfaces the remaining quota.
- Scheduled messages can be cancelled until `status='sending'`.
- An immutable audit list shows actor, time, message id, audience summary, counts,
  and failure reason.
- No editing after a send starts; create a new message instead.
- If OneSignal is disabled/misconfigured, the page is read-only with the server's
  error, and local drafts remain available.

### 8.5 Connection handling

Reuse `AdminConnection.request()` exactly. Do not add a second HTTP client or
store the OneSignal key. The admin app never talks to OneSignal directly.

---

## 9. Platform setup (OneSignal dashboard and native projects)

### 9.1 OneSignal account/app

Create one OneSignal app per environment if staging needs isolation; otherwise a
single app with `staging`/`production` as tags is acceptable for v1. Recommended:
one app for production, one for development/testing.

Record:

- App ID → `ONESIGNAL_APP_ID` (server) and `--dart-define=ONESIGNAL_APP_ID`
  (client; app id is public).
- REST API Key → `ONESIGNAL_REST_API_KEY` (server only).
- Organization key is not needed for sending.

Do not enable email/SMS channels. Do not import player data into OneSignal.

### 9.2 iOS

1. In Apple Developer, enable **Push Notifications** for `dev.kiishi.regun`.
2. Create an APNs auth key (`.p8`) and upload it to OneSignal → Settings →
   Apple iOS. OneSignal supports both sandbox and production APNs.
3. In Xcode, enable the Push Notifications capability for the Runner target.
   Add Background Modes → Remote notifications only if silent/data pushes are
   needed (not required for visible alerts).
4. If rich media or confirmed delivery is required later, add a Notification
   Service Extension; not needed for v1.
5. TestFlight/App Store builds use production APNs; debug builds use sandbox.
   Ensure OneSignal has both configured.

### 9.3 Android

1. Create/select a Firebase project and register `dev.kiishi.regun`.
2. In Firebase, generate a service account JSON for FCM v1 and upload it to
   OneSignal → Settings → Android.
3. Handle `POST_NOTIFICATIONS`: OneSignal's SDK requests it on Android 13+ when
   `requestPermission` is called; declare it in the manifest if the chosen SDK
   version requires it.
4. Add a notification icon and accent colour that match Regun's palette. Android
   requires a white silhouette small icon; use the existing rook mark in the
   correct format.
5. Create a `regun_default` channel for campaign alerts and a `regun_security`
   channel for account/security notices so users can control them independently.
6. Release signing currently uses debug signing for private testing
   (`android/app/build.gradle`). Configure production signing before store
   rollout; FCM works regardless, but install identity must be stable.

### 9.4 macOS / web

Out of scope for v1. Do not initialise OneSignal, do not add entitlements, and do
not show mobile-only settings as broken. Revisit macOS push only after mobile is
stable.

---

## 10. Security, privacy, and compliance

### 10.1 Secrets

- `ONESIGNAL_REST_API_KEY` is server-only, stored in Dokploy runtime secrets,
  never in Git, logs, Flutter defines, admin local storage, or error messages.
- `ONESIGNAL_APP_ID` is public and may be compiled into the app.
- The admin app authenticates only with its existing session token.
- Do not proxy arbitrary OneSignal endpoints from the admin; expose typed routes.

### 10.2 Data minimisation

- Push payloads contain only `route`, `routeParam`, `messageId`, `category`.
  Never include email, username, account UUID, purchase details, or tokens.
- Server logs exclude message bodies, subscription ids, and recipient lists.
- OneSignal tags contain pseudonymous ids and coarse attributes only.
- Do not upload the Regun user database to OneSignal.

### 10.3 Consent

- OS permission is necessary but not sufficient. The app master switch and
  category preferences must also be respected server-side.
- Promotional categories require `identity_account.marketing = true` for
  signed-in accounts. This reuses the existing email marketing flag; the UI copy
  must say it covers both email and push.
- Transactional/security messages are sent only when required for account safety
  or a purchase the user initiated.
- Guests receive no promotional pushes.
- A denied OS permission is final until the user changes it in system settings;
  do not repeatedly prompt.

### 10.4 Deletion and export

- Account deletion removes `push_subscription`, `push_preference`, and any
  `push_delivery` rows, and calls OneSignal's user deletion.
- Add a privacy-policy line covering push identifiers, OneSignal as a processor,
  and how to disable notifications.
- Keep an audit tombstone only as long as required for abuse/security; do not
  retain the subscription id after deletion.

### 10.5 Abuse and safety

- Rate-limit registration, preference writes, test sends, and campaign sends.
- Validate all text for length and control characters; reject newlines in title.
- Never allow admin-supplied HTML, URLs, or arbitrary deep links.
- Cap test sends per admin per hour.
- Frequency cap: at most N campaign pushes per player per day/week; server-side.
- Deduplicate by `owner` for campaigns so multi-device players get one push.
- `collapse_id` for replaceable categories (e.g. leaderboard reset).

### 10.6 Store policy

- iOS requires a clear opt-in and an in-app way to reach notification settings.
- Do not use push for solely promotional content without consent.
- Android 13+ runtime permission must be requested in context.
- Include notification handling in the App Store privacy answers (identifiers,
  usage data if analytics are enabled).

---

## 11. Testing and verification

### 11.1 Mobile

| Test | Expected |
|---|---|
| Fresh install, no permission | No prompt on first frame; game starts; Settings shows "Not enabled" |
| Enable from Settings | OS prompt appears; subscription reported; server row created |
| Deny OS permission | Settings shows system-settings guidance; no repeated prompt |
| Guest → account sign-in | `external_id` switches; server row re-linked; old guest alias has no subs |
| Sign out | `external_id` returns to guest; account pushes stop on that device |
| Account switch | New account receives; old account stops |
| Delete account | Server rows removed; OneSignal user deleted; no further pushes |
| Cold-start tap | App opens correct screen after splash, no crash |
| Warm-start tap | Correct screen; no duplicate navigation |
| Tap during active run | Notification is suppressed or queued; run is not interrupted |
| Unknown route | Home opens; no error dialog |
| Offline registration | Game unaffected; retry succeeds later |
| Desktop/web launch | No OneSignal plugin call, no crash |
| iOS sandbox + production build | Both receive a test push |
| Android 13+ | Permission prompt and notification channel behave correctly |

### 11.2 Server

- Unit tests for validation (subscription payload, preferences, audience,
  message text, route allowlist).
- Mock OneSignal client tests:
  - success with `id`
  - 200 with falsy `id` and errors
  - 4xx no retry
  - timeout/5xx one retry with the same idempotency key
  - chunking >20,000
  - partial failure aggregation
- Audience tests: marketing consent, category opt-out, deleted account, disabled
  subscription, multi-device dedupe, quiet hours.
- Account deletion test: rows removed and OneSignal delete called.
- Admin auth tests: unauthenticated 401, expired session, rate limit.
- `npm run verify` in `identity/`; root `npm run verify` for module build/tests.

### 11.3 Admin app

- Widget tests for composer validation, audience preview states, send
  confirmation, cancel, and error rendering.
- Golden/compact layout checks at narrow and wide widths.
- Test send only ever targets the configured test subscription.
- No OneSignal key is present in the admin binary; verify with a string scan.
- `make verify` in `../regun-admin`.

### 11.4 End-to-end acceptance

A release is not "done" until all of these pass on a physical iOS device and a
physical Android device:

1. A real account signs in, grants permission, and receives a security push.
2. A guest receives a guest-safe notification.
3. A campaign sent from Regun Admin arrives with the correct title, body, and
   tap destination.
4. Opting out in-app stops campaigns but not mandatory security messages.
5. Deleting the account stops all delivery and leaves no rows.
6. The OneSignal dashboard shows the expected audience and delivery counts.

---

## 12. Rollout plan

### Phase 0 — Decisions and accounts (0.5 day)

- Confirm OneSignal plan, app strategy (one vs per-environment), and owner.
- Confirm consent model: does the existing `marketing` flag cover push?
- Confirm which transactional events ship in v1.
- Create OneSignal app(s), APNs key, FCM service account.
- Add server env placeholders; no code path enabled.

**Exit:** credentials exist in the secret manager; `ONESIGNAL_ENABLED=false`.

### Phase 1 — Mobile plumbing + server registry (2–3 days)

- Add `onesignal_flutter`; `PushService`, `PushApi`, platform guard.
- Add `push_subscription` / `push_preference` tables and reducers.
- Add `POST/DELETE /notifications/subscription`,
  `GET/POST /notifications/preferences`.
- Add Settings Notifications section; permission flow.
- Add server config and `onesignal.ts` (unused by admin yet).
- Ship behind a client flag if needed (`--dart-define=PUSH_ENABLED=true`).

**Exit:** test devices register, rows appear, preferences persist, sign-out/delete
behave, desktop unaffected, `make verify` passes.

### Phase 2 — First transactional send (1–2 days)

- Implement one event end-to-end (account verified / welcome).
- Add `push_message` outbox and worker.
- Add test-send endpoint and a minimal admin Notifications page with test send
  and history (read-only).
- Verify iOS sandbox + production and Android.

**Exit:** a real sign-in produces one notification on a physical device; audit
row exists; failure is visible and retry-safe.

### Phase 3 — Admin campaigns (3–4 days)

- Full composer + audience builder + preview.
- Schedule/cancel, production confirmation, quota display.
- Audit list and detail view.
- Add event triggers for purchases and leaderboard notices.
- Add frequency cap and quiet hours.

**Exit:** a controlled campaign to an internal test segment succeeds; opt-outs are
respected; counts match OneSignal; no PII in payloads.

### Phase 4 — Limited production (1 week)

- Enable for a small real segment (e.g. staff/test accounts, one platform).
- Monitor delivery, error rate, opt-out rate, support reports.
- Fix issues; then widen to all users.

**Exit:** 7 days without delivery incidents; documented rollback (disable
`ONESIGNAL_ENABLED`, stop worker).

### Phase 5 — Re-engagement and seasonal (later)

- Inactivity segments, scheduled campaigns, boss/event reminders.
- Requires explicit product approval and a measured opt-out baseline.

---

## 13. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| OneSignal SDK breaks desktop/web build | Game cannot build | Platform guard; do not add the plugin to desktop targets if it cannot compile; verify all targets in CI |
| APNs/FCM misconfiguration found only at release | Silent no-delivery | Test on physical devices in phase 1; check OneSignal Subscriptions and logs |
| Permission prompt too early | Low opt-in | Contextual prompt after value is clear; never on first frame |
| Push used for spam | Opt-out, store complaints | Category consent, frequency caps, marketing flag, small initial rollout |
| External id mismatch after account switch | Wrong user gets a push | Explicit login/logout matrix; server derives account id from bearer |
| Duplicate sends on retry | User annoyance, bad audit | One idempotency key per chunk; state transition claim |
| Large campaign fan-out | Timeouts, partial delivery | 20k chunking, bounded concurrency, aggregate status, resumable rows |
| Admin sends wrong audience | Reputational harm | Preview count, typed confirmation, test send, audit, daily caps |
| Account deletion leaves data at OneSignal | Privacy breach | Explicit deletion endpoint + tombstone + retry; document in privacy policy |
| Clock/timezone bugs in scheduling | Sends at 3am | Store UTC; display server timezone; quiet-hours enforcement |
| OneSignal outage | No notifications | Fail soft; account and game continue; surface server error in admin only |
| Subscription id spoofing | Cross-account noise | Guest secret proof, bearer-derived account id, rate limits |

---

## 14. Open decisions

These should be resolved before phase 1 implementation. Recommendation in bold.

1. **Consent flag:** reuse `identity_account.marketing` for promotional push, or
   add a separate `pushMarketing` flag?
   **Recommendation:** add a separate field/table preference for push, but
   require both for promotional categories until the UI copy is updated.
2. **Guest promotional push:** allow after explicit opt-in, or never?
   **Recommendation:** never in v1; guests get only transactional/local-value
   messages.
3. **OneSignal app strategy:** one app for all environments, or separate dev/prod?
   **Recommendation:** separate production and development apps.
4. **Admin notification ownership:** single admin (current model) or multi-admin
   roles? **Recommendation:** single admin for v1; audit already records actor.
5. **Rich notifications / images / action buttons:** needed for v1?
   **Recommendation:** no; text + tap route only.
6. **In-app inbox:** store a feed of notifications in the app?
   **Recommendation:** defer; OneSignal history is not a product inbox.
7. **Scheduled campaigns vs server events:** should `push_message` own both?
   **Recommendation:** yes, one outbox table with `kind`.
8. **Web/macOS push:** ever? **Recommendation:** defer until mobile is stable.
9. **Localization:** is multilingual push required?
   **Recommendation:** English only in v1; OneSignal supports language maps later.
10. **Analytics:** use OneSignal stats only, or mirror events to Regun?
    **Recommendation:** OneSignal stats for delivery; Regun audit for sends.

---

## 15. File-level change map

### Mobile (`../regun`)

| File | Change |
|---|---|
| `pubspec.yaml` | add `onesignal_flutter`; add asset/icon if needed |
| `lib/main.dart` | initialise `PushService` before `runApp`; flush queued tap after first frame |
| `lib/services/push/push_service.dart` | new: SDK init, identity login/logout, subscription observer, permission state |
| `lib/services/push/push_api.dart` | new: registration/preferences HTTP with guest credential |
| `lib/services/push/push_router.dart` | new: allowlisted route mapping + cold-start queue |
| `lib/services/push/push_preferences.dart` | new: local preference state |
| `lib/services/account/account_controller.dart` | call `PushService.syncIdentity()` after verify/attach/signOut/delete |
| `lib/views/settings_view.dart` | add Notifications section |
| `lib/widgets/account_settings.dart` | optional: notification status near account |
| `android/app/src/main/AndroidManifest.xml` | notification permission/icon/channel metadata as required |
| `ios/Runner/Info.plist` / Xcode project | Push Notifications capability; APNs environment |
| `test/` | unit/widget tests for push service, router, preferences |
| `integration_test/` | device-level registration and tap routing (where feasible) |

### Server (`../regun-server`)

| File | Change |
|---|---|
| `identity/.env.example` | add OneSignal variables |
| `identity/src/main.ts` | construct `PushService`/worker; wire into `identityServer` |
| `identity/src/http.ts` | add client notification routes before token branch |
| `identity/src/admin.ts` | add `/admin/notifications/*` routes |
| `identity/src/onesignal.ts` | new: bounded OneSignal REST client |
| `identity/src/push.ts` | new: registry, consent, audience, send orchestration |
| `identity/src/push_events.ts` | new: transactional triggers |
| `identity/src/push_admin.ts` | new: admin handlers (or keep in `admin.ts`) |
| `spacetimedb/src/schema.ts` | register `push_subscription`, `push_preference`, `push_message` |
| `spacetimedb/src/push.ts` | new reducers and validation |
| `spacetimedb/src/identity.ts` | hook delete/sign-out cleanup |
| `deploy/ACCOUNTS.md` | document OneSignal env, APNs/FCM, rollback |
| `identity/test/push*.test.ts` | new tests |
| `docs/IMPLEMENTATION_STATUS.md` | record scope and verification evidence |

### Admin (`../regun-admin`)

| File | Change |
|---|---|
| `lib/screens/workbench.dart` | add Notifications destination/header/title |
| `lib/screens/notifications_page.dart` | new: list, composer, detail, audit |
| `lib/models/push_message.dart` | new: DTOs, validation, audience model |
| `lib/widgets/audience_builder.dart` | new |
| `lib/widgets/message_preview.dart` | new |
| `lib/services/admin_connection.dart` | no new transport; reuse `request()` |
| `docs/IMPLEMENTATION_STATUS.md` | record scope/verification |

---

## 16. Immediate next steps

1. Review this plan and settle the open decisions in section 14.
2. Create the OneSignal app(s) and upload APNs/FCM credentials; store the REST
   key in the server secret manager only.
3. Implement phase 1 (mobile plumbing + server registry) behind
   `ONESIGNAL_ENABLED=false`.
4. Test on one physical iOS device and one physical Android device before any
   admin UI work.
5. Then implement one transactional send end-to-end, followed by the admin
   composer.

**Definition of done for the first shippable slice:** a real signed-in player on
a physical device receives one account-security notification, the server has an
audit row, the player can disable it in Settings, account deletion removes the
subscription, and no OneSignal secret exists anywhere in the mobile or admin
builds.
