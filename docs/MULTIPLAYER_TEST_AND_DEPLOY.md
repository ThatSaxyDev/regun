# Multiplayer private-test build — 21 October 2026

Regun remains 1.0.0+7. The client and independent sibling TypeScript server must be delivered together. This is private invite-room multiplayer. Ranked play, public matchmaking, OIDC/cross-device account recovery and physical balance approval are separate release gates.

## Play

Open **Online**, enter a name, then create or join using the ten-character room code. Co-op needs two or three total players and uses Breach or Foundry. Choose weapon/survivor before marking Ready. Any change clears readiness. Every participant must be ready before the host starts.

Versus supports 1v1, 2v2 and 3v3. Choose Ossuary Cross or Ironworks Relay; the format selects its separately authored layout. All four weapons are equally available; competitive survivors use Rook. Enemies start On and the host can choose Off before readiness. Enemy types are fixed by the server. Win three rounds; elimination resolves a round, 90 seconds starts overtime, and at 105 seconds remaining normalized team health breaks the tie. Equal health draws; three draws end the match. Leave during a live Versus match forfeits the team. These rules need hands-on fairness review.

Use movement/aim sticks; aim fires. Dash/Reload remain beside the aiming thumb and mirror with handedness. Desktop uses WASD/arrows, F to fire along the last aim, R reload, Space dash, Escape menu. The menu stops local input while the shared match continues. Backgrounding disconnects and retries on return. Reconnect slots last 30 seconds; bodies remain vulnerable. Expiry forfeits competitive play; a remaining co-op player can finish alone, clearly labeled in the HUD. Arbitrary late joins are not allowed.

Shared XP grants personal funded choices; the world holds during the bounded 15-second team picker. Ordinary overflow waits four active seconds and a later pickup. Fuse banked cores explicitly when recipes are available. A downed friend has 20 seconds: get within 105 units and hold Revive for three uninterrupted seconds. Damage, distance or stale input cancels progress. A bled-out teammate spectates a living teammate and can return after a boss defeat. All downed ends the run.

Breach has the same timed supply pods as solo. One living connected friend in the 220-unit field captures at the normal rate; multiple friends do not accelerate it. The HUD points toward the pod. Each participant receives one personal non-XP entitlement when the server accepts capture. Foundry has no supply pods. Versus has neither survival XP nor supplies.

Top chips show server-validated application round-trip time and Good/Fair/Poor text/color. This includes server/subscription processing, not pure network travel. Guests persist in native Keychain/Keystore; web guests last for the process. Online results/scrap are a separate authoritative ledger; solo balances are not uploaded or merged. Private PvP is unrated. Reinstall/lost device has no linked-account recovery yet.

## Local verification

From the client: `make verify`. `flutter test integration_test/online_identity_test.dart -d DEVICE` checks native storage. `integration_test/online_combat_test.dart` exercises combat against a local published database; pass the three defines below. The simulator can reach laptop loopback; a phone requires the HTTPS hosted endpoint.

From the sibling server:

```sh
npm ci --prefix spacetimedb
npm start
spacetime publish regun-dev --server http://127.0.0.1:3100 --module-path spacetimedb --yes
npm run bindings
npm run verify
REGUN_DATABASE=regun-dev npm run smoke
npm --prefix spacetimedb run smoke:combat
npm --prefix spacetimedb run smoke:survival
REGUN_PARTY_SIZE=3 REGUN_ARENA=foundry npm --prefix spacetimedb run smoke:survival
npm --prefix spacetimedb run smoke:maps
```

Use disposable local state, never run these mutating test rooms against production. Local clients:

```sh
dart run --define=REGUN_SERVER_HOST=127.0.0.1:3100 --define=REGUN_DATABASE=regun-dev --define=REGUN_SERVER_TLS=false tool/multiplayer/smoke.dart
flutter run --debug --dart-define=REGUN_SERVER_HOST=127.0.0.1:3100 --dart-define=REGUN_DATABASE=regun-dev --dart-define=REGUN_SERVER_TLS=false -d DEVICE
```

`tool/multiplayer/latency_proxy.py` supplies ordered TCP delay/jitter for local WebSockets. It does not simulate packet loss, cellular transitions or physical latency perception. Report its configured nominal delay separately from observed application RTT.

Regenerate maps with `python3 tool/multiplayer/author_maps.py`, `python3 tool/multiplayer/export_geometry.py`, then sibling `python3 tool/export_maps.py`. Commit Tiled sources/JSON/Dart/TS together. `test/fixtures/multiplayer_combat.json` and sibling `shared/combat_contract.json` are byte-identical fixtures independently checked against each language's live contracts.

## Dokploy update

The root Dockerfile, main branch, root build context, port **3000**, HTTPS domain `regunserver.kiishi.space` and persistent **/var/lib/regun** volume remain correct. **No required new environment variables.** Keep the database name `regun` and its existing state/keys/CLI ownership. Do not delete/recreate the volume or expose container port 3001.

Before updating, stop admissions/let private rooms finish and make a consistent backup of the entire persistent volume (stop this application before copying its state). Preserve keys and CLI identity as well as database data. Record the prior image tag and server/client commit IDs. Deploy main through Dokploy. Startup publishes additively with `--delete-data=never`; it must fail instead of erasing data on an incompatible schema. Wait for healthy status, then check `/health` and the public named schema. Confirm combat, scene and personal-result views exist; use the matching client build to create a fresh private room.

The current change adds private combat, fighter, projectile, scene, simulation, match-record, account and result tables; existing movement table layouts remain compatible. Old clients can keep movement-only rooms; new clients require a complete combat schema before subscribing. Existing active multiplayer games are not migration-safe: finish/drain them before update. A callback gap over five seconds explicitly ends an active game as interrupted with no reward, rather than fast-forwarding damage; a service restart is not a saved-run continuation guarantee.

If publication/health fails, keep the volume intact and inspect logs. An older module cannot necessarily remove the new tables; restoring the previous image alone is not a validated schema rollback. Restore the stopped application from the matching full-volume snapshot together with its matching image/client, or roll forward with a compatible repair. Rehearse restore on an isolated named volume before public rollout. No live VPS changes were made by this implementation pass.

## Acceptance boundaries

Automated results are recorded in the implementation ledger. Required hands-on review remains: both party sizes, every map/format with enemies On/Off, attack visibility, wall/muzzle clipping, weapon tradeoffs, downed/revive, supply handoff, foreground/phone interruptions, touch comfort, sustained frame/memory/thermal behavior, sound and real WAN disconnects. Two simultaneous six-player local rooms are a bounded integration exercise, not a 128-room capacity claim. Default room admission is capped at 128; this is a safety bound, not a measured deployment capacity. No server rewind or lag compensation is claimed; hits use the current authoritative swept simulation. The maps intentionally have no stealth fog: walls block damage, actors within the same room are replicated. All devices see a fixed 1500×700 competitive playfield.
