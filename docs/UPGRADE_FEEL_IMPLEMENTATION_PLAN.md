# Make upgrades feel like becoming stronger

25 October 2026. **Implementation handoff; proposed, not implemented.**

Creator brief: “Help me see and feel that my character just became stronger.”
This is repeated player feedback after previous presentation work. Success means
players recognize what changed during real play, not merely that a new animation
exists. The supplied feedback also proposes a short character animation after
selection while the world is held. This plan adopts that as a brief confirmation
beat, with gameplay safeguards and a separate visual-acceptance gate.

## 1. Findings grounded in the current code

| Existing work | Source | Remaining gap |
|---|---|---|
| Brief descriptions, before/after details and larger picker glyphs | `lib/views/base_view.dart`, `lib/widgets/upgrade_offer_copy.dart`, `lib/systems/upgrade_details.dart`, `lib/theme/upgrade_glyph.dart` | Helps people choose; does not establish the upgrade's identity once the picker closes. Several unrelated upgrades share a glyph. |
| Generic accepted-choice notification | `GameNotifier.applyPowerUp`, `chooseSupport`, `fuse` in `lib/notifiers/game_notifier.dart` | All emit `upgradeConfirmed.value++`; no chosen family, previous/new rank or resolved delta is carried to presentation. |
| Recovery pulse after confirmed choice | `lib/game.dart`, `CombatSystem.upgradePulse`, `docs/UPGRADE_RECOVERY_AND_REST_AIM.md` | Same response for every upgrade. It creates space but cannot explain what became stronger. It may dominate the actual effect's first impression. |
| Survivor animation and weapon composition | `lib/components/game_utils/player_component.dart`, `lib/presentation/regun_art.dart` | Action slots are dash, brace, hurt and death. No dedicated upgrade clip exists. `survivorAction` wraps a single action frame, not a multi-frame celebration. |
| Weapon recoil, hit reactions, material VFX, refill snap and damage feedback | weapon presentation/components, `WeaponReaction`, `quickRefillProgress`, `DamageFeedback` | Substantial general combat feedback exists; that does not make an individual upgrade identifiable. Do not discard these systems. |
| Actual proc/status effects | `lib/systems/combat_system.dart`, `CombatEnemy`, bullets, grenades, support runtime | Burn, chains, ricochets, drones, guard and other effects already exist. Audit visibility and attribution before adding duplicate effects. |
| Authoritative co-op choices and recovery | server `progression.ts`, `survival_actions.ts`, `survival_runtime.ts`; client `online_session.dart`, `online_world.dart`, `online_upgrade_picker.dart` | Server validates choices and stores a pending recovery flag. The native notifier counter is not an online event contract; presentation must follow accepted server results. |
| Remote strength/rank tuning | `WeaponPowerBalance`, `RankEffects`, shared catalogue, admin previews | Copy and presentation must use the pinned effective result, including caps and weapon/survivor context, rather than assuming a fixed percentage. |

Previous attempts include 21 October recovery/refill/impact work, 22 October
readable offers and expanded survivor/proc content, and 24 October picker/glyph
and weapon feedback changes. See `REGUN_PROGRESS.md`, `WEAPON_FEEDBACK_REVIEW.md`,
`TEN_SURVIVORS_IMPLEMENTATION_REVIEW.md` and `UPGRADE_RECOVERY_AND_REST_AIM.md`.
The code supports a **diagnosis**, not proof of the player's exact cause:
confirmation is generic, specific benefits are often delayed/conditional, some
late ranks are small, and general weapon noise can mask the difference. Confirm
these hypotheses through controlled before/after clips and player trials.

Current scope is 43 offered families, eight fusions, two support families, ten
survivors and 24 weapons in solo/Training. Online admits its own supported subset;
do not expose unadmitted content to make this feature look universal. Double Dash
and Grenade Reserve have capacity-based short rank limits; most families reach
VIII. Long Dash is legacy, Scrap Cache is fallback. Do not promise VIII everywhere.

## 2. Design decision: three linked moments

### A. Understand the choice

Keep the existing compact picker and 0.1× selection presentation. Improve the
selected family's identity only where necessary: distinct silhouette/material,
plain effect copy and one meaningful before→after delta. Use current resolved
stats and existing Details disclosure. Avoid adding another statistics wall.

### B. See the survivor accept the power

On **accepted** selection, give the survivor a compact, authored activation
animation and a material cue tied to that family. The chosen card/glyph can settle
toward the survivor; it must not travel across thumbs or cover enemies. This
should feel like fitting equipment, bracing a weapon, charging a device or
settling into a stronger stance—not confetti or an unrelated full-screen flash.

Proposed timeline to validate on a phone:

- 0–70ms: selected card acknowledges the accepted choice; alternatives dismiss.
- 70–350ms: planted survivor activation clip with family material/attachment cue.
  A small label beside the player or in a stable HUD slot reads, for example,
  `HEAVY LOAD II` and the truthful stat delta. Hide raw implementation units.
- By 420ms total: return to playable movement/aim. Let the label fade for up to
  another 700ms without blocking input. Later rank pickups use a shorter 220–300ms
  variant. Fusion first-acquisition may use up to 500ms only if the player trial
  justifies it. No extra confirm button, camera zoom, shake or forced flourish.

These are targets, not final tuned values. Start with one prototype and compare
300/420ms; repeated upgrades must not become a pacing penalty.

**Clock contract:** use a distinct bounded confirmation hold after acceptance,
not the normal pause menu and not a delayed call to apply the upgrade. Apply the
choice once, keep combat/world/XP/reload/flight/support/grenade clocks held, and
advance only the confirmation presentation. Preserve 0.1× while choosing. The
existing recovery pulse fires once on actual active resume, after the beat; do
not run it during the hold, duplicate it or enhance its damage/protection.

Background, pause and focus loss freeze the presentation too. Route disposal,
death and restart cancel it. Suppress aim/movement left over from the picker;
fingers already down must not create an accidental shot, dash or grenade release.
This intentional short hold must be tested against the existing entrance and
input-reset systems, not implemented as a wall-clock Timer/Future delay.

Reduced Motion: stationary activation pose, family badge and delta; no flying
card, pulsing perimeter or sweep. Keep the beat short (~180ms target), followed
by the nonblocking readout. Respect SFX volume/mute and Haptics; one restrained
confirmation haptic, never one per particle/proc. Confirmation SFX should have a
shared short mechanical base plus a restrained family layer; avoid 43 competing
jingles. Quiet drone links and muted Aura Salad currents stay quiet.

### C. Recognize the power doing its job

Selection-only theatre cannot solve the complaint. Each family needs a distinct
truthful cue on its relevant mechanic. The first actual use after selection can
be slightly clearer; it must not gain fake damage, guaranteed procs, extra ammo
or a special target. Keep first-use emphasis pending until a real eligible event;
expire it after 20 active seconds or death/field reset so it cannot linger forever.
Passive availability perks use immediate HUD/state evidence, not a fabricated proc.

Rank I introduces the mechanic; later ranks show the actual improvement. IV/VIII
may refine an existing motif, not add permanent layers for every owned rank. No
visual implies a projectile count, damage area, duration, shield or immunity the
simulation does not provide. Use the real muzzle/contact/area geometry. Damage
and threat cues always have priority over celebratory effects.

## 3. Coverage contract: all offered families

Family animation recipes may share well-authored body actions. They must differ
in prop/material, attachment and outcome cue; a recolored generic ring is not
completion. This table is the initial direction, to be verified against actual
trigger sites and revised after rendered prototypes.

| Family (stable ID) | Activation direction | Evidence during play |
|---|---|---|
| Heavy Load (`heavyLoad`) | Weapon brace and chamber-weight snap | Actual damage delta; bounded heavier contact accent, preserving base weapon silhouette and mass rules. |
| Quick Trigger (`quickTrigger`) | Trigger/mechanism adjustment | Actual cadence and firing mechanism timing; no invented extra rounds. |
| Extended Tube (`maxBulletsIncrease`) | Magazine/tube seat | Existing immediate refill snap + new capacity markers; no duplicate reload/refill. |
| Sleight of Hand (`fastReload`) | Short practiced mechanism gesture | That weapon's own faster reload phases and audio, using authoritative completion. |
| Scattershot (`numberOfBulletsPerShotIncrease`) | Muzzle assembly opens/settles | True pellet fan/count; IV–VIII show tighter grouping when count stops increasing. |
| Piercing Rounds (`bulletsPhaseThrough`) | Hardened round/chamber cue | Visible entry/exit continuation on actual penetrations, one restrained exit accent. |
| Long Barrel (`bulletRangeIncrease`) | Barrel alignment cue | Actual range delta and flight persistence; no permanent aim line on every gun. |
| High Velocity (`rapidFire`) | Feed/propellant cue | Actual flight speed and bounded trail cadence; do not enlarge collisions. |
| Fleet Foot (`walkingSpeedIncrease`) | Foot plant/stride reset | True movement delta and existing gait matching traveled distance; avoid fake dash trails while walking. |
| Vitality (`healthIncrease`) | Chest/medical equipment set | Actual new heart and actual recovery; no healing cue if no health was restored. |
| Field Medic (`fieldMedic`) | Medical kit latch | Distinct cue only on accepted healing; ready/cooldown clarity where useful. Never promise a heal per kill. |
| Scrap Armour (`scrapArmour`) | Armor plate locks | Guard-ready badge, actual absorption/break, recharge completion; no bubble implying full immunity. |
| Quickstep (`quickstep`) | Boot/dash device ratchet | Actual recharge and ready cue; do not imply extra dash distance. |
| Double Dash (`dashCapacity`) | Extra dash cell seats | New charge slot, correct Double/Triple naming, real stored capacity and recharge. |
| Grenade Reserve (`grenadeCapacity`) | Pouch clip seats | Actual capacity slot and available charges; capacity does not necessarily mean instant refill. |
| Afterimage (`sprintInvincibility`) | Recovery device prime | Protection cue exactly during the existing valid dash recovery window. |
| Scavenger (`scavenger`) | Salvage coil/magnet latch | Actual XP attraction motion, one restrained collection accent; no permanent giant circle. |
| Lucky Find (`luckyFind`) | Brass finder/charm set | Honest offer-odds delta and compact build record; never fake a guaranteed rare next card. |
| Hot Shot (`hotShot`) | Chamber ember ignition | Real burn application and readable smolder on enemy; preserve floor/threat contrast. |
| Accelerant (`accelerant`) | Fuel channel connects | Real burning-kill spread ignition; avoid flashing all burning enemies together. |
| Static Charge (`staticCharge`) | Coil discharge into weapon | Actual primary-proc chain distinct from innate Arc/Storm Orb and companion links. |
| Conductive Core (`conductiveCore`) | Coil terminals extend | Real longer/multi-target chains; delta describes reach/count, not fake damage. |
| Dash Mine (`sprintMine`) | Mine clip arms | Actual deployed mine placement, arming and one detonation. |
| Fragmentation (`fragmentation`) | Segmented casing locks | Real secondary shard burst with readable origin; never more drawn than damaging shards. |
| Ricochet (`ricochet`) | Deflector/round seats | Preserve strong existing bounce redirection and target impact; distinguish upgrade from Revolver's innate bounce. |
| Bank Shot (`bankShot`) | Deflector reinforcement | Stronger accent on actual bounced damage, not the initial shot; remain below damage-response caps. |
| Last Shell (`lastShell`) | Final-round marker | Small ready marker at the real last release and actual empowered impact. |
| Breach Loader (`breachLoader`) | First-round chamber prime | Ready after the real reload, consumed on the actual eligible first release. |
| Orbit Drone (`orbitDrone`) | Controller links to arriving drone | Real companion presence/fire; keep accepted quiet links and target limits. |
| Targeting Link (`targetingLink`) | Designator sync | Real target mark and drone focus response; no reticle on an unmarked enemy. |
| Shrapnel (`shrapnel`) | Shard cartridge locks | Real kill-triggered close cone; no guaranteed first kill proc. |
| Executioner (`executioner`) | Chamber/aim focus | Actual wounded-target bonus accent only below the valid health threshold. |
| Heavy Payload (`grenadeDamage`) | Grenade core seats | Actual blast damage delta and grounded central impact; no larger radius implied. |
| Wide Burst (`grenadeRadius`) | Fuse/casing opens | True preview/blast radius; contact and cover continue matching. |
| Ordnance Cycle (`grenadeRecharge`) | Recharge winding cue | Actual recharge timer/ready marker, no free instant grenade. |
| Brace Loader (`braceLoader`) | Moving reload brace | Real walking-while-reloading difference, not reload speed. |
| Sure Foot (`sureFoot`) | Weight harness settles | Actual weight penalty recovered for this gun; no fictional slow resistance. |
| Scouring Heat (`scouringHeat`) | Ember core hardens | Bonus burn only on eligible elites/bosses; don't brighten every burn. |
| Faraday Reserve (`faradayReserve`) | Reserve coil connects | Actual later-jump damage retention; don't invent additional targets. |
| Blast Harness (`blastHarness`) | Harness locks to explosive rig | Real ordinary-enemy displacement; bosses/planted bodies remain planted. |
| Exposed Seam (`exposedSeam`) | Precision chamber set | Actual bonus primary hit on frozen enemy; does not itself freeze targets. |
| Measured Shot (`measuredShot`) | Weapon settles into ready posture | Ready cue after the true wait; consume on eligible release, not trigger press. |
| Close Quarters (`closeQuarters`) | Close combat brace | Actual eligible near-target hit accent; no permanent radius ring. |

Also cover fallback Scrap Cache with actual scrap/health changes and a short
recovery gesture; suppress fictional recovery at full health. Legacy Long Dash
must remain readable in old saves without re-entering ordinary offers.

### Fusions and temporary supplies

All eight fusions need named, distinct activation and real combined output:
Firebreak (burning ground), Storm Circuit (extra jumps), Minefield (mine trail),
Pinball (extra bounces/stronger bounced hits), Breach Engine (first/final release),
Hunter Swarm (three real drones), Kiln Pact (eligible elite/boss burning death
patch), Ground Wire (the actual fourth-discharge extra jump). Use actual recipe
IDs from `fusionRecipes`; do not invent more projectiles or proc opportunities.
Their final silhouette/material recipes must be approved before mass export.

Sentrygon and Aura Salad retain their temporary deployment identity and stable
support IDs. Sentry confirmation shows the real carbine/burst mount and tier;
its landing/continuous fire are the proof. Aura Salad visibly activates its real
moving damage field with the accepted muted currents and counter-rotating seal.
Neither selection implies invulnerability. Show remaining duration, actual tier
and redeployment versus upgrade accurately, including max-tier deploy-again.
Do not change weighted airdrop probability, force either into every offer, or
stack a fake instant deployment over the existing warning/landing timeline.

## 4. Art production: animate the character, not just an icon

Prototype on Rook at actual phone scale before producing ten survivor packets.
Build roughly six reusable action directions: weapon fitting/brace, magazine or
mechanism work, equipment/armor latch, medical/utility action, coil/ember prime,
and fusion resolve. Family overlays supply the specific prop and material.
Distinct silhouette and motion are required; these are not 43 full-body sprite
sets per survivor. First review may reduce/adjust recipes, but cannot remove
family identity from the coverage table.

For each needed recipe, author a short planted multi-frame activation clip in
four facings, maintaining head/body identity, scale, hand and weapon mounts,
foot registration and draw order. Do not relabel the current hurt/death pose as
“powering up,” rotate a full-body bitmap around its feet, or ship cross-survivor
placeholder poses. Reuse a brace frame only as part of a reviewed coherent clip.
Ten-survivor art leases stay owner-scoped and lazy. Load only the active survivor
and selected recipe; prewarm during the picker, never stall its confirm tap on
network/art loading. Provide a deliberate steady-pose fallback on load failure.
Keep the existing 32MiB decoded-art acceptance budget, including largest boss
pair, equipped weapon and support effects. Measure, do not assume the new sheets
fit. Preserve original masters, prompts, frame manifests and import validation
through the existing art workflow (`tool/import_survivor_art.py`, `RegunArt`).
If generating bitmap art during implementation, load the imagegen skill then;
this planning pass does not generate or replace assets.

## 5. Implementation contracts

### Typed acceptance and presentation state

Introduce a presentation descriptor (proposed `UpgradePresentationSpec`) keyed by
stable upgrade/fusion/support ID and a typed **accepted reward** event carrying:
run/room generation, actor ID, accepted sequence/offer ID, source, chosen ID,
previous/new rank or tier, pinned balance identity, meaningful resolved deltas
and presentation recipe. Native choices capture before/after values around the
existing validated commit; publish only after success. Never use card tap,
button animation, a generic rank diff, reroll/ban or offered card as confirmation.

Keep presentation event state separate from recovery damage. The existing
`upgradeConfirmed` listener has a gameplay consumer; replace/bridge it explicitly
without emitting a second pulse. Proposed `UpgradePresentationController` owns
the hold, labels, recipe and first-use emphasis. Do not put transient effects
into `GameState` via dozens of per-frame Riverpod rebuilds. Renderer reads a
small presentation state and one clock; gameplay still owns all damage/charges.
First-use emphasis receives existing accepted mechanic events/identities; it
must not recalculate RNG, mutate proc ledgers or infer hits from animation.

### Saves, pause and interruptions

Add versioned optional presentation data only if needed, and validate finite
clocks, known IDs, rank bounds, sequence and payload size. Old checkpoints default
to no celebration. Define crash windows before implementation: a confirmed upgrade
is never lost, reapplied or refunded; a paid recovery pulse fires at most once;
restoring an unfinished cosmetic beat settles to a readable static confirmation
without trapping the run in a hold. Consumed cues never replay from ordinary
background/foreground snapshots. Reset first-use emphasis on run/epoch changes.
Entering pause mid-beat and resuming it must not route through the ordinary
“upgrade accepted” event again.

### Co-op and online

Extend server accepted-choice output with a bounded serial and descriptor,
scoped to authenticated room/generation/actor. Prefer existing serialized progress
or a bounded event packet after schema inspection; do not add a public reducer
that accepts the outcome, position, damage or rank from the client. `choose()` is
the authoritative commit point. Include timeout/autoselection, support rewards,
fusions, stale requests, dead/disconnected actors and retries. Generate bindings
only if the chosen contract requires them.

Co-op already coordinates shared selection. Keep waiting players in that flow;
once all choices resolve (or the existing timeout resolves them), start one
server-owned bounded confirmation hold, then resume everyone together and consume
the existing recovery flags. A client never extends that hold to wait for art or
network acknowledgment. Each player gets their own confirmation; remote survivors
show a short bounded action, without four competing large labels. An early chooser
may receive a compact “locked in” acknowledgment while waiting, not a cosmetic
animation that falsely signals resumed combat.

Deduplicate by generation/actor/serial. Reconnect/resubscribe establishes a
watermark and renders current persistent state without replaying historical
celebrations. A missing event cannot block simulation. Capability-gate the new
protocol; older servers keep the current safe flow. Versus must not gain a global
freeze for one fighter: if supported reward paths exist there, use a nonblocking
local acknowledgment with authoritative actions unchanged. Validate actual modes
before wiring. Do not expand weapon/survivor admission in this work.

### Admin, API and web/mobile parity

Numeric balance stays in the current shared catalogue and pinned run snapshot.
Use `RankEffects`, `upgradeDetails` and authoritative hosted values to resolve
truthful before/after copy; check native/online projections for missing inputs
rather than filling with enum defaults. Inventory/count perks, caps, late-rank
curves, stat floors and survivor-specific conditions must be honored.

Do not add 43 remote animation toggles or mix VFX intensity with damage knobs.
Default plan is code-owned presentation recipes and existing Reduced Motion,
Haptics and volume settings. Add a designer-facing admin preview of affected
family/rank and true resolved benefit only if it helps verify the current numeric
editor; clearly label unsupported hosted combinations. A richer animation preview
may live in Training/review tooling instead of bloating the admin app. If new
balance controls prove necessary after testing, regenerate all shared catalogues,
retain exact historical IDs/hashes, validate draft migration and two-device
rebase/publish/rollback. Never auto-publish a visual improvement or reset toggles.

## 6. Balance audit: distinguish invisible from ineffective

Record for every offered family: trigger/eligibility, base→next resolved value,
weapon/survivor applicability, time to opportunity, expected useful frequency,
cap behavior, competing effects and actual observed output. Reuse rank fixtures
and the existing component audit as inputs, not evidence of game feel.

Run controlled same-seed/same-enemy/same-weapon comparisons at ranks0→I, I→II,
III→IV and VII→VIII plus both charge-capacity transitions. Measure appropriate
outcomes: shots/time to kill, reload time, actual penetrations/bounces, burn uptime,
heal frequency/cooldown, guard absorption, dash readiness, grenade availability,
attraction and conditional bonus contribution. Separate selected-balance revisions
and weapon immunity/resistance. Do not claim every legal upgrade helps every gun.

If a benefit is below perception or rarely finds a valid target, propose a
specific formula/eligibility/offer change with before/after evidence. Do not
silently buff all damage to rescue the presentation. Conditional/odds perks such
as Lucky Find can earn clear credit through accurate state/copy without faking
immediate combat output. Preserve current rank limits, slots, offer randomness,
XP/funded offers, four-active-second grace and supply weights unless a separately
reviewed gameplay correction is justified. This plan authorizes investigation and
presentation design, not a blanket numerical rebalance.

## 7. Work order with stop points

1. **Baseline and coverage audit.** Produce a machine-readable descriptor/trigger
   inventory and labeled before/after gameplay clips. Confirm all43 +8 +2 entries,
   fallback/legacy handling and actual online admission. Record missing/ambiguous
   sources. Deliver the initial issue list before broad art production.
2. **One complete prototype.** Implement accepted-event plumbing, hold/clock,
   interruption/restore rules and Rook prototypes for Heavy Load, Fleet Foot,
   Scrap Armour, Hot Shot, Ricochet and a supply deployment. They cover scalar,
   movement, availability, conditional proc, already-readable mechanic and delayed
   deployment. Include a live local co-op prototype before locking the contract.
   Review motion clips on both arena floors at phone scale and on device.
3. **Player gate.** Compare the old flow and the prototype with muted/unmuted,
   Reduced Motion and touch controls. If players see “a celebration” but cannot
   tell what changed, revise the design here. Do not mass-produce the same failure.
4. **Full coverage.** Produce remaining family recipes, survivor facings, all
   fusions/support variants and real mechanic cues. Check on every supported
   weapon, with stacked builds and cosmetics. Bring admin/API copy/preview parity
   and compatibility along with each slice.
5. **Acceptance and delivery.** Run focused+full checks, local authoritative co-op,
   release web/Android/iOS builds and creator phone playtests. Capture evidence,
   list any unaccepted content, and hand off exact admin actions if numerical
   changes were approved. Preserve creator release identity unless asked to bump.

## 8. Verification: prevent a third presentation-only success

Automated correctness:

- Descriptor coverage for every selectable family/fusion/support; no missing IDs,
  no impossible rank/count/damage promises, supported weapon/character context.
- Accepted choice once; stale/double tap, ban, reroll, rejected server result and
  unrelated pause never celebrate or release recovery. Support deploy-again and
  capacity-based names/ranks are correct.
- Hold does not advance bullets, hazards, grenade fuse/recharge, reload, XP grace,
  support life, boss commitment, spawn/director or damage. Beat advances once,
  releases boundedly and cannot leave input latched. Recovery runs once afterward.
- Pause/background/resume, death, restart, Continue/crash-window, pending art load,
  failed load, disposed route, changed Training weapon and room generation changes.
- First-use cues observe real accepted results; no RNG/flight/damage changes and
  no phony healing, immunity, penetration, proc or charge. Cover/collision parity.
- Deterministic native/TypeScript values; old saves/catalogue hashes, drafts,
  candidate history, enable flags, rebase and rollback survive.
- Co-op early/late chooser, timeout, disconnect, retry, reconnect, duplicate and
  out-of-order events; all players resume from authoritative time. Old server
  fallback and applicable Versus flow remain playable.

Visual/audio/performance:

- Render actual survivor+held weapon at four facings for all ten survivors, both
  floors, cosmetics, rank milestones, crowded scenes and large text. Inspect
  animation clips, not only stills. Feet stay planted and weapon mounts align.
- Preserve hostile warning/impact, damage tint, guard cues, control reach and
  camera stability. No bright full-screen pulse or permanent stack of auras.
- Reserve a small presentation-owned draw slot for confirmation so the existing
  40-effect cap cannot silently suppress it; do not evict gameplay patches or
  increase projectile/chain budgets. Prioritize warnings and damage feedback.
  Coalesce proc accents by source/target/time and bound remote-player cues.
- Maintain32MiB decoded art in worst supported loadouts. Measure frame-time,
  allocation/load spikes and audio overlap on the creator's phone and a modest
  Android device; target60fps on supported60Hz hardware, compare against baseline.
  Web profiling/builds and headless simulations do not prove phone comfort.
- Audio manifests/provenance, gain/headroom, mute/volume, pause and device listening.
  One confirmation sound/haptic per accepted event; no proc sound wall.

**Proposed human acceptance test, agreed before rollout:** use at least five
players, preferably including the people who raised the complaint. Randomize
old/new clips and hands-on runs without telling them which effect to look for.
For the six prototype families, ask: “What changed?”, “When did you notice it?”
and “Did it feel useful/stronger?” At least4/5 should identify the correct kind of
benefit without reading Details, using the next eligible real mechanic as the
observation window. Passive/odds perks are judged on accurate understanding,
not fabricated instant power. Record the number of opportunities and any proc
that did not occur; repeat deterministic Training comparisons where necessary.

Also score confirmation pacing and threat readability. Require no accidental
actions, misleading immunity reports or lost-threat complaints in the observed
trials. Compare strength ratings against the old flow and record actual gameplay
outcomes. If cosmetic ratings rise but mechanical understanding/usefulness does
not, the pass fails and returns to the relevant trigger/balance/presentation gap.
Small-sample acceptance is a product gate, not a statistical universal claim.
Creator signs off after phone play, before calling the work accepted.

## 9. Next-session handoff

Read this plan plus current `AGENTS.md`, `.impeccable.md`, `REGUN_PROGRESS.md`,
`PLAYTEST_GUIDE.md`, `REGUN_COMPLETE_GAME_PLAN.md`, and the prior feedback/recovery
documents. Inspect current git status first: earlier weapon work may already be
staged by the creator; preserve it. Current release identity was1.0.0+23 when
this plan was written; verify it rather than changing it automatically.

Suggested next-session prompt:

> Implement `docs/UPGRADE_FEEL_IMPLEMENTATION_PLAN.md` starting with the full
> coverage/baseline audit and the six-family end-to-end prototype. Preserve the
> existing recovery pulse, gameplay timings, supported online admission, pinned
> balance and staged changes. Include real character animation, truthful deltas,
> actual-mechanic feedback, co-op authority, interruption/save safety and Reduced
> Motion. Produce phone-scale motion evidence and the player-review prototype
> before mass-producing all survivor/family assets. Do not claim visual acceptance
> from passing tests or installation. Continue into full coverage after that
> prototype has met the plan's review gate; surface any justified balance changes
> with evidence instead of silently buffing everything.

Deliverables: coverage inventory, baseline/prototype clips and measurements,
implementation and asset manifests, state/protocol compatibility notes, tests,
phone acceptance results, exact admin instructions if any tuning changed, and an
honest remaining-work list. No gameplay or assets were changed by this plan.
