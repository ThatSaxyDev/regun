# Regun playable build

For the full feature-by-feature breakdown, test procedures, known limitations and improvement priorities, use [REGUN_TESTING_AND_REVIEW.md](REGUN_TESTING_AND_REVIEW.md).

This is the full functional-content test build. Art approval, difficulty/comfort tuning, physical performance and platform interruptions are still acceptance gates. Training exposes everything without changing your normal unlocks.

## Quick tour

On your first **Play**, a **Training mode** briefing appears over the paused arena. Choose **Start training** to learn the controls or **Skip training** to go straight to your normal loadout. Skipping is remembered; Training remains available from the menu.

1. Choose **Training** from the menu. Select any of the three survivors, four weapons and two arenas.
2. Follow the five short prompts: move, shoot, dash, reload, choose an upgrade. **Skip / Ready** completes the introduction and unlocks Carbine for normal runs.
3. Pause training to summon **Shadow, Demon or Scorpion Queen**. Each has a second phase. Training protects your health.
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
