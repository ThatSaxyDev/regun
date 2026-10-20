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

Report attacks whose visible marks disagree with damage, apparently unavoidable chains, excessive chase downtime, distorted poses, or slipping foot movement. Demon source walk poses remain limited; this candidate fixes playback/anchor issues without a new art generation pass. Training protects health; use a normal run to judge actual threat and damage.

## Weapon feel review

Try all four weapons against the same Training targets. Look/listen for a broad shotgun blast and shell/pump reload, tight carbine fire and magazine motion, heavy revolver flash/recoil and cylinder reload, and an electrical Arc Caster discharge/recharge. Shotgun reload now uses the common mechanical style; the old Lottie is retained only as source. Compare short target flashes with player health-loss edge cues, shield absorption sounds, and heavier boss impacts. Repeat with Reduced Motion and Sound muted. Keep enemy warnings visible during dense fire and report muddy/repetitive/harsh sound or effects obscuring threats. The new local synthesized sounds still need your listening approval.

## Eight-boss candidate — Boss Rush

**Training → Pause → Random Boss Rush → Start rush.** A shuffled roster draws from all eight bosses; 40% of rounds request a distinct pair. Defeat every living boss to advance after a short break. Health and ammo refill between rounds; the build stays. Training protects health and gives no normal profile rewards. Use Fusion Practice to prepare a build. **Next round** skips the current encounter; **Restart** starts a fresh rush. Individual Boss Practice buttons exit the rush.

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
