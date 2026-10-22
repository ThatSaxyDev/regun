# Regun: six stronger weapons and subtle weapon weight

22 October 2026 · **Approved and implemented.** Six additions bring the live
solo/Training roster to **21**, with the walking multipliers below. The user first
requested checkpoint commits: client `6f9f2b3`, backend `810244b`; this expansion
follows those commits. Release identity remains1.0.0+11. Online admission stays
limited to supported weapons; backend walking parity is prepared locally, not
rolled out. Universal reload and sniper fatigue remain documented in
RELOAD_AND_SNIPER_FATIGUE.md. The creator subsequently strengthened Twin and requested brighter weapon effects;
see HEAVY_WEAPON_FEEL_REVIEW.md for that superseding design.
See ENDGAME_WEAPONS_REVIEW.md for implementation,
validation and hands-on checks. The design targets below remain tuning targets;
automated damage samples do not certify final balance.

## Design target and current contracts

The final six should feel like earned endgame equipment: stronger opening impact
and a distinctive reason to equip each, rather than six modest variants of the
existing guns. Initial target: roughly20–35% more useful output than the nearest
existing class across its intended encounters. That means effective damage to
valid targets over firing **and reload time**, not theoretical projectile DPS.
Some tuning seeds below exceed that advantage in an ideal setup; pull them back
if ordinary or developed-build tests erase the rest of the arsenal's roles.

Existing promises remain: Frost freezes; Rivet rewards planted crowd demolition;
Reaper returns to the live gun; Sniper releases an aimed piercing shot with bounded
fatigue; Repeater accelerates during a100-round belt. Grenades remain independent.
Keep enemy mass/cover, native feel, damage distance sampling, primary/secondary
proc separation, full reload commitment, pause/save/restart and mirrored controls.
Do not bring back the rejected Hammer or a complicated harpoon substitute.

All proposed numbers are **base Rook tuning seeds**, before upgrades and distance
modifiers. The six are mechanically stronger while weight imposes a small,
predictable movement cost. Weight must not be the only balancing tool.

## Implemented roster

| Weapon / class | Equip promise | Base seed | Full / tactical reload | Mobility |
|---|---|---|---|---:|
| **Twin Verdict** / twin-bore heavy pistol | Land alternating barrels on the same enemy for a stronger second hit. |12 rounds; .48s cadence;2.5 direct, second consecutive alternating-barrel hit3.5; range780, speed1450. |2.6s /1.82s |99% |
| **Flak Regent** / fragmentation autocannon | Break a pack apart with a direct slug and controlled outward fragments. |16 rounds; .32s cadence;2.4 slug + four .45 fragments; range650, speed1050. |3.0s /2.10s |94% |
| **Anchor Engine** / magnetic ordnance launcher | Gather mobile enemies around a planted device, then crush the cluster. |4 charges;1.1s launch separation;8 crush damage;165-unit crush radius; up to600 throw range. |3.4s /2.38s |93% |
| **Faultline Driver** / seismic lane cannon | Send a committed sequence of floor fractures through a crowded lane. |5 charges;1.15s cadence;6 damage per body;720-unit lane,42-unit half-width, three sequential sections. |3.2s /2.24s |94% |
| **Cyclone Breacher** / automatic rotary shotgun | Deliver rapid, heavy close-range volleys without Frost's control effect. |8 rounds; .50s cadence; five1.2 pellets; range300, speed850. |3.0s /2.10s |94% |
| **Mourning Bell** / mechanical resonance cannon | Strike a group, then punish enemies that remain in the committed pressure cone. |6 charges;1.0s cadence;4.5 initial +1.5 delayed echo; range400;70° cone; at most five targets. |3.0s /2.10s |95% |

### Twin Verdict

One weathered twin-bore pistol with a paired cylinder, **not dual wielding**. This
fits the current survivor grip contracts. Barrels alternate visibly left/right
through measured sockets. A first hit primes one owner ID for .8s; the next hit
from the other barrel earns the3.5 hit and consumes that prime. A third hit starts
a new pair. Missing, changing targets, expiry or reloading breaks the pair. Never
build a permanent damage multiplier or prime several enemies through ricochets.

The value is repeatable focus damage with a satisfying paired rhythm. The existing
Revolver still offers a simpler heavy first hit and lighter movement. Draw distinct
bore flashes, a small physical brass pin on a primed target and a heavier accepted
second impact; no floating number storm. Empty reload resets the paired striker;
tactical reload swaps/seats the cylinder and skips that reset. Shared Pierce and
Ricochet may be offered only with a per-original-shot combo ledger.

### Flak Regent

A chunky short autocannon with a square drum and a visibly thick shell. A shell
bursts once on its first body/solid contact or its terminal range. Four fragments
fan forward from the resolved contact; they ignore the original direct-hit owner,
so a large boss cannot absorb all fragments for unintended shotgun damage. They
are short-lived secondary projectiles, no fragment-to-fragment procs, no recursion,
and at most four per shell. Check projectile capacity before spending ammo;
reserve the complete projectile budget for the possible fragmentation.

The value is strong fire into moving groups without requiring a delayed reload
trigger. Rivet keeps its larger planted demolition payoff; Flak's cover splash
cannot pass a solid wall. Use dark steel splinters and the approved low dust blast.
The drum seats in both reloads; the empty version then feeds/racks the mechanism.
No late rack motion/audio for tactical reload.

### Anchor Engine

A salvaged magnetic anchor cartridge with retractable iron jaws. Hold/drag/release
uses the existing independent primary lobber distance model. On landing it plants
for1.05s, applying a bounded inward pull over the last.65s to ordinary mobile
bodies within190. At1.05s it crushes once for8 in165. At most two devices live;
three-second lifetime ceiling includes its residue. No live device can be silently
lost under decorative effect saturation.

Pull is displacement through CrowdOccupancy/moveActor, not teleportation. Cap each
body at55 units total per device; the strongest pull wins when devices overlap.
Bosses, nests and sentinels stay planted and receive only normal damage. Do not
pull the player, bullets, drops or other devices. A wide setup gives ordinary
enemies an escape, while dense packs reward the player. This is a heavy deliberate
launcher rather than another grenade inventory. Jaws clamp, iron debris converges,
then one dust/crush clip; no neon gravity orb. Empty reload resets the jaw feeder;
tactical reload swaps the cartridge without a full mechanism reset.

### Faultline Driver

A long industrial ground-driving cannon with a capacitor ram. Hold aim then release
one committed lane, clipped to cover. Three successive240-unit sections release at
0/.10/.20s after the shot. Every release has a corresponding planted material pose;
the sequence never tracks later joystick input. Each original attack can damage a
body **once**, including a body spanning a section boundary. Innate penetration is
capped at six distinct bodies. No secondary damage is generated for merely crossing
a visual crack and no floor hazard persists after the clip.

The value is predictable line clearing, especially against a frontal cluster. Sniper
keeps longer range and higher single-target damage; Rail keeps its charged projectile
identity. Upgraded range extends the same three bounded sections rather than adding
unbounded emitters. Reuse grounded stone/iron material; never paint a clean beam or
ripple a full-screen circle. Tactical reload seats the capacitor; empty reload also
returns/locks the ram. Preserve one common release coordinate system.

### Cyclone Breacher

A three-barrel rotating shotgun fed by a compact shell cassette. One primary
round spends one ammo and releases five pellets simultaneously. Rotation indexes
after each volley, never between pellets. Default cadence .50s gives12 raw close
DPS before range effects and reload; damage should fall off sharply beyond210
units. Keep centered spread, swept contacts and the existing per-target impact
cooldown. This is close-range power, not a ranged replacement for Frost.

Scattershot can raise the count to a **nine-pellet cap**, then tighten spread rather
than keep adding projectiles. Enforce full-volley capacity before ammo/audio.
Ordinary enemies can be shoved through the existing mass/occupancy system; no extra
freeze or immunity reset. Use broad pale metal pellets and low barrel smoke, not
bright sprays. Cassette seating works in both reloads; only the empty reload cycles
the feed/pump. Mechanically complete that distinction before adding cosmetic spin.

### Mourning Bell

A handheld iron resonator mounted in a firearm-shaped cradle; its clapper and
striker are tangible mechanical parts. A trigger commits a70° cover-respecting
pressure cone and marks up to five nearest valid target owners for .55s. Initial
hit4.5; an echo applies1.5 only to the originally marked bodies that remain inside
that original cone and clear cover. No homing echo, new-target acquisition, crowd
shove stacking or infinitely refreshed marks. Bosses count as one owner.

The value is strong area pressure that rewards timing movement through a pack.
Noises must be a short low mechanical strike and a restrained echo; no piercing
ringing synth or extra continuous audio voice. Render traveling low dust/material
notches with a short physical resonator vibration; no giant abstract music rings.
Tactical reload exchanges the resonator cartridge while retaining striker tension;
empty reload additionally resets the striker. Both follow the shared .70-duration
and final-action/audio rules.

## Weapon-weight model — implemented

Use one `WeaponMobility` contract keyed by weapon. Apply its multiplier **once**
to normal player walking intent after survivor/upgrade speed is derived, before
collision/occupancy movement. Keep GameState.movementSpeed as the survivor/upgrade
baseline. Do not mutate it on equipment changes, pickups or save restore. This
prevents compounding penalties, lost upgrades and stale Training weapon changes.

No ammunition-dependent mass, stamina meter, slowdown ramp, aim-stick drag or
additional reload penalty. Avoid making a heavy gun feel sticky when direction
changes. Maximum planned movement penalty is **7%**. Keep the current dash speed,
duration, cooldown, protection and wall/body constraints unchanged for every gun.
Emergency escape should remain dependable. Any later request to weight dash is a
separate balance change, not a hidden consequence of walking weight.

| Current weapon | Walk multiplier | Relative penalty |
|---|---:|---:|
| Pump Shotgun |1.00 |0% |
| Carbine |1.00 |0% |
| Revolver |1.00 |0% |
| Arc Caster |.99 |1% |
| Burst Rifle |1.00 |0% |
| Rail Lance |.96 |4% |
| Rivet Driver |.98 |2% |
| Cinder Hose |.96 |4% |
| Reaper Disc |.98 |2% |
| Scrap Mortar |.95 |5% |
| Belt-fed Repeater |.94 |6% |
| Frost Shotgun |.99 |1% |
| Prism Cutter |.97 |3% |
| Spore Lobber |.97 |3% |
| Longwatch Sniper |.97 |3% |

The six new multipliers are in their table. Rook300 becomes282 with Repeater and
279 at the heaviest proposed gun; Scrapper345 becomes324.3/320.85; Warden261 becomes
245.34/242.73. These are multiplicative on each survivor's existing speed, not extra
percentage-point deductions from Rook. Preserve Scrapper's+15% and Warden's−13%
character contracts. Speed upgrades and slows combine in the existing order, with
weapon weight applied once; test upper/lower bounds with allVIII upgrades.

Show a brief **Mobility −6%** stat in the equipped weapon details and assembled kit
summary when relevant. Do not expose invented kilograms or clutter the combat HUD.
Compare the same kit/arena during physical blind swaps; if a5–7% penalty discourages
large guns despite their payoff, reduce it before increasing raw weapon damage.

Native, server movement and local prediction must share identical multipliers and
ordering. Implement authoritative movement/prediction together; capability-gate
mixed versions so a locally faster estimate cannot rubber-band against the server.
Keep online lobby admission limited to actually supported weapons. All15 current
native weapons/new21-target coverage must be finished server-side before promising
online support. No server rollout is authorized by the existence of this plan.

## Art, reload and animation specification

For every new gun: transparent authored receiver, detachable feed/cell/cylinder and
closing mechanism; named measured body/grip/muzzle sockets; projectile, contact and
residue frames only where that class needs them. Separate normal and left/up/down
review views for all three survivors. Fix alpha-bound/pivot/muzzle alignment in
metadata; do not stretch generated anatomy or rotate root actors to fit the gun.
The twin-bore gun uses two measured ports on one receiver rather than a new survivor
pose system. Existing gait/arm contacts must be visually checked before accepting it.

Prepare a reload phase sheet for both modes: release/empty→remove/feed→seat→optional
empty-only closing action→ready. Mark the phase times consumed by sound and art.
The final action must be absent in the tactical clip, not merely its sound muted.
Ammo is granted only on complete reload; held aim cannot interrupt either mode.
Reduced Motion plants the parts while preserving progress, ready state and cues.

Use the new grounded floor/ordnance palettes, cloth/iron/copper and restrained glass
rather than recoloured generic circles. Projectiles remain legible at device scale.
Cap each selected gun+unique VFX decode packet at approximately220KiB, use existing
shared materials where possible, and measure **largest boss pair + selected packet**
against32MiB. Suggested starting budgets: receiver224×112, effect160×160. Lazy leases
must survive pending loads/restart/route disposal. Do not trade away readable art
merely to pass a memory assertion: revise packing/selection and inspect native output.

## Shared systems and caps

The six enum/data entries include their behavior and leased art packets. Update upgrade eligibility deliberately: Scatter/Ricochet mainly suit Twin
and Cyclone; Flak fragments, Anchor fields, Faultline sections and Bell echoes must
not inherit generic projectile duplicators blindly. Explicitly test Extended Tube,
fast reload, damage, range, pierce, fusions and utility-only grenade perks. Heavy
Payload continues to mean secondary grenade damage unless its scope is separately
redesigned; never apply it twice to a new weapon's internal explosion.

Retain swept contact/cover and common owner IDs. Reserve complete burst/pellet/fragment
capacity before spending ammo. Bound active fields, marked owners, hit ledgers,
secondary spawns, sounds and floor residue. A decorative FX cap may omit a cosmetic
cue but never discard a paid gameplay impact. Checkpoints contain finite committed
state, not a queued held aim or future duplicate attack. Old loadouts/profile unlocks
remain readable. Training Pause switching disposes old weapon intent/resources while
keeping the build/encounter as it does now.

## Delivery order and acceptance

1. Finish universal reload and sniper fatigue (the current implementation pass).
2. Implement shared mobility in isolation; prove native/prediction/server parity,
   existing-speed save compatibility and unchanged dash before adding any gun.
3. Twin Verdict and Cyclone: validate measured barrel ports, full volley accounting,
   tactical/empty clips and original-gun balance comparison.
4. Flak Regent: lock down complete fragment reservations and primary-owner exclusion.
5. Anchor Engine: prove occupancy-constrained pulls, planted bosses and overlapping
   field limits. Add save/restart tests before effects polish.
6. Faultline Driver and Mourning Bell: share committed area contracts, per-attack
   owner ledgers, warning/release timing and persistent bounded state.
7. Training exposes all21. Provisional normal unlocks:33/36/40/44/48/52 settled boss
   victories, preserving old progress; review the grind before finalizing. No added
   currency/premium store or changed challenge reward is assumed.
8. Full analyzer/tests and representative developed-build soaks. Compare weak packs,
   frontal shields, dense mixes, bosses, cover and poor positioning across all three
   survivors, both arenas, base andVIII builds. Record damage per reload cycle,
   valid hit count, movement separation and actual active-time survival.
9. Signed device candidate: mirrored/floating controls, aim cancellation, boundary
   landing, restart/Continue/background, Reduced Motion, speaker mix and repeated
   heavy-weapon swaps. Physical sprite contacts, comfort and performance are human
   gates; automated simulations/installation cannot approve them.

Accept a new gun only when a player can state its advantage in one short sentence,
its intended encounter is clearly stronger than its closest current alternative,
and its cost leaves useful reasons to choose the older guns. The final numeric
values and6–7% heavy penalties remain tuning proposals until that device review.
