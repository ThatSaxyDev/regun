# Make upgrade mechanics visible during combat

26 October 2026 — burn/guard plus status/contact/readiness/healing candidates implemented; visual acceptance open.

Current evidence and limitations: [burn/guard review](art/COMBAT_STATUS_REVIEW.md) and
[mechanics/remapping review](validation/upgrade-mechanics-2026-10-26/README.md).

## 1. The result we are building

A player should immediately recognize **a burning enemy, a ready shield, a shield
absorbing a hit, an enemy being marked or frozen, and a real upgrade proc** during
ordinary combat. These should be attractive, deliberate effects with a consistent
material language, not tiny badges, ambiguous tints or a permanent pile of auras.

This is the combat-output layer. Keep the accepted normal-game upgrade sequence:
freeze → absorb → impact and existing recovery pushback together → active play.
Do not replace that work or build another comparison launcher. Shared effect
families are encouraged; forty-three separate effects are not a requirement.

## 2. Verified starting points

| Finding | Source / implication |
|---|---|
| Native burning/cinder currently draws a 12×18 orange rectangle at enemy center. | `CombatEnemy.render`, `lib/components/enemies/combat_enemy.dart`. This does not communicate flames attached to a moving body. |
| Burn has actual remaining time, damage and spread eligibility. Cinder has a separate remaining time/tick. | `CombatEnemy.ignite/update`; `CombatSystem.hit/killed`. Use these states, not owned-upgrade rank or bullet colour. Moth and Cinder Hose also need the same truthful status renderer. |
| Native guard readiness currently draws a 12×12 shield glyph beside the feet. | `PlayerComponent._renderSurvivor`, `lib/components/game_utils/player_component.dart`. Replace the badge as the primary world presentation with a proper body-scale ward. |
| Guard absorbs one accepted hit and turns off; recharge uses an existing active-time clock. Warden also owns this mechanic. | `GameNotifier.reduceHealth/advanceTime`; `RegunGame.damagePlayer`. A large shield must not imply continuous immunity. Dash and deployment protection are different states. |
| Freeze uses two chips; target mark uses simple corner strokes. | `CombatEnemy.render`; `FreezeState`. These need a shared readability pass alongside fire, not incompatible overlapping overlays. |
| Hosted enemies already serialize burn/marked state; guard/guardClock live in authoritative fighter progress. | server `actors.ts`, `survival_runtime.ts`, `progression.ts`. Native and hosted representations differ. `OnlineWorldArt.enemy` and the online fighter painter currently have no equivalent named burn/guard rendering path; do not assume native VFX automatically appears online. |
| Flame art is currently acquired for the equipped Cinder Hose. | `RegunGame` cinder art lease; `ArsenalSystem` cinder rendering. Reusing that atlas for a Hot Shot enemy requires independent status ownership, not reliance on that weapon being equipped. |
| Shared material blasts, chains, drones, Aura Salad and real weapon feedback already exist. | `AttackVfx`, `CombatSystem`, `SupportArt`, `ArsenalSystem`, bullets/mines/grenades. Inspect and refine them before adding duplicates. Preserve accepted quiet links and muted aura currents. |
| API/admin already resolve numeric rank previews and flag unsupported hosted combinations. | identity `admin.ts` `/admin/ranks/preview`; admin `widgets/rank_path.dart`. Visual work must not turn those previews into new combat admission or publish numeric changes. |

Current source scope: **43 offered families, eight fusions, two supports**, plus
legacy Long Dash and fallback Scrap Cache. The attached [coverage inventory](art/UPGRADE_COMBAT_VFX_COVERAGE.json)
contains all 55 identities and an explicit planned disposition. It is a planning
inventory, not a claim that every effect has already been visually audited.

The workspace contains staged and unstaged earlier work. Preserve that index and
all existing changes. Implementation progress is recorded in the linked reviews.

## 3. First slice: unmistakable burning and a proper shield

### Burning enemies — living flame attached to the body

- **Ignition:** a short ember catch at the actual affected body, followed directly
  by sustained fire. No ignition on a miss, mere aiming or upgrade selection.
- **Sustained burn:** textured pixel flames with a dark ember base, warm orange
  body and restrained pale tips. Several tongues climb the lower body and outer
  silhouette; drifting embers are secondary. The enemy must look alight while
  moving, attacking and taking hits. A tint alone is insufficient.
- **Registration:** use visible sprite bounds/ground anchors, including boss child
  art, not a guessed root center. Scale to ordinary enemies, elites and bosses
  with bounded coverage. Keep the face, attack pose and weak points legible.
- **End:** stop sustained flames on actual expiry or death; a brief non-damaging
  ash fade may close the effect. Corpses must not look like ongoing burn damage.
- **Spread:** show a brief transfer only between real ignition recipients. Reuse
  the same living flame after transfer. Never draw an ignited target that the
  mechanic did not affect, including blocked/out-of-range recipients.
- **Related sources:** ordinary burn and cinder share one composed flame layer
  when both exist. Firebreak/Kiln Pact ground fire stays a separate grounded
  footprint tied to its real lifetime/radius. Do not double-stack the same flame.

Start by testing whether existing ember/cinder assets support this body-attached
look. If unsuitable, author one small shared flame packet, preserving sources,
prompts, frame metadata and the established import workflow. Do not stretch an
explosion sprite repeatedly and call it sustained burning.

### Guard — a designed one-hit ward around the survivor

- **Ready:** a stable, translucent, faceted protective envelope that follows the
  whole survivor silhouette. Rear facets sit behind the body; restrained front
  facets/edges sit in front. Weathered iron/brass framing and pale sage energy
  should belong to Regun. It must be clearly visible at phone scale without
  obscuring the gun, controls or nearby threats.
- **Shape:** a few substantial textured panels and readable joins, not a tiny
  replacement icon, clean neon circle or opaque force-field dome. Its visual
  extent encloses the art; it never enlarges the player's collision body.
- **Accepted absorption:** the real blocked hit produces one local facet impact,
  crack and collapse. Use an authoritative impact direction if available; otherwise
  use a symmetric crack rather than inventing where the hit landed. Guard turns
  off immediately when consumed. Do not emit a health-loss flash/haptic for it.
- **Recharging:** no intact shield while guard is unavailable. A quiet incomplete
  frame or HUD progress may show the *actual* recharge; it must not look protected.
- **Return:** one short reassembly when the real recharge finishes. Restoring a
  save/reconnecting with guard already ready shows its steady state, not a replayed
  break/recharge celebration.
- **Shared ownership:** Scrap Armour and Warden use the same real guard state.
  Dash invulnerability, spawn/recovery protection and the upgrade pushback must
  not create this ready ward. A second valid hit after absorption can hurt normally.

Ship these two effects together in the **normal game on the creator's phone**
first. Review one enemy, a moving pack, a boss and actual guard consumption/
recharge on both floors. Correct the art direction here before exporting a larger
status pack. Keep all other existing upgrade reactions working in that build.

## 4. Full coverage: choose the right evidence for each mechanic

Use seven shared visual groups: fire; guard/protection; freeze; marking/electricity;
ordnance/physical contacts; healing/pickups; weapon/readiness feedback. Some perks
need better availability or actual motion, not another world-space effect.

Do not scale flame coverage, shield size or projectile count with rank when the
actual benefit is only damage, cooldown or spread tightening. Use the pinned
resolved values and actual eligible event; caps and incompatible weapons matter.
| Upgrade | Intended evidence during combat |
|---|---|
| Heavy Load (`heavyLoad`) | Accepted primary-contact weight accent; preserve weapon silhouette and mass response. |
| Quick Trigger (`quickTrigger`) | Actual faster mechanism/muzzle cadence, bounded to avoid a continuous flash. |
| Extended Tube (`maxBulletsIncrease`) | Keep actual magazine refill/capacity snap; no extra refill or duplicate reload. |
| Sleight of Hand (`fastReload`) | Read the real weapon reload phases and completion; retain shotgun presentation. |
| Scattershot (`numberOfBulletsPerShotIncrease`) | True fan/count; later ranks that tighten spread must not draw extra rounds. |
| Piercing Rounds (`bulletsPhaseThrough`) | Accepted entry/exit continuation with one restrained exit accent per real penetration. |
| Long Barrel (`bulletRangeIncrease`) | Actual flight persistence; no permanent aim line or fictitious hit. |
| High Velocity (`rapidFire`) | Actual projectile speed with a bounded readable trail, unchanged collision. |
| Fleet Foot (`walkingSpeedIncrease`) | Movement/gait evidence at real speed; no fake dash or permanent aura. |
| Vitality (`healthIncrease`) | Actual new heart; medical recovery only when health actually increases. |
| Field Medic (`fieldMedic`) | Brief body-to-heart medical effect on accepted healing, never on every kill. |
| Scrap Armour (`scrapArmour`) | Full-body one-hit ward: ready shell, accepted absorption/break, absent recharge, reformation. |
| Quickstep (`quickstep`) | Actual dash cooldown/ready cue, no protection bubble when merely ready. |
| Double Dash (`dashCapacity`) | Real stored dash charges and their accepted spend/return. |
| Grenade Reserve (`grenadeCapacity`) | Real inventory markers/ready state; no cosmetic extra grenade. |
| Afterimage (`sprintInvincibility`) | Distinct dash-only protected motion treatment for the real active window, not guard. |
| Scavenger (`scavenger`) | Real XP attraction/travel and collection response, no permanent radius carpet. |
| Lucky Find (`luckyFind`) | Accurate offer/rarity feedback; no invented combat proc or guaranteed rare reward. |
| Hot Shot (`hotShot`) | Body-attached living flame throughout actual burn; ignition, sustained state, extinguish. |
| Accelerant (`accelerant`) | Directional ignition transfer only to actual spread recipients; shared sustained flame. |
| Static Charge (`staticCharge`) | Real accepted chain contacts and short target-attached discharge, bounded overlap. |
| Conductive Core (`conductiveCore`) | Actual jump count/reach; no decorative extra connections. |
| Dash Mine (`sprintMine`) | Real mine placement, armed state and one real detonation. |
| Fragmentation (`fragmentation`) | Real secondary shard origins/count; retain gameplay caps and material blast. |
| Ricochet (`ricochet`) | Real redirection/contact; distinguish purchased bounce from innate weapon behavior. |
| Bank Shot (`bankShot`) | Stronger accent on an actual bounced hit only, respecting damage caps. |
| Last Shell (`lastShell`) | Visible weapon-local final-round readiness; consume on the real empowered release. |
| Breach Loader (`breachLoader`) | Prime after actual reload, consume on the real eligible first release. |
| Orbit Drone (`orbitDrone`) | Readable real companion bodies and their actual fire; preserve quiet accepted links. |
| Targeting Link (`targetingLink`) | A legible mark attached to the actually marked enemy, plus real companion focus response. |
| Shrapnel (`shrapnel`) | Real kill-triggered shard cone only when the proc succeeds. |
| Executioner (`executioner`) | Accepted wounded-target bonus contact only below the real threshold. |
| Heavy Payload (`grenadeDamage`) | Grounded central blast weight for actual damage; no larger radius implied. |
| Wide Burst (`grenadeRadius`) | Shared authoritative preview/blast extent, preserving body-edge and cover rules. |
| Ordnance Cycle (`grenadeRecharge`) | Actual recharge/ready cue; no instantaneous grant on selection. |
| Brace Loader (`braceLoader`) | Real walking-while-reloading difference; not a faster reload effect. |
| Sure Foot (`sureFoot`) | Real restored weighted-weapon mobility; no fictional slow resistance. |
| Scouring Heat (`scouringHeat`) | Eligible elite/boss burn contact/heat accent; do not intensify every burning enemy. |
| Faraday Reserve (`faradayReserve`) | Actual later-jump retained damage contact; do not imply extra targets. |
| Blast Harness (`blastHarness`) | Actual ordinary-enemy shove/debris direction; planted targets stay planted. |
| Exposed Seam (`exposedSeam`) | Readable true frozen state plus accepted bonus hit; perk itself does not freeze. |
| Measured Shot (`measuredShot`) | Charge-ready weapon cue after real idle threshold; consume on eligible release. |
| Close Quarters (`closeQuarters`) | Accepted near-target bonus contact only, without a permanent range ring. |

Also cover all eight fusions: Firebreak/Kiln Pact use actual burning-ground outcomes;
Storm Circuit/Ground Wire use actual chain paths and qualifying discharges;
Minefield uses real armed mine placement; Pinball uses real bounce contacts;
Breach Engine uses actual first/final-round readiness; Hunter Swarm displays its
three actual companions. No extra mines, arcs or rounds for illustration.

Sentry keeps its existing physical deployment/mount/fire/battery identity. Aura
Salad keeps its accepted muted currents, real moving footprint and lifetime. Improve
readability where observation proves necessary; neither implies protection.
Scrap Cache shows only actual scrap/health changes. Legacy Long Dash remains
readable in restored builds without re-entering normal offers.

### Specific rules for the remaining groups

- **Freeze:** body-clinging frost/fracture edges with clear thaw, anchored to the
  real frozen/recovery state. Exposed Seam does not itself freeze a target.
- **Mark/electricity:** a deliberate, readable target seal on actually marked
  enemies. Electrical channels follow real source/contact/chain geometry; innate
  weapon arcs, perk arcs and quiet companion links remain distinguishable.
- **Readiness:** Last Shell, Breach Loader and Measured Shot need a readable
  weapon-local ready/consume rhythm. Briefly emphasize the actual empowered
  release/contact, not trigger intent. Avoid perpetual flashing loaded weapons.
- **Healing:** a short medical body/heart response only for positive accepted HP
  recovery. No green burst per kill when Field Medic did not proc or health is full.
- **Stacking:** fire at the lower/outer body, frost at restrained silhouette edges,
  mark outside the silhouette. Preserve all simultaneously valid states. Do not
  invent steam cancellation or remove burn because the target is also frozen.
- **Priorities:** enemy commitment/impact, weak points and player damage remain
  readable above friendly ornament. Tone down secondary motes first, not essential
  status silhouettes. Existing boss grading, body/root coordinate rules and
  below-actor ground effects remain intact.

## 5. State, rendering and authority

1. Add a small shared, read-only status presentation adapter/painter for native
   and online actors. Inputs: visible body bounds/anchor, facing, grounded position,
   arena grade, active cosmetic phase and authoritative status values. Separate
   rear/body/front layers. Do not create one particle Component per spark.
2. Keep persistent state distinct from transitions. Burn remaining/cinder/freeze/
   mark/guard readiness can drive steady presentation. Guard absorb/recharge must
   originate from the accepted damage/recharge paths, not a loose boolean diff
   that also fires on reset, death, Continue or reconnect.
3. Expose native guard recharge from the existing notifier clock with a read-only
   getter/descriptor. Do not duplicate the cooldown formula in the painter. Derive
   online readiness/progress from the pinned authoritative guard clock/components.
4. Where the server lacks a transient cue, add bounded optional accepted-event
   metadata/serial at its damage/recharge commit point. No client-submitted hit,
   burn, shield or heal outcomes. Ignore unknown/missing cosmetic data safely;
   render valid steady states without blocking play. Deduplicate by actor/epoch/
   serial and establish a reconnect watermark without historical bursts.
5. Cosmetic motion follows active simulation time. Pause, picker, upgrade hold,
   background and entrance retain their established freeze rules. Saves preserve
   gameplay statuses; cosmetic phases can settle safely. Clear actor effects on
   death/removal/restart and release pending art leases on disposal.
6. Use deterministic per-actor phase offsets for packs. Cosmetic variation must
   not consume the gameplay RNG stream or change proc/target/spawn outcomes.

**Mechanics questions are separate issues:** native `CombatSystem.hit` currently
sets burn/mark before checking the final `takeDamage` acceptance, and weak-point
hits take an earlier path. Audit intended eligibility against server behavior.
Do not silently change status application, resistances or boss eligibility to make
an effect easier to demonstrate. Record a proposed correction and its evidence
separately if the investigation reveals a real gameplay discrepancy.

## 6. Art, motion and performance constraints

- Match the dark, tactile pixel world: authored flame silhouettes, weathered ward
  facets, restrained electrical material and grounded impacts. No generic smooth
  rings as a substitute for every mechanic; no full-screen bloom, camera shake or
  fast global strobing. Keep weapon/survivor identity and enemy telegraphs visible.
- Essential burn/guard states remain readable with Reduced Motion: shaped steady
  flames/smoulder and a steady ward, gentle state changes; omit traveling motes,
  orbiting energy, rapid flicker and flying shatter. Do not reduce fire back to a box.
- Reuse approved assets/painters where they fit the direction. New bitmap work
  uses the imagegen workflow; keep immutable masters, prompts, hashes and frame
  manifests under `art/source` and runtime packets under `assets/art`.
- Status art has its own shared owner-scoped lazy leases. Fire must load for a
  burning enemy even when Cinder Hose is not equipped. Prewarm opportunistically;
  do not block accepted hits or upgrade confirmation on asset loading. Define a
  readable conservative failure fallback and test pending-load route changes.
- Keep the existing **32MiB decoded-art limit**. The previous Rook + largest boss
  pair + all six infusion recipes + support/supply/equipped-weapon fixture measured
  31,898,496 bytes, leaving about1.58MiB. This is one fixture, not an all-survivor
  guarantee. Start with at most1MiB of new status art; measure every survivor and
  worst supported kit, reuse/reduce packets if necessary, never raise the cap.
- Do not spend the combat-effect cap on persistent status information. Draw a
  bounded core effect for every visible affected actor; budget optional particles
  globally and cull offscreen work. Crowds must not silently lose their burn state.
- Measure native frame time and load/allocation spikes against the same baseline.
  Automated texture counts, web captures and successful installation are not
  phone-performance proof. New SFX are not required for this visual pass; preserve
  existing music, mute/volume, accepted hit audio and haptic semantics.

## 7. Work order and proof

**A. Runtime baseline and coverage.** Use the 55-entry inventory to record actual
trigger, eligible targets, current renderer, missing online fields, overlaps and
applicability. Capture existing burn/guard at phone scale. Classify each entry as
changed, already adequate, intentionally no extra world effect, unsupported online,
or a documented mechanics question. Do not label the whole audit complete merely
because the identity list is complete.

**B. Burn + guard in the normal phone game.** Build the shared renderer/lifecycle
foundation and the two first-slice effects end to end, including Warden, Moth/
cinder sources where supported, actual absorption/recharge and online state adapters.
Capture motion on both floors and install the normal entry point. No comparison
launcher, internal timing labels or extra choices presented to players.

**C. Remaining status and mechanic groups.** Improve freeze/mark/electricity,
healing, readiness, ordnance and conditional contacts in that order. Work through
all families/fusions/supports using shared materials. Keep accepted quiet effects
and existing weapon presentation unless the observed gap warrants refinement.

**D. Stacked builds and delivery.** Test normal/elite/boss bodies, all survivor
identities, applicable weapon archetypes, rank milestones/caps and crowded combined
states. Verify authoritative co-op and safe old-server fallback without expanding
admission. Install the final normal game and export its matching tester package;
mark hosted deployment and TestFlight distribution truthfully and separately.

Correctness checks must include:

- Identical damage, burn ticks/duration, guard recharge, protection, RNG, projectile
  counts and rewards before/after the presentation change under pinned fixtures.
- Burning follows the body, ends with real state/death and never survives disposal;
  no double fire for concurrent burn/cinder and no unsupported online status.
- One guard absorption → one break → no ready shell until actual recharge. Rejected
  damage/contact cooldown, dash protection, restore and reconnect never fake a break.
- Real conditional procs only; no healing at full health or fake chains/bounces.
- Pause/background/save/Continue/restart and pending/failed loads; bounded texture,
  effect and particle work with correct render order.
- API/admin component-preview parity and retained drafts/catalogue identities where
  relevant. No new numeric knobs, palette-per-perk controls or auto-publication.

Visual acceptance is assessed in actual combat, at phone scale and on the phone:
with sound off and no Details panel, the creator should identify burning enemies,
ready/consumed/recharging guard and the changed mechanic. Inspect motion, not only
sprite sheets. Include packs and a boss, both floors, overlapping burn/freeze/mark,
player damage/warnings, left/right controls, large text and Reduced Motion. Record
missed opportunities instead of forcing procs. Revise unclear or ugly effects
before calling the corresponding group accepted. Tests/installations do not award
visual acceptance.

Deliverables: completed coverage dispositions, shared status art/renderers,
source/asset manifests, before/after normal-speed clips, a normal phone build and
matching distribution artifact, authority/save notes, measured budgets and an honest
remaining-work list. **Implementation status is recorded in the linked review; this plan does not grant visual acceptance.**
