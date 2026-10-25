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

### Full reload commitment and Carbine tactical reload — release 7

- Shotgun, Revolver and Arc Caster must finish their entire reload before firing, including while aim is held. Check both empty and partial manual reloads; no individual round should become usable mid-reload. These weapons no longer receive the experimental 15% tactical speed bonus. Existing Fast Reload upgrades and original shotgun full timing remain.
- Carbine still swaps its magazine faster when manually reloaded with rounds remaining (base 1.26s instead of 1.8s), with no final bolt cue. Empty reloads retain the full action. Pause/Continue should retain the tactical timing and cue state.
- Continue a save from the interrupted-reload experiment, including one saved during the short closing action. It must require the remaining full reload, rather than resume one-shot reload firing. Pause/background must freeze it. Check Extended Tube, training recovery, Restart and eight-rank Fast Reload/extended magazines. Last Shell and Breach Loader return to their normal final-/first-shot behavior.
- Fight Revenants beside XP drops on both arenas. Their shots remain elongated, directional rose/iron darts with a short wake; coins remain round brass pickups. Judge the lower launch sound with several shooters. The Shadow boss shares that cue. Check music/SFX sliders and mute.

### Action soundtrack — menu and combat

Listen from the menu through both arenas and Boss Rush. The menu should already suggest action; arena rhythm should push harder and the boss score should escalate it. Hear each loop for several minutes on speakers/headphones: no click, silent gap or full fadeout at repetition; no fatigue from the high end. Confirm gunfire, Revenant launches and boss warnings remain readable over music. Change music/SFX sliders separately, mute, pause/background/resume, restart, and return to menu. Solo and gameplay-mix reels are in `build/audio-review/`; native comfort and music taste still need human review.

### Close-range damage reward

Compare each weapon against the same enemy type up close, at mid distance and near maximum range on both arenas. Shotgun has the largest close reward (+20%); Carbine/Revolver/Arc have smaller bonuses (+10/+12/+8%). Far damage retains 90/95/98/98% respectively. Expect a smooth change, with ranged weapons still useful. Check large bosses, upgraded magazines, Scattershot, piercing, Bank Shot, Arc chains and range VIII; approaching carries contact risk and must not erase the boss fight. Moving away after firing or bouncing back toward the player must not refresh close damage. Native kill breakpoints, long-run builds and challenge balance need human review.

### Whole-cluster size and slightly stronger dash

- Pause → Controls → **Control size**. Move the slider from minimum to maximum: both sticks, center knobs, Dash and Reload should scale together. Default size keeps the original 56px action targets; extremes give roughly 51–65px targets. Touch the outer edge of each enlarged button and confirm it responds. Check both aim hands, fixed/floating sticks, screen safe areas, custom placements, restart and relaunch. Larger controls must not overlap or leave the screen; invalid custom overlap uses a safe fallback.
- Dash should travel about 12% faster/farther, with the same duration, cooldown and invincibility window. Test movement-aim-dash multi-touch, walls/columns, moving along arena edges, pausing during a dash and upgraded Quickstep/Afterimage. Judge the small increase in escape reach on the phone; automated checks do not establish physical comfort or difficulty.

### Breach airdrops

- The four old pillars/colliders and decorative grates should be gone; Foundry's layout stays the same. In a Breach run, expect the first drop after about 22–32 active seconds, then more at irregular intervals with one live pod at a time. Retreat offscreen and use its edge tag to find it again.
- Use **Training → Pause → Supply Practice → Call airdrop** for immediate review. Check the fixed landing warning, accelerating descent, heavy impact sound and low dusty kick. Reduced Motion should fade the pod in place. No clean glowing hostile-attack ring should replace the brass objective stencil.
- Lure each enemy role under the small pod footprint: ordinary enemies die; a boss loses only a small amount of health. An enemy merely inside the larger circle should survive the landing. Watch normal death/XP effects and repeated/paired boss cases. Landing happens once, including after Continue.
- The enlarged field should give room to dodge. Inside lights it up; eight seconds fills the meter with quiet rising charge sounds. Leaving pauses progress while the 45s deadline continues. Complete it, choose one AIRDROP upgrade and confirm XP, level and next XP cost do not change. Reject duplicate cards or immediate repeated rewards.
- Claim one, ignore one and leave one partially charged. Claimed pods stay open briefly after the picker; all must break down and disappear without persistent debris/hidden collision. Pause/background, recovery, upgrade selection and Continue freeze/resume the correct clocks. Try restarting/leaving during arrival/loading, and start Boss Rush: no drop or resource leak should survive.
- Listen on speakers/headphones for a heavy landing without clipping or drowning out warnings; filling pulses must stop when outside and stay comfortable over repeated captures. Review standing-zone risk/reward on the phone. Rendered review sheets are `build/test-previews/supply-drops.png` and `supply-area.png`; native acceptance remains open.

### Home settings and controls before a match

- On Home, tap the top-right gear. It has no visible text; accessibility and long-press tooltip identify Settings. Re-Gun sits lower; Play is separated from Training.
- Settings → Controls must work without starting a run. Change control size, aim hand, stick mode and calibration; Arrange, drag a control and return with Done/system Back. Relaunch/start a match and check saved placement/size.
- Repeat through Pause → Controls and Pause → Settings → Controls. Changes through either path must immediately apply to the paused match. Check Reset, notched safe edges and larger text on smaller phones.

### Redesigned home terminal (21 October 2026)

- With a saved solo run, confirm Continue and Play share a row, Online stays below, and Training/Collection/Settings are all reachable in the lower rail. Continue resumes the save; Play still asks before replacing it.
- Check the title and lower rail on a compact landscape phone and both notch orientations. Larger text and portrait can scroll without obscuring the pinned version footer.
- Settings → Controls should still save layout preferences before a match. Returning to Home after enabling Reduced Motion must freeze the breach hardware and ash; disabling it restores slow ambient movement.
- Review the original iron breach illustration, contrast, motion comfort and thumb reach on hardware. Automated layout/simulator screenshots do not establish physical comfort or performance.

The final home art is now **Rook's shelter**, replacing the rejected iron breach. Check visible localized flicker in the hanging work lamp and responding bench warmth, small mug steam and dust; the menu and cool background must stay steady. Reduced Motion holds the whole scene still. Confirm the characterful pixel texture survives phone-size scaling.

### Loadout preparation and shotgun assistance (21 October 2026)

- In Loadout and Training, change survivor, weapon and arena in any order. Scroll an active catalog; its tabs, assembled kit, summary and Start must remain visible. Switch back to a previous catalog and confirm its equipped item is in view. Normal locks still apply; Training exposes all gear.
- Review the compact landscape, notched, portrait and large-text arrangements. Additions to a catalog should not turn the screen back into a scrolling stack of sections.
- Compare the shotgun's new 1.2 base damage per pellet and 3.2s five-shell reload in regular play. One-shell reload is .8s; three-shell reload is 2s. Confirm held fire waits for full reload, shell sounds/mechanism stay aligned, pause freezes the clock and Continue retains progress. Review standard enemies, elites, bosses, Scattershot and VIII builds; this remains a balance candidate.
- Deploy the matching sibling server through Dokploy before comparing co-op/Versus shotgun balance. Local smoke success is not evidence of the public deployment or WAN/physical performance.

**Ordnance revision — 21 October 2026 (1.0.0+7):** Tap the third grenade button on the aiming side. Throw two into a group; verify distinct explosions, then an 18s sequential recharge without resetting the first charge. Aim, move, Dash and Reload must retain their controls; mirror and resize the whole cluster. Empty/pressed states must remain readable. Try wall bounces, near contacts, short 1.4s fuse, pause, upgrade selection, save/continue and restart. Heavy Payload/Wide Burst/Ordnance Cycle should improve grenades without granting extra charges. In PvP one full-health survivor must survive a single grenade; friendlies/self are immune. Check mines against clustered targets and body-edge hits, with stronger recorded blast audio. Ranged remains must lie prone and keep their original facing as you run past. Airdrops now use radius 260 and expiry 50s, still requiring 8s capture; check that the extra room helps while urgency remains. See `ORDNANCE_AND_SUPPLY.md`.

**Skitter correction (21 October2026):** Compare small packs before/after: .75s clear claw/scuff warning, shorter180–520-unit jump,1.4s planted recovery and nearby attackers taking turns. Dodge sideways after commitment; both route and sprite facing must stay fixed. Try bright/dark floor areas, Reduced Motion, shielded corridors and later/elite cycles. Jump should remain threatening without relentless overlapping launches. Check multiplayer after the matching server deployment.

**Independent grenade aim:** Hold the grenade control without spending a charge. Drag backward while moving forward, verify the dotted arc/ground brackets, then release. Short drags should toss nearby; full drags keep the old maximum range. Weapon aim must remain untouched. Quick taps follow movement (stationary uses last aim). Drag back into the center for Cancel; pause/background or interrupted touches must discard the throw. Try mirrored/floating controls, reduced motion, multiple fingers, walls and enemies intercepting the arc. The landing marker predicts current contacts; enemies moving into the flight may detonate it sooner. Check online after the aim_grenade server deployment.

**Rest aim / upgrade recovery:** Run while aiming backward, release aim and verify the gun holds briefly then turns toward running after .65s; re-aim must respond immediately. Try reload, idle, pause, Reduced Motion and multiplayer. Confirm an XP/supply/fusion choice while crowded: one short cool pressure pulse should shove ordinary enemies, deal light damage and destroy hostile bullets already nearby. Bosses stay planted. Later bullets and hazards can still hurt immediately—there is no added invulnerability. Reroll, ban, stale taps and ordinary pause/resume must not emit another pulse. Check walls, crowd body spacing, checkpoint/continue and three-player co-op overlapping selections. Judge whether the created space is enough to find the controls without trivializing combat.

**Online preparation UI (21 October 2026):** The public Online gate remains off; exercise `OnlineView` in the private development/test flow. On a compact landscape phone, switch Create/Join; Join must hide host settings. Edit the name, paste a lowercase/spaced/dashed ten-character invitation, verify normalization and validation, and submit using the keyboard. Empty names, short codes and excluded characters must disable Join. Test outside-tap, scroll-drag and explicit Hide keyboard; reopen either plate without losing text. On iOS/Android, verify the active editor and exit remain reachable above the keyboard, including large text. The name should survive a completed create/join and relaunch.

Open co-op and all three Versus sizes on two or more devices. Watch actual arrivals populate empty slots and announce briefly; change remote loadouts, Ready states and teams. Co-op may start at two of three players; Versus needs full balanced teams. The host's pinned Start must explain its blocker. Reconnect must preserve reserved members and avoid replaying the full roster as new arrivals. Leaving/room removal should return to preparation with a clear status. Copy should confirm near the code. Delay/fail schema, art and session opening: an active attempt must never offer Retry, automatic reconnection must be visible, errors must preserve entered name/code, and a terminal failure must expose Retry. Check reduced motion and screen reader field labels/status announcements. Automated widget and transport-state tests do not approve device keyboard comfort or live multiplayer reliability.

**Online responsiveness/control follow-up:** On the simulator or phone candidate, compare the joystick ring/stepped knob and Dash/Reload glyphs directly with solo. Test88/96/112 control size, both handedness options, fixed/floating sticks and simultaneous move/aim/dash/grenade. Movement must stay held while reaching Dash with the aiming thumb. A saved guest rejected by the public server should show a specific explanation and Start new guest, without endless retries; that action can lose access to prior online records and must be deliberate. Confirm reconnect with a valid saved guest does not create another identity.

Predicted movement requires the matching server deployment (`queue_motion`, `stop_motion`, `my_motion`). Once available, start/stop/reverse near walls, teammates and arena edges, and dash while latency varies. Self movement should appear promptly; remote players remain interpolated. Stop and verify convergence without repeated rubber-banding. Test local menu, shared choice, death/spectating, round transitions, reconnect, background/focus loss and Reduced Motion: no old movement/dash may replay. Under a long outage the bounded predictor must stop rather than run indefinitely. Combat still uses authoritative positions, so these tests do not approve hit rewind or balance. The public-endpoint simulators currently use legacy movement until the backend rollout; local200ms native prediction evidence must not be presented as deployed public behavior.


Hosted online follow-up (21 October): explicitly authorized native private-room checks now cover touch prediction, server-confirmed combat controls and same-guest reconnect, plus co-op2/3 and Versus2v2/3v3. See `docs/validation` and `MULTIPLAYER_TEST_AND_DEPLOY.md` for successes and earlier queue stalls. Backend `afa88a8` compacts acknowledgements; client pacing follows observed simulation cadence. Before phone acceptance, use the matching fresh client, verify solo-style mirrored controls, try repeated reversals/dashes during RTT spikes, and exercise real foreground/network transitions. Current simulator results do not replace that review.


Latency pass after build9: compare other players' turns/stops and dashes at cover
edges; remote presentation now uses timestamped samples and short bounded
extrapolation instead of trailing toward the latest point. Try long delayed gaps:
remote actors must stop extrapolating after80ms, and local prediction remains bounded.
First trigger should show/hear one immediate cue if eligible; verify no doubled
shot sound when server confirmation arrives, no cues during empty/reload/cooldown,
and actual ammo/hits remain server-confirmed. Check rapid trigger release/manual
reload, lifecycle/round/choice/death/reconnect and Reduced Motion. Read the retained
3v3 failure as well as the passing rerun in ONLINE_LATENCY_PLAN.md. Long delivery
spikes and physical comfort/listening remain open; a simulator pass does not close them.


Bullet correction after build10: hold fire with all four weapons while strafing,
then release/repress rapidly. Rounds should travel continuously on both devices,
start promptly from your muzzle, and join confirmed shots without duplicate pellets
or repeated sound. Try shotgun Scattershot/high-velocity/Quick Trigger, last cartridge,
manual/full reload, ricochet/pierce, near cover and an enemy touching the muzzle.
Do not count guessed visual contact as a confirmed hit: health/damage remain server
owned. Pause/background/death/shared-choice/reconnect must cancel guesses. During
long update gaps visuals must stop rather than fly indefinitely. Review reduced
motion, shot audio and both-device aim/impact alignment; automated simulator tests
are not physical approval. See ONLINE_PROJECTILE_PRESENTATION.md.

**Dash / lighter combat cues (21 October):** Dash across Magistrate chains, Marshal
beams, enemy rounds, contact and ground attacks. The entire dash must avoid HP loss,
shield use and hurt feedback; standing in an active hazard after landing can hurt.
Phase Step should extend recovery, not be required for the dash itself. Pause should
freeze protection/dust. Review the small floor dust wake (one modest cue in Reduced
Motion), thinner Skitter scuffs from initial commitment and the lighter sweep sector,
including its inside safe pocket. Check Marshal shots left/right/up/down/diagonally,
delayed second shots, brace counter, near cover and death cleanup. The body must stay
whole and the continuous beam begin at the rotating barrel. Online protection and
articulated muzzle require the matching server deployment; physical review remains
open. See art/COMBAT_READABILITY_REVIEW.md.


## Arsenal expansion — first native Burst Rifle candidate

Current local source offers a fifth solo weapon, Burst Rifle. Select it in Training, or settle3 normal boss victories to unlock it in Play; historic counts are not invented from old saves. Hold primary aim for three separate rounds, then a short gap; turn between rounds, release after one/two rounds, reload early/empty, pause during a burst/reload and test Restart/Continue. Capacity18, base burst period.60s, rounds.10s apart and full reload2.0s. Watch barrel/flash/pellet alignment, magazine seating and bolt timing at shallow/vertical/leftward angles and Reduced Motion; repeat with each survivor and independent grenade aim. Existing four guns retain their contracts.

Burst remains excluded from online kit options pending expanded protocol support. Otherten proposed additions, including Frost Shotgun, are not live. The first-slice unsigned build was not installed on the phone; native moving art/listening/comfort/balance approval remains open. See ARSENAL_IMPLEMENTATION_PROGRESS.md for exact automated evidence and limitations.


Burst reload correction now installed: shoot part of a magazine and tap Reload for a1.4-second magazine swap without bolt motion/sound. Empty reload takes2.0seconds and cycles the bolt. Times are before Sleight of Hand; both finish before held aim can fire. Compare the two animations/sounds, pause/Continue during each, and test Reduced Motion. Carbine retains its tactical behavior; Shotgun/Revolver/Arc remain unchanged.

## Fifteen-weapon native review

Training → Weapon now exposes all fifteen. Follow
[FIFTEEN_WEAPON_PLAYTEST.md](FIFTEEN_WEAPON_PLAYTEST.md), including Aim Assist
Off/On, Frost freeze, the sniper’s release shot and piercing, reload commitment,
pause/background/Continue and Extended Tube. New weapons remain online-gated.

Weapon correction pass: follow [WEAPON_DEVICE_REVIEW.md](WEAPON_DEVICE_REVIEW.md) for flowing fire, grounded blasts/spores, near/far lobbers, disc recovery and Training Pause weapon switching.

## Combat and weapon correction — 22 October 2026

See [COMBAT_MATERIAL_AND_WEAPON_REVIEW.md](COMBAT_MATERIAL_AND_WEAPON_REVIEW.md): grounded enemy/boss floor materials, committed Skitter route/landing warning, real Burster walk gait, subtle solo damage vignette, live-gun Reaper return,100-round accelerating Repeater, clearer stronger Rivet crowd payoff, Frost2.2/pellet, two-hit normal frontal shields for Sniper and reliable Spore ruptures under FX saturation. Release remains1.0.0+11. Physical acceptance remains open.

## Universal tactical reload and sniper fatigue — 22 October 2026

See [RELOAD_AND_SNIPER_FATIGUE.md](RELOAD_AND_SNIPER_FATIGUE.md). Every current
weapon now has a70%-duration ammo-remaining manual reload without its final closing
action/audio; empty reloads retain full timing. Sniper sight and actual shot share
subtle.18→.85° fatigue over six seconds, with active rest recovery. The separate
[SIX_WEAPONS_AND_WEIGHT_PLAN.md](SIX_WEAPONS_AND_WEIGHT_PLAN.md) proposes six stronger
weapons and0–7% walking penalties. Those six and weapon weight are not implemented.


## Six endgame weapons and weight — 22 October

Training → Pause → Weapon Practice now offers all21. Try Twin Verdict's paired
barrels on one enemy, then deliberately miss/change target; compare with Revolver.
Flak should split forward once and never multiply its damage inside a boss. Aim
Anchor near/far, walk enemies into its jaws, and verify planted enemies stay put.
Release Faultline through a pack and at cover; each body takes one section hit.
Compare Cyclone's rapid five-pellet volleys with Frost's freeze; range matters past
210. Bell's echo should miss an enemy that leaves the original cone before .55s.
Manual reload with rounds uses70% time and skips the closing action on every gun;
empty automatically uses the full action. Hold cannot interrupt either.

Blind-swap Rook with Carbine/Repeater/Anchor:300/282/279 normal walking, same1450
dash. Check Mobility in the loadout details/summary; upgrades should survive swaps.
Review all three survivors, left/up/down shots, aiming-thumb mirrored/floating
controls, Reduced Motion, pause/background, Continue, repeated Training swaps and
weapon sounds. Performance, comfort and final balance need actual phone play.


### Heavy-weapon follow-up

Twin: alternate barrels on a tough enemy to hear/see the brand shatter. Kill a weak
enemy with the opening shot, then shoot another: the opposite barrel still shatters.
Only two nearby forward victims take secondary fragments; cover stops them. Miss,
change living target, reload or Continue clears the previous pair. Bell is now a
bright airborne weapon pulse plus brighter separate echo, with unchanged committed
hit rules. Try all six at base/VIII for release/impact/mechanism sound and recoil.
Flak must burst at body/cover/range without hovering, even near arena edges or after
Continue. Guard/Scrap Armour should show a quiet shield beside the feet, with no
chain/debris wreath around the character. Check Reduced Motion and speaker mix.

## Proportionate enemy reactions — 22 October

All21 weapons now have individual force/brief-stagger profiles. Compare Carbine,
Repeater and Cinder's restrained nudges with Revolver, Shotgun, Sniper and Rail;
then compare all six heavy weapons. Bell should visibly stop/push ordinary enemies,
with a softer echo. Twin's paired shatter pushes more than its opener. Grenade,
Mortar, Rivet reload blasts and Anchor crush push away from their blast centers.
Frost retains its physical shove while freezing. Burn/spore floor ticks do not
continually shove. Shields resist strongly; bosses/nests/sentinels stay planted.

Try high fire-rate/pellet upgrades: enemies must recover between hard staggers.
Check walls, body crowds, pause/background, death poses and Reduced Motion. See
[WEAPON_ENEMY_REACTIONS.md](WEAPON_ENEMY_REACTIONS.md) for the full profile table.

## Training menu and settings — 22 October

Return to Training after the tutorial: no middle-screen Skip/Ready or tutorial
hints should appear. Pause: Menu, Resume, Restart and Settings stay at the top
while the practice list scrolls. Each practice section starts collapsed; tap its
header to reveal/collapse. Weapon Practice shows21 gun images, base magazine
counts and EQUIPPED. Swap guns and confirm the game stays paused.

Boss Practice contains random rush, next round/restart rush and individual boss
choices together. Survival holds Take damage; Supply is Breach-only. Check Fusion
Practice too. Reduced Motion should settle sections immediately. Repeat with
larger text and a notched phone; header/actions must remain reachable.

Settings → Controls is shared by Training, normal pause and multiplayer's match
menu. Check grouped layout/spacing, slider values, left/right hand, fixed/floating,
Arrange, Reset, and saved settings after returning/relaunching. Online Menu is
top-right; the match continues while its menu/settings are open and local fire
must remain off. See [TRAINING_MENU_REVIEW.md](TRAINING_MENU_REVIEW.md).

## Normal pause and consistent notices — 22 October

Pause a normal run: check survival, kills, bosses, health/ammo and level/XP against
the live HUD, including an active reload. Menu/Resume/Restart/Settings remain pinned.
Try Menu and Restart, then cancel/back/tap outside: the run must stay paused and
unchanged. Accept Restart only when ready to reset. Menu's Save & leave should
return home with Continue available. A failed save must leave the run available
and show a retry warning. Training's Menu/Restart also confirm.

Compare update, Replace saved run, Reset progress, Training briefing and the new
confirmations: they should share the same stepped frame and text hierarchy.
Check compact screens, larger text and keyboard Cancel. Multiplayer Leave must
warn about forfeiting an unfinished versus match and do nothing until confirmed.
The match still continues behind its menu/settings. See PAUSE_AND_NOTICE_REVIEW.md.

### Tablet landscape review

On iPad, rotate between both landscape directions: arena should fill the canvas, sprites retain proportions, HUD remains legible and no portrait mode appears. Test movement + aim + dash/reload, grenade drag range, both handedness modes, floating sticks and saved custom layouts. Review training catalog, loadout, settings and normal pause at larger text. Compare phone layout against the existing candidate. Record sustained hardware performance and thumb reach separately from simulator layout acceptance. Full-screen iPad deliberately excludes Split View/Slide Over. See `TABLET_LAYOUT_REVIEW.md`.

## Ten survivors and41 upgrades — 22 October2026

Training exposes all10 survivors. In Loadout inspect role/HP/base and weighted
walking, choose each survivor, then switch weapons: the preview must HOLD that
weapon without blank art, floating detached gun, stale atlas or moving grip.
Normal locked cards show earned progress; Training must not farm unlocks.

Run all four directions and repeatedly turn left/right. In particular compare
contact and narrow passing phases on Flint/Vesper/Fuse/Moth/Coil/Suture/Harrow;
feet/knees must keep animating, torso must stay anchored and the gun must stay
seated. Try dash/hurt/death/landing, Reduced Motion and all21 gun mounts. Compare
with the preserved Scrapper repair. Review actual continuous movement on a phone.

Flint: real reload empowers one release; pickup refill does not. Vesper: complete
a dash, then fire; repeated fast dashes must not extend the window. Fuse: independent
throws retain two charges and10s final recharge floor. Moth: tag different targets,
then compare burns/elite burns and cover-limited spread. Coil: count hit releases,
not pellets, and compare Arc/Faraday against a single boss and packs. Suture: bank
15 kills at full HP, lose health, verify one heal/12s gate and no lethal rescue.
Harrow: compare ordinary packs with elite/boss and apparatus damage.

Review support prerequisites, useful capped offers, one owned-family choice,
current/next values, all eight new families and Kiln Pact/Ground Wire. Both need
purchased III/II ranks and an explicit core; existing two slots stay. Pause/picker/
background must freeze timers; Continue must not replay charges, discharges,
heals, rewards or unlock counters. Read TEN_SURVIVORS_IMPLEMENTATION_REVIEW.md for
source ownership, exact values, migration and evidence. Human balance/readability,
comfort/listening and physical performance acceptance remain open.

## Upgrade copy and optional details — 22 October 2026

In a normal run, compare the short effect explanation and visible ammo/damage/
chance/timing changes. Open Details on Heavy Load, Scavenger and Lucky Find: full
values should appear without spending the offer, XP or a rank. Collapse again;
choose, reroll or ban and ensure the next offer starts concise. In Training the
full breakdown starts open. Check later Scattershot ranks describe tighter spread,
not additional projectiles. Check supply offers too. Repeat at larger text:
Details, Ban, Reroll and every card must remain reachable by scrolling; cards in
the same row keep aligned edges. Review readability and decision speed on a phone.

## Email identity and offline independence — 22 October 2026

With identity/online services unreachable or slow, enter Solo, Training and local
Continue. Gameplay must start without waiting for verification. Open account
setup, request a code, then dismiss while the request is pending; local play must
remain available. Background/email foregrounding, keyboard and larger text must
keep fields, Verify, Resend, Change email and the exit reachable.

With a staged HTTPS identity service and test sender configured, finish Training
and return Home: invitation appears once, never on first fresh launch or over an
update notice. Not now persists; Settings retains Connect email. Verify a six-digit
code, choose username, acknowledge the first cloud backup, then sign in on another
device. Check earned gear/records/cosmetics/selected kit; Continue/controls remain
local. Exercise two-device offline progress conflicts and explicit save choice.

Online must refuse unverified/incomplete accounts even if an old guest credential
exists. Room names are read-only and cannot override the account username. Change
only in Home Settings: initial naming is free; two changes consume allowance,
no-op/rejected names do not, and the server UTC reset is shown locally. Test
reserved/harmful/obfuscated names and benign exceptions. Recover older records
only with the original guest credential and verify repeated claims do not add
balances/rewards again. Preserve original guest credentials for rollback review.

Test fixed-email enforcement, fresh-code deletion, offline sign-out/reconnection and cloud
reset. Account A/B profiles, pending saves and Continue must not cross. A reset or
deleted account must not be revived by an older pending device. Start local play
while an account request is still running: late completion must not switch its
profile in mid-run. Verify actual inbox delivery and native Keychain/keyboard/
foreground behavior separately from captured-mail/local socket tests.

Account production follow-up: Gameplay precedes Account. Email-change, quota,
legacy-record recovery and standalone re-verification rows must be absent. Open
OTP entry, type part of the code and tap outside to hide the keyboard: the dialog,
code and resend timer must remain; Not now/Back still explicitly exits. Confirm
new messages show Regun as sender, including a server configured with a bare
hello mailbox. Review compact phone/large text after scrolling through Account.

## Screen changes and Mummy gait — 22 October 2026

Move between Home, Loadout/Training, Settings, Controls, Collection and Online;
open Settings from Pause and return. Screens should fade briefly through the
dark game surface, remain planted and never slide sideways. Back/Start and
replaced-route returns must keep their normal destination and local run scope.
Reduced Motion (game and OS) cuts straight to the destination. Test rapid back,
background/resume during navigation and both landscape orientations.

At25 seconds the gray bandaged Mummy joins the scorpions. Watch it approach from
both sides, turn, walk vertically, get blocked by another body/cover and resume.
Its eight-pose stride should keep its body scale/ground baseline, advance with
travel and retain phase through a turn. The old attack/hurt/death poses and
.6-second close-strike cadence remain. Review online co-op too: snapshot movement
drives the same walk art without changing server combat. The runtime contact
sheet is `build/test-previews/mummy-walk-both-directions.png`. Physical gait,
transition comfort and sustained performance still require device review.


## All-weapon power candidate — 23 October 2026

Start a new run (Continue deliberately preserves revision1). Use the matrix and
acceptance procedure in `WEAPON_POWER_IMPLEMENTATION_REVIEW.md`. Compare Pump's
three close connections, Spore ground occupancy/exit, delayed Mortar/Rivet/Anchor
payoff and Bell's single coherent strike with quieter .55s resonance. No weapon
body art or firing/reload pattern should have changed. Verify Reduced Motion,
cover, pause/resume and saturation. Normal unprotected runs and multi-seed boss
comparisons are still required; stationary probes are not win-rate evidence.

**Admin power-up strength / offline recovery (23 October):** Publish a small
Production strength adjustment, let the game fetch in the background, then start a
new run. Confirm the expected upgrade bonus and unchanged rank/fusion requirements.
Background/close the game during a normal run, publish another value, reopen and
Continue offline: saved balance, strength, build and position must remain pinned.
Repeat a fresh offline launch and server timeout; controls/Start/Training/Continue
must stay available with cached or bundled values. Automatic checkpoints represent
the most recent successful periodic/lifecycle save, not every simulation frame.
Admin Staging stores isolated preparation releases and has no playable preview.

## Charge capacity review

Pick Double Dash I/II and Grenade Reserve I/II: expect2/3 dash slots and3/4 grenade
slots. Spend the reserves rapidly; only the first missing slot recharges at a time.
The purchase fills only its new slot and retains the pending timer. Pause/background
and Continue mid-recharge must preserve charge counts and timers. Check markers at
smallest/largest control sizes and mirrored placements. Set admin totals to2/3:
new runs should offer only one rank of each; an existing Continue keeps its former
snapshot. Verify old online clients receive neither new offer and protocol4 peers
agree on spending and recovered charges. Physical comfort/balance remains to review.

## Boss health, grenade placement and landed supply cover

- Kill each boss at full health: gain exactly2 HP above the unchanged maximum.
  Kill another: gain2 more. Ordinary healing/Salvage must not remove extra HP.
  Save/Continue preserves the extra HP without granting it again. Check the
  boss-name VANQUISHED/+2 HEALTH stamp, including pause, two kills and large text.
- Throw into a crowd: the front enemies must not detonate the grenade. It should
  land, bounce and explode on its1.4s fuse. Compare the predicted landing marker,
  short/full drag throws, walls, pause/background and Continue mid-flight.
- Enemies just outside the damaging blast should be pushed without losing HP;
  cover and planted enemies still resist it. Review force/readability in packs.
- Let a supply pod land among enemies: center crush plus wider blast/pressure.
  Walk, dash and shoot against the landed pod from every side; grenades bounce
  against it. Standing under landing causes safe displacement, not player damage.
  Opened pods stay solid; breakdown releases the space. Continue must restore
  cover without repeating landing damage. Capture remains possible around it.
- Cross Queen poison/tail/brood warnings and every boss arrival/attack at both
  positive and negative map coordinates. Floor art, shadows, remains and dust
  must stay beneath player/enemy bodies. Check the same ordering online after
  deploying the matching server; do not infer deployed support from local tests.

### Training weapon groups

Training → Weapon starts on **Your weapons**. Choose **Try locked weapons** to
practice any gun you have not yet earned. Selecting one shows **TRAINING ONLY**,
its normal unlock requirement and **Pin unlock goal**. The pin appears in career
progress/Results and survives restart. Switching Survivor/Weapon/Arena keeps the
assembled kit and chosen group. Starting a fresh Training visit returns to Your
weapons. Pause → Weapon practice offers the same two groups and goal action.

Trying a gun does not unlock it for normal runs or grant Scrap/mastery rewards.
Normal loadout preferences and existing earned unlocks are preserved. The free
Training introduction still unlocks Carbine when completed or skipped. Boss Rush,
weapon switching, survivor/arena selection and fusion practice remain available.

### Training enemy pressure and bosses

Pause Training → Survival practice → **Enemy pressure**:

- **Light:** a small group, targeting8 nearby enemies.
- **Normal:** the default, targeting22 nearby enemies with prompt replacement.
- **Horde:** a dense crowd, targeting38 nearby enemies.

These are bounded targets, not an instant spawn burst. Enemies spawn offscreen
and walk in like normal survival, at every pressure level. They must never appear
in front of the player, even near arena edges. Body/cover rules remain. Lowering pressure removes surplus farthest enemies
without rewards. Pause and upgrade choices freeze spawning. Your choice remains
through Restart, recovery and Boss Rush during this visit; a fresh visit starts
Normal. Take damage remains a separate control.

Selecting an individual boss keeps the crowd and its pressure setting. **Start
Rush** clears regular enemies, pending arrivals, stray ordnance/attacks and loose
XP, then runs boss-only encounters. It keeps your build and remembered pressure.
Selecting an individual boss afterwards restores crowd spawning at that pressure.
Check both arenas, rapid crowd clears, movement away from the original crowd,
changing settings while paused, Restart and repeated Rush/boss switches. Confirm
that bodies remain readable and leave usable space on the actual phone.


## Fence edges and supply pod grounding

In both Breach and Foundry, walk and dash against the top, right, bottom and left
fences and into each corner. Feet must remain inside the visible fence, including
when sliding sideways along the south rail. The bottom stop accounts for the wall
face and the survivor's feet; combat hitboxes and camera framing remain unchanged.
Try different survivors/facings and a Continue saved near the old boundary.

After an airdrop lands, let the dust clear. The four feet should have tight dark
contact with the floor in closed and opened states, with no detached oval below
the pod. Check expiry/breakdown fade, Reduced Motion and player/enemy depth while
walking around it. Contact shading is shared with online supply presentation;
server collision/landing/capture contracts stay unchanged.


## Airdrop routes and final blast

Put a landed pod between you and a pursuing group. Check the four sides, larger
ordinary enemies, a player standing beside the pod and a pod near an arena edge:
they should round the pod while respecting its solid footprint and one another.
Committed jumps/charges still hit cover instead of bending during the attack.
When the pod disappears, the detour should stop affecting movement.

Claim one pod and let another expire. Both should explode once when breakdown
starts, with the same blast/force as landing, then finish their panel cleanup.
The player remains safe even inside the blast. Check pressure-only enemies beyond
the damage area, bosses/planted roles, pause and Continue during breakdown: no
second damage pulse or replayed reward. Reset/Rush cleanup should not detonate a
pod. The matching server source must be deployed for this behavior online.

## Upgrade offer rarity review — 24 October 2026

Start a fresh run for the new offer policy; Continue on an older save intentionally
retains its original odds. Double Dash and Grenade Reserve should appear less often
than regular upgrades, with their second ranks rarer again. Existing ordinary
build upgrades should remain practical to improve. Look for less repetition across
XP choices, supply drops and rerolls, without expecting a recent card to be banned.

Record several runs: weapon, survivor, level, visible choices and selected rank.
A single run cannot establish drop rates. Save/Continue during a picker should
preserve the existing hand; reroll limits, bans, fusion recipes, XP costs and
capacity limits should behave as before. Training practice remains unrestricted.

## Upgrade rank review — 24 October 2026

Use a fresh run with rank policy1; Continue on an older snapshot deliberately
keeps its prior rules. Compare Heavy Load, Quick Trigger, Fast Reload, Scrap
Armour and Ordnance Cycle at III/IV/VIII. Early ranks and total VIII power should
match their former totals; IV/VIII redistribute late growth. Keep track of which
later choices feel useful rather than assuming the mathematical curve feels good.

Training Pause → Rank comparison uses the visit's current weapon, survivor and
pinned balance, and does not grant anything. Collection → Upgrades → Show rank
path gives all ranks for an example loadout. Compare card summaries/Details with
actual magazine, reload and combat behavior. Flint shotgun reload and Fuse
grenade recharge should stop offering further ranks once their floors are reached;
Arc Caster's already guaranteed chaining may appear only to advance a valid fusion
prerequisite. Coil retention can still improve after ordinary retention caps.

Admin → Balance → Rank curves: change one milestone in a draft, compare baseline
and draft paths, choose relevant weapons/survivors and check the API preview.
Review/publish through staging and production as usual. Existing saved runs must
keep old values after publication; fresh runs must use the new release. Test
small-screen/large-text card expansion, Training comparisons and admin forms.
Source validation is not phone performance or physical balance approval.

## Early boss variety — 24 October 2026

New normal Solo runs order their first boss rotation by recorded per-boss wins:
less-beaten bosses first, random order among ties. All eight still appear before
repeats; later bags return to the normal shuffle. Counts begin with observed wins
from this update, not fabricated splits of old aggregate totals. Settle a few runs,
then compare openings. Training/Rush wins must not affect the ordering. Continue
must preserve the already-chosen bag, including after a revive. See BOSS_VARIETY.md.

## Boss attack collateral — 24 October 2026

In Training, use individual boss practice with Hordes. Ordinary boss movement
must leave minions alive. Shadow dash and Demon charge should clear the actual
body corridor only once the attack begins. Sweeps/ground strikes should kill
minions inside the active shape, preserving safe pockets and solid cover.
Warnings and paused attacks must not kill. Other bosses remain unharmed.
Player damage, timing and protection remain as before; boss-caused minion deaths
must not increase player kills, score, XP or kill-triggered bonuses. See
BOSS_COLLATERAL.md. Native feel/readability and online play need hands-on review.


## Houndrack / Storm Orb / Ring Caster review

Use Training to access all three. Houndrack should feel like continuous miniature rockets with mild correction, not hard homing; test blockers and clustered splash. Send Storm Orb past a pack and compare passage arcs with an immediate body hit; verify cover stops arcs. Hold/release Ring Caster at several radii, move with it and watch outward/return edge cuts: its interior must stay empty. Test early release, last charge, reload, pause, Continue and Reduced Motion. In admin adjust one of the 18 behavior fields, compare the authenticated API preview, publish through the existing workflow and start a fresh run; Continue must retain its pinned values. See [THREE_WEAPONS_REVIEW.md](THREE_WEAPONS_REVIEW.md). Native comfort/audio/performance and tuning still need hands-on approval.


## Weapon feedback, innate Revolver and power-up layout — 24 October 2026

This supersedes the initial three-weapon review above. In Training, fire Ring
Caster while stationary and moving: a compact cutter should emerge from the
muzzle, travel forward slowly while growing, then return to the gun when
released. Check early release, cover, last charge, pause and Continue.
Houndrack should accelerate into its acquired target with audible propulsion
and a quiet flight hiss; compare near/far primary damage (no distance drop-off).
Storm Orb should pass through several enemies, apply extra damage once to each
crossed body, and produce separate crossing crackles and accepted-arc zaps.

Start Revolver without upgrades: a round should ricochet once to a different
nearby enemy. Its Ricochet rank must still be zero. Buying the upgrade adds to
that innate count. Admin exposes Enemy ricochets beside base damage; compare
API component/rank previews and fresh game/hosted snapshots after normal
publication. Continue retains its pinned values.

Open the power-up picker on small landscape phones and with larger text.
Default offers, their Ban buttons and Reroll should fit; at larger text, scroll
the offers while Reroll stays pinned. Inspect the larger glyphs. In wide admin
panes the item artwork should sit right of title/description; narrow panes
stack. See WEAPON_FEEDBACK_REVIEW.md and its validation frames/audio mix.


## Temporary-cover crowd routing — 24 October 2026

In Breach Training call an airdrop and lead a dense mixed pack around each face
and corner while the pod is active/opened. Cross sides and stand close to cover;
pursuers must round it without continuously walking into it or crossing each
other. Check the fence-side route and chase after the pod breaks. Committed
leaps/charges must still stop at cover. Repeat in online co-op after matching
server deployment. The future sentry must register its base in the same geometry;
70×44 proxy and adjacent-cover regressions cover that foundation, not a completed
sentry feature. See AIRDROP_NAVIGATION_FIX.md.


## Combat visibility and hurt footprint — 25 October 2026

Fight one boss, then a Training pair on small landscape screens and larger text.
The top HUD should show thin transparent name/health strips without an opaque
combat plate. Check the enrage marker and both identities. Take a real hit, then
compare guard absorption and protection: only lost HP should show the warmer
survivor response, stronger brackets and the .9s HP readout above the body/heart.
Repeat with Reduced Motion, muted audio, pause and restart; movement must stay
responsive and the camera steady.

Graze Revenant darts and Shadow bolts: a clearly missed smaller body should be
safe, but fast rounds crossing the body between frames should still hit. Check
Skitter leaps, Shadow/Demon charges, ground edges and ring safe pockets; movement
clearance against fences/pods is unchanged. Repeat online only after matching
server deployment. Confirm fresh runs still use your chosen admin shotgun values;
this change does not publish or modify them. See COMBAT_VISIBILITY_AND_HURTBOX.md.


## Airdrop support candidate (25 October 2026)

Normal family flags are Off. In Breach Training, pause and choose Sentry practice
or Aura practice, then confirm the displayed card. A sentry follows movement
until its warning commits, lands at six active seconds, unfolds, fires and
expires. Check both unique gun variants and rotation quadrants. It must keep its
current reachable enemy even when a nearer one appears; after one continuously
unreachable second it may reacquire. Burst rounds must leave separately.

Walk around the base from every face, push crowds past it, and compare warning
visibility with nearby hostile attacks. Pause during incoming, fall, unfold,
reload and breakup; Continue must preserve phase and never replay impact damage.
Restart/Rush cancels without detonating. Aura follows the survivor, obeys cover,
stops after expiry and must remain distinguishable from hostile floor warnings.
Repeat in Reduced Motion and with large text and mirrored controls.

For co-op use the matching capability-6 server/client candidate. Test simultaneous
2/3-player calls, adjacent reservations/source pod, down/revive, disconnect/rejoin
and expiry. Overlapping Aura fields use strongest-only damage. Record actual
phone frame pacing, audio/mute/foreground behavior, readability and balance;
automated tests and local builds do not close these physical acceptance gates.


### 25 October: support feedback correction

Airdrop support availability is weighted, never a reserved card: default two
families give 2/3 support hands, 1/3 ordinary-only; one family gives 1/2. Training
called drops and co-op use the same rule, including rerolls/bans. Check a series
of fresh drops, not a requirement that every short sequence contains both kinds.
Sentry now excludes its own base from projectile wall contact, predicts bounded
target motion and preserves short actual-flight traces. Prepared multipliers
3/3.5/4 require admin publication (observed live revision 5 remains 1/1.15/1.3).
Aura adds active-clock inner sigils/crackling and steady Reduced Motion art;
players remain vulnerable. Verify close/all-direction shots, cover, reload,
normal/Reduced Motion energy, pause and co-op readability on device. See
`AIRDROP_SUPPORT_IMPLEMENTATION.md` for automated evidence and rollout limits.

Aura motion follow-up: outer ring rotates clockwise at .08 rad/s; inner seal
and its layered currents counterclockwise at .20 rad/s. Both use active life,
freeze on pause and hold steady under Reduced Motion. Shared native/online art.
