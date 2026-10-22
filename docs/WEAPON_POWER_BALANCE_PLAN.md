# Weapon power and area-effect balance plan

22 October 2026. Investigation of build15. **Historical investigation/proposal; the approved implementation is now documented
in [the all-21 weapon implementation review](WEAPON_POWER_IMPLEMENTATION_REVIEW.md).** Companion brightness and the Rail Lance sight are separate presentation
fixes. The aim is a powerful player facing dangerous encounters, without replacing
weapon controls, firing patterns, reload mechanisms or committed attacks.

## Outcome

Every primary weapon, including Pump Shotgun and Spore Lobber, should support a
credible normal run. Ordinary enemies should die decisively when the player uses
the weapon well. Elites, armor, positioning, reload windows and boss patterns
provide the challenge. Companion damage and one specific fusion must not be
required to rescue an otherwise ineffective primary weapon.

Regun currently continues into endless ten-minute cycles; there is no finite
"whole game" ending. Use a first-cycle clear, then 20/30-minute normal-build
survival and the complete eight-boss roster as acceptance benchmarks. This does
not promise indefinite survival. Training protection and artificially maxed
rank-VIII loadouts cannot demonstrate normal-run viability.

## What the current code actually does

| Finding | Evidence and implication |
| --- | --- |
| Shotgun connections matter more than its headline damage | Base is three1.2-damage pellets; all three close connections give4.32 before upgrades/defenses. A Mummy has6HP, so even a good base blast cannot kill it. At distance, pellets miss independently in addition to the modest.90 falloff floor. |
| Reload creates a substantial low-output window | Five shells fire at.35s intervals then a full3.2s reload. Ideal repeated-magazine output is about3.91 damage/s before distance bonuses, versus10.29 during firing. At full close connection that becomes about4.70 sustained. Missing outer pellets reduces both substantially. These are analytical ceilings, not measured encounter DPS. |
| Spore damage cannot justify its exposure requirement | Direct capsule is.5; a patch is.8 damage/s with.25s ticks,100-unit radius and2.5s life. Nominal full-life damage is only2, before boundary-tick timing. A6HP Mummy survives even a full base capsule and patch. Moving enemies receive less. |
| The patch does not slow occupants | WeaponReaction's.55 slow belongs to the short direct-hit response. Patch ticks call hitEnemy as secondary without a reaction/status. They neither hold enemies inside nor slow pursuit throughout occupancy. |
| Damage overlap is intentionally bounded | At most four patches; strongest overlapping patch wins per target; each patch selects at most eight nearest eligible targets per tick. Larger visual patches alone would leave more apparent occupants untouched under saturation. |
| Mortar fails an obvious unupgraded breakpoint | Scrap Mortar deals4.5 in145 radius after roughly.55–.85s flight at normal distances, before travel/body/cover interactions. It cannot kill a fresh6HP Mummy in one ordinary blast. Enemies may leave the landing area while it flies. |
| Rivet payoff is a separate value | Direct hit.75; lodged payload1.75, radius125; up to two payloads per host. Changing only WeaponType.damage would miss the main blast payoff. |
| Some paid effects depend on cosmetic room | Mortar impact waits for _effectRoom. Rivet lodge returns without creating a payload when _effectRoom is false. Continuous weapons also gate ticks on this budget. This is a reliability problem to isolate, not evidence that every weapon needs the same damage multiplier. |
| Main AoE does not get all primary-shot procs | Mortar/Anchor damage carries release provenance for survivor passives but remains secondary for acquired primary procs. Spore patch damage scales with shotDamage/character damage, not every capsule release bonus. Preserve intentional proc separation; budget its lower ceiling explicitly. |
| Later durability is real | Ordinary health scales1→1.65→about2.37 across cycles1/2/3, elites double relevant base health, and bosses gain180×(cycle−1)^1.3 HP. Available damage upgrades, actual XP collection and time spent reloading must be compared against this progression. |
| Companion presentation overstates its role | Native drone links use the same heavy, pale, branched lightning as major electrical hits. Several fast links dominate attention even when their damage is modest. |

Relevant sources: `lib/data/loadout.dart`, `lib/game.dart`,
`lib/components/enemies/{enemy_component,enemy_2_component,arena_enemy}.dart`,
`lib/systems/{arsenal_system,endgame_arsenal,combat_system,encounter_director}.dart`,
`lib/components/enemies/combat_enemy.dart`, `lib/notifiers/game_notifier.dart`.

The controlled runtime audit in
`docs/validation/weapon-power-baseline-2026-10-22.json` (regenerated as
`build/balance-review/current-weapon-damage.json`) records actual single releases
against an unarmored stationary target and spore walk-through exposure at
0/60/90/105 world units/s. This isolates damage delivery; it does not measure
human accuracy, normal upgrade acquisition or a full-run win rate.

Measured single releases: Shotgun4.32 at130 units versus1.247 at330; Carbine.819,
Revolver3.322, Rail Lance7, Mortar4.5, Spore capsule plus patch2.5 and Anchor8 at
300 units. The target is stationary/unarmored with1000HP to avoid overkill hiding
actual applied damage. Standalone patch damage measured1.8 at0/60 speed,1.6 at90
and1.4 at105 world units/s, with movementMultiplier1 throughout. Spore walk-through starts45 units ahead of patch center
(representing body contact near a capsule rupture); the unmodified motion profile
is recorded separately, not mistaken for a human encounter simulation.

## Research applied to Regun

Daniel Helbig's first-person weapon-design discussion treats projectile damage,
frequency, magazine/reload downtime, area coverage and physical enemy response as
separate balancing variables. Apply that situation-based approach: compare crowd
clear, armor, sustained bosses and moving targets rather than equalizing DPS.
[Weapon balancing based on gameplay situations](https://www.gamedeveloper.com/design/weapon-balancing-based-on-gameplay-situations-part-two-).

Brandon Franklin's combat-math discussion emphasizes understandable relationships
and noticeable progression. Use meaningful kill thresholds: moving a blast from
4.5 to5.5 still leaves a6HP Mummy alive;7.5 changes the encounter outcome.
The proposed values here are Regun-specific hypotheses, not values prescribed by
that article. [Integer based combat systems](https://www.gamedeveloper.com/design/integer-based-combat-systems).

Valve's Michael Booth describes alternating peaks and relief in Left4Dead's
pacing, and distinguishes pacing changes from difficulty changes. The applicable
lesson is to preserve dangerous encounter peaks and recovery space rather than
cancel every weapon improvement by immediately inflating all enemy health.
This is an analogy, not a proposal to add an adaptive director.
[The AI Systems of Left4Dead](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf).

## Proposed first numerical candidates

These are starting candidates for measurement and phone A/B review. Tune in
separate steps; do not combine every radius, damage, duration and speed buff at
once and then guess which helped. Start with damage breakpoints, then coverage,
then the bounded spore slow. Retain enemy health/spawns while comparing.

| Source | Current | First candidate | Desired result / constraint |
| --- | --- | --- | --- |
| Pump Shotgun pellet |1.2|1.7| Three close pellets≈6.12: one clean close blast defeats a6HP Mummy. Three pellets/spread/cadence/reload unchanged. Outer-pellet misses remain the ranged tradeoff. |
| Spore direct capsule |.5|1.0| Better rupture feedback; the field remains the main payoff. |
| Spore patch DPS |.8|2.4| A useful full occupation can kill a6HP bruiser. At.25s ticks this is.6 damage/tick. Strongest overlap remains, not fourfold stacking. |
| Spore radius |100|150| Diameter200→300; area×2.25. Make the footprint and all reach checks share the same value. Consider160 only after coverage/CPU review. |
| Spore lifetime |2.5s|3.0s| Nominal7.2 total field damage at candidate DPS; enough time to exploit placement without carpet permanence. |
| Mortar blast |4.5|7.5| A well-landed base blast kills a fresh Mummy, but not an8HP shield at full health. Keep flight, release, reload and cover rules. |
| Mortar radius |145|185| Approximately63% more area, rather than a63% increase in damage. Test separately from the damage buff. |
| Rivet lodged payload |1.75|2.5| Two payloads produce5 combined blast damage, plus direct-hit damage; pay off planned detonations. |
| Rivet blast radius |125|155| Approximately54% more area; keep two-per-host/eight-total limits and existing detonation behavior. |
| Anchor crush |8|10| Reward the long gather/crush commitment; ordinary elites survive more often than trash. |
| Anchor crush radius |165|190| Align payoff with the existing190-unit pull reach; preserve cover and the bounded pull. |
| Cinder direct tick |.38|.46| About21% more direct damage, with existing tick/fuel/burn/proc timing. Confirm multiple-target contact before finalizing. |
| Mourning Bell main cone |4.5|6| Better heavy opening; review existing echo and final-round multipliers together. Keep echo delay/ledger. |

The other fourteen weapons still need the same breakpoint/delivery audit. Do not assume Rail Lance,
Longwatch, Arc chains, Cyclone or rapid Belt fire need the same increase: their
piercing, chain damage, spread, sustained ramp and release bonuses differ. Review
all21, including Reaper Disc return, Flak fragments and Faultline segments, before
calling this a complete balance pass. Grenades/mines are secondary ammunition;
measure them but do not automatically apply main-weapon buffs to them.

### Spore slow — explicit, bounded mechanics addition

This is the requested exception to a values-only pass:

- Occupying ordinary enemies move at75% speed; elites at85%; bosses, planted
  nests/sentinels and committed leap/charge movement remain unaffected initially.
- Refresh occupancy during active play; clear immediately on exit/expiry. No
  stacking across patches. Combine with existing braking by taking the stronger
  reduction, not multiplying into an immobilization loop.
- Use one shared footprint for damage, slow and visual extent, with the existing
  body-edge/cover rules. No unbounded list of per-tick effects or new shove.
- Preserve pause/picker/background freezes and existing patch save lifetimes.
  Save any new durable state explicitly; do not infer statuses from graphics.
- Assess the eight-target-per-patch limit after enlargement. Prefer one shared
  eligible target set for damage/slow; test12 targets as a numerical candidate if
  visible occupants are being skipped. Profile the fixed four-patch budget before
  expanding any target cap. Avoid a larger-looking field with invisible immunity.

## Implementation sequence

1. **Capture baseline.** Record all21 weapons at0/5/10/20/30 active minutes on
   both arenas: first hit, kill time, shots/charges per kill, damage per magazine,
   reload downtime, missed area releases, targets hit, spore occupancy and XP/ranks
   actually earned. Include scorpion2HP, Mummy6, Revenant3, shield8, nest12, elites
   and all eight boss health/defense states. Store deterministic seeds and results.
2. **Fix delivery reliability first.** Damage/payload creation must not disappear
   or wait behind cosmetic FX. Retain logical attack caps, finite flights,
   exactly-once impacts and cover; evict/skip a cosmetic before losing paid damage.
   Add saturated-effect regression cases for Mortar/Rivet/continuous ticks.
3. **Centralize numerical tuning.** Put direct, blast, radius, DoT/tick/duration
   and slow values in one balance contract rather than scattered render/runtime
   literals. Renderers consume that contract. Keep damage, contact count, effect
   rank and source/proc multipliers explicit so none are applied twice.
4. **Tune damage breakpoints.** Try Shotgun/Mortar/Spore first. Compare unchanged
   encounter seeds against baseline. Promote values only when actual kill time
   and kill count improve meaningfully. Keep cadence/reload/input/mechanics.
5. **Tune useful coverage.** Test proposed Spore/Mortar/Rivet/Anchor radii as a
   separate change; measure targets per shot and delayed-hit misses. Add the
   bounded spore occupancy slow. Keep fast attacks/armor/bosses threatening.
6. **Test ordinary builds.** Base; reachable early build; affordable mixed
   mid-build; focused late build; capped combination stress. Use real upgrade
   costs and offered choices. Do not grant eight ranks to every family or assume
   every player rolls Heavy Load/Scattershot/a companion. Test builds without
   companion, with it, and with each of the eight fusions.
7. **Preserve compatibility.** Version the numerical balance for fresh runs and
   decide a documented Continue policy for stored shot/flight/patch damage so old
   payloads cannot double-scale. Match admitted Shotgun/Carbine/Revolver/Arc values
   and fixtures on the TypeScript server before any online rollout. Other17
   weapons stay outside hosted room admission. Keep offline play independent.
8. **Phone A/B acceptance.** Compare the same encounters with real touch input,
   music and sound. Record whether ordinary enemies die convincingly, blast
   commitments pay off, reload pressure remains fair and late bosses are tense.
   Only then export/install a new review build. This plan does not deploy anything.

## Acceptance gates

- An unupgraded close Shotgun lands its intended Mummy threshold; no added
  pellets, firing modes, reload interruption or extra primary procs.
- A well-placed base mortar blast kills the intended ordinary bruiser; a miss or
  armored/elite target still matters. No through-wall damage or repeat blasts.
- A base Spore patch kills an ordinary bruiser with sufficient exposure and
  visibly slows ordinary occupants; moving, edge-only exposure deals less.
- Each weapon clears the first cycle with a reachable mixed build across several
  fixed seeds. At least a five-seed offline pass per weapon/arena, followed by
  human runs, before claiming viability. Record losses and causes; do not use an
  invincible bot to claim success. Test later cycles and all boss types as well.
- Proposed review bands: first-hit delay excluded from kills-to-hit counts but
  included in real kill time; trash≈.25–.75s of useful exposure, bruisers≈.8–1.8s
  with a developed build, elites≈2–5s, bosses≈45–90s with an ordinary appropriate
  build. Spore's base unupgraded bruiser threshold can be≈2.5s field exposure.
  These are acceptance hypotheses, not universal limits or established results.
- Rank-VIII/fusion combinations do not permanently stun bosses, trivialize every
  elite, exceed projectile/chain/effect budgets or make the companion the main
  weapon. Test source attribution, armor and secondary exclusions explicitly.
- No lost paid damage under cosmetic saturation. Consistent result across small/
  large frame steps, pause/background/restart/Continue and current server fixtures.
- Phone performance, power feel, audio and readability need hands-on approval;
  passing a correctness test is not proof that combat feels good.

## Presentation fixes completed with this investigation

- Drone links have a narrow muted sage stroke without the pale core, branches
  or flashing endpoints; electrical primary weapons keep their existing effect.
  Current online snapshots identify drone links through their existing.12-second
  duration (weapon chains use.16); an explicit companion role is also understood.
  No server rollout is required for current snapshots. Damage/cadence are untouched.
- Rail Lance has a steady dotted targeting sight while aiming/charging, from the
  same muzzle/assisted heading as the shot. It clips to solid cover, hides when
  the muzzle is blocked, reloading, empty, entrance-gated or not aiming, and does
  not add sniper sway or release-to-fire behavior.
- Rendered review: `build/test-previews/companion-link-quiet.png` and
  `build/test-previews/rail-lance-sight.png`. The companion image compares the old
  left and quiet right on both floors; the Rail image compares open and covered
  lanes.102 focused combat tests passed; pixel comparison confirms substantially
  reduced companion luminance. These are local changes, not a new device build.
