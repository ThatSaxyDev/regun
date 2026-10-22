# Weapon power review — 23 October 2026

Implemented candidate, release identity 1.0.0+15. This extends the investigation in
[WEAPON_POWER_BALANCE_PLAN.md](WEAPON_POWER_BALANCE_PLAN.md) to every live weapon.
The table gives raw base damage, before survivor bonuses, distance, armor and
upgrades. A row is not a DPS comparison: magazines, commitment, target caps and
secondary effects differ. No cadence, magazine, reload, spread, aiming or firing
pattern changes are part of this pass.

## Decisions across all 21 weapons

| Weapon | Previous → candidate | Reason and retained tradeoff |
|---|---|---|
| Pump Shotgun | 1.2 → 1.7 per pellet | Three close pellets now deliver 6.12 instead of 4.32: one fresh 6HP Mummy at full connection. Three pellets, falloff and full reload commitment remain. |
| Carbine | .762 → .90 | Modest 18% lift to reliable sustained primary damage; dispersion and reload still expose the player. |
| Revolver | 3 → 3.6 | More decisive precision hits, with the six-round cylinder and .65s cadence preserved. |
| Arc Caster | 3 → 3.5 | Improves the initial hit and its two inherited 85% chains, without adding jumps or refreshing the damage bonus. |
| Burst Rifle | 1.05 → 1.25 per round | Three connected rounds total 3.75 rather than 3.15; burst spacing and recovery stay intact. |
| Rail Lance | 7 → 9 | Rewards charge commitment and narrow lining-up; retained pierce attenuation prevents full-strength damage through an entire queue. Sight follows charge/cover. |
| Rivet Driver | .75 direct retained; payload 1.75 → 2.5, radius 125 → 155 | Invest in delayed detonation rather than making it a substitute automatic rifle. Two-charge host cap remains. |
| Cinder Hose | .38 → .46 per tick | More payoff for short-range exposure. Burn limits, advancing flame contact and fuel cost remain. |
| Reaper Disc | 1.5 → 2.1 per leg | A connected outbound/return pair delivers 4.2 instead of 3; leg owner caps and return requirement remain. |
| Scrap Mortar | 4.5 → 7.5; radius 145 → 185 | A correctly landed blast kills a fresh Mummy with margin. Flight delay, cover and four-round magazine preserve risk. |
| Belt-fed Repeater | .70 retained | Its 100-round belt and .085→.040s ramp already create strong sustained output. Review real lane uptime before raising the maximum. |
| Frost Shotgun | 2.2 per pellet retained | Three connected pellets already deal 6.6 plus freeze. Keep its slower cadence and thaw immunity meaningful. |
| Prism Cutter | .48 → .60 per tick | Compensates for nearest-body beam clipping and heat-limited uptime. No new penetration or thermal capacity. |
| Spore Lobber | .5 → 1 capsule; .8 → 2.4 patch DPS | Rewards the delayed ground effect; geometry/control details below. |
| Longwatch Sniper | 12 retained | Existing high damage, three pierces and armor advantage already reward release timing. No indiscriminate late-unlock buff. |
| Twin Verdict | 2.5 → 3 | Connected pair becomes 3+5.4 rather than 2.5+4.5; the existing secondary fork scales once, with brand/miss/reload rules retained. |
| Flak Regent | 2.4 → 3 | Improves both direct payoff and proportional fragments. Four fragment reservations, owner exclusion and one burst remain. |
| Anchor Engine | 8 → 10; radius 165 → 190 | Larger delayed crush payoff. Pull displacement, planted-body immunity and per-owner limits remain. |
| Faultline Driver | 6 → 8 | A long committed ground lane rewards its landing; three sections still hit each owner only once and stop at cover. |
| Cyclone Breacher | 1.2 per pellet retained | Five pellets already deliver 6 at point blank and rapid volleys. Preserve the Pump's close-hit role and Cyclone's faster crowd role; verify range loss on device. |
| Mourning Bell | 4.5+1.5 → 6+2 | Main strike now reaches the ordinary 6HP breakpoint. Echo remains at .55s, only original owners still in the original cone, capped at five. |

## Reliability, fields and presentation

Paid Mortar impacts, Rivet payloads and continuous ticks no longer depend on free
cosmetic slots. Rendering still respects its budgets, evicting old cosmetic effects
when necessary; damage, ammo spending and one-hit ledgers remain authoritative.
A lethal Bell echo safely tolerates a boss unregistering during target iteration.

Spore radius is 150 (was 100), lifetime 3s (was 2.5), with .25s ticks. At most four
patches exist; each selects twelve nearest eligible bodies (was eight), with the
strongest overlapping patch winning rather than stacking. Ordinary occupants move
at .75 stride; elites .85; bosses and planted bodies keep full stride. Cover,
expiry and leaving the field clear the effect immediately. The stronger of impact
slow and field slow wins; they do not multiply. A committed leap retains its
attack timing. The visible ground footprint now matches the circular field.

Bell discharge art is a contiguous stepped brass compression crescent with one
subdued trailing band. Its residual front bridges the main strike into a quieter
settling echo at the outer part of the same cone. The echo does not restart at
the muzzle. Cover clipping, range and Reduced Motion remain. Weapon body/atlas
art is unchanged. Companion lightning is quieter and Rail has a cover-clipped
charge sight from the preceding presentation pass.

## Saves and online parity

`WeaponPowerBalance` records revision 2 on fresh runs. Missing markers mean
revision 1: Continue retains old base numbers, field geometry and already-paid
payload damage, preventing mixed or double-multiplied saves. Reset/new run selects
the candidate. Invalid/mismatched revision markers fail validation.

The sibling server and shared contract carry matching numerical changes for its
five admitted weapons. Separate captured player-damage ratios retain the existing
PvP damage values; old in-flight rounds default to their old scale. Server tests,
typecheck and module build cover the implementation. These local server edits
have **not been deployed**, so this phone release's new balance is for offline
play until the authoritative service is updated. No service check gates offline
entry or combat.

## Verification and remaining acceptance

The runtime audit exercises all 21 actual weapon paths in both revisions, including
burn, delayed echo, return hits and payload completion. Its data is in
[weapon-power-revisions-2026-10-23.json](validation/weapon-power-revisions-2026-10-23.json).
These stationary unarmored samples use different trigger windows and ammo costs;
they cannot rank sustained DPS or demonstrate normal-run wins.

Regressions exercise close-shotgun and pursuing-Spore kills, damage with forty
cosmetic effects, twelve-target nonstacking fields, slow exit/cover/pause/elite
rules, legacy Continue and lethal Bell echo cleanup. Existing full-game checks
also exercise progression, all bosses, shared fixtures and loadout behavior.

Physical review: start a **new run** to test revision 2. Review Bell main/echo
clarity, companion comfort, Rail sight, Spore occupancy and blast readability.
Then compare normal, unprotected runs across weapons and both arenas: first cycle,
20/30-minute progression, elite/armor breakpoints, reload exposure, ammo efficiency,
actual field occupancy and boss time-to-kill. Record multiple seeds and upgrades;
look for runaway combinations before further buffs. No automated test or successful
installation establishes physical comfort, performance or all-weapon run viability.


Verified on 23 October 2026: `make verify` passed analyzer and 533 tests (five
existing skips); sibling `npm run verify` passed typecheck, 99 tests and module
build. `make buildIOS` produced the signed 1.0.0+15 release using the existing
combined release configuration. CoreDevice installed it on Kiishi David’s physical
iPhone12 without removing app data. Installation is not a hands-on balance verdict.
