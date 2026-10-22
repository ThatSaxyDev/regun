# Ten survivors and a stronger upgrade system

**Date:** 22 October 2026  
**Status:** design proposal only; no characters, stats, art, unlocks or upgrades are implemented by this document.  
**Goal:** define the three live survivors, expand to ten worthwhile choices, make existing power-ups understandable and useful, then add a controlled set of new build options.

All proposed numbers are initial balance candidates. Unlock difficulty should reward a different way to play, not purchase a stronger version of Rook. Physical balance, comfort, audio and readability require creator playtesting.

## 1. Source of truth and scope

This plan uses the current working source, including local changes, rather than treating the original four-weapon blueprint as the live game. The current solo/Training catalog contains **21 weapons, three survivors, 33 offered upgrade families and six fusions**. Long Dash is legacy-only and Scrap Cache is a fallback; neither counts toward 33. Eight bosses and two arenas already exist. Online admits a narrower weapon set; local parity work does not establish deployment.

Reviewed contracts:

- `lib/data/loadout.dart`: survivor stats, weapon properties and compatibility.
- `lib/models/player_profile.dart`, `lib/data/challenges.dart`: unlocks and settlement.
- `lib/notifiers/game_notifier.dart`: ranks, offers, reloads, guard, healing and saves.
- `lib/systems/combat_system.dart`, `arsenal_system.dart`, `grenades.dart`, `weapon_mobility.dart`: actual effect formulas and damage paths.
- `lib/components/game_utils/coin_component.dart`, `components/movement/boost_component.dart`, `components/weapons/bullet_component.dart`, `mine_component.dart`, `components/enemies/combat_enemy.dart`: pickup, dash, bounce, mine and burn behavior.
- [Progress](REGUN_PROGRESS.md), [complete-game blueprint](REGUN_COMPLETE_GAME_PLAN.md), [playtest guide](PLAYTEST_GUIDE.md), [XP progression](XP_PROGRESSION.md), [endgame weapons](ENDGAME_WEAPONS_REVIEW.md), [enemy reactions](WEAPON_ENEMY_REACTIONS.md), [reload policy](RELOAD_AND_SNIPER_FATIGUE.md) and [upgrade recovery](UPGRADE_RECOVERY_AND_REST_AIM.md).

The older plan's roster counts and reload statements are historical. The live universal tactical reload is 70% duration when manually reloading with ammunition remaining; empty reloads take full time. Both remain committed. Shotgun base is three pellets at 1.2 damage each and 3.2 seconds for five missing shells. This expansion does not silently undo those corrections.

**Deliverables when implemented:** ten complete survivors, a truthful survivor/upgrade reference, targeted improvements to existing families, eight new families (41 offered total), two additional fusions (eight total), visible unlock progress, compatible persistence, tests and device review. No new input button or arena is needed.

## 2. Precisely define the existing survivors first

These are current facts, not proposed buffs. HP means the integer health units currently displayed by the heart UI. Walking speed is before weapon weight; a survivor's size/art must not alter the shared player hitbox.

| Survivor | HP | Base walking speed | Primary damage scalar | Actual passive | Existing unlock |
|---|---:|---:|---:|---|---|
| Rook | 6 | 300 | 1.00 | No additional mechanical passive; balanced baseline | Available immediately |
| Scrapper | 6 | 345 (+15%) | 0.85 | XP attraction radius +80 units; Dash Mine damage ×1.40 | 500 cumulative enemy kills |
| Warden | 8 | 261 (−13%) | 1.00 | Starts with one guard; recharges after 20 active seconds while absent | Survive 480 seconds in an eligible run |

Important details to put in the reference:

- Baseline XP attraction is 180 units. Scrapper starts at 260; Scavenger adds to this radius. This is attraction, not an XP-value bonus, supply capture bonus or grenade radius bonus.
- Scrapper does **not** begin with Dash Mine. The 40% bonus matters only once mines are available. Base mine damage is `3.5 + effective Dash Mine rank`, before Scrapper's multiplier; blast radius is 185.
- The character damage field scales primary weapon release damage. Secondary paths are not universally multiplied by it. Chains inherit adjusted hit damage; fixed drone, burn, mine and grenade damage have their own formulas. Audit each weapon payoff before describing Scrapper as simply “all damage −15%.”
- Warden's guard consumes one accepted damage event, regardless of that event's HP amount. It is one charge, not armour percentage or an extra health bar. Scrap Armour uses the same guard and shortens its recharge; it does not add another shield.
- Warden's base guard returns after 20 active seconds. Scrap Armour's recharge is `20 − 3e` seconds: 17/14/11 at I/II/III and 6.5 at VIII. Picking Scrap Armour immediately grants guard.
- All three share the existing dash: 1450 speed, 150ms base duration, 1.6s base cooldown and full-dash protection. Afterimage extends recovery protection; it is not needed for protection during the dash.
- Actual walking is `(survivor base + Fleet Foot gains) × WeaponMobility`. Rook with Anchor Engine walks at 279; Scrapper at 320.85; Warden at 242.73. Weight does not slow dash.
- Existing unlocks stay earned. Do not revoke Warden from an old profile or reinterpret historic challenge IDs.

### Proposed treatment of the originals

Keep these base numbers during the first expansion pass. Give Rook a clear “Balanced” identity instead of inventing a perk only to fill a card. Make Scrapper's conditional mine bonus visible in the expanded detail, and explain Warden's shared guard. Their strength should first be measured against the new roster; any later buff gets its own evidence and migration decision.

## 3. Roster design rules

1. Each survivor gets one central passive, a visible silhouette and a real cost. One passive may have a small supporting clause; avoid bundles of unrelated bonuses.
2. Survivors change how a build is played. Weapons remain freely selectable; recommendations are not restrictions.
3. Later unlocks are more specialized, not stronger. Every survivor must function before receiving a lucky upgrade or fusion.
4. No new active skill, smaller hitbox, hidden damage immunity, extra grenade charge, free fusion, XP multiplier or permanent account stat bonus.
5. Survivor passives occupy no upgrade-family slot. They do not grant ranks or satisfy fusion prerequisites unless explicitly stated; none proposed here do.
6. Use active simulation time. Pause, picker, deployment and background freeze clocks; Continue preserves them. Restart clears temporary combat resources.
7. Starting HP is not an invitation to multiply every survivability layer. Healing/guard/grenade and proc combinations need explicit limits.

## 4. Proposed ten-survivor roster

The seven additions below are working names. HP/speed are exact candidate baselines; the details following the table define their effects and exclusions.

| Survivor | Role | HP | Speed | Damage baseline | Signature and price |
|---|---|---:|---:|---:|---|
| Rook | Generalist | 6 | 300 | 1.00 | Familiar baseline; no specialist bonus |
| Scrapper | Mobile salvage/mines | 6 | 345 | 0.85 primary | Wider pickups and stronger mines |
| Warden | Defensive anchor | 8 | 261 | 1.00 | Shared recharging guard, slow walking |
| Flint — new | Reload duelist | 6 | 291 | 0.95 primary | Reloads 12% faster; completed reload empowers next release |
| Vesper — new | Dash skirmisher | 5 | 330 | 0.95 primary | Brief offensive window after a completed dash |
| Fuse — new | Ordnance specialist | 6 | 285 | 0.90 primary | Stronger grenades, shorter recharge; primary damage cost |
| Moth — new | Deliberate ignition | 6 | 300 | 0.90 primary | Controlled innate burn and stronger burn damage |
| Coil — new | Electrical conductor | 5 | 300 | 0.95 primary | Periodic innate chain and stronger electrical secondaries |
| Suture — new | Sustained recovery | 7 | 276 | 0.90 primary | Predictable kill-earned healing, limited by time |
| Harrow — new | Elite/boss hunter | 5 | 300 | Target dependent | More primary damage to elites/bosses, less to ordinary enemies |

### Flint — the ash-coated breach mechanic

**Passive: Chamber Ready.** Reload duration ×0.88. Completing a reload that replenishes at least one primary unit gives the next weapon release +20% primary damage. One charge, expires after four active seconds, consumed on release even if it misses. Tactical and empty reloads qualify; Extended Tube's pickup refill does not.

A release means one trigger event: all shotgun pellets, one Burst Rifle burst, or one committed cone/lob/charged shot. Continuous weapons get a single 100ms damage slice; never an entire held stream. Payload is captured at release so delayed hits cannot reuse the charge. No free ammunition or early firing. Sleight of Hand combines multiplicatively with the 12% discount, then existing weapon minima apply; do not reduce the shotgun below its current 850ms pre-tactical minimum.

**Play:** choose safe reload opportunities instead of always emptying a magazine. **Cost:** −5% primary damage and −3% speed. **Try:** Revolver, Shotgun, Rail Lance. **Avoid:** granting a charge when Continue restores an already completed reload.

**Art:** squared soot-black welding hood, folded copper visor, short apron and offset shell belt. Warm copper accent; silhouette must differ from Warden's broad armour. **Card:** “Faster reloads. Next release hits harder.”

### Vesper — the torn-cloak outrider

**Passive: Slipstream.** After a dash ends, primary damage is +18% for one active second. May activate once every four active seconds; dashing more often neither stacks nor extends it. Protection remains the ordinary dash/Afterimage contract. Vesper gains no additional invulnerability or extra dash charge.

For delayed projectiles the bonus is captured on release. Continuous fire samples only its eligible slices. Grenades, mines, drones and DoT do not receive the window bonus.

**Play:** dash across a firing angle and punish from the new position. **Cost:** one less HP and −5% baseline primary damage. **Try:** Carbine, Reaper Disc, Cyclone Breacher. **Risk check:** Quickstep must not produce permanent uptime.

**Art:** narrow storm hood, split charcoal cloak and pale teal ankle wraps; head shape and asymmetrical hem identify Vesper without relying on colour. **Card:** “Dash, then strike. One less heart.”

### Fuse — the demolition courier

**Passive: Packed Charge.** Grenade blast damage +20%. Sequential recharge is `max(10, 18 − 1.5e − 2)` seconds, where `e` is Ordnance Cycle's effective rank. Heavy Payload and Fuse add their bonuses before multiplying base grenade damage: `8 × (1 + .20e + .20)`. Still two charges, same throw separation, flight, fuse and friendly/self rules. Radius is unchanged.

No bonus to mines, mortar, rivet blasts, Anchor or Fragmentation shards. The grenade damage resolver applies it once to the actual grenade explosion. Fuse's base grenade is 9.6 damage with a 16-second recharge; at Heavy Payload VIII it is 16.8 before any separately approved mode tuning.

**Play:** place independent throws while the gun handles stragglers. **Cost:** −10% primary damage and −5% speed. **Try:** a precise gun plus Heavy Payload/Wide Burst. **Risk check:** final recharge never drops below ten seconds, including new fusions.

**Art:** angular iron blast hood, compact padded collar and two visible brass canisters; no enormous backpack covering the gun. **Card:** “Stronger grenades. Faster recharge.”

### Moth — the furnace tender

**Passive: Slow Ember.** The first damaging primary contact when ready ignites one target at base 0.35 damage per 0.5-second tick for three seconds; one proc per second globally per survivor, regardless of pellets, piercing, burst or target count. Acquired Hot Shot can ignite normally. All player-owned burn damage gains +25%; refreshing the same burn keeps the stronger tick value and refreshes duration rather than stacking instances.

Innate ignition uses the shared burn contract, so Accelerant may spread it once when acquired. It grants no Hot Shot rank and cannot unlock Firebreak alone. Apply the bonus once: inherited/spread burns do not gain another 25%. Cinder's separate residual burn and Firebreak ground need explicit ownership so they receive the bonus once too. Spore poison, direct flame hit damage and blast damage are excluded.

**Play:** tag targets, reposition, let fire finish them. **Cost:** −10% primary damage. **Try:** Cinder Hose, Spore Lobber with a separate ignition source, Hot Shot/Accelerant. **Risk check:** never allow repeated burn replacement by weaker sources or recursive spreading.

**Art:** worn charcoal furnace mask, low rounded hood, ember-red scarf and ash-stained gloves. Tiny ember detail only during a real ignition; no permanent glowing aura. **Card:** “Hits kindle fire. Burns hit harder.”

### Coil — the broken-grid technician

**Passive: Return Current.** Count successful weapon releases that damage at least one target. Every fifth qualifying release sends one additional arc from its first victim to the nearest unvisited enemy within 200 units, for 50% of that first contact's adjusted damage. Maximum one innate arc per 0.8 seconds; continuous weapons may contribute one qualifying release per 0.5 seconds. A burst/pellet fan contributes at most one. At five, the counter waits for the next eligible hit if the gate is closed; discharge consumes the counter even with no second target.

Electrical secondary damage from innate arcs, Arc Caster chains and Static Charge gains +10%, once at the final resolver. Coil's arc cannot arc again, ignite, ricochet, generate shards or count toward the five releases. It shares chain budgets and target visitation with the initiating hit; if budget is unavailable, consume without queuing a delayed attack. Conductive Core may improve acquired chains but does not multiply Coil's fixed one-jump proc.

**Play:** connect separate enemies rather than tunnelling one boss. **Cost:** one less HP and −5% primary damage. **Try:** Arc Caster, Burst Rifle, Static Charge. **Risk check:** Repeater/Prism cannot turn frame ticks into unlimited discharges.

**Art:** flattened insulated cap, one ceramic ear guard, short cable spool and muted blue-green trim. No electrical screen flashes or enemy-warning coloured halo. **Card:** “Every fifth hit release sends an arc.”

### Suture — the field surgeon

**Passive: Triage.** Every 15 credited enemy kills restores one HP if injured, with at least 12 active seconds between heals. The counter caps at 15. At full health it may bank one heal; after actual HP loss it is consumed on the next active update if the cooldown permits. Guard absorption is not health loss. No overheal and no death prevention; a lethal hit remains lethal.

All player-owned kills can count, including burns and grenades. Field Medic remains available, but all kill-earned healing on Suture shares the same 12-second healing gate. A Field Medic proc cannot double-heal the triggering event; if it heals early, it resets the gate without wiping an incomplete Triage counter. The precise pending/cooldown/counter state is checkpointed.

**Play:** sustain an extended run through controlled crowd clearance. **Cost:** −8% speed and −10% primary damage. **Try:** sustained crowd weapons, Vitality, guard. **Risk check:** easy enemies must not produce effectively unlimited HP per second.

**Art:** canvas respirator, cropped ivory hood, compact medical satchel and dark red cloth tabs; avoid a modern white coat or bright hospital cross. **Card:** “Earn a heart every 15 kills. Heals have a cooldown.”

### Harrow — the condemned tracker

**Passive: Quarry.** Primary damage ×1.15 against enemies tagged elite or boss; ×0.90 against ordinary enemies. No additional global damage scalar. Secondary damage inherits a primary adjustment only where that path already inherits hit damage; fixed grenades, drones, mines and DoT gain no new quarry multiplier.

A spawned ordinary add remains ordinary. Shield absorption/armour still resolve normally; this does not pierce guards, expose weakpoints or alter thresholds. Executioner may combine with Quarry once. Boss weakpoints must use their owning boss's classification and must not apply the bonus a second time.

**Play:** prioritize dangerous targets and survive a weaker opening. **Cost:** one less HP and weaker ordinary clearance. **Try:** Longwatch Sniper, Revolver, Twin Verdict, Executioner. **Risk check:** boss burst must not erase entire warning phases.

**Art:** angular bone-coloured tracker mask, battered long collar and single rust-red shoulder trophy. No huge antlers or cloak obscuring telegraphs. **Card:** “Hunts elites and bosses. Weaker against the horde.”

## 5. Unlocks that reward play, not repetitive grinding

Keep the existing two unlocks intact. New conditions below apply to normal eligible runs, never Training/Boss Rush. Retain current Aim Assist policy: eligibility for each new challenge must be explicit in data; assisted records remain separately labelled. Recommend allowing accessibility assists for survivor unlocks, without merging their competitive records.

| New survivor | Proposed unlock | Why it fits |
|---|---|---|
| Flint | Complete 40 reloads that restore ammo, across normal runs | Teaches reload management; not a weapon-specific lottery |
| Vesper | Survive six minutes in one run and complete 30 dashes in that run | Early mobility goal without demanding a no-hit boss |
| Fuse | Kill 120 enemies with grenades across normal runs | Demonstrates the independent secondary tool |
| Moth | Defeat 150 burning enemies across normal runs, with fire or another finishing source | Encourages ignition; Cinder or Hot Shot provides access |
| Coil | Deal electrical chain damage to 200 distinct enemy instances across normal runs | Introduces chain builds; Arc or Static Charge supplies access |
| Suture | Restore 40 missing HP through in-run healing across normal runs | Rewards survival; excludes deployment/reset/full-health healing |
| Harrow | Defeat 15 elites and three bosses across normal runs | A later specialization with multiple valid weapons |

Store explicit event counters and reconcile only at idempotent settlement. If counters are absent in old saves, start them at zero; use already recorded boss/elite totals for Harrow, but never invent grenade kills, reloads or heals from total kills. Save/Continue cannot duplicate awards. Unlock after settlement and show progress on the locked card; Training exposes all ten immediately.

Do not increase the existing “Everyone Out” requirement from the original three to ten and revoke an earned emblem. Preserve that achievement and add a separate **Ten Against the Breach** collection/mastery goal for all ten. Likewise preserve the existing six-fusion completion reward and add a separate eight-fusion goal.

## 6. Current power-up reference: what they actually do

Use `r` for purchased rank and `e = min(r,3) + .30 × max(r−3,0)` for most scalar effects. Thus I/III/VIII give 1/3/4.5 effective ranks. Sleight of Hand and Quickstep use a .20 tail, ending at 4.0. Count effects may use raw ranks with separate caps; never infer count from `e`. All 33 offered families currently cap at VIII.

This table describes the inspected baseline. Weapon-specific branches and global limits still apply; any implementation must produce a generated per-weapon reference rather than assuming these concise formulas cover every gun.

| # | Live family | Current effect / important limit |
|---:|---|---|
| 1 | Heavy Load | Adds .35 primary damage scalar per rank I–III, .10 per IV–VIII; starts at 1, reaches 2.55 at VIII. Not +35% to an already boosted total each time. |
| 2 | Quick Trigger | Supported firing interval ×`.85^e`; VIII is about .481 of base. Prism excluded; committed burst/release semantics still apply. |
| 3 | Extended Tube | Carbine +6 ammo per I–III, +2 later; other guns +2 then +1. Refills/cancels reload once on pickup. Prism capacity capped at 24. Shotgun retains five-shell reload-duration cap. |
| 4 | Sleight of Hand | Shotgun stored full-reload cap 2000/1500/1000ms at I/II/III, then −30ms per rank to 850ms at VIII; short partial reload uses the lesser normal duration. Other guns ×`.8^e`, VIII .4096. Tactical ×.70 applies afterward. |
| 5 | Scattershot | Base shotgun 3→5→7→9 pellets at I–III; IV–VIII tighten spread. Other guns use capability-specific counts: Frost up to 9, Cyclone up to 9 at II, Rail/Repeater up to 3. Validate the late spread benefit for every admitted weapon. |
| 6 | Piercing Rounds | Additional body penetrations from raw rank, weapon caps and innate pierce. Rail retains damage after penetration at .65; piercing does not reset distance. |
| 7 | Long Barrel | +60 range per I–III, +24 later; +300 at VIII. Actual targeting/flight must honour weapon range and hard caps. |
| 8 | High Velocity | +200 speed per I–III, +40 later; max +800 over base and absolute 2000. It changes speed, not firing cadence. |
| 9 | Fleet Foot | +50 walking units per I–III, +12 later; +210 at VIII before weapon weight. Dash unchanged. |
| 10 | Vitality | +1 max HP and +1 current HP per purchase; +8 max at VIII. |
| 11 | Field Medic | Every credited kill has `.05e` chance to heal one HP: 5% at I, 15% at III, 22.5% at VIII. No general time gate in the inspected path. |
| 12 | Scrap Armour | Immediately grants the shared one-hit guard. Recharge `20−3e` seconds: 17 at I, 11 at III, 6.5 at VIII. Same guard as Warden. |
| 13 | Quickstep | Dash cooldown `clamp(1.6−.25e, .6, 1.6)` seconds; VIII .6. |
| 14 | Afterimage | Adds 70ms post-dash protection at I, then +15ms per further raw rank: +175ms at VIII. Ordinary dash itself is already protected. |
| 15 | Scavenger | XP attraction +60e units: 240 total at I, 450 at VIII; Scrapper adds another 80. No extra XP value. |
| 16 | Lucky Find | Special-family offer weight ×`1+.35e`; acquired-family weight already ×1.5 separately. VIII special weight ×2.575. Does not promise higher rank or rarity. |
| 17 | Hot Shot | Primary hits refresh a three-second burn, `.25+.20e` damage each .5s tick: .45 at I, 1.15 at VIII. Shared burn is not one stacked instance per pellet. |
| 18 | Accelerant | Burning deaths spread that burn within `100+30e` units; spread burns cannot spread again. Firebreak can add ground fire. |
| 19 | Static Charge | Primary contacts have `.12e` chance to arc: 12% at I, 54% at VIII. Default chain retention .65 per hop; Arc's innate chains use .85. Global chain budget applies. |
| 20 | Conductive Core | Raw rank adds chain hops and +55 range per hop-search; base search 170, or 240 for Arc. Can be obtained without a non-Arc chain source today. |
| 21 | Dash Mine | One mine per dash; .35s arm, eight-second lifetime, 185 blast radius, `3.5+e` damage; 12 live-mine cap. Minefield creates three per dash within that cap. |
| 22 | Fragmentation | Shared explosions emit `4+2r` secondary shards at 20% blast damage each, under projectile limits. At VIII requests 20 shards; not another set of primary hits. |
| 23 | Ricochet | Adds raw-rank bounces on supported rounds; next-target search 500, visited targets excluded. Does not replenish range. |
| 24 | Bank Shot | Bounce damage multiplier `min(1.4,.7+.15e)`; .85 at I, 1.15 at III, 1.375 at VIII. Final projectile damage capped at twice its original damage. |
| 25 | Last Shell | Final-ammo release ×`1+.6e`; ×`1+.9e` with Breach Engine. VIII unfused ×3.7. Weapons need a real last-round semantic. |
| 26 | Breach Loader | First release after a qualifying reload ×`1+.5e`; ×`1+.8e` fused. VIII unfused ×3.25. One charge, not every shot in a magazine. |
| 27 | Orbit Drone | One drone shot per `max(.3,1−.15e)` seconds, damage `.6+.35e`, target range 600. VIII .325s and 2.175 damage per shot; fusion makes three shots/drones. |
| 28 | Targeting Link | Primary hits mark enemies; drone prefers marks and multiplies marked damage by `1+.3e`, up to ×2.35 at VIII. Does not amplify all weapon damage. |
| 29 | Shrapnel | Non-secondary kills have `.18e` proc chance; `3+r` shards at .65 damage in a short forward cone. VIII 81% and 11 shards, subject to projectile budget. |
| 30 | Executioner | Primary damage ×`1+.3e` against targets already below 35% HP; VIII ×2.35. No instant execute, and fixed secondary damage does not gain it. |
| 31 | Heavy Payload | Grenade damage `8×(1+.20e)`: 9.6/12.8/15.2 at I/III/VIII. |
| 32 | Wide Burst | Grenade radius `205×(1+.08e)`: 221.4/254.2/278.8 at I/III/VIII. Radius, not diameter or damage. |
| 33 | Ordnance Cycle | Sequential recharge `clamp(18−1.5e,10,18)` seconds: 16.5/13.5/11.25 at I/III/VIII. Always two charges. |

**Existing fusions:** Firebreak (Hot Shot III + Accelerant II), Storm Circuit (Static Charge III + Conductive Core II), Minefield (Dash Mine III + Fragmentation II), Pinball (Ricochet III + Bank Shot II), Breach Engine (Last Shell III + Breach Loader II), Hunter Swarm (Orbit Drone III + Targeting Link II). Each also needs an explicitly spent core and an available fusion slot. At most two banked cores and two equipped fusions remain the rule.

Some fusion copy needs correcting: Storm Circuit currently adds two chain hops; its description mentions marked clusters without requiring marks. Breach Engine strengthens first/final releases; it does not create a literal reload explosion. Document the actual runtime before writing new card promises.

## 7. Strengthen deliberately: clarity, useful first picks and fair ceilings

“Stronger” should mean a pick produces a useful, visible result. Several families already scale aggressively. Do not buff healing, pellets, guard, firing rate and last-round multipliers together to make the whole game easier accidentally.

### A. Fix dead or misleading choices first

- **Dependency-aware offers:** Accelerant requires Hot Shot, Moth or another compatible shared ignition source; Conductive Core requires Arc Caster, Static Charge or Coil; Bank Shot requires acquired/innate ricochet; Targeting Link requires Orbit Drone; Fragmentation requires a real explosion source, including universal grenades. A passive may enable an offer without granting recipe ranks. If the source is later removed by a Training swap, explain/disable the dependency consistently rather than offering a false benefit.
- **Bank Shot buff candidate:** change bounce multiplier to `min(1.4,1+.08e)` (I 1.08; III 1.24; VIII 1.36). This gives rank I a positive payoff. Preserve twice-original-damage cap, cumulative distance and no target repeats. Existing ricochets without Bank Shot keep their own baseline retention; acquiring the family enables the new formula.
- **Accelerant buff candidate:** spread radius `130+35e` (I 165, III 235, VIII 287.5), at most six nearest visible targets per death. Preserve one-generation spread and existing ground-fire limits. More useful first purchase, bounded late work.
- **Orbit Drone buff candidate:** base shot damage `.8+.35e` instead of `.6+.35e`; unchanged cadence/range/count and no primary proc triggers. Test Hunter Swarm + Targeting Link before accepting.
- **High Velocity:** show actual next speed; stop offering ranks that would add zero due to a cap. Resolve any weapon branch where late Scattershot/Long Barrel ranks are offered with no real effect; do not disguise dead ranks with vague copy.
- **Field Medic rebalance candidate:** keep its 5–22.5% probability but add a six-active-second global healing gate. Do not bank failed/gated procs. Suture uses its stricter 12-second gate. This is an explicit sustain reduction paired with roster expansion, not a hidden buff.
- **Keep initially:** Heavy Load, Quick Trigger, Extended Tube, Sleight, Fleet Foot, Vitality, guard, dash, grenade and first/final-shot values. Review measured outliers before changing them. Final-shot and first-shot bonuses currently multiply when one release qualifies for both; do not silently add another unbounded multiplier.

These changes are proposed separately from the baseline table. Apply a balance version and save policy; never quietly reinterpret an in-progress build.

### B. Make the UI state the actual next gain

Compact offer: name, rank, one real delta, one limitation if necessary. Examples: “Bank Shot II — Bounce damage 1.08× → 1.16×”; “Ordnance Cycle II — Recharge 16.5s → 15s”; “Afterimage II — Recovery protection 70ms → 85ms.” Expanded details show base/current/next and applicable source. Locked cards show a numeric challenge counter.

Show source labels such as PRIMARY, GRENADE, BURN and DRONE in expanded details. Distinguish damage scalar, multiplier, chance, radius and count. Keep all math out of routine player copy except meaningful current values. Loadout shows HP, unweighted walking, equipped-weight walking, passive and drawback, plus one short identity sentence. Preserve the pinned tabs/assembled-kit layout and custom pixel UI.

## 8. Eight new power-up families: 33 → 41

Add these only after the current catalog audit. All cap at VIII; use the existing `e` curve unless explicitly noted. Values below are candidate totals at I/III/VIII, not cumulative percentages added once per purchase. Utility remains available independently of the six-special-family cap; special additions compete for those six slots.

| Family | Group | Exact candidate effect | I / III / VIII | Guardrail / purpose |
|---|---|---|---|---|
| Brace Loader | Utility | Walking speed while actually reloading ×`1+.04e` | +4% / +12% / +18% | Reload only; no dash bonus or ammo effect. Helps heavy guns escape without cancelling reload. |
| Sure Foot | Utility | Reduce incoming slows by `min(.40,.08e)` | 8% / 24% / 36% reduction | Reduce the lost-speed portion, not damage/stagger; e.g. 40% slow becomes 25.6% at VIII. No immunity or change to weapon weight. |
| Scouring Heat | Special | Player burns deal ×`1+.10e` damage against elite/boss targets | +10% / +30% / +45% | Needs burn source; one modifier per damage event, including inherited burns. Gives DoT a priority-target route. |
| Faraday Reserve | Special | Electrical chains retain an extra `.02e` of prior-hop damage, capped at .92 retention | +.02 / +.06 / +.09 | Needs chain source. Standard .65→.74, Arc .85→.92 at VIII. No extra hops/procs. |
| Blast Harness | Utility | Grenade/mine blasts apply ×`1+.10e` displacement to movable normal enemies | +10% / +30% / +45% | Damage/radius unchanged; same impact cooldown, mass and displacement caps. Planted actors remain planted. |
| Exposed Seam | Special | Primary hits on a frozen enemy deal ×`1+.06e` damage | +6% / +18% / +27% | Frost/compatible freeze source required. No freeze extension or new freeze chance; bosses only if genuinely freeze-eligible. |
| Measured Shot | Special | After at least .8 active seconds without releasing primary fire, next release gains `.08e` additive damage bonus | +8% / +24% / +36% | Consume at release, including a miss; once per burst/fan. Charge/hold preparation can qualify; continuous fire gains one slice only. |
| Close Quarters | Special | Primary contact inside 160 muzzle-path units gains `.06e` additive damage bonus | +6% / +18% / +27% | First swept contact and cumulative travel, compatible direct hits only; no grenade/DoT/pulse or reset on bounce. Encourages risky proximity. |

For new conditional release bonuses (Flint, Vesper, Measured Shot, Close Quarters), add eligible bonuses into one bucket capped at +60%, then apply once alongside existing damage systems. This cap does not change old Last Shell/Breach Loader behavior. Harrow's target scalar and existing distance bands resolve once separately. Show a capped next gain truthfully.

New special families require a useful source before offering. Do not place Exposed Seam in a non-freezing build or Faraday Reserve in a build with no chain. Survivor innate sources can qualify, but fusion recipes still require bought ranks.

**Not in this pass:** free resurrections, permanent extra grenade charges, lifesteal per pellet, unlimited summons, slowing all bosses, global cooldown resets and another generic damage upgrade. A Rupture family from the older arsenal proposal remains deferred; it must not appear as an undocumented ninth addition.

## 9. Two new fusions without automatic power inflation

Keep existing III/II recipe thresholds, explicit core action and two total fusion slots. No survivor has a private mandatory recipe.

| Fusion | Recipe | Candidate payoff | Bound |
|---|---|---|---|
| Kiln Pact | Hot Shot III + Scouring Heat II | A burning elite/boss death leaves one short shared Firebreak-style patch at its body | Same existing ground-fire budget; one patch per death even with Firebreak, no recursive spreads/procs or new blast |
| Ground Wire | Static Charge III + Faraday Reserve II | Every fourth successful electrical discharge gains one extra hop at its current retention | Shared chain budget, at most one bonus hop per second; counter once per discharge, not per victim; no recursion |

These create elite-burning and efficient-lightning choices rather than merely increasing the two strongest existing fusions. Test them against Firebreak/Storm Circuit before accepting. All fusions remain broadly available; Moth/Coil passives never replace a recipe purchase. Do not introduce a third fusion slot to accommodate the expansion.

## 10. Offer economy and interaction contract

- Preserve current XP curve (8,18,35,59,90…), funded offers, four-active-second post-choice grace, overflow, separate supply offers and explicit core use. No extra upgrade screen merely for choosing a new survivor.
- Preserve three distinct eligible choices, reroll/ban costs, six special families, VIII caps and fallback Scrap Cache. Do not return an empty screen when prerequisites/caps exhaust the pool.
- More families dilute desired picks. Candidate offer rule: when a useful owned family is eligible, reserve one of three slots for a weighted owned-family upgrade; draw the other two normally without duplicates. With no owned family, draw three normally. This is a proposal replacing that slot's old weighting, not a fourth choice or a guaranteed fusion component.
- Lucky Find continues to bias special choices; the reserved slot applies the same legal pool and relevant weights. Measure recipe completion and diversity with/without it. Bans, incompatibility and max rank always win.
- Any new primary proc gets a release ID so a pellet fan, burst or lingering segment cannot repeatedly claim it. Delayed hits carry the captured release context. Secondary events cannot become primary through a new passive.
- Existing projectile 256, live-mine 12, floor-effect, chain, VFX, texture and encounter caps remain authoritative. New content does not justify raising emergency crowd caps.
- Crowd displacement always uses occupancy/wall/cover rules. Bosses/nests/sentinels stay planted. Never cancel an enemy warning or erase a committed hazard as a survivor perk.
- Upgrade confirmation keeps its existing once-only recovery pulse and instantaneous nearby hostile-bullet clear. New passives do not fire on reroll, ban, opening a menu, restoring a picker or a stale tap.

## 11. Art, motion and sound production plan

Use the game's worn iron, ash, cloth and restrained brass language. Each new survivor needs a recognizable head/shoulder outline, asymmetry and one accent; palette swaps alone are insufficient. Preserve Rook's accepted branding and shelter artwork.

1. Produce a ten-survivor silhouette sheet beside Rook/Scrapper/Warden at actual gameplay and catalog size. Check greyscale recognition and confusion with enemy heads.
2. Approve seven concepts before finishing atlases. Then produce every state/direction the current survivor renderer uses: idle/walk/dash/hurt/death/deployment and required facing coverage; inspect existing assets to enumerate exact frames. Do not assume nine pet animation states or generate a disconnected portrait-only asset.
3. Maintain current body footprint, weapon sockets, ground contact, shadows and arena grading. Check all 21 weapons across all ten bodies and representative facings; bulky props cannot hide guns, grenade preview, HP-loss cue or warnings.
4. Use subtle material feedback only on actual passive activation. No constant halo, guard wreath, flashing neon burn or screen-wide electrical effect. Reduced Motion holds art and omits decorative motion while preserving state feedback.
5. Reuse appropriate recorded mechanism/material sounds at restrained gain before adding new cues. If new recordings are needed, keep provenance/hashes outside packaged assets and preview mix/headroom. Do not play a new voice for every chain victim, burn tick or heal counter increment.
6. Lease only the selected survivor's gameplay art and currently visible catalog portraits. Release safely across pending loads, route disposal and Training swaps. Re-measure the existing 32MiB decoded boss-pair budget; adding seven installed atlases does not authorize loading all seven.

Art completion includes catalog portrait, gameplay atlas, passive icon, concise copy, mount validation and death/landing review. Unlock animation can be modest; menu atmosphere stays unchanged.

## 12. Implementation sequence and ownership

### Phase 1 — freeze and expose the baseline

Create a structured survivor definition keyed by stable ID, with stats, passive ID, drawback, unlock and display metadata. Extract upgrade formulas/compatibility to definitions/resolvers shared by runtime and descriptions. Generate current/next details from those resolvers; avoid duplicating 41 formulas in widgets.

Audit all 21 weapons' damage sources, release semantics, innate effects, reload minima and compatibility. Record a 21×41 compatibility matrix. Correct baseline copy first. Capture comparative baseline runs before buffs. No new artwork is necessary to prove these contracts.

### Phase 2 — repair existing choices

Implement prerequisite-aware offers, truthful capped-rank eligibility, candidate Bank Shot/Accelerant/drone improvements and the explicit Medic gate behind a balance revision. Validate existing six fusions, funded XP/supply flow and current survivors. Compare outcomes before adding new sources of damage.

### Phase 3 — prove the survivor framework with two additions

Implement Flint and Fuse with temporary existing art clearly confined to development/Training. Prove reload event and grenade source ownership, new challenges, snapshot validation, details UI and lifecycle behavior. Temporary art is not a shipped survivor. Finish/approve their art before calling the slice complete.

### Phase 4 — remaining five survivors

Add Vesper/Suture, then Moth/Coil, then Harrow. This order proves timed windows and healing before burn/chain ownership and elite classification. Each gets its own counters, checkpoint fields, art, copy, unlock and representative builds. Do not ship seven enum entries routed through Rook's fallback behavior/art.

### Phase 5 — expand the upgrade catalog

Add Brace Loader, Sure Foot and Blast Harness first; add the five special families once their dependencies work. Trial the offer reservation against dilution. Add two fusions last. Keep catalog counts and collection milestones synchronized.

### Phase 6 — compatibility, online and candidate review

Solo/Training first. Add shared fixtures and authoritative server implementations for every admitted survivor/effect; negotiate capabilities and hide unsupported choices on older servers. Server derives survivor stats, proc eligibility, clocks, damage and challenge counters from authenticated state. The client cannot award HP, charge counters, damage or unlocks. Co-op effects are owner-scoped; Versus gets explicit reviewed tuning rather than blindly applying PvE heal/proc rules.

No public server rollout, installation or implementation is performed by this plan. Preserve whatever release identity is current at implementation time; do not reset it from historical addenda.

### Persistence details

- Append stable character IDs; do not rename the original IDs or rely on enum ordinal position. Old profiles and saves must load unchanged.
- Add optional validated passive state: cooldown, counter, charged release expiry, mark ownership where needed. Reject non-finite/out-of-range values. Pending actions cannot replay after Continue.
- Recompute derived bonuses once from saved base/ranks/passive version. Never serialize a boosted walking/damage value and apply the survivor multiplier again.
- Preserve an in-flight run's balance revision until it ends where feasible; otherwise implement a documented one-time migration with fixtures. A change to Medic or bounce damage is still a balance change even if the save schema is unchanged.
- New progress counters settle once per run ID. Training changes neither profile unlocks nor mastery; reset/recovery does not farm healing/reload counters.
- Widen all hardcoded three-character switches, collection completion checks, art loaders and online validators. Replace the current loadout's Scrapper-versus-Warden lock-text branch with actual definition-driven unlock text.

## 13. Balance targets and verification

Targets are review triggers, not claims that simulations prove fairness. Compare within the same weapon, arena, upgrades, encounter seed and assist settings.

| Measure | Initial acceptance target |
|---|---|
| Generalist value | Rook remains comfortable and competitively useful; no specialist universally dominates it |
| Specialist upside | Roughly 10–20% improvement in its intended scenario, paid for elsewhere; investigate larger sustained gains |
| Overall outcomes | Once enough comparable human runs exist, investigate survivor median survival/boss-clear differences over 15%; do not balance from tiny samples |
| Build freedom | At least three useful weapon pairings per survivor, including one starter gun; no required fusion |
| Opening | Every survivor can clear early pressure with base kit and ordinary offered choices |
| Sustain | No immortal kill/heal loop; guard, Medic and Suture still leave meaningful vulnerability |
| Burst/control | No permanent slow/stagger/protection loop; no normal-health boss phase erased by unreviewed multiplier stacking |
| Choice quality | Every offer gives at least one legal, positive benefit; no stranded support purchase |
| Presentation | Actual phone can identify passive payoff and hostile warnings without extra HUD clutter |

### Automated checks

- Table-driven formulas for ranks 0/I/III/IV/VIII, caps and negative/non-finite inputs. Verify examples in this document against the final resolver output.
- Ten-survivor ×21-weapon baseline initialization/swap/checkpoint coverage (210 combinations); focused combat tests for risky interactions rather than claiming initialization proves all combat.
- Flint × tactical/empty/partial reload × Sleight × Extended Tube; no restored-charge duplication. Vesper × Quickstep × Afterimage; protection/window freeze and expiry.
- Fuse × all grenade upgrades × fragmentation, with exactly one explosion and ten-second recharge floor. Scrapper mines remain independent.
- Moth × Hot Shot/Cinder/Accelerant/Firebreak/Kiln Pact; stronger-burn refresh, owner attribution and single spread/bonus. Coil × Arc/Static/Core/Storm/Faraday/Ground Wire under chain saturation.
- Suture × Medic × guard × damage/death × full HP; credited kills, pending heal and shared cooldown. Harrow × boss weakpoint × armour × Executioner × distance bands.
- Release-count tests for shotgun fans, burst rounds, continuous ticks, piercing, ricochets, delayed cones/ground sections and killing the first target immediately.
- Offer seeds with prerequisites, incompatible weapons, six occupied special families, bans, maxed pool, reserved slot, rerolls and fallback. Existing purchased recipes remain valid.
- Golden/shared fixtures for any supported server rules. Old schema/profile/checkpoint fixtures, restart/Continue and idempotent settlement. Large text, narrow landscape, mirrored controls and semantics for ten catalog entries/details.
- `make verify`; optional `make soak` only for the longer population/proc/save stability work. A passing soak is not physical performance proof.

### Creator/device review

First review silhouettes and ten small gameplay captures. Then play each specialist with a starter weapon and a suggested advanced pairing. Compare both arenas, ordinary packs, elites, all boss roles, base/rank-III/rank-VIII and two-fusion builds. Use normal HP; Training protection is for learning, not difficulty approval.

Include cramped Foundry cover, two-boss Training, dense packs near caps, low HP, background/foreground, pause/picker, death/recovery, Continue, repeated swaps, Reduced Motion, large text and left-handed controls. Measure actual frame pacing/decoded textures on the target phone. Listen for repeated passive cues drowning reload/warnings. Record accepted values and rejected combinations in the playtest guide.

## 14. Definition of done

- The original three survivors have truthful stats/perk descriptions; all seven new survivors have complete art, distinctive passives, real costs, unlock progress and valid starter builds.
- All 41 offered families have exact current/next effects, prerequisites, caps and source ownership; all eight fusions have truthful payoff descriptions and explicit core actions.
- Nothing grants hidden immunity, unbounded healing, recursive procs, extra control clutter or new texture/population budget assumptions.
- Old profiles, original achievements and active runs survive the migration; Training stays reward-free and older online servers cannot admit unsupported content.
- Automated checks pass and remaining native review gates are stated honestly. Only creator playtests can approve final difficulty, feel, comfort and readability.

**Recommended first implementation slice:** the existing-survivor reference and definition-driven loadout details, dependency/capped-offer fixes, then Flint and Fuse. Establish the contracts and two distinct playstyles before producing the other five survivors and all eight upgrade additions.
