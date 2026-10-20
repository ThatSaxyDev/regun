# Regun multiplayer maps, walls and engagement design

**20 October 2026 — planning specification; no new maps or assets implemented.**  
Part of [the multiplayer plan](REGUN_MULTIPLAYER_PLAN.md). Working map names and measurements below are proposals; player counts and mode boundaries follow the creator's direction.

## 1. Scope and map separation

- **Co-op:** the actual normal Breach/Foundry maps, normal survival loop, two or three total players. Keep their open arena identity, landmarks, hazards and boss space. Do not redesign them into tactical PvP corridors.
- **Versus:** two complete dedicated maps at launch, with a third targeted after the first two pass. Default enemies On, optional Off, no player enemy-type selection.
- **Formats:** **1v1, 2v2 and 3v3 are all required in this implementation pass**. PvP room capacity is two/four/six according to format, maximum three per team. Test 1v1 first as an engineering sequence, then complete four- and six-player geometry, networking and fairness before calling the pass complete. A shared art theme does not mean one geometry is balanced for every team size.
- **Walls:** a new modular stone/iron wall and cover kit, integrated with authoritative movement/projectile geometry. Improved regular-arena wall appearance is an art-only pass unless a separate collision change is approved.

“Dark” means Regun's worn crypt/industrial atmosphere, charcoal/green stone, oxidized iron, restrained brass and warm furnace accents. Actors, cover edges, projectiles and committed warnings must remain readable. Black floors and black enemies are not an acceptable way to make the game dark.

## 2. Research and its application

Riot describes Ascent as a deliberate three-lane design, with repeated geometry playtests before art. Its process tunes sightlines, encounter distances and opening widths, then uses architectural cues for navigation. For Regun, use that process and route differentiation; do not copy bomb sites, first-person elevation or exact dimensions. [The Birth of Ascent](https://playvalorant.com/en-gb/news/dev/the-birth-of-ascent/)

Riot's Split account shows that an attractive strategic position can draw too much combat away from the intended fight. Test whether a dominant camp spot or detour defeats each Regun map's purpose. [The Creation of Split](https://playvalorant.com/en-us/news/dev/the-creation-of-split/)

Supercell discusses indestructible walls making some maps more accommodating to short-range fighters, and a Duels map refresh intended to make layouts more distinct. That supports testing weapon/cover tradeoffs and map variety in a top-down game; it does not prescribe Regun's geometry. [Mystery at the Hub](https://supercell.com/en/games/brawlstars/blog/release-notes/mysteryatthehub-patch-notes/)

The designs and numeric starting budgets below are Regun recommendations inferred from those principles and this codebase, not sourced universal rules.

## 3. Engagement rules and lane purposes

Three lanes are a useful structure, not a requirement to draw three parallel tunnels. Give each route a tactical tradeoff and connect routes so a player can rotate, retreat or contest an angle without crossing a single unavoidable killing field.

| Route | Purpose | Exposure and counterplay |
|---|---|---|
| Middle | Fastest contact and access to cross-map rotation | Broken sightline, contested cover and at least two ways to disengage; holding mid never sees every exit |
| Left flank | Safer, closer approach for shotgun/dash pressure | Shorter sightlines but longer travel; no invisible one-way ambush, dead-end pocket or guaranteed point-blank kill |
| Right flank | Longer-range angle and alternate rotation | Longer **segmented** view with intermediate cover; no spawn-to-spawn beam or unanswerable sniper perch |
| Connectors | Switch route and counter a committed holder | Readable junctions, limited simultaneous angles; crossing has a deliberate exposure cost |
| Spawn approach | Establish orientation and choose a route | Two independently usable exits, no direct opening shot, no AI arrival inside deployment space |

Left/right names are local orientation aids, not asymmetrical team privileges: opposing sides must have equivalent opportunity to reach close and ranged routes. Use 180-degree geometry where useful; verify actual path lengths/angles instead of declaring a map fair because its outline is symmetric. Decorative asymmetry is acceptable when it does not hide one side more effectively.

### Measured design constraints

Current baseline: actor collision diameter 60 units, Rook speed 300 units/s, dash 1450 units/s for a base .15s (about 217.5 unobstructed units). Base weapon ranges are shotgun 420, carbine 650, revolver 800 and Arc 560; distance-damage bands also matter. Those are current solo contracts, not final PvP balance.

Start blockout tests with these adjustable budgets:

- 1v1 contested contact in roughly 2–4 seconds from countdown release; side routes roughly 4–6 seconds. Record path distance, movement/dash choice, first mutual visibility and first viable shot separately.
- Critical retreat route should reach another usable hard-cover position in about 1–2 seconds at base movement, subject to health/time-to-kill tests. Avoid sustained uninterrupted 800-unit domination.
- Initial narrow flank clearance 150–210 units in 1v1; team connectors 240–360 units. Clear width is between **collision edges**, not sprite art. AI occupancy can require more; widening is a test result, not a fixed promise.
- Every primary cover pocket has a second escape path; any intentionally risky niche is shallow, obvious and excluded from spawn/revive placement.
- Spawn-to-first-cover and spawn-to-mid times should initially differ by less than about 5% between sides on equivalent routes. Measure stopping/peeking angles and weapon outcomes as well as time.
- Limit how many independent angles become visible at an opening. A new player should be able to identify the immediate threat without inspecting six tiny corners.

Do not solve a ranged dominance problem solely by buffing short-range damage. Fix sightlines, approach cost and safe intermediate cover first. Do not place pickups in a way that silently becomes the real win condition; any healing/ammo/objective mechanic needs a separately declared ruleset.

## 4. Proposed map pack

Prototype three different route structures, select two for full art/release, and keep the third explicitly unfinished until it passes. “1v1 / 2v2 / 3v3 variant” means stable versioned geometry, clearance and spawn/AI socket presets, never random opening/closing of arbitrary walls mid-match.

### A. Ossuary Cross — first release priority

**Identity:** an underground burial crossing, chipped stone partitions, brass memorial plates and ruined arches. Balanced teaching map for taking cover, rotating and closing distance.

**Layout:** opposite recessed deployment rooms feed a broken central crossing and two unequal-shaped but opportunity-balanced outer paths. The left path is a bent crypt gallery with short peeks; the right is a wider archive aisle with medium-range firing breaks. Mid has offset wall islands rather than a single hold-everything pillar. Each outer path connects to mid on both halves, allowing pressure to be answered by rotation.

**1v1 blockout candidate:** about 1600 × 1100 units, then adjust from timed routes and camera tests. World dimensions alone do not establish sightline length.

**Engagement story:** quick mid contest, disengage behind a wall island, then choose a close crypt push or an exposed archive angle. Distinct wall caps/quiet floor accents label each route without glowing objective arrows.

**Enemies On:** paired peripheral crypt-door sockets feed shallow approach pockets after a committed arrival cue. No socket inside either spawn shelter, connector choke or protected cover exit. Arrivals pressure movement without filling all three routes. Defer a wave if the only legal arrival would trap a participant.

**Team variants:** 2v2 widens connectors and adds a second independent route out of central cover. 3v3 opens authored outer pockets and offsets team deployment positions so three bodies cannot jam one door. No new central super-cover that protects an entire team from all responses.

**Team blockout candidates:** approximately 1850 × 1300 for 2v2 and 2100 × 1450 for 3v3. Add usable flank/connector geometry rather than scaling the 1v1 meshes. Contact/rotation measurements must hold after adding space; reduce size if players spend too long finding opponents.

**Failure cases:** shotgun wins every gallery encounter; revolver watches both archive exits; one mid island sees all rotations; undead pin a player against their own spawn wall. Revise before art sign-off.

### B. Ironworks Relay — second release priority

**Identity:** a grounded foundry transfer station with dark iron baffles, pipe housings, low furnaces and riveted machine cover. It shares Regun's industrial language without copying the regular Foundry layout or its hazard schedule.

**Layout:** staggered machine islands form a wide zigzag mid route. One outer route uses close maintenance bays; the other uses alternating loading-yard baffles for longer peeks. Multiple short cross-links favor changing angles and coordinated crossfire. There is no permanently straight rail corridor and no elevated catwalk gameplay.

**1v1 blockout candidate:** about 1750 × 1200 units, trimmed if disengagement turns into endless running. Center/ranged route lengths and side travel times differ from Ossuary Cross.

**Engagement story:** pressure from a ranged baffle, break sight, rotate through a maintenance bay, then punish a reload from a new angle. Boiler silhouettes remain below the player's readable zone or fade consistently; decorative pipework cannot imply a shoot-through opening when collision is solid.

**Enemies On:** paired service-hatch arrivals in peripheral staging bays, with tested nav paths into the arena. Standard AI cannot leap through a closed boiler wall. Avoid stacking enemy casts with crossfire until warnings remain readable. Furnace art is decorative unless a separately tested hazard is explicitly enabled.

**Team variants:** 2v2 adds parallel approach space beside central machines. 3v3 expands into pre-authored loading aprons and additional connectors; a six-player version must not turn into a single ranged firing squad across mid. Keep spawn exits independent even when an opponent and AI occupy adjacent bays.

**Team blockout candidates:** approximately 2000 × 1400 for 2v2 and 2250 × 1550 for 3v3, using different cover placements/connector openings and staggered spawns. Check at least two ways for a pressured teammate to escape crossfire.

**Failure cases:** ricochet corners deal unintended double hits; machine art hides the collision edge; maintenance pocket has no escape; six bodies create a wall; iron cover makes opponents impossible to distinguish from props.

### C. Ashen Cloister — third candidate

**Identity:** a burned monastery court, soot-black stone, restrained ember light and broken ribbed walls. More rotation and cross-link choices, with fewer long fixed firing angles.

**Layout:** a central offset shrine divides an inner loop; broken cloister walls create an outer loop with three principal approach sectors and cross-links. It is a lane/loop hybrid, visibly different from the crossing and industrial baffles. Neither loop is an uninterrupted safe running circuit.

**1v1 blockout candidate:** about 1650 × 1250 units, with outer sections closed using authored solid boundaries if testing shows excessive avoidance. Do not scale up the whole map and call that a 3v3 variant.

**Enemies On:** paired outer arch arrivals with safe staging and warnings. AI must not close both exits from a shrine pocket simultaneously. No boss floor attack imported into this tight layout by default.

**Team variants:** expand the loop's usable width and activate balanced sector connections/spawn sets, retaining clear counter-rotations. Review dominant three-person corner holds before enabling 3v3.

**Team blockout candidates:** approximately 1900 × 1400 for 2v2 and 2150 × 1550 for 3v3. Keep both loops contestable from more than one sector; extra circumference alone is not team-map design. If the third map proceeds in this pass, it must support and pass all three formats too.

**Failure cases:** infinite clockwise kiting; invisible opponents behind tall arches; outer loop bypasses all fights; a team holds a sector with no counter-angle. Reject the third map if its only distinction is different floor art.

## 5. Modular wall and cover kit

### Current gap

`MapComponent` loads one `maptile.tmx` into rectangle groups. `ArenaGeometry` constrains actors against inflated rectangles and checks shot segments against rectangles. `ArenaScenery` draws sparse atlas props, simple perimeter bands and local-player-based prop fading. This is a valid regular-arena foundation but not yet a tactical wall system, multi-map loader or multiplayer occlusion contract.

### Required kit

| Asset group | Pieces and purpose |
|---|---|
| Crypt stone | Straight runs, inside/outside corners, end caps, T-junctions, columns and broad cover islands |
| Foundry iron | Riveted partitions, baffles, armored machinery housings, corner/end joins and service hatch arrival art |
| Cloister stone | Broken arches, ribbed ends, short solid barriers and shrine cover, only if third map proceeds |
| Grounding | Contact shadows, foot/base trim, quiet damage/chip variants and floor junctions |
| Regular arena perimeter | Finished wall faces/caps consistent with the current silhouette and bounds; no extra movement obstruction |
| Authoring preview | Collision overlay, muzzle/actor anchors, connected seams, spawn/arrival markers and material legend |

Damaged appearances are cosmetic by default: cracks must not imply a gameplay opening or destructibility. Keep pixel density, lighting direction, palette and material wear consistent with existing Regun art. Avoid clean vector blocks in final output; simple blockout visuals are internal geometry tools only. Asset generation/art production belongs to the planned implementation pass; this document update itself creates no assets.

### Cover behavior contract

| Type | Movement | Projectiles / damage | Visibility |
|---|---|---|---|
| Hard wall / full machine cover | Blocks actors and dash | Blocks direct rounds and electrical chains under explicit line-of-sight checks; ricochet only where that weapon/rule permits | Art/occlusion matches the solid footprint; no implied shoot-through window |
| Short solid barrier | Blocks actors | Blocks shots in the initial 2D rules, despite low appearance | Explain through readable solid cap; no crouch/height simulation |
| Decorative rubble / floor trim | No block | No block | Cannot resemble an impenetrable barricade |
| Arrival door art | Not an actor escape route unless authored | Declared solid boundary; arrival spawns occur at a valid interior socket | Does not secretly open or provide one-way shooting |
| Broken visual wall | Behavior follows its authored intact footprint | Real gaps exist only where geometry has a gap | Ends and caps expose the same gap at all viewing positions |

“Cover” initially means blocking shots with positioned geometry, not a sticky cover button or automatic attachment mechanic. No destructible walls, penetration by ordinary upgrades, shoot-over-height mechanics, dynamic doors or secret passages in the first release. Weapon piercing through bodies must not grant piercing through walls. Retest Arc target selection/chains, drones and every secondary proc: a shared cover contract must not be bypassed by a system that only checked target distance.

### Geometry and authoring

Create separately versioned map definitions with `mapId`, geometry/content version, compatible modes/team sizes, bounds, placed material pieces, solid footprints, optional visibility metadata, player spawn sets, AI sockets, safe regions and route labels. Export server/client geometry from the same Tiled source and compare a manifest hash at admission. The exact storage layout is chosen during the map prototype; do not force new definitions through legacy solo save enums.

Rectangle-based authoring is acceptable initially if it passes corners, overlaps and joins. `ArenaGeometry`'s sequential push-out is not assumed safe for dense intersecting walls: test inside corners, adjacent rectangles, narrow passages, spawn recovery and long dash steps. Use disjoint footprints or upgrade the collision solver when necessary. Do not simulate a wall with many tiny visual tiles that each get an expensive actor/component/hitbox.

Navigation must route around the new walls for walking, lunging and ranged repositioning. Build traversability/clearance from the same geometry; use navigation waypoints or a grid with local avoidance as measured, rather than steering directly at targets through cover. Keep pending spawn reservations separate from living occupancy. AI spawn, players, warnings and projectiles never use sprite dimensions as collision truth.

### Occlusion and readability

Sort wall faces and actors by a defined foot/depth relationship. Tall foreground art can fade consistently to reveal actors without disabling collision; its solid base/outline remains legible. Extend the current `myPlayer`-only fade rule for visible participants without creating a local-player-only advantage in PvP.

The initial proposal has no stealth fog: provide consistent silhouettes/visibility for all actors intended to be visible, while walls block shots. If real hidden-information line of sight is introduced later, enforce it in server replication, aim assist and audio/VFX as well as rendering; client transparency alone cannot implement secrecy.

Keep collision overlays and a reference scene for art review. Test wall-facing muzzle origins: a close wall must stop a round rather than allowing the muzzle offset to spawn on the other side. Check beam clips, first-contact body sweeps, reflections and secondary area damage near corners. Splash damage may reach around cover only if the rules explicitly allow it and warnings show that footprint.

## 6. Enemies, spawns and engagement fairness

Versus AI spawns use a dedicated neutral preset; they are not the survival director copied at full density. Map variants declare supported AI body sizes/roles and maximum arrival capacity. Keep no-enemy matches on the same tested geometry so the variant choice is understandable, while tuning population/outcomes independently.

Player spawning requires two usable exits, no initial hostile line, fair travel to first cover and no AI reservation conflict. Use mirrored/rotated sets and swap sides across rounds. For 2v2/3v3, stagger teammates without allowing one team to start closer to contested cover. Opening protection must not permit shooting safely out of a spawn shelter before the other side can respond.

Measure AI pressure per side: target time, warnings near cover exits, damage taken, obstruction time and forced route changes. Equivalent sockets alone cannot establish fairness when opponents kite the same enemies. Cap per-route occupancy, delay unsafe arrivals and ensure AI never blocks all exits. Both enemy variants need overtime/draw tests. No normal survival drops or XP rewards should enter Versus without a separate competitive rule.

## 7. Map production and acceptance

1. **Contract/blockout:** inventory current movement/ranges/falloff, author the three route graphs and collision footprints, and reserve team/AI socket variants. No polished art commitment yet.
2. **Geometry playtest:** instrument reachability, rotation/contact time, firing angles, spawn parity and dominant holds using current weapons/dash. Compare enemies On/Off.
3. **Representative wall slice:** finish stone and iron straight/corner/cover pieces, validate shading/pixel density/footprints/occlusion on phones, then approve the kit direction.
4. **PvP alpha:** complete one map in 1v1, then 2v2 and 3v3 within this pass, with default AI and optional enemies-off; validate team outcomes and reconnect while enemies are active. A 1v1-only or empty-map harness does not complete this milestone.
5. **Map pack:** complete two distinct maps, each with all three supported team-size variants, their material kits and regular perimeter art; proceed with map three only if it adds a tested tactical difference.
6. **Release validation:** test four/six clients on each map under both enemy settings, independent side-pressure, team crossfire and weapon balance. All formats are required before this pass is complete; staging their development is not deferring team play to a later release.

| Acceptance area | Required evidence |
|---|---|
| Layout | Connected playable floor, no accidental dead ends, purposeful alternate routes, timed contact/retreat, no all-seeing cover island |
| Collision | Actor/dash/body clearance at every join; first-contact projectiles; no through-wall muzzle, chain or reflected-shot leaks |
| Spawn/AI | Safe paired/staggered starts, independent exits, population pressure under occupancy caps, no forced arrival into lethal pockets |
| Combat | Each current weapon can contest via an appropriate route; measure side/loadout outcomes, range damage and time-to-kill |
| Team scale | Team-specific widths, rotations and crossfire; no body doorway locks; four/six-client gameplay before format release |
| Visuals | Dark art with readable actors, warnings and real cover; stable shadows/depth, no false gaps or invisible wall extensions |
| Camera/HUD | Equivalent visible playfield; safe-area ping/score/health layout, no aspect-ratio advantage |
| Performance | Culled/batched wall rendering, bounded AI/navigation and material effects; sustained physical-device evidence |
| Co-op preservation | Same regular arena geometry and hazards; any perimeter-art improvement has unchanged collision unless reviewed separately |

A pathfinding success or screenshot does not prove a map is enjoyable. Include human tests of spawn pressure, camping, chase/escape, close-vs-ranged play, attention split between enemies and opponents, and touch aiming around cover. Record match count, side swaps, loadouts, network profile and sample uncertainty. Do not declare balance from a tiny 50% win-rate sample.

## 8. Deliverables and unresolved choices

Deliver: authored map sources and versioned geometry; three tested blockouts; two complete PvP maps with a third explicitly gated; modular stone/iron wall assets and manifests; team-size/AI presets; navigation/cover fixtures; improved regular perimeter appearance; art/collision review scenes; and map-by-map acceptance reports.

Review the working themes/names, final scoring/overtime, whether the third map belongs in the initial pack, and which neutral enemy roles survive the first safety tests. Three-player co-op on regular maps, default-enemies Versus, optional enemies-off, no enemy picker and playable 1v1/2v2/3v3 up to six participants **in this pass** are already requirements. The current request updates the plan; actual gameplay/map/art implementation remains a subsequent action.
