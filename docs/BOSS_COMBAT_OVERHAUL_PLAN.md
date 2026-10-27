# Eight-boss combat overhaul implementation plan

27 October 2026 · Planning only · No gameplay implementation in this document

## 1. Mandate and outcome

Rework the existing eight bosses as one roster-wide quality effort before expanding the roster. **All eight are equally important.** Marshal and Mirror Saint supplied concrete examples of broader defects; they are not the priority tier. Work order follows shared dependencies and review coverage, not character preference.

The creator's concerns cover attack patterns, readability, power, geometric construction, awkward weapon movement, unclear duplicates, and attacks whose physical objects are absent. A new effect skin alone cannot complete this work.

The intended result is eight distinct fights in which the player can recognize the attacker, anticipate its commitment, see the attack happen, understand a hit, and exploit recovery while managing movement, aim, ammunition and reload. Rich effects must support those decisions at landscape phone size.

This plan proposes implementation scope. Attack concepts below are design targets, not claims about existing functionality or approved numerical balance. It does not authorize a production deployment or certify physical acceptance.

### Existing evidence and limits

Reviewed the native boss controllers, attack shapes, geometry renderer, weak points, Marshal aiming, portal lifecycle, relevant online presentation paths, current server boss source, existing combat previews and portal captures. The creator supplied device observations. No new hands-on playtest was performed for this plan.

Confirmed implementation findings:

- Five expansion bosses share a cue/pose lifecycle, but need attack-specific choreography beyond shared floor geometry.
- `BossVfx` repeatedly expresses different powers through fractured disks, ribbons and crescents. Thin fragmented edges can merge with the arena texture.
- Marshal's separate gun rotates around a fixed hand without directional arm poses. His blade move creates lanes and a destination prop without a visible traveling blade.
- Saint's projection is a translucent idle sprite. Its attacks have several origins without equivalent source-specific release animation. The stored route is sampled, but Shatterwake currently uses the latest sample plus current/predicted positions rather than a full recorded-path replay.
- Body release clips exist and are refreshed for delayed expansion strikes; they still need visual evaluation and attack-specific poses. Do not describe the current system as having no release animation at all.
- Existing portal construction offers a useful example of coherent geometry and timing. It does not prove that copying portal seals into damaging attacks will work.
- Automated escape, retreat, lifecycle and geometry tests already protect important behavior. They do not establish recognition, excitement, comfort or fairness on a phone.

## 2. Shared design requirements

### Every attack tells one complete story

Author **preparation → commitment → release/travel → impact or active danger → aftermath → recovery** for every move. Not every move needs a projectile, but every damaging event needs a visible cause.

For every attack, record:

| Contract | Required decision |
| --- | --- |
| Purpose | What player habit it challenges and how it differs from the boss's other moves |
| Source | Body part, weapon, prop or already-established floor mechanism that produces it |
| Preparation | Readable pose and floor information available before damage |
| Lock | Exact point at which target, direction, route and shape stop changing |
| Release | Gesture and object/energy motion tied to the real attack clock |
| Damage | Authoritative geometry, cover behavior, timing and hit ledger |
| Answer | A reachable baseline movement response; dash is an option rather than a universal requirement |
| Opening | Visible recovery or break opportunity, including practical reload opportunities |
| Phase II | An understandable extension of a taught move, rather than more simultaneous clutter |
| Retirement | What remains harmless, how it fades, and how interruption/death cancels it |
| Accessibility | Muted and Reduced Motion readings; shape/value information independent of hue |

### Power and geometry

- Give the main attack a strong silhouette first. Add chipped edges, scuffs and fragments inside or around that readable construction; do not build the whole silhouette from disconnected scratches.
- Give warnings enough dark backing and value separation on both floors. Actor grading must not darken essential warning information into invisibility.
- Differentiate warning, active danger and harmless residue by shape, timing and value. A warning cannot merely look like a dim active attack, and retired marks cannot retain the same threatening emphasis.
- Build power through anticipation, compression, a decisive release, material motion, contact and settling debris. Avoid relying on global brightness, camera shake, white flashes or screen-filling effects.
- Use purpose-built geometry for glass, iron, pressure, poison, shadow and heat. Shared drawing utilities are useful; identical attack art in different colors is insufficient.
- Keep one dominant visual event per beat. Secondary detail must leave the player, next threat, escape gap and projectile lanes readable.
- Ground large attacks with contact shading and localized aftermath. Decorative fragments must not suggest additional damage or enlarge the perceived hit area unpredictably.
- Preserve the explicitly requested continuous Marshal laser. It must remain unbroken and visibly attached to the muzzle throughout its committed discharge.
- Avoid resizing old texture stamps to create large attacks. Use authored geometry and, where needed, dedicated pixel assets at a consistent scale. New assets require inspection and measured decoded-memory cost.

### Patterns and counterplay

Audit actual decision quality, not just whether an attack can technically hit a retreating bot. Every kit needs spacing decisions, readable commitment and punishable behavior. Avoid turning all eight into predictive floor-marker fights.

Preserve ordinary movement escape for the slowest unupgraded survivor, subject to the encounter's taught rules. Check physical travel through bodies and cover. An empty point elsewhere in the arena is not proof of a reachable escape route.

Do not blanket-increase speed, health, damage, attack size or simultaneous hazards to create power. Begin presentation comparisons with the existing numerical contracts. Where the new behavior requires different timing or geometry, document the exact change, implement it in both authorities, and test it as a mechanical change.

## 3. Equal-scope briefs for all eight bosses

Each boss receives the same deliverables: complete move specification, both phases, body/prop animation, warning/active/aftermath art, audio, weak-point or opening feedback, entrance/death continuity, native/online parity, regression coverage and physical review. The numbered order below follows the existing roster enumeration only.

### 3.1 Shadow — spacing and committed pursuit

**Keep:** aimed fans, committed body dash and close strike. These make the attacker physically present and provide a useful contrast to environmental bosses.

**Rework:**

- Fan: show energy gathering at the actual release point, a clear launch gesture, distinct volley beats and readable bolt silhouettes. Keep gaps visible through trails and impact detail. Show the preparation for an additional phase-II volley.
- Dash: connect the planted windup and committed lane to a visible body launch, a short bounded shadow tear and a stop/recovery pose. The moving body remains the damaging corridor; a lingering trail is clearly spent.
- Close strike: replace a weak ring-only impression with a visible body/weapon release and a compact radial pressure tear aligned to the actual strike event. Decorative spread must not imply an expanding damaging wave if damage is instantaneous.
- Recovery: communicate exposure through body posture and settling shadow, rather than an unexplained switch to idle. Retain room to reload without making every attack end a safe pause.

**Phase II:** extend taught volley/dash rhythms with visible preparation; preserve committed headings and honest gaps.

**Entrance/death connection:** carry the broken pentad and tearing-shadow vocabulary into brief attack accents. Departure remains world-space and nonblocking.

**Completion check:** players distinguish fan, dash and strike from the windup alone; fast bolts and the dash remain readable at the wider boss camera view.

### 3.2 Demon — directional weight and heavy commitment

**Keep:** cleave, delayed ground slams and charge. Preserve the role of a heavy body that commits and can be wrong-footed.

**Rework:**

- Cleave: use a planted load-up, visible striking limb/weapon, and a decisive contact front across the committed sector. Verify art against this controller's actual cleave damage timing; do not depict a traveling sweep while the entire sector damages at once.
- Slams: visibly transmit force into the floor, then release the marked impacts in an intentional rhythm. Remote impacts need a connecting cause such as a traveling floor fracture whose schedule agrees with the damage events.
- Charge: strengthen launch, body weight, contact and deceleration. Cover contact must terminate the body motion honestly; it must not produce a cosmetic continuation through a solid.
- Recovery: give the heavy moves a recognizable exertion/reset pose. Evaluate the distance rule that currently strongly favors charge when the player is far away; prevent the fight degenerating into repeated charging.

**Phase II:** combine the same taught beats before reducing available response time. Keep remote slam warnings and each release synchronized.

**Entrance/death connection:** horn/forge construction and grounded masonry support the weight; the body remains the visual source of attacks.

**Completion check:** cleave, slam and charge feel distinct with muted audio, and every impact can be traced to a visible action.

### 3.3 Scorpion Queen — tail precision, brood and lasting poison

**Keep:** tail attacks, bounded brood and route-control poison. Avoid turning the Queen into a recolored Demon.

**Rework:**

- Tail: repair incomplete attack-frame coverage or author replacement poses. Show the tail load, release and impact path. If a distant eruption is retained, establish its delivery visibly instead of implying an impossible physical tail reach.
- Brood: show a distinct abdominal/body action and grounded emergence at actual spawn locations. Brood preparation must not resemble a player-damaging pool unless it really is one.
- Poison: distinguish an incoming deposit from an active persistent seep and a harmless drying stain. Use a readable body and boundary for the pool, with restrained internal activity; scattered cracks alone do not communicate poison.
- Pace brood and poison against shared crowd/route limits, with a clear opportunity to attack the Queen between route-control sequences. Weak-point imagery must not promise a new damage multiplier unless implemented.

**Phase II:** extend the taught placement pattern within the shared encounter budget; do not independently maximize adds and poison.

**Entrance/death connection:** hooked-limb portal motifs, chitin and seep materials remain distinct from furnace and stone effects.

**Completion check:** players can tell a tail strike, spawning brood and lingering poison apart immediately, including when some adds are already present.

### 3.4 Bellkeeper — toll, travel and echo

**Keep:** gapped expanding waves, the delayed echo, close clapper attack and break opportunity.

**Rework:**

- Toll: animate a legible bell/clapper windup and exact strike, then release a substantial moving pressure front. The front needs a coherent body and locally disturbed floor, not only a rough crescent outline.
- Gap: mark its boundaries consistently and leave the true opening clear. Preserve the planted projected-crossing warning and committed wave heading; do not make the warning track the player.
- Echo: show the second toll loading and releasing. Its changed gap must be recognizable before the second wave reaches the player.
- Clapper: connect the near sweep to visible clapper motion, preserving its annular inside pocket. Make the exposed bell apparatus readable as a break target with a material-specific response.
- Recovery: include a recognizable quiet interval after the toll sequence, with purposeful bell settling instead of constant motion.

**Phase II:** teach the altered echo rhythm with the same visual rules and a readable sequence, not a pile of identical crescents.

**Entrance/death connection:** bell/clapper etchings and resonant brass pressure accents connect the fight to its portal grammar.

**Completion check:** the player identifies the moving damaging front, the real gap and the upcoming echo without relying on sound.

### 3.5 Chain Magistrate — launched iron and tension

**Keep:** five forward chains, seven enraged, straight committed rays, variable spacing/order, clasps and real gaps. Do not restore a circular star or endpoint branches.

**Rework:**

- Setup: visibly prepare anchors and clearly announce the complete forward fan. Preserve atomic staging; never silently drop part of a volley under hazard limits.
- Release: show anchors launch and links extend along the committed rays, then convey tension through a strong link silhouette and restrained recoil.
- Active contact: choose and document whether the existing instantaneous lane activation remains or becomes an extending damaging front. Cosmetic chain travel cannot imply that a still-unreached section is safe while its whole lane already damages.
- Order: give staggered volleys perceptible release beats, including the changed direction/order. Randomness must remain readable after commitment.
- Break/recovery: integrate the exposed clasps into the actual chains, with a clear fracture, loss of tension and boss interruption response. Remove the generic token-like prop impression.

**Phase II:** use the additional chains within a readable forward fan and preserve viable body-width passages.

**Entrance/death connection:** linked iron and clasp geometry carry across attacks and portal retirement without becoming new solid walls.

**Completion check:** the player sees which chains are about to release, which are active, and where a reachable gap or break target exists.

### 3.6 Mirror Saint — readable reflection and route interception

**Keep:** the role of a route-reading glass controller and breakable mirrors. Simplify presentation and sequencing enough to make its rules learnable.

**Rework:**

- Establish one mirror before crossfire. Show it forming, orienting, receiving or storing a release, and producing its own attack. A static transparent idle body cannot serve as the entire explanation.
- Give the true boss a stable silhouette and the projection a distinct glass construction. Each attacking origin needs its own preparation and release; decorative images must not masquerade as independent combat actors.
- Shatterwake: choose explicitly between a bounded replay of actual traveled ground and predicted interception. If both remain, give them distinct moves and distinct tells. Do not market a predicted line as a faithful replay. Use a coherent faceted eruption front with visible leading danger and harmless spent glass behind it.
- Crossfire: orient mirror planes and connecting paths so the reflection can be understood. Do not imply physically reflected geometry unless the authoritative committed path actually follows those planes.
- False benediction: establish the body release, mirror reply and final eruption as a taught sequence. Assess whether the final area attack adds a useful decision; remove redundant overlap if it only adds noise.
- Breaking a mirror visibly collapses its attack contribution and produces the existing interruption/opening. The real boss remains trackable throughout.

**Phase II:** add a second clearly introduced mirror or a taught extra beat; avoid simultaneous unexplained copies and floor paths.

**Entrance/death connection:** use the portal's deliberate diamonds and glass planes as a visual vocabulary, with restrained shattering instead of faint random scratches.

**Completion check:** a first-time viewer identifies the real body, attacking mirror, next release and escape direction from the rendered sequence.

### 3.7 Kiln Sovereign — pressure, valves and vented heat

**Keep:** furnace breath, heavy ground impact, pressure-grid control and valves that expose an opening.

**Rework:**

- Breath: visibly build pressure in the furnace/body, open the real release source and discharge a directional heat/slag front. Preserve the annular pocket and authoritative moving sweep rather than filling the entire warned sector with indistinguishable active fire.
- Foundry foot: show the weight transfer, physical contact and arrival of any remote impact. Avoid another unexplained circle appearing at the player's feet.
- Pressure grid: establish temporary vent sources before eruption; connect charge, release and shutdown to the actual scheduled circles. Vents must remain readable on Breach as well as Foundry.
- Valves: replace floating token-like targets with apparatus visibly connected to the boss's pressure system. Breaking one should produce a clear pressure drop, interruption and exposed-body response without adding unimplemented protection rules.
- Recovery: communicate venting/exhaust and a practical attack/reload opening. Heat residue must lose threat emphasis when its damage interval ends.

**Phase II:** change release order or combine taught vent/breath beats within a connected safe route, rather than covering more floor indiscriminately.

**Entrance/death connection:** kiln-vent portal bars, iron plates, slag and pressure response form a consistent material identity.

**Completion check:** the player distinguishes breath, pressure vent, foot impact and harmless cooling residue while still seeing the survivor.

### 3.8 Last Marshal — credible gun duel and a real returning blade

**Keep:** continuous laser gunfire, committed warnings, frontal brace with warned counter, thrown-weapon threat and punishable resets.

**Rework:**

- Gun rig: author inspected directional body/arm poses and measured hand/barrel pivots. Use bounded adjustment within each pose, switch stance before commitment, and prevent the weapon rotating impossibly across the torso. Test close-range and all-angle targets, not only a flattering horizontal shot.
- Derive gun heading, hand, muzzle, warning origin and beam origin from the same committed shot solution in native and online rendering. Do not recompute handedness from a moving target after the shot locks. Delayed shots need their own prepared transition without a mid-discharge snap.
- Measured Fire: visible aim → lock → supported discharge/recoil → reset. Keep the beam continuous and unclipped at its source while respecting real cover clipping and the current damage interval.
- Iron Courtesy: visibly brace, react to an actual frontal hit, then prepare the separately warned counter. Communicate deflection and the flank/opening without implying player rounds secretly change allegiance.
- Return to Sender: render the actual hooked blade leaving the hand, traveling to the planted destination, remaining there and returning along a separately committed route. Ground the prop in the arena rather than presenting it as a generic square marker.
- Flight and damage must agree: either preserve the existing lane damage with an honest full-lane effect, or deliberately implement a swept traveling blade. The target is a genuine visible traveling blade; that requires a coordinated mechanical change if current timing/geometry cannot represent it honestly.
- Show the planted clasp's break response and the body attacks during blade deployment. Replace the unexplained idle recovery with a clear gun mechanism/stance reset; only promise a punishable reload if a real reload interval exists.

**Phase II:** extend a taught blade/body sequence with a visible reset before recall or another gun stance. No hidden second threat during an unreadable weapon transition.

**Entrance/death connection:** cartridge and iron-seal details support the duelist identity; discharge and blade movement retain their own stronger silhouettes.

**Completion check:** all aiming angles have credible anatomy and continuous muzzle alignment, and a viewer can point to the blade throughout release, travel, planting and recall.

## 4. Technical implementation strategy

### Extend the current architecture

Keep `BossEncounterRuntime`, separate boss controllers, `BossAttackShape`, shared cover/occupancy rules, atlas leases and the server authority. Do not replace the game with a new boss framework or route expansion values through legacy Queen behavior.

Separate three concerns explicitly:

1. **Attack decision and authoritative timeline:** controller chooses target, geometry, lock/release/damage/end times, hit ownership and recovery.
2. **Body and apparatus choreography:** animation consumes the attack identity and stage, including delayed releases, directional pivots, planted props and interruption.
3. **Presentation:** boss-specific geometry/materials consume that same timeline and geometry, with bounded decoration and Reduced Motion behavior.

Add only the missing shared contracts. A small attack presentation descriptor should identify boss/actor, move, sequence, cue/beat, committed origin/path, stage times, variant/seed and required prop state. Inspect current serialized fields before adding new ones; reuse existing IDs where stable. Do not infer pose or material from cue position in a list.

For actual projectiles/props, use simulation-clock positions and swept contact. Rendering interpolates the authoritative motion; it never invents damage or updates from wall-clock futures. Avoid expanding generic shape constructors with unrelated per-boss flags; use explicit moving-attack state where needed.

### Synchronization and lifecycle

- One clock/event source drives sound, pose, travel and impact. An animation frame must not independently trigger damage already owned by simulation.
- Distinguish a warning that follows during preparation from a locked warning. Once committed, preserve the promised geometry, target and timing.
- Death/interruption removes all owned active attacks once, retires props, and clears pending releases. Cosmetic aftermath can finish harmlessly under a bounded lifetime.
- Freeze combat and its presentation consistently during pause, background, entrance/recovery and upgrade holds. Resume without catch-up bursts, repeated audio or late impacts.
- Preserve existing checkpoint compatibility and transient-attack retirement on Continue. Save new persistent prop/decision state only where needed; do not resurrect an unannounced active attack from an old snapshot.
- Keep root attack coordinates unscaled; child art size and authoritative body radius retain separate meanings.
- Floor effects remain below actors; flying weapons and beams need deliberate depth rules so a floor-priority assignment does not hide them. Cosmetic debris never masks the survivor or weak-point cue.

### Native, server and online paths

Primary native files: `lib/components/enemies/shadow_boss_component.dart`, `pattern_boss.dart`, `expansion_boss.dart`, `boss_attack.dart`, `boss_weak_point.dart`, `hostile_area.dart`, plus `lib/systems/boss_attack_shape.dart` and `boss_encounter_runtime.dart`.

Primary presentation files: `lib/presentation/boss_vfx.dart`, `boss_art.dart`, `marshal_aim.dart`, `boss_portal.dart`, `online_world.dart`, `online_boss_presentation.dart` and shared effect/audio ownership paths.

Server counterparts live in sibling `regun-server/spacetimedb/src/bosses.ts`, `marshal_aim.ts`, `actors.ts`, `boss_collateral.ts` and `boss_presentation.ts`; shared fixtures/contracts and transport serialization must be traced before changes. Read that repository's instructions before implementation.

- Presentation-only work can consume existing authoritative data without a protocol change when that data is sufficient.
- New flight, route, stance-lock, prop-phase or timing behavior must be implemented in both native and server logic with parity fixtures. Clients never supply trusted boss hits, endpoints or release times.
- Version/capability-gate new required snapshot fields using the existing project mechanism. Provide a truthful legacy rendering path or refuse incompatible combat admission; do not guess new attacks from incomplete old packets.
- Reconnect/late join renders the current state without replaying old windups, sounds, hits or cinematics. Paired bosses retain independent actor ownership and shared major-attack coordination.
- Prepare local/staging evidence before any hosted rollout. Local TypeScript success alone does not prove Flutter online presentation parity.

### Performance and assets

Keep the current 32 MiB boss-pair art target and existing projectile/hazard/effect/population limits. Measure current active decoded memory before allocating new art, including both bosses, their props and departure leases. Preserve pending-load restart/disposal guards.

Use deterministic cached geometry for stable shapes, viewport culling, bounded fragments and reusable paints/paths where practical. Do not create components per chain link, glass chip or wave segment. Essential warnings and active fronts have priority; cosmetic fragments degrade first under pressure. Effect saturation must never silently erase damage cues or truncate an attack.

Author missing directional/weapon frames and inspect actual atlas cells; do not stretch incomplete art to fit a universal frame count. Track source provenance and pivots. Audio uses existing SoLoud groups, controls, pause/lifecycle and bounded overlap; add distinct charge/release/contact/retirement cues only where they improve recognition. Avoid volume inflation as a substitute for impact.

## 5. Dependency-based delivery stages

No stage declares the overhaul complete with only selected bosses upgraded. Maintain an eight-row tracker with columns for specification, phase I, phase II, choreography, VFX, audio, openings/props, entrance/death continuity, native tests, online parity and physical review. Each cell links evidence or states the blocker.

| Stage | Work across the roster | Exit requirement |
| --- | --- | --- |
| A — Baseline and specifications | Capture every existing move in both phases; record timing, damage, geometry, pattern selection, opening, bugs and source/pose gaps. Produce eight complete briefs and an explicit mechanical-delta register. | All eight inventoried; current defects distinguished from redesign proposals; baseline clips and attack ledger complete. |
| B — Shared foundations | Implement timeline/presentation contracts, source pivots, stage styling, ownership cleanup, capture harness and parity fixtures. Prove one representative signature from **each** boss against the common foundation. | Eight signatures pass visual/geometry review; architecture supports every material and body/prop type without boss-specific hacks in generic shapes. |
| C — Complete move sets | Finish all remaining moves, both phases, real apparatus/flight, interruption and recoveries. Adjust patterns only through documented mechanical deltas. | Every move has complete cause-to-aftermath choreography; no missing blade, unexplained origin or unfinished pose remains in any boss. |
| D — Encounter composition | Tune selection, repetition, reload windows, enrage transitions, horde pressure and pair handoff; finish audio and entrance/death continuity for all eight. | Each full fight has an identifiable rhythm, useful counterplay and sustained visibility. No boss remains a visual-only conversion. |
| E — Verification and physical iteration | Run cross-authority/lifecycle/performance checks, creator device review and corrective passes across the full roster. | All eight meet the same acceptance checklist; unresolved items are explicit. Installation/build success cannot close subjective gates. |

A failed shared rule returns to the foundation before more attacks depend on it. A failed individual move remains open even if other bosses pass. Do not batch-generate every asset before the eight representative signatures establish the direction.

For each stage, provide normal-speed clips at actual phone framing with context before/after the attack. Include clean single-boss scenes and representative crowded scenes. Stills document silhouette/geometry; they cannot approve motion or attack feel.

## 6. Verification and acceptance

### Automated checks that protect meaningful behavior

- **Geometry:** rendered damaging fronts/path/width agree with authoritative collision at warning, first damage, mid-attack, last damage and retirement. Cover, arena edges, safe pockets and gaps remain honest. Test actual contact trajectories, not just counts of visible pixels.
- **Choreography:** every cue has the intended windup/release source and stage; delayed strikes cannot originate from an idle projection or stale pose. Test Marshal's full angle range, target crossing, delayed beam transitions and uninterrupted muzzle/core alignment. Test blade outbound/plant/recall and Saint origin ownership explicitly.
- **Clock and ownership:** pause/background/upgrade/entrance, phase crossing, interruption, owner death, paired death, restart, route exit, loading races, Continue and repeated lethal events do not replay damage/audio/rewards or leak art.
- **Encounters:** straight retreat, circling, late direction change, close aggression, corner escape and reload behavior. Use the slowest baseline survivor and real cover/body occupancy; no route is accepted merely because a mathematical safe point exists.
- **Collateral:** only the actual active attack clears ordinary minions, respecting cover and safe pockets. Warnings/walking do not kill; bosses remain unharmed and player rewards/procs do not inflate.
- **Parity:** identical seeded native/server traces compare lock points, phase/beat times, paths, damage windows, prop breaks and attack ownership. Online late join, latency, packet gaps and reconnect cannot create new gameplay decisions client-side.
- **Performance:** bounded hazard/effect counts, texture lease retirement and build checks; dedicated dense/pair cases. Compare baseline and candidate on the same physical device/build conditions for frame pacing, memory, hitches and heat.

Extend existing boss expansion/revision/geometry/portal/online tests rather than duplicating their coverage. Add focused regression cases for the actual failures and new mechanics. Run `make verify`; use `make soak` only for the intended long simulation gate. In the sibling server, follow its verification and local integration commands. Run a final full relevant suite after shared integration stabilizes.

### Review matrix

Automate the full eight-boss × both-phase × both-arena baseline matrix. Build weapon/survivor cases from the **current** catalogs, not the original four-weapon overview. Exercise native supported loadouts and currently admitted online loadouts separately; do not expand online admission accidentally.

For physical review, cover all eight bosses in both phases and both arenas, then distribute loadouts by risk: shortest reach, slowest reload, charge/hold behavior, sustained fire, piercing/ricochet, secondary ordnance and support-heavy builds. Include the slowest survivor, Reduced Motion, muted sound, normal sound, small-screen/wider boss view, mirrored controls, crowds and representative boss pairs. Existing automated pair support does not establish human fairness for every combination.

For every reviewed attack, record device/build, boss/phase/move, arena/loadout, crowd/pair state, what the viewer expected, actual hit/escape and corrective action. Compare normal-speed footage, not only enlarged or slowed clips.

### Same acceptance questions for every boss

1. Can the player identify who or what is attacking before damage starts?
2. Is the commitment visible, and does the attack honor it?
3. Does a visible weapon, body action or established mechanism cause the damage?
4. Does the release feel powerful through motion, contact and timing at phone scale?
5. Are danger, safe space and harmless residue distinguishable without sound or color alone?
6. Can a baseline survivor reach the intended answer through actual cover and bodies?
7. Is there a readable opening that supports Regun's aim/ammunition/reload loop?
8. Does phase II develop taught rules while retaining clarity?
9. Do entrance/death, interruptions, saves and online transitions preserve those rules?
10. Does the full encounter remain comfortable and perform within measured device budgets?

Human recognition and power judgments remain open until the creator reviews real motion. Record disagreement and the failing move; do not substitute a passing unit test or an arbitrary numeric design score.

## 7. Scope control and completion

Deliverables are the eight-boss attack ledger/storyboards, shared presentation contracts, complete native/server implementations where required, new inspected art/audio as needed, parity/lifecycle regressions, normal-speed review clips, measured device evidence and an eight-row acceptance record.

Preserve player weapons, creator-published balance, progression/rewards, controls, arena openness, ordinary enemy presentation, existing entrance holds/death camera behavior and profile/checkpoint compatibility unless a specific dependency is documented. Do not overwrite unrelated working-tree edits, publish admin balance, add bosses, bump the release version, or deploy a server as an incidental part of this work.

**The overhaul is complete only when all eight fights meet the same standard.** No boss remains on the old generic treatment as deferred cleanup. Every move must be visually accountable to its source and timing, mechanically honest, distinct enough to learn, and approved in motion on device. If any of those are missing, report the precise remaining work rather than calling the roster finished.
