# Regun — complete game blueprint

**Plan date:** 19 October 2026  
**Platforms:** iOS and Android; landscape, touch first  
**Status:** implementation underway; see [the progress log](REGUN_PROGRESS.md) for implemented features and verification. This specification is the full target, not a claim that all its features exist.  
**Authority:** this document replaces the narrower completion scopes in the initial review and progress log. Those documents remain historical evidence. The creator has authorized completing the game, including new mechanics and original art. Quality takes precedence over the earlier upload deadline.

## Contents

- [1. The game we are completing](#1-the-game-we-are-completing)
- [2. Launch scope and boundaries](#2-launch-scope-and-boundaries)
- [3. What exists and what still needs building](#3-what-exists-and-what-still-needs-building)
- [4. A complete run, moment to moment](#4-a-complete-run-moment-to-moment)
- [5. Combat rules and weapon identity](#5-combat-rules-and-weapon-identity)
- [6. Mobile controls: an early completion gate](#6-mobile-controls-an-early-completion-gate)
- [7. Kill rewards, XP, score, and pickups](#7-kill-rewards-xp-score-and-pickups)
- [8. Builds, upgrade catalogue, and evolutions](#8-builds-upgrade-catalogue-and-evolutions)
- [9. Characters, loadouts, and lasting progression](#9-characters-loadouts-and-lasting-progression)
- [10. Enemy roster and encounter director](#10-enemy-roster-and-encounter-director)
- [11. Three complete bosses — mandatory launch work](#11-three-complete-bosses--mandatory-launch-work)
- [12. Arenas, obstacles, and readable space](#12-arenas-obstacles-and-readable-space)
- [13. Game feel, sprites, effects, and audio](#13-game-feel-sprites-effects-and-audio)
- [14. All screens and player-facing flows](#14-all-screens-and-player-facing-flows)
- [15. Run state, slow motion, interruptions, and saving](#15-run-state-slow-motion-interruptions-and-saving)
- [16. Implementation architecture](#16-implementation-architecture)
- [17. Performance and stability budgets](#17-performance-and-stability-budgets)
- [18. Verification, balance, and accessibility](#18-verification-balance-and-accessibility)
- [19. Implementation milestones and acceptance gates](#19-implementation-milestones-and-acceptance-gates)
- [20. Traceability: the concerns that cannot disappear](#20-traceability-the-concerns-that-cannot-disappear)
- [21. Final definition of done](#21-final-definition-of-done)

## 1. The game we are completing

Regun is an **endless twin-stick survival shooter with roguelite builds**. Move with the left thumb, aim and fire with the right, manage a magazine, reload under pressure, and dash through danger. Killing enemies supplies experience. Level-ups create a build. Elites and bosses test that build. Death ends the attempt, records its achievements, and opens reasons to try another character, weapon, or arena.

Its defining tension is **finding room to reload while an increasingly powerful build fights an increasingly dangerous horde**. The opening should feel precise and vulnerable; a developed build should feel spectacular without making positioning irrelevant. Manual aiming, shotgun timing, and mobile comfort are design pillars, not temporary scaffolding.

“Complete” means a coherent, replayable, attractive offline game from clean installation through tutorial, loadout, repeated runs, interruptions, progression, and results. It includes functional bosses, meaningful builds, sufficient encounter variety, finished controls and menus, sound, persistence, accessible settings, stable performance, and signed mobile releases. Fixing the current bugs alone does not meet this definition.

### Non-negotiable decisions

Player-facing copy stays brief: actions, effects, and essential instructions. Do not narrate engine behavior or explain why time/combat waits during a choice.

- Endless survival until death is the main mode. A ten-minute milestone does **not** force a win or stop a run.
- Preserve the starting shotgun's normal reload formula, authored shell sounds, and Lottie presentation. Other weapons can have their own reloads.
- Preserve the deliberate 0.1× world presentation while selecting upgrades. Selection must be safe and stable.
- Comfort and visibility come before decorative controls. Repositioning and calibration are required; changing button skins alone is insufficient.
- Keep Flutter and Flame. Reuse working assets and code where they serve the design; replace incomplete systems where needed.
- Build choices must change play, not merely increase numbers. Several distinct builds must work against every required boss.
- New sprites, effects, audio, encounters, and mechanics are authorized parts of completion. They must share one visual and mechanical language.
- Ship a complete offline product without accounts, ads, purchases, or network dependency in version 1.0. Commercial expansion can follow validation.

### Reference lessons, without copying their content

| Reference | Useful lesson | Regun's decision |
|---|---|---|
| [20 Minutes Till Dawn — official developer description](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/) | Active aiming, reload pressure, upgrade combinations, and bosses can sustain a survival run. | Keep manual combat central; make reload and dash interact with builds. |
| [Vampire Survivors — official developer description](https://store.steampowered.com/app/1794680/Vampire_Survivors/) | Growth from fragile survivor to overwhelming offense gives repeated attempts a strong arc. | Deliver that escalation while retaining aiming and magazine decisions. |
| [Brotato — official developer description](https://store.steampowered.com/app/1942280/Brotato/) | Distinct characters, equipment combinations, and clear encounter pacing support replayability. | Give loadouts real tradeoffs and encounters readable rhythms, while keeping continuous survival rather than a between-wave shop. |

These references inform principles. The content roster, numbers, names, and implementation below are Regun proposals. All numerical balance values are starting hypotheses to test, not established balance or promises about player performance.

## 2. Launch scope and boundaries

This is the intended version 1.0 content contract. Content only counts when it has art, sound where appropriate, behavior, UI descriptions, balancing, tests, and device verification.

| Area | Required launch content |
|---|---|
| Modes | Endless survival; replayable training arena with no progression rewards |
| Characters | 3, each with a passive and a meaningful tradeoff |
| Primary weapons | 4; one equipped per run, selected before starting |
| Arenas | 2 with distinct layouts, presentation, and encounter pressures |
| Normal enemies | 8 behavior roles, plus defined elite modifiers |
| Bosses | 3 complete encounters; Shadow and Demon repaired, Scorpion Queen added |
| Upgrades | 30 ranked families, 6 named evolutions, bounded endless fallback rewards |
| Progression | 20 explicit challenge unlocks, personal records, collection/codex |
| Mobile experience | Comfortable adjustable controls, onboarding, settings, interruption handling, Continue Run |
| Presentation | Consistent pixel art, directional weapon presentation, readable effects, music and sound mix |
| Verification | Real iPhone and Android playtests, long runs, release builds, clean install and upgrade tests |

No multiplayer, online rankings, cloud saves, campaign, crafting inventory, procedural world generator, or additional desktop/web release is required for 1.0. These are product boundaries that let the core game become complete. They must not appear as broken or “coming soon” menu items.

If testing proves a listed feature harmful, replace it with a documented design decision and equivalent player value. Do not quietly remove whole systems to declare completion. Keep the scope table and acceptance gates current.

## 3. Baseline at planning time

**Historical baseline:** the full functional implementation now has its own status and evidence in [REGUN_PROGRESS.md](REGUN_PROGRESS.md#full-game-implementation-pass--19-october-2026). Physical acceptance and asset review are still open. The paragraphs below describe the starting point for this plan.

The original foundation included movement, manual firing, shotgun reload, dash, three active enemy types, a Tiled arena, ten simple upgrade types, audio, menus, and a working iPhone build. Recent work repaired important correctness and accumulation issues and replaced the most obviously mismatched buttons.

However, active enemies still ignore their declared health and die on the first bullet. Random ambient coins supply progression instead of kills. There is no complete encounter director, functioning boss progression, durable run save, substantial meta progression, or finished mobile product flow. Shadow and Demon files are experiments, not completed encounters.

| Existing work | Treatment in this plan |
|---|---|
| Camera/player/spawn geometry shared through arena bounds | Retain; extend to obstacles, boss footprints, and all aspect ratios. |
| Population caps, repeating timer, active sprite preloads, reduced entity/provider churn | Retain; measure native performance before increasing density. |
| Scoped reset, ammo guards, centralized damage, stable offers, simulation reload clocks | Retain and extend into shared combat/run systems. |
| Normal shotgun reload and shell sound schedule | Protected baseline with regression coverage. |
| Restored 0.1× selection | Preserve presentation; complete the logical clock and combat rules below. |
| Dark pixel button redesign | Retain direction; controls' reach and placement remain unresolved. |
| Shadow, Demon, mines, shrapnel, old dialog code | Complete or replace within the new systems; no dormant unsafe path enters the live roster. |
| Current tests and analyzer | Useful baseline; not proof of native frame rate, balance, comfort, or a complete game. |

The historical measured fixes and their limits are in [REGUN_PROGRESS.md](REGUN_PROGRESS.md). No new gameplay implementation is implied by writing this plan.

## 4. A complete run, moment to moment

### The first attempt

1. Launch directly into a clear title screen with Play, Continue when available, Loadout, Collection, and Settings.
2. First Play introduces the two sticks, dash, and reload in a short playable training sequence. The player can skip and replay it.
3. Show one enemy, then a small group. Teach by doing: move, aim/fire, collect the kill drop, dash through a marked danger, reload.
4. Offer the first meaningful upgrade after roughly 20–35 seconds of successful combat. Explain only the choice being made.
5. Introduce a second enemy role before introducing overlapping special attacks.
6. By approximately three minutes, the player has a recognizable build and meets the first boss.
7. On death, explain what killed the player, show the build and records, settle unlocks once, and make Retry immediate.

These timings are tuning goals. Observe real first-time players and change the pacing when they do not understand or enjoy it.

### The endless structure

Use ten-minute encounter cycles. The first cycle establishes the game; later cycles remix packs and increase pressure. Suggested first-cycle milestones:

| Active time | Encounter purpose |
|---|---|
| 0:00–1:00 | Learn the current weapon; chasers and small flanking groups; establish XP income. |
| 1:00–3:00 | Introduce bruisers and ranged pressure; room to pursue an upgrade direction. |
| ~3:00 | Shadow boss; reduce background horde pressure. |
| After boss–6:00 | New roles, first elites, recovery pockets, and build development. |
| ~6:00 | Demon boss; test telegraph reading and reload windows. |
| After boss–10:00 | Denser mixed packs, arena hazards, and evolution opportunities. |
| ~10:00 | Scorpion Queen; cycle milestone reward, then continue automatically. |
| 10:00 onward | Rotating bosses near 13/16/20 minutes and subsequent cycles; capped speed, growing compositions and durability. |

Only one boss may be active. If a scheduled encounter is delayed by a living boss, coalesce the pending request and allow at least 60 seconds of recovery after its death. Never accumulate a queue of back-to-back bosses. The director must work if the player kills very slowly or very quickly.

Do not scale every stat exponentially. Cap movement and attack speed, preserve reaction windows, and use composition, elites, durability, and limited attack variations to increase difficulty. Keep a viable escape route. Endless escalation should eventually overwhelm a build through pressure, not invisible hits or unavoidable overlapping attacks.

## 5. Combat rules and weapon identity

### Shared combat model

Create one damage contract for player, enemies, bosses, hazards, mines, and projectiles. Damage carries source, faction, amount, damage tags, knockback, and relevant status effects. Targets own health, armor, immunity, and their death transition.

- Actual health determines death. A hit and a kill are separate events.
- Death rewards and removal happen exactly once, including simultaneous pellet/mine hits.
- Friendly-fire rules are explicit. Hostile projectiles cannot inherit player perks.
- A projectile records targets already hit; piercing and ricochet cannot repeatedly hit the same target unless an explicitly timed mechanic permits it.
- Use swept collision for fast projectiles where discrete collision can tunnel.
- Combat hitboxes match visible bodies. Oversized sprite-sheet canvases are not hitboxes.
- Define obstacle collision consistently for player, enemies, projectiles, and line of sight.
- Status and proc effects have caps. Secondary effects cannot recursively spawn an unlimited chain.

Starting player health remains three hits. Standard damage is one; a heavily telegraphed boss attack may deal two. Retain the 500 ms damage immunity interval and clearly show it. Armor is an understandable guard charge, not an unexplained fractional health calculation.

### Launch weapons

| Weapon | Play identity | Initial tuning seed |
|---|---|---|
| Pump Shotgun | Close-range spread, burst, deliberate shell reload; starting weapon. | Preserve current 3 pellets × 1 damage, 5 shells, 0.35 s firing cadence, range 420 and speed 700 as the baseline. |
| Carbine | Sustained tracking, frequent smaller hits, longer magazine. | 1 projectile × 0.6 damage, 0.10 s cadence, 24 rounds, 1.8 s reload. |
| Revolver | Accurate high damage, deliberate shot placement and overkill tradeoffs. | 1 projectile × 3 damage, 0.65 s cadence, 6 rounds, 2.1 s reload. |
| Arc Caster | Short chain attacks and crowd control, limited direct boss damage. | 2 direct damage, 0.9 s cadence, 4 charges, 2.4 s recharge; bounded chain with damage falloff. |

Compare sustained damage, effective area damage, range, reload vulnerability, and ease of aiming. None is simply a stronger replacement for the shotgun. Weapon unlocks are alternatives. Primary weapon stays fixed during a run; perks supply additional attacks without creating an inventory-management game.

### Preserve the reload work

For the starting shotgun, normal reload duration is `900 + 700 × (missingShells − 1)` milliseconds. One missing shell takes 900 ms; an empty five-shell magazine takes 3700 ms. Existing full-magazine shell sounds remain at 0, 700, 1400, 2100, and 2800 ms. Preserve the existing Lottie asset and authored normal playback.

Keep reload timing in the simulation and drive the visual from the same state. Pause, selection, background, death, restart, and restore cannot desynchronize sounds, ammo, or animation. Baseline completion refills the magazine as it does now; per-shell interruptible reload would be a separate redesign and is not required.

Retain fast-reload ceilings of 2000/1500/1000 ms, with effective duration `min(normalPartialReloadDuration, ceiling)` so an upgrade never makes a one-shell reload slower. Any animation compression for an upgrade must be intentional and visibly synchronized; normal reload remains untouched.

### Weapon-specific reload presentation

The shotgun Lottie is exclusive to the Pump Shotgun. Do not reuse its shell-loading animation or shell sounds for other weapon types. Shared reload infrastructure may track elapsed time, block firing, and update HUD progress; each weapon supplies its own visual sequence, sound cues, completion event, and interruption/restore behavior.

| Weapon | Required reload/recharge sequence | Presentation requirement |
|---|---|---|
| Pump Shotgun | Existing authored shell-loading sequence. | Preserve its Lottie, normal timing, and shell sounds as specified above. |
| Carbine | Remove magazine, insert replacement, finish with a bolt/charging action. | New magazine-swap animation and matching mechanical sounds; no shotgun shells. |
| Revolver | Open cylinder, eject spent cases, load, close cylinder. | New cylinder-reload animation and sound cues; readable even at phone scale. |
| Arc Caster | Weapon powers down, vents/discharges, then rebuilds its charge. | New energy/venting effect and electrical audio; no conventional ammunition-loading animation. |

Choose sprite animation or a dedicated overlay asset per weapon according to readability and art direction; do not force every weapon into the existing Lottie format. Distinguish the world-character reload pose from the HUD indication: a HUD progress bar alone does not complete the weapon animation requirement. Weapon-specific poses, muzzle alignment, reload visuals, icons, and sound cues are part of each weapon's production assets.

The animation and authoritative reload clock must agree on when the weapon becomes ready. Faster-reload perks adapt that weapon's own sequence and cue schedule. Test partial magazines, empty magazines, upgrades, pause, slow selection, background, death, and save/restore for every weapon. Keep the starting shotgun's protected baseline unchanged.

### Dash

Starting target: about 195 world units over 0.15 seconds, 1.6-second cooldown, with a brief baseline immunity window. Upgrades extend or modify it. Validate the values against actual enemy speeds and device input.

A dash uses the current movement direction while the movement thumb stays on its stick. If stationary, use aim direction, then last facing as fallback. Sliding along boundaries must work, and dashing cannot leave the floor or pass through solid obstacles. Show cooldown and readiness without requiring the player to read small text.

## 6. Mobile controls: an early completion gate

The current positions are not accepted as final. Redesign around real thumb reach on a landscape phone, not around the 1500 × 700 world coordinate grid.

### Default layout

- Left stick moves; right stick aims and fires while held outside its dead zone.
- Dash and reload stay on the aiming side, within the right thumb's reach in the default layout. The left thumb must remain on movement while the right thumb presses dash. Improve spacing without relocating dash to the movement side. Mirror the whole arrangement for left-handed controls.
- Start layout experiments with stick centers approximately 84 logical pixels inside each safe side and 76 above the safe bottom. Place dash roughly 76 pixels inward and 48 above the aiming stick; place reload roughly 8 pixels inward and 106 above that stick, then tune the right-side cluster through hands-on testing. These are experiment seeds, not approved final coordinates.
- Use responsive logical-pixel control layout with safe areas and an explicit viewport-to-world transform. Resolve small-screen overlaps by layout constraints, not global scaling that shrinks touch targets.
- Use approximately 88–112 logical-pixel stick rings and 52–60 pixel action targets, never below 48. Artwork can be smaller than its touch area. Keep the inner arena visible.
- Default to fixed sticks for predictable acquisition, with floating sticks available in settings. Do not allow a floating stick to capture a dash/reload touch.
- Auto-reload on empty; allow manual reload before empty. Give immediate feedback when an action is unavailable.

### Calibration and customization

Provide an in-game control editor with a live training preview: move each control, resize within safe limits, change opacity, adjust stick sensitivity and dead zone, switch fixed/floating, and choose mirrored left-handed layout. Save the layout per device. Include reset and comfortable preset layouts. Revalidate saved positions after an aspect-ratio or safe-area change.

Each touch has one owner. Handle simultaneous movement, aim, and action pointers; ignore duplicate activations; release ownership on pointer cancellation, overlays, backgrounding, and route exit. Returning to the game must never leave a stick or trigger held down.

Offer a mild optional aim-assist cone, with clear settings and testing. It must not select distant targets through walls or erase manual aiming. Keep gameplay assists separately recorded from unassisted personal records where they alter difficulty.

### Acceptance

Test both landscape orientations, notched screens, a compact iPhone, a larger iPhone, and representative Android aspect ratios. Confirm moving + aiming + dashing simultaneously, stationary dash, manual reload, edge-of-screen dragging, interruptions, and custom layouts. Observe several human players with different hand sizes. The creator's report that controls remain inconvenient is an open requirement until hands-on validation confirms otherwise.

## 7. Kill rewards, XP, score, and pickups

Remove ambient random XP coins from the main progression loop. Progress must come primarily from fighting. Authored caches may provide occasional recovery or exploration rewards, but cannot replace combat.

- **XP:** earned from enemy drops; used only for the current run's levels.
- **Score:** a record of the attempt, not a spendable currency.
- **Scrap:** awarded at results for cosmetic unlocks; no infinite permanent damage grind.
- **Boss cores:** special upgrade opportunities, not another general HUD currency.

Drops move toward the player inside a readable pickup radius. Combine nearby XP into higher-value pickups to control component counts. Merging and collection preserve total XP exactly. If the component budget is full, merge or credit the value through a defined fallback; do not silently delete earned XP.

Use a configurable XP curve, beginning near the current seven-point first threshold and increasing gradually. Handle overflow, multiple levels from one pickup, pending choices, and death during pickup processing. Offer one stable selection at a time. Do not generate offers in a widget build.

Suggested initial score formula: `2 × floor(activeSeconds) + enemyScoreTotal + 1000 × bossesKilled + 250 × completedCycles`. Define per-enemy scores in data. Record kills, survival time, bosses, and build separately so a score is explainable. Death settles rewards once using a persistent run ID.

## 8. Builds, upgrade catalogue, and evolutions

Offer three distinct eligible choices per level. Each card shows effect, current rank, next value, and synergy tags. Grant two free rerolls and one family ban per run; make their limits visible. A ban prevents future offers, never removes an acquired perk. Offer generation considers weapon compatibility, caps, existing ranks, and available special slots.

Allow six special-family slots. Core and utility families do not use those slots. Each evolution uses two compatible special families; permit at most two evolutions per run. Preserve a route to a missing evolution partner when slots are nearly full, or clearly warn before the player fills the last slot. Do not promise impossible combinations in the UI.

Most families have three ranks. Where a cap differs, state it in data and the card. Numerical values require balancing across all four weapons. Rate, pellet, pierce, health, and movement caps prevent unreadability and runaway costs.

### Thirty launch upgrade families

| # | Family | Role and meaningful effect |
|---|---|---|
| 1 | Heavy Load | Core: direct damage with an explicit per-rank value. |
| 2 | Quick Trigger | Core: firing cadence; bounded so input and audio remain readable. |
| 3 | Extended Tube | Core: magazine capacity; affects reload exposure. |
| 4 | Sleight of Hand | Core: faster reload using protected baseline rules. |
| 5 | Scattershot | Core: extra projectiles, with weapon-specific spread and damage tradeoffs. |
| 6 | Piercing Rounds | Core: limited additional targets, with falloff where needed. |
| 7 | Long Barrel | Core: effective range, capped to arena readability. |
| 8 | High Velocity | Core: projectile speed and improved hit reliability. |
| 9 | Fleet Foot | Utility: movement speed with a hard cap. |
| 10 | Vitality | Utility: maximum health and a clearly specified immediate heal. |
| 11 | Field Medic | Utility: bounded recovery drops from eligible kills. |
| 12 | Scrap Armour | Utility: a guard charge that absorbs one hit and visibly recharges. |
| 13 | Quickstep | Utility: shorter dash cooldown, with a minimum interval. |
| 14 | Afterimage | Utility: longer dash protection and clear invulnerability feedback. |
| 15 | Scavenger | Utility: pickup attraction radius. |
| 16 | Lucky Find | Utility: better special-offer weighting; exact effect disclosed, no guaranteed rarity claim. |
| 17 | Hot Shot | Special: apply burning damage over time. |
| 18 | Accelerant | Special: burning deaths spread a bounded ignition pulse. |
| 19 | Static Charge | Special: periodic electrical proc on primary hits. |
| 20 | Conductive Core | Special: improve chain reach/target count within caps. |
| 21 | Dash Mine | Special: leave an armed mine after a dash. |
| 22 | Fragmentation | Special: explosive hits emit a limited shard burst. |
| 23 | Ricochet | Special: primary projectiles bounce to a valid new target. |
| 24 | Bank Shot | Special: reward a completed bounce with damage/control. |
| 25 | Last Shell | Special: the magazine's final shot has a distinct burst bonus. |
| 26 | Breach Loader | Special: completing a reload charges the next primary attack. |
| 27 | Orbit Drone | Special: one companion contributes measured support fire. |
| 28 | Targeting Link | Special: primary hits mark targets for the drone. |
| 29 | Shrapnel | Special: a limited close-range cone on eligible kills. |
| 30 | Executioner | Special: increased direct damage against low-health targets; does not instantly execute bosses. |

### Six evolutions

A boss core offers an evolution when its prerequisites are met; otherwise it offers a high-value eligible rank or recovery choice. Consuming an evolution opportunity is explicit, and its effect is described before confirmation.

| Evolution | Prerequisites | Result |
|---|---|---|
| Firebreak | Hot Shot rank 3 + Accelerant rank 2 | Controlled ignition bursts create short-lived burning patches. |
| Storm Circuit | Static Charge 3 + Conductive Core 2 | Periodic chain discharge through a bounded marked cluster. |
| Minefield | Dash Mine 3 + Fragmentation 2 | Dash lays a short mine trail with limited simultaneous mines. |
| Pinball | Ricochet 3 + Bank Shot 2 | Stronger chained bounces, clear falloff and a strict bounce limit. |
| Breach Engine | Last Shell 3 + Breach Loader 2 | Final shot and completed reload form a powerful alternating burst rhythm. |
| Hunter Swarm | Orbit Drone 3 + Targeting Link 2 | A small capped drone group focuses marked enemies. |

Primary-shot tags, secondary-effect tags, proc eligibility, target history, and maximum chain depth must be defined together. Secondary shards cannot spawn more shards indefinitely; drones cannot multiply drones; burning patches cannot recursively multiply patches. Snapshot final-shell and reload bonuses when the shot is created.

When all useful ranks are capped, offer Scrap Cache: five cosmetic scrap and one recovered heart, limited by maximum health. Currency keeps the reward useful at full health. This replaces further offensive inflation so capped builds retain predictable damage budgets. Never offer a capped/no-op rank or an empty picker.

## 9. Characters, loadouts, and lasting progression

| Character | Identity | Starting tradeoff |
|---|---|---|
| Rook | The existing shotgun survivor; dependable baseline. | Three health, balanced movement and reload. |
| Scrapper | Pickup control and explosive utility. | Larger attraction radius and stronger mines; lower direct primary damage. |
| Warden | Guard and close-range survival. | Four health and a guard advantage; lower movement speed. |

Select character, primary weapon, and arena before the run. Show passives and tradeoffs in plain language. Character passives must not require rolling a particular upgrade to function. All weapon/character combinations remain playable.

Version 1.0 progression is predominantly horizontal. Challenge unlocks provide new options; scrap buys cosmetics. Do not make early attempts deliberately weak to force permanent-stat grinding.

### Twenty explicit challenge unlocks

| # | Challenge | Reward |
|---|---|---|
| 1 | Complete or finish the playable tutorial | Carbine |
| 2 | Defeat 500 enemies across attempts | Scrapper |
| 3 | Survive eight minutes in one attempt | Warden |
| 4 | Defeat Shadow | Revolver |
| 5 | Defeat Demon | Arc Caster |
| 6 | Complete the first ten-minute cycle | Foundry arena |
| 7 | Perform the first evolution | Evolution recipe pages in the codex |
| 8 | Defeat Scorpion Queen | Queen trophy/profile emblem |
| 9 | Survive fifteen minutes | Veteran title |
| 10 | Survive twenty minutes | Endless trail cosmetic |
| 11 | Defeat 1,000 scorpions | Scorpion-themed charm |
| 12 | Defeat 100 elites | Elite hunter emblem |
| 13 | Defeat Shadow without taking damage during that encounter | Shadow palette |
| 14 | Defeat Demon without taking damage during that encounter | Ember palette |
| 15 | Complete a cycle with Pump Shotgun | Shotgun mastery badge |
| 16 | Complete a cycle with Carbine | Carbine mastery badge |
| 17 | Complete a cycle with Revolver | Revolver mastery badge |
| 18 | Complete a cycle with Arc Caster | Arc mastery badge |
| 19 | Discover all six evolutions across attempts | Engineer palette |
| 20 | Complete a cycle with each character | Survivor collection emblem |

Early locked recipes still appear as discoverable synergy hints; challenge 7 reveals the full reference, not a necessary mechanic. Core character/weapon unlocks should take a handful of engaging attempts, not dozens of hours. Cosmetics require actual finished assets and previews. Training cannot award challenges, scrap, or personal records.

## 10. Enemy roster and encounter director

| Role | Behavior | Counterplay / implementation requirement |
|---|---|---|
| Scorpion chaser | Basic pursuit; current sprite foundation. | Low durability, readable contact body, useful pellet targets. |
| Mummy bruiser | Slow durable approach and a close telegraphed strike. | Reposition during windup; actual multi-hit health. |
| Ranged revenant | Stops at a preferred range and fires distinct hostile shots. | Strafe; line of sight respects walls. |
| Skitter runner | Fast flank with a short committed lunge. | Visible anticipation and recovery; no instant turn during lunge. |
| Shield warden | Directional protection with exposed side/rear. | Flank or use effects; cannot form an impassable wall. |
| Burster | Approaches, arms, then explodes in a marked radius. | Escape the circle; explosion is hostile, explicit faction rules. |
| Brood nest | Slow or stationary spawner with a limited brood. | Prioritize the nest; parent plus children count against budgets. |
| Sentinel | Controls a small zone with a telegraphed pattern. | Leave the marked area; no offscreen unannounced damage. |

Elite modifiers should be readable variations: tougher body, faster pursuit within a cap, or a clearly marked extra attack. Avoid stacking every modifier or copying the same health multiplier onto every role. Every enemy has spawn, movement, attack, hurt, and death presentation as needed.

The director spends a threat budget on authored pack templates, unlocks roles over time, and alternates pressure with recovery. It considers boss state, current population, player position, and available arena space. Avoid spawning everything uniformly around the player every fixed interval.

Spawn outside the view but inside valid arena space. Near edges, use valid candidate regions; when an arrival must be visible, telegraph it for at least about 0.7 seconds and enforce minimum distance. No spawn can overlap the player, solid geometry, or an existing boss footprint. Leaving an area must not unload dangerous projectiles only to recreate them on return.

## 11. Three complete bosses — mandatory launch work

Boss work is a dedicated deliverable, not an unspecified later improvement. Shadow is required in the first complete playable slice. Demon and Queen complete the roster before release.

### Shared encounter contract

Each encounter has an arrival warning, introduction, name/health bar, matching visible and collision footprints, intentional attack scheduler, at least two phases, clear recovery windows, distinct sound, death presentation, reward core, cleanup, and persistent completion tracking. Attacks share the normal damage model.

Use shapes/patterns as well as color for warnings. Initial windups around 0.6–0.9 seconds and recoveries around 0.8–1.2 seconds are tuning seeds. Target roughly 60–90 seconds for the first boss with an ordinary early build, then test. Bosses must be beatable without one specific perk or evolution.

Reduce ordinary spawns during encounters. Prevent hazard combinations that eliminate every escape route. Enrage can add clearly announced pressure after a long encounter, but must not silently become an unavoidable death timer.

### Shadow: pursuit and spacing

- Reuse appropriate existing shadow animation frames after auditing pivots and cropping.
- Replace the huge canvas/tiny offset-hitbox mismatch with a visible body footprint.
- Alternate a fan of shadow bolts, a committed dash, and a close strike; make the dash endpoint readable.
- Below half health, add a second aimed fan or shorter recovery, preserving an escape gap.
- Replace the old constant projectile timer and unsafe delayed work with a cancellable state machine.
- Correct hostile faction filtering. Player weapons, mines, statuses, and drones all damage it through the same contract.
- Death cancels all pending attacks and awards one core. Existing hostile shots follow an explicit cleanup/fade rule.

### Demon: deliberate area denial

- Repair the existing run/attack animations and remove the hard-coded target offset.
- Implement the currently incomplete attack areas: visible cleave, delayed ground slam, and marked charge lanes.
- Match hitboxes to attack frames or scheduled active windows; anticipation never damages the player.
- Below half health, combine two previously taught patterns with a safe gap, rather than adding instant random damage.
- Remove debug rendering from release. Verify tall sprites do not hide the player, warnings, or HUD.

### Scorpion Queen: movement and brood pressure

- Create coherent original queen art and animations, building on the scorpion silhouette.
- Tail slam creates a marked impact area; a committed charge leaves a recovery opening.
- Summon a capped number of small brood enemies. They use the global population budget and cannot recursively spawn.
- Below half health, introduce short-lived poison zones with patterned edges and a strict active-area cap.
- Defeat completes the cycle milestone, awards its core and challenge, and transitions into continued survival.

### Boss acceptance matrix

For each boss test: spawn at all arena corners; every damage source; phase threshold crossed by one large hit; simultaneous lethal hits; death during a scheduled attack; player death at the same moment; pause/selection/background in every attack phase; save/restore; restart; long survival; missing audio. Verify no rewards duplicate, no projectiles survive into a new run, and no boss encounter blocks progression.

## 12. Arenas, obstacles, and readable space

**The Breach:** develop the current dungeon floor into a readable arena with sparse columns, wall landmarks, and distinct edge treatment. Preserve open movement lanes. Teach core combat here.

**The Foundry:** a second layout with different circulation, industrial landmarks, and limited telegraphed vent hazards after the player has learned basic combat. It must alter positioning, not merely recolor the floor.

Both need valid spawn regions, navigation/collision data, boss spaces, obstacle line of sight, and pickup reachability. The camera must fill the view at every edge and aspect ratio. If a view is larger than an arena dimension, fit/zoom or extend the valid floor intentionally; never expose black outside space.

Hazards have warning, active, and recovery states. Keep their simultaneous coverage bounded; an initial limit of one quarter of the visible floor is a testable starting point. Check overlap with boss attacks and obstacles. A player cannot be trapped behind a decoration that looks walkable.

Lighting, floor contrast, and prop density must support seeing projectiles and pickups. Avoid a detailed floor that competes with small moving sprites. Environment art must make boundaries intentional and attractive rather than merely hiding the void.

## 13. Game feel, sprites, effects, and audio

### Coherent art direction

Dark charcoal/plum environments, warm brass and shell accents, stepped pixel UI, restrained rust/red danger accents, and crisp silhouettes. Retain the current character's identity while improving consistency. New art is allowed; the earlier temporary instruction to preserve every sprite is superseded by this complete-game scope.

Create an asset manifest recording source/license, author or generation provenance, frame dimensions/count, pivots, hitbox footprint, muzzle anchors, palette, animation timing, and export location. Generated art is source material: clean pixels, remove inconsistent frames, and verify animation continuity before integration. Do not assume generated sheets are animation-ready.

Use a consistent pixel scale, nearest-neighbor filtering, and sensible atlas sizes. Start from the existing 32-pixel tile scale; choose character/enemy frame sizes through an on-device readability test. Audit transparent padding and texture memory before accepting large boss sheets.

Required art includes all three characters, four weapon presentations, eight normal enemy roles, elite indicators, three bosses, both arena kits, upgrade/evolution icons, pickups, attack warnings, status effects, and cosmetics. Every asset needs an in-game readability check, not just an attractive standalone image.

### Aiming and impact

Separate weapon aim from body movement so the muzzle follows the actual firing vector. Add north/south body poses where existing left/right frames cannot communicate direction. Reuse shared rigs/frames where coherent. Bullets should read as projectiles, not huge drifting cartridge cases.

Use immediate muzzle flash, small recoil, restrained hit flash, useful knockback, distinct kill feedback, and readable boss impact. Keep the player's location legible in a dense build. Shake and flashes have intensity limits and reduced-motion settings. Do not use global hit-stop in a way that breaks reload/selection clocks.

Player shots, hostile shots, XP, and hazards differ by silhouette and motion as well as hue. Give evolved effects a visual hierarchy: strong moment of activation, quieter sustained effect. Cap particles independently of damage; reducing effects must never change combat results.

### Audio and haptics

Ship a menu theme, two arena combat tracks, and a boss cue/track with smooth transitions. Cover shots, reload shells/completion, empty fire, dash, hit, kill, pickup, level-up, choice, boss warnings/death, player death, and UI confirmation. Layer variation without obscuring warnings.

Use voice limits, per-event cooldowns, and priority mixing to prevent hundreds of repeated kills or pickups from producing noise. Preload important assets; tolerate missing/failed audio without blocking play. Music and SFX sliders, mute, and haptic intensity persist. Respect platform audio interruption behavior and test headphones, silent mode, screen locking, and return from another app.

Haptics reinforce accepted damage, dash readiness, and major rewards; avoid vibrating on every pellet. Audio/haptics supplement visual information rather than carrying an exclusive warning.

## 14. All screens and player-facing flows

| Screen / flow | Required behavior |
|---|---|
| Startup | Short, resilient loading; no permanent spinner if audio fails; consistent orientation. |
| Main menu | Play, Continue only for a valid saved run, Loadout, Collection, Settings; no dead options. |
| Loadout and arena | Explain passives, weapon behavior, locks, and unlock conditions; retain selection. |
| Training / tutorial | Safe hands-on instruction, calibration access, skip/replay; no progression farming. |
| Run HUD | Health/guard, ammo/reload, XP/level, survival timer, pause, dash state; boss strip when relevant. |
| Upgrade selection | Stable three cards, ranks and exact changes, synergy hints, reroll/ban count; safe slow world behind. |
| Pause | Resume, controls/settings, abandon run, menu; clear distinction between saving and abandoning. |
| Results | Survival, kills, bosses, level/cycle, score/PB, cause of death, final build/evolutions, earned scrap/unlocks. |
| Unlock summary | Brief, dismissible, actual new content preview; never block Retry behind a long sequence. |
| Collection/codex | Discovered enemies, boss tells, weapon stats, upgrade ranks, evolution recipes, challenge progress, credits. |
| Settings | Audio, haptics, controls/editor, assist options, motion/flashes, text size where supported, reset choices. |
| Credits/support/privacy | Asset attribution, version/build, support contact, accurate offline/privacy statement. |

Use the same dark pixel language across every screen. Readable body copy matters more than using PressStart2P for paragraphs; use the display font sparingly and a readable supporting font for explanations. Fit large text without clipped cards or controls. Treat selected, pressed, focused, unavailable, and reloading states consistently.

Keep Retry within one or two clear actions from results. Avoid accidental abandon taps. Confirm destructive progress reset in settings; do not repeatedly confirm ordinary reversible navigation. If a new run replaces a saved run, make that consequence explicit before replacement.

## 15. Run state, slow motion, interruptions, and saving

Separate presentation time from logical run time. One global time-scale value cannot define every system's behavior.

| State | World presentation | Combat/input | Run/director/reload clocks |
|---|---|---|---|
| Playing | Normal | Enabled | Advance normally |
| Choosing upgrade | Existing world animates/drifts at 0.1× | No damage, firing, collection, kill rewards, or new spawns | Frozen; choices remain stable |
| Paused / background | Frozen | Disabled; pointers cleared | Frozen |
| Restoring | Static loading/paused scene | Disabled | Frozen until explicit resume |
| Results | Frozen or cosmetic death presentation | Disabled | Finalized once |

On returning from a choice, provide a short readable grace interval if needed; do not resume into unavoidable damage from overlapping projectiles. Existing reload visuals remain frozen while choosing and resume from the same logical point.

Persist settings, layouts, unlocks, cosmetics, records, and a resumable active run. Use a versioned schema, stable content IDs, atomic writes, and a recoverable backup. Save at upgrades, boss transitions, backgrounding, and a periodic checkpoint around every 15 active seconds. Mobile OS termination may skip lifecycle callbacks, so background-only saves are insufficient.

A run snapshot contains RNG state, loadout, arena/cycle, elapsed active time, player position/health, ammo and reload progress, perks, director and boss phase, relevant entity/effect state, pending offers, and reward settlement ID. Restore into pause. Do not simulate time spent away from the app. If restoring an attack would be unsafe, restore its anticipation state with a documented fair rule, never an already-active invisible hitbox.

Handle corrupted files, older schema migration, failed writes, full storage, and an incompatible run snapshot. Preserve permanent progress when only a run is invalid. Never duplicate unlocks/scrap because results are reopened or an app exits during settlement. Test both fresh install and upgrade from the current build.

## 16. Implementation architecture

Evolve the existing project incrementally. Do not combine every new feature into `game.dart` or the flat notifier, and do not rewrite healthy Flame infrastructure for its own sake.

| Layer | Responsibility |
|---|---|
| Immutable definitions | Weapons, enemies, bosses, upgrades, recipes, arenas, challenges, tuning values and stable IDs. |
| Run session model | Serializable state and deterministic clocks/RNG; no widgets or Flame component references. |
| Combat system | Damage, health/death, factions, statuses, projectile hit history, proc budgets. |
| Encounter director | Threat budget, packs, timing, boss scheduling, spawn geometry and recovery. |
| Loot/progression | Conserved XP, offers, ranks, evolutions, score, challenge events and settlement. |
| Flame components | Movement, animation, collision adapters, rendering; consume systems instead of owning unrelated timers. |
| Input service | Pointer ownership, calibrated layout, aim/movement vectors, action commands, cancellation. |
| Persistence service | Atomic save/load, migrations, checkpoints, backup, run settlement. |
| UI/state adapters | Riverpod exposes coarse player/HUD/menu state; no widget rebuild per entity mount or per projectile. |
| Audio/presentation | Prioritized effects and sound independent of authoritative damage. |

Suggested locations: `lib/data/`, `lib/models/`, `lib/systems/`, `lib/services/`, and existing component/view folders. Names may change during implementation; responsibilities should not.

Retain the existing shared arena bounds and repeating timer. Migrate every active boss, mine, shard, and old dialog away from uncancellable `Future.delayed` gameplay work. Remove unused competing dialogs and experimental paths once replacements are verified. Every timer/effect belongs to a run or encounter and is cancelled on teardown.

Add content validation: unique IDs, existing assets, valid rank limits, reachable recipe prerequisites, positive cooldowns, legal spawn weights, and complete localized/display text. Keep balance values in data so tuning does not require searching through render code.

Debug tools should allow selecting encounters/builds, fast-forwarding time safely, showing hitboxes, logging run events, and capturing performance counts. Gate them out of release. Reproducible seeds and event traces help explain a failure; do not expose implementation controls in the player UI.

## 17. Performance and stability budgets

Target stable 60 fps on the chosen supported iPhone and representative midrange Android during ordinary and developed-build combat. Use native profile frame timings and release playtests. The previous timer microbenchmark is not an FPS measurement.

Initial profiling budgets: 120 ordinary enemies, one boss with reserved headroom, 384 active combat projectiles, 80 merged XP pickup components, and about 300 visible particles. These are implementation starting points, not final difficulty design. Boss adds count within the enemy limit. If the director reaches a cap, spend future pressure on appropriate existing threats rather than spawning beyond it.

Damage/effects must stay correct when visual budgets are exhausted. Use spatial queries where traces show collision/search costs, preallocated buffers where allocation is measured, and pooling only where lifecycle correctness is proven. Reduce offscreen decision frequency without teleporting enemies or skipping collision. Avoid image decode and uncached audio loads during first attacks.

Measure update/raster frame distributions, allocation, memory, entity counts, audio voices, and battery/thermal behavior. Target the 16.7 ms frame interval and investigate sustained misses rather than quoting a favorable average. Run at least 30 minutes on each target class and a 60-minute endless soak; memory should settle rather than grow with every wave or restart.

Quality settings reduce shadows, particles, shake, and decorative effects, never enemy health or spawn count. Gameplay difficulty assists are separate settings. Choose and document the minimum supported devices/OS versions after measurement; do not infer them from the development phone alone.

## 18. Verification, balance, and accessibility

### Automated coverage with useful failure cases

- Damage amounts, armor, immunity, simultaneous lethal hits, exactly-once rewards, factions, and projectile tunneling.
- All normal reload durations/shell sounds, upgrade ceilings, every interruption, restart, and restore.
- XP conservation/overflow, capped offers, rerolls/bans, six-slot restrictions, every recipe, all-capped fallback.
- Mine/status/ricochet/drone proc caps; no secondary-effect explosions or duplicate target damage.
- Director timing, edge spawns, population limits, delayed boss requests and recovery.
- All boss attacks/phases and teardown; obstacle geometry and safe attack space.
- Save migration/corruption, atomic settlement, checkpoints, background/OS-kill recovery.
- UI layouts, large text, safe areas, pointer cancellation, navigation, and results/retry.

Use actual components/assets for integration checks where domain tests cannot establish behavior. Inspect rendered HUD/menu/selection/results images. Rendering tests do not replace human control tests or physical performance captures.

### Human playtest matrix

Test all 12 character/weapon combinations at least through the first boss; cover both arenas, all three bosses, all six evolutions, and late endless pressure. Use seeded scenarios for rare combinations instead of waiting for random offers. Test weak, ordinary, and extreme builds, including no evolution.

Observe first-time players without explaining the controls verbally. Can they move and fire, understand a kill drop, choose an upgrade, recognize reload, dodge a warning, and retry? Record confusion and change the product. Observe experienced players for dominant builds, dead choices, empty periods, and unavoidable deaths.

Track first-upgrade timing, deaths by source, boss duration, hit frequency, offer selections, reload downtime, and control misfires in development logs. These support design decisions; they do not prove retention or commercial success. Any external crash/analytics service requires a deliberate privacy decision and accurate disclosures.

Accessibility includes non-color warnings, adjustable control size/opacity, left-handed layout, readable text, optional aim assist, reduced motion/flashes, independent audio, and haptic control. Optional enemy-speed/damage assists must be explained and recorded consistently. Every critical warning has a visual form.

## 19. Implementation milestones and acceptance gates

These are substantial deliverables in dependency order, not estimates or a promise to finish within a day. Fixes, art, and testing happen inside each deliverable; they are not all postponed to the end.

### M0 — Lock the baseline and content contract

Record current branch/worktree, reproduce current tests/builds, retain the user's changes, capture current phone behavior, and inventory assets/licenses. Establish named tuning data and a requirements tracker linked to this document. Preserve reload and slow-selection regression cases.

**Exit:** current behavior and known gaps are reproducible; the scope and acceptance gates are agreed working specifications. No existing unfinished experiment is labelled complete.

### M1 — Comfortable controls and authoritative combat

Implement logical-pixel layout, pointer ownership, dash/reload placement, calibration/editor, and persistence of control settings. Introduce real health/damage/death and projectile faction rules; complete dash/reload lifecycle behavior. Validate the protected shotgun baseline.

**Exit:** comfortable movement + aim + dash on the iPhone; no stuck input or accidental action overlaps; multiple-hit enemies and exactly-once kills work. Check Android geometry early rather than discovering it at release.

### M2 — One complete playable survival slice

Rook + shotgun + Breach; scorpion, mummy, ranged enemy; kill-earned XP and magnet; three stable upgrade offers; six representative upgrade families and one working evolution; basic director; **fully functioning Shadow boss**; results, Retry, personal best, foundational run save/resume; representative music, attacks, and UI presentation.

The six-family slice should include Last Shell, Breach Loader, and Breach Engine so it tests the reload/build identity. Include enough additional damage, defense, and movement choices to make decisions meaningful.

**Exit:** a fresh player can learn, form a build, fight Shadow, die, see accurate results, resume an interrupted run, and retry without developer intervention. The loop is enjoyable before adding the rest of the roster.

### M3 — Full loadout and build system

Complete all four weapons, including their distinct reload/recharge animations and sound schedules, three characters, thirty families, six evolutions, proc limits, rerolls/bans, caps/fallbacks, descriptions, and build recap. Integrate finished or production-quality sprites and effects as each item lands.

**Exit:** every family and recipe is reachable, understandable, and functional; several distinct builds clear the first boss; no single option is a compulsory answer.

### M4 — Enemy variety, two arenas, and endless director

Complete eight enemy roles, elites, pack composition, collision/navigation, Foundry, hazards, edge-safe arrivals, and full cycle scaling. Integrate loadout/arena unlock conditions.

**Exit:** both arenas support a full cycle without invalid spawns or unavoidable traps; pacing contains pressure and recovery; population/effect budgets hold.

### M5 — Complete boss progression

Finish Demon and Scorpion Queen; integrate all three bosses into the director, phase UI, audio, cores/evolutions, cycle milestones, challenge events, and save/restore. Revisit Shadow against all new weapons and effects.

**Exit:** all boss acceptance cases in section 11 pass. Ten minutes produces a satisfying milestone and continued survival. No boss is merely present as an unused source file.

### M6 — Complete progression and presentation

Finish the twenty challenges, cosmetics, collection, menu/loadout/results flow, all production sprites, coherent UI, directional weapons, animation/effect polish, music, mix, haptics, and credits. Recheck control visibility during maximum effects.

**Exit:** every player-facing screen and content item is finished; no placeholder icons, mismatched button family, incomplete sprite animation, silent warning, or dead navigation remains.

### M7 — Mobile resilience and accessible onboarding

Complete all settings, tutorial refinements, assist modes, saved-run migrations/recovery, background/phone-call/lock behavior, storage failure handling, and accessibility checks. Exercise existing checkpoint foundations against the full content roster.

**Exit:** clean install, update, app termination, and Continue are reliable on iOS and Android; records/progress never duplicate or vanish through ordinary use.

### M8 — Balance, performance, and release-candidate playtests

Run the combination matrix, first-time sessions, boss fairness checks, 30-minute physical sessions and 60-minute soak. Profile representative devices and optimize measured bottlenecks. Resolve dominant builds, unrewarding choices, and control discomfort.

**Exit:** no crash, freeze, unbounded growth, broken run, unfair mandatory pattern, or unresolved primary control issue. Evidence includes native captures and hands-on findings, not just analyzer output.

### M9 — Distribution and launch package

Produce signed iOS and Android distribution builds, test upgrade paths, prepare icons/screenshots/preview, metadata, privacy/rating/support materials, asset credits, and release notes. Repair stale Makefile/deployment commands and establish repeatable checks/builds. Separate Android upload signing from debug keys.

**Exit:** the exact candidates intended for distribution pass the final checklist below. Store upload/review timing is separate from game completion.

## 20. Traceability: the concerns that cannot disappear

| Concern | Required solution | Gate |
|---|---|---|
| Jank as enemies accumulate | Bounded entities/effects, native profiling, fair director, long-run memory checks | M4, M8 |
| Black outside the arena | Shared geometry, camera/aspect-ratio coverage, valid boundaries and obstacle rules | M1, M4 |
| Terrible/inconsistent buttons | One finished UI language across all screens and action states | M1, M6 |
| Inconvenient joystick/action positions | Thumb-based layout, calibration, independent customization, physical testing | M1, M8 |
| Preserve painstaking shotgun reload | Protected formula, shell schedule, Lottie timing and interruption tests | M0 onward |
| Slow upgrade world was deliberate | Safe 0.1× presentation with explicit logical clocks | M2, M7 |
| Bosses mentioned but not actually planned | Shadow in M2; Demon and Queen in M5; shared encounter acceptance matrix | M2, M5 |
| Prototype lacks a satisfying loop | Kill XP → choices → build → elites/bosses → milestone → death/results → unlock/retry | M2–M6 |
| Sprites not strong enough | Asset manifest, coherent new art, directional aiming, complete animation/readability checks | M3–M6 |
| Too many small fixes, no complete game | Stage gates produce complete playable systems; launch scope and final acceptance are explicit | All milestones |
| Previous audit still has open items | Real health/rewards, dormant timer/faction migration, settings/saves/tutorial, credits/signing and device tests | M1–M9 |

## 21. Final definition of done

A build is a release candidate only when all of the following are evidenced:

- [ ] The launch content table is fulfilled, and every item is reachable through ordinary play or an explicit unlock.
- [ ] A clean install teaches the controls without verbal explanation; the creator finds the physical layout comfortable.
- [ ] All four weapons and three characters have distinct, viable roles; thirty upgrade families and six evolutions work as described.
- [ ] All eight enemy roles, both arenas, elites, and three bosses function through repeated cycles.
- [ ] Kill XP, score, challenges, cosmetic rewards, and results are correct and settle exactly once.
- [ ] Normal shotgun reload timing/presentation is preserved; slow upgrade selection remains deliberate and safe.
- [ ] No outside-map view, inaccessible drop, unavoidable spawn, stuck input, negative ammo, or cross-run leaked effect is reproducible.
- [ ] Save/Continue, restart, backgrounding, lock, audio interruptions, OS termination, and migration pass on physical devices.
- [ ] All menus, HUDs, cards, settings, collection, results, and credits have finished layouts and readable text.
- [ ] Production art/audio is integrated, legally accounted for, and visually readable during developed builds.
- [ ] Tests, analyzer, production builds, device playtests, performance traces, and long-run evidence are recorded; failures are resolved.
- [ ] Android release signing, iOS distribution configuration, versions, support/privacy details, ratings, and store assets are verified against current platform requirements.
- [ ] No unresolved crash, data-loss bug, broken progression, unfair mandatory encounter, or primary-control problem remains. Lesser known limitations are explicitly reviewed rather than hidden behind “tests passed.”

The product is complete when the full experience holds together on a phone. The implementation sequence starts with comfortable controls and a complete combat loop, proves that loop with Shadow, and then expands it into the full game described here.


## Monetization/backend update — 19 October 2026

The creator has requested native Apple/Google monetization research and expressed a preference for SpacetimeDB, with multiplayer as a future update. The detailed successor plan is [REGUN_MONETIZATION_AND_BACKEND_PLAN.md](REGUN_MONETIZATION_AND_BACKEND_PLAN.md); its [source record](research/MONETIZATION_SOURCES_2026-10-19.md) distinguishes observed requirements from proposals.

This extends the roadmap; it does not mean billing, accounts or multiplayer are implemented. Keep the existing free earned unlocks, offline solo game and shotgun/slow-motion identity. Prototype Flutter-to-SpacetimeDB compatibility before migrating paid state; build permanent content purchases first, then durable downed/continue handling and optional rewarded ads, followed by authoritative co-op. The current death settlement must be refactored before adding a paid revive. Do not confuse current local Scrap with a verified cash-purchased wallet.
