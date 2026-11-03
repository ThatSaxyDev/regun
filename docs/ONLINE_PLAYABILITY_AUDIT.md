# Multiplayer playability audit — 3 November 2026

Regun's online play has two compounding weaknesses. A small PvP match can feel
wrong because the local player, remote players, shots and hit checks operate
at different times. Co-op adds a much larger continuously changing data feed,
while most enemies are still drawn at raw received positions. Neither failure
requires sending graphics. The affected friend's match has no captured
timeline, so the exact trigger for its stalls and misses remains unknown.

This audit covers client `57ff28a` and sibling server `8fe6fa5`. The hosted
service is measured separately. A public schema and a successful subscription
cannot establish which server commit is deployed or how a real match performs.

## Earlier investigation

The closest existing records are [the latency plan](ONLINE_LATENCY_PLAN.md),
[the projectile presentation investigation](ONLINE_PROJECTILE_PRESENTATION.md),
and [the multiplayer test ledger](MULTIPLAYER_TEST_AND_DEPLOY.md).
They already found input queue stalls, uneven delivery and raw 20 Hz projectiles.
The fixes added bounded local prediction, compact acknowledgements, adaptive
remote player interpolation and cosmetic projectile prediction. Keep those gains.

The [earlier hosted 1v1](validation/online-final-1v1-2026-10-21.json) showed
23 ms to local movement, 255 ms to authoritative movement, 163–176 ms application
RTT and perfect final stop convergence after 12 seconds of reversals. That
proves the particular session eventually agreed. It leaves the difference
between on-screen and server positions during the exchange open. Prediction
lead reached 83 units. The earlier latency plan also records a **481 ms
acknowledgement gap** and six stalled samples in one 3v3 trial. A clean rerun
did not erase that failure. Historical hosted co-op cases exercised only four
active seconds each. The recent navigation transport check used local clients
and a test identity shim. None is a sustained, independent-device WAN acceptance
test with crowded late co-op, full combat, or actual account renewal.

Team Versus already exposed scale problems in the archived runs. The initial
2v2 test recorded one stalled sample in 160. The initial 3v3 recorded 15 in
240. A paced 3v3 rerun still hit the 12-command limit and recorded three
stalls, with one application RTT sample at 797 ms. The later compact payload
run completed ten seconds in both team formats without sampled stalls.
[Test ledger](MULTIPLAYER_TEST_AND_DEPLOY.md) ·
[Paced 3v3](validation/online-paced-six-2026-10-21.json) ·
[Compact payload rerun](validation/online-compact-party-2026-10-21.json)

## What goes over the connection

The Flutter client keeps one ordered SpacetimeDB WebSocket. It subscribes to
room, roster/poses, own movement, fighters, combat, projectiles, scene, probes
and account/results. The player sends a sequence, bounded movement and aim,
and a dash sequence about every 50 ms. The raw queue-motion arguments are 64
bytes before protocol overhead (four u64 and four f64 fields). Fire/reload,
grenade, upgrade and revive travel in separate authenticated reducers. The
socket carries results and subscription changes. It does not carry sprites,
video, level art or textures.

The server's global scheduled reducer steps rooms at nominal 50 ms. It writes
room tick/time, player poses and movement acknowledgements, match state,
fighters and changed projectile/scene rows. A changed row can include a
complete JSON object inside a binary protocol. Co-op reads persisted scene
JSON back into the simulation, writes changed entities back, and projects
enemy rows through a scoped view that parses and serializes again. Non-enemy
scene rows are returned as stored. Fighter and projectile views expose their
row data rather than a compact presentation-only projection. Enemy age alone
changes the row even when an enemy is planted. Each subscriber receives its
room, including enemies outside the current camera. This is row replication,
not a delta of just the position fields within a JSON string.
([SpacetimeDB subscriptions](https://spacetimedb.com/docs/clients/subscriptions/))

### Fresh measurements

| Eight-second local window | 1v1, enemies off | Three-player co-op, 37 enemies |
|---|---:|---:|
| Median scene JSON in client cache | 0 B | 12,664 B |
| Median fighter JSON in client cache | 1,110 B | 3,039 B |
| Moving player's receive rate | 30.6 kB/s | 152.4 kB/s |
| Idle peer receive rate, each | 11.5 kB/s | 132.1 kB/s |
| Moving player's send rate | 1.69 kB/s | 1.69 kB/s |
| Approximate aggregate room receive traffic | 42 kB/s | 417 kB/s |

These are TCP stream bytes at a loopback relay, including WebSocket/protocol
framing, excluding TCP/IP headers and TLS. One player sent movement at roughly
17.6 Hz, the other clients were idle, and no one fired. The test used the
existing temporary SpacetimeDB module with test account stubs and staging
reducers, the generated TypeScript SDK with Brotli requested, and the same
server sources. The shipped Dart SDK uses a different wire protocol version
and its own compression handling. These figures are neither a mobile bill
estimate nor peak rates. The co-op mover's observed 1.22 Mbit/s gives a useful
scale for a bandwidth-limited link. Measure the actual Dart wire bytes and
peak load before selecting a target or blaming compression. The co-op result
includes no live projectile rows or boss traffic.

The archived files record sampled logical JSON sizes and per-connection wire
totals. Reproduce by adapting the sibling server's
`tool/navigation_transport_smoke.mjs` to relay the generated client connections,
subscribe to `my_motion`, and count both directions after setup. Use a no-enemy
`ironworks_relay_1v1` room versus the existing staged Breach crowd. Exclude
login/initial subscriptions and compare the same command cadence.
[1v1 samples](validation/multiplayer-audit-2026-11-03/loopback-1v1.json) ·
[Co-op samples](validation/multiplayer-audit-2026-11-03/loopback-coop.json)

The same relay also measured eight-second team Versus windows with enemies
off, no shots, and every player sending movement at about 16 Hz.

| Format | Receive rate per client | Aggregate across clients |
|---|---:|---:|
| 2v2 | 34.9–35.4 kB/s | 140.3 kB/s |
| 3v3 | 38.3–38.5 kB/s | 230.6 kB/s |

The earlier 1v1 run had one sender and one idle peer, so it uses a different
input pattern. These team windows establish traffic baselines. Sustained
firing, enemies On, delivery gaps and physical WAN play remain separate gates.
[2v2 samples](validation/multiplayer-audit-2026-11-03/loopback-2v2.json) ·
[3v3 samples](validation/multiplayer-audit-2026-11-03/loopback-3v3.json)

Five fresh HTTPS connections to the production schema from this workstation
succeeded. TCP setup after DNS took roughly 170–178 ms, with TTFB 541–605 ms.
The public Dart TLS WebSocket and scoped subscriptions also connected. Fresh
TCP/TLS/HTTP setup is distinct from a running match's input RTT. These
observations provide a route baseline for this workstation only. They do not
locate a slow server region, quantify the friend's connection, or identify
server CPU contention. The checked-in WebSocket proxy already disables proxy
buffering. The deployed proxy settings have not been inspected.

The current hosted Dart 1v1 integration test built and connected two fresh
simulator clients in 3.75 s, but production refused room creation with
`Verify your email to play online`. The old fixture still uses guests.
This is an expected admission policy mismatch for the test, not evidence
of a match disconnect. It means the historical guest smoke can no longer
validate live gameplay. Replace its fixture with dedicated verified QA
accounts before repeating hosted combat tests.
[Hosted 1v1 attempt](validation/multiplayer-audit-2026-11-03/hosted-1v1.json)

## Why 1v1 can still feel desynchronized

1v1 is the smallest Versus reproduction. The same movement, firing and hit
paths also serve 2v2 and 3v3. Team modes add simultaneous inputs, different
latencies per player, moving body blockers, overlapping shot traffic and
room-wide replication to four or six recipients. Enemies On adds scene
traffic in every Versus format.

1. **A visually good shot can be a server miss.** The local body and first
   projectile are predicted. A remote player is interpolated on a delayed
   server timeline. The server fires from its current muzzle and sweeps
   against current authoritative target bodies and cover, with no historical
   hit evaluation. Fire intent and movement/aim also have separate queues.
   The server uses the newest queued aim when available, but that aim is not
   bound to the origin and target frame the shooter saw. At 300 units/s,
   100 ms is 30 units. A dash or corner crossing changes the discrepancy
   faster. This explains how hit feedback can disagree with what was drawn
   even when the two clients later agree on health and positions. The prior
   projectile work made cues and bullets smoother without resolving this
   temporal mismatch. Projectile rewind is a design problem of its own:
   preserve authoritative fire/cadence, map validated input to a bounded
   history, and define walls, dash and late hits before implementing it.

2. **A delivery gap can turn into a visible stop or correction.** One missing
   motion command means zero movement for that server step. Obsolete ordinary
   commands are dropped when several accumulate; old commands expire after
   250 ms of server receipt age. This prevents replaying stale motion but
   sacrifices distance. The client slows near its 12-command window and
   stops generating slices when full. A rejected movement reducer can
   neutralize the current input and reset prediction. The remote player's
   buffer only targets 20–70 ms and extrapolates up to 80 ms before holding.
   Those safeguards can all be correct locally and still produce a poor
   combined result during burst delivery. The 481 ms historical gap exceeds
   the remote presentation envelope. Diagnose input starvation, queue
   drops, rejection, late acknowledgements and correction magnitude
   independently of average ping. Held fire has another failure path:
   its 150 ms keepalive has only about 100 ms of delivery margin before
   the 250 ms server freshness gate cuts fire. The server also requires
   fresh movement input for fire, including while the player stands still.
   Compare fire interruptions against both inputs' arrival histories.

3. **One ordered stream couples transient state to reliable state.** TCP
   retransmission can delay later messages behind an earlier missing segment.
   Once queued, old poses can still be delivered before newer poses, even
   though the newer state is more valuable. A fast connection can have
   this issue without exhausting average bandwidth. Compression reduces
   bytes but cannot remove ordered delivery or a long server frame.
   This is a mechanism and a test target. The friend's match was not
   captured, so TCP retransmission cannot be assigned as its cause.
   [Fiedler, Snapshot Interpolation](https://gafferongames.com/post/snapshot_interpolation/)

## Why co-op adds its own failure modes

- **Most enemies step at snapshot cadence.** The player interpolator is used
  for peer members. Ordinary enemy painting reads raw `entity.x/y`; gait
  changes its sprite, not its position. Some bosses have dedicated
  presentation paths. A steady 20 Hz feed can already look stepped at 60 Hz.
  Jitter lengthens the visible holds. Warnings, hazards, remote bodies and
  projectiles do not consistently share a presentation clock. A stale or
  skipped warning can be a fairness problem, not merely visual roughness.
- **Replication work grows even while players stand still.** A 37-enemy
  scene has roughly 12.7 kB of current JSON state. One player's modest input
  is only a small fraction of the observed traffic. Age, phases, health,
  per-entity strings and bookkeeping arrive alongside position. Projectiles
  can reach 256 room rows; hazards, support, pickups and mechanical bosses
  add further data and simulation work. The idle crowd test does not measure
  this ceiling. Scope is room-based, not relevance-based.
- **The app does too much on each update.** The Dart SDK decodes and applies
  row changes, then the app coalesces refresh callbacks but reconstructs the
  full fighter, scene and projectile collections, re-decodes unchanged JSON,
  rebuilds dynamic movement geometry and reconciles from the caches. The
  arena ticker scans entities and calls setState each render frame. Those
  costs contend with input sampling on the UI isolate. This is a code-proven
  workload, not a measured phone frame-budget violation. Capture frame and
  isolate traces to find which work dominates.
- **One scheduler transaction couples rooms.** The active-room loop steps
  every room under a nominal 50 ms callback. Each callback performs one
  fixed step and does not catch up missed wall time. A slow tick can slow
  the authoritative world. Serialization, views, snapshots and co-op
  simulation can all contribute to overruns. No production tick duration,
  view cost, host CPU or WebSocket send queue trace was available, so this
  is an architectural risk rather than a diagnosis of VPS saturation.
- **Some stops are deliberate shared phases.** A co-op upgrade choice pauses
  combat for all players. Boss reveals, downed state, reconnect and account
  renewal can also gate controls. A freeze needs to be classified against
  the authoritative phase and connection state. Comparing pixels alone
  cannot distinguish a deliberate pause from tick starvation or network
  delivery loss.

## What to take from larger shooters

Graphics are rendered locally. Activision's published Call of Duty PC/console
paper describes choosing data centers and weighting connection quality; it
does not disclose COD Mobile's exact transport or tick rate. Riot documents
measuring network RTT, processing delay and jitter separately, then tuning
move buffering and recovery. Fiedler shows how timestamped snapshots and
bounded interpolation handle irregular arrivals. Regun needs those design
principles adapted to its measured paths. Copying another title's tick rate
would increase work before correcting the timeline, and a closer endpoint
would not fix raw co-op motion on a LAN.
[Activision, Matchmaking Series: Ping](https://research.activision.com/content/dam/atvi/activision/atvi-touchui/research/publications/docs/Call-of-Duty-Matchmaking-Series-PING.pdf) ·
[Riot, Gameplay Consistency Update 2](https://playvalorant.com/en-us/news/game-updates/valorant-gameplay-consistency-update-2/) ·
[Fiedler, Snapshot Interpolation](https://gafferongames.com/post/snapshot_interpolation/)

## Implementation order and acceptance

1. **Get one end-to-end trace from both players.** Log anonymized session,
   epoch and tick, input sequence and local send/first visual times, server
   receipt/consume and reply, snapshot arrival/decode/cache times, render
   frame age, predicted/authoritative position and correction, interpolation
   underruns, shot receipt/target and outcome, phase gates, disconnects,
   wire bytes, server tick compute and send backlog. Pair server and client
   events by ID. Use monotonic intervals per host and estimate clock offset
   separately. Keep log volume bounded and exclude account data.
2. **Fix the shared Versus path.** Start with an enemies-off 1v1 to isolate
   the behavior, then exercise the same fix in 2v2 and 3v3. Use fixed lane tests,
   moving target, wall entry/exit, direction reversal, dash and simultaneous
   shots. Tie aim, input sequence and fire intent together coherently.
   Make queue recovery explicit and avoid neutralizing live controls for
   recoverable rejection. Use render/authority traces to decide a bounded
   lag-compensation policy per weapon class. Preserve server-owned collision
   and test behind-cover, cross-ping fairness, stale input and cheat limits.
3. **Make co-op snapshots cheaper and coherent.** Split immutable/loadout and
   low-frequency state from hot poses. Use compact typed/quantized motion
   and deltas, timestamps, retained spawn/despawn/phase state, and bounded
   cue history. Process only changed rows and decouple render repaint from
   widget rebuilds. Interpolate ordinary enemies on the same timebase as
   remote hazards and peers; use keyframes after discontinuities. Apply
   relevance carefully so an offscreen boss or projectile cannot hide a
   threat that enters view. Keep slow clients from accumulating obsolete
   poses. Preserve a reliable path for actions, outcomes and resync.
4. **Test transport and hosting against the same trace.** Compare existing
   WebSocket with compact/coalesced state first. If ordered-stream stalls
   still dominate under loss, evaluate a separate sequenced, replaceable
   gameplay channel while retaining reliable account/lobby/results paths.
   Compare alternative hosting routes using both players' real ISPs.
   Increase cadence only when profiling shows tick and bandwidth headroom.
5. **Set a release gate that resembles play.** Independent phones and ISPs,
   1v1, 2v2 and 3v3 each through several full rounds with enemies Off and On,
   and 2/3-player co-op through a crowded
   wave, upgrade, boss, reconnect and resume. Repeat with 50/150/300 ms RTT,
   jitter, constrained throughput and injected delivery holds/loss. A
   TCP delay proxy is not a packet-loss simulator; use an impairment tool
   that models retransmission for that case. Compare p50/p95/p99 input-to-
   presentation, authoritative ack age, frame time, server tick duration,
   snapshot gaps, correction magnitude, bytes and intentional versus
   unexpected holds. Require clean state convergence and matching hit
   outcomes for scripted cases, sustained headroom below the 50 ms tick
   budget, and no unexplained freezes on real devices. Successful lobby
   setup or final position convergence alone cannot pass this gate.

For team Versus, exercise all players moving and firing together, opposing
players with asymmetric RTT, allied and enemy body crossings, multiple
projectiles around the same cover, and one player's stall or reconnect while
the others continue. Report the worst client separately from the room average.
Each format must independently meet the release gate.

No production gameplay, hosting or transport settings were changed by the audit.

## Code map for follow-up

| Area | File and entry point |
|---|---|
| Client subscriptions, input and row decode | `lib/multiplayer/online_session.dart`: `connect`, `_refresh`, `_sendMotion`, `_tick` |
| Prediction window, correction and remote sampling | `lib/multiplayer/movement_prediction.dart`: `advance`, `reconcile`; `lib/multiplayer/remote_motion.dart`: `add`, `render` |
| Projectile reconciliation and render | `lib/multiplayer/projectile_presentation.dart`; `lib/widgets/online_arena.dart` ticker; `lib/presentation/online_world.dart`: `enemy` |
| Authoritative movement and hit checks | `../regun-server/spacetimedb/src/index.ts`: `queueMotion`, `tick`, `tickCombat`; `queued_motion.ts`: `takeFreshMotion` |
| Scene read/write and public payload | `../regun-server/spacetimedb/src/survival_runtime.ts`: `SurvivalFrame` constructor and `save`; `index.ts`: `roomScene`, `roomFighters`, `roomProjectiles` |
