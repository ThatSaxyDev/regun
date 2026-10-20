# Regun multiplayer plan: co-op and competitive PvP

**Date:** 20 October 2026  
**Status:** proposal for review; multiplayer is not implemented.  
**Requested scope:** online co-op **and** competitive PvP, using SpacetimeDB with TypeScript as the preferred server language.  
**First platforms:** native iOS and Android. Desktop/web can support development clients; production support needs its own acceptance pass.

## 1. Recommended direction

Keep Flutter/Flame for the game client. Build an authoritative TypeScript simulation inside SpacetimeDB. Share networking, movement, weapons, collision, identity and match lifecycle across both modes, then supply separate co-op and PvP rules.

Start with a small two-device foundation, deliver private two-player co-op and private 1v1 duels, and open ranked PvP only after combat fairness, population and operations pass explicit gates. Competitive combat is part of this plan from the beginning; a public ladder is a later release gate, not a prerequisite for playing private duels.

The critical first uncertainty is native Dart integration. SpacetimeDB officially supports TypeScript server modules, but its official client list does not include Dart. A community client must be tested against an exact server version before committing the gameplay migration. If it fails, test an official TypeScript SDK gateway; changing the Flutter client is not the default solution.

The existing offline game remains available. Multiplayer does not require completing the earlier commerce roadmap first. Accounts needed for online identity are included; billing, ads and premium-wallet work are separate projects.

### What success means

- Two friends can create/join a private room, choose loadouts, complete a co-op run, recover from a short disconnect and receive one correct result each.
- Two opponents can play a fair private duel with server-owned movement, ammo, damage and outcomes, followed by a rematch.
- Online controls retain Regun's touch layout and weapon identity, with acceptable responsiveness on real iPhones and Android phones in intended regions.
- Ranked matchmaking, when enabled, uses trusted online results, equal competitive access and documented disconnect/rating rules.
- Solo saves, progression, reloads, slow-motion upgrade selection, training and presentation continue to work.

## 2. Current game and the migration it requires

This plan extends [the complete-game blueprint](REGUN_COMPLETE_GAME_PLAN.md), [the progress log](REGUN_PROGRESS.md), [the playtest guide](PLAYTEST_GUIDE.md) and [the earlier backend plan](REGUN_MONETIZATION_AND_BACKEND_PLAN.md). Where the earlier plan proposed Rust first or deferred all PvP, this proposal evaluates TypeScript first and includes both modes. It does not claim their implementation or acceptance.

The audited application is `1.0.0+11`, with four weapons, three survivors, two arenas, eight enemy roles, eight bosses, thirty upgrade families and six fusions. These are reusable content and presentation foundations, not network-ready simulation contracts.

| Current area | Observed coupling | Required change |
|---|---|---|
| `lib/game.dart` | One `myPlayer`; owns spawning, firing, combat, camera, run lifecycle and persistence | Separate online session/replication from local simulation; address actors by match-scoped IDs |
| `PlayerComponent` | Reads local joysticks, global state and local collision directly | Separate local input, predicted local movement, remote actor presentation and authority |
| `GameNotifier` | One player's health, build, ammo, reload timers, upgrades and phase | Keep solo behavior; online HUD reads a per-player projection of server state |
| `CombatSystem` | Direct references to `game.myPlayer`, local RNG and component targets | Server simulation uses player/entity IDs, factions, pure rules and bounded proc budgets |
| `BulletComponent` | Both renders and applies local swept collision/damage | Online visuals reconstruct server shots; authoritative hit resolution runs server-side |
| Dash/reload controls | Buttons directly mutate dash, immunity, ammo and timers | Emit action intents; reconcile predicted feedback with server acceptance |
| Director/tactics/occupancy | Target and visibility decisions assume one player | Team-aware targets, relevance and safe spawn/escape rules |
| Bosses/attack geometry | Actor components own attacks and presentation timing | Server attack state/timelines; client art uses the same committed geometry and timing |
| `RunStore`/checkpoints | Local solo schema 1/2; serializes one run and transient-state recovery | Preserve solo format; online resume attaches to a server match, never uploads a trusted world |
| Profile/settlement | Local earned progression and once-only run settlement | Separate online match ledger and authoritative rewards from unverified local results |

There is no multiplayer dependency or implementation in the audited app. The local CLI reports SpacetimeDB **2.12.0**; that is an installed candidate, not a verified server/client compatibility matrix.

## 3. Product scope and proposed rules

All rules below are proposed defaults. Confirm or adjust them before their dependent milestone; they are not silently approved by this document.

### Co-op survival

| Decision | Proposed first-release rule |
|---|---|
| Players | Two; preserve identifiers/contracts that permit four later, without claiming four-player balance |
| Entry | Private invite code, readiness and a shared countdown; public co-op queue later |
| Starting content | Rook, shotgun, Breach and a small enemy subset for the slice; expand to the full current roster before claiming full co-op support |
| Friendly fire | Off; collision rules explicitly distinguish teammates from enemies |
| XP | Shared team XP; each player gets a personal build/offer pool; one pickup credits the team once |
| Upgrades | Queue level-ups and resolve at server-controlled safe breaks; both players see a synchronized 0.1× presentation, with reload/input/damage gated |
| Picker timeout | Initial experiment: 15 seconds of real server time, then a documented valid fallback; never run this deadline on the slowed combat clock |
| Death | Downed state with a revive interaction; initial experiment: three-second hold, damage interrupts, twenty-second bleed-out |
| Defeat/re-entry | All players downed means defeat; a bled-out player spectates and may return at an earned checkpoint/boss break if the teammate survives |
| Disconnect | Neutralize input immediately on confirmed disconnect, retain a slot for an initial 30-second grace, no free repeated immunity |
| Pause | A local menu does not pause a live teammate; unanimous pause only in safe intermissions |
| Rewards | Server settlement once per participant/match; reconnect retrieves the same result |

Safe breaks need actual pacing support: stop reinforcements, finish or retire hostile attacks under a defined rule, then enter selection. Do not wait indefinitely for an enemy to die before offering upgrades. Preserve XP overflow and stacked choices. If this cadence damages survival pacing, compare a timed individual-choice prototype before locking the mode; do not implement two incompatible upgrade systems by accident.

Disconnected players stay vulnerable under a declared policy; a disconnect must not become a dodge. Co-op initially permits reconnects, not arbitrary late joins. If only one player remains past grace, offer a clearly marked solo finish or end the match according to the chosen reward rules. Never silently replace a partner with a bot.

### Competitive PvP

| Decision | Proposed first-release rule |
|---|---|
| Format | Private 1v1 round-based duel; first to three round wins |
| Round pacing | Initial experiment: 90-second cap, then a clearly warned overtime rule; define the tie outcome explicitly |
| Arena | Small authored, symmetric duel layout derived from Regun's art; neither survival arena is assumed competitively fair |
| Loadouts | Equal baseline survivor; first slice uses mirrored shotgun, then all four weapons after dedicated PvP tuning |
| Access | Competitive legal equipment available equally, independent of solo unlocks or purchases |
| Builds | No survival RNG upgrades, fusions, guards or proc chains until deliberately designed and balanced for PvP |
| Combat | Server damage and projectile collision; distinct competitive health/damage values where required |
| Respawn | Between rounds, with explicit input reset, countdown and deployment protection |
| Camera | Consistent gameplay-visible area across aspect ratios; wider screens must not reveal opponents earlier |
| Aim assist | Explicit competitive policy, measured and applied consistently; do not inherit solo assistance silently |
| Disconnect | Initial 30-second reconnect grace; no global pause or immunity; ranked abandonment may forfeit under published rules |
| Rewards | No rating for private matches; cosmetic/progression rewards must resist repeated farming |
| Ranked | Public launch only after the later ranked acceptance gate |

Choose spawn points, sightlines and cover through playtests. Prevent first-shot spawn advantage, repeat spawn trapping and camera-edge ambush asymmetry. Test left/right and top/bottom starting sides. Overtime must be readable and independently tuned; it must not introduce an untested damaging floor effect as a shortcut.

For ranked: use a versioned rating model such as Glicko-2, provisional placement, regional latency limits, an expanding skill window and a visible maximum wait. Final model and thresholds are a separate decision after population estimates. Never hide bots in the competitive queue. If population cannot sustain fair matches, launch private/casual duels and defer the ladder.

## 4. Technical architecture and authority

```mermaid
flowchart LR
    A[Flutter input and local prediction] -->|Sequenced intents| T[Transport adapter]
    T --> S[SpacetimeDB TypeScript module]
    S --> R[Shared simulation rules]
    R --> C[Co-op rules and encounters]
    R --> P[PvP rounds and scoring]
    S -->|Authorized state and events| T
    T --> V[Flame interpolation, HUD, art and audio]
    S --> L[Durable match results and online profile]
```

**Server owns:** membership, ready/start transitions, spawn locations, movement bounds, dash/immunity, fire cadence, ammo/reload, projectiles, collision, damage, statuses, RNG, enemies, bosses, upgrades, rounds, revive, rewards and match results.

**Client owns:** touch interpretation, camera within competitive constraints, predicted local feedback, remote interpolation, animations, audio, material VFX, accessibility settings and menus. Predicted effects never award damage or rewards.

Use a TypeScript SpacetimeDB module for authoritative tables and transactional reducers. Keep the simulation core independent of database APIs so headless scenarios can exercise it. This runtime is not assumed to be an unrestricted Node.js server: verify package/runtime restrictions and scheduled execution on the selected release. A conventional TypeScript service is optional for gateway, matchmaking coordination or future external integrations; it must not become a second combat authority.

Start with one regional deployment and logical match isolation. A module/database is a scheduling and resource boundary, not automatically an independently scaling process per match. Measure transaction duration and cross-match contention before choosing matches per database, regional sharding or dedicated match allocations. High-frequency combat tables should not share an avoidable failure/maintenance boundary with future commerce.

### Proposed repository structure

```text
server/
  spacetimedb/          # Schema, reducers, schedules, lifecycle and access rules
  simulation/          # Movement, geometry, weapons, entities and mode rules
  tests/               # Reducer integration, bots, abuse and load scenarios
shared/
  rules/               # Versioned numeric content and arena geometry
  protocol/            # Reviewed application contracts/version metadata
  fixtures/            # Cross-language movement/combat expected outcomes
tool/
  multiplayer/         # Export/check contracts, run local instances and bots
lib/multiplayer/
  transport/           # SDK-specific adapter and generated bindings
  models/              # Inputs, snapshots, events and online state
  prediction/          # Movement replay, reconciliation and interpolation
  presentation/        # Remote actors and network-driven combat rendering
  session/             # Connection, membership and lifecycle controller
docs/validation/multiplayer/
                         # Compatibility, network, fairness and device evidence
```

Names are proposed, not existing files. Generated wire bindings come from the pinned SDK/schema toolchain. Separate application contracts must not duplicate that generator's serialization logic.

## 5. Native Flutter compatibility gate

Evaluate `spacetimedb` **1.3.0** as an initial community-package candidate: its maintainer advertises v2 support, generation, subscriptions and a binary codec. That broad claim does not prove compatibility with 2.12.0. Inspect source, maintenance, license, security and transitive dependencies before adding it. Pin the exact tested package/generator revision and server/runtime versions.

The spike must demonstrate:

1. A TypeScript module builds, publishes locally and runs a server-driven scheduled simulation with no gameplay client connected.
2. Generated Dart bindings correctly handle IDs larger than 2^53, identities, enums, optional fields, timestamps and binary messages.
3. Release iOS and Android clients authenticate, invoke permitted reducers, receive initial state and transaction updates, unsubscribe and reconnect.
4. A client cannot subscribe to another room's restricted data or mutate another player's state. Filtered subscriptions alone are not authorization.
5. Repeated enter/leave/restart/background cycles clean up callbacks, subscriptions and credentials correctly.
6. Inputs are never replayed after a disconnect as generic offline mutations. Disable the SDK's offline action queue for gameplay and rewards.
7. Two devices receive consistent match state and recover from Wi-Fi/mobile-data transitions.

If the direct client fails materially, run a bounded gateway comparison: Flutter WebSocket → authenticated TypeScript gateway → official SpacetimeDB TypeScript SDK. Measure added delay, bandwidth, session mapping and cleanup. The gateway must bind each user to authorized operations/views; a shared privileged identity must never accept a client-supplied player ID as proof. Choose direct SDK or gateway in a written decision record before continuing; do not maintain both production paths without demonstrated need.

## 6. Data model, access and lifecycle

| Record | Purpose and important constraints |
|---|---|
| Online player/account | Stable authenticated identity, display name, linking/deletion state; separate from local profile ID |
| Room/member | Mode, capacity, invite lookup, leader, readiness, allowed loadout and expiry; atomic join prevents overfill |
| Match | Region, ruleset/content/protocol versions, seed, authoritative tick, phase and terminal result |
| Participant | Account-to-slot binding, team, connection generation, grace deadline and abandonment state |
| Player actor | Transform, aim, health, ammo, dash/reload/status timelines and current life/round |
| Latest input/action receipt | Accepted sequence, bounded movement/aim and deduplicated dash/reload/choice requests |
| Entity/projectile/drop | Match-scoped IDs, authoritative owner/faction, collision state and bounded lifetime |
| Attack | Source actor, committed geometry, warning/activation/recovery ticks and cancellation state |
| Build/offer | Per-player ranks, authoritative eligible offers, offer ID and deadline; private until reveal rules allow |
| Round/score | PvP round state, side/spawn assignment, score and outcome reason |
| Match result/reward ledger | Unique match/participant/ruleset settlement; retry returns the existing result |
| Rating update | Unique rated result plus algorithm/season version; correction history, no client rating writes |
| Schedule/cleanup | One active loop per match/allocation, expected generation and expiry; stale callbacks cannot advance replacements |

Use private backing tables and identity-authorized views/operations for member-only state. Determine the exact access mechanism during the compatibility gate. Public combat data should contain only information deliberately safe for anyone to read; do not rely on an honest client's match filter. Do not replicate hidden opponents/offscreen information if the competitive rules promise it is secret. Invite codes are rate-limited discovery aids, not account credentials.

Every mutation verifies caller membership, current phase, connection generation, bounded values and request freshness. Admission/loadout validation is server-owned. Membership changes, room start and settlement must remain correct under concurrent calls.

### State machines

```text
Session: signed out → connecting → authenticated → room → loading → live
         live → reconnecting → rejoined | expired
         any state → leaving → disposed

Match: waiting → loading barrier → countdown → active
       co-op: active ↔ safe upgrade break; active → team defeat | completion
       PvP: active → round result → countdown; final round → match result
       terminal → settled → retained result / cleaned transient state
```

Provide loading deadlines, minimum participant readiness and cancellation behavior. A slow asset load cannot start one player in a damaging arena while the other is still loading. Joining/rejoining carries a match epoch and life/round generation so late events cannot affect a new match or respawn.

## 7. Simulation, protocol and responsive play

### Inputs

Send normalized movement, normalized aim, held fire, action sequence IDs and input sequence numbers. Commands identify the intended session/match generation, but authorization derives from the authenticated caller. The server controls elapsed time and speed; client timestamps are diagnostic/untrusted.

Clamp vector magnitude, reject non-finite coordinates, bound request frequency and input queues, deduplicate actions and reject old sequences. On stale input, clear held fire/movement after a short measured timeout. A backgrounded app must not continue walking/firing indefinitely.

### Tick and clocks

Begin with an experiment at **20 Hz** (50 ms), compare **30 Hz** for PvP, and raise only when measurements justify cost. The carbine's 0.1-second cadence and fast bullets require accurate substep timing/swept tests; merely raising render FPS does not fix authority.

Use a server tick index and a deterministic order: accept bounded inputs → move actors/occupancy → advance weapon/AI/attack timers → sweep projectiles/resolve damage → apply deaths/drops/XP/round outcomes → publish state/events. Document simultaneous lethal-hit/trade behavior rather than depending on reducer arrival order.

Separate simulation time from real deadlines. Co-op selection may slow simulation; disconnect, loading and upgrade-choice deadlines keep advancing. Implement one idempotent scheduling chain per match/allocation. Test delayed callbacks, restart, tick overrun and duplicated schedule requests. Bound catch-up work; do not fast-forward minutes of lethal combat after a deployment stall. If a server restart cannot restore a valid match, abort it explicitly and settle/void it under documented policy.

### Prediction and reconciliation

- Predict local movement and dash using the same numeric geometry and constraints as the server.
- Server updates include the authoritative tick and last processed input sequence. Restore authoritative movement and replay only unacknowledged permitted inputs.
- Smooth small position errors; snap safely for respawn, invalid predictions and large discrepancies. Never smooth an actor through a wall.
- Interpolate remote actors behind server time using a small adaptive buffer; cap extrapolation and then hold/fade rather than inventing movement.
- Show local muzzle/recoil/reload feedback promptly; reconcile accepted shots/ammo. Key effects by shot/action ID to avoid double audio/VFX on confirmation or reconnect.
- Apply authoritative health, hit confirms, death, XP and rewards. A speculative hit marker must not look like confirmed damage.

### PvP latency and hit policy

Start with projectiles on the current authoritative world, without full-world rollback. Establish server-time input handling, maximum accepted input age and clear dash/immunity boundaries. For each hit, log shot time, resolution tick, victim position, immunity and wall test in development evidence.

Compare this baseline at 50/100/200 ms RTT. If it produces unacceptable disadvantage, prototype a **bounded** compensation policy with stored transforms, server-estimated time and strict maximum age. Do not trust client hit claims or rewind victims through cover/dash protection without explicit rules. Benchmark fairness for both attacker and defender before locking policy. Ranked is blocked until this choice is resolved and communicated.

### Replication and bandwidth

Subscribe only to authorized match state. Co-op encounters must consider both players' relevant areas; individual camera culling must not stop the server simulation. Separate persistent actor state from short-lived shot/impact/attack events. Reconstruct decorative particles locally. Projectile events include IDs, owner, origin, direction, speed/range and spawn tick; snapshots retain enough active damaging projectiles/attacks for late rejoin.

Apply a transaction's changes coherently before rendering a frame. Give transient events monotonic IDs and bounded retention; reconnect takes a fresh snapshot and a valid event cursor, without replaying old explosions or missing still-active hazards. Never delete a damaging attack merely because a client culled its visual.

## 8. Shared contracts and content port

Extract numeric tuning from Flutter enums into a reviewed, versioned source with generated Dart/TypeScript outputs. Preserve stable IDs across releases; names and translated labels are not wire IDs. Export world bounds, obstacle geometry and hazard footprints from the authoritative arena layout. The server must not try to run Flame or depend on sprite dimensions for collision.

Cross-language fixtures cover movement at walls/corners, dash distance/immunity, body occupancy, swept projectiles, pellet once-only damage, pierce/ricochet, reload timings, RNG, XP overflow, proc ceilings and attack geometry. Match expected outcomes/tolerances, not identical rendering. TypeScript numbers, Dart doubles and integer IDs require explicit limits/serialization; avoid accidental precision loss or different RNG behavior.

Port incrementally:

1. One survivor, movement/dash, shotgun and a static target.
2. All four weapons with authoritative reload, ammo, spread and collisions; competitive variants use separate values.
3. Basic enemies, shared XP and a representative upgrade/fusion path.
4. Full enemy roles, elite/director logic and both arenas.
5. Boss timelines/weak points/phases, then all eight bosses and the full build roster.

Enemy targeting must consider eligible living teammates, target hysteresis and readable commitment. Spawn safety covers both players; distance/visible population limits use the relevant union rather than doubling budgets blindly. Preserve separate living occupancy/pending spawn reservations, boss priority, actor-based movement and emergency caps. Revalidate the escape budget for attacks threatening two positions at once; solo escape tests do not prove co-op safety.

## 9. Co-op and PvP presentation

Keep the custom charcoal/brass pixel UI, brief player copy, mirrored control clusters and dash/reload under the aiming thumb. Reuse material `AttackVfx`, grounded actors, directional poses and weapon art. No generic Material switches or geometric placeholder attacks in the finished mode.

Add Online → Co-op / Duel, create/join, invite copy, readiness, connection status, teammate health/downed/revive indicators, PvP score/countdown, reconnect, result and rematch flows. Keep offline Play/Continue available. Early development modes stay behind an internal flag until functional; no broken public menu entries.

Warnings carry server activation times and committed geometry. A client receiving a warning late must resynchronize; it cannot gain extra local immunity by delaying presentation. Define a severe-desync policy so a match does not continue deceptively. Initial fresh load/rejoin uses a readiness/protection rule, not the training world's global freeze.

Preserve planted warnings, attack impact clips/recovery, texture leases and disposal guards. Online hit flashes, weapon recoil and sound cues must survive reconciliation without duplication. Reduced Motion and audio preferences remain local. Co-op landing/revive does not pause everyone; any invulnerability is server-owned. The shotgun retains its normal timing and original Lottie. PvP balancing must not overwrite solo values.

## 10. Identity, rewards, safety and competitive integrity

Use authenticated online identities with secure native token storage and a defined guest-to-linked-account path. Guest private rooms can be supported first; ranked requires recoverable accounts. Resolve simultaneous sessions by connection generation rather than allowing two devices to drive one slot. Account linking must not duplicate rewards or merge unverified balances by addition.

Offline Scrap/unlocks remain local/legacy state. Competitive stats and authoritative online rewards use a separate ledger. Do not accept local saves or uploaded solo results as rated proof. Define how earned online rewards appear in the existing Collection; allow idempotent claim/projection and recovery without making a locally edited balance authoritative.

Protect against forged IDs, speed/fire spam, invalid aim, stale inputs, room enumeration, ready/start races, offer replay, duplicate settlement, reward farming and rating manipulation. Competitive access/effect budgets must not depend on paid power. Server authority does not eliminate aimbots or collusion: retain bounded match evidence, anomaly signals and a review/appeal process. Avoid speculative permanent bans from a single latency anomaly.

Exclude chat/voice from the first release. Display names still need length/character rules, reporting and moderation. Before public ranked, provide report/block behavior, abandonment rules, proportionate retention and a privacy/deletion process. Never log auth tokens. Specify retention for diagnostic inputs and match evidence before enabling production collection.

## 11. Deployment, observability and cost

Use separate local, staging and production databases/credentials. Keep module schema migrations and app/protocol releases versioned together. Existing matches stay on their ruleset; incompatible clients fail admission with a clear update path. Avoid changing weapon values halfway through a match.

Deploy by draining admissions, allowing live matches to complete, then publishing/migrating; test rollback and schema compatibility in staging. Do not assume an old binary can read a newly migrated schema. Backups, restoration and failure recovery require a rehearsed procedure. Start self-hosted locally; select managed versus self-hosted production only after measuring regional latency, operations and costs.

Measure: active rooms/matches/players, connection/rejoin success, RTT/jitter, stale inputs, correction distance, tick interval/duration/overruns, reducer failures, memory/table growth, bytes per client, warning lead-time, hit disputes, settlement retries, disconnect causes, queue waits and result consistency.

Load test many simultaneous matches with realistic input rates and entity counts. Include idle connections, reconnect storms, room churn and maximum legitimate proc/projectile loads. Define admission limits and saturation behavior; stop admitting new matches before existing matches collapse. Report measured matches per allocation with hardware/configuration and headroom.

Model cost per concurrent match-hour from compute, resident rows/memory, bandwidth, retention, auth, gateway if used and monitoring. Do not infer free production capacity from vendor headline rates. Compare measured 20/30 Hz cost and latency; verify current hosting/pricing/backup terms when making the deployment decision.

## 12. Delivery milestones and exit gates

Milestones are dependency-based deliverables, not a claim that multiplayer can be completed in a few days. Estimate dates after the compatibility and combat slices reveal measured work. Review scope at each gate rather than cutting fairness/recovery at the end.

| Milestone | Deliverable | Exit evidence |
|---|---|---|
| M0 — Approve scope/contracts | Mode rules, architecture decision, threat model, preserved solo baseline, content/version inventory | Agreed decisions; current verification recorded; no gameplay migration yet |
| M1 — Native compatibility | Pinned TS module, Dart client/generator or measured gateway, identity/access, schedule and reconnect spike | iOS + Android release evidence, access rejection tests, written go/no-go and exact versions |
| M2 — Shared movement room | Private two-player room, readiness/loading, movement/aim/dash, prediction/interpolation, teardown | Two real devices; corner/body tests; no stale input, leaked callbacks or cross-room state |
| M3 — Authoritative combat | Shotgun first, then four weapons; health, projectile sweeps, reloads, death and result foundation | Simulation/reducer tests and latency matrix; no client-authored damage or duplicated shots |
| M4 — Private PvP alpha | Duel arena, equal loadouts, rounds/ties/overtime, reconnect/forfeit, rematch | Human attacker/defender fairness review; camera/access parity; no private rating grants |
| M5 — Co-op vertical slice | Basic enemies, director, shared XP, personal builds, safe upgrade break, downed/revive, one boss | Two players complete a representative run and recover through interruption/result retry |
| M6 — Full co-op content | All current survivors/weapons/enemies/bosses/arenas/build families/fusions and challenge policy | Coverage ledger; cross-language fixtures; crowd/attack fairness and real-device long sessions |
| M7 — Public online beta | Recoverable accounts, casual admission, regions, reports, operations, load caps and durable rewards | Security/load/recovery evidence; privacy flows; regional device/network acceptance |
| M8 — Ranked PvP | Settled hit policy, competitive balance, matchmaking/rating, placements/season policy and anti-abuse review | Sufficient population; trusted idempotent rating; acceptable waits/latency and adjudication |
| M9 — Release and expansion | Staged rollout, rollback rehearsal, support docs and accepted telemetry | Release checklist signed off; then evaluate four-player co-op, 2v2 or additional formats |

M4 and M5 can share completed infrastructure but each needs its own acceptance. The proposed review order gets a small duel playable before the large AI/content port. This does not make co-op optional. Four-player co-op, 2v2, spectators and tournaments remain later scope.

## 13. Verification and acceptance matrix

| Layer | Required cases |
|---|---|
| Solo regression | Existing `make verify`; original shotgun reload/Lottie, 0.1× choice, save schema 1/2, training entrance/recovery, controls and art contracts |
| Pure simulation | Fixed-seed movement/combat fixtures; collisions, simultaneous kills, dash immunity, all weapon reloads, XP/build/proc caps and mode transitions |
| Server integration | Real module reducers/schedules; authorization, concurrent joins, start/settle races, duplicated/stale requests, forged data and cleanup |
| Client lifecycle | Route enter/exit, restart, callback disposal, token restore/link, readiness failure, app update mismatch and background input reset |
| Network | 50/100/200 ms RTT; asymmetric delay/jitter; underlying packet loss and retransmission stalls; disconnect/reconnect; Wi-Fi/cellular switch |
| Transport correctness | WebSockets preserve order within a connection; test stale application callbacks/retries across reconnects rather than assuming UDP-style wire reordering |
| Co-op | Far-apart players, target switching, teammate pickups/revives, safe spawn union, stacked upgrades, boss phases, two downed, disconnect during every critical phase |
| PvP | Both spawn sides, 30/60/120 Hz rendering, aspect ratios, aim assist, corners/cover, trade kills, dash boundaries, overtime, forfeit/rejoin and repeated rematches |
| Integrity | Duplicate reward/rating settlement, restarted server, delayed finalization, account double-session, private-state reads, farming/collusion scenarios |
| Performance | Real release clients during dense co-op and PvP; multi-match server load, gateway overhead if used, sustained memory/bandwidth and frame times |
| Operations | Drained deploy, stale schedules, restart recovery/void outcome, backup restore, incompatible schema rollback, overload admission and service outage messaging |

Record device/OS/build, server region/version, SDK/generator version, ruleset, network profile and exact scenario. Include screenshots/video for controls, warnings and competitive fairness. Headless bots cannot approve touch comfort, attack readability or physical-device performance.

### Proposed measurable starting targets

These are reviewable budgets, not achieved results. Ratify them after M1–M3 measurements; revise explicitly if the intended devices/regions cannot meet them.

- Target 60 FPS on selected supported phones, with a documented p95/p99 frame-time budget and thermal-duration test; measure dense co-op for at least 30 minutes.
- At 20 Hz, aim for p95 simulation work below 25 ms and p99 below the 50 ms tick budget at the accepted allocation load, leaving operational headroom.
- Target p95 reconnect to playable state within five seconds after connectivity returns, while still inside grace.
- Initial ranked eligibility experiment: RTT at or below 150 ms with acceptable jitter; 200 ms remains an explicit degraded-condition test, not a promise of ranked fairness.
- Track correction-distance distribution; repeated visible teleports during ordinary movement or systematic wall-crossing are release blockers.
- Zero accepted unauthorized writes, duplicate terminal results, double reward/rating grants, cross-room leaks or damaging attacks without the intended warning contract.
- Set and publish a measured bandwidth budget after M3 rather than guessing before content/event payloads exist.

## 14. Main risks and decision points

| Risk | Response / decision gate |
|---|---|
| Community Dart SDK falls behind server protocol | Pin/test early; compare official-SDK gateway; stop the migration if neither passes native acceptance |
| Ported TS gameplay diverges from solo | Shared numeric data, stable IDs and fixtures; retain mode-specific values explicitly |
| PvP feels unfair under latency | Measure early duel; settle hit policy, competitive geometry, tick rate and regional admission before ranked |
| Co-op doubles visual/crowd pressure | Team-aware director and VFX budgets; preserve escape space rather than doubling enemies |
| Upgrade/pause design harms flow | Prototype synchronized safe breaks; preserve solo semantics; review pacing before full content port |
| Shared database saturates across matches | Measure transactional contention/load; allocation/sharding plan and admission caps |
| Reconnect grants advantage or corrupts rewards | Connection/life generations, no generic replay, authoritative recovery and idempotent ledgers |
| Public PvP has too few players | Private/casual first; visible waits, limited regions/hours if appropriate; defer ranked rather than fake opponents |
| Scope expands into commerce/social infrastructure | Keep purchases, ads, trading, voice/chat and guilds outside this release |

Before implementation, review: co-op/PvP formats, upgrade/downed rules, progression/reward separation and whether the proposed private-duel-before-full-co-op review order is preferred. Technology choices remain conditional on M1; tick rates, grace periods and balance numbers remain experiments until tested.

## 15. First implementation packet after plan approval

The first packet is **M0–M1 only**: record the solo baseline, create an isolated TypeScript module, pin candidate tools, implement two authorized test identities plus a tiny scheduled movement state, generate/test Dart bindings, and document native connection/reconnect/access results. Keep it outside the normal public game flow.

Its deliverables are reproducible local commands, a version matrix, automated protocol/access tests, an iOS/Android device checklist and a direct-SDK versus gateway decision. It does not migrate profiles, add purchases, change solo balance, deploy production infrastructure or claim playable full multiplayer. Once this gate passes, M2 connects the first private room to Regun's actual controls and presentation.

## 16. Research and evidence

Primary sources checked for this planning pass:

1. [SpacetimeDB language support](https://spacetimedb.com/docs/intro/language-support/): TypeScript server modules are supported and run on V8. This establishes language availability, not Regun throughput.
2. [SpacetimeDB official client list](https://spacetimedb.com/docs/clients/): Rust, C#, TypeScript and Unreal are listed; Dart is absent from that list.
3. [SpacetimeDB functions](https://spacetimedb.com/docs/functions/): transactional reducers, external-effect procedures and read-only views have different roles.
4. [Reducer documentation](https://spacetimedb.com/docs/functions/reducers/): schema/reducer patterns and execution context; exact scheduling API still needs a compiled spike against the selected release.
5. [Community Dart package](https://pub.dev/packages/spacetimedb): retrieved version 1.3.0 advertises SpacetimeDB v2, binding generation and offline mutation replay. These are maintainer claims; native compatibility is unverified here.

The retrieved vendor documentation displays a **2.0.0** version label while the locally installed CLI reports **2.12.0**. Do not infer exact API compatibility from these pages. Research caches are ignored local files under `.firecrawl/regun-multiplayer-*`; the public links above are the durable references.

Repository evidence: `lib/game.dart`, `lib/notifiers/game_notifier.dart`, `lib/components/game_utils/player_component.dart`, `lib/components/weapons/bullet_component.dart`, `lib/components/movement/boost_component.dart`, `lib/systems/combat_system.dart`, `lib/systems/encounter_director.dart`, `lib/systems/arena_geometry.dart`, `lib/systems/boss_encounter_runtime.dart`, `lib/services/run_store.dart`, `lib/data/loadout.dart`, `pubspec.yaml` and the existing tests.

No gameplay code or dependencies were changed for this plan. No network simulation, build, server load test or physical-device multiplayer validation was performed. The rules, architecture, budgets and milestone order above are recommendations for review.
