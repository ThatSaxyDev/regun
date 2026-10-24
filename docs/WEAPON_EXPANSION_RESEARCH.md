# Weapon expansion research: finding room beyond Regun's 21

24 October 2026 · Research and design assessment.

**Subsequent decision:** the creator selected Houndrack, Storm Orb and Ring Caster.
Those three now have a mobile/admin/API implementation described in
[THREE_WEAPONS_REVIEW.md](THREE_WEAPONS_REVIEW.md). The recommendation below is
retained as the research-stage assessment; the blade cluster and remaining slots
have not been selected.

**Recommendation:** retain the creator's micro-rocket machine gun, and develop
three additional briefs around a traveling lightning orb, directly controlled
blade cluster and expanding/retracting cutting ring. Three other directions
deserve consideration with explicit reservations. The evidence does **not** yet
justify twelve implementation-ready weapons. Twelve additions remains the target;
the unfilled slots should remain open rather than repeat the rejected proposal.

## What was actually checked

This pass used external searches, extracted page content, developer weapon
announcements/patch notes and community mechanical references. Sources are linked
beside their claims. It also checked the actual21-entry `WeaponType` and the
native firing/flight, continuous-hit, committed-area, upgrade and drone paths.
Raw web extracts are retained locally under ignored `.firecrawl/regun-weapons-*`.

Developer descriptions establish intended mechanics; community references help
explain details but are not developer guarantees. Historical updates are identified
as historical. No popularity ranking, frame-by-frame video analysis, hands-on
comparative playtest, weapon balance certification or user playtesting is claimed.
No foreign game's damage/ammo values are treated as transferable to Regun.

The earlier roster was a speculative design pass without external research. Its
eleven unwanted concepts and the slow Houndrack tuning are withdrawn. The new
micro-rocket direction comes from the creator, not from this research.

## 1. Regun's occupied design space

The comparison must include built-in behavior **and** ordinary builds. A weapon
that merely adds an already offered ricochet, burn, chain or drone effect is weak
evidence of a new identity.

| Current primary | What the player already does / gets |
|---|---|
| Pump Shotgun | Aim immediate close spread; three centered pellets and shell reload |
| Carbine | Track with responsive sustained straight rounds |
| Revolver | Place immediate heavy single rounds between deliberate gaps |
| Arc Caster | Hit one body to start inherited electrical chain jumps |
| Burst Rifle | Track through three separately released rounds |
| Rail Lance | Aim through charge or release early; penetrate a narrow queue |
| Rivet Driver | Plant bounded host payloads, then detonate through reload/expiry |
| Cinder Hose | Sweep an advancing short flame cone and apply burn |
| Reaper Disc | Send out a physical blade and position for its return pass |
| Scrap Mortar | Choose distance and lead a delayed ground blast |
| Belt-fed Repeater | Stay firing through spool-up and accelerating sustained output |
| Frost Shotgun | Connect a spread to freeze pursuit and create escape time |
| Prism Cutter | Hold a clipped beam on the nearest intercepted body while managing heat |
| Spore Lobber | Place bounded, nonstacking damage/slow patches in pursuit routes |
| Longwatch Sniper | Deliberately release a precise long-range piercing round |
| Twin Verdict | Brand, then alternate barrels for a focused shatter/fork payoff |
| Flak Regent | Land/terminate a shell and fan four secondary fragments forward |
| Anchor Engine | Place a device, gather movable bodies, then crush |
| Faultline Driver | Release a committed ground lane with three timed sections |
| Cyclone Breacher | Track with fast heavy close-range pellet volleys |
| Mourning Bell | Strike a committed cone; echo against original owners who remain |

Local evidence: `lib/data/loadout.dart`; `lib/systems/arsenal_system.dart`
(`releaseAim`, `_rounds`, `_continuous`, flight processing);
`lib/systems/endgame_arsenal.dart` (Flak, Anchor, lane and echo);
`lib/notifiers/game_notifier.dart` (`weaponSupportsPowerUp`, eligibility);
`lib/systems/combat_system.dart` (chains, kill effects, autonomous drone);
`lib/data/weapon_power_balance.dart` (pinned balance revisions).

The current code makes several naive additions redundant: freeze is not an empty
slot, heat is not an empty slot, reload detonation is not an empty slot, and a
slow orb that only pulls then explodes would compete directly with Anchor.

## 2. What the references establish

These are observed reference mechanics. Regun adaptations below are separate
design recommendations.

| Reference / source quality | Verified observation | What it helps us examine |
|---|---|---|
| **Deep Rock Galactic, Hurricane** — developer teaser plus community-maintained equipment reference | Hurricane is a guided rocket primary. Its Rocket Barrage variant exchanges guidance for a much denser stream. | Continuous rocket output and guidance are separate design dimensions. The creator's combination need not copy either variant wholesale. |
| **Nuclear Throne, Lightning Cannon** — developer Update30 and community guide | The developer specifically describes situations where a miss can outperform direct contact. The guide describes a slow orb emitting nearby lightning before impact. | A shot can deal its useful damage while passing a pack, rather than only after hitting its first body. |
| **Gunfire Reborn, Thunder Storm** — developer October2023 notes | Its revised primary launches an electrical orb that emits nearby arcs and explodes on impact. | A second independently documented example of the traveling damage-emitter archetype. |
| **Gunfire Reborn, Cloud Weaver / Hexagon** — developer August/September2022 notes | Cloud Weaver launches controllable spikes. Hexagon couples a blocking shield to a retaliatory shot; later notes adjust both behaviors. | Persistent player control and a defensive attack cycle are real alternatives to ordinary rounds. |
| **Gunfire Reborn, Star Ring / Jet Octopus** — developer June2023 introduction, with later correction | Star Ring expands/contracts. Jet Octopus absorbs energy from enemies. October2023 notes remove Star Ring's former maximum-radius contraction bonus. | Spatial radius control and enemy-fed resources; also why an old wiki number cannot be copied uncritically. |
| **Enter the Gungeon, Black Hole Gun / Particulator / BSG** — player-maintained wiki | These cover attraction, a splitting homing projectile and a charged large-area weapon respectively. | Distinct in their source game does not automatically mean distinct in Regun. |
| **Roboquest, Boomerang / Rapier** — developer Arsenal preview, April2024 | The preview describes a stronger return pass and precision melee respectively. | Boomerang is already close to Reaper; importing every distinctive source-game weapon would duplicate existing roles. |
| **Borderlands3, Tediore** — original concept artist and community mechanical reference | The artist explains throwable-reload gun design. The reference details disposable and autonomous reload forms. | Reload can deploy something tangible rather than just change damage or refill ammo. |
| **Real hardware, XM25 / SAGM** — historical US Army material,2009–2014 | The distinctive purpose is engaging defilade using airburst; the Army distinguishes direct and indirect approaches. | The real tactical capability matters more than the name or explosive visual. This is historical design evidence, not a present-day service-status claim. |

Sources for the observations above:

- [Ghost Ship Games: Hurricane teaser,27 October2021](https://www.youtube.com/watch?v=f8MZhstUldE)
  — developer description retrieved; no claim of watching/analyzing the footage.
  [Hurricane equipment reference](https://deeprockgalactic.wiki.gg/wiki/%22Hurricane%22_Guided_Rocket_System)
  — player-maintained detailed mechanics, including the unguided Rocket Barrage.
- [Vlambeer: Nuclear Throne Update30](https://steamcommunity.com/games/nuclearthrone/announcements/detail/1280459995929129826)
  — historical developer design description;
  [In-Depth Nuclear Throne Guide: energy weapons](https://idntg.com/weapons#energy)
  — community explanation, including version-specific caveats.
- [Gunfire Studio:2022 weapon introductions and subsequent corrections](https://store.steampowered.com/news/posts/?appids=1217060&enddate=1668744036&feed=steam_community_announcements)
  — Cloud Weaver and Hexagon, including hit-attribution/control fixes.
- [Gunfire Studio:2023 introductions and October revisions](https://store.steampowered.com/news/posts/?appgroupname=Gunfire+Reborn&appids=1217060&enddate=1700278227&feed=steam_community_announcements)
  — Thunder Storm, Star Ring and Jet Octopus. This archive contains multiple dated
  entries; the later Star Ring correction supersedes its introductory bonus.
- [Enter the Gungeon: Black Hole Gun](https://enterthegungeon.wiki.gg/wiki/Black_Hole_Gun),
  [Particulator](https://enterthegungeon.wiki.gg/wiki/Particulator),
  [BSG](https://enterthegungeon.wiki.gg/wiki/BSG)
  — player-maintained references despite the site's official-wiki branding.
- [RyseUp: Roboquest Arsenal preview, April2024](https://store.steampowered.com/news/posts/?appids=692890&enddate=1713186496&feed=steam_community_announcements)
  — developer-described return/melee behavior.
- [Kevin Duc: Borderlands3 Tediore concept art](https://www.artstation.com/artwork/rRyKy5)
  — contributing artist's own design explanation;
  [Tediore mechanical reference](https://borderlands.fandom.com/wiki/Tediore)
  — community documentation; no claim that all modules occur on every gun.
- [US Army: XM25 demonstration,2010](https://www.army.mil/article/38768/xm25_lets_soldiers_eliminate_targets_they_cant_see),
  [Picatinny: SAGM and XM25 distinction,2014](https://www.army.mil/article/133029/Enhanced_grenade_lethality__On_target_even_when_enemy_is_concealed/)
  — institutional historical primary sources.

## 3. Working selection filter

This is our design judgement, not a published scientific scoring system. For each
candidate, describe:

1. **What the player controls:** heading, range, an in-flight object, a radius,
   setup location, or an attack/defense phase.
2. **Where damage lives:** a contact point, line, fixed patch, moving field,
   controllable cluster, ring edge, or autonomous deployed body.
3. **When useful damage happens:** immediate hit, passage, return, sustained
   contact, interception, or reload deployment.
4. **Why equip it instead of its nearest existing gun**, including an encounter
   where that nearest gun remains preferable.
5. **Whether it survives Regun's controls and arena:** one primary aim stick,
   independent grenades, open Breach, limited cover, crowds, planted bosses,
   bounded resources and readable material effects.

A minor accuracy ramp or shield damage modifier may be a valid weapon variant,
but does not meet the creator's requested level of distinction for this expansion.
Art and sound must reinforce a clear mechanic, not compensate for its absence.

## 4. Four strongest directions

These pass the paper comparison. They are candidates, not playable evidence.

### A. Micro-rocket machine gun — Houndrack

**Creator's direction:** a machine gun of tiny rockets, mildly targeting one enemy.

**Regun proposal:** hold primary aim for rapid individual mini-rockets. Keep
manual aim important: a stream biases toward the enemy being aimed at, rather
than distributing itself automatically over the crowd. Each rocket visibly
accelerates from the rack with short exhaust, limited curvature and a small
impact. Changing deliberate aim changes the acquisition for later launches;
existing rockets retain their own committed acquisition. Dead targets do not
trigger endless searching. No orbiting, U-turns, through-cover hits or full-screen
smoke. Rocket volume, acceleration and delayed arrival should be recognizable
before a damage number is seen.

**Nearest comparisons:** Carbine/Belt give immediate straight pressure; Flak bursts
into forward fragments. Houndrack instead produces a stream of separate propelled,
slightly correcting impacts. Its downside is delayed arrival and damage wasted on
rockets already traveling toward a dying target. Tiny blast splash is an open
design choice, not assumed to be a full grenade per rocket.

**Reference use:** borrow neither Hurricane's unrestricted crosshair guidance nor
Rocket Barrage's loss of guidance literally. Their documented difference helps
separate the creator's two requested features. The exact homing relationship is
our proposed touch adaptation. No fixed magazine/rate/damage seed is chosen yet.

**First proof:** actual mini-rockets must look and respond differently from yellow
Carbine bullets, while remaining comfortable against fast lateral enemies and
cover. Test retarget/death waste and simultaneous-flight limits before tuning DPS.

### B. Traveling lightning orb

**Player promise:** fire a slow electrical ball alongside a formation and let its
passing arcs rake the pack before it ends in a compact discharge.

**Regun proposal:** a bounded moving orb owns a local damage radius for a finite
flight. Passing near enemies is useful; an early body collision ends that useful
travel. Aim into a gap beside a pack to extend exposure. Walls stop the orb and
also occlude arcs. Per-owner tick gates and a total hit budget prevent a boss or
dense overlapping bodies from receiving per-frame damage. No attraction, frozen
floor patch, screen-wide lightning or repeated acquired-primary proc trees.

**Why it differs:** Arc first hits a body, then chains from that hit. Anchor
plants, gathers and crushes. This weapon damages **during its moving passage**
without pulling anything. A gap can be a better aim point than the nearest enemy.
Arc remains better for immediate connected targets; the orb rewards pack motion
and route judgement. It fails the distinction test if it becomes an Arc projectile
with a larger on-hit chain or merely an Anchor with electrical art.

**References:** Nuclear Throne's developer-described near-miss payoff and Gunfire's
documented Thunder Storm primary provide the behavioral starting point. Their
exact damage, wall destruction and screen effects do not carry into Regun.

**First proof:** compare a direct hit versus a deliberate pass beside three moving
enemies. Both outcomes should be visually understandable without tutorial prose.

### C. Directly guided blade cluster

**Player promise:** launch a compact formation of blades, then steer that active
formation through enemies with the aim stick while the survivor keeps moving.

**Regun proposal:** primary hold maintains one short-lived controllable cluster.
Aim direction steers its travel with limited turn rate relative to the survivor;
it does not require a mouse cursor or teleport to an aim point. Finite reach,
active duration and contact cadence make this a weapon commitment, not a permanent
companion. Releasing/canceling ends control with a clear bounded return/cleanup
policy; lifecycle cancellation cannot leave it killing unattended. Distinct
blades share owner/tick limits and current solid geometry.

**Why it differs:** Reaper has outbound/return legs; its player positioning affects
the return route, but it is not a continuously steered formation. The existing
drone acquires its own target; this weapon requires deliberate steering. Houndrack
slightly corrects launched rockets automatically; this requires ongoing manual
control of a limited group.

**References:** Cloud Weaver establishes the controllable-spike family. Gungeon's
Remote Bullets reference documents a controller-specific trap: directional-stick
control is not equivalent to placing a mouse cursor. That warning argues for an
early touch prototype rather than importing PC control verbatim.

**First proof:** steer while dodging with the movement thumb and using independent
grenade aim. If the cluster feels like wrestling the controls, revise this slot;
do not turn it into another auto-targeting drone and call it solved.

### D. Expanding / retracting cutting ring

**Player promise:** push a ring of cutting elements outward, then pull it back
through surrounding enemies. Fight by managing the cutting edge's radius.

**Regun proposal:** primary hold expands the ring; release retracts it. The edge
is the damaging region, with one bounded crossing allowance per owner per phase;
the interior is not a filled-damage circle. Player movement changes how the edge
crosses a formation, while cover clips damage and visible segments consistently.
Use segmented physical blades or material energy cutters, rather than a generic
hostile warning outline. It consumes primary resources and has a real ready/reload
cycle; no permanent protective ring or continuous contact immunity.

**Why it differs:** Bell commits a forward cone and revisits original owners.
Reaper returns one blade along a route. This uses a player-centered perimeter
with independently controlled extent and a vulnerable inner pocket. It fails if
implemented as an instantaneous radial explosion or merely a stationary aura.

**Reference:** Star Ring supplies the expansion/contraction concept. Mapping its
separate controls to hold/release and adapting the damage to top-down cover are
our recommendations. Do not inherit the removed historical maximum-radius bonus.

**First proof:** the ring edge, empty interior, crossing hits and release behavior
must be immediately legible on both arenas, including Reduced Motion and large
crowds. Reject visual resemblance to enemy attack warnings or upgrade recovery.

## 5. Three conditional directions

| Direction | Concrete proposal / reference basis | Main reservation and proof needed |
|---|---|---|
| **Counterfire cannon** | Hold a short-lived frontal interception panel; release one bounded retaliatory shot. Hexagon is the documented reference. | This changes defense, not just gun damage. Must not grant global invulnerability or turn sustained fire into free defense. Ordinary projectile interception only as an initial design; contact, floor hazards and lasers remain threats. It also needs a useful baseline shot in melee-heavy encounters without requiring a new action button. |
| **Disposable sentry receiver** | An aimed reload ejects a small receiver that briefly fires from its landing point while a replacement is fitted. Tediore reload forms and Roboquest Buddybot illustrate deployment. | Rivet already gives offensive value to reload; the drone already attacks autonomously. It earns a slot only through actual ground placement/crossfire. One bounded deployment, finite carried payload and cover dependence; repeated one-shot reloads and Extended Tube must not print free turrets. Strong art/reload scope. |
| **Enemy-fed pressure weapon** | Hold to extract bounded energy from nearby enemies; release the collected pressure as a physical forward discharge. Jet Octopus supports the enemy-fed-resource direction. | Extraction is an energy mechanic, **not evidence that the reference physically pulls enemies**. Pulling bodies would duplicate Anchor. Avoid making it just Cinder's cone plus a larger last shot. It needs a clear resource/two-stage loop and a boss-safe fallback without modifying other guns' reload rules. |

These are not automatic roster additions. Distinction, controls and defensive/
resource consequences must pass review before they become implementation tasks.

The controller warning comes from the
[Remote Bullets mechanical reference](https://enterthegungeon.fandom.com/wiki/Remote_Bullets).
The ground-deployment example is described in
[Epic Games Store's Roboquest guide](https://store.epicgames.com/cs/news/roboquest-become-a-robot-legend-with-these-tips-and-secrets).
Both are supporting references, not developer performance/balance guarantees.

## 6. Screened out or deferred

| Researched family | Nearest Regun overlap | Decision for this expansion |
|---|---|---|
| Black-hole / singularity gun | Anchor's gather/crush | Reject as a separate slot unless its core behavior changes substantially; a darker orb is insufficient. |
| Boomerang / returning saw | Reaper's two-leg cuts | Reject. Roboquest's return bonus does not create missing design space here. |
| Poison/acid puddle launcher | Spore's persistent damage/slow patches | Reject simple elemental substitution. |
| Freeze beam / ice automatic | Frost plus existing continuous-fire models | Reject merely changing delivery and color. |
| Charge sniper / railgun | Rail and Longwatch | Reject another charged piercing damage package. |
| Heavy frontal armour-breaker | Revolver, shotguns and existing armour/pierce distinctions | Withdraw Gatecrasher: a shield multiplier alone is not compelling enough. |
| Accuracy-ramping SMG | Carbine/Belt sustained aiming | Withdraw Needle Loom: insufficiently different in ordinary use. |
| More automatic chain lightning | Arc and Static/Conductive upgrades | Reject; traveling-orb passage damage is the specific distinction worth testing instead. |
| Homing submunition pod | Flak fragmentation + Houndrack's homing | Defer. Particulator is distinctive in Gungeon, but this looks like combining two occupied Regun behaviors. |
| Large charged plasma blast / BSG-style clear | Rail charge + Mortar/Flak blast | Defer. Size and a screen-wide payoff do not justify overriding open-arena cover/readability. |
| Airburst launcher | Mortar/Flak and independent grenade placement | Defer. Historical XM25/SAGM purpose is attacking defilade. Regun would need an explicit low/high-cover and overhead-flight design to gain that purpose; merely bursting early recreates the rejected Fusewheel. |
| Wide traveling plasma line | Faultline's committed lane | Defer. A real moving transverse cutter could differ, but must prove more than a wider lane with different art. |
| Mine/trap primary | Sprint Mine, independent grenades, Spore/Anchor placement | Defer. A tripwire needs player enthusiasm for trap setup; it cannot be treated as desirable because it is technically different. |
| Death-seed/contagion gun | Rivet payloads, Shrapnel/Accelerant kill effects | Withdraw the previous Injector concept until a stronger independent play pattern exists. |

This screening is a design inference from the source mechanics and current Regun
code. It is not a claim that those weapons are poor designs in their own games.

## 7. What the research changes about our process

The first proposal went directly from an idea to a name/stat table and detailed
implementation. The revised order is:

1. **Behavior brief:** plain archetype, what is seen on screen, player action,
   nearest current gun, useful situation and tradeoff. No themed naming exercise
   or fixed stat table until that comparison holds.
2. **Control/geometry proof:** first Houndrack, orb, guided cluster and ring. Test
   the exact new interaction before producing all twelve sprite packets. These
   are the next design/prototype candidates, not an instruction to implement now.
3. **Creator review of the actual promise:** concept comparisons followed by
   short real-renderer clips when implementation is authorized. Numbers and asset
   polish cannot rescue a rejected play pattern.
4. **Complete production packet:** once a direction is accepted, follow the
   existing expansion guide: source masters, measured sockets/parts, timed reload,
   sound, impacts, resource HUD, upgrades/passives, saves and catalogue/access.
5. **Balance and acceptance:** compare effective output and escape options across
   current baseline revisions, all survivors, enemies/bosses and upgrades. Keep
   existing native/online admission, source-owned procs, geometry and lease budgets.

No new prices, boss thresholds, power tier, live-balance publication, installation,
new online admission or weapon implementation is authorized by this research.
The existing21 remain the reference. The previous8-earned/4-shop split is withdrawn.

## 8. Result and remaining uncertainty

There is a defensible starting set of **four distinct briefs**, of which only
Houndrack has explicit creator interest, plus **three conditional ideas**. The
other five requested slots are intentionally unfilled even if all three conditional
ideas survive. If they do not, more than five slots remain open. Filling the target
requires further concept selection, not pretending research has validated twelve.

All seven still need judgement about desirability. Touch steering, ring clarity,
counter-defense fairness and autonomous deployment are the biggest uncertainties.
Source descriptions establish precedents; they do not establish that these will
feel good in Regun. That distinction is the reason for the earlier, smaller
behavior-review gate in the revised plan.
