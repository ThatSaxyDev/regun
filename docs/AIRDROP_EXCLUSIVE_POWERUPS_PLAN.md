# Airdrop-only rewards: Sentry Gun and Aura Salad

24 October 2026 design; implementation authorized by the creator on 25 October.
The local native/web, server/API and admin implementation is now present. Normal
family enable flags remain Off for the acceptance gates below. See
[AIRDROP_SUPPORT_IMPLEMENTATION.md](AIRDROP_SUPPORT_IMPLEMENTATION.md) for actual
checks, build results and remaining release gates. Numbers remain playtest values.

The source-grounding section records the pre-implementation baseline; delivery
status is reported separately so proposed checks are not mistaken for evidence.

## Intended experience

An airdrop can grant a short-lived battlefield advantage that ordinary XP cannot
buy. Sentry Gun anchors a position with automatic ballistic fire. Aura Salad moves
with the survivor and damages enemies that approach. Both create a meaningful
window of power and then expire; neither replaces the player's primary weapon.
They coexist with permanent upgrades, including Orbit Drone.

The creator's placement clarification is part of the design: selecting a sentry
starts **SENTRY GUN INCOMING**, rather than immediately dropping a gun at the
selection position. Moving during the countdown influences where it will land.

**Creator clarification, 25 October:** the mounted gun has its own authored sprite
and silhouette. Carbine and three-round-burst describe its weapon variants and
firing behavior, not permission to paste either survivor weapon onto the base.
The sentry commits to one enemy until that enemy dies, then acquires the next.
This supersedes the earlier periodic nearest-target switching proposal.

## Source baseline before this implementation

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
  Native blast pressure currently also reads Blast Harness through
  `CombatSystem.explode(grenade: true)`. Preserve existing pod behavior when
  extracting it; the proposed sentry uses the unmodified base profile below.
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

1. Each supply menu draws a weighted chance of one eligible temporary reward.
   An ordinary-only hand competes at weight 2 against the total eligible support
   weight. With both family weights 1, support appears in about half of
   hands; half offer three ordinary upgrades. A support hand retains two
   ordinary upgrades. XP/fusion menus never draw these rewards. Enablement does
   not guarantee a support card.
2. Roll Sentry Gun or Aura Salad with equal initial family weight. Use recent-offer
   suppression to reduce repetition. Sentry has Carbine and Burst variants; roll
   the mount inside the selected family, so two mounts do not double its odds.
   The actual card states the mount, tier, lifetime and damage BEFORE selection.
   Selecting it immediately confirms that exact variant; no second modal.
3. Keep eight explicit versions, I–VIII, per family for the current run. The first
   selection deploys I; later selections advance through VIII. At VIII a later
   pickup deploys VIII again, clearly labelled **Deploy again**, without increasing
   rank. There is never a permanent damage field left running after expiry.
4. One incoming/live sentry and one active Aura Salad per owner. The same family
   is ineligible while incoming, deploying, active or breaking. No stacking,
   replacement explosion or duration refresh through repeated selection. Both
   families may coexist. Repeated tier-III deployment remains useful after expiry.
5. Reroll repeats the weighted supply draw, including ordinary-only hands. Ban excludes the whole family,
   including both sentry variants, for this run. Use existing reroll/ban currency.
   Ordinary XP rolls must never acquire one through ban replacement or fallback.
6. Tier progress resets on a new run and persists through Continue. It lives in
   separate temporary-reward state, outside special slots, eight-rank upgrades,
   fusion prerequisites and Lucky Find's permanent-special weighting.

This preserves airdrops' current permanent-upgrade value while giving each
eligible drop a visible exclusive choice. An all-exclusive supply menu can be
considered later when there are enough distinct families; two families should
not produce three near-duplicate cards now.

### Offer and confirmation contract

Introduce a discriminated offer-card model rather than adding these families to
the permanent `PowerUp` enum. Preserve ordinary enum IDs in historical saves.
Each issued hand carries its offer generation, source (including supply receipt
where applicable), policy version and exact card identities. A support card
includes family, next deployment tier, mount if applicable, and the pinned
configuration identity from which its preview is derived.

Selection validates membership, generation, original source, family ban and owner
capacity before mutating anything. One successful confirmation atomically advances
the family tier, reserves its entitlement, closes the hand, starts four active
seconds of grace and queues exactly one existing upgrade-recovery pulse. Duplicate,
stale or forged selections grant nothing and spend nothing. Choosing an ordinary
card does not advance temporary tiers. Tier progress is per family, shared between
the two sentry mounts; offering/rerolling/banning does not advance it.

Roll the ordinary two- or three-card portion with existing eligibility, useful-rank
checks, owned-build support and permanent-special weighting. First draw support
availability against the ordinary-only outcome, then choose its family from a
separate pool with recent-family history and no Lucky Find multiplier. Its
recent-offer factor starts at the existing policy's .35. Both mounts initially
have equal conditional weight. Persist the RNG/policy/history needed to reproduce
Continue. Reroll and ban regenerate the hand through this same source-aware path;
no generic ordinary fallback may inject support into XP or fusion. Salvage fills
ordinary shortages using the existing fallback convention; never duplicate a
support family to fill the menu. Ban currency and family exclusions remain separate
from permanent-rank storage.

Co-op currently auto-selects the first card after its existing 15-second choice
deadline. Put ordinary cards before the exclusive card so timeout retains an
ordinary default. Automatic and manual choices must use the same validation and
once-only confirmation path; do not add another choice deadline. Preserve existing
match selection/freeze behavior and consume the pulse on active resume.

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
| Next 36–63s | Live targeting and unlimited-ammo firing. Lifetime advances even when idle, blocked or offscreen. |
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

### Placement and geometry transaction

Use explicit phases: following, finding-zone, warning, falling, deploying, active
and breaking. Derive phase boundaries from pinned incoming time, fixed 1.8s warning,
.65s descent and .55s deployment. Require at least one active second of following
(incoming time >=3.45s). Working lifetime starts after deployment, not selection.
Finding-zone shows status instead of a countdown promising an unavailable impact;
on success the countdown resumes with the full warning plus descent remaining.

Candidate search must have fixed work and distance bounds: initially at most 32
deterministically ordered probes within 260 units of the owner's ground position,
retried at .5s intervals when blocked. Hold the previous legal candidate while
stationary if geometry has not changed. Validate the whole footprint plus player
clearance and a legal displacement exit, not only its center. Treat the 160-unit
base separation as center-to-center and still reject overlapping padded rectangles.
Reservations block other solid placements, including future source pods, but never
block actors or rounds before landing. Resolve simultaneous allied locks in stable
entitlement order. No live admin change may invalidate a committed reservation.

The reservation, planted footprint and removal must enter native `ArenaGeometry`
and authoritative server geometry through the same cover contract. The native
router is reusable, but `RegunGame` currently supplies only the pod as dynamic
cover; extend that provider rather than assuming a general registry exists.
Validate every player displaced at landing, including allies, without pushing
them through another solid or beyond the arena. If an unexpected geometry conflict
makes landing unsafe, defer the entitlement and repeat the committed warning at
a newly validated location; never teleport the warning at the impact frame.

Extract a friendly-impact operation with an explicit emitting-cover ID to exclude
from its own sight checks. Other pods, sentries and walls remain occluders. Do not
reuse the global `_landingSupply` flag to hide all cover while a sentry lands.
Landing installs the base, applies the once-only impact with only self-cover
excluded, then resolves surviving overlaps. Expiry stops shot release, removes the
base and applies breakup once. Routing caches must observe both geometry changes.

## Sentry Gun: targeting, firing and balance

| Setting | Carbine mount | Burst mount |
|---|---|---|
| Tier-I base damage per round | 0.9 | 1.25 |
| Trigger pattern | One round each .10s | Three real rounds, .10s apart; bursts start each .60s |
| Ammunition / reload | Unlimited / none | Unlimited / none |
| Acquisition radius | 550 | 650 |
| Projectile speed | 950 | 1100 |
| Damage multipliers I / II / III | 3 / 3.5 / 4 | 3 / 3.5 / 4 |
| Working lifetime I / II / III | 36 / 42 / 48s | 36 / 42 / 48s |

Mounted weapon damage/cadence/speed are read from that weapon's pinned
base configuration, even if the player holds a shotgun or another gun. It does
not copy the player's current upgraded shot, survivor damage multiplier, pellets,
ricochets, final-shell/reload bonuses or procs. At I the source round uses the configured sentry multiplier before distance damage. Later versions
scale only the documented sentry multiplier. Preserve the source weapon's
ballistic distance curve, sampled from the sentry muzzle; Burst is currently flat.
Acquisition range is capped by the configured source weapon range.

Fire-only upper bounds at I are 27 HP/s for Carbine and 18.75 HP/s for Burst before
distance factors. These exclude travel, rotation, missing, cover and
idle time; they are not promised sustained DPS. The Burst's longer acquisition
range distinguishes it from the higher-volume Carbine. Exact active-time damage
must be measured using the implemented release clocks before balancing.

When unassigned, acquire the nearest living enemy with clear cover sight and in
range, querying at 10Hz rather than rebuilding/sorting every render frame. Lock
that enemy's stable owner ID until death or permanent removal from the encounter.
A closer enemy, reload, temporary cover, range loss or boss invulnerability never
changes the assignment. While the living target is covered, out of range or
invulnerable, stop releasing rounds and retain the lock; track its authoritative
position and resume legal fire when possible. Battery time still advances. Never
shoot through cover or beyond range to honor a lock. On death/permanent removal,
clear the assignment and acquire the next eligible enemy at the next bounded
query. Respect boss vulnerability and body/weak-point ownership; a destroyed weak
point does not count as the boss owner's death or let a round hit that owner twice.

The head rotates continuously on the shortest turn at a proposed 300°/s, with
360° mechanical coverage. Fire only within 6° of its target. Rounds leave the
animated muzzle along its actual heading and travel physically; no homing or
hits through walls. A burst retains one target but cancels remaining subshots
when it dies or firing becomes illegal; it must not spray three simultaneous
pellets or transfer the rest of a burst to a new enemy. Cancelling subshots for
temporary cover/range/vulnerability loss does not clear the living-enemy lock.
Reload/turn can overlap; firing never bypasses an unfinished reload.

Use a support-ballistic damage classification: no primary hit/release procs or
knockback pinning, but Shield Warden's directional armour and Marshal's directional
brace reduction/counter still apply. Today's `primary:false` alone bypasses both
defence branches, so blindly reusing it would be a gameplay bug. A brace counter
targets the living owner through the existing boss targeting path, never a turret
treated as a survivor. Support kills use normal owner-attributed XP/score/death;
existing global kill rewards may apply with their normal caps, not twice.

Do not substitute `weaponHit:true`: that path also applies survivor and upgrade
behavior. Define explicit support-ballistic, support-area, support-crush and
support-blast origins with owner/deployment identity. Keep defence eligibility,
primary-proc eligibility, reaction and reward attribution distinct; preserve
existing callers' behavior. Test native and server defence branches together.
Area/crush/blast retain normal area vulnerability rules without directional
ballistic counters. Projectiles use swept first-body contact and cumulative
muzzle travel, with one accepted owner hit even when boss weak points overlap.

Unassigned acquisition runs at 10Hz with stable actor-ID tie-breaking; there is
no periodic target-switch timer. Revalidate owner existence/death, cover, range
and vulnerability at each release even between queries. Cancel illegal pending
subshots and retain the burst-start cooldown. Ammo/reload, target assignment and
firing permission are separate state: a reload or pause must not drop the lock.
Projectile-cap deferral must
not reset cadence or spend ammo. Add serializable burst/reload state around the
existing `BurstFireClock` semantics, not a second approximation of burst timing.
Rounds already released may finish their bounded flight after battery expiry;
they still count toward the owner's eight-round allowance and room cap. New
deployments cannot evade that allowance. Owner/run cleanup removes orphaned rounds
without impacts or refunds.

**Impact is part of the budget.** The sentry adds two full supply impacts on top
of the source pod's existing impacts. If a boss occupies both inner circles,
that is an extra 6% maximum HP plus up to 16 flat blast damage, before cover and
vulnerability, even without gunfire. Ordinary inner-circle targets can die
instantly. Start with the requested matching profile; do not quietly add grenade
upgrades, Fragmentation or multiply that percentage by sentry tier. No manual
recall/replacement can farm these blasts. Balance review must log bullet damage,
inner crush and outer blast separately.

The sentry matches the **base** supply profile: 62-unit crush/3% boss maximum HP,
8 flat damage within205 and130 outer pressure, using base grenade reaction only.
No Blast Harness, Heavy Payload, Wide Burst, survivor multiplier, Fragmentation
or tier multiplier applies to either impact. Existing pods keep their current
modifier behavior. Explicit profile arguments must make this distinction testable;
do not change pod balance as a side effect of extracting the helper. Attribute
these hits to sentry landing/breakup rather than the generic grenade source.

## Aura Salad

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
At I, an unscaled 2-HP Skitter needs seven accepted ticks of continuous exposure;
contact remains dangerous. For comparison the existing Spore Lobber patch has
2.4 base DPS and 150 radius but is planted and short-lived. Aura's weaker moving
DPS and finite uptime should make it useful without becoming a safe walking kill
zone. Enemy cycle health still scales; no automatic hidden percent-health damage.

One aura per owner. In co-op overlapping allied fields deal only the strongest
eligible aura tick to a given enemy, using a shared tick phase and deterministic
owner tie-break. It is still useful to spread out. No friendly/player damage.
Low ticks reuse normal death/reward attribution; no burn, chains or shrapnel loops.
On expiration the emitter winds down and field fades; no last damaging tick after
its lifetime and no explosion. Downed-owner effects are suspended; no damage
or duration advance while owner recovery freezes their combat. Ordinary death/
run end clears them, while co-op disconnect cleanup removes orphaned support.

### Aura tick contract

Activation deals no damage; lifetime starts when activation finishes. Use a shared
active-simulation tick index and save its fractional clock. An aura becomes eligible
at the first shared tick strictly after activation; activation/re-entry/restore
never produces an immediate bonus tick. No tick occurs at or after expiry. The
table gives steady exposure rates; exact finite-window damage depends on tick
phase. Seven accepted tier-I ticks kill an unscaled2-HP enemy, not a promise that
every moving Skitter dies exactly1.7s after contact.

At each tick first collect eligible living owner bodies, test body-edge coverage
and cover for each field, then choose each field's nearest12 with stable actor-ID
ties. Resolve overlapping candidates once per enemy: largest valid tick damage
wins, then stable owner ID. Only that winner receives damage/kill attribution.
Apply the cap before overlap resolution; do not refill a field's list after losing
a tie. Cover-blocked or suspended fields cannot suppress a weaker valid field.
Process normal simulation substeps with bounded catch-up; never replay missed
wall-clock ticks on Continue. Test equivalent elapsed simulation at30/60/120Hz
and a bounded long frame without using the frame-end position for all past ticks.

## Animation, art and sound acceptance

Sentry needs a new authored grounded chassis/mast with separate rotating head
and a unique mounted-gun design. Author dedicated Carbine-style and three-round-
burst variants with their own turret-scale silhouettes, receiver/barrel/feed
details and muzzle sockets. They share the sentry's visual family and communicate
the source firing behavior, but neither copies, recolors or simply resizes the
survivor weapon sprite. Source weapon balance remains linked; art and muzzle
geometry belong to the sentry. Give each a deliberate mount/pivot and establish front/back depth
relative to mast, contact shadows and recoil direction for every heading. Root
geometry stays planted while only the head turns. Show braces unfolding, mast
lift, small settling weight, bounded barrel recoil and feed motion.
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
support runtime. Use a typed card identity alongside the existing numeric hand
generation; do not replace numeric `offerId` with a compound string. The card
identity includes reward family, tier and sentry mount. Selection must validate
its original source and exact issued card; a client-sent reward ID
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
and acquisition <= source range. Aura tick interval is .25–1s and target cap1–12;
slower ticks must update DPS previews. No editable field may exceed the stated
runtime budgets. Offer membership, caps, proc tags and supported
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
must be reacquired legally. Native clocks/damage freeze during picker, pause,
background and entrance; restart/Rush/disposal cancels without reward/blast.
In co-op only authoritative match/owner suspension freezes support. One client's
backgrounding never pauses the room by itself; existing connection/lifecycle
policy determines suspension or disconnect cleanup, and clients catch up from
current replicated state without replaying damage.

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

### Co-op correctness is a release gate

Calling a sentry in co-op must remain correct when other players are choosing,
moving, firing, downed or reconnecting. Do not infer this from solo tests or pure
TypeScript fixtures. The following is part of the first delivery, not follow-up
polish:

| Situation | Required authoritative behavior |
|---|---|
| Two/three allies choose sentry from the same pod | Each original participant receipt can grant at most one chosen reward. Each owner gets its own tier, entitlement and unit. Stable reservation order produces legal distinct landing sites; no shared-pod receipt is consumed twice for one owner. |
| One ally finishes choosing first | Reserve their entitlement immediately, but do not advance incoming or consume battery while the existing shared selection freeze is active. All clients see the same remaining arrival time when combat resumes. |
| Repeated select, timeout/select race, stale reroll or ban | Only one transaction wins for the issued hand generation. No duplicate unit, tier, pulse, currency spend or blast. The losing request leaves the authoritative result intact. |
| Allies approach the same site or fence | Server resolves full footprints/reservations and legal exits for every overlapping player. A reservation is not premature solid cover. No allied health damage, trapping or actor teleport through cover. |
| Owner becomes downed | Suspend incoming/deploy/fire/aura and their owner clocks; keep a committed reservation/base at its existing location. Already-fired support rounds are removed without hits; no deferred shots/ticks accumulate. Revive resumes remaining time without another landing, activation or recovery pulse. |
| Owner bleeds out, leaves or disconnects | Cancel their pending/live support, cover, reservations and rounds without breakup damage/reward. Preserve already-earned tier history in the participant progress retained by the existing room lifecycle. Reconnect does not refund/replay that consumed reward. Do not grant room re-entry rights beyond existing policy. |
| Room ends, resets or changes generation | Cancel all support and presentation leases without impacts; old messages/entities cannot attach to the new generation. |
| Client subscribes late or reconnects | Current replicated state supplies phase, position, heading, ammo/reload, tier and remaining active time. Events supply transient cues only. Missing an event cannot hide a live base, warning or aura; replayed events cannot damage or respawn anything. |
| Delayed client movement/selection | Server applies authenticated room/epoch/sequence checks; candidate follows current authoritative owner position. Clients never backdate selection, advance countdown or correct a locked point locally. |
| Legacy peer or versus room | Capability admission prevents support-enabled co-op with an incapable peer. Versus never offers/accepts support. Unsupported rooms cannot be made supported by changing a client flag. |

Identify every support entity by room/run generation, owner and deployment serial;
tag landing/breakup cues with phase/event serial. Keep damage receipts in the
authoritative persisted runtime, not the visual component or client event cache.
Repeated runtime loads, scheduler steps and subscription changes must be idempotent.
Clients may interpolate head/fall presentation but must not predict damage or
move a planted base away from its authoritative point. Render any still-active
committed warning from the latest snapshot even if its event was missed. Do not
replay an expired warning, extend authoritative timing to hide latency or fabricate
a local hit. Test late state delivery against the actual damage timeline.

Add replicated support entities and client rendering/bindings as one integration
slice. Verify owner attribution through real projectile hits, boss weak points,
deaths, shared XP/score rules and kill perks. A shared co-op XP reward is not an
extra damage hit or a second owner kill. Stable aura overlap attribution and
Marshal counters must agree on every client.

Reserve 24 slots of the existing global projectile capacity for player fire;
support must stop releasing before it consumes that reserve, in addition to the
eight-per-owner/24-room support caps. Count pending projectile insertions and
released tail rounds. If current primary/hostile usage already consumes capacity,
defer support first without ammo/audio consumption. Measure server step cost and
replication volume with three sentries, three auras, an active boss pair and the
normal encounter crowd, including clients viewing different areas of the arena.

Required integrated test matrix:

- Run both mounts and all three tiers with two and three clients. Include one
  owner calling support while allies keep moving/firing, then all owners calling
  together at the same pod, source pod breakdown during incoming, and adjacent
  live bases. Exercise unlimited sustained fire, burst cancellation and expiry while
  a projectile is in flight. All peers must see the same mount, locked footprint
  and lifecycle without friendly damage or blocking primary fire.
- Repeat at simulated 50/150/300ms round-trip latency, up to 50ms jitter and 1%/5%
  transport loss where the test transport supports it. Record actual achieved
  conditions; a reliable ordered transport must be tested for delayed delivery,
  reconnect and head-of-line stalls rather than assuming application packet loss.
  Inject duplicate/stale application requests independently of transport behavior.
- Interrupt every phase by owner down/revive, disconnect, room end and late
  subscription. Background one client while others continue. Reconnect another
  peer that was observing the deployment; the disconnected owner's consumed unit
  remains cancelled. Compare the resulting snapshot with uninterrupted peers.
- Add server race fixtures that permute selection/timeout/reroll/ban, simultaneous
  lock/landing, death/impact, expiry/disconnect and reset/late-event ordering. Run
  at least 100 seeded deployment sequences per room size, retaining failing seeds.
  Correctness assertions are zero duplicate grants/impacts/kills, zero overlapping
  committed bases, legal displacements and exact ammo/receipt conservation.
- Compare authoritative support snapshots across subscribers at the same server
  sequence after resynchronization. Render clocks derive from that sequence and
  may interpolate only presentation; do not require network clients to display
  an unknowable future state under latency. Warning/state recovery, simulation
  timing and texture/frame/server-step budgets must meet the existing project
  acceptance limits documented before implementation, with measured results.

Any repeatable missing warning/entity, divergent locked position, double impact,
wrong kill owner, cover bypass or allied trap blocks release. A retry that happens
to pass does not close a failing seed. Keep the feature disabled until the failure
is understood, fixed and its regression passes. This gate establishes tested
reliability under declared conditions; it is not a promise of flawless networking
under every device or connection failure.

### Save and balance compatibility

Version the additive support payload and source-aware offer policy independently
from permanent upgrade ranks. Saves include bans/tiers, deployment serials,
entitlements/reservations, phase/tick clocks, issued hand, pinned support config,
ammo/reload/burst state and applied impact receipts. Persist any in-flight support
rounds, their remaining travel and hit history if they survive Continue; restore
must not refund them or restart their range. Validate finite bounded numbers,
legal phase transitions and phase/receipt consistency before accepting a save.
Rebuild derived cover/reservations before restoring actors; reacquire stale targets
without firing during restore. Resume only after the existing paused Continue flow.

Absent support payload/config in a historical run means support disabled for that
run, not current defaults injected on Continue. An old ordinary supply hand stays
ordinary, including reroll/ban for that hand. Reject malformed new support payloads
through the existing invalid-checkpoint recovery; do not silently spawn a free
replacement or discard the rest of a valid old run. New publications affect fresh
runs/rooms only. Match client/server/admin snapshot and component-preview hashes.

Keep both new family enable flags off in the prepared release until integrated
acceptance is complete. Generate a new catalogue with historical definitions
retained and review its diff; never run catalogue generation as an incidental way
to overwrite creator-edited weapon values. Verify source-linked Carbine/Burst
edits change fresh-run sentry projections and leave Continue/existing rooms intact.
Stale admin drafts use the established archive/rebase and authenticated publish
flow; this introduces no parallel configuration channel.

## Implementation sequence after approval

Each stage produces reviewable evidence and must pass before the next stage is
accepted. Keep production enable flags off throughout development.

1. **Contracts and visual direction.** Finalise rules above and a field-by-field
   client/server/admin change map. Review the gameplay-sized storyboard, all head
   quadrants, muzzle/footprint alignment and aura over hostile floor warnings.
   Exit: no unresolved ownership, timer, overlap or impact-modifier rules.
2. **Shared data and offers.** Implement typed cards, separate tiers/bans/history,
   deterministic selection, source validation, projections, disabled catalogue
   entries and old-save/old-hand compatibility. Add admin controls/previews through
   existing authentication/publication plumbing. Exit: Dart/TypeScript fixtures
   agree on offers, tier advancement, timing and damage; failed/duplicate choices
   have zero side effects. Creator weapon values remain intact.
3. **Native runtime and combat.** Build placement/reservations, phase clocks,
   safe displacement, cover integration, explicit damage origins, shared impact
   profiles and aura tick ownership. Integrate approved material art/audio and
   leases; placeholder geometry cannot satisfy presentation acceptance. Exit:
   every phase survives pause/Continue, no impact/proc repeats, all defence and
   existing pod regressions pass, rendered movement/muzzle/cover agree.
4. **Authoritative co-op vertical slice.** Port the same contracts, add capability
   admission, generated bindings, replicated states and client presentation.
   Exit: two and three real clients complete simultaneous deployment, selection
   races, freeze/revive/disconnect/reconnect and late-subscription scenarios;
   damage/phase/owner records agree. Pure tests alone cannot close this stage.
5. **Balance, budgets and physical review.** Run the matched seeded matrix and
   real-client stress cases below, then review on target phones with both control
   layouts, Reduced Motion and large text. Record per-source damage and observed
   frame/server/texture/audio budgets against the same no-support scene. Exit:
   no correctness failures or progression/cover regressions; creator accepts
   placement, warning readability, feel and balance. Fix and repeat failing cases.
6. **Controlled release.** Review catalogue diff and deployment/client capability
   order, validate disabled staging end-to-end, then enable in a separate reviewed
   release. Verify older clients remain safely admitted only to compatible rooms.
   Retain an operational way to disable new support offers for new runs/rooms;
   do not hot-remove support from pinned active runs. Installation, staging/live
   publication and server deployment remain separate actions from this plan.

Record each gate's commands, source revisions, fixture/render paths and actual
device/client observations in a feature validation report. Mark unrun scenarios
pending; neither a build nor a successful install closes a hands-on gate.

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
  rotation across ±π, nearest eligible acquisition, commitment despite a nearer
  enemy, next-target acquisition after death/removal, retained lock across cover,
  range loss, invulnerability, reload, pause and Continue, own muzzle, Shield
  Warden facing, boss weak-point owner identity, duplicate receipt and expiry
  during a burst. Assert zero ammo spent on blocked/out-of-range subshots and no
  remaining burst transferred to the next enemy. Native/server fixtures and all
  co-op subscribers must agree on the locked owner ID.
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

25 October correction: the eight-rank implementation and weight2 ordinary-only
policy are recorded in AIRDROP_SUPPORT_IMPLEMENTATION.md. Its latest tables and
capability7 compatibility rules supersede earlier three-tier recommendations.

Creator correction: sentry ammo is unlimited with no reload. The latest support
implementation report supersedes all earlier magazine/reload recommendations;
source cadence remains, and battery lifetime defaults span36–63s acrossI–VIII.
