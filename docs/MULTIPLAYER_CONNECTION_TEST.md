# Online connection and movement test

20 October 2026. This is the first Flutter networking slice, not completed multiplayer combat. Solo Play, Continue, Training and profile rewards retain their existing simulation and saves.

## Try it

1. Choose **Online** on the main menu. The next screen says **connection test**.
2. Enter a player name and create a Co-op or Versus room. Copy its ten-character code to a friend running this build. They enter their name and choose Join room.
3. Co-op uses Breach or Foundry with two or three total players, host included. Versus supports 1v1, 2v2 and 3v3 room sizes with balanced teams. Its current arena is an internal movement fixture, not one of the planned PvP maps.
4. Versus defaults to Enemies On; the host can choose Off. This records the intended rule only: no enemies spawn in the movement test.
5. Everyone selects Ready. Co-op requires at least two ready, connected players; Versus requires both teams filled. The host chooses Start movement test.
6. Move, aim and dash with the sticks and aiming-thumb Dash button. Desktop also accepts WASD/arrows and Space. Firing and reload are intentionally absent while authoritative combat is unfinished.
7. Leave returns to Online. Back disconnects; an existing room slot is recoverable for up to 30 seconds by returning to Online in the same app process.

The top HUD shows every player's application round trip in milliseconds: Good below 100, Fair from 100–199, Poor at 200 or more. Labels accompany color. Measuring, Stale (no new sample for three seconds) and Offline are separate states. Freshness uses local elapsed time, avoiding phone/server wall-clock differences. This sample includes server processing and subscription/ack delivery; it is not a raw socket-only ping.

## Connection and safety contracts

- Direct TLS WebSockets to `regunserver.kiishi.space`, database `regun`; override the host at build time with `REGUN_SERVER_HOST` for another TLS deployment.
- Pinned community Dart SDK/generator `spacetimedb: 1.3.0`; server/official TypeScript tooling remains 2.12.0. Generated BSATN preserves Int64 IDs rather than converting IDs through floating point.
- Subscriptions only request `my_room`, `room_members`, `my_probe`. Backing room/member/session/timer tables stay private. Identity and reducer authorization remain server-owned.
- Codegen fetches the public named V9 schema route directly. It filters server-only tables/lifecycle reducers, fixes the identity-scoped singleton probe cache key, and disposes failed connections. These adaptations are reproducible in `tool/multiplayer/generate.dart`.
- Tokens and view caches remain in process memory. No JWT is written to preferences or disk. Force-quitting loses this test identity. Durable identity needs secure platform storage before the production account flow.
- No offline storage, optimistic game state or mutation replay. Reconnect replaces the client, subscribes afresh and adopts the server generation; old movement/action sequences are cleared. Automatic retries are bounded to 25 seconds. Backgrounding disconnects and neutralizes input; foregrounding reconnects.
- Bounds/obstacles are exported from the same Tiled source as the server. Protocol, map ID and source hash must agree before input/start is allowed. Export again after authored geometry changes and update both repositories together.
- Online rendering is isolated from `RegunGame`: it never runs a local enemy director, damage, XP, supply rewards, profile settlement or checkpoint writer. Positions are authoritative with display interpolation. Local movement prediction/reconciliation is not implemented yet; latency will be perceptible.

## Reproduce checks

```sh
python3 tool/multiplayer/export_geometry.py
dart run tool/multiplayer/generate.dart
dart format lib/multiplayer/generated lib/multiplayer/geometry.dart
make verify
dart run tool/multiplayer/smoke.dart
flutter drive --profile --publish-port \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/online_transport_test.dart -d <iphone>
```

The live smoke creates disposable identities/rooms on the configured host, checks two-player co-op movement/probes/reconnect and 1v1/2v2/3v3 lobby/start paths, then leaves/closes them. If wireless VM-service discovery stalls, run `flutter run --release --target=integration_test/online_transport_test.dart -d <iphone>` and retrieve `Documents/regun-online-smoke.json` from the app container with `xcrun devicectl device copy from`. The report contains status/check names and no credentials. The native test temporarily installs a test entry point; restore the regular release with `make runRelease DEVICE=<iphone>` afterwards. Tests do not award profile rewards. Automated native transport evidence does not prove multiplayer comfort, physical performance, audio, or combat balance. Android acceptance remains separate.

## Verification recorded

`make verify`: analyzer clean, 175 tests passed, four opt-in long simulations skipped. The hosted Dart smoke passed co-op movement/probes/reconnect and every PvP room size. The same checks passed in an actual iPhone release build on 20 October 2026; its [sanitized on-device report](evidence/ONLINE_IPHONE_2026-10-20.json) is retained here. Small-phone UI tests cover six-player lobbies, enlarged text, shared arena art and mirrored move/dash touch controls. Probes only run for room members; server validation rejection is not treated as connection loss.

This does not complete M1: Android release, wider lifecycle/network-loss and protocol fixtures, production identity, two-device feel/performance and the full acceptance matrix remain open.

## Still required by the approved plan

Authoritative four-weapon combat, health/death, enemies/bosses, progression/fusions, shared supply drops and per-player receipts; full co-op survival; competitive scoring/respawns/results; two complete covered PvP maps plus the third candidate and format variants; modular wall art; local prediction/reconciliation and latency/loss testing; secure durable identity; Android/native lifecycle/release acceptance. All three PvP team sizes remain part of this implementation pass. No scope is deferred by this movement fixture.
