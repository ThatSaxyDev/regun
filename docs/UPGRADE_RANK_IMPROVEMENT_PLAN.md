# Upgrade rank improvement plan

24 October 2026. Implementation is now in source across mobile, module, gateway
and admin. See [implementation status](UPGRADE_RANK_IMPLEMENTATION.md) for the
shipped scope, checks and remaining device review. This document records the design
and acceptance plan. Keep eight as the normal maximum and improve what
players get from each choice. Capacity upgrades retain their separate limits.

## Intended result

A player can understand the next rank, feel a useful improvement after taking it,
and finish a build without endlessly extending its numbers. An upgrade must not
consume a rank while delivering no lasting benefit, except a clearly explained
rank that genuinely unlocks an available fusion prerequisite. Reaching VIII should
feel like completing that upgrade, not opening another mandatory grind.

## Current source baseline

The enum contains45 entries:43 offered families, one retired legacy entry and
Salvage fallback. Most offered families reach VIII. Double Dash and Grenade Reserve
have two ranks at default caps (one-to-three stored dashes, two-to-four grenades);
a lower authored cap can remove the redundant rank. There are eight fusion recipes,
with current III/II prerequisites, two fusion slots and two banked cores.

Many effects use three full early ranks followed by0.3 effective-rank increments.
Reload/dash cooldown tails use0.2. Other upgrades use explicit integer gains or
counts. These are not interchangeable: damage, projectile count, speed, cooldown
and proc frequency need separate power budgets.

Some safeguards already exist: capped projectile velocity, range and Prism Cutter
magazine upgrades stop appearing. Scattershot already changes from extra projectiles
to tighter spread at later ranks. Preserve those behaviors rather than claiming
they are new work.

Potential weak spots to audit, not blanket claims of broken upgrades:

- Shotgun Fast Reload has30ms later increments. Flint's reload bonus can reach
  the850ms floor early, leaving subsequent ranks without reload improvement.
- Fuse's grenade-recharge bonus can reach the10s floor before the final rank.
- Live strength modifiers can reach other limits or round small gains away.
- Shared damage-bonus caps can flatten one upgrade in a particular combined build.
- Count-based upgrades must deliver their advertised count/coverage without
  exceeding existing projectile, chain, population or effect budgets.

## Rank structure

| Ranks | Purpose | Design rule |
|---|---|---|
| I | Establish the upgrade's identity | Clear first benefit; show behavior and result |
| II–III | Make it a reliable part of the build | Preserve current early progression and III/II fusion access initially |
| IV | First late-rank milestone | Noticeable refinement within the family's existing mechanic |
| V–VII | Develop that identity | Useful, measured increments rather than a universal scalar tail |
| VIII | Finish the upgrade | A strong, bounded final step and clear completed presentation |

A milestone does not automatically add a new attack or fusion. First try a better
curve, spread/control refinement or stronger final increment within the existing
mechanic. Redistribute the late-rank power budget before increasing total VIII
power. Do not make every rank a large spike or every VIII rank a proc generator.

## 1. Audit every family and rank

Build a generated rank matrix for all43 families across compatible weapons and
survivors, default balance and supported extreme admin values. Record current and
next actual effects, rounding, floors/ceilings, prerequisites, fusion contribution,
secondary effects, eligibility and brief/detail copy. Store the exact snapshot and
sample conditions with each result.

Use effective values: full/partial reloads, firing cadence, magazine size, distance
bands, chain retention, healing cooldown and movement constraints. Include affected
survivors such as Flint, Fuse, Scrapper, Coil and Suture, and combined/fused builds.
Do not infer combat value from a description or a nominal rank number.

Classify each transition: useful; too small to notice; capped/zero; unsupported;
misdescribed; or primarily a fusion milestone. Produce a proposed old/new I–VIII
table for each changed family before implementation. First batch: Fast Reload,
Ordnance Cycle, Scattershot, Heavy Load, Quick Trigger and Scrap Armour.

## 2. Remove wasted choices

Use a shared effective-benefit calculation for offer eligibility, application and
preview. Apply the same rules in the Flutter game and supported server catalogue.
A cap or rounding change must not let a card promise a gain it cannot apply.

- If the next rank changes no lasting effect and unlocks no meaningful recipe
  prerequisite, omit it for that build. Keep the stored rank; no refunds, automatic
  conversion or silent stat changes to an existing run.
- If a capped component still has a real secondary benefit, show that actual
  benefit. A one-off refill alone should not disguise a permanently empty rank.
- Preserve access to legitimate III/II fusion prerequisites. A recipe-enabling
  choice must say what it enables instead of claiming an impossible stat gain.
- Keep bans, limited rerolls, fallback, unique cards and recently added rarity/
  repetition policy. Do not compensate for weak ranks by making them more common.

## 3. Improve families in controlled batches

| Families | Proposed improvement direction | Limits to preserve |
|---|---|---|
| Heavy Load, Quick Trigger, Last Shell, Breach Loader | Replace overly flat late tails with authored IV/VIII milestones; compare whole firing/reload cycles | Existing release rules, conditional identity and bounded combined damage |
| Extended Tube, Fast Reload, Brace Loader | Make later ranks improve sustained handling; omit exhausted benefits | Shotgun commitment, partial reload rules, reload floors, magazine caps and pickup refill |
| Scattershot, piercing, Ricochet, Bank Shot | Strengthen precision/coverage or impact within existing mechanics; clearly distinguish count changes from spread changes | Pellet/chain/projectile budgets, weapon compatibility and ricochet damage cap |
| Hot Shot, Accelerant, Scouring Heat | Make later burn investment meaningful against its intended targets | Burn duration/proc limits, spread generations, boss fairness and authored fusions |
| Static Charge, Conductive Core, Faraday Reserve | Separate chance, reach, jumps and retention; give a clear final benefit | Chain budgets, retention ceiling and existing Ground Wire/Storm Circuit roles |
| Sprint Mine, Fragmentation, Shrapnel, grenade damage/radius/recharge, Blast Harness | Improve useful blast coverage/pressure and sustained ordnance without charge spam | Cover, body/wall collision, ordinary/boss resistance, recharge floors and effect budgets |
| Orbit Drone, Targeting Link | Improve reliable focused damage and final build completion | Drone/fire limits, target rules and Hunter Swarm identity |
| Health, Field Medic, Scrap Armour | Prefer clearer reliability/recovery benefits over excessive late sustain | Healing cooldowns, recharge floors, damage/protection rules and survivor identity |
| Movement, Quickstep, Afterimage, Sure Foot, Scavenger, Lucky Find | Make benefit clear and hide exhausted effects; retain positional skill | Movement/aim control, dash timing, protection bounds and established offer policy |
| Executioner, Exposed Seam, Measured Shot, Close Quarters | Make conditional investment worthwhile and understandable | Target/weapon prerequisites, shared bonus caps and existing triggers |
| Double Dash, Grenade Reserve | Keep low rank caps and scarcity; improve explanation of stored charge versus recharge | Three dashes/four grenades at default maxima; no extra VIII progression |

Directions are design proposals, not final new mechanics or approved numerical
buffs. Review actual old/new curves and whole-build results before choosing them.
Ship corrected eligibility/copy first; add new behavior only when numbers and
presentation cannot make the existing identity satisfying.

## 4. Make each choice understandable

Keep existing pixel frames, typography, glyphs and compact three-choice layout.
Cards show name, current→next rank and one short statement of the real benefit.
Details show accurate current→next effective values with sensible precision and
units. Examples: “Full reload0.97s →0.85s”; “Tighter spread;9 pellets”; “Next rank
unlocks Firebreak eligibility” only when it actually does. These are formatting
examples, not promises for every weapon or survivor.

Use the existing selected-upgrade cue for IV/VIII emphasis; no extra modal, camera
shake, purchase prompt or long interruption. Respect Reduced Motion. Collection
and Training show the full rank path and let players compare III, IV and VIII.
Keep important actions pinned and test compact landscape/large text. Any new effect
must reuse the game's material/pixel presentation and have a strict render budget.

## 5. Reconcile game, API and admin

1. Define a versioned rank-effect contract with shared Dart/TypeScript fixtures.
   Keep eligibility, application and display derived from the same calculations.
2. Existing admin strength controls remain compatible. Add explicit curve fields
   only for reviewed numerical changes, with bounds and compatibility checks.
   No arbitrary formulas/scripts or remotely authored new attack behavior.
3. Admin reviews current/new rank tables, cap interactions and sample supported
   loadouts. Use staging, revision checks, publication reasons, durable requests,
   history and publish/rollback as new releases. Staging remains catalogue review.
4. Pin rank policy plus numerical snapshot at new run creation on app/server;
   persist it through Continue/revive. Old runs retain their old calculations,
   eligibility and displayed effects. Reject unsupported policy versions safely.
5. Deploy compatible app/module/gateway/admin capabilities before activating a
   release. Disabling or rolling back a release affects subsequent runs only.

Avoid a single global tail multiplier that changes every upgrade, or new UI values
that the current simulation cannot reproduce. No money, ownership, losses or spend
history affects rank power, price, odds or encounter difficulty.

## 6. Verification and player review

Automated: exact rank deltas, cap/rounding cases, survivor/fusion combinations,
no empty offers, deterministic selection/recent-history recovery, old/new save
compatibility, stale choices, XP/supply/fusion source handling and shared server
fixtures. Test admin publication and numeric bounds for any new fields. Verify UI
copy against the actual simulated effect, not another copy of its formula.

Compare whole builds and weapon cycles at III/IV/VIII, normal and fused, on ordinary,
elite and boss targets. Record damage, uptime, healing, safety, coverage and CPU/
effect budgets. Stronger numbers are not evidence of better choice quality.

Then conduct fresh-run phone sessions with several users. Record which offered
ranks they choose/skip, why, time/level to IV/VIII and whether they can explain the
benefit. Aggregate optional instrumentation honestly: attempts/exposure are not
unique players, and training/time-accelerated tests are not normal progression
samples. No need to collect input traces or identify players for this review.

Acceptance: no unexplained zero-benefit choice in tested supported cases; copy
matches application; all eight fusions remain reachable; capacity limits/rarity
remain; previous saves retain their rules; compact controls remain reachable; and
players report that later investment is worth choosing. Reaching VIII must not
become necessary for a viable normal build.

## Implementation order

1. Audit matrix and proposed curves; review the first six families.
2. Effective-benefit eligibility and accurate brief/detail copy.
3. Core weapon/handling improvements, then ordnance/defence, then special families.
4. Selected IV/VIII finishing steps and in-style feedback where justified.
5. API/admin authoring, compatibility and safe release activation for each batch.
6. Phone review and observed pacing; adjust one batch at a time.

No new XP curve, extra rank cap, fusion gate increase, weapon price change or paid
upgrade mechanism is part of this plan. Do not revise XP/rarity simultaneously
unless evidence shows those systems independently need adjustment.
