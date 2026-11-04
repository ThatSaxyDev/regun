# Regun multiplayer recovery plan

**Goal.** When I move, dash, or fire on my phone, my friend sees the action promptly and smoothly. In Versus, hits and misses should make sense from both screens. In co-op, players should agree on when enemies appear, attack, and die.

**Scope and order.** Co-op with two and three players, 1v1, 2v2, and 3v3 are all required. Start with 1v1 to isolate timing and fairness problems, and capture baselines for every format before judging shared fixes. Keep the current hosting and SpacetimeDB. Use the Lightcone idea of prioritizing time-sensitive gameplay updates where measurements show a benefit.

The production Breach test used two signed-in simulators on one Mac. Across eight trials, median movement onset was 56 ms locally and 279 ms remotely. Shot presentation was 10 ms locally and 258 ms remotely. Server tick intervals were 55 ms at p95, and the largest observed client update gap was 100 ms. These are co-op presentation measurements. Versus needs its own baseline. The Breach test build used a temporary geometry hash override after comparing its bounds and obstacles with the server source.

The first production 1v1 pass on Ossuary Cross used the regular geometry contract and ran eight alternating movement and shot trials with enemies off. Median remote onset was 281 ms for movement and 280 ms for shots, versus 64 ms and 12 ms locally. Application RTT was 174–178 ms, and server tick intervals were 52 ms at p95. Neither client hit the prediction queue limit. The observer usually presented actions within roughly one sample of the sender seeing the authoritative update. This pass did not isolate input send, server execution, or outbound delivery time. It did not test hit fairness. The first run confirmed room exit only on the host.

Run the baseline with `bash tool/multiplayer/run_versus_probe.sh HOST_SIM_UDID PEER_SIM_UDID DEFINES_JSON` using two already signed-in iOS simulators with the regular Regun build installed. The runner restores their original app builds after recording reports. [First run reports](validation/multiplayer-recovery-1v1/)

The repeat run confirmed exit on both clients. Median remote movement and shots were 266 ms and 219 ms. The sender's most recent movement acknowledgement at observed movement onset reported a median input age of 47 ms (14–62 ms). That measures server receipt to simulation for the acknowledged command, which can differ from the first movement command. The observer presented shots and movement within 12 ms of the sender observing authority in this run. Prioritize tracing input send and server application before tuning interpolation to reduce onset delay. The difference between the two runs is baseline variability. Both used the same gameplay code.

The dispatch probe then matched the first movement sequence to its acknowledgement and measured the first fire dispatch. In eight trials the old fire dispatch median was 27 ms. Reusing the 16 ms client clock for the existing rate-limited combat pump reduced that median to 5 ms. Median remote shot onset went from 237 ms to 194 ms across the two short runs, while the maximum rose from 246 ms to 294 ms. This isolates a client dispatch improvement. Remote latency varies and still needs broader testing. Both clients left the room in each run. The per-client reports are in the validation folder above.

## Current candidate

- The combat send loop now runs on the 16 ms client clock and retains its existing send throttle. The production duel trace above measures that change.
- The client checks a collision hash for each co-op arena. It also accepts the deployed server’s legacy identifier for a map whose collision layout still matches. Foundry collision now matches the server. Client and server generators agree on all four co-op hashes. The server change is local and should be staged after compatible clients are available.
- Two signed-in iOS simulators entered and played Foundry against the deployed server with the regular geometry check and enemies enabled. Both observed up to 22 enemies, completed eight alternating movement and shot trials, and confirmed room exit. Median remote movement and shot onset were 286 ms and 247 ms. One client had a 330 ms update gap despite a 52 ms server tick interval at p95. This confirms compatibility and exposes remaining latency variance. [Foundry reports](validation/multiplayer-recovery-foundry/)
- Ordinary enemy travel and grenade flight are smoothed between snapshots. Spawn, attack, damage, and impact stay authoritative. Enemy attack phases use the authoritative position so committed warnings stay aligned.
- The first local iOS socket run passed with three players on Breach, two on Foundry, four on Ironworks Relay, and six on Ossuary Cross. All clients converged after movement with zero prediction stalls or dropped movement commands. The repeat run verified simultaneous fire from every player on every client, including 3v3 with enemies enabled. The repeat 2v2 run dropped six queued movement commands across the four clients and still converged. These runs used disposable local accounts and loopback latency. [Local match reports](validation/multiplayer-recovery-foundry/local-parties.json)

### Production tick trace, 4 November 2026

A repeat Foundry match did not reproduce the original peer-only 330 ms gap. It captured a shared 195 ms gap on ticks 400–401. Those ticks were stamped 49.73 ms apart by the scheduled server reducer. The next tick, 402, was stamped 199.91 ms after 401. Both clients received it roughly 51 ms after receiving 401. The game applied tick 401 in under 0.75 ms after the SDK cache saw it on either client. This puts the observed delay before the game applies updates and shows a server-side cadence interruption at the same time. The reducer timestamp marks the transaction's assigned time and does not measure execution, commit, view evaluation, or WebSocket delivery separately. The next diagnostic should correlate those stages and host resource metrics around 06:37:54 WAT. [Paired trace summary](validation/multiplayer-recovery-foundry/tick-gap-summary.json)

## 1. Measure every format, starting with 1v1

- [x] Automate both signed-in clients in one private match with enemies off. Reuse saved sessions without exporting credentials. Drive both players and record both directions.
- [ ] Script movement starts and reversals, dashes, isolated shots, sustained fire, crossing into cover, and simultaneous fire. Include reload, round reset, and reconnect.
- [ ] Correlate input sequence, server tick, and shot ID. Measure input sampling to send, server receipt to application, and client receipt to presentation. Use local elapsed times and report clock uncertainty for cross-machine estimates.
- [ ] Save the repeatable baseline with median and p95 action delays, update gaps, visible stalls and corrections, and hit outcomes. Use identical scenarios for before-and-after comparisons.
- [ ] Extend the runner to four and six clients for 2v2 and 3v3. Measure every player's view under simultaneous movement and fire. Test Versus with enemies off for isolation and with the supported enemy setting on for release coverage.
- [ ] Capture two- and three-player co-op baselines in Breach and Foundry once compatible. Include a crowded wave, a boss attack, and a reconnect during combat. Record delays and missed or duplicated events for each peer.

## 2. Improve Versus movement and shots

- [ ] Fix the largest avoidable wait the trace exposes. Check whether fresh input edges wait in the send loop, server mailbox, or update delivery. Preserve dash and trigger edges, room generation checks, and server-owned combat.
- [ ] Tune the existing timestamped remote movement track from captured gaps. Keep turns, stops, and dashes readable, constrain presentation to cover, and reset at spawn, death, and round transitions. Compare stall duration and correction size as well as delay.
- [ ] Make remote muzzle flash, sound, and projectile agree. If delivery queues delay these events, test compact authoritative events with stable IDs and duplicate suppression. Keep ammo and damage authoritative.
- [ ] Replay corner, dash, and simultaneous-fire cases from both perspectives. Consider bounded projectile lag compensation only if the traces still show a mismatch between what players see and the server outcome. Test cover and the defender’s view before adopting it.
- [ ] Rerun 2v2 and 3v3 after each shared change. Check simultaneous shots from multiple players, teammate and opponent motion, eliminations and round transitions, and one player lagging or reconnecting while the others continue. Compare the worst client and server tick cadence alongside match-wide averages.

## 3. Repair and smooth co-op

- [x] Generate client and server geometry versions per arena from the same layout and align Foundry collision.
- [ ] Verify Breach against production with the regular geometry check. Foundry passed with two signed-in clients.
- [x] Smooth ordinary enemy and grenade presentation between authoritative snapshots. Use stable IDs and server ticks to align enemy arrivals, attack warnings, impacts, and deaths. Preserve committed warning geometry and the server’s ownership of spawning and damage.
- [ ] Test crowded waves, split parties, late updates, and reconnects with two and three players. Every client should converge on the same living enemies and authoritative health, including after reconnect. Verify warnings precede damage on every screen, grenade effects play once, and revive, upgrade, and supply state recover without duplicate rewards.

## 4. Release gates

- [ ] **1v1.** Show lower remote action delay and fewer visible stalls and snaps with no regression in local responsiveness. Verify scripted hit outcomes from both sides. Repeat on two physical phones on separate connections.
- [ ] **2v2.** Pass the same responsiveness and fairness checks with four active clients. Verify simultaneous fire, elimination, round transitions, and reconnect from all four views.
- [ ] **3v3.** Pass the same checks with six active clients, including enemies enabled. Verify that per-client update gaps, frame time, and server tick cadence stay within the budgets set from baseline testing under full combat load. Include physical phones on separate connections in the team-format playtests.
- [ ] **Co-op.** Both arenas pass with two and three players on the regular client. Verify enemy and boss synchronization, crowded-wave performance, revive, supply and upgrade outcomes, and reconnect. Repeat on physical phones.
- [ ] Share before-and-after results and review any production server change before pushing it. Keep each mode in private testing until it passes its own gate.

**First deliverable.** A repeatable 1v1 trace and the first fix it justifies, with a before-and-after duel and regression checks across 2v2, 3v3, and both co-op party sizes.
