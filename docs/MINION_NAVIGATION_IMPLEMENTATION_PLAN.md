# Minion navigation repair — implementation plan

29 October 2026. **Execution specification; navigation changes are not implemented by this document.**

## 1. Objective and starting point

Repair the reproduced diagonal packing, mixed-speed deadlocks and collective boss-yield motion across native Solo/Training and authoritative online co-op. Minions should maintain their distinct combat roles, find usable approaches around slower bodies and bosses, and remain threatening without filling every accessible lane.

This is a navigation correction, not a weapon/health/speed rebalance. It includes code, shared contracts, regression tests, reproducible visual evidence, performance measurement, release validation and backend rollout verification. A headless pass does not close human comfort/difficulty acceptance.

Starting references:

- [Investigation, role inventory and reproductions](MINION_MOVEMENT_INVESTIGATION.md).
- Client checkpoint: **768f1d9b13178018fb6a334cedfd6e5575ceaf1c**; parent `61ce9852b4e0a647e16e0dbe7f93a3fda4a91de8`.
- Server baseline: `0516da57de14a96e9cb5b7aadc1c7ecd911a94a3`; sibling `../regun-server`, clean at planning time.
- Source release is **1.0.0+28**. A build-29 distribution record is not a source-version change or permission to overwrite release identity.
- Latest baseline verification: **analyzer clean; 973 passed /5 intentional skips (`make verify`)**; server **typecheck clean; 216 passed; module build successful (`npm run verify`)**. Raw evidence belongs in `docs/validation/minion-navigation-baseline-2026-10-29/`.
- Current baseline already includes Lodestar normal Solo/Rush/online admission, capability 11, armored head/core, segmented ground occupancy and connected shutdown. Preserve all of it.

Baseline symptom: the real native scene with 36 mummies and one scorpion reaches median mummy spacing 94.11, near its 94-unit hard minimum, with 35/36 mummies reporting blocked at 30s. Homogeneous pursuit also packs. The fixed-boss yield probe switches 101 times in 5s. These are scenario-specific reference measurements, not universal acceptance thresholds.

## 2. Contracts that must remain true

- Keep body radii, circle/capsule cover clearance and swept movement authoritative. No teleporting, phasing through living bodies, shrinking hitboxes or pushing ordinary enemies through walls to hide a jam.
- Keep all primary weapons, ammunition, reloads, damage, XP, rewards, encounter admission and population limits. The emergency 120-enemy cap is not a crowd target. Do not lower spawn counts as the primary fix.
- Keep Scorpion 60, Mummy 95, Revenant 80, Skitter 105 ground/1050 leap, Warden 55 and Burster 90 base movement; existing elite/cycle/status multipliers apply. A smarter approach can change difficulty and still needs review.
- Keep Mummy 36-unit melee reach, .15s opening/.6s repeats and cover checks. No raised strike while approaching, remote damage or through-crowd melee extension.
- Keep Skitter 480 commitment, .75s warning, 180–520 committed leap, 1.4s recovery and nearby attack turn-taking. Airborne travel ignores ordinary bodies but respects solid cover and grounded boss footprints. Never steer a released leap toward a new target.
- Keep Warden/Burster/Revenant planted attack timing. Boss telegraphs, release geometry and collision paths cannot bend after commitment.
- Keep all grounded boss bodies, both actors of permitted boss pairs, Walker flight/charge layers, Ariet airborne behavior and escort planning. Preserve existing boss collateral policy; navigation cannot add minion kills/rewards or attack cancellation.
- Lodestar remains one occupancy/combat owner with multiple current ground shapes. Respect clipped burrow masks, emerging sections and inert spine/wreck occupancy through the existing lifetime. Never substitute its 500-unit fallback radius for its actual segmented footprint. Head death removes offense without prematurely removing physical remains.
- Keep living actors, pending spawn reservations, ground blockers and damage targets as distinct concepts. A warning reserves an arrival but is not a living steerable minion. A wreck can be solid after offense/health is gone.
- Pause, picker, entrance, reveal, background and Training recovery must freeze navigation time and clear/hold commands through the existing authority. No wall-clock timeouts. Reduced Motion changes presentation, not routes or collision.
- Online remains server authority. No new client-supplied enemy position, velocity, target, phase or collision outcome is trusted.

## 3. Chosen architecture

Use a **role goal planner + bounded velocity candidate solver + swept occupancy finalizer**. Keep the engine and authored role state machines. Do not add an external avoidance library, full-world A* per actor, or global fixed formation slots.

Proposed pure modules are deliberately portable between Dart and TypeScript:

| Layer | Native files | Server files | Responsibility |
|---|---|---|---|
| Contracts/tuning | `lib/systems/minion_navigation_frame.dart`, `minion_navigation_policy.dart` | `spacetimedb/src/minion_navigation_frame.ts`, `minion_navigation_policy.ts` | Stable IDs, simulation time, bodies, phases, desired speeds, target state, bounded constants. |
| Goal/escape decisions | `lib/systems/minion_navigation.dart` | `spacetimedb/src/minion_navigation.ts` | Role approach, bypass commitment, progress state, density-aware goals and intentional holds. |
| Local velocity selection | `lib/systems/crowd_steering.dart` | `spacetimedb/src/crowd_steering.ts` | Candidate generation, clearance prediction, deterministic scoring and hysteresis. |
| Boss navigation adapter | `lib/systems/boss_navigation.dart` | `spacetimedb/src/boss_navigation.ts` | Actual occupancy shapes, grounding, intended movement and committed path descriptors. No new combat simulation. |
| Cover navigation | Existing `obstacle_router.dart`, `arena_geometry.dart` | Existing `navigation.ts`, `rules.ts` | Static/dynamic route legality, clearance, bounded/cached detours. |
| Final placement/movement | Existing `crowd_occupancy.dart` | Existing occupancy helpers currently in `actors.ts` / `rules.ts` | Swept legal motion, all relevant blockers, pending reservations and shape contact. |
| Integration | `game.dart`, ordinary enemy components, `CombatEnemy` | `actors.ts`, `survival_runtime.ts` | Authority-owned planning/commit order, lifecycle, attack phase exclusions and contacts. |

Names may be consolidated when implementation shows a clearer boundary; responsibilities and acceptance gates remain mandatory. Avoid leaving two competing movement paths active.

### Frame and state contracts

`NavigationBody` includes stable owner ID, ordinary/boss/reservation kind, role, position, achieved velocity, footprint, grounding, mobility/phase and desired speed. Boss footprints include circle or clipped capsule primitives with owner IDs. Broad-phase indexing must cover each shape's full swept bounds, not just its root or capsule endpoint.

`NavigationTarget` includes authoritative player ID, position and bounded measured velocity. Native uses actual accepted player travel, including cover/weapon weight, rather than raw joystick×base speed. Prediction retains existing lead caps. Discontinuities such as Continue, landing and respawn reset the velocity sample. Co-op retains existing target hysteresis and invalidates the plan on a genuine target change.

`NavigationMemory` owns approach/bypass side, current intermediate goal, obstacle owner, last accepted velocity, progress window, hold/replan deadlines and bounded waiting age. It is keyed by stable combat/actor ID, not render order or pointer addresses. Fixed hash-derived choices use a documented integer hash; no language-default `hashCode`, floating sine hash, or per-frame global RNG consumption.

`NavigationDecision` returns goal/desired velocity, mode and reason. Reasons distinguish pursuit, bypass, melee/cast hold, boss yield, no legal route, density wait and frozen/retired. Diagnostic labels must not turn a navigation failure into a success merely by calling it a hold.

### Authority-owned movement step

Ordinary movement needs explicit describe/plan/commit/post-move phases, so sorting sprites by Y cannot decide who gets space first:

1. Advance only active simulation/status/phase clocks once; consume external displacement through the existing collision path.
2. Gather authoritative target/body/phase/shape data and pending arrival reservations. Snapshot at a documented simulation boundary.
3. Describe ordinary pursuit requests. Planted attacks, frozen actors and committed airborne movement do not enter ordinary replanning.
4. Plan goals and velocities from the same immutable frame. Process stable IDs with bounded waiting-age fairness for conflicts, independent of render Y and container iteration order.
5. Commit legal movement through the live swept occupancy finalizer. Later commits see accepted positions/reservations, and can safely brake/stop if predictions conflict. Refresh shape queries where boss machinery actually moved.
6. Run the existing contact/release checks and update gait from accepted displacement, preserving test-defined strike/warning boundaries. Rejected or superseded movement must not emit a hit.

The first integration slice must trace current `CombatEnemy`/Flame update order, recoil/pulse movement, actor phase changes and mechanical 120Hz callbacks. Split ordinary role updates explicitly rather than moving actors twice or silently shifting attack clocks into a generic planner. Do not rewrite boss attack state machines just to obtain movement order. Use parity/timing tests to settle any unavoidable one-step boundary difference before broad adoption.

Native rendering remains at its existing frame cadence. Server combat currently ticks at 50ms; mechanical rigs retain their 120Hz internals. Planning consumes active simulation time with a bounded accumulator, not frame counts. Run local decisions at up to 10Hz initially, staggered by stable ID; evaluate immediate invalidation each movement step. Goal re-evaluation is slower, around 4Hz, unless progress/geometry/target invalidates it. Those rates are initial candidates to measure at30/60/120Hz, not a claim that lower-rate planning is already smooth. Committed decisions never skip final collision each step.

### Goal and bypass behavior

Normal pursuit starts with existing role intent. Avoid chasing the same center through a dense core: sample a small set of reachable approach directions relative to the player and open local corridors. Goals are temporary free-space opportunities, not permanently assigned evenly spaced ring positions.

An enemy that makes insufficient goal-relative progress across an active-time window evaluates bypasses around a slower body/cluster. Prefer a route that can make actual progress while respecting cover, boss footprints and other planned goals. Hold the chosen side for long enough to execute it; re-evaluate when the blocker dies, moves away, target changes or the route becomes illegal. Density pressure acts before hard contact. Genuine full enclosure allows a planted wait; an available bypass must not be ignored indefinitely.

Initial tuning candidates: .6s progress window, 12-unit meaningful progress, .8–1.6s bypass commitment and a .25s minimum interval before choosing another side. Scale progress checks to desired speed and goal displacement; slow/frozen/knockback actors and valid melee/cast holds are not false jams. Do not reset progress merely because an actor shuffles sideways repeatedly.

Co-op pressure may remain directed at the current target; don't add target switching merely to improve metrics. Avoidance has no knowledge of a future player input and cannot home a committed attack.

### Velocity solver and final collision

Start with at most 32 candidates per active decision: preferred/current velocity, zero, bounded angular alternatives at several speed fractions and the committed bypass tangent. Normal pursuit can turn toward a better path; preserve speed caps. Candidate scoring considers expected progress, swept body/solid clearance over a short horizon, current lane density, change from accepted velocity and commitment/wait priority. Collision/cover legality outranks progress.

Initial ordinary horizon .6s; use relative neighbor motion with bounded predicted acceleration assumptions. Query a spatial index expanded by actor speed, neighbor speed and body extent. Large/fast boss sweeps use their separate motion descriptors, not a neighbor-radius cutoff that can omit them. A bounded query/candidate budget must fail by slowing/stopping, never by ignoring nearby collision blockers. Zero steering remains zero in both languages; do not normalize a nearly cancelled result into full speed or default +X.

Keep final substepped occupancy authoritative. Improve the fallback to evaluate all actual contacts at the earliest collision, with stable tie-breaking and valid residual tangent options; do not select an arbitrary first neighbor from grid traversal. Cap catch-up work and preserve existing maximum step safety. Continuous external impacts still use existing force budgets/mass resistance, not ordinary route goals.

### Boss movement/yield policy

Export navigation descriptors from the current authoritative boss state: current grounded shapes, desired velocity/route segment, stationary phase, optional committed swept path and interval. Ordinary minions react to predicted body/path contact. A planted boss remains an obstacle but does not order everyone along an imaginary forward corridor.

Consider all active grounded bosses and valid remains. Yield toward reachable free space with a committed side and separate enter/exit margins. Example starting margins: begin prediction inside footprint+24, clear the yield only beyond footprint+56 or when the threat ends; validate against minion speed and actual time to contact. The final geometric clearance is unchanged. Never reserve an entire attack damage area as permanent movement exclusion, erase hazards or forbid player escape lanes.

For Lodestar, use section ground primitives and masks at their actual poses; a moving or exposed tail is not represented by the head's center-to-player direction. For Ariet, keep airborne carrier out of ground blocking and preserve escort coordination. For Walker, match charge/brake airborne rules and grounded landing. Compound-body contact normals use the contacted primitive, not the compound root.

## 4. Ordered implementation milestones

Each milestone is a reviewable client/server commit pair where applicable, with exact counterpart hashes recorded. No deployment is required to run local or disposable-server validation.

### M0 — Checkpoint and executable symptom fixtures

- [x] Inspect all current client changes and pin the clean sibling backend revision.
- [x] Save current code/art/investigation as the checkpoint above.
- [ ] Preserve raw baseline positions/metrics and add fixed-seed scenarios for mixed/same-type mobs, boss boundary and static Foundry cover without dynamic solids.
- [ ] Promote the bug-specific scenarios from `tool/` into meaningful regression tests as each repair lands; retain probes for comparative diagnostics.
- [ ] Define a reachability witness for jam assertions: authored known-free bypass/corridor or independently checked bounded route. Exclude legitimate full enclosure, no-target, attack holds and reachable-contact waits.
- [ ] Record baseline call order, actor priority effects and timing; pin normalized Dart/TS inputs and expected invariants.

**Exit:** current checkout consistently exhibits the symptom; a bad packed solution cannot pass solely because spacing/speed remain legal. Tests describing desired behavior should be introduced with the relevant implementation, not leave main permanently red.

### M1 — Shared navigation frame, lifecycle and static/dynamic routing

- [ ] Add the portable frame/state/decision contracts and deterministic ID/hash convention.
- [ ] Gather achieved velocity and actual current footprints; preserve one compound owner and separate pending reservations.
- [ ] Establish ordinary two-phase movement integration, independent of render ordering, without duplicate role/status updates.
- [ ] Route when the requested path is obstructed by any solid. Remove the native dynamic-obstacle-only gate; use one target-aware router for static and temporary cover.
- [ ] Cache route data by geometry revision/body clearance/goal; invalidate on pod/sentry changes, boss footprint/path changes, restart/restore and removal.
- [ ] Port shared normalization/zero behavior and update boundary to server; keep existing co-op target hysteresis.
- [ ] Trace all pause/picker/entrance/recovery/destruction lifetimes. Remove navigation memory and reservations on retirement and pending-load failure.

**Exit:** static Foundry routing works without an airdrop/sentry; adding unrelated dynamic cover does not toggle unrelated route quality. Render priority/permutation cannot select a different pursuit side from the same navigation state. Current attack/reload/status timing tests still pass.

### M2 — Mixed-speed bypass and crowd goal selection

- [ ] Add progress windows measured against goal progress, not mere displacement.
- [ ] Add stable bypass decisions and reachable intermediate goals around slow bodies, nests, sentinels and congested groups.
- [ ] Distinguish valid melee/cast waiting from a rear actor with an available route; bound starvation and invalidate dead obstacles immediately.
- [ ] Exercise the exact one-scorpion/mummy case with retreat, hold, turn and scorpion death; repeat with Warden/nest/sentinel and all-mummy/all-scorpion packs.
- [ ] Verify no target leak into movement RNG/checkpoint behavior and no additional contact reach or attack cancellation.

**Exit:** mixed-speed actors take a usable detour around an isolated slower blocker in the authored witness scenes, without teleporting, body overlap or indefinite waiting. Dense packs show fewer sustained stalls while retaining closing pressure. The stationary-surrounded-player scene is inspected, but zero blocked actors is not required or physically sensible.

### M3 — Predictive local steering and fair collision commit

- [ ] Add bounded candidate velocities, spatial relative-motion queries, stable scoring and deceleration.
- [ ] Carry chosen velocity/side between decision steps; smooth ordinary turns only within legal collision/speed bounds.
- [ ] Integrate waiting-age fairness and stable commit arbitration with movement independent of sprite render priority.
- [ ] Replace first-blocker-only fallback with earliest/multiple-contact handling; use compound primitive normals and exact swept legality.
- [ ] Verify head-on/two-way traffic, overtaking, crossing flows, blocked-corner escape, reverse player direction and bursty frame timing.
- [ ] Recheck external recoil, upgrade pulses, grenade blast displacement, Frost/Spore holds and planted bodies.

**Exit:** no through-body shortcuts at normal/elite/cycle/fast-attack speeds; no full-speed normalization near zero. Mixed-pack jam reduction persists across seeds and actor permutations rather than moving the jam to another angle.

### M4 — Phase-aware multi-boss navigation

- [ ] Implement descriptors for all current boss motion families: Shadow; Demon/Queen; Bellkeeper/Magistrate/Sovereign/Marshal; Walker; Ariet/escorts; Lodestar. Mirror Saint stays retired from normal admission; retain any existing legacy/test compatibility.
- [ ] Replace fixed rectangle yielding with predicted geometry contact, side commitment and exit hysteresis.
- [ ] Handle every actor in allowed boss pairs and the first-boss-airborne/second-grounded case. Do not admit Ariet/Lodestar into random pairs to manufacture test coverage; geometry-only fixtures can exercise compound interactions.
- [ ] Cover static/recovering/charging bosses, boss approaching mobs from behind/side, nearby cover and disappearing footprints.
- [ ] Preserve Lodestar masks/ground sections/inert wreck and Walker landing; keep existing boss crush/no-reward behavior exactly where already authorized.
- [ ] Ensure planner decisions cannot cancel or retarget boss warnings, lower attack coverage, change damage or create a guaranteed player-safe zone.

**Exit:** stationary bosses cause navigation around their bodies without corridor chatter. The fixed-boss boundary test has at most two yield-mode transitions per encounter with that static boundary, instead of 101/5s. Minions clear predicted body paths when room/time permit; safe failure remains possible when physically trapped and cannot be misreported as perfect navigation.

### M5 — Role and presentation pass; save/restore compatibility

- [ ] Scorpion: broad independent flank opportunities without paired rank-like arcs. Mummy: contact/bypass goals while preserving walk/strike; Revenant: reachable clear-shot approaches and crowd-aware retreat.
- [ ] Skitter: ground planning only, retained leap commitment/turn-taking/landing occupancy; Warden: slow pressure and shield phase; Burster: prediction until planted warning; nest/sentinel stay fixed.
- [ ] Preserve Ariet's pressure/intercept roles, rig motion and partner traffic policy; use shared collision geometry without running two competing local solvers.
- [ ] Use measured movement for gait; stop Scorpion walking-in-place when appropriate. Add bounded deterministic gait/approach phase variation only if captures show remaining lockstep. No new texture assets or random wobble are needed.
- [ ] Save optional bounded `navigation` state keyed by existing combat IDs: version, seed/hash choice, committed side/goal, validated obstacle ID and simulation-relative remaining holds. Read older saves without it. Missing/corrupt optional transient state falls back safely; malicious/unbounded values cannot allocate arbitrary memory or restore illegal motion.
- [ ] Restore target/geometry references only after actors/reservations mount. Revalidate routes; reset achieved-velocity samples. Do not replay damage or preserve a dead obstacle lock. Pause/Continue/restart/Training recovery have explicit reset rules.
- [ ] Server persists only authoritative bounded planner state where runtime reconstruction requires it; keep private route history off public snapshots. Existing client snapshots/interpolation remain authoritative presentation only.

**Exit:** role timing/identity and all current content still work; old and new checkpoints resume safely. Presentation is neither synchronized walking-in-place nor noisy twitching, including Reduced Motion. No schema/capability bump is assumed unless integration demonstrably requires a wire-contract change; if needed, add explicit mixed-version discovery/tests before rollout.

### M6 — End-to-end validation, measurement and release

- [ ] Run the complete scenario matrix below in native and TS at fixed seeds and multiple timing schedules.
- [ ] Run full client/server verification and explicit long soaks. Build normal release candidates and inspect actual runtime renders/motion, not just scatter plots.
- [ ] Run a disposable real-server transport session with 1/2/3 authenticated test clients: moving mobs, slow blocker, boss, pause/selection lifecycle, target disconnect and joining mixed supported clients. Keep all test-only staging outside production reducers.
- [ ] Capture candidate/backend commit hashes, fixture hashes, results and limitations in `docs/validation/minion-navigation-<date>/`; update this plan, investigation, progress and playtest guide with final behavior.
- [ ] Establish a paired rollout/rollback record: matching server revision and client candidate, backend compatibility, online policy state and known open device gates. Keep source push, module rollout and authenticated WAN verification separate claims.
- [ ] Build/install through existing native channels when execution reaches device review; distribute using the creator's intended tester channel and actual release identity. Increment version only as an explicit release decision, not incidentally inside navigation work.
- [ ] Verify deployed movement with an authenticated session and distinguish that from health/schema reachability. Preserve backend state volumes, account/auth/epoch/sequence rules and online availability.
- [ ] Physical review on iPhone and representative Android: mixed mobs, both arenas, boss crowd lanes, thumb comfort, readability, frame pacing, sustained heat and difficulty. Log actual device/build/time and feedback.

**Exit:** automated behavior/collision/performance gates pass; actual visual evidence supports the repair; compatible client/server candidate is traceable. Human acceptance can remain explicitly open until performed, but the fix cannot be called physically accepted on test/installation evidence alone.

## 5. Test and acceptance matrix

| Area | Required scenes | Evidence/gate |
|---|---|---|
| Reported symptom | 36 mummies+one scorpion; scorpion in front/middle/side; retreat→hold→turn; blocker death; baseline seeds 7/19/43 plus at least 7 more | Per-actor progress/mode/blocked duration, trajectories, visible density and captures. No persistent rigid diagonal core with a witnessed open bypass. |
| Same-type/mixed roles |12/36/48/60 ordinary actors; mixed Warden, planted caster, nest/sentinel; capped120 stress | Collision/speed invariants; no starvation in authored feasible passages. Do not demand every actor can simultaneously occupy melee range. |
| Traffic/geometry | Head-on pair, crossing streams, overtaking, three-body wedge, all approach angles, negative coordinates, arena corners | Rotation/translation/permutation fixtures; preserve legal path and avoid arbitrary grid-direction bias. |
| Static/temporary cover | Both maps; Foundry columns with no temporary solids; pods/sentries far away and at wall; appearance/removal/breakdown | Same obstruction invokes same planner; clearance and pending reservations preserved; no source-of-cover gating. |
| Bosses | Every active family grounded/stationary/moving; permitted pair roster; airborne/grounded transitions; Lodestar masked segments and inert remains | Correct current/swept footprints; no constant corridor orders, chatter, boss blocking from avoidable traffic or lost collision authority. |
| Combat interruption | Knockback, recoil, pulse, grenade blast, freeze/Spore, elite/cycle scaling, Skitter warnings/flight, boss lethal shutdown | Existing damage/timing/telegraph/reward tests plus new movement contacts. No unintended invulnerability or attack/reward changes. |
| Lifecycle/persistence | Pause/background/picker/entrance/recovery; Continue before/after bypass; old/corrupt saves; restart/dispose during loads | Active-time freezes, bounded reset/restore, no leaked memories/reservations/late actors or RNG drift. |
| Co-op authority |1/2/3 clients; competing targets, target hysteresis, death/disconnect/rejoin; capability 11 and compatible mixed clients | Shared fixtures and real transport; no client enemy authority, no extra traffic for private planner state. |
| Timing/performance | Native 30/60/120Hz plus variable 16–80ms frames; server 20Hz; solver fixtures at matching 30/60/120Hz; long hitch safety | Outcome tolerances and collision invariants, bounded query/candidate/substep counts, timing/allocation trace, memory cleanup. Native/20Hz positions need not be bit-identical. |

### Initial measurable gates

These are proposed engineering targets to validate in M0; change them only with recorded scenario evidence, not to conceal a failure:

- **Safety:** zero new body/cover crossings or unbounded speed across the matrix; contacts within existing numeric tolerances. Test the full segment, not only the endpoint.
- **Witnessed overtaking:** in an open, authored single-slow-blocker setup, at least 90% of eligible pursuers pass the blockage or reach their valid combat goal within the route-length/speed allowance plus 2 active seconds. Exact feasible allowance comes from the authored witness path; valid holds are not credited as successful bypasses.
- **Sustained crowd stalls:** at least 50% reduction in total avoidable >1.5s stall time versus baseline across moving-target mixed-pack seeds, with no seed regressing by more than 10%. Classify reachability consistently between baseline/candidate; also inspect per-actor worst cases so averages cannot hide starvation.
- **Boss chatter:** the static-boundary fixture has at most two yield transitions; general yielding has committed sides and no rapid oscillation on a fixed threat. New threats/invalid routes may cause legitimate transitions.
- **Threat:** route improvements do not turn mobs into permanent orbiters. Record closing distance/contact opportunities alongside stall reduction; compare normal unarmed kiting and ordinary shooting scenarios. Final difficulty is a player decision, not a contact-count maximization objective.
- **Variation:** no per-frame noise; measure persistent close-packed neighbor relationships, not heading alignment alone. Natural enemies chasing one player can legitimately move parallel.
- **Compute:** at most 32 velocity candidates per decision; local spatial queries; capped replans/substeps; no unbounded catch-up. Profile full navigation at 60 actors plus worst admitted boss geometry. Initial native budget target≤2ms p95 of the navigation slice on the chosen representative device, with full 60Hz frame pacing assessed separately. Measure server 20Hz CPU/headroom against its pre-change trace. These are targets, never claims based on laptop test duration.
- **Memory:** bounded per-actor state, no actor references retained after teardown; repeated restart/Continue/disconnect tests return to the pre-run footprint. Preserve current art/texture budgets.

## 6. Shared fixtures, tooling and validation commands

Create `test/fixtures/minion-navigation-v1.json` in the client and a byte-identical packaged copy under server `shared/`. Define one canonical export/sync command and verify fixture hashes in both repositories; CI must not require an adjacent checkout. Include stable IDs, units, geometry, timing, role/phase, seed, target state, expected legal decisions and tolerance. Numeric comparison uses explicit tolerances appropriate to Dart Vector2 Float32 and TS numbers. Compare discrete side/phase/zero decisions exactly where specified; compare trajectories at aligned sample times with bounded tolerance and invariant outcomes.

Proposed focused additions: `test/minion_navigation_test.dart`, `crowd_steering_test.dart`, `boss_navigation_test.dart`, `minion_navigation_integration_test.dart`, `minion_navigation_checkpoint_test.dart`; server corresponding `*.test.ts`. Extend existing crowd/tactics/temporary-cover/mummy/Skitter/Ariet/Walker/Lodestar tests rather than duplicating their combat contracts.

Keep the two existing probes runnable for before/after JSON. Add a developer-only seeded scene/capture harness for repeated normal-speed motion and body/goal/route overlays, with no production menu controls or shipped staging reducers. Capture dots/paths **and actual enemy artwork**; synchronized gait or body-facing problems can be invisible in center plots. Export a deterministic summary of stalls, contacts, replan/side switches, query counts and solve time.

```sh
# Client baseline/full verification
make verify
# Existing diagnostic comparison (outside normal suite)
flutter test --no-pub tool/crowd_movement_probe_test.dart tool/crowd_native_probe_test.dart --reporter expanded
# New focused tests after their milestones land
flutter test test/minion_navigation_test.dart test/crowd_steering_test.dart test/boss_navigation_test.dart test/minion_navigation_integration_test.dart test/minion_navigation_checkpoint_test.dart
# Explicit long simulations
make soak
# Sibling backend: typecheck + test + module build
cd ../regun-server
npm run verify
```

Run local transport with the existing server harness patterns plus the new private movement scenes. Record the actual command used once the harness is implemented; do not invent a completed smoke script in the evidence.

## 7. Risks, rollback and review boundaries

| Risk | Control |
|---|---|
| Smarter movement becomes much harder to kite | Preserve speeds/attacks/population first; compare pressure, reload windows and escape lanes before tuning difficulty. |
| Avoidance replaces a grid with orbiting or twitching | Reachable temporary goals, progress-based recovery, side hysteresis and actual-motion review; no fixed ring slots/random noise. |
| Refactoring Flame updates duplicates movement/status/damage | M1 call-order trace, single ownership, real component timing/contact tests and old/new checkpoint coverage before broad role changes. |
| A sparse neighbor query misses a large/fast boss | Full swept AABB indexing for shape primitives; final collision always considers relevant blockers. |
| Compound boss avoidance uses wrong normals or buried geometry | Contacted clipped primitive determines clearance/normal; reuse existing authoritative masks and lifetime. |
| A body remains frozen/removed while a route still references it | Stable IDs, immediate invalidation, bounded memory and lifecycle teardown tests. |
| Native/server drift returns | Versioned shared fixtures, shared numeric/hash/zero rules and matched commit evidence. |
| Server updates impact active room continuity | Keep public contract compatible where possible, handle missing optional planner state, test reconstruction and release during room lifecycle. |
| Performance regresses in crowded frames | Bounded/staggered planning, cached geometry, spatial queries, measured native/server traces and capped catch-up. |

Checkpoint rollback preserves the whole pre-navigation client. Each milestone remains revertible as a matching client/server pair; new optional navigation state must be ignorable when reverting. No destructive server state reset, wholesale actor teleport or silent disabling of crowd occupancy is an acceptable rollback. A developer-only old/new comparison mode may exist during diagnosis, but remove it from the final production path once validation passes.

Reviewable deliverables are: this completed checklist; paired source commits; passing shared/role/integration tests; before/after native motion and position captures; measured performance evidence; old-save and co-op transport results; exact candidate/backend identities; updated brief player playtest instructions; and an honest list of remaining physical/WAN acceptance items.
