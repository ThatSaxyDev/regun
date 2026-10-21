# Regun: expanded arsenal, power-ups and loadout

20 October 2026 · Proposal for review. The four weapons, new upgrade families, unlock changes and loadout redesign below are **not implemented**. The current jumper, Magistrate and explosion corrections are separate completed work described in the progress log.

## Direction

Grow the roster from four to eight weapons by adding four different ways to fight: deliberate penetration, a close flame stream, planted explosives and returning blades. Each must earn its place through aiming, animation, sound and decisions during combat. Preserve the Shotgun's close blast, Carbine's tracking/magazine swap, Revolver's deliberate precision and Arc Caster's chain pressure. Review all eight together; do not make the original four feel like starter equipment.

Keep one equipped primary per run, the current two-stick controls and dash/reload thumb cluster. No extra fire-mode button. New weapons are available in Training for testing, while normal-mode unlocks reward repeat play and mastery. Preserve existing unlocks and saved builds. Do not implement multiplayer as part of this expansion.

## Four new weapons

All numbers below are initial simulation/playtest seeds, **not approved balance**. Compare real 30-second output including reloads, missed shots, walls and target resistance; a large ideal damage number alone is not a reason to ship a weapon.

| Weapon | How it plays | Initial seed | Strength / cost |
|---|---|---|---|
| **Rail Lance** | Holding aim charges a heavy stake, then fires automatically; releasing aim cancels the charge. Clear charge/readiness feedback. | 3 stakes; .45s charge + .65s recovery; 7 direct damage; 1000 range; 2.6s magazine reload. Two additional penetrations at 65% retained damage each. | Lines up elites and bosses. Loses output to missed charges and chaotic flanking; cannot shoot through arena solids. Revolver remains immediate and more forgiving. |
| **Cinder Hose** | A broad, short flame stream swept by the aim stick. Fuel replaces the normal ammo label; reload changes the fuel canister. | 60 fuel; .06s simulation tick; .22 direct damage/tick; 240 range, 40° cone; 2.3s canister swap. Short non-stacking burn, initial .6 damage/second. | Strong at sweeping a nearby pack. Must stay dangerously close; no instant long-range deletion. Cannot use a hit event for every flame particle. |
| **Rivet Driver** | Drives visible explosive rivets into enemies. Reload commits a brief detonation cue, bursts the planted rivets, then swaps the strip. | 8 rivets; .26s interval; .75 impact + 1.25 stored burst damage; 560 range; 2.2s strip reload. Two rivets per target, eight live rivets total; 3s expiry. | Set up a pack or exploit a boss opening. Damage is delayed, targets can die before the setup pays off, and detonation must never wait forever for a reload. |
| **Reaper Disc** | Throws a thick spinning saw disc along the aim direction; it turns back toward the player's recorded catch path. Outbound and return paths are readable. | 3 discs; .65s interval; 1.5 damage per allowed contact; 500 outward range; 2.4s cassette swap. At most one outward and one return hit per target per disc; three discs active. | Rewards movement that lines up the return pass. No homing orbit, unlimited re-hits or arbitrary ammo refunds when a disc returns. Walls stop an outbound disc and trigger a bounded return; they never permit damage through solids. |

**Visual and audio identities:** Rail Lance gets a chunky copper/ceramic stake, a planted charging mechanism, a heavy report and a short material wake rather than a clean laser line. Cinder Hose gets a small pilot ignition, noisy ember clusters and a low combustion sound with a restrained hiss; stop the loop immediately on pause/release. Rivets remain visible in the target, use a dry powered-tool clack and share the main explosion sprite for detonation. Reaper Disc gets a readable rusted-metal silhouette, brief motor rasp and separate outgoing/return impacts. Every weapon needs its own reload mechanism, HUD preview, world pose, muzzle alignment and sound. Use the game's existing material language and arena grading.

**Implementation order:** Rail Lance first (charge/penetration foundation); Rivet Driver second (bounded delayed effects/provenance); Cinder Hose third (swept area ticks/loop lifecycle); Reaper Disc fourth (two-leg swept collision and per-target contact history). Ship complete weapon slices, not four unfinished enum entries. Confirm the first slice's controls on the phone before building the remaining three.

## Unlocks that last beyond one good session

Current normal-mode gates are training, one Shadow defeat and one Demon defeat. That explains how a skilled player can finish the four-weapon roster quickly. More weapons alone would postpone the same problem unless the new progression spans multiple successful encounters.

Proposed cumulative targets, displayed as progress rather than hidden requirements:

| Unlock | Persistent normal-mode requirement |
|---|---|
| Rail Lance | 6 boss victories, including victories while using Revolver. |
| Rivet Driver | 12 boss victories across at least 3 distinct boss kinds; earn a boss victory with Rail Lance. |
| Cinder Hose | 18 boss victories across at least 4 kinds; earn a boss victory with Rivet Driver. |
| Reaper Disc | 24 boss victories across at least 6 kinds; earn a boss victory with Cinder Hose. |

A boss arrives after three active minutes at the earliest; these totals therefore cannot all complete in a single sub-hour normal session. They are starting progression targets to measure, not promised engagement times. Do not add forced daily waits, currency purchases or a requirement to win without taking damage. Aim Assist and accessibility settings remain eligible. Training/Boss Rush never award progression. Existing unlocked weapons stay unlocked.

Add schema-versioned `totalBossVictories`, `defeatedBossKinds` and `bossVictoriesByWeapon`, settled once per run ID. Keep per-run counts so repeated victories over the same kind count individually. Old saves have a set of boss identities/unlocks, not reliable lifetime kill counts: preserve those entitlements and migrate known minimum progress; do not invent historical victories. Show the migration's starting progress accurately. Prototype these gates with real session results before finalizing them.

## New power-ups

Start with four families, all ranked I–VIII, to complement the arsenal without flooding the offer pool. Keep the existing rank/effective-rank distinction, six special slots, funded XP choices, prompt grace, bans/rerolls and unique choices. No second picker without a newly funded level.

| Family | Brief card copy | Purpose / first tuning target |
|---|---|---|
| **Rupture** | “Killed enemies explode.” | The requested death explosion. Eligible player-owned kills create a small real blast at the corpse using **the exact same shared explosion renderer/atlas as mines and Rivet Driver**. Rank I: 1 damage, 90 radius. Rank III: 1.5 damage, 110 radius. IV–VIII add smaller gains; initial VIII ceiling 2.1 damage/135 radius. Guarantee the trigger for eligible kills rather than hiding the effect behind a low proc chance. |
| **Concussive Loads** | “Hits shove harder.” | Amplifies existing bounded impact, initially +15% shove at I, +35% at III, +55% maximum at VIII. Preserve the .24s target response cooldown, crowd/wall constraints and planted-boss resistance. No increased stun duration or pellet stacking. Tune per weapon so a flame tick cannot continuously immobilize enemies. |
| **Fault Finder** | “Repeated hits expose armor.” | Repeated primary attacks mark a target's armor briefly. Start with three distinct attacks to open a 1.2s vulnerability; subsequent ranks improve the bounded benefit/duration. At most one stack per trigger/tick window; no stacking per pellet, arc jump or secondary shard. Help Carbine/Cinder sustained pressure without replacing Heavy Load or making boss weak points irrelevant. |
| **Overpressure** | “Larger, stronger blasts.” | Improves blast radius/damage for Rupture, Dash Mine and Rivet Driver. Start at +10% damage/+8% radius; cap the final family at +35%/+25%. Apply once per blast. Offer only when the equipped weapon or build actually has an explosion source. Fragmentation remains the separate shard-burst upgrade. |

Rupture is distinct from existing **Shrapnel** (a chance of a shard cone on a primary kill), **Fragmentation** (shards from explosions) and **Accelerant** (burn spread). Keep all three identities understandable in Collection.

**Proc safety is part of the feature:** introduce explicit damage provenance/parent-event IDs instead of relying only on `lastHitWasSecondary`. Weapon, burn, drone and weapon-detonation kills can qualify for Rupture; a Rupture descendant cannot recursively create another Rupture. Each enemy emits one kill event. A future chain-reaction fusion may permit exactly one extra generation, with an explicit six-burst budget; it is not part of the base upgrade. Parent damage modifiers apply once, and child effects cannot re-trigger full-strength chain/burn/shard trees. Keep damage and visible bursts synchronized inside the existing 40-effect/projectile budgets; coalesce nearby simultaneous bursts with a defined damage ceiling rather than doing invisible damage when the visual budget is exhausted. Training gets direct access for validation.

Add these families incrementally. Build-aware eligibility must exclude no-effect choices (for example Ricochet on a flame stream until there is a meaningful authored behavior). Preserve without-replacement offer selection, including rerolls. Audit Scattershot, Piercing, High Velocity, Extended Tube, first/last-shot perks and all six fusions for each weapon. For continuous fire, define a trigger/tick proc window; no per-particle procs. For discs/stakes, retain projectile and bounce damage caps.

## Loadout redesign for eight weapons

The present screen has three equally weighted text columns, disabled locked entries and a tiny footer weapon preview. Doubling the weapon list would increase scrolling without helping a player understand the choices. Replace it with a compact **armory selection screen** using the existing pixel UI, worn metal/brass palette, custom controls and fonts.

**Landscape layout:** a narrow rail switches Survivor / Weapon / Arena; the center holds a two-column weapon roster; the detail panel on the right shows the inspected weapon at a useful size. A fixed bottom strip shows the equipped survivor, weapon and arena beside Start. On shorter/narrower screens, move the detail panel to a scrollable sheet reached from the selected card; preserve the roster and reachable Start. Never shrink eight cards until labels or touch targets stop fitting.

Each weapon card has a recognizable sprite, short role (Spread / Automatic / Precision / Chain / Charge / Flame / Setup / Return), clear equipped state and one concise strength. Locked cards are still tappable for inspection. Distinguish **inspected** from **equipped**: opening a locked weapon's details cannot replace the usable selection or enable Start with an invalid loadout.

The detail panel contains a large, grounded weapon preview, one-sentence role, meaningful stats (damage per shot or tick, effective range, capacity/fuel and reload time) and a brief tradeoff. Show honest units rather than arbitrary star ratings. Offer one deliberate “Preview” action to play a brief fire/reload sample; no automatic repeated sound or looping gunfire while browsing. Reduced Motion shows planted poses. “Try in Training” works for locked weapons without granting profile rewards.

Locked details show progress, for example **Boss victories 9 / 12**, plus any incomplete mastery requirement. Show the next actionable milestone; do not bury it in a paragraph. Earned unlocks get a short armory reveal and are easy to find on the next visit. Remember the last valid selections, while retaining current Start behavior, resumable-run handling, double-tap prevention and navigation cleanup.

Put weapon-compatible power-up examples below the main detail, with a route to the existing Collection/build reference. Do not create a pre-run perk equipment system: upgrades are earned during a run. Collection should explain Rupture/Fragmentation/Shrapnel separately and show I–VIII progression and real fusion prerequisites.

## Delivery and acceptance

1. **Shared foundations:** damage provenance, weapon-capability/upgrade compatibility data, schema migrations and persistent unlock progress. Do not scatter eight new `switch` fallbacks through legacy prototypes.
2. **Loadout prototype + Rail Lance:** use real art, locked inspection, Training preview and a complete playable weapon slice. Confirm thumb reach and legibility on the smallest supported landscape phone with large text.
3. **Rupture + Rivet Driver:** share the main explosion renderer, add budgets and re-entry-safe kill handling, then tune pack clear/boss pressure against existing weapons.
4. **Cinder Hose + Reaper Disc:** finish their state/collision/audio lifecycles and compatible perk behavior. Add Concussive Loads, Fault Finder and Overpressure as tested slices.
5. **Full eight-weapon review:** same arenas, enemy mix and boss phases; starting build, rank III and rank VIII; shield/boss resistance; reload/dash risk; phones/headphones. Preserve the latest recoil/reload improvements on all existing guns. No weapon may win every meaningful comparison.
6. **Release:** unique/eligible offers; save/Continue and old-profile migrations; pause/background/restart during charge, loop, return and detonation; no offline catch-up attacks; short and long soaks; native build and physical comfort/performance/audio review. A successful install or headless test does not establish human balance approval.

Keep the release identity at 1.0.0+7 until the creator requests a version change. Implementation of this proposal is the next task after review; this document does not claim the new arsenal/loadout/power-ups already exist.

### Implementation note — 21 October 2026

The current four-weapon/three-survivor roster now has a pinned Survivor/Weapon/Arena catalog interface with persistent kit preview and Start. This navigation improvement is implemented independently of the proposed new weapons/loadout systems above; those proposals remain unimplemented. The creator separately requested the current shotgun's 1.2 base pellet damage and 3.2-second base reload candidate.
