# Regun playable build

For the full feature-by-feature breakdown, test procedures, known limitations and improvement priorities, use [REGUN_TESTING_AND_REVIEW.md](REGUN_TESTING_AND_REVIEW.md).

This is the full functional-content test build. Art approval, difficulty/comfort tuning, physical performance and platform interruptions are still acceptance gates. Training exposes everything without changing your normal unlocks.

## Quick tour

On your first **Play**, a **Training mode** briefing appears over the paused arena. Choose **Start training** to learn the controls or **Skip training** to go straight to your normal loadout. Skipping is remembered; Training remains available from the menu.

1. Choose **Training** from the menu. Select any of the three survivors, four weapons and two arenas.
2. Follow the five short prompts: move, shoot, dash, reload, choose an upgrade. **Skip / Ready** completes the introduction and unlocks Carbine for normal runs.
3. Pause training to summon any of the **eight bosses**. Each has a second phase. Training protects your health.
4. The same pause menu offers each of the **six fusion recipes**. It prepares the prerequisite ranks and opens the actual core choice. Select the fusion, resume, then shoot/dash among targets to try it.
5. Choose **Play** for a normal run. Only earned loadouts are available. Kills produce XP; ranks build toward boss-core fusions. Boss milestones lead into repeating ten-minute cycles. Results award scrap, challenges and horizontal unlocks once.
6. Open **Collection** to inspect all upgrades, recipes, enemies, challenges and cosmetic rewards. Scrap buys cosmetic palettes; equipped styles appear in play.

## Controls

Movement is left; aim/fire is right. Dash and reload stay with the aiming thumb. Pause → Controls allows size, reach, height, opacity, sensitivity, dead zone and fixed/floating sticks. **Arrange** lets you move each control independently. Right/Left mirrors the entire arrangement. Reset restores the default.

## Save and Continue

A normal run checkpoints during play, on pause/background and on exit. Return through **Continue**. It opens paused with the saved build, ammo/reload progress, enemy/boss health and XP. Transient hostile attacks are discarded and resume has brief protection. Training does not overwrite the normal checkpoint. Starting a replacement normal run asks before discarding the existing one.

## Physical validation — record actual observations

Use release builds on the iPhone and a representative Android phone. Simulation results cannot satisfy this checklist.

- Fresh install, tutorial, first death, retry, first unlock; update over an existing install preserves profile and records.
- Move + aim + dash together; repeat along all edges/corners, around columns, while reloading, and with mirrored/floating/custom controls.
- Each weapon × survivor combination; all bosses including phase changes, death and repeated cycles. Check warnings are visible and avoidable.
- Both arenas for at least 30 minutes: dense developed build, two fusions, elite/boss overlap. Capture frame time and memory with Instruments/Android profiler. Record device/OS, build, thermal state, duration, frame-time percentiles, memory trend and hitches.
- Pause during reload and an upgrade choice; background, screen lock, audio interruption, force-close and Continue. No stuck stick, lost reward, duplicate result or unexpectedly resumed firing.
- Music/SFX mute, volume changes, Bluetooth route, reduced motion, aim assist and enlarged system text.
- Check thumb reach/accidental taps and boss fairness by hand. Report reproducible actions, arena/loadout/time and a recording when possible.

## Repeatable developer checks

**Training → Pause → Take damage → On** enables real damage with automatic recovery. It defaults Off on a new training visit and stays selected across Restart and Boss Rush rounds. Death preserves the build and encounter: a short fallen pose fades, the camera eases back to arena center, then the survivor descends into dust, braces and returns to control. The world waits during this roughly 2.7-second sequence. Health/ammo refill and two seconds of protection allow an escape from center. Turning damage Off restores practice health. Normal runs still end at death.

Fresh starts and restarts use the same landing entrance, without the death/camera return (about 1.2 seconds). Continue preserves the saved position and opens paused without deploying again. Pause/background freezes the entrance; Reduced Motion replaces travel with a short concealed relocation/fade. Try dying off-center during reload, amid hazards, in a boss pair, pausing halfway, toggling damage Off, restarting, and leaving mid-return. Boss health/build must survive a recovery; no normal rewards or game-over overlay should appear in training. Check the landing audio and motion pacing on the phone.

Boss bodies now share subdued arena lighting (cool crypt/warm foundry) and layered contact shadows. Non-emissive stone, glass and iron attack sprites have a restrained ambient grade; furnace heat retains its emission. Compare all eight bosses and attacks on both floors, especially dark silhouettes, mirror glass and chain warnings. This treatment needs physical visual approval, not only screenshot review.

`make verify` runs analyzer and regular tests. `make soak` runs the explicit 30/60-minute simulation. `make buildAPK` creates a local Android candidate; `make buildIOS` creates the signed iOS device build when the development team is configured. `make runRelease DEVICE=<id>` installs/runs a connected phone. APKs use local debug signing until a private upload keystore is configured.

## Enemy personality pass — what to try

Use a normal run or training with several enemies alive. Run straight for a few seconds, turn sharply, then stop briefly. Repeat near columns and arena edges.

- **Scorpions:** split into left/right arcs at a distance, then close in. They should pressure your sides rather than form one narrow train.
- **Mummies:** aim a short distance ahead of your current movement. Change direction to wrong-foot them; their existing close strike remains.
- **Revenants:** retreat if rushed, strafe at firing range, approach if too far away. They plant for a 0.4-second cast before a shot. Watch for fair gaps between shots.
- **Skitters:** flank during approach, then warn and lunge along a committed line. Sidestep after the warning; a lunge must not turn after you.
- **Shield Wardens:** advance directly, absorb front shots, and keep their existing strike/recovery window.
- **Bursters:** intercept your route, then stop for the marked detonation. Turn or dash away from the marked area.
- **Nests / Sentinels:** stay as area-control threats; remove nests to stop reinforcements and leave sentinel ground marks.

Check squeezing through packs, crowded corners, and movement around obstacles. Report any vibrating, stuck or excessively evasive group. The current movement and population revision below changes difficulty and needs physical balance testing. No physical FPS claim is made by the automated dense-scene test.

**Current crowd revision:** living enemy bodies now reserve space and cannot move through each other. Normal pursuit can slide around a blocked body; committed lunges stop rather than bend through a neighbour. Reinforcement warnings reserve their arrival space. Ordinary enemies yield out of a boss's approach. The director counts both arena and visible populations, including pending arrivals: the arena target rises from 20 toward 60, and visible crowd thresholds from 18 toward 44 pause new arrivals. The 120-enemy limit is only an emergency ceiling. The visible threshold controls reinforcements, not an invisible barrier for existing enemies. Try tight turns, columns, near walls, nest reinforcements and bosses among mobs; report overlap, shuffling, blocked bosses or a loss of challenge. Difficulty/readability and motion comfort still need phone review.

## Menu layout check

Open all six Collection sections. Tabs should remain completely visible, cards in a row should share their bottom edges, and a thin scrollbar should indicate more content. Scroll to the final row: the full card must clear the soft bottom edge. Switch sections while scrolled down; the next section should start at the top. Back stays visible throughout. Repeat in Loadout and Settings, including enlarged system text. On narrow layouts, fewer columns and a stacked Start footer are intentional.

## Revised boss practice

Training → Pause separates **Boss Practice** and **Fusion Practice**. Boss buttons replace the current practice boss, allowing direct comparisons. Fusion buttons prepare ingredients; tap the named card on the **FUSE** screen to activate it.

For each boss, try retreating straight, then dodging sideways after a warning, then attacking during recovery. Repeat below half health. Demon should close distance with its marked charge and threaten nearby targets with cleaves/slams. Queen should obstruct the projected route with staggered strikes/poison while retaining brood summons. Shadow should close long gaps and send staggered, faster fans. Check that turning after a warning does not make the boss silently reverse the marked attack. Test near walls/columns, during reload, after Continue, and kill a boss during an active attack to check cleanup.

Report attacks whose visible marks disagree with damage, apparently unavoidable chains, excessive chase downtime, distorted poses, or slipping foot movement. Demon source walk poses remain limited; this candidate fixes playback/anchor issues without a new art generation pass. Training protects health by default; enable Take damage to rehearse hits and recovery, and use a normal run to judge final difficulty.

## Weapon feel review

**XP and unwanted extra-choice correction — 1.0.0+12:** next-level costs now start **25, 50, 80, 115, 155, 200** and continue with rising increments. Ordinary enemy/boss XP rewards stay unchanged. Ordinary upgrades require funded XP; boss kills no longer open free ordinary upgrade cards. Cores bank until a recipe is available and you tap **Fuse core** in the HUD/pause menu. After choosing, gameplay resumes: overflow is retained, another pickup may fund the next level after four active seconds, and pause/waiting cannot generate a new choice alone. Old saves migrate their XP-bar progress once. See [XP_PROGRESSION.md](XP_PROGRESSION.md) for research, exact costs and test cases. Record first/second upgrade times and level at each boss; the prepared-build soaks do not validate normal progression pacing.

**Upgrade revision — 1.0.0+12:** all thirty upgrade families now reach rank VIII; cards and Collection show the new ceiling. Existing I–III gains remain, while IV–VIII add smaller but useful gains. Scalar upgrades receive 30% of an early rank per later pick; reload/dash cooldown retain a tighter 20% tail. Scattershot keeps its rank-III round count and tightens the spread with each later rank. Fusion prerequisites stay III/II; six special slots and bans remain.

Extended Tube now says **“Larger mag. Refill now. Same reload time.”** Selecting it immediately fills the enlarged magazine and cancels any active reload. A 320ms mechanical snap and **MAG READY** cue make that refill visible; shooting is already allowed and cancels the cosmetic cue. The larger shotgun tube no longer adds reload time: seven or sixteen missing rounds cap at the original 3.7 seconds before Sleight of Hand. Ordinary five-shell/partial reload timing is unchanged. Sleight reaches 1 second at III and 850ms at VIII; other weapons retain at least about 41% of their normal reload duration. This is a pickup refill, not permanent zero-time reloads.

Other VIII bounds: Scrap Armour recharges in 6.5 active seconds, Field Medic heals on 22.5% of kills, Quickstep cooldown is .6 seconds, Quick Trigger fires at roughly 48% of the original interval, and bounce damage cannot exceed twice its initial amount. Each later pick should help without bypassing the normal projectile/effect/population caps. Test sustained rank-VIII builds, both arenas, saved runs, all four weapon reloads, pause/background during the pickup cue, collecting the upgrade while empty/reloading, firing immediately after selection, and rank-VIII exclusion from offers. Simulations do not establish physical difficulty or final balance.

**Build 1.0.0+11:** all four weapons have heavier projectile/muzzle/impact presentation, without damage, cadence, range, speed, reload or collision-size changes. Shotgun pellets now draw at 15×8 world units, Carbine rounds 13×5 and Revolver rounds 15×6, with brass edges, shaded undersides and small hot cores. Arc Caster has thicker irregular pixel arcs, short forks and a grounded impact scuff rather than a clean arrow/line effect. Compare each against the same targets; look for readable rounds without losing enemy warnings.

Accepted primary bullet hits give moving normal enemies a brief decaying shove and reduced stride. One response per target per .24 seconds prevents pellet stacking or rapid-fire pinning. Shotgun/Carbine/Revolver/Arc responses last .09/.06/.1/.075 seconds and request 13/5/16/8 units before resistance, walls or body occupancy. Mummies, elites and Wardens resist; nests, sentinels and bosses stay planted. Secondary chains/burn/drone hits do not add pushback. Try close blasts, sustained fire, upgrades, columns and dense crowds; enemies should visibly absorb the hit, then resume pressure. Reduced Motion suppresses extra shotgun debris. Physical feel and comfort need phone approval.

Try all four weapons against the same Training targets. Look/listen for a broad shotgun blast and shell/pump reload, tight carbine fire and magazine motion, heavy revolver flash/recoil and cylinder reload, and an electrical Arc Caster discharge/recharge. Shotgun reload now uses the common mechanical style; the old Lottie is retained only as source. Compare short target flashes with player health-loss edge cues, shield absorption sounds, and heavier boss impacts. Repeat with Reduced Motion and Sound muted. Keep enemy warnings visible during dense fire and report muddy/repetitive/harsh sound or effects obscuring threats. The new local synthesized sounds still need your listening approval.

## Eight-boss candidate — Boss Rush

**Training → Pause → Random Boss Rush → Start rush.** A shuffled roster draws from all eight bosses; 40% of rounds request a distinct pair. Defeat every living boss to advance after a short break. Health and ammo refill between rounds; the build stays. Training protects health by default and gives no normal profile rewards. Use Fusion Practice to prepare a build. **Next round** skips the current encounter; **Restart** starts a fresh rush. Individual Boss Practice buttons exit the rush.

New encounters: **Bellkeeper** (gapped waves and delayed echoes), **Chain Magistrate** (sequential chains and sweeps), **Mirror Saint** (recorded movement and reflected paths), **Kiln Sovereign** (pressure zones, foot strikes and furnace sweep), **Last Marshal** (aimed shots, front brace and a returning blade). Shoot the exposed bell/clasp/glass/valve/blade to interrupt the relevant attack and earn a longer opening. Every boss enrages below half health.

Watch windup → impact → reset, especially while changing direction or interrupting. Impacts must return to living poses rather than holding a final frame. Test both phases, death during an active pattern, repeated summons, all weapons, walls/columns and reduced motion. In a pair, both health bars must persist independently; killing one must leave its partner fighting. Major attack ownership waits for owned floor attacks and Shadow bolts to finish before the partner commits. Report overlapping warnings, blocked escape routes, clipped limbs, sliding feet, harsh sound or an attack that feels unfair. Training's protected health cannot establish normal-run difficulty.

Normal play uses a saved shuffled eight-boss rotation from the very first encounter. Normal encounters remain single bosses. This is eight total bosses, with fifteen still the longer-term target; multiplayer is not implemented.


## Combat-material and boss-pressure review — build 1.0.0+9

Attack presentation now uses textured stone faults, glass eruptions, linked iron and barbed anchors, furnace debris and acidic ground. This covers all eight bosses and ordinary enemy warnings, ground hazards, explosions, burning ground, spawn marks and supporting hit/guard/projectile effects. There are no generic circle outlines marking attacks. The warning should be a recognizable planted footprint; the damaging release adds a physical eruption, weapon or moving wave. The damage footprint, ring gap and committed direction remain authoritative. Check that the floor treatment stays legible on both arenas, in pairs and with Reduced Motion.

Mirror Saint: continuing along the same route is now intercepted by **Shatterwake**, followed by staggered crossfire and a false-body combo. Change direction after the warning; break a mirror to interrupt. Chain Magistrate: **Writ of Iron** reaches through the predicted route, followed by a second anchor chain; **Reaping Chain** swings a visible weighted head. Its warning must stay locked after you turn. Both kits have shorter openings between combos; Saint has 300 base health. Normal-run and Boss Rush identities stay randomized.

Arc Caster: six charges (was four), three damage (was two), .75s firing interval (was .9s), two innate jumps (was one), 85% retained damage per jump (was 65%), 240-unit jump reach (was 170), 560 projectile range and 1050 speed. Recharge stays 2.4s. Compare a lone boss with a spread-out pack: the weapon's reward is reliable multi-target damage, while Revolver retains higher base sustained direct damage. Chains stop at walls and do not recursively trigger chains. Reload, take Magazine upgrades, try all survivors and Continue an old Arc run; the new base should apply once while preserving earned ranks. New shot/impact audio needs your listening approval.

Check threat and readable escapes by hand; scripted retreat/sidestep and population tests cannot establish final feel, fairness or native rendering performance.

The arena stays fully open. All eight bosses now have larger bodies with matching collision/occupancy radii and more reach, area coverage or faster releases. Bellkeeper waves travel at 1200/1450 units per second with a narrower escape gap; its clapper covers a 540-unit, 212° sector with a close inside pocket. Shadow's faster fans reach across the arena; Demon charges farther and cleaves more broadly; Queen strikes and poison deny more ground. Magistrate chains reach beyond the predicted route, Saint's glass lanes/eruptions widen, Sovereign's eruptions and breath cover more floor, and Marshal's shots and returning blade threaten farther routes. Large sweeps have inside pockets and locked warnings; range does not mean tracking after commitment. Existing population/hazard limits remain.

Try standing far away, sustained straight retreat, a late sideways turn after the warning, moving inside a sweep, and dashing through a gap. Repeat every boss in both phases, around columns and at boundaries, and with two bosses in Rush. The long-distance automated check uses normal health and requires all eight to threaten a retreat from 1000 units within 7.5 seconds; it does not measure how difficult the fight feels. Report attacks landing outside their visible footprint, invisible off-screen releases, an unusable inside pocket, or a large body hiding its warning.

**Current release identity — 1.0.0+7:** retains the full upgrade/boss/VFX implementation. The Carbine should produce separate, tightly grouped rounds with slightly differing muzzle origins/headings, with no curved flight. The shotgun retains **three** pellets with one in the middle; Scattershot I–III gives five/seven/nine. Pellets draw larger (22×11); shotgun hits push susceptible enemies up to 34 world units before mass resistance over .12s, without stacking per pellet or crossing bodies/walls. Opening XP requirements are 8/18/35/59/90, then increasingly steep; measure first/second upgrade times and progression at bosses. Existing saves retain their bar fraction once on migration. Listen to all four weapons on phone/headphones: real firearm attacks, short bass/low-mid pressure, heavier impacts and less ringing in boss hits. Check rapid Carbine fire and paired Boss Rush for muddy buildup or fatigue. Automated audio/file and mix checks are not listening acceptance.

### Damage readability — release 7, 20 October

- In Training, enable Take damage. Let an enemy hit you: expect one light haptic, a brief pale hit on the survivor followed by a warm tint, a half-second stepped edge cue and the actual health loss (`−1` followed by the heart sprite, or `−2` plus the heart for a two-point attack) beside the heart. Aim/camera must stay steady.
- Repeated contact during the damage guard, protected deployment and an absorbed Scrap Armour hit must not produce a health-loss cue/vibration. Armour still has its own impact sound.
- Turn Haptics off: keep the visible cues without vibration. With Reduced Motion on, omit the pale flash and use quieter edge shading; the warm player tint/health readout remain. Pause holds the cue; Restart clears it. Training death still follows the existing recovery sequence.
- Check the cue during busy boss attacks and on the smallest/large-text HUD. Native vibration strength and readability need hands-on approval; automated channel assertions cannot establish physical feel.

### Reload sound and sharper weapon motion — release 7

- Reload Shotgun and Carbine repeatedly. Expect subdued shell handling/a physical pump, and three distinct magazine-out/seat/bolt contacts rather than bright ticking. Check Revolver and Arc too. Music/SFX sliders and mute must still work.
- Fire each weapon: recoil should recover about 17–18% sooner, with a readable short muzzle flash. Reload parts should move quickly into a hold and seat decisively; ammo must become available at the same time as before. Preserve shotgun shell count/timing and the original HUD Lottie.
- With Reduced Motion enabled, moving magazine/cylinder/cell/tilt cues stay planted; reload progress remains visible. Try pause, partial reload, Extended Tube and an eight-rank reload build. Judge sound fatigue and animation readability on the phone; automated checks do not replace listening.

### Longer leaps, forward chain volleys and explosion blending — release 7

- Let a Skitter approach from about 500 units away. The .55s lane should precede a long leap: sometimes toward your current position, sometimes ahead of your movement. Change direction after the warning; it must never track you midair. Test close range, an elite/later cycle, columns and other enemies. Bodies/walls still stop it; Reduced Motion removes the sprite lift.
- In Magistrate practice, expect **five chains toward your area**, or **seven below half boss health**. A single boss-centered fan has no branching endpoints or rear-facing star spokes. Read a gap and settle in it; blindly running across the fan can cross another chain. A center lane still punishes straight retreat. Check simultaneous/staggered patterns, breakable clasps, pause/death/restart and a paired Rush. Busy floor hazards may delay the whole volley; they must not reduce it to two chains.
- Compare mine/Burster explosions on Breach and Foundry. The same sprite should be graded to the arena, have a planted foot/scorch and fade through debris while actors stay visible above it. Confirm blast damage/footprint still match, and test Reduced Motion and overlapping bursts. Native readability, difficulty, animation and performance require hands-on review.
- Review the combined arsenal/power-up/loadout proposal in `docs/REGUN_ARSENAL_AND_LOADOUT_PLAN.md`. These planned systems, including Rupture, are not yet selectable in the game.

### Skitter warning and Marshal beam follow-up

Skitter's warning should look like matte claw scrapes/dust in the floor, not the Marshal's gun lane. Check it on both floor textures and while moving. The Marshal now fires a continuous orange/white laser from his gun for a short held burst, including his brace counter; no tiled stone eruption sprites should appear in those shots. The muzzle must connect to the beam, aim must lock before firing, the gun must stay raised through release, and the beam must not hit outside its visible width or through columns. Each beam damages once, pause freezes it, and Reduced Motion removes its traveling filaments. His blade kit is still a separate attack.

### Tactical reload and staged fire — release 7

- Spend some ammo, then manually reload each weapon. Carbine should swap the magazine faster and skip the last bolt click; empty reloads retain it. Other weapons get a smaller tactical speed advantage. Normal full shotgun timing stays intact when aim is released.
- Hold aim through an empty Shotgun, Revolver or Arc reload: a new shell/round/charge must load, the weapon should close/ready briefly, then fire. Expect another reload after spending that one round. Release aim to fill the whole weapon. Try manual partial reloads too: retained ammo cannot instantly bypass loading. Check world/HUD animation, actual ammo count and Reduced Motion.
- Pause or background during insertion and during the closing action, then Continue. Neither ammo nor closing time should advance offline. Try Extended Tube during loading/closing, Restart and training recovery. Check eight-rank Fast Reload and extended magazines for free rounds or an excessive fire-rate gain. Last Shell/Breach Loader must not refresh on every one-round interruption.
- Fight Revenants beside XP drops on both arenas. Their shots should be elongated, directional rose/iron darts with a short wake; coins remain round brass pickups. Dodge across and along their paths. Judge the lower, quieter launch sound through phone speakers/headphones with several shooters; it should remain audible without the old whistle/chime. The Shadow boss shares that cast cue. Check music/SFX sliders and mute.

### Action soundtrack — menu and combat

Listen from the menu through both arenas and Boss Rush. The menu should already suggest action; arena rhythm should push harder and the boss score should escalate it. Hear each loop for several minutes on speakers/headphones: no click, silent gap or full fadeout at repetition; no fatigue from the high end. Confirm gunfire, Revenant launches and boss warnings remain readable over music. Change music/SFX sliders separately, mute, pause/background/resume, restart, and return to menu. Solo and gameplay-mix reels are in `build/audio-review/`; native comfort and music taste still need human review.
