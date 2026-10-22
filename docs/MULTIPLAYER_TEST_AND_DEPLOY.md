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

## Prediction protocol update — 21 October 2026

The movement-response pass adds the private `motion_state` table, owner-scoped `my_motion` view and `queue_motion` / `stop_motion` reducers. It leaves existing member/room layouts and `submit_input` intact for old clients. New clients enable prediction only when all three capabilities exist. Publish the matching sibling server source before evaluating predicted movement against the public endpoint. Until then the new client deliberately uses the legacy authoritative presentation; improved controls/auth recovery still work.

Commands contain authenticated room/generation, sequence, bounded movement/aim and dash edge only. Neither duration, speed, position nor damage comes from the client. Receiving a command does not acknowledge motion. Each server callback consumes at most one 50ms step, with a maximum 12-command queue; stale input is discarded and acknowledged as dropped. The snapshot identifies the last applied/dropped sequence and simulation tick, position, dash state and server-owned speed/cooldown. The client renders its bounded replay after that acknowledgement, interpolates remote players, and constrains corrections through shared cover/body rules. Menus send a stop request; reconnect/death/shared choice and epoch changes reset prediction. No shot rewind or hit prediction is added.

Run `npm run verify`, generate local test bindings with `npm run bindings`, then `npm --prefix spacetimedb run smoke:prediction`. From the client, opt into the disposable local connection check:

```sh
flutter test --no-pub test/live_prediction_test.dart --dart-define=REGUN_LIVE_PREDICTION=true --dart-define=REGUN_SERVER_HOST=127.0.0.1:3100 --dart-define=REGUN_DATABASE=regun-dev --dart-define=REGUN_SERVER_TLS=false
```

Use `tool/multiplayer/latency_proxy.py` on ports3101/3102 with50/100ms one-way delay and10/15ms jitter; add `REGUN_DELAYED=true` and the corresponding host to the live test to require motion before server echo. These proxies preserve TCP ordering and do not simulate radio conditions or packet loss. `integration_test/online_prediction_test.dart` repeats the touch/dash/pause test natively against that local delayed endpoint; use `test_driver/prediction.dart` to retain its screenshot. Routine/local smoke tests must remain local. Explicitly authorized hosted playtests below use fresh guests and disposable private rooms.

Connection diagnosis now distinguishes a rejected saved guest (`SpacetimeDbAuthException`) from service/transport/preparation problems. A rejected credential stops automatic retries. The explicit Start new guest action warns about online-record access, archives the rejected credential only in secure storage, clears the active token and reconnects. Solo progress is untouched. `integration_test/online_connection_diagnostic_test.dart` checks the actual saved identity without changing it, then tests rejection/recovery/reconnect using an isolated in-memory guest. Tokens must never appear in reports. A rejected credential does not by itself establish server key rotation or an expiry cause.

Deployment still requires the full-volume/key backup and drained-room procedure above. Keep `/var/lib/regun` and signing keys; publish additively with `--delete-data=never`. No runtime/public-schema migration or production rollout has been performed by the local tests.


## Authorized hosted verification — 21 October 2026

The creator authorized testing against the newly deployed server and pushing backend main for automatic deployment. Backend `8f54d71` published the prediction protocol; `afa88a8` reduces replication by keeping command receipt private and returning `queueLength` instead of the buffered commands in owner acknowledgements. Public health returned HTTP 200. Existing persistent data/keys were not reset.

`integration_test/hosted_online_test.dart` and `hosted_party_test.dart` require `REGUN_HOSTED_PLAYTEST=true` and the exact public host/database. They create fresh in-memory guests and private rooms, then leave/close in `finally`. They do not replace the saved guest. These are native debug simulator exercises; multiple SDK clients in one simulator process do not establish independent-device, cellular, release-frame-time or physical comfort acceptance.

The first hosted 1v1 run passed room/roster/ready, actual stick touch, stop/dash convergence, authoritative fire/reload, grenade inventory, 12-second reversals, menu stop/resume and same-guest reconnect. First local movement was 27ms, server movement 282ms; stopped error was zero, maximum pending inputs seven, no sampled stalls, application RTT 173/164ms. Larger parties exposed queue-cap hitches: initial 2v2 had one stalled sample/160 and 3v3 had 15/240. A cadence-pacing rerun reduced 3v3 to three/240 but still failed, with RTT spikes up to 797ms. These failures prompted compact acknowledgements, removal of receipt-time room-wide member updates, and coalescing client row refreshes. See the retained validation reports for the subsequent deployment run.

Prediction now follows observed server tick cadence and queue occupancy, keeping the 12-command bound rather than extending speculative movement indefinitely. Model tests exercise 20Hz and slower callbacks at 300ms RTT. Client verification: analyzer clean, 227 tests passed/five skipped. Backend verification: 77 tests, typecheck/build, and local prediction smoke passed, including compact owner payload checks.

The corrected compact-payload run passed all four scenarios: co-op three/Breach and two/Foundry (four active seconds each), 2v2/Ironworks Relay and 3v3/Ossuary Cross (ten seconds each). All 480 sampled client intervals had no input-cap stalls; maximum pending inputs were 11/11/11/10, and every final stopped error was zero. Compact acknowledgements were confirmed in each scenario. Recorded application RTT ranged 152–465ms. This short run is regression evidence, not a claim that latency spikes are eliminated. The first refresh-coalescing attempt exposed a room-creation ordering regression; commands now synchronously refresh cached room state on completion before dependent setup runs, and the corrected hosted run passed. Reports are in `docs/validation/online-*-2026-10-21.json` and include the earlier failed queue tests.

Final 1v1 touch/reconnect regression against the compact deployment also passed: local movement23ms/server255ms, zero stalls over12 seconds of reversals, maxpending8, exact stopped convergence and successful same-guest reconnect. Both test guests left their room. See `docs/validation/online-final-1v1-2026-10-21.json`.
