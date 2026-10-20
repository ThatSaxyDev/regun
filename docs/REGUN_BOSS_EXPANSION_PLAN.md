# Regun — five new bosses on the road to fifteen

Design proposal · 19 October 2026. Scope: plan five additions, bringing the roster from three to eight. Fifteen is the longer-term roster goal; the remaining seven are not specified here. This document records the original proposal. The five-boss implementation and randomized Training Boss Rush now have a candidate; see the latest REGUN_PROGRESS.md entry and PLAYTEST_GUIDE.md. Networking remains future work.

## The direction

Five encounters the player can recognise from a silhouette, a sound and one sentence about how they fight. Borrow the Souls-like appeal of anticipation, commitment, learning and earning an opening. Preserve Regun's own identity: manual aiming, magazines, reload pressure, twin-stick movement and dash. Do not copy another game's characters, attacks or presentation.

Defeating the existing three within an hour is feedback, not a sufficient difficulty measurement. Establish whether the player won first try, learned after deaths, used Training's protected health, or found a dominant build. A practised player winning is desirable. Repeatedly succeeding by holding one direction and firing without reading attacks is the problem to solve.

The new bosses should create stories: **the bell that strikes twice; the judge who draws chains across the floor; the saint who replays your escape; the furnace you dismantle under pressure; the marshal whose thrown weapon is still fighting you.** None relies on a long-distance dash as its central mechanic.

## What the current code gives us

Reviewed `lib/components/enemies/shadow_boss_component.dart`, `pattern_boss.dart`, `boss_encounter.dart`, `lib/game.dart`, `lib/systems/encounter_director.dart`, `lib/models/run_checkpoint.dart` and the current crowd implementation.

- Shadow combines aimed fans, a committed dash and a close strike. Demon combines cleave, marked slams and charge. Queen combines tail strikes, brood and poison. These establish warning → commitment → impact → recovery, a half-health phase, cores, damage ownership and cleanup.
- Demon and Queen share `PatternBoss`; a non-Demon branch frequently means Queen. Adding enum entries would accidentally route new designs into Queen behaviour. Give each new boss its own controller built from shared attack primitives.
- Selection is currently `bossesDefeated % 3`; cycle health scaling also assumes groups of three. More enum values alone will not expand progression correctly.
- The game/HUD/director assume one `activeBoss`. Restore explicitly rejects multiple bosses. Damage tracking and cleanup must become encounter/actor specific before pairs are enabled.
- Shared body occupancy, crowd yielding, pending-spawn reservations and population gates are foundations to retain. A boss fight does not get permission to fill the screen with adds.

## The five

| Boss | Main test | Signature | Opening the player earns |
|---|---|---|---|
| The Bellkeeper | Timing and restraint | A visible strike followed by a delayed echo | Crack the bell during its final recovery |
| The Chain Magistrate | Route planning and angle control | Anchors turn open floor into a changing chain diagram | Bait the crossed chains, then flank the exposed body |
| The Mirror Saint | Recognition and changing habits | Replays a short, marked section of your previous movement | Identify the real body while its glass is exposed |
| The Kiln Sovereign | Arena management and target choice | Vents and limb attacks build toward a pressure release | Disrupt a valve to expose the furnace core |
| The Last Marshal | Firing discipline and opportunity | A thrown weapon keeps attacking while he fights unarmed | Punish the stance change or interrupt the weapon's return |

### 1. The Bellkeeper — “The first ring is not the last.”

**Reveal.** A huge copper bell is lowered onto the floor. A gaunt quarantine officer unfolds beneath it, dragging its clapper like a hammer. A short visible pulse accompanies the first toll. Keep the floor readable; do not shake the whole screen or require sound to understand the attack.

**Combat loop.**

1. **Broken Toll:** an expanding shockwave with a clearly marked missing sector. The boss visibly prepares the sector before striking. Move into it; ordinary movement must suffice for the intended route.
2. **Clapper Sentence:** a slow, locked hammer sweep followed by a ground impact. The lifted clapper and directional floor arc establish its reach. Move around the committed side; shoot during recovery.
3. **Second Toll:** the bell visibly continues vibrating after the first wave. An outer pulse indicator counts down an echo through the previously threatened sector. Do not rush back just because the first wave passed.

**Second phase.** The bell cracks at half health. The echo travels in the opposite announced direction; the clapper sweep can precede a toll. Teach the echo by itself before combining it. At most two wave fronts may exist, with distinct first/echo markings.

**Counterplay.** A side opening exposes the clapper assembly after the signature sequence. Any weapon can exploit it; sufficient damage interrupts the next toll and earns a longer opening. Missing the interruption means another avoidable sequence, not an unavoidable blast. No permanent invulnerability except a brief readable arrival/transition if needed.

**Why it is formidable.** It punishes panicked return movement and greedy firing after an apparent opening. It does not need to outrun the player.

**Production needs.** Separate bell/clapper layers; planted strike, resonating bell, cracked-phase poses; two distinct toll sounds plus a quiet recovery cue. First prototype: one wave with a real gap, then its delayed echo.

### 2. The Chain Magistrate — “Choose your route before the sentence falls.”

**Reveal.** A tall executioner in a worn containment mantle plants two enormous chain anchors. Chains scrape across the floor before tightening. This is one readable figure with large props, not a mass of small bodies.

**Combat loop.**

1. **Writ of Iron:** two anchor destinations are marked and then planted. A dashed line shows the chain that will become dangerous; it is non-damaging during setup.
2. **Draw the Line:** the Magistrate tightens one chain and sweeps its marked arc. The far side remains an escape route. Chains are attack shapes, not suddenly appearing solid walls.
3. **Cross Examination:** a second chain crosses the first, but they activate in sequence. The overlap creates a deliberate passage between activations, rather than two simultaneous walls.

**Second phase.** The executioner reels an anchor back and plants it at a newly announced position. The pattern changes while the player recognises the same rules. Maximum two anchors and one major active sweep; no endlessly accumulating chain web.

**Counterplay.** Bait anchor placement away from the route you intend to use. Shoot an exposed anchor clasp to cancel its next sweep, or avoid the sweep and attack the boss directly. Destroying a clasp is an advantage, not a DPS gate or a mandatory precision shot for one gun. No forced long-distance dragging, stolen controls or unavoidable wall pinning.

**Why it is formidable.** Retreating in a straight line creates poor angles. Good players prepare space, then cut inside during the reset.

**Production needs.** Separate chain/anchor assets, locked line/arc collision primitives, clasp damage ownership and an anchor-return animation. First prototype: one anchor and one honest sweep around existing columns.

### 3. The Mirror Saint — “Your last escape becomes the next attack.”

**Reveal.** A bone-white medical figure steps between two large smoked-glass panels. One reflection moves a fraction late. Its shoulders open into a single broad glass mantle, avoiding a dense field of small repeated shapes.

**Combat loop.**

1. **Recorded Escape:** record a short recent player route, simplify it to at most three segments, then show its full outline before a cutting light traces it. Change your route instead of running the same circle again. Recording ends before the warning; the attack never secretly keeps recording your current input.
2. **False Benediction:** one separated projection performs an obvious imitation while the real body casts a different attack. The real body always has a stable visual tell, such as a broken shoulder plate and a floor shadow. Never depend on colour alone.
3. **Split Light:** the two panels announce a reflected beam path, including its corner. The path locks before activation. Step off the full path or break an exposed panel to cancel that cast.

**Second phase.** The Saint alternates its recorded-path attack with a panel beam. The projection stays limited to one, and its position cannot hide the real body's warning. This is not a projectile-count multiplier copying the player's entire developed build.

**Counterplay.** Identify the body, change direction after the route snapshot, and fire when the mantle opens. Panel destruction gives a temporary opening; panels reform only during a visible reset. All weapons retain a reasonable way to damage the body without perfect aim at a tiny object.

**Why it is formidable.** Repeated habits become dangerous. Recognition and deliberate direction changes beat it; random teleporting and unreadable clones are unnecessary.

**Production needs.** Route snapshot/trace primitive, bounded reflected-line solver, distinct real/projection poses and large glass panels. First prototype: the recorded route alone, with no clones or beam.

### 4. The Kiln Sovereign — “Make the furnace lose pressure.”

**Reveal.** A huge furnace chassis kneels onto four heavy supports. A copper faceplate opens to show the core. A pipe runs visibly from each valve to its threatened sector, connecting cause and effect.

**Combat loop.**

1. **Pressure Grid:** activate a small set of marked floor sectors around the fight, leaving a connected, reachable route. Show pipe/valve pulses before heat rises. These are bounded local hazards, not a replacement map or an arena-wide floor lottery.
2. **Foundry Foot:** one support lifts, stamps and remains briefly exposed. The targeting position locks before the foot falls; the whole machine does not dash after the player.
3. **Furnace Breath:** a broad directional heat sweep rotates through its shown arc, with a visible trailing safe sector. Turning direction requires another warning.

**Second phase.** A ruptured valve changes which sectors are threatened, then the boss pairs a stamp with a pressure release. Previously safe ground is not made damaging without a new warning. Keep at most three pressure sectors, one stamp and one major release within the encounter's shared budget.

**Counterplay.** Shoot a clearly exposed valve during its pressure cycle to cancel one release and expose the core. Or take the longer safe route and attack the body. The boss takes normal damage outside core openings; the core rewards good play rather than making the encounter invulnerable busywork. Weak points share the boss's damage ledger so a shotgun blast or lightning chain cannot count the same hit several times.

**Why it is formidable.** It attacks the space the player relies on. Success comes from making and preserving a route, not merely moving faster than the boss.

**Production needs.** Chassis/support/valve layers, directional sweep and pressure-sector primitives, bright readable core animation. First prototype: two valves, one release and one connected safe route in each existing arena.

### 5. The Last Marshal — “Watch the weapon, then watch his hands.”

**Reveal.** An armoured survivor checks a single oversized sidearm, ejects a spent casing and drops his long hooked blade into the floor. The opening pose resembles a duel. He is readable and grounded; no full-arena lunges or constant teleporting.

**Combat loop.**

1. **Measured Fire:** a deliberate two-shot sequence with a visible pause and a committed firing line. Bait it, reposition, then shoot during the mechanical reload.
2. **Iron Courtesy:** the Marshal visibly braces his weapon to deflect frontal shots for a short window. Firing into the brace can trigger a separately telegraphed counter, never an instant returned hit. The boss does not read raw player input to counter before the shot exists. Flanking, holding fire or waiting for recovery all work; reflected player shots never change faction and hurt the player.
3. **Return to Sender:** he throws the hooked blade into a marked floor position. While he fights near his body with short committed cuts, a chain shows the blade's eventual return route. Its return is another warned attack, not harmless scenery becoming lethal without notice.

**Second phase.** The blade can remain planted through one extra body attack before recall. He may change from gun to blade stance after a clearly shown reset. Fixed, learnable sequences vary with distance and cooldowns; do not create arbitrary infinite combos or choose the perfect answer after every dodge.

**Counterplay.** Punish his reload and stance changes. Hit the planted blade's clasp during its exposed interval to delay recall and stagger him, or move out of the announced return lane. Burning, chains, mines and drones retain explicit interactions rather than being silently disabled by his brace.

**Why it is formidable.** It asks the player to manage the magazine, recognise a real opening and track two connected threats. The weakness is commitment: when he chooses an action, a practised player can exploit it.

**Production needs.** Gun/blade/chain layers, brace and reload poses, planted-weapon ownership, reliable recall-path collision. First prototype: measured fire, brace and genuine reload recovery; add the thrown blade after the duel works.

## Difficulty rules for every boss

- Start by proving a player can lose because of a recognisable mistake and win by changing behaviour. Do not start by multiplying health or shortening all warnings.
- Use roughly 0.9–1.2 second first-exposure warnings as prototype seeds. Delayed attacks can wait longer, with a visible countdown/pose. These are tuning proposals, not validated universal timings. Enrage combines taught moves before it accelerates them.
- Target roughly 75–120 seconds for an ordinary appropriately developed build during initial tuning. A strong build may finish faster. Do not secretly raise health because the player has a good build; record equipment and compare comparable attempts.
- Normal openings around 1.2–2 seconds let the player punish. Each kit also needs occasional longer spacing/recovery opportunities, around 4–4.5 seconds as a starting point, so the original 3.7-second empty-shotgun reload remains viable. An opening is not player invulnerability.
- Prototype most ordinary hits at one heart, heavy committed hits at two. Threat comes from decisions and sequences, not casually deleting a six-heart survivor. Existing guard and damage cooldown apply consistently.
- There must be a baseline movement route through intended patterns, including slower Warden. Dash, Afterimage, piercing, a particular weapon, perfect aim, audio and colour perception cannot be mandatory answers.
- Check actual reachability through arena solids, boss footprints, normal bodies, active/pending hazards and the player's movement speed. “Less than 25% floor covered” is not sufficient if that area blocks the only exit.
- Reserve the needed route before committing the attack; prevent new arrivals occupying it. If the next attack cannot fit safely, choose another attack or wait before announcing it. Never shift a locked warning onto the player or secretly change its timing to force a hit.
- Share the current entity, projectile, hazard and effect limits. No per-boss duplicate budgets, exponential split projectiles or unlimited summons. Body separation and camera safety remain requirements.
- No dense clone carpets, clustered small growths or repeated hole-like surface motifs. Give each boss one strong silhouette and large readable moving parts. Reduced Motion softens cosmetic motion while retaining essential attack cues.

## Improve the existing three without making five reskins

Before the new roster enters ordinary rotation, run one focused pass on the current three:

- **Shadow:** make spacing/fan recognition its main exam. Add a clearly taught fan variation and a meaningful exposed recovery; reduce dependence on repeating the long dash. Keep all projectile gaps real.
- **Demon:** emphasise heavy directional commitment, readable weight and delayed slam rhythms. Improve its weak walk poses. The charge should close a bad distance, not be its answer to every situation.
- **Queen:** emphasise route control and brood leadership. Limit adds and poison together against the encounter budget; provide a clear tail/abdomen recovery to attack. Keep existing pivot/pose corrections.

Measure wins with straight retreat, circling and close aggression, across the existing weapons. Record actual causes of damage. Preserve existing earned unlocks, known reload timing and deliberate safe 0.1× solo upgrade selection. This pass has its own acceptance gate; roster expansion must not hide broken old encounters.

## The path from eight to fifteen

Organise the eventual fifteen by encounter roles, not fifteen health bars: duelists, rhythm/timing tests, route controllers, target-selection fights and environmental machines. These five fill gaps in the current roster. Reserve the last seven for mechanics that remain missing after playtests; do not commit seven names and then discover they all play like a charge boss.

For these eight, introduce tiered solo pools rather than playing the same three forever. Preserve first-time access to Shadow/Demon/Queen for their existing weapon/arena unlocks. A newcomer should not need lucky random draws to find progression bosses. Use a saved, seeded encounter bag with repetition protection and a short guarantee for unmet progression encounters. Keep encounter cadence separate from roster size: adding five bosses does not silently turn a ten-minute cycle into an eighty-minute run or alter health scaling via `% 3`/`~/ 3` arithmetic.

Training exposes all implemented bosses and their phase practice, with protected health clearly identified. Add first-kill Collection entries and attack hints. Continue giving one normal core per solo boss; do not make five new fusion families a hidden dependency for this batch. Cosmetic trophies are optional rewards, not permanent damage inflation.

## Two bosses together: design for it, do not enable every pair

Eight bosses create 28 distinct unordered pairs; fifteen create 105. Two individually fair kits are not automatically a fair pair. Release only authored, tested pairings. Multiplayer and duo boss release remain later work; the five solo encounters must succeed first.

An encounter coordinator owns the shared attack budget:

1. One boss holds the **major attack** slot. The other can reposition, recover or use an approved low-pressure support action; it cannot independently start another area-closing signature.
2. Each major attack reserves its real floor footprint, time interval, escape route and ordinary-enemy traffic restrictions. Reject incompatible next actions before their warnings begin.
3. Both bosses share projectile/hazard/effect and reinforcement limits. As boss pressure rises, ordinary arrivals drop. Do not add a second full solo health pool and full solo add budget without tuning.
4. Co-op targeting locks during windup, announces the targeted player and has a dwell/cooldown policy. Avoid both bosses permanently chasing the weakest player; do not make a target switch home an already committed attack.
5. Keep both threats or their persistent direction cues readable. No camera zoom that makes mobile telegraphs illegible. If the arena cannot accommodate the pair, do not schedule it there.
6. Killing one changes the survivor at a visible reset: an authored move variant or stance change, not an invisible speed/damage spike or an instant attack across the death reward screen. Reward handling and upgrade breaks must be coordinated.

| Pair experiment | Why it might work | Required restriction |
|---|---|---|
| Bellkeeper + Last Marshal | Timing test plus opportunistic duelist | Marshal cannot recall across the toll's reserved escape route |
| Chain Magistrate + Demon | Route setup plus heavy commitment | No charge/sweep combination that closes the chain passage |
| Kiln Sovereign + Shadow | Environmental pressure plus a mobile pursuer | Fans/dashes respect the pressure-release route; no double signature |
| Mirror Saint + Queen | Too many independent route-denial layers for a first pair | Leave disabled initially |
| Two Kiln Sovereigns / two Chain Magistrates | Competing arena ownership | Leave disabled until a bespoke combined encounter exists |

These are candidate experiments, not approved matchups. First prove a pair in a local encounter harness, then test the actual authoritative co-op implementation. Solo duo encounters, if later offered, need their own tuning and remain optional until fair.

## Implementation foundation

### First: a boss encounter runtime

- Keep per-boss controllers. Extract reusable warning/commit/impact/recovery clocks, locked target snapshots, owner-scoped hazards, body collision, vulnerability windows and interruption rules.
- Introduce a definition registry keyed by stable boss ID. Definitions reference controller factories, art/audio, valid arena footprints, attack tags and progression eligibility. Do not extend the existing Demon/Queen conditional chain for five unrelated kits.
- Replace the single-pointer assumption with an encounter owning identified actors. Solo uses one actor initially. Update HUD, damage/no-hit records, boss cleanup, Training selection, defeat counts, reward cores and spawn/crowd references together.
- Every attack has an encounter ID, actor ID, attack ID, simulation start/lock/impact/end ticks, target snapshot, shape, damage and budget cost. Multiple parts of one boss still represent one boss/reward; damage deduplication applies across its weak points.
- Migrate checkpoints explicitly. Read existing schema-1 solo saves, preserve health/build/progression and director time, and write a versioned encounter payload with actor states and reward receipts. Resume through safe neutral recovery with transient attacks retired, matching current resume safety; do not restore an active damage shape without its warning.
- Two-boss death/Continue tests must prove no duplicate cores, skipped surviving boss, resurrected attack or premature end-of-encounter settlement. Do not equate one actor dying with an entire pair ending.

### Then: five reusable attack capabilities

Build only what these bosses require: a gapped expanding wave, anchored line/arc hazard, bounded recorded-path trace, reflected beam path, and owned weak point/deployed weapon. Use shared shape definitions for both rendering and collision. One wave/beam/chain does not need a component for every visible pixel or link.

Give attack shapes consistent warning, active and retirement states; enforce common budgets and cleanup by ownership. Add a small debug encounter view for committed shapes, reservations and phase clocks. Keep those details out of the player's HUD.

### Art, sound and memory

Storyboard each reveal and three attack cycles before generating final art. Each boss needs silhouette, idle/movement, distinct windups, impacts, recoveries, phase transition and defeat. Use separate moving props where appropriate; do not stretch the same eight poses into five new encounters or assume all new sheets fit the old 40-frame layout.

Use the quarantine-facility palette and materials: copper/brass, bone, graphite, worn steel, restrained glass/heat accents. Lock pivots and body scale across attack poses. Keep telegraphs on top of cosmetic debris but below readable actors/UI. Arrival/death spectacle must not hide the next threat or force a long camera takeover in an ongoing run.

Budget active decoded textures, not just PNG download size. The current shared art is already around its 32 MiB texture target; five permanently preloaded boss atlases would threaten it. Plan encounter-scoped atlas loading and safe release, preload before arrival, and measure the two-boss active set. Do not expand the budget without native evidence. Distinct warning/impact/recovery sounds must also work muted through visuals.

### Multiplayer preparation, not a multiplayer claim

The future authority owns phase selection, RNG, target locks, damage, attack IDs, reservations and rewards. Clients render the same committed event. Do not build mechanics around local wall-clock futures or unsynchronised player traces. A Mirror Saint route is an authority-approved bounded sample, not a client claim.

Co-op adds latency, reconnect, player collision, shared upgrade breaks and target ownership work. Test player obstruction of escape routes; avoid teammates body-blocking each other in mandatory passages. Follow the existing backend/co-op plan and its Flutter/SpacetimeDB compatibility gate. Networking is not supplied by this boss plan.

## Delivery order and gates

| Step | Deliverable | Exit condition |
|---|---|---|
| 0 | Current-boss audit and encounter harness | Reproducible baseline wins/losses; attack/hit/reload metrics; no straight-kiting exploit accepted |
| 1 | Encounter runtime and new attack primitives | Existing three migrate without changing their intended behaviour; old saves and core rewards stay correct |
| 2 | Bellkeeper greybox, then finished slice | Gap/echo timing is clear; all loadouts have a baseline answer; first complete new boss with approved art/audio |
| 3 | Chain Magistrate | Column/corner routes and clasp alternative pass; no chain traps or mandatory DPS checks |
| 4 | Last Marshal | Duel/reload loop works before thrown-weapon complexity; brace never creates instant counter damage |
| 5 | Kiln Sovereign | Connected safe route and weak-point damage ledger survive all weapons and both arenas |
| 6 | Mirror Saint | Route recording/beam geometry stay honest; real-body recognition is clear on a phone |
| 7 | Eight-boss solo rotation and old-three improvement pass | Existing unlocks remain reachable; repeated cycles, Training, Collection and Continue work |
| 8 | Local duo experiments, later actual co-op | Only validated pairs enabled; shared attack scheduling and authority/network tests pass |

Build one finished slice before producing all five art packs. The Bellkeeper validates timing/waves; the Magistrate validates route reservations; the Marshal validates punish windows. The more complex environmental/recorded-path bosses follow that foundation. No calendar promise is attached before the first slice reveals production cost.

## Acceptance and playtest evidence

- For each new boss: four weapons × three survivors × two arenas, phase crossings from burst damage, ordinary and developed builds, weak-point/guard/status interactions, and attacks near every wall/column arrangement. None requires a specific fusion.
- Pause, slow upgrade selection, background, restart, save/Continue, death during warning/impact and simultaneous lethal hits. All owned attacks clean up; rewards settle once. Check partial shotgun reloads and audio interruption.
- Script straight retreat, circle-strafing, corner parking, point-blank damage racing and long-range offscreen firing. Then use human play to find exploits the scripts miss. A motionless bot is not a fairness oracle.
- Record win/loss, attempts, fight duration, health spent, source of every hit, reload downtime, guard blocks and loadout. Separate Training, first attempts and learned rematches. Compare equal builds before changing health or damage.
- Ask the reporting friend to try an unseen boss, describe what killed him, then rematch. Desired result: early mistakes expose the rules; later attempts show recognisable improvement and earned wins. A fast expert victory can be a success, not an automatic reason to increase damage.
- Reject unavoidable overlapping patterns, unclear real/false bodies, hidden active hitboxes, unreadable crowded surfaces and attacks that require guessing what happened offscreen. Test muted sound, reduced motion and physical thumb use.
- Keep the 30/60-minute simulations and body/population bounds. Profile actual iPhone/Android frames and memory with the active art set, then test approved duo candidates separately. Automated simulation is not native performance or comfort proof.

**Definition of done for this batch:** five distinct, beatable and demanding solo encounters; the existing three remain sound; the expanded roster is reachable and persistent; and a player can explain the mistake that cost a hit and the opening that earned a win. Future pairs are supported by the architecture, not falsely advertised as already balanced multiplayer.
