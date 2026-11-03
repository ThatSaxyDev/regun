# Regun Survival Maps PRD and Implementation Plan

**3 November 2026 · Proposed · First implementation target: Foundry in Training**

## 1. Product decision

Deliver four Survival arenas: rebuild Breach and Foundry and add Floodworks and Relay Graveyard (working names). Give each a recognizable place and a different combat decision. Keep the existing 4,512 × 4,512 world footprint for the first comparison. Foundry gets hard cover with deliberate sightlines and a localized vent crossing. Breach keeps its open ground and uses landing sites to give its existing supply drops different tactical costs. All four get open boss ground and landmarks you can recognize while aiming on a phone.

A successful map gives the player reasons to choose where to fight. A player should be able to describe a decision such as “I went around the presses to reload, then cut across the cooling plates before they fired.” The environment should also tell you why Rook is here. Breach is a failed evacuation line. Foundry is a working industrial system running after its crew has gone.

**Delivery scope.** Four authored Survival layouts, their Training equivalents, matching co-op geometry and behavior before general rollout, map presentation in loadout, compatibility for saved runs, and a repeatable map validation workflow. Dedicated Versus layouts are a separate product track. The four-arena roster is the release scope. Prototype the new maps alongside the reworks and validate each in Training before finishing its art.

## 2. Baseline and constraints

| Area | Current behavior | Design implication |
|---|---|---|
| Authored geometry | The Survival TMX provides the shared footprint, empty Breach solids, six Foundry columns and 25 vent anchors. | Use Tiled as the source of truth. Compare candidate layouts against the current map with the same camera and controls. |
| Foundry vents | Solo considers a vent every six active seconds after a boss defeat while no boss is active. It picks the closest anchor, with a 115-unit radius, 1.2-second warning and 1.5-second active phase. | Preserve the established warning cadence for the first comparison and test deliberate vent placement separately. |
| Breach drops | Native selection samples valid points in the visible floor. One pod at a time, 260-unit capture radius, eight active seconds inside and a 50-second lifetime. The landed pod is temporary cover. | Add authored site preference to the existing selector. Keep a validated fallback for camera positions with no eligible site. |
| Player movement | Manual aim, movement, dash and independent grenade aim all compete for attention. | Broad connectors, readable silhouettes, and safe exits matter at phone scale. Use the actual collision edges when measuring width. |
| Crowd and bosses | Bodies occupy space, attacks commit to paths, and boss geometry includes safe pockets and projected warnings. | Check traversal and avoidance with large bodies, mixed packs and active attack footprints. An empty-map walk is only the first test. |
| Runtime | Solo and online each simulate gameplay. Co-op uses the Survival arenas and the server owns authoritative collision and damage. | Publish compatible map revisions and keep the two simulations aligned. |

## 3. Design requirements

| ID | Requirement | First acceptance check |
|---|---|---|
| MAP-01 | Three readable districts per arena. Give each a recognizable silhouette, a combat purpose, and connections to the other districts through a loop or bypass. | On a phone, a player can name or describe at least two districts and predict which route leads back to the open ground. |
| MAP-02 | Keep an open deployment and boss ground. Two distinct retreat options must remain usable when an encounter or hazard pressures one route. | Test with ordinary crowd occupancy, large bosses, pairs in Training, and the smallest supported visible world area. |
| MAP-03 | Solid props must visibly meet their collision footprint and provide a real tactical benefit. Each major cover island needs a way around either side. | Dash, fire, ricochet and throw along all four faces and diagonals. Verify enemy routing and player escape on both sides. |
| MAP-04 | Distinguish safe, warning, active and cooling vent states by shape and material, supported by local audio. | Players can identify the warning with sound off and Reduced Motion enabled. Damage matches the marked floor. |
| MAP-05 | Breach drop sites must offer distinct approach and hold costs. Landing, capture and escape remain feasible with the pod body present. | Complete, abandon and revisit drops in each district. Check the capture boundary, cover, rewards, and expiry. |
| MAP-06 | Arena changes must preserve valid spawns, pickup access, camera framing and saved runs. | Run geometry fixtures, old-save restore cases, wide and compact viewport checks, and solo/co-op replay scenarios. |
| MAP-07 | Environment art must support combat readability and the existing mobile frame and memory budgets. | Compare the same worst-case fight on baseline and candidate builds on reference phones. Include boss-pair texture pressure. |

### Boss access and retreat

Every district and connector available during a boss encounter must remain contestable. For ground bosses, the default is physical access through the player's retreat routes. Check continuous swept paths against each boss's actual collision footprint and movement rules, including turns around cover and temporary pod placement. Where a route is too tight, widen it or move the obstacle. For bosses with a distinct movement model, verify they can reposition or attack the space through their normal mechanics while honoring cover and warning rules.

Cover can buy a reload or a change of direction. It must never let a player hold a position indefinitely or deal repeated damage to a boss that cannot reach, reposition around, or threaten them. Preserve two usable retreat directions from primary fight areas. Test crowd and pair occupancy as well as static clearance. Keep the open boss ground as a natural place to fight, with the rest of the arena still connected and usable.

**Acceptance.** In Training, lure each boss through every major connector and around every cover island in both phases. Try holding and firing from each corner and behind a landed pod. Repeat representative large-body pairs and co-op retreats. A reproducible body jam, unreachable firing position or only escape blocked by geometry fails the layout gate. Correct the layout before adjusting boss speed, damage or attack reach.

### Optional enclosed encounters

Standard Survival bosses use the open arena. If a future encounter requires a sealed fight space, the encounter takes control and carries the player to a safe authored landing point inside it. In co-op, deploy all living players together at separate safe points. Show the perimeter and landing sequence before enabling combat. Reuse the deployment timeline where it fits: clear held inputs, freeze encounter damage during transfer, and provide a Reduced Motion relocation cue. Start the boss only after landing, restore the enclosed encounter consistently on Continue or reconnect, and release the boundary when the encounter ends.

## 4. Foundry layout

### 4.1 Spatial brief

| District | Placement hypothesis | Tactical role | Environmental story |
|---|---|---|---|
| Rail Loading Lane | West side, oriented north to south, with exits into the upper and lower yard | Longest clean shot. Easy to see approaching packs. Crossing the exposed stretch while empty is costly. | Rail stops, chalk load marks, dropped cargo slings and a half-loaded wagon outside the primary route. |
| Press Yard | East of the center, with two offset machines in the first blockout | Short-range approach, cover to reload, and a choice of which side to round. The offset prevents both presses from forming one straight wall. | Bolt plates, oil channels and pressed scrap tell the player what the machines did. Use solid machine bases and flat, passable debris. |
| Furnace Crossing | South connector between rail and presses, with a dry bypass farther south | Shortest rotation crosses plates. The bypass stays dry and costs time. Both return to open ground without requiring a dash. | Cracked supply pipes lead from the furnace to flush vent plates. Scorch is concentrated inside the danger footprint. |
| Casting floor | Open ground shared by the three districts | Deployment and large fights. Wide transitions lead toward the rail and the press yard. | Broad pour marks and a broken crane rail give orientation without interior blockers. |

```text
                      NORTH CONNECTOR
                  /          |         \
        Rail Loading      Casting      Press Yard
             Lane           Floor       (two islands)
                  \          |         /
                   +-- Furnace Crossing --+
                   |     vent shortcut     |
                   +------ Dry Bypass -----+
```

Route sketch. Lines show connections. Distances and collision footprints come from the Tiled blockout.

The casting floor is a shared combat space, not a fourth district. In Tiled, start with the west lane near x=1,050, a central clear area centered near x=2,250 and y=2,000, press islands around x=3,200, and the vent crossing near y=3,150. Coordinates are top-left TMX world coordinates and describe test placements. Fit the final footprints to actual collision and camera probes. Prototype two machine bases of roughly 220 × 140 and 180 × 120 units. Reserve roughly 1,600 × 1,200 units of contiguous open casting floor for the initial probe and enlarge it if live attack tests require it. Use 320–450 units of clear width as a starting point for main connectors and at least 260 for an alternate route. Increase clearance where a boss body plus occupied escape lane requires it.

Compare **F0** (current columns and vents), **F1** (new route geometry with vents disabled for the geometry test), and **F2** (same F1 with authored vent behavior). Include a current geometry run with vents disabled when isolating layout effects. Hold encounter inputs and loadout constant. If the press yard becomes a permanent camp, test moving the cover away from the perimeter or increasing the opening behind it before touching weapon damage or enemy counts.

### 4.2 Vent rules

1. Replace grid dependence in the candidate with authored groups tied to the furnace crossing. Choose eligible plates near occupied play space. Commit position at the warning and let it finish at the displayed location.
2. Start with one warning or active group at a time, the current radius and warning/active durations, and the post-boss activation gate. Give the floor a clear cooling state during the interval before another vent. Tune group locations and the dry bypass before increasing damage or frequency.
3. Delay a warning if the group would cut the only viable exit, overlap deployment or recovery, or exceed the simultaneous hazard budget. Use authored exclusion regions and encounter state for the first pass. Test dynamic crowd blockage separately.
4. During a boss encounter, suspend new vent commitments by default. When a boss becomes due during a committed vent, finish the current cycle and give the transition a clear quiet beat. Boss Rush tests run without ambient vent pressure. Verify that the boss handoff cannot defer progression indefinitely.
5. Candidate experiment **F3** lets a vent damage ordinary enemies without primary weapon procs. Route damage and kills through normal combat and reward accounting. Test repeated baiting and dense pack clears against baseline XP and scrap pace. Boss damage stays outside this experiment. Ship this interaction only if it adds route choices and does not become the dominant farming strategy.

## 5. Breach layout

| District | Placement hypothesis | Tactical role | Environmental story |
|---|---|---|---|
| Broken Gate | North edge, around a large gap in the visual gate structure | Long views toward the central ground, less room to circle near the fence, two lateral ways back inland. | Bent iron, old barricade mounts and damage facing inward. Any boundary gap must still read as a closed gameplay boundary. |
| Evacuation Road | Diagonal sweep through the center | Best visibility and circulation. An exposed drop here is easy to approach from several directions and costly to hold under ranged pressure. | Painted arrows, wheel tracks, flat stretchers and discarded gear. Keep a low contrast running surface. |
| Signal Court | East or southeast edge, linked to the road and a broad perimeter return | An edge-side drop trades some approach angles for reduced retreat room. The pod itself offers the reload break. | Damaged signal equipment, cable runs and a steady amber beacon with a static Reduced Motion state. |

Use a district art and site pass with zero new permanent interior blockers as the first Breach candidate. Keep the existing open central fight space. Place two or three optional sockets per district in Tiled and validate their usable approach routes at blockout time. For each request, filter sockets with the current visible-floor, player distance, repeat separation, solids and support reservation checks. Require the capture circle to fit the safe floor and preserve ways around the pod footprint. Prefer a different district from the last landed pod when several eligible sockets remain. Keep random sampling as a fallback and the existing retry when no valid point exists. Use the same selection rules and seeded inputs where solo and co-op can share them. In co-op, define the eligible play-space anchor using the server's existing team objective policy and verify both grouped and split teams.

Preserve the current pod timeline, friendly impact, temporary cover, reward ownership and checkpoint phase. Landing site weighting must not alter XP or force a run to depend on capturing drops. In Training, add a way to preview each district's site class using the existing airdrop practice path. Test normal random drops separately from the forced practice case.

## 6. Presentation and player flow

- Update arena catalog cards after the layouts pass. Proposed short copy is “Breach · Open ground and supply drops” and “Foundry · Machine cover and pressure vents.” Use thumbnails that show each arena's route identity at card size.
- Deployment frames the central landmark and a visible departure route. Let players learn the other districts by moving. Use a small Training prompt only if players consistently miss the vent warning or the dry bypass.
- Build art in layers. Quiet floor and route marks sit under material hazard warnings. Low props and contact shadows establish solid edges. Foreground art must preserve visibility of actors, pickups and bullets where they overlap. Keep critical geometry legible at negative world coordinates and near the wall faces.
- Use local machine hiss and release sounds within existing audio budgets. Keep phase recognition available through visible valve/plate changes. Reduced Motion uses steady light and explicit phase changes. Avoid decorative flicker that resembles attack warnings.
- Author clean room tone, floor variants, reusable edge pieces, hero props, contact shadows, vent states and loadout thumbnails. Record source, pixel scale, collision footprint and atlas budget alongside the assets. Reuse material VFX and existing culling where possible.

## 7. Engineering implementation

| Step | Implement | Evidence before moving on |
|---|---|---|
| A · Baseline | Trace Tiled-to-runtime coordinates in `MapComponent`, `ArenaBounds`, `ArenaGeometry` and the online room geometry. Capture baseline Training scenarios and reference device performance. Trace the sibling server's co-op vent, supply and checkpoint behavior before defining parity fixtures. | A reproducible scenario list with seeds, loadouts, pressure, viewport, timings and representative phone captures. |
| B · Authoring contract | Add optional district, vent group, protected floor and supply socket metadata to the existing authoring path. Give maps and authored objects stable IDs. Document units, origin, bounds, required layers and defaults for older data. Use one coordinate transform for fixtures, art and authority. | Loader rejects malformed data, duplicate IDs, invalid bounds and impossible socket placement. Legacy layers still load. |
| C · Training Foundry | Add an internal candidate selection to Training. Load F0/F1/F2 from authored definitions through existing geometry and scenery. Add a simple vent practice trigger and run position, spawn and hazard probes. Record the selected revision with each run. | A phone build that switches candidates cleanly through restart and route disposal, plus traversal and combat comparisons. |
| D · Training Breach | Add visual district landmarks and site weighting around `SupplyDrops` and the existing selector in `game.dart`. Keep legacy drop coordinates meaningful on restore. Run repeated forced and random drops. | All three district tradeoffs are demonstrable and the selector has a valid fallback or retry. |
| E · Combat validation | Reuse body occupancy, obstacle routing, spawn reservations, swept movement and line-of-sight queries. Cover applies consistently to movement, gunfire, blast occlusion and grenade prediction according to each existing weapon contract. Audit special cases such as pierce, bounce, airborne projectiles and committed attacks. | No stuck packs, unreachable pickups, wall tunneling, mismatched grenade landing previews or cosmetic collisions. |
| F · Co-op parity | Extend the existing map export where appropriate. Inspect `../regun-server/tool/export_maps.py`, `shared/maps.json`, `spacetimedb/src/room_geometry.ts` and `survival_runtime.ts`. Add shared fixtures for transform, blockers, site selection and vent footprint and timing. Gate revised rooms by client compatibility. | 2- and 3-player hosts and guests agree on layout, cover, warnings, authoritative hits and reconnect state. |
| G · Production art and rollout | Finish art after geometry approval. Validate cache and lease cleanup across route exit and restart. Enable Training candidate, then private solo/co-op sessions, then new-run default after acceptance. Retain legacy revision data through the compatibility window. | Reviewed phone captures, platform and save checks, and a rollback drill on a new run and a saved candidate run. |

### State and compatibility

- Pin a stable map revision to the run or room when it starts. Continue and reconnect restore that revision with the same world transform. Old snapshots with no revision resolve to the legacy map. Restart inside a pinned session reloads its definition. New runs use the rollout default.
- Persist committed vent group, phase and elapsed active time if the existing hazard snapshot cannot already represent them. Validate range and phase on read. Legacy active hazards retain their saved footprint. Checkpoint RNG and recent-site history only where they affect future committed selections. Restore never replays landing damage, a vent hit, or a claimed reward.
- Pause, picker, entrance, training recovery and lifecycle transitions follow existing active simulation clocks. Reconnect presents authoritative phase and remaining time. Clear pending work on world replacement and release assets even when loads complete after disposal.
- Keep a candidate revision disabled for fresh runs if rollout is reverted. Restore pinned candidate runs with the retained definition. An unknown revision should produce a recoverable Continue or join error with the original save intact.
- Validate exports in CI for geometry drift. The server owns co-op collision, spawns, vent damage and supply state. The client draws the matching revision and uses it for prediction. Old-client rooms use compatible geometry. Reconnection cannot switch revisions.

## 8. Test and acceptance plan

| Check | Method | Proposed gate |
|---|---|---|
| Place recognition | Give six phone playtesters one short run per candidate, counterbalance order, and ask where they turned, reloaded and got hit. | At least five can distinguish two districts per tested arena and describe a route choice without prompting. Treat this as a directional private-test gate. |
| Routes and size | Record time from the open ground to first meaningful cover or route choice, bypass versus shortcut time, and long stretches without threats or objectives. | The Foundry bypass costs a few seconds in ordinary movement and stays viable under pressure. Preserve the footprint unless repeated empty travel remains after placement tuning. |
| Combat fairness | Matched runs with close, long-range, area and ricochet builds. Include early play, dense late waves, elite Skitters, ranged pressure and solo/pair boss attacks. | Both routes get used. No reproducible unavoidable damage at a connector, dominant camp, or boss-safe exploit. Review any recurring damage with video and collision overlays. |
| Vent clarity | Cross before warning, during warning, while active and during cooling. Repeat at low contrast, with sound off and Reduced Motion on. | Floor footprint and hit agree. Players can describe an available dodge or bypass. A boss transition and a delayed frame preserve a readable warning. |
| Supply | Capture, abandon, expire, save and resume from each phase. Test offscreen travel, boundary sites, blocked reservations and pod-as-cover routing. | Existing timers and rewards hold. The pod leaves at least two usable escape directions at each accepted site. Restore grants each reward once. |
| Spawn and collision | Probe clearance with player and large bodies, visible spawn warnings, pod reservations and dense packs. Sweep all solids, perimeter edges and short connectors. | Zero invalid deployments, unreachable pickups, collision mismatches or reproducible jammed packs that stop encounter progression. |
| Device quality | Compare baseline and candidate on a reference iPhone and lower-tier Android, with a tablet viewport check. Log frame percentiles, stalls on first asset use and peak resident/texture memory. | No repeatable new combat stall. Initial comparison budget is at most 10% regression in p95 frame time on the same device and scenario, within existing art budgets. Confirm the frame target with the baseline before shipping. |
| Network and lifecycle | Play 2- and 3-player co-op with latency, old client compatibility, reconnect, backgrounding and guest recovery. Restore legacy and candidate saves. | No room revision drift, prediction through cover, repeated hazard damage or duplicate rewards. |

Capture evidence with the map revision, game build, device, loadout, encounter seed, control layout and Reduced Motion setting. Use Training pressure and boss controls to replay failures. During private tests, collect district entry, vent warning and hit, death source, drop outcome, route times and frame timings through existing debug instrumentation or manual notes. Compare against the same baseline inputs. Use `make verify`, focused map and checkpoint regressions, the server's existing map/Survival fixtures, and `make soak` for long simulations. Phone feel, visual readability and native performance require hands-on review.

## 9. Delivery gates and decision log

1. **Geometry gate.** Ship an internal Foundry Training comparison with recognizable placeholder shapes, adjustable cover spacing and a visible dry bypass. Approve route topology before committing to final art.
2. **Mechanics gate.** Compare F1 and F2, then test F3 separately. Approve which vent rules ship. Prototype Breach drop site weights and retain the fallback.
3. **Content gate.** Approve phone-scale art and audio for all four arenas, including actors under cover edges and warnings on varied floor materials. Update catalog cards and the playtest guide.
4. **Compatibility gate.** Prove solo checkpoint restoration, matching co-op revisions, rollout disable behavior, and migration from old rooms and runs.
5. **Release gate.** Review evidence from device and multiplayer sessions. Promote candidates for new runs when all required gates pass. Keep recorded baselines for later maps.

| Open decision | Default for implementation | Resolve using |
|---|---|---|
| Final arena size | Shared footprint | Measured dead travel and boss clearance after route tuning |
| Foundry vent damage to enemies | Separate F3 experiment | Route use, kill attribution and XP drift |
| Number and shape of press islands | Two offset bases | Crowd flow, gun angles and reload opportunities |
| Breach permanent cover | Existing perimeter and temporary pod cover | Phone tests showing a recurring cover need that site placement cannot solve |
| New arena sizing | Start at the shared footprint | Measure travel, boss clearance and whether routes remain distinct under pressure |

**First implementation slice.** Add the versioned Foundry Training blockout with two offset press footprints, a rail lane, an open casting floor and a furnace bypass. Include baseline comparison and one repeatable dense pack and large boss scenario. The review artifact is a playable phone build and a brief comparison with route timings, screenshots and observed failure cases.

## 10. New Survival arenas

### Floodworks

A flooded municipal pumping station. Stained gauge posts, stranded rescue equipment and high-water marks show the crew lost control before abandoning it. The combat decision is **when to cross**.

- **Pump court.** Open deployment and boss floor on the west bank. Two broad exits lead to the sluice and the upper embankment.
- **Sluice apron.** A flush channel cuts across the middle as the direct route. A fixed warning runs along its actual footprint before the surge. Start with a 2-second warning and a 3-second active window, then tune from device tests. Crossing stays physically possible. Prototype damage through the existing hazard contract so a route never turns into an invisible wall.
- **Upper embankment and intake yard.** An always-dry connector reaches the east bank. The intake yard reconnects to both crossings. Keep the dry route wide enough for crowded retreat and give the direct crossing a measurable time advantage.
- **Runtime.** Author the channel, dry route and protected ground in Tiled. Start with a single seeded surge cycle using active simulation time. Suppress new surges during boss commitments and deployment. Store committed phase and remaining time for Continue and reconnect. Distinguish water warning and active state with visible waterline movement or a static stepped fill in Reduced Motion.
- **Gate.** Compare the same blockout with surges off and on. Players should sometimes cross early and sometimes take the dry route for a reason they can explain. Reject any layout where a surge plus a mixed pack can seal both banks or where the bypass is so efficient the crossing never matters.

### Relay Graveyard

An emergency communications yard full of wrecked relay wagons and severed cables. One open transmission apron faces the dead antenna field. The combat decision is **which direction to face and where to relocate when your firing angle goes bad**.

- **Transmission apron.** Broad central deployment and boss ground with three wide approaches. Broken mast silhouettes sit at the perimeter.
- **Wagon rows.** Two offset cover islands on one flank offer short peeks and let you break ranged fire. Each has two paths around it. Maintain a wide through-route behind the rows.
- **Cable field.** The other flank has open diagonal shots across flat cable trenches and a broad route back to the apron. Floor seams and leaning dishes make the angles recognizable on a phone.
- **Runtime.** Use authored approach sectors for a map-specific reinforcement pattern during normal waves. Begin with two well-separated eligible approaches per pattern, chosen from the existing valid spawn budget. Keep the current warnings, distance limits and reservation checks. Rotate the preferred approaches between waves, avoid spawning on a player's immediate exit, and fall back to the normal director if authored approaches are invalid. Keep boss move selection and health separate from this behavior. Persist only the state required to restore the next pattern and honor already committed spawns.
- **Gate.** Compare the same layout with the normal director and with sector weighting. Players should turn or relocate as pressure changes. Watch for one-way camping, safe farming behind wagons, unreadable rear spawns and packs jamming at connectors. Tune weighting and openings before raising the enemy cap.

### Four arena implementation sequence

| Slice | Deliverable | Exit evidence |
|---|---|---|
| Shared foundation | Extend the arena catalog, Tiled metadata and stable revision handling to support four definitions and per-map bounds. Keep existing arena IDs and assign stable IDs for the additions. Audit two-arena assumptions in loadout, Training, challenges, saves and server rooms. | All four definitions load and can be selected in Training. Legacy runs still restore. |
| Layout blockouts | Build Foundry first to establish the comparison workflow. Block out Floodworks and Relay Graveyard, then test Breach's district and supply changes using the same workflow. | Each map has a distinct decision in matched loadout playtests and enough clear ground for crowded boss combat. |
| Signature mechanics | Add Floodworks surges and Relay approach weighting as separate switches. Test each against its geometry-only baseline, then run the Foundry and Breach mechanics checks across the full roster. | Native Training evidence for route choice, warning readability, spawn fairness and recovery. |
| Content and integration | Finish all four arenas, add catalog cards and Training access, and expose the two additions in normal Survival. Use existing arena progression conventions, with final unlock timing set after the first device playtest. Export shared co-op definitions and validate both new mechanics on the server. | All four run through solo and co-op with matching revisions, lifecycle restoration and rollback coverage. |

## 11. References

- [Regun complete game blueprint](REGUN_COMPLETE_GAME_PLAN.md) and [current playtest guide](PLAYTEST_GUIDE.md)
- [Breach airdrop design](AIRDROP_DESIGN.md), [ordnance and supply updates](ORDNANCE_AND_SUPPLY.md) and [multiplayer map scope](REGUN_MULTIPLAYER_MAPS_AND_COVER_PLAN.md)
- [Deep Rock Galactic Survivor](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/) shows how terrain and resource access can create competing priorities under crowd pressure. Breach applies that lesson through temporary cover and optional supply objectives.
- [Supergiant Hades patch notes](https://www.supergiantgames.com/blog/hades-welcome-to-hell-update-patch-notes/) document hitbox tuning and foes taking trap damage. Foundry applies that lesson through clear footprint tests and a separate enemy-damage experiment.
- [Supercell map and balance notes](https://supercell.com/en/games/brawlstars/blog/release-notes/mysteryatthehub-patch-notes/) describe hard walls as a way to support short-range fighters. Foundry tests that effect through connected short- and long-range routes.

## 12. Device review implementation

The four layouts ship through the ordinary Arena catalog and use the same
survival loop. The Foundry comparison selector was removed when the press
layout became the default for new runs. Foundry retains its cycle unlock.
Existing solo saves with the prior Foundry layout retain its six blockers.
Floodworks uses one committed surge footprint, and Relay Graveyard rotates
preferred reinforcement approaches while retaining ordinary spawn validation.
Breach prefers eligible authored landing points and falls back to its existing
placement search.

See [the four-arena playtest instructions](PLAYTEST_GUIDE.md#four-survival-arenas).
Phone review should focus on whether each route reads clearly mid-fight and
whether bosses can contest positions behind cover. The co-op catalog additions
depend on the matching server capability and geometry export.
