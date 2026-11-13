# Regun roguelite V1

**Implementation plan for creator review · 12 November 2026**

**Expedition** is the working name for Regun’s flagship solo mode. Start at Rook’s shelter, fight through procedurally built rooms, choose what to fight for at each fork, defeat the boss at the end of each region, and bring one evolving build to a final victory. **Arena** is current endless solo survival. **Online** retains its multiplayer entry. Training remains available from the shelter.

The approved direction is room-based progression, real entrances and exits, sealed combat, two visible reward destinations, procedural physical layouts, and several fights before every boss. The region order, boss assignments, boon counts, timing targets, name, and rollout below are proposed V1 decisions. This plan is the build brief for the subsequent implementation.

**Build order** · [Player flow](#2-player-flow-and-rules) · [Generation](#4-route-and-room-generation) · [Game integration](#6-flutter-and-flame-implementation) · [Saves](#7-save-restore-settlement-and-compatibility) · [Server and admin](#8-server-and-admin) · [Milestones](#9-delivery-slices-and-exit-gates) · [Acceptance](#10-verification-and-physical-acceptance)

## 1. What V1 delivers

| Area | Investor-ready V1 |
|---|---|
| Complete run | Four distinct regions, **21–25 mandatory combat rooms plus four bosses**. Every region asks the player to clear five to seven rooms before its boss. The opening, regional transitions, final victory, defeat, and retry are playable through the ordinary game UI. |
| Procedural dungeon | Generated route graphs and constructed physical rooms, with region-specific topology, door placement, cover, sightlines, and hazards. At least four topology families per region. Each supports at least three materially different geometry configurations before cosmetic variants. Boss chambers are authored for their fights. |
| Builds | Six recognizable reward families, at least 30 drafted effects across them, at least six reachable build-defining capstones, and explicit repair choices. Existing combat effects and fusions can meet these counts when they support Expedition’s pacing and eligibility rules. |
| Weapons and survivors | Existing owned weapons and survivors enter through the current entitlement rules. V1 budgets for compatibility with all 24 weapons and 10 survivors in the current catalog. Rook and Pump Shotgun form the fresh-profile path. |
| Meta progression | First-clear and mastery milestones, permanent unlocks that expand future build choices, a regional/boss record, a discovered-boon collection, and at least two post-clear difficulty steps with authored encounter changes. |
| Platforms | Signed, private release builds for iOS and Android, plus macOS release with keyboard/mouse and controller for a live presentation. Validate the shipped mode on every platform where it is enabled. Web availability is a separate release decision after storage and performance validation. |
| Operations | Packaged offline defaults, server-backed content revisions and pilot controls, scoped run analytics, and an admin workbench for validation, preview, publication, rollback, and triage. |
| Showcase | A five-minute live walkthrough using a real pinned seed, a separate late-run save for the finale, and a fresh random run available in the same build. A recorded full clear and QA evidence accompany the build. |

Start with **35–50 active minutes** for a successful run, including combat and boss phases. Track real elapsed time separately, including reading rewards and taking breaks. Target a clear first fight and first boon within roughly 90 seconds. Combat room targets begin at 35–85 active seconds, with later set pieces allowed longer when the extra time creates a tactical phase. Pace targets are tuning hypotheses. Save & exit makes a full run playable over several sessions.

## 2. Player flow and rules

### Shelter and loadout

- **Play** opens Expedition once the private review build is accepted for promotion. While testing, give Expedition a separate entry on eligible builds. **Arena** opens existing solo loadout or its suspended run. **Online** opens multiplayer.
- Expedition setup shows the survivor and starting weapon. The route determines location. Existing Armory unlocks and account ownership apply. Guests can start, finish, and retry with the bundled rules while offline.
- Show the next region and boss milestone in the run view. During combat, keep the HUD to health, ammunition, charges, boss health when relevant, and compact room progress. The pause screen can show the route already taken, current build, and useful recipe progress.
- After an end, show region and room reached, final outcome, build, major choices, unlocks, and active time. **Retry** starts a new seed with the same legal kit. **Change kit** and **Shelter** are secondary actions. Retry is one input from a successfully settled result.

### Room lifecycle

| Phase | Entry condition and player experience |
|---|---|
| Entry | Spawn inside the entrance on validated clear ground. Show the room silhouette and door positions. Combat arms only once deployment finishes. The return threshold is closed. |
| Combat | Outgoing doors are solid. The encounter controller issues a finite authored wave schedule with committed warnings and bounded active/pending counts. The player can use the whole legal room. |
| Clear | All required waves have been issued and all encounter-owned enemies and pending enemy spawns are resolved. Combat hazards disarm and remaining hostile shots retire. A boss clear also waits for its encounter-owned shutdown to finish. |
| Reward | The destination reward advertised by the door that brought the player here becomes claimable. Boon and upgrade rooms show a draft. A repair reward previews actual healing and uses the same claim flow. Combat is stopped. |
| Exit choice | After the claim is durable, two normal exits open and display distinct destination reward families. Crossing an enabled threshold commits its destination. The unchosen branch cannot be taken afterward. The final pre-boss fork can lead through different reward antechambers to the same boss chamber. |
| Transfer | Retire the old room, load the committed room, switch geometry and presentation together, and restore control at the new entrance. Health and build carry forward. The final boss sends the player to victory settlement. |

The encounter controller tracks planned waves, reserved arrivals, mounted actors, and owned summons. A required spawn that loses its point retries at a validated reserve point. If all planned points fail, load the room’s tested alternate encounter using the same threat tier and log the fallback. Ordinary summons count while their owner lives. On owner death, finite summons remain killable and spawner-owned ephemeral actors disarm and retire through their normal presentation. Encounter scripts must bound spawning so a clear is always attainable. A stuck enemy may recover to an authored combat anchor after a visible warning and a verified path failure. The run keeps its health and damage history during recovery.

Two exits are the default after a combat reward. Region transitions and the final victory can use one dedicated exit or action. Boss doors show the boss threshold and reward. Repair or boss rewards cannot be collected repeatedly. Reaching zero health after an accepted hit ends the attempt. If a lethal player hit and clear condition occur on the same simulation step, defeat takes precedence. Once a clear is committed, room damage stops. V1 has one life per attempt and supports suspension, with a separate Expedition save per profile. Paid Arena recovery does not apply.

### Threat and pacing

Give each room a combat question. Examples include finding reload windows across two connected lanes, crossing a timed hazard to stop a ranged nest, or splitting an armored escort from a fast pack. A player should be able to see why the shape of the room changed the fight.

Use authored encounter packs with budget tiers and compatible topology tags. Region depth introduces enemy roles and meaningful pairings. Increase danger through routes, waves, cover pressure, and attack combinations before increasing health. Keep spawn warnings clear of the entrance safety area, door thresholds, and active hazard exits. Use the established occupancy, warning, projectile, and effect budgets as ceilings. Rebalance the actual targets for smaller spaces. A boss chamber has authored reinforcement rules and validated escape routes.

## 3. Regions and boss ladder

These locations are production briefs for new chamber kits. The existing open Survival layouts remain references for material and enemy behavior.

| Region | Combat depth | Generated spaces and encounter focus | Boss chamber and build test |
|---|---:|---|---|
| **Breach** | 5 | Evacuation passages, collapsed checkpoints, split barracks, and an open loading room. Teach door seals, short-range cover, and the first ranged/charger pairing in a readable order. | **Walker** in an authored evacuation court. Read the mounted guns, committed thruster rush and landing blast while protecting a reload window. |
| **Foundry** | 5–6 | Press alleys, cast-floor loops, vent bypasses, and separated loading lanes. Phase machinery to create alternate paths and opportunities to pull enemies onto hazards. | **Kiln Sovereign** on an authored casting floor with verified inside pockets and retreat routes. Tests patience through warnings and short damage windows. |
| **Floodworks** | 6–7 | Sluice crossings, dry embankments, valve rooms, and service loops. Mix long range threats with flanking enemies and timed water pressure. | **Last Marshal** at a dry control station. Break sight lines and reposition during measured fire and brace. Test that cover buys time without creating an indefinite safe position. |
| **Relay Graveyard** | 5–7 | Wrecked wagon lanes, cable yards, switch rooms, and linked signal platforms. Late waves alternate line pressure and close-range interception. | **Lodestar** in a wide authored rail bed with room for its compound body and both emergence routes. Preserve the armor rule and connected shutdown. Add a campaign-specific relay shutdown, victory reveal, and return to the shelter. |

Each region owns an entry reveal, chamber kit, material and lighting palette, door frame variants, threat motifs, an environmental sound layer, and an authored boss approach. Use existing enemy sprites, player and weapon motion, material warnings, and supported sound paths. The new art budget goes to readable rooms, doors, route markers, regional landmark pieces, and the finale. The first and last room of each region receive deliberate compositions. A seeded sequence can select from approved variations of those rooms.

A boss admission review covers real hit geometry, camera framing, entrances, large-body movement, attack reach, and options for both slow and fast kits. Bosses retain their combat identities. A region may set its own bounded tuning profile after device review. Art timing, hit windows, and recovery remain tied to the encounter’s existing authoritative geometry. Alternate bosses and additional biomes can be evaluated after V1.

Budget at least six encounter recipes per region, including two multi-wave recipes and one authored late-region set piece. A recipe specifies its role mix, positions, wave timing, and layout constraints. Variants can swap an approach, hazard timing, or compatible role within a threat band. Build and test the opening’s first five rooms as a progression of decisions. Room one teaches seal and clear. Room two asks for a choice of range or cover. Room three pairs distinct enemy roles. Room four pressures the player’s preferred reload or escape route. Room five puts an earned boon to work before the boss. The geometry and compatible pack can still vary at each depth.

## 4. Route and room generation

### Data contracts

| Contract | Contents |
|---|---|
| `ExpeditionManifest` | Schema, generator and content revisions, required client capabilities, immutable hash, region order, recipes, reward catalogs, admitted IDs, balance reference, and profile reward rules. |
| `RegionSpec` | Depth bounds, topology weights by depth, threat budgets, reward supply constraints, approved encounter families, hazard mix, boss and fallback definitions. |
| `RoomTemplate` | Stable ID, floor envelope, allowed topology variations, connectors, cover sockets, encounter anchors, hazard masks, transform rules, collision shapes, art references, and allowed body sizes. |
| `RoomPlan` | Stable room ID, depth, template and transforms, resolved geometry or reproducible recipe, door IDs and poses, entrance spawn, hazard configuration, encounter plan, and incoming reward. |
| `EncounterSpec` | Versioned wave recipes, anchor tags, threat budget, delayed/triggered wave conditions, actor ownership, completion rule, and alternate pack. |
| `RewardSpec` | Stable reward family, depth and kit eligibility, rarity, mutually exclusive tags, caps, prerequisite and capstone rules, legal fallback, and display data. |

Start from data exported from authored room pieces in Tiled or a checked equivalent. Runtime generation composes approved modular floor/wall forms, slots in pieces, and instantiates collision and art from the same result. Support joined rectilinear forms such as an L, split room, loop, or linked halls with solid wall rectangles and an outer bound. Validate camera reveal and player clearance over the entire walkable shape. Hazard transforms need matching artwork, navigation, and damage footprints. Allow rotations only where directional art, machine paths, and door sockets support them.

### Generation algorithm

1. **Pin the rules.** Generate a run ID and seed. Pin generator version, content hash, campaign balance hash, and unlock eligibility. Split deterministic random streams for graph, geometry, encounter, reward, and cosmetic decisions so rendering and combat call counts cannot change the route.
2. **Plan region graphs.** Use forward-only layers with a boss node. Normal nodes have two distinct outbound edges. Branches may merge later. Cap node count by using a bounded width per layer. Assign a destination reward to each edge/node consistently so the sign is truthful even when two paths merge. Constrain depth, reward diversity, threat and healing distribution, and capstone opportunities across reachable paths. Place the next region entrance after the boss.
3. **Construct the visited room.** Choose a topology, compatible envelope and connector assignment, then sample cover positions and hazard layout. Apply a region/depth-specific encounter recipe against actual valid anchors. Materialize only the current room and preload the immediate destinations as budgets allow. An exit preview needs only its resolved reward and readable destination details.
4. **Validate and commit.** Validate entrance-to-both-exits reachability, all enemy anchor reachability and clearance, sufficient safe combat area, alternate routes around authored cover, spawn distance, hazard gaps, boss capacity, and camera bounds. Validate projectile sight lines and body-size-specific traversal for each admitted encounter role. Use bounded generation attempts, initially eight, then a known-good room of the same depth/threat/reward tier. Persist the resolved decision and log the reason when a fallback is used.
5. **Check variety.** Measure a normalized floor/collision signature that ignores decoration and simple recolors. Confirm that the same depth produces different routes, cover decisions, and encounter pairings. A series of consecutive rooms cannot repeat the same topology and cover pattern within a run unless the space is an authored story/boss transition.

Use stable ID ordering, fixed-width integer seed mixing, and shared canonical fixtures for Flutter native, Flutter web if enabled, and the server’s structural validator. Store the compact graph and resolved current room plus committed destination in the save. The pinned generator and content can derive future unvisited rooms. Persist exact offers as soon as a reward is revealed. A matching seed and pinned content reproduce route and offers given the same decisions and unlock pool. Real-time combat outcomes remain player-dependent.

### Tools for content work

- Build a CLI to validate the content package, materialize a seed and room ID, export the route, and emit a plan hash, room image, and geometry/encounter report. Add a development-only in-game inspector for nav clearance, anchor masks, spawn reservations, wall collision, and room ledger.
- Provide a fast way to jump to any region, replay a failing room with a known kit, and inspect current and next room art residency. Shipping entry points use normal play and checkpoints generated by the game. Dev commands and fixtures are removed from review builds.
- Keep binary art packaged with the app. Remote manifests may select compatible shipped assets and bounded content values. Ship new geometry primitives, attacks, boon behaviors, and art in a client update. Carry a compatibility reader and required asset IDs for any revision with a resumable run.

## 5. Boons and persistent progression

### Reward families

| Door | What it offers | A build direction to prove |
|---|---|---|
| **Weapon** | Magazine, reload timing interactions, precision or spread, and compatible behavior-changing primary effects. | A shotgun build that rewards deliberate first and final releases. |
| **Ordnance** | Grenade and mine upgrades, new secondary interactions, and controlled area denial. | A mine route that turns dash placement into offense. |
| **Ember** | Ignition, sustained burn, and spread or ground effects. | An ignition payoff that changes which enemy the player targets first. |
| **Storm** | Electrical charge, chain reach, and discharge payoffs. | A build that uses packed enemies as conductors without unbounded chain recursion. |
| **Mobility** | Dash availability, movement-triggered effects, and repositioning rewards. | A build that rewards cutting through a room and setting up a new firing angle. |
| **Guard** | Guard, protection, defensive counters, and sustain mechanics. | A close-range build that survives through timed protection and controlled recovery. |

A boon door normally offers three legal choices on clear. **Repair** is a separate advertised destination and applies a bounded heal. Capstone and boss rewards can offer a smaller curated draft. Each displayed draft must be compatible with the player’s kit and current ranks. Check prerequisites, cap slots, prior selections, conflict tags, and effect budgets before presenting. If a family cannot offer a legal effect, use its authored fallback or offer a different family before the door is shown. Keep the door’s promise once committed.

Provide a viable opening for every admitted starting kit. Build rules can reserve one eligible current-family continuation after a player invests in it and can bias capstone eligibility without guaranteeing identical builds. The generator must offer at least one feasible capstone route by the second boss for each featured build path. A player can still spend those choices on survivability. Document the exact Expedition rank and capstone costs in the content table. Existing Arena rank VIII and fusion requirements continue to use their Arena rules. For Expedition, prototype tighter rank ladders and boon recipes that can mature within the room budget. Preserve intrinsic weapon effects and proc ceilings. Make damage, coverage, or mechanical payoff legible in the next fight.

Test an opening balance with three ranks for most stacking boons, one rank for a behavior unlock, and a capstone that requires a rank-II primary effect and a compatible rank-I effect. An earned boss draft can then present a qualified capstone or an immediate general upgrade. For example, an Ordnance path can take Dash Mine twice and Fragmentation once to qualify for Minefield at the next boss. A shotgun path can pursue Last Shell and Breach Loader to qualify for Breach Engine. Use mode-specific recipe requirements with the existing effect handlers. Start repair rooms at 30% maximum health and region boss recovery at 25%, both capped at missing health. These are test values. Review outcomes across low-health and high-health routes before locking the catalog.

A room reward uses the existing effect application contracts through an explicit Expedition reward source. It spends no Arena XP and does not award an extra XP picker. Design assumptions for V1 are **no random XP-level-up overlays in Expedition**, no ambient free Arena supply rewards, and one reward decision per combat room. Arena mechanics can appear as authored room objectives or hazard variants where they fit. The run carries health, loaded ammo, charges, boon ranks, capstones, and survivor progression. Snapshot any in-progress reload and remaining charge timers, freeze them during rewards and transfer, and resume them in the next room. Health carries through every door, with explicit repairs and disclosed regional boss recovery. Retire room-local projectiles, deployed objects, temporary cover, enemies, and hazards at transfer. A build’s deployable ability remains available under its saved charges and cooldown.

### Between attempts

- Add Expedition milestones, boss clears, deepest region, discovered boons/capstones, and personal clear records in a separate profile namespace. Award once per run ID with explicit completed, defeated, or abandoned outcomes. Abandoned attempts do not grant completion unlocks.
- Early milestones open new reward options or a starter choice. First clear opens a new rule set; higher steps alter encounter budgets, hazard combinations, or elite composition. Players see the rules before starting. The fresh starter kit remains viable at base difficulty.
- V1 uses earned Expedition unlocks and existing ownership. It issues no new spendable Scrap for Expedition, does not call Arena settlement or paid revive, and has no Expedition public leaderboard. These are proposed product boundaries for an offline investor V1. They keep the server’s paid wallet and Arena public records outside a new device-reported reward loop.
- Surface a new attempt’s practical goals in the shelter and results. Show the next reachable unlock or a discovered recipe the player can pursue. Use the current run’s build and regional progression to explain what happened without adding long forced tutorials.

## 6. Flutter and Flame implementation

| Existing seam | Work to do |
|---|---|
| [Menu, loadout, and local route](../lib/views/menu_view.dart) | Add a typed solo mode and an Expedition entry, mode-specific loadout/Continue routing, independent suspended-run summaries, and replacement confirmation scoped to the selected mode. Use account local-play ownership guard across the entire route. |
| [RegunGame](../lib/game.dart) | Introduce a narrow room lifecycle boundary. Split one-time run initialization, room-world mount/retire, and terminal settlement. Keep the route-local notifier, camera viewport controls and shared combat systems through room transfers. Dispatch director behavior by mode. |
| [EncounterDirector](../lib/systems/encounter_director.dart) | Keep time-driven Arena admission. Expedition advances a finite room encounter ledger with active-time wave clocks, boss completion signals, and room-specific pressure profiles. Share spawn validation and cap enforcement. |
| [MapComponent](../lib/components/map/map_component.dart) and [ArenaGeometry](../lib/systems/arena_geometry.dart) | Add a room geometry provider with generated collision and presentation. A door owns a collider and a swept entry trigger bound to its lifecycle. Keep the same geometry consumers for player/dash, projectiles, grenades, navigation, hazards, and boss movement. |
| [GameNotifier](../lib/notifiers/game_notifier.dart) | Add immutable Expedition reward offers and acceptance through shared effect application. Gate stale choice IDs and record accepted effects. Isolate Expedition boon cadence from the Arena XP and supply offer path. |
| [Checkpoint](../lib/models/run_checkpoint.dart) and [RunStore](../lib/services/run_store.dart) | Add Expedition’s schema, slot, validation, atomic transition journal, and recovery. Retain existing Arena file names and schema readers. |
| [Profile](../lib/models/player_profile.dart) and [results](../lib/widgets/run_results_panel.dart) | Add Expedition stats, unlocks, and a receipt journal through the current owner-scoped profile persistence. Add clear and defeat presentation, room/depth/build summary, and quick retry. |

Use an explicit room generation ID on async art loads, callbacks, effects, delayed attacks, and pending spawn reservations. Prepare the destination with combat suspended, release outgoing actors and geometry, and atomically switch renderer, navigation and camera bounds to the new room. Release outgoing audio and asset leases on the same lifecycle. Cancel on route disposal or restart. Maintain at most one active combat world. Start the next room only after safe player placement, data validation, and input reset. Clean up held movement, aim/fire, grenade drag, and controller confirmation on every modal/transition. Crossing with the aim thumb or holding a key during a prior choice cannot commit a door.

Use physical doorway traversal in all input modes. Show icons plus text and shape differences, audible and visible seal state, and focusable boon cards. Support mirrored touch layouts, large text, Reduced Motion, controller disconnect/reconnect, keyboard focus, safe areas, and short landscape displays. Keep both destination signs readable from a safe position. Use a short transition that prioritizes showing the new entrance. Reduced Motion uses a brief fade. Retain approved camera behavior and warning contrast. Add quiet ambient cues in cleared rooms and keep encounter music transitions synchronized with the sealed-room and boss states.

## 7. Save, restore, settlement, and compatibility

1. **Scope storage.** Key files or web entries by profile owner and mode. Keep separate serialized queues, backup recovery, and expected-run-ID guards. Treat legacy solo saves as Arena in their existing slot. Training, Arena replacement, Expedition replacement, and account changes each use explicit ownership and slot rules.
2. **Record the world and the run.** Save schema, run ID, seed, pinned manifest/config, graph or recipe identity, current and pending room, phase and transition sequence, exact draft/claim ledger, health and build, inventory and cooldowns, earned milestones, encounter wave/actor state, boss-specific snapshots, and active clocks. Bound sizes and validate foreign IDs and geometry before mounting. Periodic and background checkpoints capture mid-fight progress with the existing safe-resume policy for transient hostile shots. A committed room clear, terminal state, or consumed offer must never revert to an older live phase via backup.
3. **Make choices transactional.** Serialize room clear, reward acceptance, exit commit, and terminal outcomes. Persist each proposed state change before enabling the next irreversible action. Use stable IDs for room, reward, and door. A crash before a successful write resumes the earlier legal choice. A crash after the exit write resumes the committed destination. While storage is unavailable, surface a retry and retain the current state in memory. Continued combat cannot turn a failed write into a second payout.
4. **Settle once.** Durably record the terminal outcome first. Apply the mode-specific stats and unlocks plus a settled run ID in one owner profile commit. Retire the checkpoint only after that write succeeds. If a crash occurs between these commits, reopen results and replay settlement idempotently. A late autosave or older backup cannot resurrect a terminal attempt. Retry performs a new run only after local settlement is durable. Network sync happens in the background.
5. **Keep identity changes explicit.** A suspended attempt is device-local in V1. Cloud sync covers settled Expedition milestones and records through the existing account sync, under the same account and progress epoch. Preserve the current attach/conflict/reset policy. Do not silently reassign a guest save to an account or merge currency/state from separate owners. Reset/deletion purges the owner’s Expedition saves and pending upload data. Older app versions can write whole profiles, so prove that legacy uploads preserve the server-held Expedition namespace before enabling cross-version sync.
6. **Retain older content.** Update tests cover old Arena profiles, active Expedition runs through newer releases, and removed IDs. Keep the previous compatible generator and content reader for the supported resume window. For an unrecognized schema or missing required assets, keep the saved file and surface a recoverable message with an explicit abandon option. Remote disable closes fresh pilot starts and leaves compatible suspended runs resumable.

## 8. Server and admin

### Server authority

The existing multiplayer simulation remains on SpacetimeDB. Expedition runs locally, including room generation and combat. The identity gateway and private module tables own release policy, durable admin actions, account sync, and optional run measurement. Structural checks on client reports can prove the submitted shape is plausible and deduplicated. They cannot verify the combat. Tag reports **device-reported** in admin and exclude them from competitive records, spendable value, and server-verified claims.

Reuse existing gateway auth, schema migration practices, audited publish and rollback patterns, bounded requests, and disposable integration harness. Add an isolated Expedition release namespace to avoid changing Arena or Online balance pointers.

| Proposed contract | Ownership and behavior |
|---|---|
| `GET /expedition/v1/current` | Public production manifest with immutable digest, required capability, balance hash, and compatible release pointer. ETag/cache support. The gateway checks referenced catalogs. Client verifies supported schema, hash and bundled IDs before adopting it on a **new** run. Bundled defaults work offline. |
| `GET /expedition/v1/availability` | Client-facing availability and supported capability range, with an authenticated staging path for eligible pilot builds. Reuse release-policy conventions. A private review binary can opt in offline with its packaged baseline. General release hides Expedition until enabled. |
| `POST /expedition/v1/reports` | Bounded batch of allowlisted room/run events and terminal summaries. Authenticate with existing account or guest-device mechanism as appropriate. Idempotency by owner, progress epoch, run ID and event ID. Validate manifest, bounded depth/counts/timing, event types, known IDs and branch/offer references where the report contains sufficient context. Keep analytics and progression separate. |
| `/admin/expedition/*` | Authenticated candidates, validation, releases, history, preview reports, publish, rollback, availability and aggregate metrics. Every mutation checks server-side authorization, expected revision, request ID, and reason. Staging/public channel pointers are independent. |
| Account save | Add a bounded versioned Expedition namespace to the existing settled profile contract. Preserve the namespace for legacy writes and account conflicts. Existing authentication, progress epochs, and deletion apply. |

Store immutable private release rows and per-channel pointers, plus audited availability changes. Use transaction-level idempotency and compare-and-set publication so a stale candidate cannot overwrite the active release. Validate ranges, IDs, dependencies, counts, compatibility, deterministic seed fixtures, and capstone attainability at candidate promotion. Generate room samples and soak evidence in the repo’s Flutter content tool/CI. The backend validates structure and a matching trusted validation artifact for candidate publication; it does not simulate Flame rooms. Shared schema and contract fixtures are versioned across all three repos. Verify canonical hashing across Dart and TypeScript.

The server retains bounded terminal summaries and short-lived event detail with an initial proposal of 30 days for raw events and 90 days for aggregate pilot metrics, subject to existing privacy policy and creator approval. Reuse existing collection and deletion controls, offer a local-only pilot path, and keep input streams, email, device secrets, and personal information out of diagnostic payloads. Cap the device queue and retry in the foreground with backoff. Treat 401, revoked epoch, duplicates, and schema rejection separately. On network or reporting failure, play, saving, and local progression continue. Add operational metrics for release fetch errors, invalid manifests, duplicate/rejected reports, queue lag, and version adoption. Test payload limits, rate limits, retention cleanup, and deletion before enabling real reporting.

Version the event contract around started, room entered, room cleared, reward claimed, door committed, suspended, resumed, and terminal outcome. Track branch selection against the number of times each door pair was shown. Count boss reach per started run and immediate retries per completed results screen. Exclude the walkthrough seed and development sessions from pilot retention views. Where a player suspends or drops offline, keep the run distinct from a completed defeat. Group by pinned revision and platform, and include counts before comparing rates.

### Admin workbench

Add an **Expedition** destination to the existing Flutter admin. Reuse its theme, secure session, local drafts, candidate history, revision diff, and audit UX. Implement these views as part of V1.

| View | Operator can do |
|---|---|
| **Regions and encounters** | Edit safe numeric/tier settings for each region, room/encounter weights and budgets, permitted prepackaged room IDs, depth, hazard mix and boss admission. Show units, legal ranges and why an encounter cannot fit a room. |
| **Boons and rewards** | Review family pools, weight bounds, repair amounts, caps, prerequisites and exclusions. Warn about empty pools, impossible capstones, dominant paths, or kit exclusions. |
| **Seed review** | Enter a seed, content revision and kit. Inspect the deterministic route graph, reward coverage, generated room thumbnails and reports exported by the actual client tool, plus a failing room and reproduction ID. Show when a report is stale relative to the draft hash. |
| **Releases and rollout** | See local draft, validated candidate, staging release and production release as separate states. Review the diff and compatibility range, publish by channel, toggle fresh admission, and roll back to a compatible immutable release. |
| **Runs and diagnostics** | View starts, room clears/deaths, door choices, boon picks, first boss reach, first clears, retries, interruption and fallback rates by revision/platform. Expose a run/room/seed reproduction view to authorized operators. Show small-sample counts and device-reported status. |

V1 authors new geometry, art, boon behavior, and boss moves in the game repo and ships those IDs in content packages. Admin edits safe data for shipped behaviors and shows read-only validation evidence. Server checks are the publication gate. A rejected or stale publication leaves local drafts intact and recoverable. Test admin on macOS and iPhone, including large text, keyboard-open, auth expiry, offline work, and lost publication acknowledgement. The current admin checkout has unrelated work in progress around App Updates and Notifications. Preserve those edits and isolate implementation work.

## 9. Delivery slices and exit gates

Each milestone is a playable build with the supporting storage, content, diagnostics, and validation that it needs. Build the first region end to end before multiplying content.

| Milestone | End-to-end slice | Exit gate |
|---|---|---|
| **M0 · Baseline and contracts** | Record client/server/admin revisions and existing verification. Agree on V1 design assumptions, wire schemas, room state transitions, content authoring format, and platform targets. Establish representative device measurements and sample seed fixtures. | Current modes pass baseline checks. A room/boon contract and reproducible generator fixture are reviewable across the three repos. |
| **M1 · First generated region** | Private entry to a real five-room Breach run, multiple physical room forms, sealed waves, two reward doors after each normal clear, distinct boon directions, Walker chamber, defeat/victory/retry, and device-local Continue. Package defaults and seed validator. Use a real touch and desktop playthrough. | Several seeds change both layout and build choices. Resume before/after room choice and mid-boss. Every reached reward can be claimed once and every required encounter can clear. |
| **M2 · Two-region integration** | Add Foundry, safe cross-region transfer, one deeper capstone path, results and progression, and complete admin candidate → validation → staging → fresh client consumption → rollback flow. Add report intake and local cloud-sync tests. | A full two-region run uses the same build across transitions. An admin change affects a new compatible run; the earlier run resumes with its pinned rules. Offline, owner switch, and staging rollback cases pass. |
| **M3 · Full campaign** | Add Floodworks and Relay Graveyard, all four boss encounters, 21–25 rooms, full boon set, collection/milestones, post-clear steps, authored finale, and all admitted kit compatibility. Expand admin diagnostics and fixture library. | Fresh starter kit clears the full campaign on several seeds in release builds. Validate all region/threat bands and capstone paths. All four bosses work in both phases and on real Continue. |
| **M4 · Investor release candidate** | Profile and tune native performance, resolve pacing/readability findings, finish scene/audio/UI presentation, rehearse the live demo, and package signed builds, operational handover, and known-issues notes. | Physical acceptance and test matrix below pass. Demonstrate offline cold start, fresh random run, two alternative routes, legitimate suspended finale, victory, and retry. |
| **M5 · Controlled rollout** | Publish additive schema/gateway and admin to staging first, promote compatible rules, deliver private builds, then enable a pilot cohort. Decide main-menu promotion after pilot review. | Validate fallback and rollback under actual staging conditions. Record all three commit/build IDs, content hash, supported revision ranges, and the pilot decision. Production rollout is a later decision. |

The critical path is **room geometry and encounter completion → durable room transfer → first regional boss → build pacing → content expansion and device polish**. Content kit production, backend release plumbing, and admin tooling can advance independently once M0 fixes the contracts. Budget four workstreams across gameplay engineering, procedural/content design and art, server/admin, and QA/release. Schedule the full-campaign estimate after M1 produces a measured chamber-kit throughput and a tested transition cost. New bespoke boss moves, additional art kits, and platform expansion each affect that estimate.

Cut release candidates from a recorded client/server/admin revision set. Publish the additive server schema and gateway first, smoke old clients and account saves, then deploy the matching admin and stage a validated manifest. Publish the private game builds with a packaged copy of that manifest. Check fresh starts, active-run pinning and pilot analytics, then enable the approved audience. If a revision causes a regression, disable new pilot starts or repoint them to the previous compatible manifest. Keep the affected revision readable for saved runs and keep local settlement available during an outage. A binary defect requires a replacement client build. The review handoff includes exact rollout and rollback commands for the target environment, dry-run evidence, build hashes, and the list of supported saved revisions.

## 10. Verification and physical acceptance

### Automated

- **Generation.** Run at least 10,000 complete graph seeds per supported manifest and stress materialized rooms across every region/depth/template combination. Validate path counts, boss reachability, true distinct rewards, reachable entrances/exits, large-body traversal, valid fallback rooms, capstone reachability, and collision/art manifests. Record known seed and plan hashes. Fail any invalid committed room or nonterminating generation. Tune valid-layout fallback rate below 1% across the corpus.
- **Combat.** Test actual player actions against generated walls, sealed doors, thresholds, cover, hazards, spawn ownership, summoning, multi-wave clears, dash at a door, projectiles crossing a threshold, and last-kill/last-hit races. Exercise each weapon and survivor on each topology class through combinatorial fixtures, plus directed checks for slow, long-range, splash, beam, orbit and multi-hit weapons. Test each boss against constrained camera and worst legal escape lanes.
- **Persistence.** Inject process loss before and after each durable transition and settlement write. Cover mid-wave, pending spawn, live boss, boss shutdown, draft reveal, reward selection, committed door, transfer, and terminal result. Test duplicate input, simultaneous background save, double settlement, read-only storage, corrupt primary/valid backup, owner switch, version upgrade, cache outage, and stale account epoch.
- **Backend/admin.** Check unauthorized access, production/staging isolation, inconsistent hashes, duplicate/stale publishes, lost acknowledgements, rate/body limits, older readers, analytics/report retries, deletion/reset and rollback. Run a disposable real database/gateway smoke from a signed-in admin draft through publish and client consumption to report intake and admin diagnostics. Verify relevant nginx routes, schema upgrade and persistent volume retention.
- **Regression.** Run `make verify` and targeted `make soak` in the game, `npm run verify` and `npm --prefix identity run verify` on the server, and `make verify` in admin. Confirm Arena checkpoints, Online matchmaking/co-op/Versus, Training, Armory, existing wallet, and account flows. Exercise old binaries against the additive server contract in staging.

### Physical devices and playtesting

Use release builds on a representative iPhone, mid-tier Android, and presentation Mac/controller. Measure actual frame times, memory and thermals through a full run and three consecutive room-heavy attempts. Compare same-device Arena and Expedition baselines. Aim for a 60 fps presentation with p95 frame time at or below 16.7 ms on the reference phone during ordinary combat, measure p99 and hitches separately, and review sustained thermal behavior. Set the final supported-device budgets at M0 with measured baselines. Record boss art residency, peak room-transfer memory, p95 room-ready time (initial warm target under one second), and asset return to baseline across retries. Exercise low memory, interruption and restore, muted audio, mirroring, Reduced Motion, large text, controller disconnect, and offline gameplay. Reproduce and fix collision softlocks, visible warning/hit disagreements, and repeated transition hitches before the investor candidate.

Run a small observed cohort with new players and experienced action roguelite players. Let them enter through normal menus with a fresh or representative profile. Ask them after their first attempt which door they took and why, how their build changed, what killed them, and what they would try next. Record first room/boon time, whether they understood the doors without prompting, build maturity at each boss, abandonment points, clear times, branch distribution and immediate retries. Use pilot counts alongside the observations. Investigate repeated confusion in the first two rooms, reward routes heavily favored under similar health/build conditions, and players reaching a boss with interchangeable builds. Tune the encounter or reward that produced the behavior before adding more content. Retention claims require actual cohort evidence.

### Investor rehearsal

1. Cold launch at the shelter and start Expedition with Rook and the Pump Shotgun.
2. Clear a generated Breach room, read both door promises, choose a family, and show its payoff in the next fight.
3. Show a second seed with a materially different layout and spawn plan. Demonstrate one legitimate Continue across a room transition.
4. Resume a real campaign checkpoint in the final region, show a developed build and Lodestar’s armor/shutdown, finish the run, then show the unlock and Retry.
5. Keep a fully recorded uncut clear, one-page run sheet with real build and seed IDs, and a signed offline backup build. Capture the entire path on native hardware. Use an admin staging view if asked how content is operated, with a real revision diff and rollback evidence.

## 11. Risks and implementation decisions

| Risk | Response |
|---|---|
| Procedural rooms feel like recolored arenas | Require distinct geometry signatures and region-specific movement decisions. Compare rooms using the same kit and pack. Cut templates that change appearance only. |
| A generated room can strand a body or leave the exits sealed | Validate against the collision and nav representations used in combat. Bound wave ownership and fallback generation. Reproduce failures from a seed, room ID and revision. |
| Boon RNG prevents a build from maturing | Guarantee reachable continuation and capstone opportunities while keeping healing and specialization in competition. Playtest starter and edge-case kits before extending the pool. |
| Five to seven rooms feel repetitive before the boss | Vary fight duration and combat objective by depth. Mix short packs with specific two-wave set pieces. Adjust encounter content before adding more HP. |
| Room transfers retain entities or invalidate a save | Centralize world ownership and cancellation. Pin manifests and persist exact decisions, with crash injection at every boundary. |
| A live setting damages an active run or exposes untested content | Use compatibility-checked immutable releases and pin snapshots. Roll back new admissions while retaining active-run readers and assets. |
| Client-reported data is mistaken for competitive proof | Isolate analytics and campaign milestones from wallet grants and public records. Mark report provenance explicitly. |
| Too much content enters the polish pass at once | Lock an end-to-end quality bar at M1, use the same production tooling for the other regions, and review one complete region at a time. |

Start implementation with M0 and M1 using the working name, four-region scope, door-earned boons, one-life solo rules, device-local suspended runs, and packaged offline defaults above. The first review build should play as a complete generated region with a boss. The investor build is the complete four-region campaign with functioning admin operations, tested saves, and native playtest evidence.

## Repository references

- Game baseline reviewed at `1952511`, package `1.0.1+46`. Read [AGENTS](../AGENTS.md), [progress](REGUN_PROGRESS.md), [the original complete-game plan](REGUN_COMPLETE_GAME_PLAN.md), [playtest guide](PLAYTEST_GUIDE.md), and [Survival map design](REGUN_SURVIVAL_MAPS_PRD.md) before implementation.
- Server baseline reviewed at `9f39f31`. Extend the existing [identity gateway](../../regun-server/identity/src/http.ts), [admin service](../../regun-server/identity/src/admin.ts), [module schema](../../regun-server/spacetimedb/src/schema.ts) and [deployment proxy](../../regun-server/deploy/nginx.conf). Follow the [server release contract](../../regun-server/docs/ADMIN_AND_LIVE_BALANCE.md).
- Admin baseline reviewed at `ab99631` with unrelated working-tree edits. Start from the [workbench](../../regun-admin/lib/screens/workbench.dart), [admin connection](../../regun-admin/lib/services/admin_connection.dart) and [implementation status](../../regun-admin/docs/IMPLEMENTATION_STATUS.md).
