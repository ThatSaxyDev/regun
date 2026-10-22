# Regun: fifteen-weapon expansion plan

> Implementation update (21 October 2026): all fifteen solo weapons are now implemented for creator review. See [progress](ARSENAL_IMPLEMENTATION_PROGRESS.md) and the [phone test guide](FIFTEEN_WEAPON_PLAYTEST.md). Online expansion remains gated; design acceptance and physical review are still open. The investigation and proposal below retain their original planning context.

21 October 2026 · Codebase investigation and proposed implementation plan.

Implementation status is in [ARSENAL_IMPLEMENTATION_PROGRESS.md](ARSENAL_IMPLEMENTATION_PROGRESS.md). The four-weapon investigation below is the pre-expansion baseline. All fifteen native weapons now exist; expanded online admission remains pending.

**Target: fifteen complete primary weapons, with eleven additions to the four already implemented.** Keep one equipped primary per run, independent grenade aiming, movement/primary aiming sticks, and the mirrored Dash/Reload/Grenade cluster. Each addition must change how the player fights and have a recognizable sprite, mechanism, impact and sound. A new enum entry or recolored gun is not a completed weapon.

This document proposes future work. No weapon, balance, unlock, sprite, server or release change is implemented by this planning task. Numbers for new weapons below are tuning seeds, not approved balance. Investigation used the current working tree, including its existing uncommitted changes, and read the sibling `../regun-server` implementation. No outside research or new art generation was needed.

## Scope contract — fifteen means fifteen

The corrected requirement is **4 existing + 11 new = 15 playable primary weapons**. The earlier ten-weapon target is superseded. The eleven identities below are the proposed roster; their tuning is provisional, while the total and production-quality requirement are fixed. Intermediate milestones are development gates, not a smaller completion target.

**Included:** all eleven weapon behaviors and resources; finished world/preview/projectile/mechanism sprites; event-aligned VFX/audio; normal unlocks and Training access; all current survivors and arenas; compatible existing upgrades/fusions; save migration; authoritative multiplayer and prediction/rendering support; touch/keyboard/mouse input; lifecycle/accessibility; bounded assets/effects; balance and physical review evidence. The existing four remain fully supported.

**Outside this expansion:** mid-run weapon swapping, multiple equipped primaries, dual wielding, attachments, new survivors/arenas/bosses, extra action buttons, a generic animation-engine rewrite, paid weapon sales and the earlier proposal's four extra upgrade families. They are not dependencies for reaching fifteen. The proposed Breach Hammer is the roster's one melee primary; it occupies the same primary slot and controls, with dedicated swing art/collision. This is a design recommendation for review, not an inference that melee was specifically requested. It is not a separate melee button or an additional equipment system.

Each new weapon needs a complete delivery packet: stable definition, state machine, original sprite parts/clips and measured sockets, reload/resource timeline, sound/cues, collision/proc rules, upgrade/fusion mapping, native/server fixtures, save policy, catalog/unlock entry and recorded acceptance. The implementation tracker must show all eleven packets individually; a global “weapons done” checkbox is insufficient.

## 1. Findings from the actual implementation

### Live roster and protected baseline

[`WeaponType`](../lib/data/loadout.dart) contains **four**, rather than three, weapons. All four are represented in firing, art, reloads, Training, profiles and the authoritative TypeScript weapon specs. Arc Caster is unlocked after Demon in normal play; Training exposes it immediately.

| Weapon | Base ammunition | Shot interval | Base damage | Range / speed | Base full reload |
|---|---:|---:|---|---|---:|
| Pump Shotgun | 5 shells | .35s | Three pellets × 1.2 | 420 / 700 | 3.2s |
| Carbine | 24 rounds | .10s | .762 per round | 650 / 950 | 1.8s |
| Revolver | 6 rounds | .65s | 3 per round | 800 / 1150 | 2.1s |
| Arc Caster | 6 charges | .75s | 3 direct; two innate chain jumps, 85% retention per jump | 560 / 1050 | 2.4s |

Distances and speeds are world units and world units/second. Base damage precedes survivor, upgrade, distance and enemy modifiers. Preserve these contracts while expanding; review new weapons against the current four rather than quietly buffing or nerfing existing guns.

- Shotgun: centered three-pellet spread; 800ms first-shell duration + 600ms per additional missing shell; larger magazines retain the five-shell timing cap. Preserve full reload commitment, Fast Reload bounds, shell/pump cues, original Lottie asset and approved presentation requirements.
- Carbine and Burst Rifle have the .70-duration manual reload when ammunition remains; Burst was explicitly added to this rule after device review. It retains bounded ±2° round heading and small muzzle offsets; rounds then travel straight.
- Current recoil recovery is .14/.07/.19/.18s; muzzle visibility has a separate 45ms window. The .24s per-target shove cooldown, resistance and occupancy rules remain.
- Preserve the four existing distance curves in [`WeaponBallistics`](../lib/systems/weapon_ballistics.dart), cumulative travel and first swept contact; secondary effects do not apply distance damage again.
- Preserve eight-rank upgrade tails, six special slots, two fusion slots, explicit banked-core fusion, funded XP offers, supply offers, four-active-second prompt grace and upgrade recovery pulse.

### Earlier documents versus current code

The [eight-weapon proposal](REGUN_ARSENAL_AND_LOADOUT_PLAN.md) already proposed Rail Lance, Cinder Hose, Rivet Driver and Reaper Disc. None is in the live enum. Retain their useful concepts and expand the target to fifteen. This plan supersedes its arsenal count, implementation sequence and assumptions about loadout/multiplayer; its proposed Rupture and other new upgrade families remain separate, unimplemented scope.

The pinned Survivor/Weapon/Arena catalogs and assembled-kit preview are already implemented. Extend them; do not start again from the obsolete three-column loadout design. Multiplayer is now implemented, so the earlier proposal's instruction to omit it cannot be carried into a finished shared weapon expansion.

Current `pubspec.yaml` says **1.0.0+11**, Flutter minimum 3.47.7, Dart minimum 3.13.0 and SoLoud 5.2.1. Earlier “keep +7” notes are historical relative to the later build11 progress entry. Preserve the current version during weapon work unless separately directed.

One presentation discrepancy needs a baseline capture before refactoring: the instructions repeatedly protect the shotgun Lottie, while current [`BaseView`](../lib/views/base_view.dart) mounts `WeaponReloadDisplay` for all weapons. The October 19 weapon-feedback note records a prior request for that shared mechanical display. Preserve the Lottie file and do not silently resolve this discrepancy by deleting/replacing presentation. Record the actual installed/current appearance and settle the intended shotgun HUD before changing its renderer. This does not block the eleven new weapons' specifications.

### Integration map and concrete risks

| Area | Current evidence | Expansion consequence |
|---|---|---|
| Definition | `lib/data/loadout.dart`: enum mixes identity, text and six scalar combat stats | Scalars cannot describe charge, burst, stream, embedded payload or return flight. Retain stable IDs; add typed behavior specifications. |
| Firing | `lib/game.dart::spawnShotgunBullets` fires every current weapon; `RepeatingAction` supplies cadence | Extract an adapter around existing behavior first. New modes need their own explicit states, not an ever-growing shotgun branch. |
| Reload | `lib/notifiers/game_notifier.dart`: one progress clock, shell schedule, non-shotgun .42/.82 cues and migration markers | Keep the simulation clock; make cue tracks explicit per mechanism. Preserve full reloads, tactical Carbine/Burst and instant pickup refill. |
| Sprite mechanism | `weapon_art.dart` uses `type.index` for body and `4 + index` for part | A fifth enum entry would point into the existing moving-parts row. Replace ordinal addressing before adding content. |
| Anchors | `WeaponFeel.width/grip` determines muzzle; `PlayerComponent`, firing and online prediction reconstruct transforms separately | Long barrels, flipping and moving parts increase drift risk. Introduce one measured socket/transform contract. |
| Sprite source | `assets/art/weapons/arsenal.png`: four bodies and four separate mechanisms, visually inspected | Modular sprites already fit the design. Preserve original pixels and compose authored parts rather than inventing whole-body survivor animations for each gun. |
| Atlas tooling | `tool/inspect_art.py` measures alpha and **rewrites the entire manifest from its CONFIG** | A blind rerun can remove later hand-added entries. Make generation merge/preserve known entries or use a dedicated weapon metadata tool before running it. |
| Hits | `BulletComponent`: swept contacts, cover, target history, piercing, bounces, distance and impacts | Reuse these contracts for ordinary rounds. Returning/area/ballistic weapons need separate bounded flight/contact models. |
| Procs | `CombatSystem.hit/onKill`: primary flag and `lastHitWasSecondary`; eight chain starts reset per update | Add attack provenance and time-based budgets for sustained/delayed attacks. A frame-based budget alone changes behavior across native/server tick rates. |
| Offers | `eligiblePowerUps(GameState)` has no weapon capability input | Add compatibility to offers, rerolls, fusion availability and preview copy together. Avoid dead upgrades. |
| Persistence | Loadout saves enum names; checkpoints validate schema 1/2, capacity ≤100 and bullet speed ≤2000 | Append stable names, version runtime state and validate it explicitly. Do not loosen all validation to fit one new weapon. |
| Unlocks | `PlayerProfile` schema 1 uses challenge IDs and once-per-run settlement | Existing boss sets cannot reconstruct lifetime boss counts. Preserve unlocks and add honest forward progress. |
| Online | Server `weapon_specs.ts`/`combat.ts`; client `combat_state.dart`, `online_world.dart`, projectile prediction and cue correlation | Scalar parity is necessary but insufficient. New event/state kinds, peer rendering, capability gates and server-owned collision are required. |
| Online fallbacks | `OnlineGun.baseCapacity` defaults unknown guns to five; loadout lock copy defaults to “Defeat Demon” | Replace misleading fallbacks with explicit definitions and supported-content handling. |
| Audio | `SoloudPlay.warmCombat` assumes three shot variants, one impact and three non-shotgun reload cues; generators enumerate four guns | Make cue lists data-driven, prewarm selected content and manage loop handles. Do not play a flame shot WAV every particle/tick. |

Primary source paths above are relative to this Flutter repository. Server sources are `../regun-server/spacetimedb/src/weapon_specs.ts`, `combat.ts`, `index.ts`, and `../regun-server/shared/combat_contract.json`. Client copies live in `test/fixtures/multiplayer_combat.json`; generated network bindings must be regenerated through `tool/multiplayer/generate.dart`, never manually patched.

## 2. The proposed fifteen-weapon roster

The first four retain their roles: close spread, sustained automatic, immediate precision and electrical chain. Eleven additions cover burst discipline, charging/penetration, delayed setup, close sweeping fire, return-path movement, ground bombardment, sustained spin-up, three-pellet freezing blasts, heat-managed cutting, persistent contamination and close melee sweeps.

| New weapon / stable ID | Player decision and cost | Initial simulation seed | Essential sprite mechanism |
|---|---|---|---|
| **Burst Rifle** / `burstRifle` | Track through a short burst, then reposition during the gap. Better concentrated windows than Carbine; less continuous correction. | 18 rounds; three shots at 0/.10/.20s; .60s between burst starts; 1.05 damage/round; 700 range; 1100 speed; 2.0s empty / 1.4s tactical reload. | Compact receiver, sliding bolt and detachable short magazine. A separate flash/bolt impulse for every released round. |
| **Rail Lance** / `railLance` | Hold aim through a visible charge; line up bodies. A miss wastes a deliberate opportunity. Revolver remains the immediate precision option. | 3 stakes; .45s charge + .65s recovery; 7 direct damage; 1000 range; 1600 speed; 2.6s reload. Up to two additional bodies at .65 damage retention per penetration. | Heavy copper/ceramic rails, moving charge carriage and magazine. Charge stays planted; a short release impulse and material wake, not a laser. |
| **Rivet Driver** / `rivetDriver` | Plant visible payloads, then reload to detonate before targets scatter. Early detonation sacrifices remaining magazine use. | 8 rivets; .26s cadence; .75 impact + 1.25 detonation damage/rivet; 560 range; 950 speed; 2.2s reload. 90-radius bursts; 2 rivets/target, 8 live payloads; 3s fuse. | Reciprocating hammer, feed strip and latch. Embedded rivets retain readable attachment positions. Trigger/latch pose precedes actual detonation. |
| **Cinder Hose** / `cinderHose` | Sweep nearby space while accepting short range and exposed reloads. It must not replace shotgun burst damage. | 50 fuel; .10s damage/fuel tick; .38 direct damage/tick; 240 reach; 40° cone; 2.3s canister swap. Non-stacking .6 damage/second burn for 1s. | Pilot nozzle, pressure valve and removable canister; finite authored flame sprites with start/sustain/stop states. |
| **Reaper Disc** / `reaperDisc` | Move to line up a return pass; accept a slow, visible outbound attack. No orbit or homing damage farm. | 3 discs; .65s release interval; 1.5 damage/contact; 500 outbound range; 700 speed; 2.4s cassette reload. Max three flights, one outward + one return hit/target/disc. | Exposed rotor, cassette and rotating disc art. Departure/catch animation must match the real flight; catching does not refund ammunition. |
| **Scrap Mortar** / `scrapMortar` | Lead a pack with a visible landing target and delayed blast. Weak at point-blank pursuit and against a boss that keeps moving. | 4 shells; .95s interval; 4.5 blast damage, 145 radius; target distance 180–620; .55–.85s flight; 2.8s reload. Max four live shells. | Short upward tube, breech block and shell; muzzle puff, elevated shell/shadow, then grounded shared explosion. |
| **Belt-fed Repeater** / `beltRepeater` | Commit to a lane through spin-up for sustained pressure; frequent retargeting/releasing wastes its advantage. Carbine stays immediately responsive. | 60 rounds; .40s spin-up; .12s round interval; .70 damage; 620 range; 1000 speed; 3.6s belt-box reload. No movement penalty in the first version. | Receiver, multi-barrel cluster, feed belt and box; barrel speed follows spool state, with one registered muzzle per actual barrel. |
| **Frost Shotgun** / `frostShotgun` | Fire three ice pellets per blast to freeze approaching enemies in place and open an escape route. Trades damage/cadence for control compared with Pump Shotgun. | 5 frost shells; .80s interval; three pellets × .80 damage; centered spread at −9°/0°/+9°; 360 range; 800 speed; 2.6s full reload. Ordinary enemies freeze for .60s, then resist freezing for 1.20s; no stacking/refresh. | Insulated shotgun receiver, pump, coolant chamber and shell; three chunky ice pellets, compact frost muzzle puff and crystal-chip impact; planted frozen pose with restrained ice edging. |
| **Prism Cutter** / `prismCutter` | Keep a narrow beam on the nearest target while managing heat; cover and body interception limit pack clear. Arc Caster remains the chain weapon. | 10 heat units; +1 heat per .10s firing tick; .48 damage/tick; 460 reach; 12-unit beam width; .40s idle delay then 2 heat/second cooling; 1.8s manual/automatic full vent. | Emitter, focusing iris, heat shutters and capacitor; material pixel beam and restrained vent exhaust, not an abstract clean line. |
| **Spore Lobber** / `sporeLobber` | Place short-lived contaminated zones in a pursuit route; reward anticipation rather than immediate burst. Poison does not slow enemies or stack without bound. | 6 capsules; .70s cadence; .50 direct impact + .80 damage/second in a 100-radius patch lasting 2.5s; 480 range; 600 speed; 2.7s reload. Max four patches/owner. | Sealed chamber, capsule drum and plunger; wet capsule travel, rupture and low grounded spore sprites distinct from hostile poison. |
| **Breach Hammer** / `breachHammer` | Step close and commit a directional sweep; strong crowd contact but vulnerable to range and recovery. Dash remains independent. | 4 capacitor Babcharges; .20s windup + .12s active sweep + .48s recovery; 3.2 damage/body; 130 reach, 100° sweep; 2.2s cell reload; max six bodies/swing. | Head, haft, power cell and authored bracing/swing/recovery poses; explicit hand/head sockets and planted feet. No stretching the survivor's arms procedurally. |

These seeds intentionally include tradeoffs; they are not a promise of equal DPS. New weapon distance multipliers start neutral (1.0) unless a scenario justifies an authored curve. Rail penetration attenuation is separate from distance; neither is accidentally applied twice. Mortar explosions use secondary damage semantics and never receive the existing primary-shot proximity multiplier.

### Precise firing and lifecycle contracts

**Burst Rifle.** Aim held starts successive bursts. Each subshot reads current deliberate aim, consumes one round and emits one distinct event; magazine size need not be divisible by three. Releasing primary aim cancels unissued rounds without refunding fired rounds. Manual reload cancels unissued rounds and starts a 1.4s tactical magazine swap if ammo remains; an empty magazine takes2.0s and cycles the bolt. Both reloads complete before firing. Tactical seats the magazine at82% and skips the bolt pose/sound; empty seats at42% and cycles at82%. Empty reload begins after the final actual round. Quick Trigger initially reduces only inter-burst recovery, with a .30s minimum between burst starts; the .10s intra-burst spacing stays readable. Pause/picker freezes state; lifecycle input reset cancels pending burst intent so foreground/Continue cannot release a stale round.

**Rail Lance.** Aim held charges automatically, releases at full charge, recovers and repeats. Explicit aim can turn during charge; direction commits at release. Letting go before release, reload, death or lifecycle cancellation clears an unspent charge. No ammunition, damage, shot cue or proc is emitted before release. Pause freezes the charge; resetting input while paused cancels its intent before resume. No stored full-charge attack after Continue. Charge feedback is non-flashing and world/HUD agree. Stakes use swept finite-speed travel and stop at solid cover. Innate penetrations plus upgrades have a total cap of six contacted bodies; each visited body is counted once.

**Rivet Driver.** A payload attaches only after a confirmed impact. Reload's first phase locks the mechanism; at .12s active time the latch event detonates the current payload set exactly once, then the remainder of the reload completes. Reloading a full magazine with live rivets may execute this action; the current generic “full magazine = ignore reload” guard must become capability-aware. Each rivet otherwise expires in a real blast after 3s. A dead host drops payloads at its last position; they retain remaining fuse and owner. At the two-per-target/eight-total cap, incoming rounds deal direct damage but create no extra payload; ammo markers distinguish embedded from plain hits. Simultaneous payloads coalesce visually with exact bounded summed damage, cover tests and one proc window. No hidden extra blast because an effect failed to mount.

**Cinder Hose.** A start event opens the valve; the tick accumulator consumes one fuel per accepted .10s interval. Particle count and render rate cannot change damage. Test cone/body intersection, cover and the angular sweep between consecutive aim samples; do not skip bodies during fast sweeps or hit behind the player. One direct hit per target per tick, at most eight nearest exposed bodies per tick, ordered by distance then stable actor ID; render flame attenuation past the capped contact depth so the visible reach does not promise unlimited penetration. Burn refreshes one status rather than stacking particles. Quick Trigger reduces tick interval to a .075s floor, with explicit proc windows. Stop the sustain loop on release, empty, pause, picker, interruption, death, restart and route disposal; restarting it never creates a second voice. No ammo cost during a held but suspended stream.

**Reaper Disc.** Commit outbound heading. At range/solid contact, record a return destination from the player's current catch socket and travel toward that fixed point; it does not chase indefinitely if the player moves again. Swept collision applies on both legs, walls block both, and a blocked return is destroyed. End after reaching the recorded point or a 2s return timeout. Stable actor IDs track outward and return contacts separately, including boss weak-point ownership. Contact ledger caps at 32 actors per leg; reaching it stops further damage for that leg while preserving a readable return. Ammo remains spent. A return hit uses a reduced proc weight and cannot create a second full chain/shard tree from one attack. No ally/self damage.

**Scrap Mortar.** Uses primary aim, not the grenade pointer. Show a subdued ground marker while actively aiming. Map post-dead-zone stick magnitude to 180–620 range; commit position at each launch and clamp to valid arena/cover limits. Expose the distance visibly in Training before relying on this control; keep independent grenade drag prediction untouched. Aim assist may assist direction toward a ground lead only if tested, never silently snap range. The launch event spends one shell, and a shared deterministic flight model supplies position, shadow and impact time. For the first version, solids clip the ground path/impact; shell height is cosmetic and does not imply firing through Foundry cover. Impact, not a grenade fuse or shell/body graze, causes one blast; no direct-hit double damage. The shell is friendly and has a distinct silhouette from hostile floor warnings. Quick Trigger floor .55s; piercing/ricochet/High Velocity are initially ineligible. A dead owner does not leave an unbounded or unowned shell.

**Belt-fed Repeater.** Holding deliberate aim spins up without spending ammo or dealing damage. At .40s, release bullets at .12s intervals while held; spread tightens from ±5° to ±2° across the first .60s of actual fire. Release ends firing immediately and unwinds the spool over .25s; the next hold starts a fresh spin-up. Pause freezes state; lifecycle reset/Continue clears spool intent. Quick Trigger reduces the shot interval to a .075s floor, never the initial spin-up. Each round gets an attack event and an explicitly indexed barrel socket; rotation is cosmetic and cannot select a muzzle from a different frame. Reload opens the feed tray, removes the belt box, seats/feeds a replacement, then locks before readiness. No independently homing rounds or hidden mobility debuff.

**Frost Shotgun — creator-selected direction.** One blast releases **three simultaneous pellets**, including a centered pellet, and consumes one shell. These are three pellets in a shotgun spread, not three sequential trigger pulls or a burst rifle sequence. Hold primary aim for repeated blasts at the weapon cadence. Each pellet has independent straight swept travel, body/cover contact and damage; reserve the whole three-pellet volley atomically. Initial damage/timing values are tuning seeds; the three-pellet freezing identity is the creator's requirement.

A confirmed primary pellet hit freezes a living ordinary enemy **in place** for .60 active seconds, stopping movement, contact damage and new attacks. This is a real freeze, not a movement-speed reduction. Interrupt its unreleased attack/lunge at the current valid occupied position and clear that attack's pending release/owned warning, so thaw cannot release a stale attack. Retain body occupancy; do not teleport, slide the body or resume an interrupted leap. After thaw, allow .20s planted recovery before the enemy may start a new attack with its full normal warning. Already released hostile projectiles and independent floor hazards remain live; freezing a shooter does not clear the arena. Death/burn damage and reward handling still work while frozen, so do not freeze the entire component update or revive a dead target at thaw. This interruption is specific to the new freeze effect; other weapon impact contracts remain unchanged.

After freeze expires, the target has **1.20 active seconds of freeze immunity**, shared across all owners. Further pellets during freeze/immunity still deal damage but never stack, refresh freeze, reset recovery or extend the immunity deadline. Three pellets hitting one body can deal three pellet hits but apply only one freeze. Bosses, nests and sentinels take damage but are immune to freeze; no frozen bosses or displaced planted actors. Freeze is applied only by confirmed Frost Shotgun primary pellets, including explicitly supported piercing contacts; chains/burns/shards/grenades never inherit it. Hot Shot uses its existing separate status, without an invented melt/shatter bonus or death explosion. Shots remain subject to cover, range, resistance and normal proc/impact budgets.

The sprite packet retains a grounded shotgun grip, short pump motion and a coolant/shell reload mechanism. All three pellets share the actual release muzzle/event; the spread changes direction rather than spawning three barrels. Frozen ordinary enemies hold an appropriate planted living pose with restrained ice edging; do not hold an airborne leap or damage/defeat frame. Preserve the readable silhouette and suppress the canceled attack's warning art. At thaw, ice chips fall below actors and the creature settles before restarting its normal warning. Reduced Motion uses steady ice edging with no shake/flash or chip shower. Reload completes fully before firing; this new weapon has its own 2.6s mechanism/cue track and does not reuse or alter Pump Shotgun's 3.2s timing/original Lottie.

Pause/picker/entrance freezes freeze, thaw-recovery and immunity clocks. Checkpoints persist validated remaining durations and interrupted-action state on stable enemy IDs; restore cannot refreeze for a full duration, restore a canceled attack or erase immunity. Server owns status acceptance, cancellation and thaw. Versus initially retains damage-only Frost shots until a separate player-freeze fairness policy is approved. The weapon's pitch is **three ice pellets: freeze the enemies you hit, then make room to escape**.

**Prism Cutter.** Primary aim opens the iris and commits the first server/native tick; each .10s interval reserves heat/damage/VFX together. A clipped segment/capsule tests the nearest exposed body, including body radius and cover; damage is per tick, never per beam stamp. Beam endpoints follow confirmed aim/muzzle and stop at the first intercept. Released aim closes the beam immediately, retaining heat. Cooling starts after .40s idle, with fractional heat stored in the runtime. Reaching 10 heat automatically commits a 1.8s full vent; Reload may start the same vent early while any heat remains. Vent completion resets heat; held aim cannot interrupt it. Quick Trigger changes recovery from stopped beam to ready, not tick damage rate; it is initially ineligible rather than offering an imperceptible benefit. No first/last-shot perks, Scattershot, High Velocity, Piercing or Ricochet offers. Extended Tube expands the thermal reservoir to a 16-unit cap and instantly cools it once as the pickup refill; later operation still requires cooling/venting. Pause/picker/entrance freezes heat, cooling and vent. Readouts show HEAT and VENT rather than fictitious cartridges. Rendering uses authored pixel material stamps with a clear clipped core/envelope; retain Marshal's existing laser presentation unchanged.

**Spore Lobber.** A capsule follows a straight swept ground path; visual bob does not imply an arc through walls. It ruptures at the first solid/body or maximum range and creates one patch at the last valid point. Body impact is direct damage; patch ticks are secondary, at .25s fixed intervals, first tick after .25s. A target inside overlapping patches from the same owner takes only the strongest patch's tick; different owners remain subject to the room damage/effect budget. Up to eight exposed bodies/patch tick, selected by distance/stable ID, with body-edge intersection and cover. When four patches are already active, a fifth landed capsule replaces the oldest before its first tick; never silently create an invisible fifth patch. Patches do not follow enemies or spread on death. Innate spores are a separate status/source from Hot Shot, preventing burn-spread chains from being implied. Floor material has a quiet friendly rim/texture, lies below actors, and must not obscure Queen/Foundry warnings. Persist remaining patch lifetime and tick phase with ownership and terminal flags.

**Breach Hammer.** Primary aim starts a swing and fixes its facing at windup completion. Release before .20s cancels with no charge spend; at .20s spend one charge and enter the .12s active sweep. The active head/shaft path sweeps its authored arc once, resolving cover, nearest contacts and stable actor ownership; every body/weak-point owner can be hit only once/swing. The sixth exposed contact terminates further damaging reach; art loses energy beyond the stopped segment. There is no circular damage behind the player, projectile travel, innate invulnerability or wall penetration. Recovery completes at .80s from swing start; held aim then starts the next swing. Quick Trigger reduces recovery to a .25s floor; windup/active duration stay readable. Dash cancels any unissued windup or ends the active sweep, without refunding a spent charge; it never projects a moving full-length damaging arc during dash. Reload waits for an issued swing's recovery; pause freezes the phase and lifecycle resets unissued intent. The independent grenade control remains usable unless the shared entrance/pause gates apply. New full-body braced/swing poses must preserve ground anchors, use three survivors/four facings and be checked alongside current run phases; do not force a rotated rifle sprite to stand in for a melee animation.

If mortar distance control proves uncomfortable on a phone, revise and re-test that control before committing final art. Do not replace a failed addition with a reskinned existing gun and call the fifteen-weapon objective complete.

## 3. Sprite precision is a first-class deliverable

### Art direction and production packet

Keep worn iron, dirty copper, ceramic, olive and restrained brass from the [art bible](art/ART_BIBLE.md). Friendly Cinder must differ from hostile furnace effects by silhouette and motion as well as color. Flame, wakes and disc trails remain subordinate to enemy telegraphs. Keep Rook/Scrapper/Warden anatomy and their accepted full-body run loops. Do not revive the rejected segmented-leg experiment described in [animation repair](art/ANIMATION_REPAIR_2026-10-19.md).

Before final painting, prepare one packet per gun:

1. Native gameplay-size silhouette beside all four originals, on both arena floors, with each survivor.
2. Neutral east-facing body and named detachable parts, side-by-side at consistent source density; separate projectile and impact/charge/stream assets as needed.
3. A part map identifying which mechanism is already painted into the receiver. Avoid doubled magazines/cylinders/cells when the moving part is drawn; author an exposed socket/open-body pose where necessary.
4. Fixed logical canvas, measured alpha crops, explicit source dimensions and pivot/socket metadata. Cropping transparent margins must never move the mechanical anchor.
5. A contact sheet and real-time loop of idle, launch, recovery and full reload. Add charge/burst/stream/return clips only for the appropriate weapon.
6. Asset source/prompt/license, original master, SHA-256, atlas layout, chosen decode size and approval status. Preserve the current generated source pixels; do not silently “repair” unrelated atlases.

The eleven packets must include at least these independently addressable parts:

| Weapon | Mandatory parts / states |
|---|---|
| Burst Rifle | Receiver, magazine, bolt; fire impulse per subshot; magazine out/in and bolt release |
| Rail Lance | Receiver, charge carriage, stake magazine; charge accumulation/ready/release/recovery; spent-feed reload |
| Rivet Driver | Receiver, reciprocating hammer, feed strip, detonation latch, lodged rivet; loaded/spent feed states |
| Cinder Hose | Receiver/nozzle, valve, fuel canister; pilot/start/sustain/stop; depressurize/swap/repressurize |
| Reaper Disc | Launcher, rotor, cassette, in-flight disc rotation frames; release/catch-or-expire; cassette out/in/lock |
| Scrap Mortar | Tube, breech, shell, airborne projectile/shadow; opening/loading/closing; launch and recoil return |
| Belt-fed Repeater | Receiver, barrel cluster, belt/feed cover and box; spin-up/sustain/unwind; cover open/feed/lock; indexed muzzle sockets |
| Frost Shotgun | Receiver, pump, coolant chamber and shell; three-pellet release/pump return; shell/coolant reload/lock; crystal impacts, planted frozen living pose and thaw edging/chips |
| Prism Cutter | Emitter, iris, shutters and capacitor; beam on/off, stepped heat and vent holds; clipped pixel beam material |
| Spore Lobber | Receiver, drum, capsule and plunger; launch/drum advance/reload; capsule rupture and four bounded patch age states |
| Breach Hammer | Head, haft, cell plus survivor-specific swing/bracing poses; windup/active/recovery; cell swap; authored head/hand trajectory |

The Hammer packet additionally budgets **3 survivors × 4 facings × at least 3 key action poses = 36 full-body pose references**, plus the weapon parts. Reuse an existing pose only after anatomy/hand alignment review; 36 references is a production checklist, not permission to duplicate one pose 36 times. Determine whether the active .12s needs an intermediate frame through motion tests. Other ten new weapons do not require new survivor run sheets. Include this exception in art cost and memory estimates before approving the melee slice.

Favor rigid sprite parts with authored pivots and short eased translation/rotation for mechanisms. Use hand-corrected frame sequences where shape actually changes (flame ignition, a turning disc, an opening breech). Do not generate unrelated full-gun images for every time step: receiver proportions and sockets would drift. For firearm/tool weapons, the existing four-way survivor bodies plus continuously rotated gun remain the baseline; Hammer uses its explicit action-pose packet without replacing run art. Add directional gun art only when actual north/west occlusion tests justify it, rather than multiplying every weapon into sixteen facings by default.

### Proposed `WeaponArtSpec` contract

Replace `type.index` and `4 + index` with named atlas/frame references. Keep the old four mappings explicitly, so appending enum values cannot change their pixels. Each specification should declare:

```text
weaponId, artVersion, atlasId
logicalCanvasSize, sourcePixelDensity, renderScale
bodyFrame, namedPartFrames, optionalClipFrames
gripSocket, supportHandSocket, muzzleSocket, ejectionSocket
partPivots, partAttachmentSockets, projectilePivot, optionalCatchSocket
occlusionPolicy, mirrorPolicy, materialGrade
clips: named phases + holds + event markers + reducedMotion pose
```

Sockets use the untrimmed logical art canvas; crop origin is retained. Alpha centroids help discover body bounds but do not infer a barrel tip, hinge or support-hand attachment. Measure and author those points explicitly. The current manifest's single `pivot` and body-height normalization are insufficient for all of them; retain grounded-body metadata and add a weapon-specific layer rather than changing every character/enemy renderer.

One pure `WeaponPose` calculation produces body/part transforms and sockets for world rendering, HUD, loadout sample and online peers. One transform helper maps the released muzzle to world space. Include the current ±aim hand offset, actor origin, rotation and leftward flip. Account for near-wall muzzle placement by clipping or rejecting an obstructed release; never spawn on the far side of a solid. A developer overlay may show socket crosses, hit shapes and crop bounds, but it must be absent from the shipped player HUD.

Mirror the full attachment transform, including support hand, part offsets and ejection direction. Test at angles just above/below north/south and the existing behind-body threshold `aimDirection.y == -.35`; no sudden weapon pop or reversed mechanism. “Left-handed controls” changes control placement, not the physical socket conventions. Avoid resizing each cropped pose independently; use one source-to-world scale. Keep nearest filtering, enough atlas padding for rotated crops, and check decode rounding at native render size.

Cosmetic recoil must not change shot direction, damage or logical muzzle distance. At release, flash and projectile share the event's muzzle; then the receiver recoils from it. Do not derive projectile origin from a receiver that has already kicked backward. During reload, moving parts cannot move the authoritative damage origin because no round is allowed until ready.

### One event timeline, several consumers

The runtime owns simulation time and emits events such as `chargeStarted`, `shotReleased`, `subshotReleased`, `reloadStarted`, `partSeated`, `detonated`, `reloadCompleted`, `streamStarted/Stopped`, `discReturned/Expired`, `spoolReady`, `freezeApplied/Thawed`, `ventStarted/Completed`, `patchCreated/Expired` and `swingCommitted/Ended`. An event includes run epoch, actor ID, attack ID, event index, simulation timestamp, weapon ID and committed muzzle/aim when relevant.

- Damage/ammunition/flight are advanced by runtime state, never by the renderer reaching frame N or a sound finishing.
- Sprite pose, muzzle VFX, HUD and audio sample the same phase/event. Each cue has one owner and an idempotent event key; missed render frames cannot drop damage or duplicate sound.
- Use `previousTime < marker <= currentTime` event crossing with a defined event-at-zero rule. Large updates execute crossed events once, in order, with remaining substep time.
- For existing non-shotgun reloads preserve .42/.82 markers and the Carbine/Burst tactical exceptions. New weapons receive authored tracks rather than inheriting those markers blindly.
- Normalize non-shotgun reload mechanisms to their actual upgraded duration; maintain a small mechanical closing hold. Shotgun retains its authored shell schedule and Fast Reload behavior. Do not stretch the 45ms muzzle impulse over the whole fire cooldown.
- Reduced Motion keeps receivers/parts planted, omits sweep/lift/long trails and replaces charge buildup with a steady stepped state. Preserve event timing, readable ready/empty/reload states and actual projectile/damage positions.
- First/last shot effects attach to real resource-consuming attacks; no cosmetic preview creates them. Preview uses an isolated playback sample with no run state or reward changes.

**Example Rail Lance seed:** charge 0–450ms with a planted carriage and two restrained readiness steps; release at 450ms (one ammo spend, one muzzle/shot event); short 60ms kick; settled recovery through 1100ms. The next charge may start at 1100ms while aim remains held. Reload is a separate 2600ms track. Quick Trigger initially reduces recovery only to a .35s floor; charge stays .45s so the weapon remains legible. A frame dropped across 450ms cannot fire twice or leave the gun in a permanent firing pose.

### Sprite acceptance tolerances

These are proposed engineering tolerances, not claims that current art has passed them:

- Reconstructing a cropped frame preserves the authored grip within **one decoded source pixel** across all phases. A moving part returns to its socket within the same tolerance.
- Muzzle event, flash origin and projectile origin agree within **one world unit in the pure transform model**; rendered overlays differ by no more than one output pixel after rasterization. Collision radius is independent of draw width.
- Ammo, phase and release markers agree within **one simulation step**, with identical event ordering at native variable dt and server 50ms dt. Render feedback arrives on the next rendered frame. This is not a zero-latency network promise.
- Inspect every mechanism at 0%, 10%, 42%, 72%, 82%, 94%, 100% and every authored event boundary, including before/after the marker. Detect clipping, duplicate parts, fractional resize wobble and muzzle jumps.
- Render eight aim angles plus wrap/flip/occlusion boundaries, three survivors, idle/run/reload/dash, both floors, Reduced Motion and enlarged HUD text. Continuous angle math must also be unit-tested beyond those screenshots.
- View real-time and slow-motion footage on the phone. A contact sheet alone cannot establish that ignition, feed, catch and impact land convincingly.

## 4. Runtime architecture and integration

Introduce a small typed specification/runtime split, with a compatibility adapter for the existing four guns. Do not move all of `GameNotifier` or rewrite unrelated combat in the first step.

| Proposed contract | Owns | Does not own |
|---|---|---|
| `WeaponSpec` | Stable ID; resource kind; base stats; behavior kind; capability/upgrade policies; audio/art references | Live timers, entities, saved profile |
| `WeaponRuntime` | Idle/charge/burst/spool/fire/swing/vent/recovery/reload state; ammo/heat; phase time; pending events; validated snapshot | Drawing or direct SoLoud calls |
| `WeaponAttack` / flight models | Swept paths, cone ticks, rivet payloads, disc legs, shell landing, accepted freeze/thaw/immunity status, clipped beam ticks, spore patches and melee sweeps; owner/event IDs | Local input trust or menu state |
| `WeaponPose` + `WeaponArtSpec` | Socket transforms, part poses, phase selection, common presentation | Damage decisions or timer advancement |
| `DamageContext` | Owner/team, attack/parent ID, direct/secondary kind, contact leg/tick, proc budget, kill-credit source | Full recursive proc trees by default |

Keep the external `WeaponType` IDs for existing saves; append eleven names without reordering originals. Prefer exhaustive lookups with validation over catch-all shotgun behavior. Unit-test one definition, runtime, art packet and audio packet per supported weapon. Refactor the misleading `spawnShotgunBullets` name only after its existing behavior is captured and the adapter passes regression tests.

Keep `GameState.noOfBullets/maxBullets` as a compatibility projection initially, with spec-defined labels such as fuel/stakes/discs. Prism heat and Hammer melee are typed resources/attacks: heat must not be independently advanced as magazine ammo, and melee must not create a fake bullet just to fit this projection. `WeaponRuntime` becomes the single owner of primary ammo/reload time; avoid two independently advanced clocks. `GameNotifier` remains the scoped HUD/build surface and owns the existing quick-refill notifier contract. Publish fine-grained pose/progress updates rather than rebuilding the whole HUD on each stream tick.

Validate reservations **before** consuming resources or issuing shot audio. Native currently can break its pellet loop at capacity after beginning a shot, whereas the server requires space for the whole volley; settle this discrepancy with a shared atomic release policy. Reserve a complete subshot/volley and its minimum readable VFX, including pending component mounts. If unavailable, delay that release without spending ammunition and without a phantom flash. Keep critical boss/enemy warnings prioritized; decorative exhaust can be reduced first. Hard saturation must never create invisible damage.

Damage provenance is required for new delayed/continuous attacks, even if Rupture remains deferred. A rivet host death, burn tick, return pass and fragmentation shard cannot repeatedly claim the same kill or restart a full proc tree. Keep current once-only death/reward rules. Ordinary weapon impact uses existing mass/occupancy constraints; bosses, nests and sentinels stay planted. Cinder uses .25s per-target proc windows; disc return permits at most one reduced secondary proc window; rivet/mortar blasts remain secondary and use bounded Fragmentation rather than direct-hit chains.

## 5. Upgrades, fusions and honest offers

Do not add more upgrade families just to fill the expanded arsenal. Existing **33 offered families** should form useful builds first. Introduce capability-aware eligibility with an explicit decision for every family × every weapon. Both Training direct preparation and normal offers use that contract. Preserve bans/rerolls, unique choices, rank VIII exclusion, special slots and fallback behavior.

| Mechanic | Burst / Rail | Rivet | Cinder | Disc | Mortar |
|---|---|---|---|---|---|
| Heavy Load | Scale direct damage | Scale direct + stored payload once | Scale tick damage; burn uses its own status rule | Scale each allowed contact once | Scale blast once |
| Quick Trigger | Recovery rules above; no extra burst rounds or shorter charge | Cadence, .14s floor | Tick rule above | Release cadence, .35s floor; no extra live flights | .55s interval floor; flight time unchanged |
| Extended Tube | Capacity + immediate pickup refill | Capacity + refill; payload cap stays eight | Fuel + refill; tick cost stays one | Reserve capacity + refill; max three flights stays | Shell capacity + refill; max four live shells stays |
| Sleight of Hand | Normalize authored reload | Normalize reload but keep detonation before completion | Faster canister swap | Faster cassette swap | Faster breech load |
| Scattershot | Bounded fan; Rail max three stakes/release, spread tightening IV–VIII | Extra direct rivets, same payload cap | Ineligible initially | Ineligible initially: three-flight cap already defines space | Ineligible initially |
| Piercing Rounds | Burst standard; Rail combines with six-body cap | Additional direct contacts, at most two new payloads per rivet flight | Ineligible initially | Bounded contacts/leg; never duplicate a target on one leg | Ineligible |
| Ricochet / Bank Shot | Bounded directed ricochet; cumulative distance/cap retained | Direct round only, payload damage does not inherit bounce scaling | Ineligible | Ineligible initially; avoid conflicting return paths | Ineligible |
| Long Barrel | Outbound range; fixed damage bands | Travel only; burst radius unchanged | Cone length to 320 cap | Outbound reach to 650 cap; return timeout bounded | Target range to 760 cap; flight duration max 1s |
| High Velocity | Finite projectile speed within validated limit | Direct flight speed only | Ineligible | Travel speed to 1200 cap; angular art speed separate | Ineligible initially |
| First/last-shot perks | Actual resource-consuming round; burst final round handled once | Direct round only; no repeated payload bonus | First/final fuel tick once per magazine | Outbound contact damage only | One launch/blast snapshot; no double bonus |
| Hot Shot / electrical / marks / Executioner | Existing direct-hit semantics, shared proc caps | Direct impacts; detonation secondary | Windowed direct ticks; innate burn + Hot Shot refresh one bounded status | Outbound primary, reduced return policy | Secondary blast; direct-only procs ineligible |
| Grenade families | Independent secondary inventory/flight for every primary | Same | Same | Same | Same; not a mortar upgrade |

For the five additional identities, apply the following explicit policy; shared utility/defense/movement/grenade families remain available for all.

| Mechanic | Belt-fed Repeater | Frost Shotgun | Prism Cutter | Spore Lobber | Breach Hammer |
|---|---|---|---|---|---|
| Heavy Load | Direct rounds | Pellet damage only; freeze duration unchanged | Tick damage once | Direct impact + patch damage once each | Swing damage once/body |
| Quick Trigger | .075s interval floor; spin-up unchanged | Interval floor .45s; freeze/immunity unchanged | Ineligible initially | Interval floor .40s; patch ticks unchanged | Recovery floor .25s; windup/active unchanged |
| Extended Tube | Belt + immediate refill | Frost shell capacity + refill; freeze stays bounded | Heat reservoir to 16 + one pickup cooling; normal cooling still required | Capsule reserve + refill; four patches stays | Cell capacity + refill; one active swing stays |
| Sleight of Hand | Faster belt reload | Faster complete shell/coolant reload | Faster vent, .85s floor | Faster drum swap | Faster cell swap |
| Scattershot | At most three rounds/release; atomic reservation | Base three pellets; +2 at I–III (max nine), IV–VIII tighten spread; no freeze stacking | Ineligible | Ineligible; avoid multiplying persistent zones | Ineligible; not extra invisible swings |
| Piercing / Ricochet / Bank Shot | Standard bounded round behavior | Piercing up to three bodies/pellet; Ricochet/Bank Shot ineligible initially | Ineligible | Ineligible; rupture happens once | Ineligible; body cap is authored sweep geometry |
| Long Barrel | Round range | Pellet reach to 480; freeze unchanged | Beam reach to 560 | Capsule reach to 600, patch radius unchanged | Ineligible initially; do not stretch limbs/head path |
| High Velocity | Round speed ≤2000 | Pellet speed ≤1400 | Ineligible | Capsule speed ≤1000 | Ineligible |
| First/last-shot perks | Each actual spent round | Direct impact only | Ineligible; cooling cannot reset Breach Engine | Direct capsule impact only | One spent swing; one snapshot for all its contacts |
| Direct-hit status / chains / mark / Executioner | Existing bounded semantics | Bounded primary-pellet semantics; freeze once per eligible body/window | .25s proc windows; mark first confirmed hit/window | Capsule impact only; patch secondary | Once/body/swing, at most two chain starts/swing |
| Fragmentation | Existing independent blast sources only | Same | Same | Spore rupture/patch is not an explosion; no innate shards | No innate explosion/shards |

**All 495 upgrade/weapon cells (33 × 15) require an explicit supported/ineligible rule**, with rank I/III/VIII examples for supported effects. The tables group common behavior for readability; the implementation manifest and tests must cover each family, not only these headings. First/last resource rules mean Prism cannot acquire Last Shell/Breach Loader or Breach Engine; all weapons still have viable builds without every family.

This table is the initial policy, not a shortcut around per-family tests. Define rank increments/caps for new capacities in the specs rather than inheriting “Carbine versus everything else.” Reload reductions keep existing minima and a conservative **40% of base / at least .85s** floor for new weapons until playtesting; authoritative server and native must apply the same values. High Velocity caps at 2000 until validation changes are deliberately reviewed.

All six current fusions need explicit eligibility:

- **Firebreak:** primary ignition-capable weapons; Cinder's native burning alone does not satisfy Hot Shot III. Mortar cannot acquire an unusable recipe; Belt/Frost/Prism/Spore-impact/Hammer use their explicit direct-hit policies.
- **Storm Circuit:** direct-hit-capable weapons using proc windows; Mortar excluded in the initial policy; Prism is windowed and Hammer has its two-start cap.
- **Minefield:** available to all; independent of primary behavior.
- **Pinball:** Burst/Rail/Rivet/Belt only among additions; all other additions exclude its prerequisites.
- **Breach Engine:** all cartridge/cell-based resource models above preserve a real first/last attack; Prism is excluded; no repeated bonus for every pellet, flame particle or payload explosion.
- **Hunter Swarm:** available to all; Targeting Link also needs a bounded mark path for Mortar and secondary-only patch builds, so let confirmed blasts/patch contacts mark affected bodies at most once per .25s window without enabling unrelated primary procs.

For inherited or Training-prepared incompatible ranks, preserve stored rank data but disable the unsupported effect with accurate build-reference copy. Existing four-weapon saved builds retain their exact behavior. Do not silently replace paid-for picks or mutate a saved build just because eligibility is refined.

Rupture, Concussive Loads, Fault Finder and Overpressure from the prior proposal remain optional follow-up work. Heavy Payload/Wide Burst currently affect grenades; do not silently broaden them to every blast or introduce a duplicate blast family in this expansion.

## 6. Persistence, unlocks and loadout

### Saves and interruption

Add a versioned optional `weaponRuntime` snapshot with finite/bounded fields: weapon ID, ammo, phase/time, reload cues already emitted and relevant flight/payload IDs, heat/idle-cooling phase, spool state, per-enemy freeze/thaw-recovery/immunity durations and melee event/contact phase. Old saves without it reconstruct the existing four-weapon state using current migration markers (`weaponBalance`, `shotgunReloadBalance`, `xpCurve`, `survivorSpeedBalance`); do not rerun them on every Continue. Preserve run ID and settled reward history.

Policy for new transients:

- Existing ordinary bullets keep their current transient-save policy. Do not turn legacy Continue into a replay of previous volleys.
- Charge, spool, active beam and unissued burst/swing input are canceled on Continue without spending new ammo. Retain Prism heat/vent and already-spent resources; a canceled active Hammer swing is never reissued or refunded, and Frost status resumes only its saved remaining duration. Reload progress/cues remain durable.
- Persist new ammunition-backed rivet payloads, active discs, mortar shells and spore patches with remaining lifetime, committed position/path, stable owner/actor IDs, contact ledger and terminal-event flag. Reconnect payloads to restored enemy IDs; if a host is gone, use the saved last valid position/fuse. Build the stable-enemy-ID mapping before attachment restore.
- Loading opens paused and does not emit elapsed sounds or apply wall-clock catch-up. Already detonated/returned/expired objects cannot settle again. Snapshot/removal must be idempotent even if the engine still has a pending component removal.
- Cap payloads at eight, discs at three, shells at four, spore patches at four for the local player; validate snapshot sizes, IDs, geometry, times and damage derived from trusted build state. Reject corrupt primary data through existing RunStore fallback, without wiping the profile.
- Extended Tube cancels primary reload/charge and clears unissued burst state before refilling; it does not duplicate/refund launched ordnance. Training recovery resets primary runtime and clears its owned transients consistently, preserving the training build/encounter.

Pause, picker, entrance and app interruption must freeze weapon damage/resource clocks even where the world intentionally shows 0.1× upgrade motion. Restart/route disposal increments the epoch, cancels input/voices, releases leases and makes late async loads unable to mount into the next run.

### Unlock progression

Keep existing Shotgun/Carbine/Revolver/Arc gates and every earned entitlement. All fifteen are available in Training without normal rewards. Proposed normal gates use cumulative **future** boss victories: Burst 3, Belt 5, Rail 7, Frost 9, Rivet 12, Cinder 15, Disc 18, Prism 21, Spore 24, Mortar 27, Hammer 30. These totals are a proposed ordering, not a mandate to grind thirty bosses before the roster can be evaluated: Training exposes all eleven immediately, and measured sessions may justify fewer victories or parallel kill/mastery goals. These are tuning seeds, not approved session-length targets. Avoid a mandatory weapon-unlock chain: players should not have to master an unwanted gun to reach the next one. Accessibility settings remain eligible.

Add schema-versioned cumulative boss victories and per-weapon/kind counters only if their UI/reward paths ship together. Current sets record distinct kinds, not repeated victories; migrate only reliable lower bounds, never fabricate lifetime totals. Count authenticated normal run events once, carry counters through checkpoints, settle once per run ID and exclude Training/Boss Rush. Keep local solo progression separate from trusted online authority rather than letting a client submit arbitrary victories.

Extend the existing catalog to fifteen, preserving pinned tabs, retained selections, scroll-to-equipped behavior, kit preview and reachable Start. Use two columns where room permits and one on narrow layouts; no miniature fifteen-card squeeze. Locked weapons may be inspected independently of equipped selection. Show one-sentence role, actual units, one tradeoff and unlock progress. A deliberate fire/reload preview is optional; never autoplay fifteen audio loops. All thumbnails wait for atlas readiness; list virtualization and pooled thumbnail art must not hold every high-resolution combat atlas.

### Input parity and independent resources

Hold/aim/release and Reload keep their existing meanings on touch and equivalent keyboard/mouse input. New state machines consume normalized intent events rather than querying a particular joystick widget. Mortar's analog distance needs a visible desktop equivalent (aim-point distance clamped to its valid band), with server-owned position/cover checks; test both paths against the same target fixture. Cancel on focus loss and input epoch changes. Touch keeps separate pointer ownership for movement, primary aim and grenade drag, including out-of-bounds release, mirroring, floating-stick exclusions and custom placements.

Grenade charges/recharge, primary cartridges/capacitor charges, Prism heat, payloads and fusion cores are distinct inventories. Reload/vent/refill must not alter grenade charges or replay an upgrade pulse. A Hammer swing or active beam cannot borrow a grenade pointer or introduce a new mandatory action button.

## 7. Authoritative online parity and rollout

The current server advances combat at 50ms steps, while local projectile prediction assumes ordinary rounds and current cadence. New weapons cannot simply be accepted as strings and drawn as shotgun bullets.

1. Add matching specs/state machines to `weapon_specs.ts` and `combat.ts`, with behavior/phase fixtures beyond today's scalar contract. Store every new state transition on the server's simulation clock.
2. Extend round/entity presentation with typed burst, charge, stream, payload, two-leg disc, shell, spool, freeze/thaw/immunity, heat/vent, spore patch and melee sweep states/events. Use `(room generation, actor, attack, subevent)` keys to reconcile local feedback with confirmed release; no second flash/sound/projectile on confirmation.
3. Reuse validated primary aim for every new weapon except Mortar's added range intent. Freeze acceptance and interrupted-attack cleanup, beam intercepts, patch ticks and melee contact ledgers are server-owned. Mortar adds a bounded finite primary distance intent, separate from `aim_grenade`; server derives origin, cover clipping, trajectory and damage. Authenticate room membership, epoch and sequence. Never accept client muzzle, contact list, target attachment, endpoint or damage as truth.
4. Pure models run the same fixed-step/substep fixtures in Dart and TypeScript. Test marker crossings at .10/.20/.45s and server-quantized intervals; compare event ordering/positions within the defined step tolerance rather than claiming identical unquantized cadence.
5. Prediction is cosmetic. It cannot spend confirmed ammo, attach a real rivet, explode, mark a hit or award a kill. Turn off unsupported speculation until the new behavior's correlation tests pass. Remote clients render server phases instead of inferring charge from a shot counter.
6. Negotiate supported weapon IDs and weapon-event protocol before selection/match admission. Existing clients use exhaustive enum parsing, so server-only capability gating is insufficient: do not place them in rooms containing unsupported weapons. Either retain old-roster rooms or require the compatible client for expanded-roster rooms. Unknown content in an unexpected snapshot must yield a safe supported-content message, never an enum crash or damaging shotgun fallback.
7. Budget per actor and per room, including six distinct equipped weapons and all synchronized streams/blasts. Test co-op/Versus team filtering, reconnect, late join, peer departure and stale/replayed input. Tune PvP damage separately on the server; solo seeds are not PvP approval.
8. Verify the server/client pair locally with delayed transport before any hosted rollout. Generate bindings only when contracts change. Client content unlocks remain disabled online until the matching server capability is present. Deployment/store distribution is a later release action, not implied by this plan.

## 8. Texture, VFX and audio budgets

The current manifest has **40 entries**. A read-only metadata estimate gives about **30.19MiB** non-lazy decoded RGBA and **1.69MiB** for the largest pair of lazy expansion boss atlases: approximately **31.88MiB** before a supply pod/dust atlas, new weapons or engine overhead. Floor height was assumed square in that estimate; it is not a runtime profile. Existing ≤32MiB pair tests make globally preloading eleven new gun sheets an unsuitable default.

- Keep the small old arsenal and add measured compact thumbnail art. Load detailed new weapon packets through shared acquire/release leases for the active local/remote roster. Loading the fifteen-item menu must not preload fifteen combat packets.
- A proposed 256×128 RGBA packet costs 128KiB decoded; a 256×256 packet costs 256KiB. These are allocation examples, not approved dimensions: prove native readability before choosing them. Eleven 256×256 packets add 2.75MiB; even a six-peer selection adds up to 1.5MiB before Hammer action art. Both exceed the estimated pair headroom. Total packaged/download size and simultaneous decoded residency must be reported separately.
- Retain the ≤32MiB decoded-art regression target by reclaiming measured duplication/resolution where visually safe; inventory both multiplayer wall variants and currently always-loaded support textures before choosing cuts. Do not reduce approved survivor art blindly or silently raise the target. Test the worst **valid** scenario in each mode: solo boss pair (Rush disables supply), solo boss + active supply, normal arena, and online six-player mixed roster. Do not pretend a smaller solo lease set covers online.
- Preserve lazy pending-load restart/disposal safety. Release only after users/pending render callbacks are gone. Count thumbnail and route-transition overlap, not just steady gameplay.
- Keep existing 256 primary-projectile / 40 combat-effect caps and other existing fire/mine/hostile/hazard budgets. New types must participate in a shared reservation ledger instead of bypassing `BulletComponent` registration. Rivet attachments are bounded state, not eight untracked explosion components per frame. Critical feedback must fit before damage is issued.
- Reuse `AttackVfx.explosion`/material atlas for Rivet/Mortar blasts, arena grading, debris/scorch and below-actor priority. Do not use clean abstract circles as finished explosion art. Reaper is a real metal silhouette; Rail is a material stake, not Marshal's continuous laser.
- Use shared clocks/phase animation, view culling and bounded particles for streams. Avoid per-particle collision checks, decodes, per-frame list allocation and whole-screen additive haze.
- Extend `generate_weapon_audio.py`, `generate_reload_audio.py` and preview tools with explicit cue manifests. Preserve CC0 provenance/hashes and approved mechanism extracts. New Cinder/Prism/Repeater loops need attack/sustain/release files and owned SoLoud handles; a group mute/lifecycle stop must silence all of them.
- Keep existing music arrangements/group gains and output recovery. Prewarm selected/visible content without decoding everything; prewarming must not block taps. New loop/cue mixing needs peak/headroom tests plus physical speaker/headphone listening.

## 9. Delivery sequence and gates

Complete vertical slices. Art, collision, upgrades, saves, online events and tests belong inside each weapon milestone.

| Stage | Deliverable | Exit evidence |
|---|---|---|
| **A — Baseline** | Capture current four guns, actual shotgun HUD, asset allocations and server/client fixtures; note existing working-tree changes. | Existing tests are reproducible; originals' muzzle/reload/cadence contracts recorded. No unrelated changes overwritten. |
| **B — Precision foundation + Burst Rifle** | Named atlas lookup, socket/pose model, typed runtime adapter and attack events; first full new gun. | Four originals match baseline; three separate burst releases, cancel/reload/save lifecycle, actual sprites/audio and online reconciliation work. Native sprite alignment reviewed. |
| **C — Rail Lance** | Charge/recovery timeline, finite-speed penetration and own art/reload. | One release per charge; wall/body sweep, attenuation/caps, aim cancellation, Reduced Motion and client/server marker fixtures pass. |
| **D — Rivet Driver** | Damage provenance, stable payload attachments, detonation/cue track and durable payload snapshot. | Host death, expiry/reload race, full-mag reload action, cap behavior and restart/Continue cannot double-blast or double-reward. |
| **E — Cinder Hose** | Fixed-time cone model, tick/proc caps, flame art and loop lifecycle. | Same damage across dt schedules; no through-cover hits or extra voices; phone warning visibility survives sustained fire. |
| **F — Reaper Disc** | Two-leg model, stable hit ledgers, blocked return/catch expiry and cassette animation. | No repeated body/weak-point farming; outbound/return art and collision agree; paused/saved/remote flights remain bounded. |
| **G — Scrap Mortar** | Primary range intent/marker, deterministic lob, grounded blast and breech reload. | Phone targeting is usable alongside independent grenades; server clips cover/owns damage; landing event and art agree. |
| **H — Belt-fed Repeater** | Spool model, indexed barrel sockets, belt reload, server cadence and audio loop lifecycle. | No damage/ammo during spin-up; correct muzzle per round; release/vent/background cannot leave a loop or fire intent running. |
| **I — Frost Shotgun** | Atomic three-pellet volley, bounded freeze/thaw/immunity, pump/reload and planted frozen-pose art/save/server support. | No pellet-stacked/permanent freeze or frozen bosses; interrupted attacks never release on thaw; readable poses and shared co-op immunity verified. |
| **J — Prism Cutter** | Heat resource, clipped beam ticks, explicit vent timeline and shared heat HUD. | No per-frame/beam-stamp damage; fractional cooling and auto/manual vent agree across native/server; old ammo code cannot invent rounds/perks. |
| **K — Spore Lobber** | Capsule rupture, four bounded patches, non-stacking timed damage and patch persistence. | Replacement/overlap/cover/terminal-event tests pass; friendly patches remain distinct from hostile poison on both floors. |
| **L — Breach Hammer** | Survivor action poses, head/hand sockets, swept melee contacts, cell reload and dash cancellation. | Actual posed head agrees with damaging sweep; no rear/wall contacts, repeated body hits or procedural anatomy distortion; all three survivor packets reviewed. |
| **M — Full fifteen-weapon pass** | Final compatible offers/fusions, normal unlock progress, catalog details, complete art/audio records and budget tuning. | All 15 independently meet their packet checklist; every weapon reachable normally and in Training; matching online support/gating and old migrations verified. |
| **N — Candidate review** | Full regression, release-mode builds, device playtest matrix, performance/audio captures and documented tuning. | No known incorrect damage, stuck input, replayed reward, missing art or lifecycle leak; creator reviews physical precision/comfort/balance. |

Burst first is a deliberate change from the prior Rail-first proposal: it proves the event/socket architecture with relatively low-risk swept bullets before charge, attachments or continuous damage make a regression difficult to locate. Do not batch all eleven enum additions before the first complete slice is working.

No reliable calendar estimate follows from file count. The largest uncertainties are temporal sprite quality, Hammer pose production, mortar thumb control, freeze interruption/thaw cleanup, stream/beam/patch readability, durable attachment identity and online texture pressure. Review evidence at each gate and adjust seeds/asset density before producing the next packet.

### Work packages and scope control

Track these independently with statuses **specified → model tested → sprites integrated → full slice verified → physical review → accepted**:

- **F1 contracts:** stable IDs/spec registry, primary resource types, event keys/provenance, native/server fixture format and safe old-content admission.
- **F2 precision tooling:** named crops/sockets, shared transforms, timeline player, non-destructive manifest authoring, overlay/contact-sheet/video capture and selected-roster leases.
- **F3 integration:** offer/fusion capability manifest, resource HUD, saves/profile unlock schema, fifteen-entry catalogs, input adapters, event correlation and loop lifecycle.
- **W01–W11 content:** Burst, Rail, Rivet, Cinder, Disc, Mortar, Belt, Frost, Prism, Spore and Hammer. Each uses the complete packet above. Their milestone order is independent of normal unlock order.
- **V1 acceptance:** original-four regressions, all 45 survivor pairs, 495 compatibility cells, 22 new-weapon/arena combinations, 11 × 8 × 2 = **176 new-weapon/boss-phase scenarios**, mixed online roster, lifecycle/migration, budget and native evidence. Seeded practice makes the 176 checks tractable; it is not 176 full campaigns.

UI previews, new runtime state, network rendering and final art are not optional polish to defer beyond “fifteen complete.” Optional work is restricted to the explicitly excluded features. At each gate record findings, remaining assets, code/tests, performance delta and unresolved human-review points. If a weapon fails its distinct-role or phone-control gate, revise that slot in the plan and still deliver eleven additions; dropping it changes the authorized target.

Do not promise a fixed delivery date before F1/F2 and the first full slice expose the actual art/timing cost. After Burst, estimate separate model/integration, sprite cleanup, audio and verification effort per remaining packet; give a range and contingency for Hammer anatomy, heat UI, freeze fairness and online resources. Scope cuts must be concrete feature changes for review, never a silent reduction from fifteen to ten.

## 10. Verification and definition of done

### Automated behavior and visual evidence

Extend existing suites rather than relying only on new mirrored implementation tests:

- `weapon_presentation_test.dart`, `weapon_ballistics_test.dart`, `combat_and_director_test.dart`: original behavior; close/far/swept impacts; all new phase, contact and cover rules, including non-stacking patches, heat, freeze immunity and melee sweep coverage.
- `art_contract_test.dart`, `sprite_playback_test.dart`, `performance_budget_test.dart`: named frames, crop/socket validity, actual decode allocations, clips/holds and bounded mixed-content load. Add focused weapon-pose and weapon-timeline fixtures.
- `build_system_test.dart`, `game_notifier_test.dart`: all 33 families × fifteen weapons, III/VIII extremes, no-effect exclusion, all six recipes, stale choices/rerolls, prompt grace and pickup refill while every new phase is active, including fractional cooling, winding spool, active freeze/thaw/immunity and active melee sweep.
- `run_store_test.dart`, `player_entrance_test.dart` and focused flight tests: old schema 1/2 saves, malformed optional snapshots, all reload phases, charge/burst cancel, payload host restore, disc ledgers, shell/patch terminal flags, retained heat/vent, retained freeze/thaw/immunity and spent melee swings. Pause/background/restart/route exit while loads and removals are pending.
- `multiplayer_contract_test.dart`, local fire/projectile presentation tests and TypeScript combat tests: shared specs, phase fixtures, maximum upgrades, room saturation, six-player mixed roster, team rules, correlation, delayed confirmation and old-client capability refusal.
- `loadout_flow_test.dart`, `online_preparation_test.dart`, phone/large-text layout suites: fifteen-item catalogs, locked inspection versus equipped, last-item scroll, kit/Start visibility, atlas readiness and inherited selections.

Use seeded encounters for isolated targets, aligned bodies, Shield Warden front/flank, weak points, nest/sentinel planted response, moving Skitters, cover edges, simultaneous deaths, all eight bosses in both phases and a boss pair. Compare 30-second and 90-second output including reload/charge delays, misses, travel and overkill; record single-target versus pack output rather than optimizing only a stationary DPS total. Test low-rate/high-rate dt, deliberate long frames and 50ms server updates. Use long soaks to find retained entities/voices/leases, not to claim phone FPS.

Capture transparent socket overlays and clean gameplay clips from the real renderer for each weapon; include muzzle contact, turning while firing, mirrored aiming, full/partial reload, empty hold, simultaneous grenade drag, dash and Reduced Motion. Golden images establish positioning; real-time playback establishes whether the animation lands.

During implementation run `make verify`, targeted Flutter tests and `make soak` when sustained modes are integrated. In the server repository run `npm run verify` and relevant `smoke:combat`, `smoke:prediction` and `smoke:projectiles` scripts with a local server. Build native candidates only after those checks. These are future validation steps; they were not executed as part of this documentation-only task.

### Physical review matrix

- All **45 survivor/weapon pairs**: first-boss slice, aim/reload/dash/grenade comfort and both handed layouts. All fifteen primaries on both arenas; eleven new weapons against all eight boss kinds, both phases, using practice scenarios.
- Starting builds, representative rank III and bounded rank VIII/two-fusion builds; compare original four against additions so each keeps a useful role.
- Smallest supported landscape phone, large text, fixed/floating/custom controls, Reduced Motion and aim assist. Review Cinder warning visibility, Rail readiness, Rivet expiry, Disc return, Mortar range control, Belt spool feedback, Frost escape utility/immunity fairness, Prism heat, Spore floor clarity and Hammer head/sweep alignment explicitly.
- Release-mode iPhone plus representative Android: 30-minute heat/memory/frame-time captures, active supply, boss pairs, developed builds and online mixed-weapon scenes. Record device, OS, build, duration, thermal condition, frame-time percentiles and allocation trend.
- Speaker/headphone listening with music, muted SFX, Bluetooth/interruption/foreground; stream loops must stop immediately and never multiply. Reconnect cannot replay old firing/reload cues.

### Completion checklist

- [ ] Fifteen primaries exist in authoritative definitions, real gameplay, Training, normal unlocks, menu/HUD, sprites, audio, saves and supported online rooms.
- [ ] Eleven additions have distinct tactical decisions and complete fire/reload/resource loops; none is a missing-art fallback or only a stat variant.
- [ ] Named frames, authored sockets, no-drift mechanisms and shared event timing meet the proposed precision checks at real gameplay scale.
- [ ] All four originals retain approved damage/cadence/reload/spread/impact rules; shotgun presentation discrepancy is resolved explicitly before changing it.
- [ ] Offers/fusions explain real effects; rank VIII and proc/flight limits hold; independent grenades remain usable.
- [ ] Old saved profiles/runs load, no entitlement is removed and no transient attack/reward replays after Continue or reconnect.
- [ ] The worst valid texture/effect/voice scenarios fit measured budgets, including online peers and route/load overlap.
- [ ] Analyzer/tests/build/soak evidence is retained; native animation, warning readability, controls, listening and balance have separate recorded human review.

The implementation may produce a testable fifteen-weapon candidate before the physical review passes. Successful headless tests, builds or installations must not be described as physical precision, comfort, performance or balance approval.
