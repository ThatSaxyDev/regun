# Regun — what is in the build, how to test it, and what is unfinished

Updated: 20 October 2026. This guide describes the implemented build, rather than everything we might eventually add. Use it as a testing notebook: check a box only after you have actually tried that item on the phone.

## 1. Start here

Regun is now an endless, manually aimed twin-stick survival shooter. Move, aim/fire, dash, reload, collect kill XP, choose upgrades, combine a build, defeat bosses, then survive harder cycles until death. Normal runs feed horizontal unlocks and cosmetic progression. There is no campaign-ending victory screen; surviving into another cycle is the objective.

The functional roster is **four weapons, three survivors, two arenas, eight normal enemy roles, eight bosses, thirty upgrade families, six fusions, and twenty challenges**. The build also includes a collection, cosmetics, training, saved runs, adjustable controls, settings, music, and sound effects.

It is a **full-content test build**, not a claim that balance, final art, comfort, or physical performance is finished. Some of those can only be judged by playing. You do not have to test everything in one sitting.

### Fastest way to see the new work

1. Open **Training** on the starting screen.
2. Choose a survivor, weapon, and arena. Training permits every loadout without needing normal unlocks.
3. Move, aim/fire, dash while moving, and manually reload.
4. Pause. Summon a boss from the practice buttons, or select one of the six fusion presets.
5. A fusion preset supplies its prerequisite ranks and opens the real core selection. Choose the fusion, resume, then test its effect.
6. Return to the menu and inspect **Collection**. Its tabs list upgrades, recipes, enemies, challenges, styles, and credits.
7. Later, use **Play** for a normal run. Training does not prove the normal progression or difficulty curve.

Training prevents health damage by default; Pause → Take damage → On enables damage and center respawn. It does not award normal run scrap, records, combat challenges, or boss unlocks. Completing or skipping the short introduction does unlock Carbine. Training is a practice space, not a way to farm the normal profile.

### Recent fixes to retest

The reported freeze after three hits was reproduced: combat reached game over, but the results overlay collapsed to zero size. The overlay now retains full-screen bounds. Retest a normal contact death during reload, tap Restart, die again and tap Menu. Automated coverage now checks that entire sequence with saving working and no warning banner, including once-only result settlement.

### Settings navigation fix

**Back is now fixed in the top-right of Settings**, next to the heading. The settings below it can scroll without moving Back off screen. It returns to whichever screen opened Settings. Returning from in-run Settings should leave you at the pause menu, rather than unexpectedly resuming combat.

## 2. Suggested testing sessions

| Session | Approximate time | What to concentrate on |
|---|---|---|
| A — feel and navigation | 10–15 minutes | Starting screen, Settings Back, controls, each gun, pause/resume, exit. |
| B — bosses and fusions | 20–30 minutes | Use Training to summon all bosses and try all six fusion presets. |
| C — an ordinary attempt | One uninterrupted run | First-minute pacing, XP/choices, bosses, death/results, unlocks, retry. |
| D — saves and progression | 15–20 minutes | Continue, partial reload, app background/lock/termination, collection/shop. |
| E — sustained load | At least 30 minutes | A developed normal build, both arenas over separate attempts, responsiveness, heat, battery and hitches. |

If a menu traps you, a control stops responding, a run crashes, or progress disappears, report that first. Those matter more than fine damage tuning.

## 3. Every screen and what to verify

| Screen / entry | What it does | Check on your phone |
|---|---|---|
| Starting screen | Play, Training, Collection, Settings; Continue when a valid normal checkpoint exists; best score when present. | Title/actions align, character is appropriately small, no clipped buttons. |
| Play | Opens the introduction if unfinished; otherwise opens normal loadout selection. | First-time path is understandable. Replacing a saved normal run asks before discarding it. |
| Loadout | Select survivor, weapon, arena. Locked options explain their requirements. | Selected state is clear; Start uses your actual selection. Training allows the entire roster. |
| Training | Five introduction prompts plus repeatable practice. | Move → shoot → dash → manual reload → XP/upgrade can all complete. Skip/Ready returns cleanly. |
| In-game HUD | Health, survival time, kills, level/cycle, XP progress, ammo/reload; boss name/health during encounters. | Readable without covering threats, notch/home-indicator safe, correct after a reload or upgrade. |
| Pause | Resume, Controls, Restart, Settings, Menu; boss/fusion practice actions in Training. | Time/reload do not advance normally while paused; leaving clears stick input. |
| Controls | Calibration, handedness, fixed/floating, Arrange, Reset, Done. | Changes appear immediately and survive returning later. Details below. |
| Upgrade / Fuse | Stable offers with ranks/effects, ban/reroll when available, explicit fusion choice. | One tap applies one choice. Old/double taps cannot spend twice. |
| Results | Cause of death, run statistics/build, fusions, earned scrap, records and new unlocks. | Correct run/loadout, no duplicate rewards when leaving/reopening, Restart starts fresh. |
| Collection | Six tabs: Upgrades, Fusions, Enemies, Challenges, Style, Credits. | Horizontal tabs and vertical content scroll; Back is reachable. Discovery/completion states persist. |
| Settings | Separate music/SFX levels, haptics, reduced motion, aim assist; profile reset from menu settings. | Back stays visible at all scroll positions; toggles persist. |

**Reset progress is destructive.** It has a confirmation and clears the profile/records and saved run. Test cancellation freely; confirm a reset only when you intentionally want to erase this device's test progress. It does not mean “reset controls.”

## 4. Combat and the four weapons

Default movement is left, aiming/firing is right. Holding an aim direction fires repeatedly. Releasing the aim stick stops firing. Emptying the magazine starts reload automatically; the reload button also allows a partial-magazine reload. There are no finite reserve-ammo pickups to manage.

| Weapon | Starting magazine | Identity | Base reload | What to feel for |
|---|---:|---|---|---|
| Pump Shotgun | 5 | Three initial pellets, broad close-range spread. | 0.9 s for one missing shell; +0.7 s per additional missing shell. Empty five-shell reload: 3.7 s. | Spread is useful, shell timing feels right, ammo display matches animation/sounds. |
| Carbine | 24 | Fast sustained fire with lighter individual hits. | 1.8 s | Consistent cadence, readable magazine swap/bolt action, no shotgun animation. |
| Revolver | 6 | Slower heavy rounds with longer reach. | 2.1 s | Hits feel substantial, deliberate cadence, cylinder reload/ejection is distinct. |
| Arc Caster | 6 | Three-damage bolts, two innate jumps retaining 85% damage per hop, 240-unit jump reach. | 2.4 s | Faster bolts, .75 s cadence, heavier electrical feedback; a base discharge clears three ordinary scorpions. |

Reload times above are the unmodified starting values. Reload and magazine upgrades change them. The original shotgun Lottie and normal shell-sound schedule are preserved: an empty five-round reload cues at 0, 0.7, 1.4, 2.1, and 2.8 seconds, ending at 3.7 seconds.

### Weapon checklist — repeat with each gun

- [ ] Aim in every direction while standing and moving. Gun direction follows aim rather than only the body facing.
- [ ] Hold fire until empty; automatic reload completes and firing resumes while aim is held.
- [ ] Fire one shot, then manually reload. Full-magazine reload does not waste or corrupt ammo.
- [ ] Pause partway through reload. Resume without duplicate sounds, lost ammo or a prematurely completed animation.
- [ ] Dash while moving and firing; movement does not require lifting the movement thumb.
- [ ] Shoot through a crowd, near columns and beside arena boundaries. Walls should block shots; enemies should not take hits through a wall.
- [ ] Enemy health matters: tougher enemies survive weak hits, and death/rewards happen once.

### Survivors

| Survivor | Starting role | How to compare |
|---|---|---|
| Rook | Six hearts; balanced baseline. | Establish the reference feel with each gun. |
| Scrapper | Six hearts, larger XP attraction, stronger mines, 15% lower direct primary damage. | XP reaches you from farther away; compare normal shots and Dash Mine damage with Rook. |
| Warden | Eight hearts, recharging guard, slower movement. | Guard absorbs a hit, then recharges; movement is slower but survivability is higher. |

Try all **twelve survivor/weapon pairs** eventually. Start with each gun on Rook, then compare the other two survivors using your favourite gun. Roles are implemented, but none is certified balanced or equally enjoyable yet.

## 5. XP, thirty upgrades, and build choices

Enemies drop XP when defeated. XP increases level and opens upgrade choices. It no longer depends on an endless supply of unrelated ambient coins. When the drop budget fills, earned XP merges into existing drops instead of being discarded.

The deliberate **0.1× world presentation during selection remains**. Your logical combat/run/reload clocks wait for the choice; selection should be safe. This explanation is for testing, not additional in-game narration.

All thirty families have **eight ranks**. Later picks have smaller but rewarding gains, with stricter reload/dash limits. A build can take up to **six different special families** and up to **two fusions**; core/utility families do not use the six special slots. Taking an existing family's next rank does not consume a new special slot. A card flags the final special slot. Each run starts with **two rerolls and one ban**.

Training offers fusion presets, not a free editor for every arbitrary upgrade. Test other families by gaining XP and selecting their cards. The collection explains every family even before you discover its effects.

### Upgrade catalogue

| Family | Group | Implemented effect / observation |
|---|---|---|
| Heavy Load | Core | +35% base projectile damage. |
| Quick Trigger | Core | Fire 15% faster. |
| Extended Tube | Core | Larger magazine; refill immediately. |
| Sleight of Hand | Core | Reload faster. |
| Scattershot | Core | More projectiles; wider spread. |
| Piercing Rounds | Core | Hit additional enemies. |
| Long Barrel | Core | Increase effective range. |
| High Velocity | Core | Faster projectiles. |
| Fleet Foot | Utility | Move faster. |
| Vitality | Utility | Add a heart and recover one. |
| Field Medic | Utility | Each kill has a 5% / 10% / 15% chance by rank to restore one heart, up to maximum health. |
| Scrap Armour | Utility | Absorb a hit; guard recharges. |
| Quickstep | Utility | Dash recharges faster. |
| Afterimage | Utility | Longer dash protection. |
| Scavenger | Utility | Attract XP from farther away. |
| Lucky Find | Utility | Special upgrades appear more often. |
| Hot Shot | Special | Hits ignite enemies. |
| Accelerant | Special | Burning kills ignite nearby enemies. |
| Static Charge | Special | Primary hits can arc to another enemy. |
| Conductive Core | Special | Lightning chains farther and hits more targets. |
| Dash Mine | Special | Leave a mine after a dash. |
| Fragmentation | Special | Explosions emit a small shard burst. |
| Ricochet | Special | Projectiles bounce to a new enemy. |
| Bank Shot | Special | Bounced shots hit harder. |
| Last Shell | Special | Final shot: +60% damage per rank. |
| Breach Loader | Special | First shot after reload: +50% damage per rank. |
| Orbit Drone | Special | A companion fires at nearby enemies. |
| Targeting Link | Special | Shots mark targets for drone focus. |
| Shrapnel | Special | Kills can release a close-range shard cone. |
| Executioner | Special | Deal more damage to wounded enemies. |

### Upgrade checklist

- [ ] Take one rank, then compare its described effect with the prior state.
- [ ] Take higher ranks. The displayed rank increases, and capped ranks stop appearing.
- [ ] Reroll: offers change and the counter decreases once. Ban: the chosen family is removed from future offers and the ban counter decreases once.
- [ ] Reach six special families. Existing families can still rank up; a seventh distinct special family is not offered.
- [ ] Select while enemies are near you. You should not lose health while reading the choice.
- [ ] Pause/background during a choice and return. The pending choice remains valid.
- [ ] At a fully capped build, **Scrap Cache** grants five cosmetic scrap and recovers a heart if injured. It is the endless fallback, not another uncapped damage increase.

Some effects are chance-based: a single hit/kill may not demonstrate lightning, healing or shrapnel. Compare a sequence of attacks before reporting “does nothing.” Also watch for the opposite bug: secondary effects creating an uncontrolled, self-repeating explosion/chain storm.

## 6. All six fusions — the easiest practice route

In Training, pause and select the named recipe. It supplies prerequisite ranks and opens **Fuse**. Choose the named fusion, then resume. Switching practice presets is a testing shortcut; normal runs must earn their prerequisites and a boss core. Practice does not prove how easy the recipe is to obtain in an ordinary run.

| Fusion | Required ranks | Test action | Expected difference |
|---|---|---|---|
| Firebreak | Hot Shot 3 + Accelerant 2 | Shoot and defeat burning enemies near a group. | Eligible ignition kills leave limited, short-lived burning ground. |
| Storm Circuit | Static Charge 3 + Conductive Core 2 | Shoot clustered enemies; Arc Caster is an easy comparison. | Lightning reaches additional nearby targets with bounded chaining. |
| Minefield | Dash Mine 3 + Fragmentation 2 | Dash past/away from enemies, then let them approach the trail. | A short three-mine trail arms, explodes and emits shards. |
| Pinball | Ricochet 3 + Bank Shot 2 | Fire into a spread-out group. | Extra target bounces with stronger bounce damage; shots still expire. |
| Breach Engine | Last Shell 3 + Breach Loader 2 | Compare the last magazine shot and the first after a completed reload. | Both burst windows become stronger. It changes damage rhythm, not the reload animation into a different weapon's. |
| Hunter Swarm | Orbit Drone 3 + Targeting Link 2 | Mark a target by shooting it while others are nearby. | Three drones contribute support fire and prefer marked targets. |

- [ ] Every preset opens a selectable, correct core choice.
- [ ] Effect is visible/useful without hiding all enemy warnings.
- [ ] Effects remain limited, expire, and clear on restart.
- [ ] A third fusion is not offered in a normal two-fusion build.
- [ ] Each fused build survives Save/Continue correctly in a normal run.

## 7. Arenas, enemy roles, and bosses

### Two arenas

**The Breach** is the more open dungeon with sparse columns. **The Foundry** has more obstructed routes, a different floor treatment, and marked vent pressure after a boss has been defeated, outside active boss encounters. Both retain a finite arena; there is no infinite scrolling world generator.

- [ ] Walk and dash to all four edges and corners. The camera must not expose black space beyond the floor.
- [ ] Slide around columns without clipping into them or getting permanently stuck.
- [ ] Dash toward a column, including during a hitch. It must not let you tunnel through.
- [ ] Enemy pursuit and boss movement respect the same obstacles.
- [ ] XP remains collectable near walls/columns. Any inaccessible drop is a bug to report.
- [ ] Foundry vent warning appears before damage and can be escaped.

### Enemy field guide

Arrival times below describe ordinary director eligibility, not an exact guaranteed spawn time. Random selection and population limits affect the actual encounter.

| Enemy | Becomes eligible | What makes it different | What to test |
|---|---|---|---|
| Scorpion | Start | Continuous pursuit. | Pressure increases without immediate unfair contact spawns. |
| Mummy | About 25 s | Slower bruiser with close-range attack. | You can leave its reach before the strike. |
| Revenant | About 65 s | Ranged attacks. | Strafe shots; enemy projectiles do not damage their own side. |
| Skitter | About 1:50 | Committed lunge followed by recovery. | Lunge is readable and you can exploit the recovery. |
| Shield Warden | About 3:40 | Directional armor and a vulnerability window. | Front shots are less effective; positioning/recovery matters. |
| Burster | About 4:30 | Marked explosion. | Warning matches the actual damaging area and has escape time. |
| Brood Nest | About 6:40 | Spawns a limited brood. | Destroying it matters; adds do not grow without a cap. |
| Sentinel | About 7:40 | Marks dangerous ground. | Mark first, damage later; leaving the zone works. |

Some later roles can be elites: more health/speed and a visual distinction. Later cycles increase enemy durability and pressure. Check that elites remain identifiable in a crowd.

### Eight bosses

| Boss | Ordinary eligibility | Patterns to look for |
|---|---|---|
| Shadow | Random, from first encounter | Aimed shot fans, committed dash, close strike, recovery, a stronger second phase. |
| Demon | Random, from first encounter | Cleave, marked slam and charge lane, with second-phase pressure. |
| Scorpion Queen | Random, from first encounter | Tail strike, capped brood, lingering poison and a second phase. |

Encounter requests occur around 3, 6 and 10 minutes per cycle; their boss identities are randomized. Normal play keeps one active boss. A long fight delays later encounters, and there is recovery after defeating one. A saved shuffled bag rotates all eight from the first encounter, without repeats within a bag or an immediate repeat across bags. Training Boss Rush draws random single bosses or distinct pairs. Cycle number follows elapsed ten-minute periods; progression rewards for “complete a cycle” currently use defeating Queen.

The five additions are Bellkeeper, Chain Magistrate, Mirror Saint, Kiln Sovereign and Last Marshal. See [Boss Rush practice](PLAYTEST_GUIDE.md#eight-boss-candidate--boss-rush) for moves, weak points and animation checks.

For each boss:

- [ ] Summon it in Training to learn its shapes and timing. Training invulnerability means this alone cannot establish damage fairness.
- [ ] Confirm the boss name/health bar, damage response, and second phase below half health.
- [ ] Watch each warning and dodge it. Warning location/shape must match the damaging attack.
- [ ] Check recovery windows permit attacking/reloading instead of constant unavoidable pressure.
- [ ] Repeat in a normal run to assess real health loss and fair escape routes.
- [ ] Defeat it. Health bar and owned attacks clear, reward/core appears once, and the next boss does not stack immediately.
- [ ] Pause/background mid-encounter; Continue restores remaining health with a safe new anticipation rather than resuming an invisible attack instantly.

## 8. Normal progression, collection, and cosmetics

Normal run rewards settle at the end of the run. Leaving a live run saves it; it does not cash out all challenges as though you had died. Continuing and returning to results must not award the same run twice.

**Scrap earned:** run scrap bonuses + one per ten kills + fifteen per defeated boss + one per complete minute survived. Scrap purchases cosmetics, not permanent combat strength. Copper/Moss cost 100 each; Ivory costs 150.

Style rewards include palettes, emblems/charms, a crown-like Queen trophy, veteran markings and an Endless trail. Some challenge rewards are completion/mastery badges or discovery markers in the collection, rather than separate equippable items. The recipe archive does not hide the recipe reference until unlocked; recipes can be read in Collection already.

### Twenty challenges

| Challenge | Requirement | Reward |
|---|---|---|
| First Steps | Complete training | Carbine |
| Clean Sweep | Defeat 500 enemies | Scrapper |
| Hold the Line | Survive 8 minutes | Warden |
| Out of the Dark | Defeat Shadow | Revolver |
| Cool the Furnace | Defeat Demon | Arc Caster |
| First Cycle | Defeat Scorpion Queen | The Foundry |
| Fusion Made | Create a fusion | Recipe archive |
| Royal Pardon | Defeat Scorpion Queen | Queen emblem |
| Still Standing | Survive 15 minutes | Veteran title |
| Beyond the Breach | Survive 20 minutes | Endless trail |
| Pest Control | Defeat 1,000 scorpions | Scorpion charm |
| Elite Hunter | Defeat 100 elites | Hunter emblem |
| Untouched Shadow | Defeat Shadow without being hit | Shadow palette |
| Untouched Flame | Defeat Demon without being hit | Ember palette |
| Pump Action | Complete a cycle with Shotgun | Shotgun badge |
| Steady Hands | Complete a cycle with Carbine | Carbine badge |
| Six Chambers | Complete a cycle with Revolver | Revolver badge |
| Live Wire | Complete a cycle with Arc Caster | Arc badge |
| Full Circuit | Discover all six fusions | Engineer palette |
| Everyone Out | Complete a cycle with every character | Survivor emblem |

### Progression checklist

- [ ] Normal locked choices unlock after the appropriate completed run/training introduction.
- [ ] Total-kill/scorpion/elite challenges accumulate across attempts rather than resetting each run.
- [ ] Best records never decrease after a worse attempt.
- [ ] Equipped style visibly changes the character/accessory/trail during play and remains selected after reopening.
- [ ] Buying an affordable style deducts the correct scrap once; an unaffordable style cannot be purchased.
- [ ] Training combat does not unlock bosses/characters or add normal currency/records.
- [ ] Restart, Menu, and repeated taps at results cannot award the same run twice.

**Current assisted-run distinction:** aim-assist runs have separate records. Time-based challenge checks currently consult the standard best-survival record, so assisted survival time alone does not unlock Warden/Veteran/Endless. Other eligible normal-run challenge types still settle. This behavior needs a product decision and clearer communication before launch.

No-hit boss rewards currently mean **no health lost while that boss was active**, including ordinary enemies present during the encounter. A guard-absorbed hit does not count as lost health. Decide whether that matches the intended challenge wording when testing.

## 9. Controls, settings, audio, and presentation

### Control setup

Open Pause → Controls. Dash and reload stay on the aiming side, so the movement thumb can remain on movement. Left-handed mode mirrors the whole arrangement. The custom Right/Left selector replaces the generic switch.

| Setting | What to judge |
|---|---|
| Horizontal reach / height | Comfortable thumb reach without resting over the home indicator or obscuring too much combat. |
| Stick size | Easy to grab without making the center of the playfield crowded. |
| Opacity | Visible enough to locate controls; transparent enough to read threats beneath them. |
| Sensitivity | Aim/movement reaches useful response without an excessive thumb travel. |
| Dead zone | Small resting movements do not accidentally shoot, but deliberate motion responds promptly. |
| Fixed / Float | Fixed centers stay put; floating sticks anchor within their relevant input areas and reset after release. |
| Arrange | Drag individual movement/aim/dash/reload positions. Invalid overlapping/opposite-side arrangements are rejected or safely constrained. |
| Reset | Restores control defaults, not progression. |

- [ ] Move + aim together, then dash while moving. Repeat with mirrored and floating controls.
- [ ] Release every finger: no continued movement/fire. Pause, open another screen, lock/background, return: no stuck input.
- [ ] Drag near another control: touches do not activate the wrong action.
- [ ] Confirm custom positions persist after leaving/reopening.

### Settings and audio

- [ ] Back is visible immediately on entry and after scrolling. Test from both menu and in-run pause.
- [ ] Music slider affects music, Sound affects effects; zero actually silences the relevant channel.
- [ ] Menu, Breach, Foundry and boss music switch in the appropriate contexts and loop.
- [ ] Every gun and non-shotgun reload has its own cues. The shotgun retains its original shell cues.
- [ ] Volume balance allows threats/hits/reload to be heard through the music.
- [ ] Haptics respond to accepted health damage when enabled, without vibrating continuously on every overlapping frame.
- [ ] Reduced motion suppresses extra particle/trail motion; it does not remove essential attack warnings or freeze all sprite animation.
- [ ] Aim assist gently biases aimed fire toward nearby valid targets; manual aiming is still necessary.
- [ ] Try headphones/Bluetooth, background/foreground, a call or other audio interruption. These are native-device checks, not yet proven by unit tests.

The new music and additional cues were synthesized by a small original Python audio generator in the repository, then integrated through SoLoud. They are real generated sound files, not an online music service. The loops/timbres/mix are a functional first pass; longer compositions, richer instrumentation and smoother transitions are valid future polish work.

## 10. Save, Continue, and interruptions

Normal runs save periodically (about every fifteen active seconds), on pause/background, exit and relevant state changes. Continue restores loadout/build, position, ammo/reload progress, pending choices, live enemy/boss health and XP drops. It opens paused. Transient hostile projectiles/areas are discarded, with brief resume protection; a boss restarts an anticipation rather than reproducing a mid-frame attack exactly.

That is intentional recovery behavior, not a pixel-perfect combat replay. Nothing simulates while the app is closed. Training should preserve any existing normal checkpoint.

| Test | Steps | Expected result |
|---|---|---|
| Partial reload | Fire, reload, pause midway, go to Menu, Continue. | Same normal run; reload resumes from saved progress. |
| Pending upgrade | Gain a level, leave/background during selection, Continue. | Valid pending choice, no free second application. |
| Damaged boss | Damage a boss, pause/exit, Continue. | Same boss with remaining health; safe resumed pattern. |
| Background | Switch apps while moving/firing, then return. | Paused; released controls do not remain held. |
| Lock | Lock/unlock while in a run. | No unexpected combat advance or stuck input. |
| OS termination | Pause/background so a checkpoint completes, then close/reopen the app. | Continue recovers the latest completed checkpoint and profile. |
| Abrupt kill | Close without a fresh checkpoint. | Recovery may be up to the last completed periodic save; this is not continuous per-frame saving. |
| Training detour | Save a normal run, practice in Training, return. | Original normal Continue remains available. |
| Replace run | With Continue available, choose Play and cancel replacement; then deliberately confirm once. | Cancel keeps old run; confirmed replacement starts a fresh one. |
| Update | Install a later build over this one without deleting the app. | Compatible profile/settings/checkpoint survive. |

Saves are local to this installation. There are no accounts, cloud backup, cross-device transfer or online rankings. Deleting the app may delete local progress. Avoid uninstalling when the purpose is to test an update path.

If storage fails, the game surfaces a save issue rather than claiming it saved. Report the exact message. Backup recovery and serialized writes are implemented and tested, but real full-disk/OS interruption behavior still needs device evidence.

## 11. Performance: what was improved and what remains unproven

Implemented work includes bounded enemies/drops/projectiles/effects, pending-spawn accounting, expiring hazards/mines, capped particles/chains, preloaded sprites, fewer per-entity UI/provider updates, one firing timer instead of accumulating timer components, shared collision geometry and audio-source caching. Fast projectiles use swept hits with wall checks; dash movement is substepped around obstacles.

The latest recorded accelerated simulations passed 30 and 60 minutes of developed-build combat. Enemies stayed at or below 120 and XP drops at or below 80. The 60-minute scenario defeated thirteen bosses and retained 142 world children at the final sample, below its peak of 300. Health was deliberately replenished by that test so it could keep running.

**These numbers prove neither 60 FPS nor human survivability.** They do not measure phone frame times, native audio reliability, memory bytes, thermal throttling or battery use. Automated test success is evidence for the scenarios covered, not proof that the entire game is bug-free.

### On your iPhone

- [ ] Play for at least thirty minutes across dense normal gameplay, a boss and two fusions.
- [ ] Note whether aiming and movement remain responsive as the horde grows.
- [ ] Record when hitches occur: first enemy type, first sound, XP collection, fusion effect, boss arrival, death/results or Continue.
- [ ] Note heat, battery drain, audio stutter and whether later runs feel worse than the first.
- [ ] Repeat on Android when a representative phone is available.

For a measured verdict, capture frame-time and memory traces with Instruments/Android profiling tools, recording device/OS, duration, loadout, thermal state, and peak/typical frame times. A screen recording alone is useful bug evidence but not a substitute for those traces.

## 12. What is done, what is short, and what to improve next

| Area | Current state | Remaining work / improvement |
|---|---|---|
| Core loop and full roster | Implemented and covered by automated scenarios. | Human balance, pacing, build viability and boredom checks. |
| Bosses | All eight have live encounters, phase changes, rewards and practice access; Training includes randomized Boss Rush with occasional pairs. | Phone-based fairness, escape windows near columns/edges, warning readability and richer bespoke animation/audio. |
| Controls | Adjustable, mirrored, floating/fixed, independent arrangement. | Your physical thumb comfort is still decisive; test small and large phones. |
| Art | New generated survivor, enemy, boss, gun, item and arena art is integrated throughout gameplay and previews. | Review motion/hand consistency, dense-scene contrast and repeating floor materials on hardware. See `art/ART_OVERHAUL_PROGRESS.md`. |
| Character identity | Functional stat/passive/accessory differences. | Rook is a baseline rather than a deep unique mechanic; stronger silhouettes/animation could make all three more memorable. |
| Audio | Four generated music contexts and additional weapon/reload/UI cues. | Longer/less repetitive arrangements, smoother transitions, richer timbres and hardware mix review. |
| Collection/cosmetics | Catalogue, discoveries, twenty challenge records, shop/equip/previews. | Some mastery/archive rewards are record markers rather than new equip slots; presentation and reward excitement can improve. |
| Save/Continue | Local checkpoints, backup recovery, profile settlement protection. | Physical lock/call/termination/update cases; no cross-device recovery. |
| UI | Custom pixel buttons/controls; starting-screen alignment and Settings pinned Back repaired. | Further issues you find should be handled screen by screen; no blanket redesign is assumed. |
| Accessibility | Enlarged-text layout checks, reduced motion, aim assist, input calibration. | Physical readability/color/contrast review; gameplay is not proven usable by blind players and full gamepad/assistive play is not implemented. |
| Long sessions | Bounded accelerated simulations pass. | Real frame-time, memory, heat and battery measurements; balance beyond early cycles. |
| Asset rights | Original generated/code artwork is identified; inherited files are inventoried. | Confirm licenses/attribution for inherited sprites, tiles, fonts, sounds and splash/icon before public distribution. |
| Release packaging | iOS development-device release build; Android release APK build. | Android upload keystore, store distribution/export configuration, listing/support/privacy/rating materials and final approved screenshots. Android test APK is debug-signed. |

### Recommended order after your testing

1. **Fix blockers:** trapped navigation, crashes, stuck controls, missing/duplicate progress, attacks that ignore their warnings.
2. **Tune the play:** thumb reach, reload vulnerability, early pacing, XP economy, boss damage/recovery, build combinations and endless scaling.
3. **Measure and optimize:** reproduce dense-session hitches, obtain native traces, optimize the actual bottleneck, repeat the same scenario.
4. **Raise presentation quality:** coherent sprites/animation, boss identity, arena detail and the music/SFX mix. Preserve legibility over spectacle.
5. **Prepare distribution:** clear inherited asset rights, configure signing/accounts, and prepare the exact tested store candidate.

Additional modes, weapons, online systems or permanent combat-stat grinding are optional future scope. They are not needed to judge whether this existing survival loop is fun and dependable.

## 13. How to send useful feedback

A short report is enough:

```text
Area: Settings / controls / weapon / boss / fusion / save / performance
Mode: Training or normal
Loadout: survivor + weapon + arena
Time/cycle: approximately when it happened
Steps: what I did immediately before the problem
Expected: what I thought should happen
Actual: what happened instead
Repeatable: every time / sometimes / once
Evidence: screenshot or short recording, if helpful
Severity: blocks play / loses progress / feels unfair / visual polish
```

For balance feedback, “Revolver on Rook could not punish Demon's recovery without taking a hit” is more actionable than “Demon is too hard.” For UI, screenshots like your starting-screen alignment example are useful; identify the element that feels wrong.

## 14. Developer evidence and related documents

- `REGUN_PROGRESS.md`: implementation history, native build status and measured evidence.
- `validation/`: saved analyzer/test/build/soak outputs and candidate hashes. These describe the dated candidates in the log, not an assertion that every future edit has the same binary hash.
- `ASSET_REVIEW.md` and `ASSET_MANIFEST.csv`: asset provenance review, per-file hashes and remaining creator/distribution decisions.
- `REGUN_COMPLETE_GAME_PLAN.md`: full product plan and release gates. Unchecked physical/asset/distribution gates are intentionally still unchecked.

The Settings update adds a small-screen/enlarged-text regression check that verifies Back stays fixed while scrolling and returns to the preceding route. Physical return from your actual pause/menu flow remains part of Session A.


## Art replacement candidate — 19 October 2026

The old soldier and purple grid floor are retired from gameplay and packaged assets. All three survivors, eight normal roles, three bosses, four weapons and both arenas now use the replacement art pipeline. See [the art review](art/ART_OVERHAUL_PROGRESS.md) for exact delivered states, map footprint changes, performance budget, test evidence and a focused phone test session. Existing shotgun timing, upgrade slow motion, controls and progression remain. Physical performance/thermal validation and visual approval remain open.


## Current animation candidate

See [the animation repair report](art/ANIMATION_REPAIR_2026-10-19.md). The rejected segmented-leg preview was never installed. The currently installed release uses complete-body run frames, phase-preserving facing changes and revised locomotion cadence. Compare moving footage and real gameplay before accepting anatomy/gait quality; tests validate timing and game regressions, not artistic perfection.
