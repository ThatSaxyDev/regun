# Lodestar / 03 — magnetic serpent workshop

**29 October 2026 · Proposal for creator review · Flutter / Flame**

**Decision:** build a grounded, articulated magnetic serpent. Six connected bodies bend through the arena while induction machinery forges projectiles, plants electrical poles, drives cutting crescents and extends a tail lance. Its whole body is a moving mechanism. This takes the third workshop beyond Walker's artillery and Ariet's flight without abandoning Regun's industrial materials or manual aiming.

This deliverable is the complete workshop blueprint and an identity study. The rig, assets, attacks and playable encounter below are proposed work, not implemented content. Current release stays **1.0.0+28**. First implementation target is an isolated workshop, then a complete Training candidate after review.

![Lodestar identity study](../art/source/bosses/lodestar/identity-v01.png)

Concept art describes the identity; exact counts, joints, sockets and dimensions in this document govern the rig. The board is not an atlas to cut up.

## 1. What the player should experience

A long industrial machine curves across the player's route. Copper flywheels spin under opening iris plates; a visible charge travels along its bus bars. Metal teeth assemble in a forge and launch in a committed fan. Two induction poles land, unfold and briefly conduct between them. The head's crescents open before a physical sweep. Behind the machine, the tail collar turns and its nested lance snaps outward.

The player keeps moving, chooses an opening and fires into real body sections. Getting behind it changes the threat rather than switching the boss off. Its weapons acquire a moving survivor quickly, then commit to readable attacks that can be dodged. Cooling happens while it travels and its mechanisms keep working.

| Boss | Physical identity | How it controls space | Distinct motion |
|---|---|---|---|
| Walker | Long-legged artillery platform | Guns, rockets and assisted melee rush | Planted feet, hydraulic load transfer, independent turrets |
| Ariet | Low-flying gunship with escorts | Fast passes, roof weapons and coordinated crossfire | Thrust, banking, continuous lateral flight |
| **Lodestar** | Grounded articulated induction machine | Curved body routes, forged metal, electrical gates and physical cutting tools | Five constrained couplings, roller bogies, flywheels, iris shutters and telescoping machinery |

No jet engines or missile banks belong to this identity. The magnetic fiction controls **its own manufactured metal and equipment**; it does not reverse the player's controls, drag the survivor, redirect friendly ammunition or require a particular weapon.

## 2. Research and selection

Research accessed 29 October 2026. References inform structure and combat lessons; Lodestar's appearance, rig and arsenal are original proposals. Community descriptions are distinguished from developer accounts.

| Reference | Evidence and lesson | Translation into this workshop |
|---|---|---|
| [Ammoconda — Enter the Gungeon community wiki](https://enterthegungeon.fandom.com/wiki/Ammoconda) | Describes continuous segmented movement, attacks from several segments and segments losing attacks after damage. | A body can supply several threat origins. Use a shared scheduler so independent modules do not all attack at once. Do not adopt healing turrets or indefinite growth. |
| [Serpent — Nova Drift community wiki](https://nova-drift.fandom.com/wiki/Serpent) | Describes chained enemies, sequential broadside fire and chains splitting when middle sections die. | Test the whole curved body and distributed sockets. Keep one connected actor in the first candidate; splitting would multiply encounter and cleanup complexity. |
| [Nova Drift: News & Upcoming Content — developer](https://blog.novadrift.io/nova-drift-upcoming-content/) | The developer discusses clearer entrances, less brute-force randomness and more tactical enemy combinations. Its separate Serpent body-gear discussion concerns the **player's** body, not a boss. | Deliberate arrival, recognizable patterns and a finite footprint. Treat long-body logistics as a rig problem, not an excuse for invisible collision or uncontrolled screen coverage. |
| [Returnal: the making of Hyperion — Housemarque / PlayStation](https://blog.playstation.com/2021/05/28/returnal-the-making-of-that-unforgettable-hyperion-fight/) | The team describes attacks rooted in the boss's instrument, distinct projectile language, designed gaps and repeated readability testing. | Make charge and release visibly originate in the machine. Coordinate shapes and sound; validate an escape route rather than equating danger with projectile count. |

These are reference facts; all proposed timings, counts and acceptance targets below are our design decisions, not values taken from these games. No external artwork or audio is included in the project.

### Directions considered

| Candidate | Strength | Reason for decision |
|---|---|---|
| **Magnetic articulated serpent — selected** | Strong new silhouette; movement and four visibly different mechanisms; naturally modular | Highest contrast with both current machines and a clear sequence for building the difficult rig first |
| Gyroscopic reactor with orbiting tool arms | Excellent independent rings and tool animation | Risks another central platform that parks while weapons move; several floating parts can look disconnected |
| Resonance engine with acoustic horns | Non-military weapons and strong sound identity | Less distinct from existing bell/resonance imagery; harder to communicate fairly when sound is muted |

## 3. Identity, scale and art production

Working name **Lodestar**, workshop number **03**. Suggested short player-facing name: **LODESTAR**. It is a salvage/refining machine repurposed into a predator, not a magical creature or a literal biological snake.

- Exactly six major rigid bodies: one head, four induction carriages, one tail; five visible couplings.
- Initial assembly envelope about **610 × 150 world units**, derived from the current 1500 × 700 camera. At an844px-wide view that is roughly343 logical pixels long when horizontal. These are candidate dimensions, to measure with the real HUD and native DPR.
- Head about144 ×128; carriage art about108 ×116; tail about120 ×100. Center spacing approximately100–108. Couplings close real gaps; they do not stretch to fake missing reach.
- Worn iron, muted olive, old copper and pale ceramic. Cold white/teal induction is a restrained accent. Warnings must differ by shape and motion as well as color.
- Neutral top lighting, authored underside/contact shadows, readable front/rear and a distinct tail. No painted perspective that only works facing one direction.

### Asset and motion breakdown

| Module | Separate moving parts | Sockets / constraints |
|---|---|---|
| Head carriage | Wedge armor, split intake jaws, optic collar, brake pads | Spine neck, two tool bearings, charge path; head collision excludes tool extension |
| Four carriage bases | Armor frame, paired roller bogies and side covers | Front/rear couplers, ground footprint, optional equipment mounting points |
| Five couplings | Two bearing halves, cross-link, copper braid and hose | Actual previous/next sockets; bend limit initially±28°; no disconnect at maximum bend |
| Forge on carriages1 and3 | Iris leaves, counter-rotating copper flywheel, feed fingers, formed metal teeth | Forge center and actual release lips; individual teeth appear before launch |
| Pole carrier on carriage2 | Two bay doors, sliding deployment cradles, two folded poles | Dock and release transforms; pole hinge, landing foot and conductor tip |
| Power unit on carriage4 | Flywheel, iris, load indicator, cooling louvers | Shared charge bus and phase-change exposure |
| Head cutting assembly | Two support arms, elbows, crescent tools, bearing collars | Bounded extension/rotation; tool edge stays attached and clears own hull |
| Tail carriage | Independent yaw collar, three nested lance stages, recoil slide | Root, extension stops, tip; folded state remains distinguishable |
| Damage / failure | Bent covers, stopped rotors, released jaws, inert wreck sections | Same rig sockets; no new unconnected replacement silhouette |

Create new compatible isolated art after identity review. Required manifest: source rectangles, source pixels/world size, normalized pivots, coupling endpoints, tool edges, pole tips, lance tip, paint order, height, rotation limits and damage shapes. Use a source atlas separate from any downsized runtime decode. Estimate pixel coverage from real phone rendering before setting decode sizes. Never cut the six bodies out of the concept sheet and call that production art.

## 4. The articulated rig — first engineering gate

The rig is the main new work. Combat waits until it moves convincingly.

**Proposed model:** one owner/actor ID, a head navigation path sampled by travelled arc length, and five followers evaluated at fixed distances along that path. Every body gets its own solved ground transform. Constrained couplings connect real sockets. Yaw comes from adjacent path samples rather than a sine wave. Locomotion consumes actual accepted movement, not requested velocity.

Start with a minimum head turn radius around **220 units** and validate it against the±28° joints. Joint reach, center spacing and the final art must agree mathematically. If a route cannot fit the full body, use a wider turn or retrace the accepted path. No teleporting followers, rubber couplings or sliding the tail through cover.

**Collision is compound.** Reserve the six body footprints and connecting physical spine under the same actor. Sweep every relevant footprint before committing a movement step. Either accept a legal articulated pose or reduce that step/replan. Extend actor-based occupancy deliberately; moving only the head through `moveActor` does not validate the tail. A single huge enclosing circle would block visible empty space and is not acceptable. Friendly enemies yield to the compound body; keep pending spawn reservations separate.

The player can move through visible empty space between bends, but not through armor or the connected spine. Normal travel does not inflict passive contact damage or shove the player into a hazard. Routes avoid the survivor's current body; an interrupted route slows and replans instead of clipping through them. Damaging tool contact belongs only to the explicitly warned weapon windows.

Roller rotation follows each module's signed travelled distance. Braking closes visible pads; iris shutters and flywheels respond to load. Short stops still show machinery working. Coupling cables use bounded curves joining sockets, never long springs. Tail movement remains attached after walls and path reversals. Ground shadow/contact is distinct from equipment height projection.

### Motion acceptance

An isolated `tool/lodestar_workshop.dart` should eventually expose: Straight, Broad turn, Figure eight, Brake/resume, Reverse, Wall, Narrow route, Player crossing and Reduced Motion. These controls are planned, not present yet.

- Solve at a fixed120Hz; compare accepted trajectories and joints at30/60/120Hz presentation.
- Continuous ordinary travel target260 units/s; phase two300, with acceleration initially900. Tune around the **whole** body and current player speed, not head pursuit alone.
- Target at least85% active encounter time above40 units/s in open-arena tests. No incidental stop longer.5s; the clearly braced tail thrust may deliberately hold up to1.3s. Arrival, pause, recovery deployment and destruction are measured separately.
- Cooling moves at approximately180; it is a firing opportunity, not idle parking.
- Show eight headings on both actual floors with player, normal camera and HUD; no camera zoom to hide the footprint problem.
- A six-body pose must fit the available route and remain separated from itself. Reject tight closure around the player; keep an open escape corridor at least220 units wide during any C-shaped approach. Narrow arena situations select a simpler route instead.

Reduced Motion retains necessary movement, joints, tool poses and warnings. Remove optional body oscillation, camera effects and rotor streaks; use lower-frequency clear load changes. Pause freezes simulation clocks and mechanism state.

## 5. Four weapon systems

Values are **starting test candidates**. Initial accepted damage is1HP per attack sequence, including both blades or both electrical pulses; damage contact cooldown still applies. No heavy move adds unannounced body damage. Faster scheduling, positioning and combinations supply difficulty before damage increases.

### A. Shard Forge — manufactured kinetic projectiles

Carriage1 or3 opens its iris, spins the induction rotor, draws visible metal slugs into the feed fingers, then ejects a committed fan from actual forge lips. Distinct heavy iron teeth with bright cut faces and short induction tails; never two tiny glowing dots.

Candidate: .9s preparation; heading can follow movement until the final.25s, then locks. Two five-tooth fans .22s apart,640 speed,760 maximum travel. The second fan has its own visible index shift committed in the first warning. Both waves share one1HP damage budget. No homing after release. The director reserves a visible escape corridor; it may omit a tooth to preserve it.

**Counterplay:** move out of the committed fan or into a deliberately wide gap; close-range tests must not assume every decorative gap fits the player. Forge sockets swivel independently, giving meaningful side/rear response while the body turns. Clear the launch path against its own body and cover. If obstructed, reposition or choose the other forge; do not emit through armor.

**Workshop proof:** run one forge alone through sixteen bearings and short/mid/long ranges against a continuously moving target. Show charge, tooth construction, lip release, straight travel, cover impact, spent rotor and moving cool-down.

### B. Induction Gate — physical deployable electrical weapon

Carriage2 opens its two cradles and launches a folded pole from each real socket. Poles travel, land and unfold before conducting. Each is physical shootable ordnance with1HP, not another AI enemy. They stay where they landed while Lodestar moves away.

Candidate: at most two poles; no damage during flight/landing. After both tips are ready, a fixed **.95s warning** connects their committed positions. Then two .18s conduction pulses with a .45s off interval. Tip shutters/load lights show which interval is live. Both pulses share one1HP budget. Poles fold/fade after the second pulse or expire within4s total. Destroying either pole cancels the pending connection immediately.

Conduction follows the cover-clipped segment between the actual tips with an initial damage radius18. Render material electrical filaments, dark conductor backing and planted terminal sparks on that same geometry. No abstract full-screen lightning, invisible extra width or arc through solid cover. Pole flight/cover can invalidate a pair; abort instead of drawing across an unvalidated destination.

**Counterplay:** leave the lane, use cover, or shoot a pole. Never place a terminal on the player or build a gate that seals the only exit. It may redirect the player's route, but it does not pull them. Both poles must be visible when the warning begins; defer or select another move otherwise.

**Workshop proof:** both flights, cover clipping, destroy-one cancellation at every stage, alternating pulse states, finite cleanup and a retreat path with the full serpent body present.

### C. Crescent Shears — actual moving melee tools

Head bearing collars rotate toward a chosen sector, arms extend, jaws spread and the cutting crescents sweep through a committed arc. Tools have visible arms and joints. Any apparently suspended blade is carried by its support; no ornamental detached ring.

Candidate: .8s preparation, then a .5s120° sweep at approximately175-unit reach. Left/right sweep direction is committed before warning; blades share one hit budget. The body takes a short committed low-speed route during the move. Preview the **combined future body/tool path**, then execute that saved path; do not home the sweep after commitment. If a collision would invalidate the saved pose, abort damage and retract.

Collision sweeps the physical blade capsules between substeps, leaving actual empty gaps empty. No damage over a filled disk. The tool must clear the serpent's own carriages before staging. The load rotates out of the strike and retracts visibly while the boss resumes normal movement.

**Counterplay:** leave the marked arc, pass through the validated open side, or retreat beyond the blade. Initial warning must provide a walking escape; dash can improve the opening but cannot be the only legal response.

**Workshop proof:** blade edge/socket agreement, max extension, all bearings, body curvature, cover abort and a player slipping through the genuinely empty side.

### D. Tail Lance — rear pressure with telescoping machinery

The rear collar acquires a bearing quickly while the rest of the machine travels. Brake pads engage, nested lance stages load, and the tip thrusts down a fixed line. This supplies credible danger behind Lodestar without turning the whole serpent instantly.

Candidate: .85s warning with committed target line, .22s extension, .10s damaging hold, .35s retraction. Maximum tip travel approximately380 beyond the tail socket. Root/body braking begins at commitment so warning and thrust share one planted transform; deliberate total hold at most1.3s. Motion resumes as the lance retracts. Final values must fit that cap and preserve sufficient response time. A miss does not retarget during extension.

Use swept physical lance contact, cover clipping and one hit budget. It cannot pierce the serpent itself. Full360° collar acquisition is conditional on a clear extension arc; blocked angles select a different socket/attack while the body repositions. Initial tracking target8rad/s; commit before extension. No invisible damage along the whole warning line before the tip arrives.

**Counterplay:** step sideways out of the lane, then punish its retraction. This is a distinct braced action, with load, extension and release clearly visible.

**Workshop proof:** one segment→two→three stage extension, actual tip contact, rear circling, close player, wall stop, interrupted staging, pause and recovery.

## 6. Movement intelligence and attack coordination

It continuously chooses broad intercept routes and side exchanges. Estimate player movement with bounded history; discard stale intent on teleport/recovery. Use prediction to **choose** a route and aim, then honor the committed warning. It must fire at moving targets; no acquisition condition may require zero player velocity.

A shared director owns all module clocks and reservations:

1. One major attack at a time. Pole flight, warnings and both live/off pulse intervals reserve the gate sequence until it ends.
2. First candidate has no attack overlap. After isolated acceptance, phase two may add **one three-tooth forge support fan** during a gate's off interval, only if a combined reachable-space check passes. No shears/lance overlay; no support firing during recovery. Failure to prove the route means single-attack sequencing.
3. All distant projectiles must finish or be harmless before quiet recovery starts. Recovery is.8s with no new hostile release while the body continues travelling. It must remain a real opportunity to reload/fire.
4. Do not repeat the same major attack immediately. Weight socket visibility, cover, player range, previous escape lane and last move. A blocked tail cannot hold the turn forever; pick a legal forge or reposition immediately.
5. Deadline main attacks against optional support. No module can repeatedly restart a timer and starve another. Publish selected move and reason in the development overlay.
6. No simultaneous normal mobs in the first workshop/Training candidate. Future crowd admission must preserve the same body/escape checks, rather than compensating for a weak boss with adds.

**Rear coverage acceptance:** place a moving survivor at sixteen bearings and at150/350/650-unit distances. Within2.5s a suitable visible weapon should start a readable threat, or active repositioning must begin immediately if cover/self-occlusion prevents release. No unbounded aim alignment wait. This measures initiation, not unavoidable damage; changing direction must still evade committed attacks.

### Initial scheduling candidates

Cooldown starts after a sequence finishes and freezes with active simulation time.
These values prevent one attractive weapon from monopolizing the fight; they are
starting points for the Training playtest, not approved balance.

| Family | Individual cooldown | Phase-two change |
|---|---|---|
| Shard Forge | 4.2s shared across both forge carriages | 3.8s; full warning retained |
| Induction Gate | 8s after both poles are harmless | 7s; same two-pole limit and pulse warning |
| Crescent Shears | 5.5s | 5s; same warning and sweep reach |
| Tail Lance | 5s | 4.5s; same committed line and hold cap |

The shared.8s no-release recovery still applies between sequences. If every weapon
is unavailable, travel and visibly reload; begin the next legal warning promptly
when a module is ready. Do not invent an idle pause on top of these clocks.

## 7. Full encounter candidate

- **Arrival:** choose a clear visible approach corridor with enough room for the full body. A low industrial grinding cue and advancing dust/scuffs precede the head. Carriages feed into view in order; weapons stay safe until the tail has entered and every body is legal. No underground emergence beneath the player, occult portal or reused sky drop. If a legal corridor is unavailable, defer deployment.
- **Phase one,100–50%:** learn all four families separately. Initial health candidate200 sharedHP; compare real kill times against Walker/Ariet and all current weapon/survivor loadouts before committing balance.
- **Phase change:** shutter armor opens to show hotter induction cores and exposed copper. Existing attack finishes safely or cancels through a defined non-damaging transition; no retroactive warning speed-up, free healing or invulnerability puzzle.
- **Phase two,≤50%:** travel260→300 and shorter *between-attack* waits; retain minimum warnings. Optional gate/forge support remains disabled until combined escape review passes. No growth, split bodies, extra poles or reinforcement waves.
- **Defeat:** disarm immediately, stop new damage/projectile releases, brake the body, unwind flywheels in sequence, vent through open shutters, then settle into six connected inert sections. Pole conductors extinguish and remaining ordnance becomes harmless visibly. Distinct sequential machinery failure, not another giant death explosion. Wreck is non-blocking and finitely cleaned up. Reward/completion once, only when admission later defines them.

The Training candidate should provide protected-health practice, Take damage, full-fight restart and a deterministic attack selector. Normal player deployment/recovery, pause and input gating retain existing shared behavior. Native full fight follows module review; a debug attack selector alone is not a completed boss.

## 8. Shared damage, geometry and lifecycle contracts

One boss, one health pool, one encounter owner. Six damageable bodies do **not** mean six rewards or six applications of the same shot. The union of actual body shapes supplies first contact; empty bends are not a filled giant circle.

- One primary projectile may damage the boss once even if it crosses several sections. Distinct shotgun pellets retain independent ordinary hits. Preserve cumulative-distance ballistics sampled at the first swept contact.
- Piercing/bounce cannot refresh the boss hit identity. Arc chains cannot treat another body section as a new enemy or multiply proc budgets. Grenades/mines/explosions apply once per boss if any legal visible section intersects their blast; cover still applies.
- No baseline per-section invulnerability. Baseline modularity is a construction/animation choice, not six new armor-health systems. Optional destructible carriages/splitting are deferred until the core encounter proves useful.
- Pole targets use the existing shootable-ordnance contract; destroying them gives no enemy XP and never heals the boss.
- Warning, visible mechanism, release socket and damage use the same committed transforms. Swept blade/lance contact and fast projectiles cannot rely on endpoint-only tests.
- All pose/attack clocks use active simulation time. Pause/picker/entrance freeze charge, flight, pole pulses, cooldown and destruction. Restart/leave/death invalidate every delayed callback and release pending art leases.
- Attach all damage, projections, ordnance and effects to the encounter owner. No invisible poles, duplicate release on resume, stale hitbox after retraction or delayed hit after defeat.

## 9. Phone-scale readability, VFX, sound and budgets

Keep the current camera and controls. A long boss can move partly out of view; an offscreen module cannot start a targeted major warning. Clipping the warning below a thumb is also a failed framing case. Reposition the boss, not the HUD. Keep body priority/ground effects ordered from the true transforms; height is not collision translation.

Warnings retain a consistent reserved visual family but differ materially: iron teeth/forge feed, two conductor terminals and a fixed lane, a physical curved blade scuff, and a narrow lance gouge. Effects must blend with Breach and Foundry while staying readable. Reuse `AttackVfx` infrastructure with appropriate new material sprites; do not recolor one generic circle for every weapon. Shared floor warning/damage geometry remains authoritative.

Audio plan: roller rumble with joint load ticks; rising induction whine; solid metallic shard release; dry pole landing, charge latch and distinct live-pulse crack; loaded tool bearing and blade drag; telescopic lock/thrust/retraction; sequential flywheel rundown. One bounded motion loop plus existing limited one-shots, SoLoud groups/mute/lifecycle. Keep warning recognition available without audio. Use documented original/cleared sources; this proposal has no newly sourced runtime audio.

Initial ceilings, to profile rather than assume:

| Resource | Candidate ceiling |
|---|---|
| Main bodies / couplings | 6 /5, fixed; one occupancy/damage owner |
| Major attacks / optional support | 1 / at most1 three-tooth fan after acceptance |
| Live induction poles | 2 total, including flight and pending loads |
| Live hostile moving projectiles | 20; reserve entire volleys before starting |
| Moving damage tools | 2 crescents or1 lance, never both live |
| Transient impact effects / persistent floor marks | 8 /12; finite lifetimes and viewport culling |
| New decoded boss art including VFX | Target≤12MiB; total shared encounter art stays within existing32MiB ceiling |
| Motion loops | At most1, released on exit |

Atlas sharing/instancing of four carriage bases saves texture memory; do not duplicate decoded sheets for each segment. Keep role-specific caps/shutters distinct through separate parts. If art exceeds the target, measure useful resolution and repack before increasing the established encounter budget. Native frame time, heat, allocations and comfort require actual device runs.

## 10. Workshop build order and review gates

| Gate | Build exactly this | Required proof before adding more |
|---|---|---|
| **0 — this proposal** | Research, identity board, component/attack contracts, risk list | Creator reviews direction, silhouette, arsenal and complexity |
| **1 — one carriage + joint** | New isolated part art, real pivots, rotor/iris/roller and one coupling | Connection holds at all angles; readable at phone scale on both floors |
| **2 — full locomotion** | Head +four carriages +tail, compound occupancy, accepted path and reversible couplings | Figure-eight/walls/player crossing; no self-crossing, stretched joints, tail teleport or parked AI |
| **3 — Shard Forge alone** | Aiming, feed/build/release, actual material projectile, impact and cooldown | Moving-target hits AND committed-direction evasion; all bearings and cover |
| **4 — Induction Gate alone** | Actual two-pole flight, warning, pulse timing, shootability and cleanup | Interrupt/cancel at every phase; surviving walking route with whole body |
| **5 — Shears alone** | Arms, crescents, saved movement/sweep, contact and retraction | Painted edge matches swept damage; empty side truly passable |
| **6 — Tail Lance alone** | Fast collar, brace, nested stages, swept contact and moving recovery | Rear threat, bounded stop, no self/cover penetration or homing thrust |
| **7 — complete Training fight** | Director, arrival, both phases, defeat, settings/restart/recovery and all modules | Full end-to-end playtest; no isolated-module-only completion claim |
| **8 — admission later** | Only after Training acceptance: chosen roster slot, rewards/save schema, online capability/parity | Separate normal/co-op review; never silently route a new kind through a legacy boss branch |

Each module is built end to end before the next: art → attachment → movement → warning → release → damage → recovery → cleanup → render/motion proof. Gates are concrete review checkpoints, not instructions to leave a half-working weapon in the Training candidate.

## 11. Verification plan and risks

**Portable rig/system checks:** deterministic fixed-step motion; bounded joint/reach error; socket continuity; signed roller travel; full-body swept occupancy and self-separation; wall/reverse handling; every module's independent targeting/commitment; gate pulse/destroy timing; high-speed contacts; capacity reservation; active-clock freeze and owner teardown.

**Native integration checks:** all24 weapon/survivor/arena combinations; actual moving-player acquisition/hits and sharp-reversal evasion; rear/side/close angles; one-shot identity across six sections; grenade/mine/chain/bounce behavior; pole interception; restart/death during pending loads; defeat cleanup; Training recovery; memory accounting and Reduced Motion. Actual rendered pixels must show connected joints and readable ordnance; passing headless geometry is not art acceptance.

**Physical review:** release build on the iPhone at normal HUD scale, both floors, muted audio, Reduced Motion and mirrored controls. Observe comfortable walking escapes, reload opportunities, readable source/target relationships, meaningful aggression, steady frame pacing and repeated-fight heat/memory. Record device/OS, build, duration and actual observations. Installation alone establishes none of those.

| Risk | First experiment / fallback |
|---|---|
| Long body jams against cover or traps the survivor | Gate2 full compound route test before combat. Widen routes/reduce bend, preserve physical gaps; no giant-circle collision shortcut. If it still fails, revise segment spacing before producing final art. |
| Serpent following looks rubbery | Fixed spacing and constrained socket solver; inspect slow motion, reverse and wall stop. Redraw coupling art if its actual reach is inadequate. |
| Mechanisms disappear at phone scale | Render at real camera/DPR early. Fewer larger shutters/teeth instead of added noise; keep intended boss size. |
| Multiple sections multiply weapon damage | One actor/hit ledger and first contact regression before full arsenal tests. |
| Magnetism reads as arbitrary magic | Show feedstock, copper conductors, mechanical load and physical release. Restrict forces to authored ordnance; no unexplained player displacement. |
| Gate plus body produces an unavoidable prison | Validate a connected walking escape over the whole committed timeline, including body movement and cover. Defer attack if invalid; optional support stays off until proved. |
| Threat is impressive but passive | Continuous-motion duty test, bounded acquisition and moving-player native hit test. Quiet recovery still travels. |
| Too many custom systems at once | Finish Gate2 before weapons; finish each weapon before combining. Defer splitting, destructible carriages, adds and online work. |

## 12. Review decision

The recommendation is **Lodestar with six connected bodies and all four weapon families**, delivered through the gates above. First approval is the identity and full encounter direction. The next concrete work would be the carriage/joint art and isolated articulated movement workshop.

The key choices to review are: the grounded serpent silhouette; magnetic/industrial weapons instead of military guns; a dangerous rear-mounted lance; and a first candidate focused on one connected machine rather than reinforcements or split bodies.

**Deliverable boundary:** this proposal adds review material only. It does not replace Walker/Ariet, change gameplay balance, add a new boss enum, install a phone build or change the release number.
