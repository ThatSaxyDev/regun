# Build 11: remote online-play switch

Current app identity: **1.0.0+11**. Build10 and earlier have no remote menu policy.
Build11 includes the multiplayer implementation; availability comes from the server.
There is no app build-time Online On/Off flag to remember.

## Operator control

After the one-time server update, set this **runtime environment variable** on the
Regun server application in Dokploy:

```env
REGUN_ONLINE_PLAY_ENABLED=false
```

- `false`: Online remains grey/Coming soon and new multiplayer connections receive503.
- `true`: Online opens co-op/Versus and new multiplayer connections are accepted.

Save the environment and restart/redeploy the **server application** to apply it.
Do not rebuild or replace the phone app. The default isfalse; any other nonempty
value is rejected at startup. Changing environment requires a server restart and
can interrupt live matches, so let current rooms finish first.

The server must retain the same named storage mounted at `/var/lib/regun`. This
folder holds multiplayer state, guest-signing keys and publisher ownership. Never
replace it with an empty volume to perform this update. See the sibling backend's
`docs/GUEST_IDENTITY_PERSISTENCE.md`. The actual production mount is still unverified;
the new server configuration has not been pushed/deployed by this pass.

## How the installed app follows it

`GET https://regunserver.kiishi.space/features` returns, for example:

```json
{"schemaVersion":1,"onlinePlay":false}
```

This endpoint is public, has no player identity/credentials and sends no-store
headers. The application checks without blocking Play, Settings or other solo
navigation. It refreshes on Home entry/return, foreground resume, every30seconds
while Home is visible and immediately before opening Online. After the server is
healthy, allow up to30seconds on an already-open Home; foregrounding also rechecks.

Unknown, failed, timed-out or malformed policy cannot enable Online. No enabled
value is stored across app launches. A short inline Checking label is confined to
the Online action. Pending checks leave solo controls/semantics usable. Turning the
flag off blocks fresh connections at nginx too, including older clients that ignore
this endpoint. It is an availability switch, not a replacement for authentication.

Direct in-game matches are not governed by a Home polling overlay. Normal network/
reconnect rules remain; changing server environment can itself restart those games.

## Verification / delivery boundaries

Client tests cover on/off/on with the same service, strict schema/type validation,
HTTP/malformed failures, stale-enabled failure closure, timeout, request coalescing,
disposal and non-blocking Home. `make verify` passes267 tests/five skips with analyzer
clean. Server feature checks exercise the production nginx template against an
isolated upstream: both boolean values, no-store headers, identity/subscription
admission, health and blocked admin routes. Invalid environment values fail.

Container continuity additionally cyclestrue→false→true on the same local named
volume and reconnects the original in-memory guest token. Production storage or
rollout is not established by these local checks. There is no claim that the public
endpoint currently supports this switch until the matching backend is deployed.
