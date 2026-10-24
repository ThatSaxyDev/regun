# Airdrop-only rewards: Sentry Gun and Aura Farm

24 October 2026. **Proposal only: neither reward is implemented.** No gameplay,
API, admin catalogue or art/audio generation is authorized by this document.
The separately requested title-spacing and existing airdrop-navigation fixes are
implementation work; they do not enable these proposed rewards.
Numbers below are starting playtest values, not measured final balance.

## Intended experience

An airdrop can grant a short-lived battlefield advantage that ordinary XP cannot
buy. Sentry Gun anchors a position with automatic ballistic fire. Aura Farm moves
with the survivor and damages enemies that approach. Both create a meaningful
window of power and then expire; neither replaces the player's primary weapon.
They coexist with permanent upgrades, including Orbit Drone.

The creator's placement clarification is part of the design: selecting a sentry
starts **SENTRY GUN INCOMING**, rather than immediately dropping a gun at the
selection position. Moving during the countdown influences where it will land.

## What the current game actually does

- Breach owns the timed supply objective. First arrival is 22–32 active seconds;
  subsequent scheduling is 55–80 seconds after cleanup. Capture radius is 260,
  capture time eight seconds, usable life 50 seconds. Foundry and Boss Rush do
  not currently have normal airdrops. Keep that arena scope for this delivery.
- `GameNotifier.offerSupplyUpgrade()` currently calls the same offer roller as XP.
  It spends no XP/level and retains unique choices, bans/rerolls and prompt grace.
  There is no airdrop-only reward type, temporary reward tier or deployable turret.
- `SupplyDrops` has warning → falling → active → opened → breaking phases.
  Current landing AND breakdown cause a friendly impact: ordinary enemies are
  crushed within 62 units plus body radius; bosses there receive 3% maximum HP;
  an additional 8-damage blast reaches 205 units, with 130 units of outer pressure.
  Cover/vulnerability apply; no player damage or Fragmentation shards are added.
- Active/opened supply pods are solid 92×52 cover. Their footprint disappears
  when breaking starts. New deployables must participate in geometry/routing,
  not merely draw over enemies and projectiles.
- Orbit Drone is an existing permanent moving companion, striking periodically
  within 600 units and supporting Targeting Link/Hunter Swarm. Making Sentry
  another permanent orbiting companion would duplicate that role.
- Current mounted-weapon candidates are Carbine (0.9 damage, .10s cadence,
  24 rounds, 1.8s reload, 950 speed) and Burst Rifle (1.25 damage per round,
  three rounds .10s apart, .60s burst-start interval, 18 rounds, 2s reload,
  1100 speed). Values come from the run's pinned weapon snapshot.
- Online co-op has two or three players. Each participant receives a supply
  receipt; the server owns choices and combat. The ordinary upgrade rank system
  is I–VIII and has six special slots: temporary rewards should not silently
  consume those slots or adopt those scalar curves.

Grounding: `lib/systems/supply_drops.dart`, `lib/game.dart` (`landSupplyDrop`,
`_impactSupplyDrop`), `lib/notifiers/game_notifier.dart`,
`lib/systems/upgrade_offer_policy.dart`, `lib/systems/combat_system.dart`,
`lib/systems/burst_fire_clock.dart`, `lib/data/loadout.dart`,
`lib/data/weapon_power_balance.dart`, plus sibling server `progression.ts`,
`supplies.ts`, `survival_runtime.ts` and `weapon_specs.ts`.
The latest supply contract is [COMBAT_RECOVERY_AND_SUPPLY.md](COMBAT_RECOVERY_AND_SUPPLY.md)
and the 23 October breakdown follow-up in [REGUN_PROGRESS.md](REGUN_PROGRESS.md).
Older airdrop documents contain superseded capture/impact/cover values.

## Obtaining rewards and higher versions

Recommended first version:

1. Each supply menu reserves **one of its three cards** for an eligible temporary
   reward. The other two retain normal upgrades. XP/fusion menus never draw these
   rewards. If no temporary reward is eligible, show three ordinary choices.
2. Roll Sentry Gun or Aura Farm with equal initial family weight. Use recent-offer
   suppression to reduce repetition. Sentry has Carbine and Burst variants; roll
   the mount inside the selected family, so two mounts do not double its odds.
   The actual card states the mount, tier, lifetime and damage BEFORE selection.
   Selecting it immediately confirms that exact variant; no second modal.
3. Keep three explicit versions, I–III, per family for the current run. The first
   selection deploys I; later selections deploy II, then III. At III a later
   pickup deploys III again, clearly labelled **Deploy again**, without increasing
   rank. There is never a permanent damage field left running after expiry.
4. One incoming/live sentry and one active Aura Farm per owner. The same family
   is ineligible while incoming, deploying, active or breaking. No stacking,
   replacement explosion or duration refresh through repeated selection. Both
   families may coexist. Repeated tier-III deployment remains useful after expiry.
5. Reroll preserves the supply-only slot rule. Ban excludes the whole family,
   including both sentry variants, for this run. Use existing reroll/ban currency.
   Ordinary XP rolls must never acquire one through ban replacement or fallback.
6. Tier progress resets on a new run and persists through Continue. It lives in
   separate temporary-reward state, outside special slots, eight-rank upgrades,
   fusion prerequisites and Lucky Find's permanent-special weighting.

This preserves airdrops' current permanent-upgrade value while giving every
eligible drop a visible exclusive choice. An all-exclusive supply menu can be
considered later when there are enough distinct families; two families should
not produce three near-duplicate cards now.

## Sentry Gun: placement and lifecycle

Proposed incoming time: **six active seconds**, editable in admin with a readable
minimum. Exact timeline after the picker closes:

| Time | Behavior |
|---|---|
| 0–3.55s | INCOMING countdown. A compact friendly landing stencil follows the nearest legal ground point at the player's feet as they move. No falling object, solid body or damage yet. |
| 3.55s | Lock the visible landing point. Brief confirmation cue; marker changes to planted warning. Player can step away. |
| 3.55–5.35s | 1.8s committed landing warning, matching the established airdrop anticipation. The point stops following the player. |
| 5.35–6s | .65s accelerating descent. Shadow and descending chassis agree with the locked point. |
| 6s | One landing impact using the current supply-impact profile. Feet plant; solid base becomes active. A player caught underneath is safely displaced, never damaged. |
| 6–6.55s | .55s braces/head deployment. The gun rises, turns and settles before firing. |
| Next 24/30/36s | Live targeting, magazine cycles and firing. Lifetime advances even when idle, blocked or offscreen. |
| Expiry | Stop firing, remove solid cover, one supply-profile breakup blast, then 1.3s collapsing panels/dust and removal. No blast when restart/disposal merely clears the unit. |

The countdown displays true remaining time until impact, including descent, not
an extra hidden delay after zero. A small HUD status and world stencil share the
same simulation clock. When the survivor stands still the candidate holds still;
there is no placement joystick. Placement follows ground position, not weapon aim.
The existing upgrade recovery pulse remains separate and occurs only once.

Validate walkable footprint, arena bounds, source pod, other sentries and route
clearance. A blocked candidate projects to a nearby legal point, visibly; it must
not silently jump across the arena. Preserve at least 160 units between turret
bases. If none is legal at lock time, retain the paid incoming entitlement, show
**Finding drop zone**, retry a bounded candidate search every .5s, and restart the
full planted warning once valid. Do not consume the reward without deploying it.
Once committed, do not retarget to chase the player or avoid enemies intended to
receive the impact. Reserve the committed footprint against new solid placement.
Enemies/players may still move through a warning; overlap at impact uses the
existing displacement/crush contract. Incoming units count against owner caps.

The sentry stays where it lands; it does not follow the player. For the first
version it expires by battery time and is not an additional enemy-health target.
Register its solid planted footprint in the shared temporary-cover geometry so
normal enemies automatically use the same tested routing and body-slide path as
the pod. Do not add a sentry-specific steering bypass. Its footprint is proposed
at roughly 70×44, anchored to final art;
validate this with actual feet and corridor routing before freezing the value.
Its own muzzle must be outside its own cover; other cover continues to block.

## Sentry Gun: targeting, firing and balance

| Setting | Carbine mount | Burst mount |
|---|---|---|
| Tier-I base damage per round | 0.9 | 1.25 |
| Trigger pattern | One round each .10s | Three real rounds, .10s apart; bursts start each .60s |
| Magazine / reload | 24 / 1.8s | 18 / 2s |
| Acquisition radius | 550 | 650 |
| Projectile speed | 950 | 1100 |
| Damage multipliers I / II / III | 1 / 1.15 / 1.30 | 1 / 1.15 / 1.30 |
| Working lifetime I / II / III | 24 / 30 / 36s | 24 / 30 / 36s |

Mounted weapon damage/timing/magazine/speed are read from that weapon's pinned
base configuration, even if the player holds a shotgun or another gun. It does
not copy the player's current upgraded shot, survivor damage multiplier, pellets,
ricochets, final-shell/reload bonuses or procs. At I the base round therefore
matches the corresponding player weapon before those bonuses. Later versions
scale only the documented sentry multiplier. Preserve the source weapon's
ballistic distance curve, sampled from the sentry muzzle; Burst is currently flat.
Acquisition range is capped by the configured source weapon range.

Fire-only upper bounds at I are 9 HP/s for Carbine and 6.25 HP/s for Burst before
distance factors. These exclude reload, travel, rotation, missing, cover and
idle time; they are not promised sustained DPS. The Burst's longer acquisition
range distinguishes it from the higher-volume Carbine. Exact active-time damage
must be measured using the implemented release/reload clocks before balancing.

Target nearest living enemy with clear cover sight, from the turret. Query at
10Hz rather than rebuilding/sorting every render frame; retain the current target
for at most .25s to prevent jitter, then compare nearest again. Invalid/dead/
covered/out-of-range targets release immediately. Respect boss vulnerability and
body/weak-point ownership; do not let one round hit a boss twice.

The head rotates continuously on the shortest turn at a proposed 300°/s, with
360° mechanical coverage. Fire only within 6° of its target. Rounds leave the
animated muzzle along its actual heading and travel physically; no homing or
hits through walls. A burst retains one target but cancels remaining subshots
when it dies/becomes invalid; it must not spray three simultaneous pellets.
Reload/turn can overlap; firing never bypasses an unfinished reload.

Use a support-ballistic damage classification: no primary hit/release procs or
knockback pinning, but Shield Warden's directional armour still applies. Today's
`primary:false` alone bypasses that armour branch, so blindly reusing it would
be a gameplay bug. Support kills use normal owner-attributed XP/score/death;
existing global kill rewards may apply with their normal caps, not twice.

**Impact is part of the budget.** The sentry adds two full supply impacts on top
of the source pod's existing impacts. If a boss occupies both inner circles,
that is an extra 6% maximum HP plus up to 16 flat blast damage, before cover and
vulnerability, even without gunfire. Ordinary inner-circle targets can die
instantly. Start with the requested matching profile; do not quietly add grenade
upgrades, Fragmentation or multiply that percentage by sentry tier. No manual
recall/replacement can farm these blasts. Balance review must log bullet damage,
inner crush and outer blast separately.

## Aura Farm

Selecting it starts a short .35s readable activation around the survivor, then a
finite moving damage field. No falling pod, second capture or explosion is added
unless separately requested. A small emitter visual travels with the survivor.

| Tier | Lifetime | Radius | Damage per .25s tick | DPS per continuously exposed enemy |
|---|---|---|---|---|
| I | 18s | 135 | .30 | 1.20 |
| II | 22s | 145 | .375 | 1.50 |
| III | 26s | 155 | .45 | 1.80 |

The field intersects actual enemy bodies and respects solid cover from player
ground center. Damage uses fixed active-time ticks, not frame count, re-entry or
number of sprites. Leaving and entering between ticks does not grant extra
hits. It follows the authoritative survivor position; dash creates no damaging
trail or swept corridor. At most 12 nearest valid owners are damaged per tick;
weak points never duplicate their owner's damage.

No slow, stun, projectile deletion, healing, invulnerability or primary proc is
bundled into the field. Bosses use normal vulnerability/area-damage rules.
At I, an unscaled 2-HP Skitter needs about 1.7 seconds of continuous exposure;
contact remains dangerous. For comparison the existing Spore Lobber patch has
2.4 base DPS and 150 radius but is planted and short-lived. Aura's weaker moving
DPS and finite uptime should make it useful without becoming a safe walking kill
zone. Enemy cycle health still scales; no automatic hidden percent-health damage.

One aura per owner. In co-op overlapping allied fields deal only the strongest
eligible aura tick to a given enemy, using a shared tick phase and deterministic
owner tie-break. It is still useful to spread out. No friendly/player damage.
Low ticks reuse normal death/reward attribution; no burn, chains or shrapnel loops.
On expiration the emitter winds down and field fades; no last damaging tick after
its lifetime and no explosion. Downed/dead-owner effects are suspended; no damage
or duration advance while owner recovery freezes their combat. Ordinary death/
run end clears them, while co-op disconnect cleanup removes orphaned support.

## Animation, art and sound acceptance

Sentry needs a new authored grounded chassis/mast with separate rotating head,
not a carbine sprite hovering over a box. Reuse the actual Carbine/Burst identity
and muzzle socket, with a deliberate mount/pivot. Establish front/back depth
relative to mast, contact shadows and recoil direction for every heading. Root
geometry stays planted while only the head turns. Show braces unfolding, mast
lift, small settling weight, bounded barrel recoil and magazine/feed motion.
Near expiry use three steady battery segments and a brief motor wind-down, then
material blast and chassis breakup; never a generic glowing circle substitute.

Before runtime implementation, review a storyboard of incoming → falling →
planted/unfolding → tracking across all quadrants → firing/reload → breakup.
Produce final gameplay-sized art and mobile-size previews, not only enlarged
concepts. Generate new bitmaps only in the later approved implementation phase.
Use the existing art pipeline, acquire/release leases and cancellation guards.

Aura uses a low-opacity material field beneath actors, a distinct friendly edge
and sparse damage wisps touching accepted targets. It must stay recognisable
while moving without hiding leap/claw warnings, boss safe pockets or floor fire.
The collider is circular but the effect must read as a textured energy field,
not a flat translucent disc. Reduced Motion holds the texture steady, removes
rotation/descent/bounce extras and retains all timing/footprint information.

Audio: incoming confirmation and lock cue, supply landing/breakup family,
restrained servo on substantial turns, distinct lower-gain mounted firing,
reload and shutdown. Servo cues are rate-limited, not played every heading update.
Aura has a short activation/expiry tone and bounded accepted-hit accents; avoid
one constant loud drone or one voice per victim. SoLoud mute/volume/lifecycle
remain authoritative. Test with music, player firing and boss cues together.

## Shared mobile, API, admin and online contracts

Create explicit reward-source/type metadata (ordinary XP, supply, fusion and
Training practice), separate I–III reward progression, and a serializable
support runtime. Offer IDs include reward family, tier and sentry mount. Selection
must validate its original source and exact issued card; a client-sent reward ID
must never grant an airdrop item from XP. Keep existing funded-XP/grace rules.

A dedicated **Airdrop rewards** admin section shows both identities with actual
art and tier tables. It exposes enabled state and bounded numeric controls for
family weight, duration/damage by tier, sentry incoming time/acquisition/turn rate,
and aura radius/tick/target cap. Carbine/Burst base numbers display as linked
read-only source weapon values; source-weapon edits intentionally affect future
sentry deployments in future pinned runs. Do not provide a second independent
copy of those values. Shared impact values display as the inherited supply
profile, with both landing and expiry explicitly explained.

Enable flags must be typed validated fields with the custom admin selector;
this introduces no remote code or generic Material switch. Enforce increasing
tiers, warning/descent fitting inside incoming time, bounded cadence/target counts,
and acquisition <= source range. Offer membership, caps, proc tags and supported
modes are code contracts, not arbitrary editable JSON. Keep historical catalogues
and archive/rebase incompatible drafts through the existing machinery.

Use generated shared definitions and a pure Dart/TypeScript component projection
for tier damage, arrival phases, coverage, shot pattern and uptime. Add an
authenticated support preview alongside current weapon/rank previews; do not label
ceiling DPS as guaranteed output. Publish/rebase/revision/auth work through the
existing pipeline. A new run pins the entire configuration; Continue and rooms
retain theirs. Missing fields in old saves mean no support active, not a free
spawn. Old outstanding supply menus finish with their original ordinary offers.

Native saves persist family tiers, pending incoming reward, current candidate/
locked position, phase clock, heading/target ID, ammo/reload/burst phase, remaining
life and once-only landing/breakup receipts. Restore into pause, never catch up
wall-clock time or repeat blast/selection/rewards. A target ID may be stale and
must be reacquired legally. Freeze all clocks/damage during picker, pause,
background and entrance; restart/Rush/disposal cancels without reward/blast.

Online scope is co-op, not versus: server owns incoming movement-following,
locked placement, RNG, target/turn/muzzle, rounds, aura ticks, receipts and damage.
Clients render replicated states/events and countdown; never submit coordinates,
damage or elapsed time as authority. Match freeze and disconnect/owner cleanup
apply. Add capability admission so an old client cannot join a support-enabled
room unable to display warnings/entities. Keep current five hosted weapons;
this is not permission to enable the other primary weapons online.

Budget one sentry and one aura per player (max three each in current co-op).
Reserve pending units against caps; limit sentry rounds to eight in flight each
and 24 per room, inside existing global projectile caps. Support defers shots
without spending ammo when saturated and leaves a reserved allowance for player
fire. Aura checks are bounded at 12 owners × four ticks/s per field; overlap
resolution happens once per shared tick. Cull offscreen art, not simulation.
Keep added decoded textures within the existing 32 MiB boss-pair budget.

## Implementation sequence after approval

1. Finalise the proposed reward/tier/placement rules and tune starting values.
   Review sentry storyboard and aura look at actual game scale.
2. Build shared definitions, source-aware offer policy and pure projections in
   Dart/TypeScript; add admin forms/previews and old-catalog/save compatibility.
3. Build incoming/placement/lifetime runtime, shared friendly-impact helper,
   sentry cover/routing and support-ballistic damage path. Add aura ticks and
   ownership before connecting final art.
4. Integrate authored head/base animation, material effects, bounded audio,
   mobile cards/HUD and actual shared co-op replication/capability gates.
5. Run parity/integration checks, render all phases, then physical review.
   Staging balance publication, server deployment and installation are separate
   actions; this proposal does not perform them.

## Acceptance and tuning plan

- Reuse the existing temporary-cover regression scenarios: a 16-body crowd with
  flanking intent, all approach faces, actual movement versus direct sightline,
  adjacent pod/sentry footprints, fences and committed attack stops. Add the
  completed rendered sentry to those scenarios before accepting this feature.
- Source isolation: never in XP/fusion, including reroll/ban/fallback, six full
  special slots, tier III, disabled families, both families already live and
  ordinary old supply menus. Preserve the pinned footer and large-text fit.
- Placement: move/stop/change direction during incoming; marker follows until
  lock and never after. Timer includes descent. Test close source pod, corners,
  no legal point, three allied reservations, movement into landing, pause/
  background/Continue in every phase. Invalid state cannot grant an extra unit.
- Sentry: real separate burst releases, ammo/reload conservation, aim-error gate,
  rotation across ±π, nearest-target changes, cover and own muzzle, Shield Warden
  facing, boss weak points, duplicate receipt and expiry during a burst.
- Impact: exactly one landing and one breakup profile; inner crush, percentage
  boss damage, flat blast/pressure, other cover and no player damage. Cleanup,
  restore and old network events must never replay them.
- Aura: exact exposure DPS across frame rates; body-edge/cover cases, dash,
  exiting/re-entering, target cap, last tick at expiry, boss owner deduplication,
  overlap strongest-only and normal rewards without primary procs.
- Run matched seeded encounters with no support, Sentry, Aura and both, tiers
  I–III, all survivors, early/later health cycles, boss phases and two/three-player
  co-op. Separate per-source damage, kills, uptime, target idle time, cover saves
  and incoming/deploy delays; measure device frame/texture/audio budgets.
- Check natural acquisition frequency: a claimed pod needs at least 22–32s
  arrival + 2.45s descent/warning + 8s capture initially, and later spacing also
  includes source-pod cleanup. These are bursts of help, not permanent uptime.
- Physical acceptance: turret feels heavy and aimed, the player can deliberately
  position it through incoming movement, Aura does not erase contact pressure,
  and neither effect hides enemy warning shapes or masks critical audio.
  Automated damage budgets alone cannot establish those outcomes.

## External references and limits

Activision's official [COD Mobile Hijacked guide](https://www.callofduty.com/call-of-duty/2019-11/Call-of-Duty-Mobile-Map-Snapshot-Hijacked)
describes sentry placement controlling a lane or the middle of the map. The
[official Nuketown Russia guide](https://www.callofduty.com/blog/2020/12/call-of-duty-mobile-nuketown-russia-map-snapshot-guide)
also recommends sentries on ground lanes. These support the stationary placement/
sightline role. They do not establish Regun's damage, lifetime, sky-drop countdown
or tier values; all such numbers above are explicit design proposals derived
from Regun's source. COD's scorestreak acquisition is not copied into XP or kills.
No claim is made that its sentry has the proposed Regun arrival/explosion rules.
