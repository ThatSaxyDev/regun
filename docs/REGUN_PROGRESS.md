# Regun completion progress

**Historical implementation log.** The authoritative full-game scope and roadmap are now in [REGUN_COMPLETE_GAME_PLAN.md](REGUN_COMPLETE_GAME_PLAN.md). Completed work below remains evidence; earlier proposed next passes are superseded.

## Direction and constraints

- Mobile first, with iOS validation followed by Android. Quality takes priority over the original upload deadline.
- Preserve the manual aim / shotgun / reload / dash identity and endless-survival direction.
- Preserve the original shotgun reload formula: 900 ms for one missing shell, plus 700 ms for each additional missing shell. Keep the existing Lottie asset and normal playback speed. First five-round full reload remains 3700 ms; sounds remain at 0, 700, 1400, 2100, and 2800 ms. The existing fast-reload upgrade retains its separate timing.
- Earlier passes retained sprites while repairing functionality. The complete-game scope now authorizes coherent new art and animations.
- User screenshots confirm the camera showing outside the arena, oversized controls, and buttons that conflict with the game's visual theme. These are explicit completion requirements.

## Pass 1: completed implementation

### Arena and controls

The loaded Tiled map supplies the world rectangle (4512 × 4512). Camera clamping, movement bounds, and spawn positions now share that geometry. The player can slide along walls and cannot dash through them. The camera stops following at the map edges instead of revealing empty space.

All four controls now live in the camera viewport, including dash and reload. Their positions scale together with the fixed-resolution game view. Their original art was retained in pass 1; pass 2 below replaces the controls and shared buttons.

### Growing runtime work

- Replaced the firing SpawnComponent/EmptyComponent pattern with a single repeating action timer.
- Removed RiverpodComponentMixin from gameplay entities that only read state. Their mounting and removal no longer force Flutter game-widget rebuilds.
- Preloaded the active sprite roster so first spawns do not decode those images mid-fight.
- Added strict tracked population budgets of 120 enemies and 80 coins, including pending loads. These are initial budgets to tune against physical-device profiling and difficulty design, not final balance targets.
- Bullet hit handling now runs once per contact; already-dying targets cannot restart death effects or schedule repeated removals. Scorpion deaths emit one smaller particle burst. Mummy/ranged death cleanup follows simulation time.
- Enemy shots no longer kill their own team or depend on the player's piercing upgrade. They are passive colliders against the player/player bullets.
- Audio requests share an in-flight load per asset, tolerate unavailable audio, and no longer compute unused SoLoud visualizer data.

### Run correctness

- Each game route has its own scoped notifier. One reset creates fresh run state and cancels prior reload/dash/invulnerability clocks. An outgoing route cannot cancel a new route’s run clocks.
- Restart swaps the complete World, which isolates enemies still loading as well as mounted enemies. The map and viewport controls are retained.
- Reloads and shell sounds now follow simulation time. Pausing, upgrade selection, and app interruptions freeze them. The Lottie HUD stays mounted through overlays and its ticker pauses with gameplay.
- Ammo cannot go negative; an empty magazine starts reload and returns without firing an extra volley.
- Damage is centralized, clamped, and protected by a 500 ms interval between accepted hits. Dash invulnerability applies consistently to active enemy damage sources when unlocked.
- XP upgrades at the intended threshold, with one stable pair of eligible upgrade offers. The world pauses fully while choosing. Repeated queued taps cannot apply a second old offer.
- One-time/capped upgrades are filtered from offers. Enemy roster unlocks are idempotent rather than using a 20 ms pickup race.
- Backgrounding moves a playing run into the pause state and clears input. Resume is deliberate.

## Measurements and validation

| Check | Before | After |
|---|---|---|
| Placeholder components retained after 600 simulated idle seconds | 1714 | 0; one timer retained |
| Isolated 36,000-update timer microbenchmark | ~203 ms | ~23–25 ms |
| Three-minute scene simulation | No population budgets | Peak 120 enemies, 80 coins, 205 retained world children in the observed run |
| Analyzer | 15 diagnostics | Clean at the end of this pass |

The timer benchmark measures only that subsystem in a Flutter test runtime. It is not an FPS comparison or a claim of an eightfold improvement to the game. The dense scene test runs actual game components with real assets, movement, shooting/reload, and upgrades; it uses extra health to keep the simulation running. It does not measure mobile rendering, thermal behavior, or human multi-touch control feel.

Regression coverage includes all five normal reload timings and shell counts, paused reload behavior, restart isolation, ammo bounds, damage/invulnerability/death, exact XP thresholds, stable upgrade offers, camera edges/corners, wall/dash clamping, actual scene mounting, bounded entity growth, and long-run timer retention. A rendered corner scene was inspected to verify the camera/player positions visually.

Final verification for this pass:

- `flutter test --no-pub`: all 16 tests passed.
- `flutter analyze --no-pub`: no issues found.
- `git diff --check`: passed.
- `flutter run --release --no-pub -d 00008101-000248EC1450001E`: signed release build completed, installed and launched on the physical iPhone over Wi-Fi.
- Branch remains `tiles_for_background`; changes are in the existing working tree, with earlier user changes preserved.

Hands-on frame-rate, thermal and multi-touch validation remain pending. Native installation is not a substitute for those checks.

## Current roadmap

Follow [the complete game blueprint](REGUN_COMPLETE_GAME_PLAN.md), especially its milestone gates and final definition of done. The earlier short list of next passes was insufficient for the requested complete game and has been replaced.

## Pass 2: buttons and touch controls

The creator correctly called out that deferring the explicitly rejected buttons was a missed requirement. This pass replaces the visible controls rather than leaving them as a plan item.

- Replaced the oversized A/B art with labelled pixel dash/reload symbols on small charcoal plates, while retaining 112 × 112 world-unit touch areas.
- Reduced and unified both joystick graphics: translucent rings, small metal thumb pads, and less arena obstruction.
- Rebuilt the shared Start/Restart/Resume/Menu/upgrade buttons with stepped corners, hard edges, warm brass/rust accents, and PressStart2P lettering. Removed pastel purple/red fills and rounded toy-like shadows.
- Added pressed/disabled/active/reloading feedback. Menu actions activate directly without the old delayed callback.
- Recorded the creator-supplied design direction in `.impeccable.md` for future sessions.
- Preserved sprites, shotgun reload timing, shell sounds, and the Lottie asset.

Validation: 17 tests passed, analyzer clean, phone-size menu and game/result screenshots rendered and visually inspected. The added UI check also verifies touch activation. Previews are in `build/test-previews/`.

Pass 2 release build was signed, installed and launched on the physical iPhone over Wi-Fi.

## Audit reconciliation and intended slow motion

The creator confirmed that the 10% world speed during upgrade selection is intentional. It is restored, with stable upgrade offers and blocked player damage/input while the picker is open. Reload clocks and their HUD animation stay frozen while choosing; ordinary pause and game over still stop the engine. The original audit item classifying slow motion itself as a defect is withdrawn.

| Original finding | Current status |
|---|---|
| P1: negative ammo / extra volley | Fixed and tested |
| P1: restart isolation | Fixed and tested, including loading entities and route-local state |
| P1: upgrade world running | Reclassified as intentional slow motion; restored at 0.1× |
| P1: unstable choices / build side effects | Fixed and tested |
| P1: enemy unlock race | Fixed with idempotent unlocks |
| P1: inconsistent damage / invulnerability | Fixed for the active roster |
| P1: health bounds / death transition | Fixed and tested |
| P2: XP off-by-one | Fixed and tested |
| P2: actual enemy health / damage / kill rewards | Still open; active enemies still die on the first bullet hit |
| P2: hostile projectile friendly fire | Fixed for the active ranged enemy; dormant shadow projectile code still needs migration |
| P2: complete boss encounter | Still open |
| P2: component accumulation | Main leak fixed, populations bounded and simulated; physical-device traces / thermal checks still open |
| P2: coordinate systems / arena edges | Fixed; new controls need continued real-device reachability validation |
| P2: capped / redundant upgrade offers | Fixed and tested |
| P2: wall-clock gameplay timers | Fixed for the active run; dormant mine/shrapnel/shadow/dialog experiments still contain futures |
| P2: audio error handling / concurrent loads | Implemented; deliberate failure injection on native devices still open |
| P3: maintenance / presentation / release completeness | Partial: analyzer clean, regression tests, redesigned buttons, native iPhone release install. Metadata, credits/asset rights, stale automation, Android signing, settings/tutorial/results/persistence still open |

Next substantive gameplay work remains enemy damage/kill rewards, kill-linked XP, and difficulty progression, followed by a complete boss encounter.

## Pass 3: combat loop, Shadow, and mobile controls

This is the first implementation toward the complete-game blueprint. It is **not** completion of M1/M2 or the full release scope.

### Implemented

- Shared `CombatHealth` / `Damageable` contract: scorpion, mummy, ranged enemy, and Shadow receive actual damage. Health reaches zero once; rewards cannot repeat on overlapping hits. Chaser contact no longer bypasses its health by killing it.
- Killing enemies creates XP drops; removed the ambient coin spawner. Attraction pulls nearby drops toward the player. At the 80-component budget, new XP merges into an existing drop without losing value. Score/kills are awarded for kills, not pickup touches.
- XP overflow survives multiple queued level-ups. Three distinct offers are generated once, and UI interactions carry an offer token to reject taps from old selections.
- Initial elapsed-time encounter director introduces mummy and ranged roles, reduces arrival frequency during bosses, schedules Shadow around three active minutes, and prevents stacked bosses with recovery time.
- Shadow is in the live loop: arrival warning, aimed bolt fan, marked dash lane, close-area strike, recovery, stronger second phase, actual health, boss HUD, exactly-once rewards, and projectile cleanup. Its padded animation is positioned around the body instead of using its source-sheet center as the body collider.
- Added Heavy Load, Last Shell, and Breach Loader. Final-shell and post-reload bonuses are snapshotted on the shot. Meeting Last Shell 3 + Breach Loader 2 when defeating a boss enables an initial Breach Engine modifier. The planned core-choice/evolution presentation remains unfinished.
- Movement/aim controls retain separate pointer ownership and a small dead zone. Dash is now by the movement thumb, reload by the aiming thumb. Stationary dash uses aim or remembered movement. Dash has a cooldown and brief starting protection; Afterimage extends protection.
- Control positions and sizes use Flutter logical pixels converted through the actual canvas and letterbox transform. In Flame, `game.size` is the virtual viewport, so the conversion explicitly uses `canvasSize`. A phone-render inspection caught and corrected this distinction.
- Pause → Controls exposes side inset, height, stick size, ring opacity, mirrored layout, and reset. Preferences persist on the device. Independent dragging, floating sticks, sensitivity, and training preview remain planned.
- HUD now shows active survival time, kills, level, health, ammo, and Shadow health. Added three-card upgrades and results with survival, kills, bosses, score, early build recap, and saved personal bests.
- Normal shotgun formula, shell sound schedule, and Lottie remain protected. Fast reload cannot take longer than the normal partial-magazine reload. Selection retains 0.1× presentation and freezes logical combat/reload/run clocks.
- Removed the explanatory upgrade footer at the creator's request. Player-facing copy describes actions/effects, not simulation clocks or implementation decisions.

### Evidence

- `flutter analyze --no-pub`: clean.
- `flutter test --no-pub`: 31 tests passed before the native build, including physical pointer events for simultaneous movement/aim/dash and input release on pause.
- Added tests for repeated lethal damage, invalid damage, XP overflow/stale offers, full pickup-pool XP conservation, boss second phase/death/projectile cleanup, boss attack freeze during selection, director recovery, control geometry, and preference persistence/corruption.
- Existing normal reload tests still verify every one-to-five-shell duration and sound count.
- Three-minute component simulation remains bounded at 120 ordinary enemies. It does not establish physical FPS or player balance. Loot saturation is now tested explicitly from kill/drop behavior rather than expecting ambient coins to fill the arena.
- Phone-size rendered HUD, choices, Shadow arrival, controls, and results were inspected. Art/controls remain subject to physical-device playtesting.

### Milestone status and remaining scope

| Milestone | Status |
|---|---|
| M0 baseline | Working baseline, plan and regressions recorded; asset rights inventory remains open. |
| M1 controls/combat | Core damage and responsive layout implemented; independent calibration/training and human comfort validation remain open. |
| M2 playable slice | Kill XP, offers, Shadow, results and initial build interaction implemented; full run checkpoints/Continue, tutorial, music, explicit evolution rewards and balancing remain open. |
| M3–M9 | Full content roster, Demon/Queen, second arena, production art/audio, meta progression, accessibility, mobile resilience, profiling and distribution requirements remain open. |

Do not describe a release installation as proof that these outstanding milestones are complete.

Native verification for pass 3: `flutter run --release --no-pub -d 00008101-000248EC1450001E` completed its signed Xcode build, installed, and launched on the physical iPhone over Wi-Fi. Physical comfort, boss balance, thermal behavior, and frame-rate validation remain pending.

### Creator correction: keep dash on the aiming side

The creator rejected moving dash beside the movement stick. The corrected default keeps movement on the left and groups dash/reload around the right aiming stick. The layout is mirrored as a whole for left-handed use. Spacing and reach can change; the movement thumb must stay on its stick while the other thumb presses dash. The blueprint and design context now record this constraint. The touch regression test exercises that two-thumb sequence explicitly.

Checkpoint serialization and atomic-file storage scaffolding have been started but are not wired into a player-facing Continue flow. No full-run saving claim is made for this build.

### Creator correction: finish the settings design

Replaced the generic handedness switch with an explicit stepped Right / Left selector. It has selected markers, brass borders, pressed/focused states, and accessible selection semantics. Settings sliders now use rectangular tracks and custom pixel grips. Reworked the editor into two columns on landscape phones to avoid the previous unnecessarily tall panel. Phone-size renders of both selections were inspected, and the integration test opens the editor, switches layouts, and returns to play.

The corrected right-side action cluster and themed settings selector/sliders were signed, installed, and launched on the physical iPhone in release mode after these corrections. Analyzer and whitespace checks passed; the full suite passed 33 tests. The Flutter runner was detached to leave the game available on the phone.

## Full-game implementation pass — 19 October 2026

**Current status:** full functional content is implemented for testing. Earlier partial-pass scope descriptions above are historical. Physical-device acceptance, final visual/audio approval and distribution gates remain open; this is not a claim that every launch gate is passed.

| Scope | Implemented behavior |
|---|---|
| Run and combat | Kill XP, real health/damage, score, invulnerability/guard, burn/marks/chains, piercing/bounces, mines, shards, drone support, endless fallback rewards. |
| Loadouts | Four weapon identities with separate magazines, cadence, damage, projectile and reload presentation/audio; three survivors with their baseline/passive tradeoffs; all twelve combinations mount and fire in integration tests. |
| Builds | Thirty ranked families; six recipes with prerequisites and boss-core offers; six special slots, two fusion slots, reroll/ban budgets, rank caps, stable offer tokens and saved builds. |
| Encounters | Eight normal behavior roles, elite modifiers, marked arrivals, time-based director, increasing cycle pressure and capped adds. Shadow, Demon and Queen have live health, warnings, phase changes, recovery and once-only core/death rewards. |
| Arenas | Breach and Foundry, column geometry shared by movement and shots, vent hazards, bounded camera; substepped dash/wall sliding and projectile sweep/wall ordering. |
| Progression | Twenty challenge definitions, horizontal loadout unlocks, scrap, cosmetic ownership/shop/equip/previews, enemy/fusion collection, separate assisted records and once-only settlement. |
| Product flows | Menu, loadout, guided/practice training, HUD, upgrades/fusions, pause, results, collection, credits and settings. Training exposes all bosses/recipes without normal rewards. |
| Touch | Aim-side dash/reload retained; custom pixel controls, mirrored layout, fixed/floating sticks, independent arrangement, size/reach/height/opacity/sensitivity/dead-zone settings and interruption resets. |
| Persistence | Atomic serialized normal-run checkpoints with backup/tombstone, damaged enemies/bosses, reload/offer state and resume grace; profile backup, reset and protected cross-run settlement. |
| Presentation | Original canvas weapon/enemy/Queen/scenery/cosmetic art, effects/icons, four generated music loops and weapon/reload/UI cues; existing shotgun reload retained. Final premium art/audio and inherited asset rights require review. |
| Native setup | Updated Android Gradle/Kotlin/Java setup; removed unused legacy native audio/online dependencies; modernized splash generator; retained iOS CocoaPods for SoLoud. Makefile now contains relevant checks/builds without unrelated banking tests or global DerivedData deletion. |

### Verification evidence

- Analyzer: no issues. Regular suite: **58 passed**, with two opt-in soak cases skipped by default. Includes all weapon/character combinations, all three boss state machines/phase changes/rewards, live damaged-world save/restore with partial reload, touch/geometry, profile settlement, checkpoint backup and cross-run safety, and UI layouts on 667×375 and 1024×768 at 150% text size with bundled fonts.
- Explicit long-session suite: **both passed**. 30 simulated minutes: 7 bosses, 6,062 kills, peak 120 enemies / 80 XP drops / 40 effects / 240 world children; retained 124 at final sample. 60 simulated minutes: 13 bosses, 14,127 kills, peak 120 enemies / 80 XP / 95 player shots / 12 fire patches / 9 mines / 8 hazards / 300 world children; retained 142 at final sample. Full output: `validation/soak-2026-10-19.txt`.
- Those accelerated component simulations deliberately sustain health and do not measure phone FPS, memory bytes, thermal behavior, human balance or survival difficulty.
- Rendered and inspected phone HUD, settings, result/upgrade buttons, all four weapons, each boss and collection styles. Functional original canvas art remains subject to creator approval.

### Remaining gates and handoff

M0–M5 gameplay/content is implemented. M6 presentation/progression and M7 resilience have functional implementations and automated coverage; premium asset approval, provenance and physical checks remain. M8 physical balance/performance acceptance and M9 distribution are not marked complete. The unchecked final release checklist in the master plan remains authoritative.

Use [PLAYTEST_GUIDE.md](PLAYTEST_GUIDE.md) to reach every feature and record physical evidence. Creator decisions and asset provenance are in [ASSET_REVIEW.md](ASSET_REVIEW.md). Native build/install results are recorded below after the final dependency-clean candidate completes.

### Final native candidates

- `flutter build ios --release --no-pub`: passed; signed `build/ios/iphoneos/Runner.app`, 24.9 MB, bundle `dev.kiishi.regun`, version 1.0.0+2. Final candidate installed successfully on the paired iPhone 12 using `devicectl`. Remote launch failed because Apple's Wi-Fi device tunnel timed out; the installed app can be opened on the phone. This is not recorded as a successful launch or performance test.
- `flutter build apk --release --no-pub`: passed; `build/app/outputs/flutter-apk/app-release.apk`, 64.7 MB universal candidate. Local debug signing is retained for private testing. No physical Android was connected, so Android runtime/performance acceptance is open.
- Final dependency resolution removes unused Flame Audio/Supabase native trees, uses Flame Tiled 3.1.1 and splash generator 2.4.8, and retains CocoaPods for SoLoud. The full scene and long-run tests were repeated after the map upgrade.
- Every fusion now has a direct combat integration assertion: burning patches, chain damage, three-mine trail, extra bounces, final-shell damage and three-drone strikes. This extends the existing integration case; suite count stays 58.
- Manifest of on-disk art/audio/font assets and hashes: `ASSET_MANIFEST.csv`. Inherited provenance remains a creator review item rather than an assumed license clearance.

Final package inspection: APK signature verifies as the documented Android Debug certificate; package `dev.kiishi.regun`, versionCode 2 / versionName 1.0.0, min SDK 24 / target SDK 36. Candidate binary hashes are in `validation/candidate-sha256.txt`; analyzer/test/build/soak outputs are retained beside them. `git diff --check` passed. Branch remains `tiles_for_background`; work is uncommitted.

### Starting-screen alignment follow-up

Kept this pass to the starting screen: title and actions share a left edge, all menu buttons share one width, secondary actions form a vertical column, and the menu character is smaller and centered optically beside that column. Other screen layouts and gameplay controls were not changed. Phone-size rendered button/touch check and analyzer passed; signed iOS release build passed. Preview: `build/test-previews/menu-buttons.png`.


### Settings navigation and creator testing handoff

Moved Settings Back out of the scrolling content into a persistent top header. It now remains visible at all scroll positions and pops to the route that opened Settings. A small-phone/150%-text navigation regression verifies that the button stays fixed while scrolling and returns correctly. Full suite: 59 passed (two opt-in soak cases skipped); analyzer clean. Signed iOS release rebuild passed and was installed successfully on the paired iPhone. This update does not claim new physical performance evidence.

The comprehensive creator-facing test inventory, suggested sessions, expected behavior, current shortcomings and improvement priorities are in [REGUN_TESTING_AND_REVIEW.md](REGUN_TESTING_AND_REVIEW.md).


### Contact-death results freeze — reproduced and repaired

Creator report: after three enemy hits, combat stopped, the HUD disappeared and no result actions were visible. Reproduced with real scorpion contact during a full shotgun reload and a working checkpoint/profile store. Health reached zero correctly; the results widget existed but could not be hit-tested. The overlay Stack derived its size from non-positioned children: removing the HUD at game over left a zero-sized save-warning placeholder, so the positioned results filled a zero-sized parent. Earlier screenshot tests had a visible save-warning path that incidentally supplied different Stack layout behavior and hid this defect.

Set the overlay Stack to expand to the game viewport independently of the HUD/warning. The regression now checks visible/hit-testable results after contact death, successful save without a warning, Restart restoring three hearts/five shells and a running engine, a second contact death, Menu returning to its preceding route, and exactly two settled run IDs. Full suite: 60 passed, two opt-in soaks skipped; analyzer clean. The pre-fix failing reproduction is retained in `validation/death-results-reproduced-2026-10-19.txt`. Native rebuild/install results follow after completion; physical retest is still requested.

Death-results fix native verification: both iOS and Android release builds passed. The corrected iOS build installed successfully on the paired physical iPhone after retrying one transient Wi-Fi connection reset. Updated build/test outputs and candidate hashes are retained in `validation/`. Open the installed app and repeat contact death → Restart → contact death → Menu for hands-on confirmation.


## Full active-roster art replacement — 19 October 2026

The rejected Flame soldier and purple grid floor have been retired from runtime and packaged assets. New generated bodies/actions cover all three survivors; separate guns cover four weapons; new sheets cover all eight enemy roles and three bosses. XP, mines, drones and hostile bolts also use the replacement art. Menu/loadout/Collection previews now match. Both arenas have new materials, props, landmarks and depth handling. Shotgun reload timing/Lottie, deliberate upgrade slow motion, functional systems and death/results repair are preserved.

Tiled object groups now supply the shared solid geometry and Foundry vent anchors. Column/boiler footprints were deliberately repositioned; save restoration relocates points inside new solids. Tall scenery fades when obscuring the player.

Validation: clean analyzer; 62 regular tests; 30/60-minute developed-build simulations pass. Shared decoded textures: 29.54 MiB; source assets: 22 textures / 352 frames. iOS release app (63.6 MB) and Android release APK (103.2 MB, local debug signing) built successfully. Native-device render/thermal traces remain open. The install attempt failed with CoreDevice 4016 because the iPhone was unavailable; this art candidate is not confirmed installed.

See [art/ART_OVERHAUL_PROGRESS.md](art/ART_OVERHAUL_PROGRESS.md) for actual in-engine images, exact delivered scope, phone test steps and explicitly remaining art/physical-validation gates. Evidence and hashes are in `docs/validation/art-*`. Source/prompt records are in `art/source/GENERATION_PROMPTS.md`; asset hashes are refreshed in `ASSET_MANIFEST.csv`.


## Animation playback follow-up — 19 October 2026

The creator reported run/step holds across gameplay and rejected a segmented-leg experiment because its proportions/anatomy were wrong. That experiment was removed from runtime and was never installed. The current candidate uses new complete-body survivor loops, shared menu/game timing, phase-preserving facing changes, regular enemy locomotion pacing and correct walking selection for enraged moving bosses. Existing game mechanics/reload/upgrade slow motion remain. Analyzer and 64 regular tests pass; both native release builds succeed. This validates playback/correctness, not perfect source anatomy or physical FPS. See [the animation report](art/ANIMATION_REPAIR_2026-10-19.md) and actual-motion preview for the visual review.

## Enemy personality and crowd steering — 2026-10-19

Added per-enemy stable flank handedness, scorpion/skitter arcs, bounded movement prediction for mummy/burster interception, and revenant distance keeping/strafe with a planted 0.4-second cast. Existing Skitter committed lunge bypasses crowd steering so its warning stays dodgeable. Shield attack/recovery, nests, sentinels and bosses retain their authored roles.

Soft crowd steering uses one immutable spatial-grid snapshot per update, includes stationary enemies as local obstacles, and bounds steering to the existing movement speed. No enemy-to-enemy hard colliders, teleporting or per-enemy full-world scans. Exact overlapping spawn positions separate deterministically; snapshots and side assignments clear on restart. This is local avoidance, not a full obstacle pathfinder: packed corners and fairness remain physical playtest items. Existing checkpoints remain valid; transient approach choices are rebuilt on Continue. Player-facing bestiary descriptions and playtest instructions reflect the changes.

Validation: analyzer clean; 71 tests pass with four opt-in skips, including six new role/spacing/live-scene regressions. The 180-second dense-scene integration reaches the existing 120-enemy cap and passes. iOS release builds. This does not validate native frame times or final combat balance. Evidence: `docs/validation/enemy-tactics-*`.

The combined enemy-personality release was installed successfully on the paired iPhone (`dev.kiishi.regun`), preserving app data. Native balance/comfort/performance approval is still open.

## Menu grid and safe-edge repair — 2026-10-19

The Collection screenshot exposed unequal Wrap card heights, a clipped horizontal tab strip and abrupt scroll edges. Collection now uses content-driven equal-height rows, choosing one/two/three readable columns based on available width and text scaling. All six tabs fit in complete rows rather than cutting off horizontally. Each section gets a fresh scroll position so a long prior section cannot leave the next one apparently blank.

Collection, Loadout and Settings share a pinned Back/header, aligned safe-area margins, an inset vertical scroll viewport with a thin brass thumb, soft continuation edges and enough final padding to fully reveal the last card. Loadout uses the same adaptive section grid; its summary/Start footer stacks on narrow widths. The home screen and gameplay controls are unchanged.

Validation: analyzer clean; 73 tests pass (four opt-in skips). New rendered Collection regression verifies equal row tops/bottoms, fully visible tabs, final-card clearance, pinned Back, tab switching from the bottom, and all six sections. Collection/Loadout/Settings are checked at 568×320, 844×390 and 390×844 with safe insets and both 100%/150% text scaling. Inspected `build/test-previews/collection-alignment.png`. Native comfort acceptance remains open. Evidence: `docs/validation/menu-layout-*`.

The menu-layout iOS release built and installed successfully on the paired iPhone (`dev.kiishi.regun`), preserving app data. Installation is not physical visual/comfort approval.

## Boss threat, pose alignment and Training grouping — 2026-10-19

Player review: bosses were easily kited, Demon locomotion read poorly, Queen attack sprites jumped/clipped, and Training mixed boss names with fusion names.

### Implemented

- Training pause now separates **BOSS PRACTICE** from **FUSION PRACTICE** in aligned action rows. Fusion practice explicitly prompts the player to select the fusion on the next screen. Choosing a practice boss safely replaces the previous boss without awarding kills, XP or a core; owned hazards/projectiles retire with their owner.
- Boss approach speeds and attack frequency increased; short-range attacks are no longer blindly selected against distant targets. Recovery windows remain. Boss health was not increased.
- Demon closes distance with a longer, clearly marked charge when far away; near targets get a cleave or staggered ground slams. Charge damage uses swept collision and deals two damage. Cleaves check their committed half-circle and line of sight at impact.
- Queen keeps brood summons, uses staggered tail strikes and places persistent poison to obstruct the player's projected route. Every marked circle uses the same constrained position/radius as its actual hazard; target/facing lock before the attack. Normal patterns mark two areas; enrage adds a third.
- Shadow has longer committed dashes, faster staggered projectile fans and shorter idle/recovery gaps. Normal fans use two volleys at 500 units/sec; enraged fans use three at 560 units/sec. Far-away targets cause a dash rather than an ineffective close strike. Charges use swept hits and locked facing.
- Attacks have visible windup, impact and recovery with short impact audio/effects. Warnings remain at least 0.7 seconds (Shadow fan) / 0.8 seconds (enraged Demon/Queen); attacks do not home after commitment.
- Boss sprite pivots now follow the lower body instead of moving tails/raised arms. Size is referenced to idle/walk frames rather than attack effects. Queen impact clips omit incomplete final tail/spit cells, and phase clip lengths match attack durations. Idle/recovery no longer holds a distorted final impact cell. Demon walking cadence is a deliberate 0.64-second loop.

### Verification and honest limits

Analyzer clean; **77 tests pass**, four opt-in checks skipped. New live-scene regressions use an actual held touch gesture, assert sustained player displacement and incoming damage during straight retreat, verify a locked warning can be escaped, verify facing remains locked, validate locomotion returns to a looping clip, replace practice targets without rewards, and clean up owner-dead hazards/projectiles. Queen curated poses must retain full body height and omit the incomplete final cells. Existing boss enrage, all loadouts/fusions, Continue, contact-death/results and dense 120-enemy tests remain green.

Native scene captures inspected at `build/test-previews/boss-revised-*.png`; logs under `docs/validation/boss-revisit-*`. iOS release builds. This establishes functional attack coverage, not physical difficulty/fairness acceptance or a native performance trace.

The existing generated Demon walk frames still have weak foot-pose variation. This pass repairs anchor/cadence/phase selection and removes known broken Queen cells; it does not claim hand-cleaned anatomical animation or replace the source PNGs. Final gait quality and attack readability need creator review on the phone. Full obstacle pathfinding and arena-wide encounter balance remain separate acceptance work.

Installation attempted, but CoreDevice returned error 4016 and lists the paired iPhone as unavailable. This revised boss candidate has **not** been installed yet; the last installed release remains on the phone. Unlock/reconnect the device before retrying.

After the user reconnected the device, the revised boss/Training release installed successfully on the paired iPhone (`dev.kiishi.regun`), preserving app data. The earlier installation failure above is superseded. Physical boss fairness, animation approval and performance validation remain open. Evidence: `docs/validation/boss-revisit-ios-install-connected-2026-10-19.txt`.

## Weapon and damage presence — 2026-10-19

Creator explicitly authorized replacing the shotgun Lottie's active presentation with the shared mechanical reload renderer. Shell timing remains unchanged; a closing pump cue is added. Four guns now have distinct visual recoil/flash/trail/impact treatments, legible bodies, weapon-labelled ammo/reload display, and barrel-aligned projectile origins. Primary hits flash the target; player damage has short edge feedback; boss/poison strikes have bounded heavy impact strokes. Reduced Motion softens/disables optional kicks/flash treatments. Existing damage/cadence/magazine/boss stats are unchanged.

A 31-file original local synthesis kit replaces the equipped gun/reload/impact event sounds, with rotating firing variants, quieter impacts and prewarming. External ElevenLabs generation was unavailable (`ELEVENLABS_API_KEY=MISSING`); source, matrix, technical verification and limitations are documented in [the feedback review](art/WEAPON_FEEDBACK_2026-10-19.md). Listening approval is open. This is not a claim of studio sample quality or physical performance validation.

Verification: analyzer clean; 79 tests pass (four opt-in skips); iOS release built and installed successfully on the paired iPhone (`dev.kiishi.regun`), preserving app data. Native feel/listening approval and physical performance remain open. Evidence: `docs/validation/weapon-feedback-*`.


## iPhone layout coverage and installed version label (2026-10-19)

Added the installed app version/build beneath the static home artwork, using Orbitron and muted brass. `package_info_plus` reads native bundle metadata rather than duplicating the pubspec value, so build overrides remain accurate. The art and label share a centered column; art sizing now reserves label clearance and respects both pane width and height. Native release metadata verified as **1.0.0 (3)**.

Added `test/iphone_layout_test.dart`, covering eight landscape logical sizes: 568×320, 667×375, 812×375, 844×390, 852×393, 874×402, 932×430 and 956×440. Home, Collection, Loadout and Settings pass at 100% and 150% text scaling, including loaded home artwork and version label bounds. Gameplay tests cover both left/right notch arrangements, bottom safe insets, large HUD values, a loaded Demon boss, pause menus, and default movement/aim/dash/reload targets of at least 48 logical pixels inside safe edges. The home artwork stays static; dash/reload remain with the aiming thumb.

Analyzer clean; **81 tests pass, four opt-in skips**. Home captures at 844×390 and 956×440 were visually inspected. Signed iOS release built (68.7 MB) and installed successfully on the paired iPhone, preserving its data; installation database sequence 6208. Evidence: `docs/validation/iphone-layout-*`.

Coverage is automated layout validation across compact, standard, Pro and Pro Max proportions. It does not establish frame rate, thermal performance, physical comfort or every possible content/control arrangement on those devices. Physical acceptance remains open beyond the paired iPhone; iPad was not validated in this pass.


## Telling version configuration and update prompt (2026-10-19)

Regun **1.0.0 (4)** now checks Telling release configuration on home entry and home-screen resume. Custom stepped charcoal/brass panels use PressStart2P/Orbitron: optional Update/Later (one-day, exact version/build snooze), or required Update/Check again with no Back/outside dismissal. Live gameplay is never interrupted. Store failures retain the prompt; failed first checks allow offline play within a five-second deadline. Known required prompts stay visible through failed retries until a successful policy response lifts them.

Uses pinned `telling_logger` 1.5.0's isolated version-only helper without initializing telemetry/session/crash collection. Installed metadata includes both native version and build; package_info_plus uses the SDK-compatible 9.x range. Added platform-validated HTTPS store opening and Android release Internet permission. The supplied project key is embedded through ignored local build defines and was verified in both compiled candidates. Live iOS 1.0.0 build 4 currently returns `requiresUpdate:false`; no dashboard policy was changed. A real Apple listing URL remains necessary before enabling an update requirement.

Analyzer clean; **87 tests pass, four opt-in skips**, including optional/required decisions, snooze targets, forced override, unavailable/malformed configuration, launch failure, Back blocking, policy withdrawal, offline startup and compact/Max landscape layout at enlarged text. The required panel was rendered and visually inspected. Signed App Store IPA signature/profile verified; iOS release installed over the existing app on the paired iPhone (installation sequence 6216), preserving data. Real dashboard-to-store navigation and physical acceptance remain open.

Configuration, build commands and phone test steps: [UPDATE_CONFIGURATION.md](UPDATE_CONFIGURATION.md). Evidence: `docs/validation/update-*`.


## Forced-update missing-link regression (2026-10-19)

Live Telling response for iOS 1.0.0 builds 3 and 4 now requires minimum build 5 (`decisionSource: build`), with `isRequired: true` and an empty store URL. The installed metadata was correct. Our validation incorrectly treated an unusable store action as an unusable update decision and silently suppressed the prompt. Removed that coupling: required policies return immediately, ignoring snoozes and independent of preferences/store URL availability. Missing links show the required panel with a disabled Update action and a brief message; Check again fetches the corrected link or policy withdrawal. Invalid URLs still cannot be opened. Also prevented a pending Later save from dismissing a subsequently replaced policy.

Analyzer clean; **88 tests pass**, four opt-in skips. Regression checks cover the actual minimum-build-5 / empty-link response, forced Back blocking, disabled Update and recovery when the listing URL is configured. Test candidate retains build 4 deliberately to remain below the dashboard's build-5 threshold. The project key and dashboard policy were not changed.

Corrected App Store IPA rebuilt and signature/profile verified. Device release installed successfully over existing data (installation sequence 6224). The IPA and device candidate both retain 1.0.0 (4) for the below-build-5 test. Actual on-screen confirmation remains with the phone playtest.


## Starting-health balance adjustment

Raised baseline starting health and maximum health from three to six for Rook and Scrapper. Warden starts at seven, preserving its extra-heart passive. New runs and restarts use the new values; existing saved runs keep their recorded health and capacity. Health upgrades and healing still respect the run's maximum. Updated damage/death/restart expectations and playtest survivor descriptions.

Follow-up balance adjustment: Warden now starts with eight hearts (two above the six-heart baseline); updated its loadout description and playtest guide.

Carbine balance adjustment: base damage increased by 27%, from 0.6 to 0.762. Cadence, magazine capacity, reload duration and other weapon stats are unchanged.


## TestFlight update destination support

The configured live destination is an official TestFlight invitation, `https://testflight.apple.com/join/96knrEeD`. The original store-listing-only allowlist rejected it. iOS now accepts official HTTPS TestFlight join URLs with eight-character alphanumeric invite codes, as well as App Store listings. Android remains restricted to its Play listing; malformed/lookalike/insecure invitations cannot open. Required-update decisions remain independent of URL availability.

Analyzer clean; **90 tests pass**, four opt-in skips. Added URL-opening and live-policy-shaped UI regressions proving the TestFlight link enables Update instead of displaying link-unavailable feedback. Release candidate increments to 1.0.0 (6); the direct phone test build deliberately overrides its build to 4 so the existing minimum-build-5 policy can be exercised. No dashboard policy was changed.

App Store IPA 1.0.0 (6) rebuilt and signing/profile verified. Corrected phone test release 1.0.0 (4) installed over existing data (installation sequence 6264), with the same project key embedded. Update-button visibility/opening is covered by native-widget/adapter tests; actual TestFlight navigation on the physical phone remains for user confirmation. Older installed beta binaries need the corrected build from TestFlight; remote URL edits do not replace their validator code.

## First-run Training briefing

Checkpointed the existing full game as `2dc4252` before this change. First Play now opens Training with a charcoal/brass field briefing over the paused arena. It names Training mode, briefly describes the controls to practise, and offers Start training / Skip training. Start resumes the existing guided steps; Skip records the existing tutorial completion/unlock and replaces Training with the normal loadout screen. Later Play visits respect that choice. Explicit practice sessions and normal runs retain their existing entry flow.

Added regression coverage for actual Menu → first Play, paused clocks, Start, Skip → normal loadout → Back → Play, and compact landscape/enlarged-text layouts. Rendered and inspected the in-game briefing at `build/test-previews/training-intro-ingame.png`.

`make verify`: clean analyzer, 93 tests passed, four opt-in checks skipped.

At the creator's request, `make runRelease DEVICE=00008101-000248EC1450001E` built, signed, installed and launched the release on the paired iPhone over Wi-Fi. This preserves existing player data; the introduction appears on first Play for profiles that have not completed/skipped Training. Native comfort/performance acceptance remains open.

## Field Medic healing frequency

Player feedback: heart recovery from kills was too rare. The creator rejected the initial fourfold buff and chose twice the original rate. Field Medic is now 5% per rank, increased from 2.5%: ranks 1/2/3 have 5%/10%/15% chance on each kill to recover one heart. The upgrade description states the per-rank odds. Healing remains capped at maximum health; it remains a random chance rather than a guaranteed kill interval. Existing saved upgrade ranks use the improved odds automatically.

Live-scene regression cases cover all three ranks, kills without the upgrade, successful/failed rolls, secondary-damage kills, exactly-once kill/heal handling and the health cap. Physical balance approval remains open.

The selected 2× healing release built, installed and launched successfully on the paired iPhone over Wi-Fi. Analyzer clean; 93 regular tests passed before the shield investigation below.

## Scrap Armour investigation

A player mentioned possible missed shield absorption, without reproducible steps. Added tests of actual Scrap Armour acquisition at each rank, full absorption of two-heart hits, simultaneous-hit protection, recharge at 17/14/11 active seconds and paused recharge clocks. Added live collision checks for scorpion contact, revenant shots, Shadow bolts and a two-damage ground strike: each consumes the shield without losing hearts or showing health-loss feedback.

These cases pass; a shield bypass has not been reproduced. Shield gameplay remains unchanged. One shield blocks one accepted hit, followed by the existing 500 ms damage protection; it does not protect for the entire recharge period. Keep the phone report open until a specific scenario can be captured rather than treating passing automated cases as proof against it.

## Crowd bodies and population-aware pressure

Players reported tightly overlapping moving groups, including discomfort from the clustered appearance. The creator requires enemies to respect each other's space and a challenging arena that is not filled indiscriminately. A sustained-pursuit regression reproduced the old compression (median nearest spacing about 50.7 world units for 85-unit components).

- Soft separation now starts at body-sized distances, with symmetric pair variation instead of one uniform gap.
- `CrowdOccupancy` adds a live spatial index: accepted movement immediately reserves body space, stationary enemies remain obstacles, ordinary pursuit slides around bodies, and substepped committed moves stop rather than cross enemies. Player movement/collision rules are preserved. Boss movement uses the same occupancy and normal enemies yield early around their approach.
- Pending arrivals reserve free, wall-valid space before the warning appears; relocation retains safe player distance. Old overlapping checkpoint populations are spread on mount. Bounded search failure skips a new spawn rather than stacking it. Restart/removal clears reservations.
- The director's progressive arena target is 20 → 60; visible reinforcement thresholds are 18 → 44. Counts include pending arrivals and the active boss. Both director spawns and summoned adds respect the gates; boss encounters retain their separate slot. Existing crowds are not culled or blocked by a viewport wall. No deferred spawn burst accumulates. The old 120-enemy constant remains a runtime safety cap.
- Damage, health, movement-speed stats, weapon balance, role unlocks, elite/cycle scaling, boss telegraphs and phase timing are unchanged. Reduced body density is a balance change: maintaining strong challenge alongside readable movement requires physical playtesting, not a claim based on the limits alone.

Regression coverage includes a 40-enemy live pursuit with pairwise body-separation checks, stationary blockers, fast committed movement, pending arrivals, full old-save populations, player-safe relocation, population gates and boss threat. Inspected `build/test-previews/crowd-spacing.png`. Physical motion comfort, packed corner behaviour, boss fairness and difficulty remain open.

Verification: analyzer clean; 106 regular tests pass (four opt-in checks skipped). Both explicit soaks pass. The 30-minute simulation peaks at 60 normal enemies / 30 visible / 202 world children, with 8 bosses defeated; the 60-minute simulation peaks at 60 normal enemies / 25 visible / 267 world children, with 16 bosses defeated. These developed builds receive extra health and are lifecycle/population evidence, not physical difficulty or FPS measurements. Logs: `docs/validation/crowd-verify-2026-10-19.txt` and `docs/validation/crowd-soak-2026-10-19.txt`.

The signed iOS release built, installed and launched on the paired iPhone over Wi-Fi, preserving player data. Evidence: `docs/validation/crowd-ios-install-2026-10-19.txt`. Native crowd readability, comfort, difficulty and performance remain for hands-on approval.

## Five-boss expansion planning

The creator's long-term direction is fifteen bosses, with this next batch scoped to five additions. [REGUN_BOSS_EXPANSION_PLAN.md](REGUN_BOSS_EXPANSION_PLAN.md) proposes Bellkeeper, Chain Magistrate, Mirror Saint, Kiln Sovereign and Last Marshal: five distinct encounter tests, their art/presentation, counterplay, phase changes and implementation gates. It also covers a focused improvement pass on the existing three, a compatible encounter/save refactor and later authored two-boss experiments for co-op. This is a design plan, not implemented content or a multiplayer/balance acceptance claim. No gameplay or installed build changes were made for this planning request.


## Eight-boss expansion and randomized Training Boss Rush — 19 October 2026

Checkpoint `dcecbfc` commits the prior onboarding, Field Medic 2×, shield checks, crowd coordination and five-boss plan before this implementation. The live roster is now **eight**, with fifteen remaining the longer-term target.

- Five distinct controllers: Bellkeeper (gapped waves/echo and clapper), Chain Magistrate (sequential chains/sweeps), Mirror Saint (recorded route/reflected path/projection), Kiln Sovereign (pressure zones/foot/furnace sweep), Last Marshal (committed shots/front brace/deployed returning blade). Half-health phases and optional targetable apparatus interruptions create longer 1.5× damage openings. Adds and warnings retain shared population/effect limits.
- Normal encounters randomize **all eight from the first encounter** in a saved shuffle bag, with no immediate repeat across bags. No fixed Shadow → Demon → Queen introduction remains. Existing unlock challenges still require their named boss. The request cadence and single-boss normal encounters remain.
- Training → Pause → Random Boss Rush starts repeated complete fights; 40% of rounds request a distinct pair. A new round waits for both deaths and a short break, refills ammo/health and retains the build. Next round skips; Restart restarts the rush. Training protects health and excludes ordinary rewards. Individual boss and fusion practice remain available.
- Actor IDs and per-boss health-loss accounting replace assumptions that one actor is the entire encounter. Major attacks alternate between partners and wait for owned lingering ground effects/Shadow bolts. Killing one boss clears its attacks without erasing the survivor. Checkpoints write schema 2 and accept schema 1; pair health restores paused with transient attacks discarded.
- Warning and damage share committed shape geometry. Escape checks consider simultaneous activation windows rather than treating delayed echoes as simultaneous walls. Attack ownership, eight-hazard cap, clipped paths and connected floor/body checks bound the patterns; these checks support fairness review but cannot prove human difficulty.
- Five original generated 40-pose transparent atlases and fifteen original synthesized warning/hit/break cues are integrated. Measured atlas crops/pivots, planted warnings, short impacts, living poses during lingering attacks, recovery and death are wired explicitly. Leased lazy atlases release on death, exit and restart; a pair stays below the 32 MiB decoded-art ceiling in the lifecycle test. Prompt/source/hash records are included. Visual and listening approval remain open on hardware.

Validation: `make verify` passed analyzer and **115 tests**, with four opt-in cases skipped. Tests cover all five additions across four weapons × three survivors × two arenas, all 28 distinct pairs in both arenas, both phases, random first-boss coverage, saved rotation, piercing part/body deduplication, guarded/unguarded strike timing, paused attacks, interruptions, death cleanup, twelve randomized rush rounds, texture leases and damaged pair restore. Rendered phone-size scenes were inspected. Straight-retreat legacy testing now isolates random adds so a body obstructing the test lane cannot make its result random; crowd interactions retain separate scene coverage.

The 30/60-minute developed-build simulations passed again with the full randomized rotation (5/13 bosses, peak 60 enemies, at most 7/8 hazards, final 163/156 children). A subsequent presentation correction gives each delayed strike/echo a fresh short release pose rather than letting the body idle through the combo. Build version is **1.0.0+7**. Simulations and installation do not prove physical animation comfort, balance, FPS or thermal behavior; use the updated Boss Rush playtest notes.

Final native verification: signed iOS release **1.0.0+7** completed its Xcode build, installed and launched on Kiishi David’s iPhone (`00008101-000248EC1450001E`). The runner exited successfully with `--no-resident`, leaving the app on the phone. The final presentation correction passed analyzer and all **115 tests** before this installation. `git diff --check` passed. Physical boss fairness, motion comfort and performance approval remain open.

## Combat materials, Arc Caster and open-arena boss pressure — 20 October 2026

Player feedback rejected diagram-like lines and generic circle attack warnings, especially Mirror Saint and Chain Magistrate. The creator also identified the large arena as a source of weak boss pressure and requested stronger coverage without boxing the player into a smaller arena.

- Shared `AttackVfx` now draws textured stone ruptures, shattered glass, iron links/barbed anchors, furnace debris and acidic ground. The pass covers all eight bosses, regular enemy warnings, ground hazards, explosions, burning ground, arrivals and supporting hit/guard effects. A new transparent 24-sprite material atlas was generated with built-in imagegen and copied unchanged; source prompt, hashes and measured frame metadata are recorded. Floor effects draw beneath actors. Warnings and damage share committed geometry; circle outlines and plain attack lines are replaced with material footprints, moving debris and physical apparatus.
- Mirror Saint intercepts the projected route with Shatterwake, staggered crossfire and a false-body combo. Chain Magistrate sends sequential anchors through the predicted route and a weighted chain sweep. Both recover faster; mirrors/clasps remain interrupt targets. Saint's base health is 300. Recorded paths skip duplicate points so a stationary route cannot consume the attack with a zero-length segment.
- Arc Caster now has six charges, three base damage, .75-second cadence, 560 range and 1050 projectile speed. Two innate jumps retain 85% damage per hop across 240 units; walls block chains and secondary damage cannot recursively chain. Recharge stays 2.4 seconds. Recoil, flash, impacts and four synthesized shot/impact files reinforce the discharge. Checkpoint weapon-balance migration applies the new base magazine/range/speed once while preserving upgrade ranks and recharge state.
- All eight boss bodies grow modestly, with matching hitboxes and crowd occupancy. No root transform scales attack coordinates. The arena is unchanged. Shadow fans travel at 950/1150 with 3200 range and longer charges; Demon gains broader cleaves/strikes and longer charges; Queen gains wider poison/tail coverage and a targeted brood eruption. Bellkeeper waves reach up to 3400 at 1200/1450 speed with a 57° gap, and clapper covers 540 units across 212°. Magistrate chains extend farther; Saint glass widens; Sovereign eruptions/breath cover more ground; Marshal shots/blades extend beyond the predicted route. Shorter recovery/pursuit reduces idle chase time. Large rotating sweeps include a close inside pocket; warnings clip that pocket too. Bellkeeper wave warnings mark a fixed projected crossing near the player so a distant outer radius cannot hide the warning. Existing major-attack coordination, body occupancy and population/effect limits remain.
- Faster Shadow bolts use swept player contact with wall checks to avoid tunnelling through a player on a slower frame. Guard absorption remains exactly once.

Regression coverage adds real Arc projectile/jump damage, attenuation, blocked chains, old-save migration, Saint/Magistrate retreat versus warning-time sidesteps, all eight bosses threatening normal-health long-distance retreat in both phases, inside-pocket geometry and fast-bolt/guard contact. Existing loadout/arena matrices, all 28 boss pairs and texture lifecycle checks remain. Captured warning/release scenes for the material pass were visually inspected. Native fairness, comfort, listening, frame time and thermal acceptance remain open; simulation and installation cannot establish them.

Final validation: `make verify` passed the analyzer and **124 tests**, with four opt-in cases skipped. Both explicit soaks passed: 30/60 simulated minutes defeated 8/14 bosses, peaked at 60 normal enemies and 8 hazards, with 203/259 peak world children and 156/185 retained. Signed iOS release **1.0.0+9** built in 20.2 seconds, installed and launched on the paired iPhone; `--no-resident` exited successfully and the built Info.plist reports version 9. Logs: `docs/validation/combat-pressure-verify-2026-10-20.txt`, `docs/validation/combat-pressure-soak-2026-10-20.txt`, and `docs/validation/combat-pressure-ios-install-2026-10-20.txt`. Use Training → Pause → Random Boss Rush to review the full roster and occasional pairs.

## Player deployment, training damage and grounded bosses — 20 October 2026

The creator requested optional damage in training, center respawn with a paced animated camera/player sequence, and reuse of the entrance for fresh runs. A later correction requested better integration of boss/attack sprites into the environment.

- Training pause adds a custom pixel **Take damage — Off / On** selector. Off is the default for a new visit; selection survives Restart and Boss Rush within the visit. Turning it Off restores practice health. Training still excludes normal progression rewards.
- Lethal training damage remains outside game-over/settlement. `PlayerEntrance` freezes combat and uses the same simulation clock as the game: a .5-second fallen-pose fade, a 1-second eased camera return to the arena center, a brief ground cue, a .55-second descent/landing and .45-second recovery. Dust/scuffs, a brace pose and a subdued landing cue use existing assets. The body is invisible during camera travel; it appears through the entrance at the destination rather than visibly teleporting. Bosses, hazards, build and encounter health persist. Completion refills health/ammo and grants two seconds of protection. Input, reload/dash and damage are gated throughout.
- Fresh starts/restarts use the same landing entrance without death/recentering (1.2 seconds). Continue retains the saved position and paused restoration without replaying deployment. Pause/background freezes the sequence. Reduced Motion removes pan/descent and conceals camera relocation under a brief charcoal fade.
- All boss bodies receive restrained ambient lighting matching crypt/foundry and layered foot contact shadows. Stone, glass and chain material sprites have a subdued ambient grade; hot furnace releases keep their emission. Floor attack/area components now use priority -10, so their presentation stays beneath actors even in negative world coordinates. Attack geometry/timing and boss stats are unchanged in this pass.
- Combat fixture setup advances the real initial entrance before unrelated gameplay assertions. Dedicated live-scene coverage exercises the default protection/toggle, initial descent, lethal off-center damage, intermediate camera positions, preserved/frozen boss and director, pause, landing, refill/protection, restart, Reduced Motion and normal game-over behavior. Rendered deployment, recovery, settings and boss material scenes were inspected. Phone pacing, sound, readability and performance remain physical acceptance items.

Validation: analyzer clean, **126 tests passed**, four opt-in cases skipped. Explicit 30/60-minute simulations passed with 8/14 bosses, peak 60 normal enemies, 7/8 hazards, 197/274 peak world children and 160/157 retained. Final signed iOS build **1.0.0+10** built in 15.8 seconds and installed/launched on the paired iPhone in 8.6 seconds; the runner exited successfully and the built Info.plist reports 10. Logs: `docs/validation/entrance-verify-2026-10-20.txt`, `docs/validation/entrance-soak-2026-10-20.txt` and `docs/validation/entrance-ios-install-2026-10-20.txt`. These are automated/lifecycle and installation evidence, not physical animation/balance/performance approval.

## All-weapon punch and restrained enemy impact — 20 October 2026

The creator requested bigger, more substantial rounds and hits that visibly slap, across Shotgun, Carbine, Revolver and Arc Caster, without a damage buff. They also reiterated that electrical strikes must fit the game's art style.

- Draw footprints increase independently from collision geometry: Shotgun 15×8, Carbine 13×5, Revolver 15×6 world units. Stepped brass casings, shaded undersides, a narrow hot core and thicker trails replace tiny white dashes. All four get stronger weapon-specific recoil/muzzle flashes and impact sizes. Arc uses thicker irregular pixel arcs, muted oxidized-metal tones, small forks and a textured ground scuff; its extra clean arrow/zigzag overlay is removed. Existing hit-effect caps and Reduced Motion remain.
- Accepted primary bullet hits request a short front-loaded, decaying shove (Shotgun 13 units/.09s, Carbine 5/.06s, Revolver 16/.1s, Arc 8/.075s) and brief stride reduction. A .24-second per-target cooldown prevents stacking shotgun pellets or pinning with rapid-fire upgrades. Mummies, elites and Wardens resist; bosses and stationary roles remain planted so telegraphs and attack geometry stay valid. Movement uses actor-based occupancy/wall-constrained `moveTo`, with no body crossing or accumulated deferred shove. Secondary chain/burn/drone hits do not trigger it. This is a small control/balance change despite unchanged damage, requiring physical testing.
- Damage, cadence, reloads, ranges, projectile speeds and hitboxes remain unchanged. A hit-flash reset bug that cleared boss arena grading is corrected: the cached crypt/foundry ambient filter returns after each flash.
- Regression coverage exercises actual projectile identity/audio/once-only hits for all weapons, unchanged direct damage, early shove, response cooldown/recovery, armour/stationary/boss resistance, blocked bodies and walls. Updated arena screenshots and the weapon sheet were inspected for art/readability. Final physical punch, comfort and difficulty remain open.

Validation: analyzer clean; **127 tests passed**, four opt-in cases skipped. Both explicit simulations passed: 30/60 minutes defeated 8/12 bosses, peaked at 60 normal enemies and 8 hazards, with 200/264 peak world children and 187/186 retained. Signed iOS release **1.0.0+11** built in 20.9 seconds, installed/launched on the paired iPhone in 9.2 seconds, and exited successfully with `--no-resident`; built Info.plist reports 11. Logs: `docs/validation/weapon-impact-verify-2026-10-20.txt`, `docs/validation/weapon-impact-soak-2026-10-20.txt`, `docs/validation/weapon-impact-ios-install-2026-10-20.txt`. These results do not establish physical weapon feel, native FPS or final balance.

## Eight-rank progression and immediate magazine pickup — 20 October 2026

The creator requested a clearer, short magazine-refill presentation, relief from longer shotgun reloads after capacity upgrades, and eight ranks of power-ups. They asked for rewarding later ranks with limited reload acceleration, then explicitly requested a slightly stronger late-rank curve.

- All thirty offered upgrade families reach VIII; stale offers cannot grant IX. Existing I–III stat gains stay intact. IV–VIII scalar gains use 30% of an early rank per pick (VIII = 4.5 effective ranks); reload and dash cooldown use a tighter 20% tail. Magazine, movement, range, Heavy Load and projectile speed use explicit smaller late increments. Scattershot holds its III projectile count and improves spread precision by 4% per later rank. Afterimage adds 15ms protection per extra rank. Count-based pierce/bounce/chain/shard upgrades grow under existing runtime budgets; bounced projectile damage caps at 2× initial damage. Fusions still require III/II and six special slots remain.
- Late-rank bounds include 850ms shotgun Sleight of Hand (III remains 1000ms), about 41% of normal duration for the other reloads, .6s dash cooldown, 6.5s guard recharge, 22.5% healing chance and 54% conditional Static Charge chance. No probability exceeds certainty or recharge becomes negative. The first three Field Medic ranks retain 5%/10%/15%.
- Extended Tube already changed ammo immediately when selected. Its presentation now makes that explicit: cancel the current reload, fill the new capacity, show a non-blocking 320ms mechanical snap and MAG READY cue in HUD and world weapon. Pause freezes it; firing, manual reload and restart cancel it; Reduced Motion holds the ready pose. HUD listens to the inner run provider, with all four rendered pickup scenes inspected. The card states “Larger mag. Refill now. Same reload time.”
- Upgraded shotgun magazines cap future normal reload duration at the original five-round timing (3700ms), so 5→7 does not add 1400ms. Base/partial shotgun timing is preserved; Sleight remains a separate capped improvement. The refill applies on acquiring the upgrade, not on every empty magazine without a reload.
- Regression coverage grants every family I–VIII, validates ongoing offers and VIII exclusion, rejects IX, round-trips saved ranks, tests refill/cancellation/pause/firing, all four VIII reloads, guard bounds and unchanged original shell timings. Developed-build simulations now equip VIII utility/core and six VIII special upgrades to exercise the stronger combinations. Physical progression, comfort, readability and difficulty still require hands-on acceptance.

## XP pacing and removal of unfunded upgrade screens — 20 October 2026

The creator clarified the extra-upgrade complaint: a second power-up screen could appear without the XP bar earning another level. They also rejected the old tiny opening costs and explicitly requested online research and much faster cost growth. Research and the chosen curve are documented in `docs/XP_PROGRESSION.md`, with Vampire Survivors/Brotato community references and Regun's actual enemy XP rewards.

`XPProgression.cost` now gives per-level requirements **25, 50, 80, 115, 155, 200**, reaching 430 at run level 10 and 1355 at level 20. XP drops are unchanged. Normal upgrades require funded XP; selecting a card or fusion no longer opens a chained picker. Overflow is retained, with four active seconds of prompt grace and a subsequent XP pickup required before another earned choice. Old runs preserve bar progress once under checkpoint `xpCurve:2` and retain saved grace.

The unrelated ordinary cards came from the boss-core fallback. That fallback is removed. Cores now bank until ingredients are ready and the player explicitly chooses **Fuse core** from HUD/pause; only real fusion recipes appear. Two cores are banked for two fusion slots; surplus core rewards give five scrap without another screen. Training Fusion Practice still opens its requested recipe directly.

Final +12 validation: analyzer clean; **132 tests passed**, four opt-in cases skipped. New tests cover accelerated thresholds, one funded offer, no automatic chained cards, retained XP, pause/grace, explicit cores/fusions and once-only save migration. Both VIII-developed-build soaks passed: 30/60 simulated minutes defeated 8/16 bosses, peak 60 normal enemies, 6/8 hazards, 207/298 peak world children and 132/212 retained. Signed iOS **1.0.0+12** built in 21.0 seconds (87.0 MB); Info.plist reports 12. **Installation was deferred at the creator's request**. Logs: `docs/validation/progression-verify-2026-10-20.txt`, `docs/validation/progression-soak-2026-10-20.txt`, `docs/validation/progression-ios-build-2026-10-20.txt`. Simulations use prepared builds and do not establish normal upgrade pacing, native FPS or final physical balance.

## Release number correction — 20 October 2026

The creator corrected the intended release identity to **1.0.0+7** and explicitly requested release installation and a link to the exported IPA. `pubspec.yaml` now uses 1.0.0+7. Earlier +8 through +12 entries above are historical development-candidate records; all completed gameplay/progression changes remain in this corrected release. No gameplay changes are part of this version-only correction.

## Rifle grouping, shotgun weight, audio and opening progression — release 1.0.0+7

The creator clarified that the shotgun needs weight rather than more pellets. It retains its original three-pellet pattern and straight center round. Pellet art grows from 15×8 to 22×11, with wider trails/impact debris. Surviving susceptible enemies receive a real 34-unit shove before mass resistance over .12s (previously 13/.09); the .24s target cooldown prevents pellet stacking or continuous stunlock. Bosses/planted enemies retain resistance, and shoves respect bodies and walls. Regression checks verify surviving-enemy displacement, health, recovery and obstruction safety.

Carbine rounds vary by at most ±2° with small independent lateral/longitudinal muzzle offsets, then travel straight. Damage, cadence, range/speed, ammo and reload timing remain unchanged. Tests check bounded differing origins/headings, straight flight, ammo expenditure and centered shotgun spread.

Opening progression now costs 8,18,35,59,90,128,… XP, with increasingly large later increments; the earlier 25-XP opening was too slow. Marker `xpCurve:3` migrates old bar fractions once, including previous marker-2 saves. Funded ordinary choices, four active seconds of prompt grace and explicit fusion remain. See `XP_PROGRESSION.md`.

Combat sound replaces the thin noise-heavy report with recorded CC0 transients, pressure/contact layers, short low-mid harmonics and restrained upper-frequency ringing. Twelve firing variants, eight shared/weapon impacts and fifteen boss cues are revised; existing reload mechanisms receive clean end fades. Source recordings, authors/license/hashes are retained outside packaged assets. See `art/source/audio/README.md`, `docs/art/COMBAT_AUDIO_REVIEW.md` and manifests. The provider probe returned `ELEVENLABS_API_KEY=MISSING`; no provider generation is claimed. Thirty-five combat files pass format/DC/headroom/end-fade checks; a representative SFX-only rifle/paired-boss mix peaks at .707. This is not subjective listening approval.

Final validation: analyzer clean; **132 tests passed**, four opt-in cases skipped; both 30/60-minute prepared-build soaks passed. Final archive/export completed in 31.2/26.0 seconds; the App Store-signed IPA reports **1.0.0+7**. Latest release installed and launched on the paired iPhone (24.1s build, 4.3s install/launch). Export: `build/releases/Regun-1.0.0+7.ipa`. Evidence and SHA-256: `docs/validation/combat-release7-2026-10-20.txt`. Physical audio/feel, performance and balance remain for hands-on review.

## Laptop SDK, SoLoud silence correction and Rook launcher — 20 October 2026

At the creator's request the main laptop Flutter SDK was upgraded from 3.44.8/Dart 3.12.2 to **Flutter 3.47.7 / Dart 3.13.5 stable**. Existing SDK edits were preserved in its Git stash. SoLoud is pinned to **5.2.1**, with Dart native build hooks and updated playback return types. The original SDK's meta pin prevented this upgrade; no SDK dependency override was introduced. Flutter and Xcode pass doctor; Android license acceptance remains pending, and engine artifacts fetch as needed.

Audio was not removed. The app was missing explicit iOS session ownership, while SoLoud deliberately leaves that to the application. Native startup now configures/activates a mixed playback session and restores it on foreground/resumable interruptions/media-service reset. Dart explicitly starts the device, observes automatic output-start failures and requests idempotent foreground recovery without resetting audio assets or unpausing a paused match. The web SoLoud loader is included. Saved phone preferences were not muted; native logs report media volume .70.

On the paired iPhone, the production audio manager produced menu RMS .00684, Shotgun .03209, Carbine .01908, Revolver .03009 and Arc .04183; muted SFX measured exactly zero. The test uses the actual native decoder/mixer. VM-service discovery stalled, so the test exported its result file from the app container instead. Native XCTest launch/foreground session checks both passed. This establishes active native audio output, not subjective listening quality or full real-call/route acceptance. Details: `docs/AUDIO_RUNTIME.md` and `docs/validation/soloud521-iphone-mixer-2026-10-20.json`.

Rook's head, based on the actual front-facing sprite, now supplies the launcher icon and native/Flutter startup splash. It retains the dark helmet, cyan visor and ochre scarf on a restrained quarantine-green/charcoal background. Apple/Android primary guidance informed centered placement, opaque unmasked iOS export and Android adaptive/splash safe areas. The generator now uses 0.14.4 to apply a measured 3% adaptive inset. Critical adaptive radius .2926 fits .3056; Android 12 radius .3114 fits 1/3; iOS store icon is opaque RGB 1024×1024. The old arrow/engine-logo interstitial is replaced by one Rook mark, no forced timer, a short reduced-motion-aware menu transition, and no remaining startup route behind Menu. See `docs/ROOK_BRANDING.md`.

Final checks: analyzer clean; 132 game tests plus the new startup-route test passed, with the four opt-in cases left skipped. Both native session tests and the phone mixer/mute check passed. The regular `lib/main.dart` release was archived/exported in 66.3/28.3s, then installed and launched on the paired iPhone (23.9s build, 31.7s installation). App Store IPA reports **1.0.0+7**, contains both SoLoud wrapper/engine frameworks and uses a store provisioning profile with debugging disabled. Export: `build/releases/Regun-1.0.0+7.ipa`. Physical icon appearance, launch transitions, sound quality and performance remain hands-on acceptance items.

## Damage readability — 20 October 2026

Health loss now combines one light haptic with a 320ms survivor hit cue (70ms pale accent, then warm tint), a 500ms stepped edge frame and a fixed-space health readout showing the actual loss. The camera stays steady. Existing Haptics settings apply; Reduced Motion omits the pale flash and softens the edge treatment. Shield absorption, deployment protection and contact cooldown do not emit health-loss feedback. Pause preserves the cue; restart and training recovery clear it. The HUD's new readout scales within its reserved bounds for large text. Damage, immunity timing, movement and aiming are unchanged. Release identity stays 1.0.0+7.

Validation: analyzer clean, **134 tests passed** (four opt-in cases skipped), including health-loss/haptic gating, multi-point hits, pause/reset and the phone safe-area/large-text matrix. Reviewed the 844×390 render. Final release archive/export completed in 26.3/26.1s; installed and launched on the paired iPhone (20.8s build, 7.3s installation). Updated `build/releases/Regun-1.0.0+7.ipa`; checksum/details in `docs/validation/damage-feedback-release7-2026-10-20.json`. Physical vibration strength and combat readability remain for hands-on review.

Heart-sprite follow-up: the creator requested `−1` followed by the existing pixel heart instead of `−1 HP`. The loss cue now uses the actual `heart.png` sprite with nearest-neighbor sampling; two-point hits display `−2` plus the same heart. Analyzer and all six targeted damage/phone-layout tests pass, including large text. Reviewed the updated 844×390 render; refreshed the version-7 release IPA.
Installed and launched the heart-sprite follow-up on the paired iPhone (17.8s build, 7.4s installation).

## Recorded reloads and sharper weapon motion — 20 October 2026

The creator found the reloads shrill/repetitive and weapon motion sluggish. Eleven reload cues now use processed CC0 recorded mechanism extracts, with bounded peaks, lower pitch, high-frequency damping and SFX gain .32 (previously .42). Shotgun shell insertion/pump and Carbine magazine-out/seat/bolt have separate material identities. Source licenses/hashes, reproducible processing, format/mix checks and a listening reel are documented in `docs/art/COMBAT_AUDIO_REVIEW.md` and `art/source/audio/README.md`. Existing firing/impact/music/UI assets stay unchanged.

Recoil recovery is .14/.07/.19/.18s for Shotgun/Carbine/Revolver/Arc (about 17–18% shorter); the 45ms muzzle cue remains visible independently of recovery length. Reloads use quick eased actions into holds and decisive seating at existing sound phases, instead of continuously drifting parts. Shotgun shell movement takes 210ms inside its unchanged 700ms step. Reduced Motion keeps reload parts/body planted. Total reload duration, firing cadence, projectile/damage behavior and the original shotgun HUD Lottie are preserved. Analyzer and all 134 tests pass (four opt-in cases skipped); eleven reload WAVs pass format/DC/endpoint/peak/upper-band checks. Physical sound/feel acceptance remains open.

Creator clarification: Carbine must swap a whole magazine. A dedicated regression verifies both a one-round top-up and an empty magazine: no intermediate ammo refill, fixed 1800ms base reload, exactly magazine-out/seat/bolt cues and zero shotgun shell sounds. Final analyzer/full suite: **135 tests passed**, four opt-in cases skipped. Release archive/export 24.4/25.3s; installed/launched on the paired iPhone (19.1s build, 12.6s installation). Latest version-7 IPA and hashes are recorded in `docs/validation/reload-motion-release7-2026-10-20.json`.

## Coffee-pass combat corrections and arsenal proposal — 20 October 2026

Skitter's old lunge covered only 105 units (350 × .3s). It now commits from up to 620 units away, travels 240–680 units at a base 1050 speed and retains its .55s warning and .8s recovery. Each commitment has a 60% direct-target / 40% bounded prediction choice (maximum 200-unit lead). Heading locks before the warning; no homing after a player turn. Duration accounts for cycle/elite speed so movement cannot exceed the warned length. A small sprite lift leaves its shadow grounded; Reduced Motion stays planted. Occupancy/walls still block movement. Swept player contact prevents a long/coarse step from skipping damage.

The creator clarified that Magistrate chains must concentrate toward the player, rather than surround the boss with mostly irrelevant off-screen spokes. The final kit is **five forward chains, seven when enraged**, each a single straight boss-centered ray. A center lane predicts the route; outer lanes form a varied forward fan, with bounded spacing/length jitter and simultaneous or staggered release order. No endpoint branches, cross-links, circles or old sweep follow-up. Shared textured iron/anchor VFX remain authoritative. Rays shorten at walls/columns without bending. Narrower lanes preserve reachable gaps as count rises; warnings remain planted. Existing attack ownership, exposed clasps and impact/recovery poses remain. A capacity precheck stages the whole volley or waits for floor hazards to expire, instead of silently dropping chains under the eight-hazard cap.

Main mine/Burster explosions now use a reusable `AttackVfx.explosion` path with the same ember atlas: arena ambient grading, a flattened floor scorch/contact base, sparse debris, a planted plume and a .42s fade. They draw below actors and keep the player silhouette readable. Reduced Motion uses a restrained fixed plume pose and fade. Explosion radius/damage are unchanged. Future death explosions will use this exact renderer; the obsolete mine sheet/generic attack circles are not restored.

`docs/REGUN_ARSENAL_AND_LOADOUT_PLAN.md` is the **unimplemented proposal** requested by the creator: Rail Lance, Cinder Hose, Rivet Driver and Reaper Disc; cumulative mastery unlocks; Rupture (enemy death explosions), Concussive Loads, Fault Finder and Overpressure; proc provenance/budgets and an eight-weapon upgrade audit; a full armory/loadout redesign with useful weapon previews, locked-item inspection, visible progress and a fixed equipped-summary/Start strip. Existing weapons/unlocks remain valuable. The new weapons, new upgrades and loadout redesign have not been implemented in this pass.

### Distinct leap warning and continuous Marshal laser

The creator rejected the shared sprite-strip warning used for Skitter and Marshal. Skitter's lane now uses matte paired claw gouges, a low dusty scuff and arena grading; it no longer uses the generic stone ribbon shared with gunfire. It retains the same committed reach/direction and warning clock.

Measured Fire and the Marshal's brace counter now use `AttackMaterial.laser`: an unbroken warm-white core, layered orange/red energy edges, square filaments and a gun-source flash. These are actual requested energy beams, not repeated floor-impact sprites. Warning and damage use the same immutable clipped line. The line starts at the measured gun-muzzle offset, extends *through* its locked aim point and stops at arena solids. The firing pose is held with the gun raised throughout the beam and between delayed releases; it does not lower mid-beam. Measured Fire holds each release for .28s (previously .12s); the counter holds .24s (previously .15s). Each still hits at most once, damage/width stay unchanged, and Reduced Motion removes traveling filaments. Beams draw at gun/actor height; floor warnings and explosions retain their below-actor treatment.

Regression coverage includes pixel-sampled continuous core output, gun-source/aim-point alignment, actual damage, one hit per release, immutable committed geometry, pause/reduced motion, cleanup and both arena renders. Physical readability, motion comfort and difficulty remain for device review.

Final validation: analyzer clean; **140 tests passed**, four opt-in cases skipped. The 30/60-minute prepared-build soaks passed with 8/16 bosses, peak 60 enemies and eight hazards; peak world children 194/315, retained 154/226. Reviewed grounded explosions on both arenas, forward-chain fans, continuous beams and claw-scrape warnings. Final release archive/export completed in 44.5/26.3s and reports **1.0.0+7**. The phone was initially unavailable, then reconnected; the final `lib/main.dart` release installed and launched successfully (23.1s build, 11.8s install). Latest IPA: `build/releases/Regun-1.0.0+7.ipa`; checksum/measurements: `docs/validation/coffee-combat-release7-2026-10-20.json`. These checks do not establish physical-device performance, difficulty or subjective presentation approval.

### Tactical reloads, staged readiness and readable Revenant shots — release 7

Manual reloads with ammo remaining are 30% shorter for Carbine (base 1.26s instead of 1.8s) and 15% shorter for the other three weapons. Empty reloads keep their existing duration and Fast Reload scaling. Carbine swaps the whole magazine, seats it near the end and skips the bolt cue when a chambered round remains. No per-round Carbine loading.

Shotgun, Revolver and Arc Caster now fund individual rounds/charges during the reload. Held fire interrupts once a new round has actually loaded, then performs a short ready action (120/140/100ms respectively; tactical actions 15% shorter) before firing. Retained ammo alone cannot instantly cancel a reload. Releasing aim lets the complete reload finish at its previous full duration. Ammo counters show actual funded rounds; HUD/world art share loading and closing state, with Reduced Motion support. Reload interruptions do not invent ammo or rearm Last Shell/Breach Loader; those perks rearm on full magazine completion. Checkpoints retain staged ammo, tactical timing and a pending closing action, while old snapshots remain readable. Pause freezes all stages. Magazine pickups, recovery and restarts clear pending closes.

Revenant projectiles no longer use the small brass-colored item presentation: an elongated painted iron dart with muted rose highlights and a short ragged wake contrasts with round brass XP coins. Collision radius, damage, travel speed and range remain unchanged; projectiles also respect pause. The shared Revenant/Shadow cast sound is now a short filtered physical launch, using the existing CC0 source recording (`tool/generate_revenant_audio.py`), at .30 runtime gain with a 100ms overlap limit and combat prewarming. `tool/preview_combat_audio.py` now validates and mixes this cue too. Device sound fatigue/readability and tactical-reload balance still need hands-on review.

Validation: analyzer clean; **149 tests passed**, four opt-in cases skipped; all five weapon-presentation tests passed after the dart texture refinement. Both 30/60-minute soaks passed (8/16 bosses, peak 60 enemies/eight hazards). 36 combat WAVs validate; representative mix peaks at .707. Release IPA verified as 1.0.0+7 (88985981 bytes, SHA-256 `fc9b37aad3d8b48de0c57bd609f96013eb766857fa566b89fafcd2d6c390fbcd`). Phone installation was attempted but the paired iPhone was unavailable. See `docs/validation/tactical-reload-projectiles-release7-2026-10-20.json`.

### Action soundtrack, including menu — release 7

All four music loops now share a darker rhythmic action identity: menu 124 BPM, Breach 138, Foundry 146, boss 156. Original sixteen-bar compositions use low-string power dyads, syncopated bass, heavier drums/toms, phrase variations and a short half-time rebuild. Combat starts at full rhythmic intensity. The menu is action-ready with a less dense half-time backbeat. Existing SoLoud paths, loop/transition/pause/settings contracts and .25 music bus gain are preserved. There are no new runtime dependencies or simultaneous music layers. `tool/generate_action_music.py` regenerates all four; the legacy audio generator can no longer overwrite music. `docs/art/ACTION_MUSIC_REVIEW.md` and `ACTION_MUSIC_MANIFEST.json` record the source, hashes and review requirements. The music validator passes all four format/length/seam/headroom checks; representative combat mixes peak at .705/.692/.714. Native listening and fatigue/readability review remain open.

Release packaging succeeded; all four packaged music hashes match the source manifest and IPA identity remains 1.0.0+7. Paired iPhone remains unavailable, so installation/native listening are pending. See `docs/validation/action-music-release7-2026-10-20.json`.

Phone retry succeeded: the latest 1.0.0+7 release installed and launched over Wi-Fi (22.0s build, 12.8s installation/launch). Native listening and comfort approval remain open.


### Full reload commitment restored after device feedback — release 7

The creator found firing between reload stages too forgiving. Shotgun, Revolver and Arc Caster now finish their complete reload before any shot can fire, including held aim. Per-round funding, short ready/closing interruptions and their 15% tactical-duration bonus are removed. Normal reload durations, Fast Reload scaling, the shotgun Lottie and Extended Tube pickup refill are preserved. Last Shell/Breach Loader return to their normal final-/first-shot conditions because one-round interruption loops no longer exist. World/HUD show full reload progress without a separate closing state.

Carbine alone keeps the chambered-round manual magazine reload: .70 duration (base 1.26s versus 1.8s), seat near the end, no final bolt cue; empty reloads retain the full action. Its tactical presentation and checkpoint state remain. Old `reloadPlan` snapshots migrate to a complete reload, roll staged ammo back into the pending refill and undo the old non-Carbine .85 timing multiplier; Continue cannot resurrect a saved short closing action. Regression coverage exercises held aim across all three weapons, full/partial timings, pause/Continue, old interruption saves and Carbine cue/timing persistence. Music and projectile corrections remain.

Validation: analyzer clean, **152 tests passed**, four opt-in cases skipped. The updated 1.0.0+7 release IPA was verified and installed/launched on the paired iPhone over Wi-Fi (20.4s build, 10.0s installation/launch). Physical balance approval remains open. See `docs/validation/full-reload-release7-2026-10-20.json`.

### Bounded close-range weapon damage — release 7

Added distance-based primary-shot damage via `WeaponBallistics`: Shotgun +20% close / −10% far; Carbine +10% / −5%; Revolver +12% / −2%; Arc +8% / −2%. Smooth fixed world-space bands preserve ranged roles and prevent range upgrades extending the close bonus. Projectile cadence, reloads, spread, pellet count, hitboxes, speed and knockback stay unchanged. Swept hits use actual first-contact travel; piercing and bounces preserve cumulative distance without repeatedly applying the multiplier. The final ricochet damage remains capped at twice original damage, and chains inherit the adjusted source amount once. Secondary projectiles and autonomous/proc damage do not gain another proximity multiplier. Final travel steps stop at the existing maximum range. See `docs/WEAPON_RANGE_BALANCE.md`; native balance remains for review.

Validation: analyzer clean; **158 tests passed**, four opt-in cases skipped. Both 30/60-minute prepared-build soaks passed (8/16 bosses, peak 60 enemies/eight hazards). The verified 1.0.0+7 release IPA was installed and launched on the paired iPhone over Wi-Fi (21.4s build, 8.2s installation/launch). Physical difficulty/readability approval remains open. See `docs/validation/weapon-range-release7-2026-10-20.json`.

### Whole-cluster control sizing and dash feel — release 7

The creator confirmed Dash/Reload were not growing with the stick slider: they were fixed at 56px. The slider is now **Control size**, preserving its existing persisted size key and default. `ControlLayout.buttonSize` scales both buttons proportionally with the sticks (about 51–65px across the current slider). Flame scales the visual and interactive components together. Geometry uses the actual action radius for safe-edge clamping and overlap rejection; default spacing remains familiar, with extra room at large sizes. Left-handed mirroring, aim-thumb placement, fixed/floating handling and stored custom positions remain. Tests exercise all sizes, inset/height extremes and mirrored geometry on three viewports; live touch checks include enlarged-button outer edges and persistence.

Player dash speed increases from 1300 to 1450 world units/s (about 12% faster and farther at the same duration). Cooldown, protection, upgrade scaling and collision constraints are unchanged. The live multi-touch regression checks actual dash displacement while the movement finger stays held, then checks pause/reset and enlarged reload input. Native comfort and difficulty remain for review.

Validation: analyzer clean; **159 tests passed**, four opt-in cases skipped. Verified release IPA identity remains 1.0.0+7; installed and launched on the paired iPhone over Wi-Fi (20.3s build, 9.9s installation/launch). Native comfort/balance review remains open. See `docs/validation/control-size-dash-release7-2026-10-20.json`.

### Timed Breach airdrops replace the four structures — release 7

Removed the four Breach pillars from both the authored collision layer and scenery, plus its four static decorative grates; Foundry remains unchanged. New single-pod objectives arrive at random visible, safe, separated positions after the run begins, with a planted warning, accelerating fall, heavy impact and new arena-graded dust sprites. Impact kills ordinary roles in the small landing footprint and deals base3% max-health damage to a boss. The capture field is separate and was enlarged from 145 to **220 units** after the creator's visual feedback.

Hold inside for eight active seconds to earn one AIRDROP upgrade, with a segmented brass meter, expiry countdown, illuminated field and low rising fill pulses. Leaving pauses charge while the 45s lifetime continues. A claimed pod opens and lingers briefly; claimed or unclaimed, it breaks into settling panels and disappears through dust. Reduced Motion uses stationary fades. XP/level/cost remain intact, offers use existing unique/rank/bans rules and grace, and checkpoints retain clocks/phase/source/claimed state without repeating crush damage or rewards. Pause, picker and deployment/recovery freeze the objective. Lazy art leases handle pending restart/disposal and release outside use, retaining the 32 MiB boss budget. Boss Rush excludes drops; Training Pause → Call airdrop allows immediate review. See `docs/AIRDROP_DESIGN.md`.

Validation: analyzer clean; **167 tests passed**, four opt-in cases skipped. The 30/60-minute soaks passed with 8/17 bosses, peak 60 enemies and seven/eight hazards; peak world children 198/357, retained 126/234. All 48 combat WAVs validate; representative mix peak .745. Verified all 14 new packaged art/audio hashes in release IPA 1.0.0+7 and installed/launched it on the paired iPhone (22.5s build, 14.7s install/launch). Native sound, comfort and balance review remain open. See `docs/validation/supply-drops-release7-2026-10-20.json`.

### Controls before a match and home settings — release 7

Home now has a dedicated icon-only Settings button at the safe top-right edge, with a pixel gear, accessible name and tooltip. Re-Gun/menu content sits lower and Play has a larger gap before Training. Settings → Controls opens the same editor as Pause → Controls without mounting a run: all six sliders, stick mode, aim hand, Arrange and Reset are available. Changes save to the existing device preference and are read by the next run. Opening Controls through in-match Settings also applies changes to the paused game immediately. Arrange respects safe edges and system Back returns to the editor.

Validation: analyzer clean; 168 tests passed, four opt-in simulations skipped. The home-to-settings-to-controls regression changes size, drags placement and verifies persisted values after service recreation. Compact/notched/portrait/large-text menu checks now include Controls; rendered home reviewed at phone size. Release identity remains 1.0.0+7.

## Online connection slice (20 October 2026)

The separate SpacetimeDB server now has a Flutter client entry through Online. Room creation/join, supported team sizes, readiness, host start, movement/dash, per-player application RTT and reconnect are connected. This isolated movement test does not run combat, enemies, supplies, progression or profile rewards. See [MULTIPLAYER_CONNECTION_TEST.md](MULTIPLAYER_CONNECTION_TEST.md) for usage, pinned protocol adaptations, verification and outstanding native/full-game acceptance.


## Private multiplayer implementation — 21 October 2026

Authoritative co-op survival and unrated Versus now live in the independent sibling TypeScript SpacetimeDB module and native Flutter Online flow. Co-op uses the normal Breach/Foundry with two or three total players, complete rosters, shared funded XP/personal VIII builds and explicit cores, downed/revive and timed Breach supplies. Versus supports 1v1/2v2/3v3 on two authored covered maps, default neutral enemies On / optional Off, equal weapon access, rounds/overtime/forfeits and results/rematch. The third map remains a candidate. Secure native guest identity and a separate once-only online ledger preserve offline profiles. The creator-approved movement remains server-authoritative with display interpolation; no speculative hit/rewind claims.

See [the test/deploy guide](MULTIPLAYER_TEST_AND_DEPLOY.md) and [implementation ledger](MULTIPLAYER_IMPLEMENTATION_PROGRESS.md). Server: 67 tests/build and connected combat, both maps/all formats, two-player Breach and three-player Foundry passed. Native simulator storage/combat/reconnect passed. Client analyzer and 180 tests pass with four opt-in skips. Cross-language weapon/boss/survivor/XP fixtures pass; local ordered 100/200ms delay smoke passes. Regular art/Boss Rush retains its 32MiB decoded-art gate; optional higher-resolution online walls are leased only by Online. No VPS deployment or physical combat performance/balance approval is inferred from these checks. Version remains 1.0.0+7.

## Home terminal redesign — 21 October 2026

Replaced the survivor lineup with an original code-painted iron breach: stepped masonry, radial locking hardware, a split furnace seam, stair approach and drifting ash. Static architecture has its own repaint boundary; a separate 24-second ambient ticker moves only lock indices and ash. Reduced Motion/system Disable Animations freezes the scene, and Navigator ticker handling suspends covered routes. Home no longer loads the survivor atlases for its illustration.

The title and navigation now share a bounded, safe-area composition. Continue and Play share the first row when a saved run exists; Online occupies the second; Training, Collection and Settings share a lower utility rail. All five actions remain visible at ordinary text size on compact landscape phones. Portrait and enlarged text use deliberate scrolling; the footer stays outside the scroll viewport. Settings retains its accessible name/tooltip and opens the same persistent controls. Saved-run replacement/resume, first-run training, audio, best score and installed version metadata are preserved. No gameplay or server contracts changed.

Validation: analyzer clean, **182 tests passed**, four opt-in simulations skipped. New checks cover five actions, compact/notched/tablet/portrait safe edges, enlarged text, Continue/Settings callbacks and switching animation to Reduced Motion. Existing native-size/menu/settings/startup/training regressions pass with ambient animation disabled for settling. Human visual preference and touch comfort remain for review.

The debug iOS simulator build also succeeded; installed and launched on the open iPhone 17 simulator. Native screenshot confirms the title, primary navigation, lower Settings rail and version footer remain inside the safe area. Simulator retains its existing local multiplayer endpoint; no hosting configuration changed.

## Rook's shelter artwork correction — 21 October 2026

The creator rejected the iron breach's sterile vector treatment and approved a textured pixel shelter illustration conditional on the lamp visibly flickering. Home now depicts Rook checking a shell beside a battered shotgun, mug and route map, using the established helmet/scarf identity. The warm lamp has uneven localized filament flutter and short dips, with responding bench light; cool masonry and the navigation stay steady. Small dust motes and stepped mug steam add secondary motion. Reduced Motion/system Disable Animations freezes the scene. Effects appear only after the plate has decoded. The five-action navigation and reachable Settings rail remain, with a warmer charcoal/plum palette; the decorative terminal caption is removed, while actual best score/version remain.

The packaged 1536×1024 plate is `assets/art/arenas/home_hideout_v2.png`; generation method, references and exact prompt are recorded in `art/source/menu/HOME_HIDEOUT.md`. A rendered-pixel regression verifies change in the actual lamp and bench, no change in the distant shelter, and identical frames under Reduced Motion. The creator's illustration approval does not replace review of the animated result on hardware.

Validation of the shelter correction: analyzer clean; **183 tests passed**, four opt-in simulations skipped. Signed release 1.0.0+7 built, packaged plate SHA-256 verified and installed/launched on the paired iPhone 12. A fresh debug simulator build was installed/launched on the open iPhone 17. Both use the configured public multiplayer endpoint, allowing them to address the same rooms. Installation/launch and automated light checks do not establish the creator's physical animation/comfort approval.

## Home button finish and creator credits — 21 October 2026

Home actions now share Regun's stepped `controlPlate` geometry: recessed warm iron faces, caught top lips, brass rims/pins, sparse surface scuffs and a depressed touch state. Continue/Play priority comes from warmer iron and brass rather than a flat cream slab; utility actions and Settings use the same construction. The approved Rook shelter, localized flickering lamp, five-action layout and accessibility behavior remain.

Collection → Credits now shows a tappable, underlined “Created with Flutter and Flame by Dedeke David” attribution opening `https://kiishi.space` in the external browser, with a 48px minimum touch target and a brief failure message if opening fails. The notice reads “No accounts or ads are required.” Analyzer clean; all 183 tests pass (four opt-in skips), and the compact/enlarged-text Collection/menu checks pass after the link touch-target refinement. Visual preference remains for creator review.

Rebuilt and installed/launched the button/credits refinement on the paired iPhone (signed release 1.0.0+7) and open iPhone 17 simulator (debug). Both continue to use the same public multiplayer configuration. The accepted shelter plate and flicker regression are unchanged.

## Loadout preparation and shotgun assistance — 21 October 2026

Replaced the long Survivor/Weapon/Arena document with three pinned catalog tabs showing the current choices, a persistent kit stage using actual survivor/weapon/floor art, a locally scrolling active catalog and a fixed summary/Start. Switching catalogs retains all selections and returns to the equipped entry, so adding roster entries grows the local list without pushing other categories offscreen. Portrait reflows the stage above the list; compact/large-text layouts keep navigation and Start reachable. Normal unlocks, training access, profile cosmetics, saved-run clearing and the launch contract remain. Weapon previews wait for atlas readiness; the larger survivor art is opt-in.

At the creator's request, Pump Shotgun base damage rises **1.0→1.2 per pellet**. Three close connected pellets now deal 4.32 before defenses/upgrades (previously 3.6). Base reload is **800ms + 600ms per additional missing shell**: 0.8/1.4/2.0/2.6/3.2s for one through five, with the existing five-shell cap on bigger magazines. Existing Fast Reload bounds and complete-reload commitment remain; the original Lottie is retained, recorded shell cues and visible mechanism follow the new cadence. Fire rate, spread, pellet count, range/speed, impact response, falloff and proc budgets stay unchanged. A separate one-time `shotgunReloadBalance` checkpoint marker preserves completion and consumed cues from old saves without repeating the Arc migration.

Validation: analyzer clean; **187 tests passed**, four opt-in simulations skipped, including pinned catalog selections/unlocks/compact/large-text behavior, reload boundaries, magazine/Fast Reload limits, held fire and old staged/current checkpoint migration. Sibling server typecheck/build and **67 tests** pass; shared fixtures agree, and a fresh isolated local module passed the connected combat/reload/damage/elimination/rematch smoke. Signed 1.0.0+7 release installed/launched on the paired iPhone; fresh simulator debug build installed/launched on the open iPhone 17. Both address the public endpoint. The matching server source must be deployed through Dokploy before this tuning takes effect online. No VPS deployment or human balance/comfort approval is inferred.

Final visual review caught cached weapon thumbnails waiting for a new asynchronous frame after catalog switches. Ready survivor/weapon atlases now paint immediately, while genuinely cold loads still wait for readiness. A pixel-level thumbnail regression verifies the visible equipped-weapon image rather than accepting an empty placeholder; the full 187-test suite and analyzer remain clean.

## Ordnance, remains and supply correction — 21 October 2026

Implemented two-charge secondary grenades with an aiming-side tap button (mirrored/resizable/custom placement), material grenade sprite, ballistic arc/solid bounce/contact-or-1.4s-fuse, sequential 18s recharge, validated checkpoint persistence, pause/selection/deployment gates and single-blast cleanup. Three VIII-rank utility families bring offered families to 33. Matching authenticated/replay-protected SpacetimeDB reducer, authoritative flight/recharge, online art/audio and capability gating are implemented; PvP damage is independently 3.2HP with no self/friendly fire. Mines now use radius 185 and damage 3.5+effective rank (Scrapper unchanged), body-edge intersection and cover occlusion, with a recorded bounded explosion cue. Breach supplies use radius 260 and 50s expiry, retaining 8s capture. A separate prone Revenant corpse replaces the kneeling frame; dying legacy enemies freeze facing. Existing boss-pair texture cap is preserved through small native sprite decodes. See `ORDNANCE_AND_SUPPLY.md` for contracts, checks and open physical acceptance.

Validation for this pass: Flutter analyzer clean;192 client tests passed with4 opt-in skips;70 server tests/typecheck/module build passed. A fresh local SpacetimeDB2.12 database passed the extended live combat smoke (grenade sender/generation/replay guards, two charges, sequential recharge, fuse removal, single-grenade PvP3.2HP, plus firing/reload/round/rematch). Exact control states/prone remains were rendered to `build/test-previews/ordnance.png` and inspected. Release iPhone build installed/launched on the paired phone; debug simulator build installed/launched on the open iPhone17 simulator. Those are build/install checks, not physical comfort/audio/balance acceptance. Public Dokploy deployment remains separate from these local checks.

## Skitter fairness correction — 21 October 2026

Players reported relentless jumps and hard-to-see anticipation. Commit range620→480, maximum leap680→520 (minimum240→180), warning .55→.75s and planted landing recovery .8→1.4s. Clear sight is required before commitment; nearby Skitters within700 units take turns through warning/jump plus .35s landing separation. Jump speed/damage, committed direct/predicted route, collision, elite/cycle scaling remain. The shared material warning has denser larger ground scuffs, broader dark backing and brighter claw cuts visible at the start; no flashing, clean line arrows or new texture budget. Native warning/jump facing is locked to the committed direction. Native regression checks warning/recovery durations, pack staggering and non-homing; authoritative tests also check long range and cover rejection. A rendered two-floor warning preview lives in build/test-previews/skitter-warning.png. Native comfort and balance remain hands-on acceptance.

Skitter validation: analyzer clean; focused native tactics/visual9 tests and boss regression22 tests pass; authoritative71 tests/typecheck/build pass. Rendered warning contrast is checked from the start on both floor palettes. The full client suite exposed an obsolete long-reach expectation, updated to the new bounded reach before the boss regression passed. Physical visibility/pack balance remains for playtest.

Skitter warning blending follow-up: creator accepted the new path but requested a fainter, better-grounded finish. Muted the warm highlight to dusty stone, softened its opacity and reduced the dark backing/scuff opacity while preserving mark size, density and immediate contrast. The same painter serves solo and online; attack timing/collision are unchanged. Two-floor render inspected; focused visual test and analyzer pass.

## Independent grenade aim correction — 21 October 2026

Creator playtest reversed the original tap-only direction. Grenade now supports hold/drag/release with independent heading, bounded drag range and same-physics preview including cover/bounces/current contacts. Tap uses movement, falling back to last weapon aim only when stationary. Holding does not consume charges or cook the fuse; return-to-center, pointer cancel, pause/background/focus/connection/epoch changes cancel. Shared custom control keeps material art, shifted grenade grip, Release/Cancel, mirrored arrangement and charge/recharge states. Max throw/damage/recharge unchanged; aimed speed40–100% of600. Native tests exercise running forward/throwing backward, single release, center cancel, pause and pointer interruption plus tap movement direction. Shared preview tests compare endpoint against actual substep simulation. Online raw-pointer control tests multi-touch capture/cancellation. Backend aim_grenade adds finite direction/power validation and existing sender/room/generation/seq/charge guards while retaining throw_grenade for old clients. Extended live-local smoke passes independent heading/range and malformed/replayed/outsider requests. See docs/ORDNANCE_AND_SUPPLY.md; physical thumb feel/trajectory readability remain for creator testing.

Independent aim validation:197 client tests passed (4 opt-in skips), analyzer clean; after final pointer/online preview refinements18 focused control/online/flight tests passed.72 server tests/typecheck/module build pass; live-local smoke passed aimed heading/power plus invalid NaN/power, outsider and replay denial. Actual native hold/trajectory rendered in build/test-previews/grenade-aim.png and visually inspected. Hands-on range/comfort/readability remains for creator acceptance.

## Resting gun direction and upgrade recovery — 21 October 2026

The gun now follows movement after .65s without deliberate aiming, smoothly turning on the shortest route; immediate aim/reload direction wins. Shared solo/online model preserves separate grenade aim and Reduced Motion. Confirming an earned upgrade/fusion queues one distinct force pulse on resume: radius250, damage1, up to145-unit mass-scaled shove over .32s, no boss/anchored displacement or invulnerability. Following creator clarification it also clears nearby hostile bullets at that instant, with no ongoing shield or hazard/laser cleanup. Cover/occupancy constrain push and damage; normal damage and later bullets remain live. Dedicated confirmation/validated checkpoint flag and authoritative pending progress prevent replay/reroll/menu-triggered pulses. New cool pressure rim/audio distinguish it from ordnance. See docs/UPGRADE_RECOVERY_AND_REST_AIM.md for contracts and validation: 201 client tests plus final13 focused tests, clean analyzer,74 server tests/build and live-local three-player Foundry earned-choice/pulse/replay/resume smoke. Physical acceptance remains open.


## Shelter power and background update check — 21 October 2026

Update checks no longer disable home taps, focus or accessibility while awaiting the API. The passive checking label allows taps through and owns its Material/text style, removing inherited yellow underlines. Real update notices retain their existing modal/required-policy behavior. A delayed startup/resume regression verifies taps through both the menu and status, focus/semantics availability, offline recovery and undecorated text.

The approved shelter now has darker surrounding ruins and a preserved warm working area. An uneven 24s voltage envelope visibly dims/brightens the actual bulb and reflected workbench/survivor lighting, with brownout holds and staggered recovery. Sparse dust drifts through the wider shelter, occasional tiny sparks fall from the upper-right damaged cable, and the mug retains its steam. Reduced Motion keeps a steady frame and omits sparks. No artwork replacement, combat textures or per-tick widget rebuilds. Rendered bright/brownout/spark/steady frames in build/test-previews/shelter-*.png were inspected. Voltage continuity/range, actual bulb/workbench pixel changes, unchanged remote masonry and Reduced Motion stillness pass. Full client suite:203 passed,4 opt-in simulations skipped; analyzer clean. Native comfort/readability remain hands-on acceptance.

Native builds: signed release1.0.0+7 built successfully; physical installation could not proceed because CoreDevice reported the paired iPhone unavailable (4016). Debug simulator build installed/launched on the open iPhone17. The phone still needs this candidate installed when connected; no physical performance/comfort acceptance is inferred.


## Public 1.0.0+8 candidate — 21 October 2026

Creator requested a public build showing upcoming multiplayer without access. Version is now1.0.0+8. `ReleaseFeatures.onlinePlay` defaults false in lib/config/release_features.dart; this one constant restores normal navigation when changed to true after release. Gray Online remains tappable and shows a short Coming Soon notice, with the shared stepped frame, charcoal surfaces, brass pins/type and existing pixel action button. No backend change or store upload is part of this switch.

Creator also requested liveliness within a five-second recording and reported a gray patch over the dim lamp. Removed the flat bulb polygon in favor of feathered rotated attenuation that preserves painted texture. Increased irregular contact dips/recovery, broader sparse dust and occasional cable sparks; darker surrounding grade and Reduced Motion hold remain. Tests verify voltage variation in every five-second interval across the loop, actual rendered dim/bright lamp and bench, stable Reduced Motion, release popup/dismissal and restored online callback. Compact/large-text popup and bright/brownout frames rendered and inspected.

Build8 validation:16 focused home/update tests passed (including additional five-second-window and popup render checks); analyzer clean. App Store export succeeded at build/ios/ipa/regun.ipa, with archive settings validating1.0.0/build8. Signed archive app installed and launched on the paired iPhone; simulator debug build installed/launched and home frame inspected. No App Store upload performed. Physical animation/comfort acceptance stays with creator review.

## Online preparation UI — 21 October 2026

Following the creator's lobby/input review, Online now has separate Create/Join paths, a remembered guest name, stepped native text editors with persistent labels/focus, explicit Paste and keyboard dismissal, normalized ten-character invitations and immediate submission validation. The primary action stays pinned; the header yields space while the landscape keyboard is open. The shared menu's new header/dismissal options default to the prior behavior for other screens.

The waiting room presents co-op squad slots or two Versus teams, survivor portraits, remote weapons, You/Host labels, empty places and Ready/Choosing/Reconnecting states. A bounded local notice reports joins, departures and reconnections, suppresses invented arrivals when the local connection resynchronizes, and explains a room disappearing. Copy confirms inline. A compact kit summary exposes existing weapon/survivor choices; Ready/Start and the specific authoritative start blocker remain visible below the scrolling content. Normal co-op still starts with two ready players; Versus still needs full balanced teams. No matchmaking, chat, host migration or gameplay/server rule changes were added.

Initial connection attempts and automatic retries no longer display an available Retry button. Service HTTP rejection, invalid schema, arena preparation and session attachment have distinct brief failures and a safe internal diagnostic category. Closing/backgrounding during schema/art preparation cannot proceed into a stale session attachment. This improves feedback and lifecycle handling; the phone's reported live connection failure has not been established as fixed.

The charcoal/brass pixel treatment uses existing survivor art and native text-editing semantics. Static membership feedback supports Reduced Motion without new ambient animation. Review rationale and sources are in `ONLINE_UX_REVIEW.md`; rendered previews are `build/test-previews/online-join.png`, `online-squad.png` and `online-lobby.png`. Public build 8 identity and `ReleaseFeatures.onlinePlay = false` remain unchanged. No server deployment or device installation was performed. Native keyboard/VoiceOver feel, two-device arrivals/readiness and real WAN reconnect acceptance remain for hands-on review.

Validation of this UI pass: analyzer clean; **213 client tests passed**, four opt-in simulations skipped. New regressions cover initial/retry presentation, service/schema/art failure categories, route disposal during a pending schema request, name persistence, code normalization/validation, IME composition, keyboard insets/dismiss/refocus at normal and 1.8× text, explicit paste/copy, outside-touch dismissal, squad/readiness/loadouts, join/leave/reconnect notices, room removal and resync suppression. The regenerated Join, co-op and six-player Versus widget renders were inspected. No physical-device or live-room acceptance is inferred.

Creator-authorized private phone install: enabled `ReleaseFeatures.onlinePlay`, built signed release1.0.0+8 with the configured public multiplayer endpoint and installed/launched `dev.kiishi.regun` on the paired physical iPhone12. Xcode release build and CoreDevice installation/launch succeeded. This supersedes the gate-off/no-install delivery state above for this local private candidate; no store upload or server deployment occurred. The online UI and full live connection still require creator device review.

## Online movement response, control parity and guest recovery — 21 October 2026

Creator device feedback identified delayed self movement and simplified Online controls. `ControlArt` now owns the joystick ring/stepped knob and Dash/Reload plate/glyph rendering shared by the original Flame components and Online. Online retains the same persisted sizes, opacity, mirrored aiming-thumb cluster, floating exclusions and sensitivity/dead-zone order; its knob travel now matches Flame. Grenade remains independent. Native touch tests and fixed/floating/right/left control regressions cover the cluster.

The sibling server adds an opt-in private bounded movement queue with owner-scoped applied acknowledgements. It consumes at most one server-owned50ms movement step per callback; no client positions, duration, speed, damage or hits are accepted. The client predicts local presentation, replays only unacknowledged commands and blends small cover-constrained corrections; large corrections snap and Reduced Motion avoids reconciliation blending. Other players retain display interpolation. Dash uses the same direction, duration, cooldown, movement ranks and collision rules; input-generation, shared phase/death, menu, connection and route transitions reset/stop prediction. The maximum prediction/queue horizon is12 commands (600ms). Old servers remain capability-gated and use the earlier authoritative display. Combat authority/rewards/weapon timing are unchanged; no rewind, speculative hits or seamless bad-network promise is made.

Native public-server diagnosis on the iPhone17 simulator reproduced a rejected saved guest (`session_SpacetimeDbAuthException`), while a fresh guest connected successfully. A rejected credential now stops retries and offers an explicit Start new guest action with an online-record warning. Secure storage retains the rejected token under a separate secure key before replacement; no credential is written to reports. Solo profile data is untouched. An isolated native recovery test connected/subscribed and reconnected using its new saved token. This establishes the simulator's failure category, not the physical phone's exact cause or whether the original token expired versus server keys changing. Connection/subscription timeouts now allow a reasonable cold mobile handshake. Route/lifecycle double-disposal detaches listeners synchronously and shares one close future.

Validation: analyzer clean; **225 client tests pass**, five opt-in simulations/live checks skipped. **77 server tests**, typecheck and module build pass. Disposable local TypeScript smoke confirms applied acknowledgements, owner scoping, wrong-room/generation/replay/invalid-vector denial, one-step movement, dash and stop. Flutter live-local movement tests pass direct and through nominal100/200ms round-trip ordered TCP proxies with jitter, including early local movement, convergence, bounded replay, menu stop and reconnect epochs. The iPhone17 simulator repeats actual touch movement/dash/pause at approximately200ms application RTT; its screenshot `build/test-previews/online-prediction-native.png` was visually inspected. Public native guest diagnosis and isolated recovery/reconnect pass. Proxy tests do not simulate actual radio packet loss or establish physical comfort/performance.

Restored the normal `lib/main.dart` debug app, Online enabled, on both running iPhone17 and iPhone18Pro simulators with the **public** endpoint. Release identity remains1.0.0+8. The matching prediction backend is published only to disposable local `regun-dev`; the public backend has not been updated. VPS deployment is blocked because its saved SSH entry references a missing key; browser control for Dokploy is disabled. Until the backend is deployed, these public-endpoint simulator builds have the new controls and guest recovery but keep legacy movement. Follow `MULTIPLAYER_TEST_AND_DEPLOY.md` for additive rollout/volume preservation and verification. No phone installation or store upload occurred in this pass.

The matching signed iOS release1.0.0+8 phone candidate also builds successfully (`build/ios/iphoneos/Runner.app`,109.1MB); it has not replaced the phone app while the creator is away. The production rollout/access question remains pending.

Public prediction rollout verified: the creator clarified that pushing backend main triggers automatic deployment and authorized the push. Committed/pushed sibling server `8f54d7175d103a5dbecd07e09e474a215573a1b0` (`Add authoritative movement acknowledgements for client prediction`). The public named schema now advertises `queue_motion`, `stop_motion` and `my_motion`; `/health` returns HTTP200. A fresh authenticated TLS WebSocket connection successfully subscribed to the existing scoped views plus `my_motion`. This supersedes the rollout/access blocker above. These were schema/connection checks, not production room-mutation or physical gameplay acceptance. Existing updated simulator clients can select prediction on their next connection; the physical phone still needs the latest client candidate installed.


### Hosted multiplayer regression pass — 21 October 2026

At the creator's request, tested fresh native SDK guests against the deployed public server in disposable private rooms. Initial 1v1 passed actual touch-before-echo (27ms local/282ms authoritative), dash, stop, fire/reload, grenade, 12-second reversals, menu resume and identity-preserving reconnect. Larger party tests exposed capped prediction queues (2v2 one/160 samples; 3v3 fifteen/240). Added observed-server-cadence pacing with bounded buffer feedback; compacted owner acknowledgements and kept packet receipt private server-side; coalesced row refreshes and flushed command completion state before dependent room setup. Server `afa88a8` was pushed to main and compact acknowledgements verified live. Corrected final party run passed co-op three/Breach, co-op two/Foundry, 2v2/Ironworks Relay and 3v3/Ossuary Cross: zero cap stalls/480 sampled client intervals, zero stopped-position error. RTT still varied (152–465ms); the short tests do not prove absence of future WAN spikes. Analyzer clean, client227 pass/five skipped; server77 plus build/typecheck and local protocol smoke pass. Retained safe reports and failed comparisons live under `docs/validation`. Simulator multi-client testing is not physical-device or independent-network acceptance.

Final 1v1 rerun after deployment passed again (23ms local/255ms authoritative response, maxpending8/no sampled stalls, reconnect and cleanup passed). Rebuilt the normal `main.dart` debug simulator app with the existing local define file and installed/launched it on iPhone17 and iPhone18 Pro; both use the public server and Online remains enabled. No phone installation was possible in this pass.

Phone installation follow-up (21 October): rebuilt signed iOS release1.0.0+8 from the current client with the existing private define file and Online enabled. `devicectl` confirmed successful in-place installation and launch on the creator's iPhone12. This includes the hosted-tested prediction pacing, compact acknowledgements and command-refresh correction. User data was not cleared; physical gameplay/comfort acceptance remains for the creator.

IPA follow-up (21 October): creator requested a build-number bump and IPA. Source identity is now1.0.0+9. `make buildIPA` produced a signed App Store export at `build/ios/ipa/regun.ipa` (104.3MB as reported by Flutter). Xcode app validation and the exported IPA Info.plist confirm1.0.0/build9 and `dev.kiishi.regun`. Online remains enabled as explicitly requested for this multiplayer review. No upload was performed.


### Multiplayer latency implementation after build9

Recorded plan/results in `docs/ONLINE_LATENCY_PLAN.md`. Backend1379097 sheds old
movement bursts without granting extra simulation time, preserves original pending
dash heading, expires receipt-aged inputs/dash edges and exposes private input-age/
callback diagnostics. Client uses bounded timestamped remote interpolation (20–70ms
adaptive buffer,80ms max extrapolation with shared cover constraints), clears tracks
on phase/epoch/death/reconnect/relocation, and sends combat edges independently of
prior RTT with six-request bound/150ms keepalive. Eligible first trigger has cosmetic
muzzle/recoil/audio feedback; confirmation suppresses the duplicate. No predicted
bullets/ammo/hits/rewards. Analyzer clean;237 client tests/five skips;80 backend tests,
build/typecheck/local smoke. Local delayed six-player native and hosted co-op2/3,
2v2,1v1 touch/combat/reconnect pass. Initial hosted3v3 hit six sampled stalls during
481ms ack gap; instrumented rerun passed, both retained. Route handshake157–180ms
and callback p95 around51–55ms support investigating delivery path/hosting next,
without proving its exact cause. No hosting/tick-rate change; physical feel remains
open. Current identity stays1.0.0+9 and Online remains enabled.

Latency delivery: current release app installed/launched on creator iPhone12 and
normal app restored on both iPhone17/18 Pro simulators, with Online enabled. Identity
remains1.0.0+9; prior IPA export is unchanged. Physical movement/audio feel remains
for creator approval. Local test server/proxy stopped after verification.

Build10 IPA follow-up: creator requested IPA10. Current identity is1.0.0+10; signed
App Store export completed with latest multiplayer latency improvements and Online
enabled. Exported Info.plist verifies1.0.0/build10 and dev.kiishi.regun. Artifact:
build/ios/ipa/regun-1.0.0-10.ipa. Hash/size recorded in validation/ipa-build10-2026-10-21.json.
No upload was performed. Phone/simulators still carry the prior private build9.


### Online bullet travel/correlation correction after build10

Creator reported improved movement but lagging/desynchronized bullets. Raw20Hz bullet
coordinates were still painted directly. `ProjectilePresentation` now advances server
rounds continuously up to80ms between arrivals and predicts bounded local primary
volley visuals from actual weapon/rank/cadence/reload contracts. Serverf82c200 adds
optional burst/shot/pellet/muzzle metadata and additive combat_input_v_2. Server-owned
latest validated aim avoids waiting behind movement backlog. Local/server identities
join one flight, including carbine random heading; no duplicate confirmed bullet/cue.
Cover/range/body guesses hide speculative travel without fake hits; confirmed pierce
can resume beyond a guessed body, and ricochet updates reset the old direction.
Primary ammo/damage/hits/procs remain authoritative; grenades unchanged. Legacy
clients/reducers remain compatible; new speculation requires protocol2 capability.

Analyzer clean,252 client tests/five skips;82 backend tests/build/typecheck and local
prediction/projectile protocol smokes passed. Delayed native Carbine17ms visual versus
287ms confirm; Shotgun14ms versus259ms,9 matched pellets and75 continuous peer frames.
Hosted Carbine24ms versus203ms,11 matched projectiles,34 peer-between-update frames,
zero duplicate visual keys, full combat/menu/reconnect regression passed. Test name
length/capability detection issues were corrected before passing reruns. See
ONLINE_PROJECTILE_PRESENTATION.md and retained validation reports. Physical feel,
listening and WAN hit fairness remain open. Identity stays1.0.0+10; existing IPA is
not regenerated by this correction.

Projectile delivery: both normal simulator apps updated/launched. Signed release10
device build prepared and verified, but the phone's CoreDevice connection timed out
before installation. Phone remains on the previous client until reconnected; creator
notified. IPA10 is unchanged. Local test server/proxy stopped.

Phone retry: after creator reconnected the iPhone, CoreDevice confirmed successful in-place installation and launch of the signed build10 projectile correction. No profile/guest reset; physical playtest remains for creator review.

### Full dash protection and lighter combat cues (21 October 2026)

Creator reports late-dash hits, missing dash VFX, heavy Skitter/arc art and poorly
attached angled Marshal lasers. Base immunity now covers the whole movement window;
Phase Step adds brief recovery. Native active-dash damage gate and matching legacy/
queued server timing prevent the last-frame gap. Grounded short dust, narrow scrape
warnings and lower boss arc material stamps retain timing/collision/safe pockets.
Marshal has separated planted-body/gun sprites and a shared articulated muzzle for
each committed shot/counter. Online articulation capability-gates muzzleProtocol2.
See docs/art/COMBAT_READABILITY_REVIEW.md. Identity stays1.0.0+10; no IPA/phone update
or production deploy is implied. Physical comfort/readability/balance remains open.

Dash/readability delivery: signed release1.0.0+10 rebuilt with Online enabled, installed in-place and successfully launched on creator iPhone12 via CoreDevice. No app-data clearing. Matching online server changes remain local; IPA unchanged. Physical feel/readability remains for creator review.

### Scrapper speed (21 October 2026)

Creator finalized +50% movement speed with the existing −15% direct-damage tradeoff.
Scrapper base is450 (Rook300, Warden270); description states the actual bonus. Native
saved runs migrate their stored speed by+150 once via survivorSpeedBalance1 while
retaining movement upgrades. Speed reset returns the survivor's own base. Online
prediction/fallback and authoritative server/paired contract fixtures agree; Versus
still uses Rook. Targeted44 client tests and84 backend tests/build/typecheck pass.
Phone installation and matching online server deployment are not part of this edit.

Warden speed follow-up: creator finalized −13% speed (261 vs Rook300), with explicit
loadout copy. Two extra hearts/guard remain. survivorSpeedBalance2 migrates older
Warden saves by−9 once and preserves the version<1 Scrapper migration/upgrades.
Online prediction/server and identical shared fixtures agree.45 targeted client
tests and84 backend tests/typecheck/build pass. No installation or rollout implied.

### Scrapper correction and installation candidate (21 October 2026)

Creator clarified+15%, not+50%; final base345 (Rook300, Warden261). Copy and server/
prediction/fixtures agree. survivorSpeedBalance3 preserves upgrades while migrating
original speeds by+45 or reverting marker1/2 candidate speeds by−105 once; Warden's
−9 migration remains. The+50% candidate was not installed.

The left run artwork lacked passing poses despite advancing correctly. New original
full-body8-pose left sequence includes narrow feet-under-body steps3/7; shared
survivorRunFrame selects it for solo/online. Source generated through built-in image
generation referencing existing Scrapper; generated RGBA copied unchanged, alpha
measured for anchored metadata. Original source atlas retained. Decode320/new and
832/original keep pair art budget.12fps/phase continuity and all other facings stay.
Full pre-speed-clarification verify:261 pass/five skips, all boss pairs below32MiB.
Final corrected speed/gait regression45 pass/one optional video skip; analyzer clean,
84 backend tests/build/typecheck pass. Phone installation recorded separately below.

Corrected-speed/left-run delivery: signed release1.0.0+10 rebuilt from final+15% source, successfully installed in-place and launched on creator iPhone12. Saved data not cleared. Online remains enabled, server speed/protection/muzzle changes still await deployment, IPA unchanged. Physical animation/feel approval remains open.

### Build11 and remote Online availability (21 October 2026)

Version is now1.0.0+11. Removed the compiled Online=true decision: the Home action
reads /features from the public server, defaults closed, validates schemaVersion1 /
booleanonlinePlay, coalesces4s checks and never persists an enabled policy. Refresh
on entry/return/foreground,30s visible-Home cadence and before Online navigation.
Pending checks only affect the Online action. Failed checks close new entry; solo
controls remain usable. Server runtime REGUN_ONLINE_PLAY_ENABLED defaultsfalse and
is rendered through validated nginx config: public no-store /features and server
503 admission gate for identity/subscription whenoff. No database schema migration.
Server environment/redeploy changes availability without another phone build.

Analyzer clean;267 tests/five skips. Actual nginx template tests pass both states,
cache headers/admission/health/admin isolation/invalid values; image builds. Full
local named-volume toggle/reconnect check is recorded in validation. Production
rollout remains pending verification of the existing persistent state/key mount.
See ONLINE_REMOTE_TOGGLE.md. Artifact/device delivery recorded separately below.

Build11 delivery: signed App Store IPA exported and embedded version/bundle verified as1.0.0+11 / dev.kiishi.regun; artifact build/ios/ipa/regun-1.0.0-11.ipa (106,971,381bytes), hash in validation/ipa-build11-2026-10-21.json. Signed device app also rebuilt/verified. Installation attempt failed before transfer with CoreDevice4016, iPhone unavailable; requested reconnect. Phone remains on prior build until retry succeeds. Production backend62fdf0a remains local; remote switch is not yet live.


### Fifteen-weapon expansion — first Burst Rifle slice (21 October 2026)

Creator approved implementation of the fifteen-primary plan, including Frost Shotgun's three-pellet true-freeze direction. The first native addition is Burst Rifle: three actual .10s-spaced rounds, .60s burst starts,18-round magazine,2.0s complete reload, own generated modular receiver/magazine/bolt sprite and recorded-source cues. Named weapon art mappings preserve all original four frames. Mirrored measured sockets and within-frame release offsets align travel/flash; full-volley capacity is claimed before ammo/audio. Pause/input/reset/reload cancel unissued intent appropriately. Optional validated recovery saves never replay pending rounds. Profile schema2 cumulative boss victories unlock Burst at3, counting repeated normal victories once per settled run; both profile schemas/backups remain readable, Training excluded.

Analyzer clean;283 client tests/five skips;88 server tests plus typecheck/build. Unsigned iOS release build succeeded (113.5MB), no install/export/deploy. Shared art30.30MiB and existing boss-pair <=32MiB checks pass; audio previews pass. Burst's server model/fixtures exist but current online lobby selection rejects it until expanded-weapon negotiation/prediction is completed. Current solo roster isfive; remainingten additions, physical motion/audio/comfort/balance and full runtime/capability extraction remain open. Identity1.0.0+11. See ARSENAL_IMPLEMENTATION_PROGRESS.md and validation/arsenal-stage1-2026-10-21/summary.json.


Burst Rifle phone delivery: creator explicitly requested installation. Signed release1.0.0+11 rebuilt with configured release defines, signature/bundle/version/Burst atlas verified, installed in place and launched successfully on creator iPhone12 through CoreDevice. No app-data clearing, IPA export or server rollout. Evidence: validation/arsenal-stage1-2026-10-21/phone-install.json and phone-launch.json. Physical feel/audio/readability acceptance remains for creator review.


Burst Rifle reload follow-up: creator explicitly requested a faster chambered reload with distinct animation versus empty. Burst now joins Carbine's tactical rule: manual ammo-remaining swap uses.70 base duration (1.4s), seats at82%, no bolt; empty stays2.0s, seat42%/bolt82%. Full completion still gates held firing; Continue preserves duration/progress/consumed cues, old full-only Burst saves keep their full reload. Analyzer clean,284 client tests/five skips,89 server tests/build/typecheck pass. Signed1.0.0+11 installed in place and launched on creator iPhone12, data not cleared; server not deployed. See validation/burst-tactical-reload-2026-10-21/summary.json.

## Fifteen primary weapons — native candidate (21 October 2026)

The solo/Training arsenal now reaches fifteen. See
[implementation progress](ARSENAL_IMPLEMENTATION_PROGRESS.md) and
[phone review notes](FIFTEEN_WEAPON_PLAYTEST.md) for every packet, behavior,
validation and remaining online/physical gates. This supersedes earlier five-
and four-weapon counts without marking hosted multiplayer expansion complete.

## Weapon device corrections (21 October 2026)

Creator phone feedback replaces Breach Hammer with Longwatch Sniper, fixes stalled
Reaper reservations, adds release aiming/near-far previews for both lobbers, flowing
Cinder material, grounded ordnance/spores, Repeater motor/70 rounds/faster cadence,
larger Frost pellets/longer Rail rounds, Prism18 capacity, Training pause weapon
switching and subtle loadout idle motion. See WEAPON_DEVICE_REVIEW.md for exact
contracts, save migration, art provenance and physical review requirements. The
roster remains15 and the release identity1.0.0+11. Validation/device evidence is
recorded under validation/weapon-device-review-2026-10-21/.

Device correction validation: analyzer clean,361 Flutter tests pass/five optional
skips;89 backend tests/typecheck/build pass. All74 expansion cues validate.
Signed iOS release1.0.0+11 built (128.9MB), strict/deep signature and bundle/version
verified. Installation could not begin: CoreDevice4016, paired iPhone unavailable.
Latest corrections are **not installed**; prior phone candidate remains until a
connected/unlocked retry succeeds. No data cleared, IPA export or server deployment.

Phone delivery retry: creator reconnected the iPhone; the signed correction build1.0.0+11 successfully installed in place and launched. Data was not cleared. The earlier unavailable-device installation note is superseded by this successful retry. Physical playtest approval remains open. Evidence: validation/weapon-device-review-2026-10-21/install-retry.json and launch.json.

## Combat and weapon correction — 22 October 2026

See [COMBAT_MATERIAL_AND_WEAPON_REVIEW.md](COMBAT_MATERIAL_AND_WEAPON_REVIEW.md): grounded enemy/boss floor materials, committed Skitter route/landing warning, real Burster walk gait, subtle solo damage vignette, live-gun Reaper return,100-round accelerating Repeater, clearer stronger Rivet crowd payoff, Frost2.2/pellet, two-hit normal frontal shields for Sniper and reliable Spore ruptures under FX saturation. Release remains1.0.0+11. Physical acceptance remains open.

22 October delivery: complete combat/weapon review including the later Burster
walk, revised Skitter route/landing and subtle solo damage vignette is validated
(analyzer clean,372 client tests/five skips;89 server tests/typecheck/build). Signed
1.0.0+11 release133.5MB installed in place and launched successfully on creator
iPhone12 after one connection-reset retry. Saved data not cleared. Shared decoded
art30.06MiB; largest pair/Cinder budget remains <=32MiB. No IPA/server deployment.
Evidence: validation/combat-review-2026-10-22/. Physical playtest approval open.

## Universal tactical reload and sniper fatigue — 22 October 2026

See [RELOAD_AND_SNIPER_FATIGUE.md](RELOAD_AND_SNIPER_FATIGUE.md). Every current
weapon now has a70%-duration ammo-remaining manual reload without its final closing
action/audio; empty reloads retain full timing. Sniper sight and actual shot share
subtle.18→.85° fatigue over six seconds, with active rest recovery. The separate
[SIX_WEAPONS_AND_WEIGHT_PLAN.md](SIX_WEAPONS_AND_WEIGHT_PLAN.md) proposes six stronger
weapons and0–7% walking penalties. Those six and weapon weight are not implemented.

Universal reload/sniper delivery: analyzer clean,391 client tests/five optional
skips;90 server tests/typecheck/build pass. Signed133.5MB1.0.0+11 installed in place
and launched on creator iPhone12, data intact. No server deployment/IPA export.
Six additions and subtle weight modifiers are documented proposals, not live content.
Evidence: validation/reload-sway-2026-10-22/. Physical approval remains open.


## 22 October 2026 — six endgame weapons and subtle weight

User-approved implementation follows checkpoint commits game6f9f2b3/backend810244b.
The live solo/Training catalog is21. Twin Verdict pairs alternating-barrel hits;
Flak Regent reserves/releases four secondary fragments; Anchor Engine pulls through
occupancy then crushes; Faultline Driver commits three piercing ground sections;
Cyclone Breacher fires5–9 centered heavy pellets; Mourning Bell echoes only original
owners still in its committed cone. All have leased generated mechanisms, measured
mounts, recorded-source audio and tactical/empty reloads. WeaponMobility applies
0–7% to walking after survivor/upgrades, preserving saved stats and1450 dash.
Fast-projectile stat upgrades/swaps now respect the existing2000 save ceiling.
Native analyzer/tests:443 passed,5 optional skipped. Backend parity:91 passed,
typecheck/build passed locally; no rollout or expanded online admission. Signed
1.0.0+11 iOS candidate built142.8MB and verified. See ENDGAME_WEAPONS_REVIEW.md and
validation/endgame-2026-10-22 for tests,12 base/VIII pack samples,144 survivor/facing
mounts, both reload sheets and device records. Final physical feel/balance remain
for creator playtesting.


## 22 October2026 — heavy weapon feel / Guard photo correction

After device review the creator requested stronger identities and feel, permitted
code-constructed art and explicitly requested a brighter airborne Bell pulse.
Twin is now brand→shatter:1.25s prime,4.5 second hit and a capped two-victim iron
crossburst; opening kills cock the other barrel so weak packs expose the ability.
All six receive distinct layered recorded sounds and payoff timing, stronger local
recoil/contact feedback; Bell leaves no floor AoE paint, Faultline sections fracture,
Anchor clamps and Cyclone uses three muzzle ports. Other weapons/reloads/weight stay.
Flak terminal resolution fixes sub-pixel travel stalls and uses an actual short
burst, with fragment reservations/one-hit owner exclusions retained. The photo's
unsettling wreath was the player Guard's six enemy chain/shield stamps, now replaced
with a quiet foot badge; protection is unchanged.448 tests/5 optional skips and
122 audio-cue checks pass. Signed1.0.0+11 candidate143.2MB built/verified. See
HEAVY_WEAPON_FEEL_REVIEW.md and validation/heavy-weapon-feel-2026-10-22. Native
comfort/balance/listening remain human review gates.

## 22 October 2026 — all-weapon physical enemy reactions

The creator requested proportionate physical reactions across the full arsenal.
All21 now have explicit WeaponReaction profiles: restrained rapid-fire/continuous
nudges, heavier bullet/shotgun kicks and strong pressure/blast displacement. Hard
stagger briefly holds ordinary pursuit/attack clocks and pose; .65s recovery and
.24s force gating prevent stacked pellet/rapid stun-lock. Stronger hits replace
weaker impulses without summing. Existing mass, cover, walls and body occupancy
remain authoritative. Shields resist without a full hold; bosses/nests/sentinels
remain planted. Blast/echo/chain/fragment reactions stay secondary for procs; DoT
never continually pushes. Frost retains its ice-hit shove. Sprite recovery and
death-unfreeze have a dedicated regression. Damage/cadence/reloads/weight remain.

Analyzer clean;453 Flutter tests pass/5 optional skips. Server parity passes93
checks, typecheck and module build, with a shared profile fixture for admitted
weapons. No online weapon admission or live server deployment. Signed143.2MB
1.0.0+11 installed in place on creator iPhone12 with data retained. See
WEAPON_ENEMY_REACTIONS.md and validation/enemy-reactions-2026-10-22. Physical
feel/balance/performance remain for creator Training playtesting.

## 22 October 2026 — Training menu and shared settings

The creator requested a coherent Training pause UI. Main navigation/actions are
pinned above a scrolling practice list; duplicate Controls is removed in favor of
Settings. Five animated collapsed sections cover weapons, survival, supplies,
bosses and fusions. Boss/rush controls are unified. All21 weapon options now show
shared leased gameplay art with equipped markers/capacity. Only the first-run
guided visit mounts tutorial hints/Skip/Ready. Paused HUD clutter is concealed.

Shared Settings/Controls now group related options with clear vertical spacing,
label/value above48px slider tracks and adaptive choice rows. Online Menu moves
top-right with reserved roster space and opens these same settings; live-match
pause/forfeit/input semantics stay intact. Preference bounds and control geometry,
weapon behavior and gameplay balance remain unchanged. See TRAINING_MENU_REVIEW.md
and validation/training-menu-2026-10-22 for automated/render/device evidence.

Training UI delivery: analyzer clean,457 tests pass/5 optional skips; signed
143.2MB1.0.0+11 installed in place and launched on creator iPhone12. Existing data
retained. Native touch comfort remains for creator review.

## 22 October 2026 — deliberate pause snapshot and unified banners

Normal pause replaces filler with actual survival/kills/bosses, health/ammo,
level/XP and equipped-kit data; active reloads show remaining time. Live
Menu/Restart and system back confirm before acting. Cancel preserves pause/run;
failed Menu saves stay in the run with a visible retry warning. Terminal results
navigation remains direct. Online leave confirms, including explicit versus
forfeit copy. GameNotice extracts the creator-approved update banner into one
shared design for update/replacement/reset/briefing/coming-soon/run confirmations;
compact notifications share its frame. Required/optional update and passive
checking semantics stay unchanged. See PAUSE_AND_NOTICE_REVIEW.md and
validation/pause-notices-2026-10-22 for tests, renders and device records.

Pause/banner delivery: analyzer clean;462 tests pass/5 optional skips. Signed
143.2MB1.0.0+11 installed in place and launched on creator iPhone12 with data
retained. Physical readability/touch comfort remain for creator review.

### Tablet landscape pass — 22 October 2026

Removed tablet gameplay letterboxing by extending world visibility, preserving phone framing and sprite proportions. Added tablet HUD/type/touch sizing and shared online geometry. iPad native configuration now enforces both landscape directions in full screen. Native iPad simulator gameplay, simultaneous controls, practice, loadout and settings renders pass; phone regression layouts remain covered. See `TABLET_LAYOUT_REVIEW.md` and its evidence folder. Hardware comfort/performance acceptance remains open.

## 22 October 2026 — ten survivors and upgrade expansion

Solo/Training now contain10 survivors,41 offered families and8 fusions. Flint,
Vesper,Fuse,Moth,Coil,Suture,Harrow have distinct generated directional art,
passives/tradeoffs and explicit settlement-based unlocks. Original stats/entitlements
remain; source-aware release ledgers prevent fan/burst/chain replay and main blast
weapons can use innate passives without acquiring primary-only explosion procs.
New-run balance2 improves bounce/spread/drone/Core choices and bounds Medic healing;
old Continue retains prior changed-formula balance. Sure Foot recovers existing
weapon weight rather than resisting nonexistent incoming slows. See
[TEN_SURVIVORS_IMPLEMENTATION_REVIEW.md](TEN_SURVIVORS_IMPLEMENTATION_REVIEW.md).

Dedicated left-run packets and broad/passing pixel regressions cover all seven;
all-direction playback, owner-scoped art leases and original Scrapper repair remain.
The assembled loadout now holds its selected gameplay weapon at the shared mount.
Existing pixel plates/tabs/control placement and1.0.0+12 identity remain. New online
survivors are gated; no server deployment or phone installation is implied.
Physical balance, continuity, comfort/audio and sustained performance remain open.

Final survivor validation: analyzer clean;494 tests pass/five optional skips.
30/60-minute developed-build simulations pass; peak selected-survivor/largest
boss-pair/Cinder decoded art25.34MiB under32MiB. iOS debug simulator build succeeds.
Evidence: validation/survivor-expansion-2026-10-22/. No phone install or server
deployment in this pass; physical acceptance remains open.

## 22 October 2026 — readable upgrade offers

Normal solo/airdrop offers now lead with a short effect description and meaningful
counts, damage, chances or timing. Raw world measurements and offer weights live
behind an inline Details action; Training opens with full values. Disclosure is
keyed to the offer/rank and cannot choose an upgrade. Late Scattershot describes
spread, and important healing gates and wounded-target conditions remain visible.
Collection and online cards share the clearer effect descriptions; online values
remain server-owned. Existing formulas, ranks, timing, card alignment and selection
contracts are preserved. Focused widget checks cover disclosure without purchase,
Training defaults, compact screens/large text and aligned Ban actions. Rendered
normal/expanded cards were inspected under build/test-previews/upgrade-*.png.
Native readability remains for creator review; no installation in this pass.

Upgrade-copy verification: `make verify` passes (analyzer clean;498 tests pass,
five optional skips). No gameplay balance changes or phone installation.

## 22 October 2026 — email identity and cloud-save implementation

Optional email/code/username setup and account Settings now use the existing pixel
notice/field/button system. Account data and owner-scoped local outboxes preserve
existing PlayerProfile progression plus selected normal-play kit. Offline Play,
Training and Continue do not await verification or cloud availability; profile
switches wait until local play ends. Online admission/server names are account-
authoritative. Two monthly renames and a versioned moderation list are enforced
on the server. The sibling backend includes private SpacetimeDB account/challenge/
session/profile tables and a Node signing/delivery service with Sendbyte/Resend
adapters. See CLOUD_IDENTITY_IMPLEMENTATION.md for scope, configuration, migration,
validation and operational gates. No production deployment, live email or phone
installation is implied. Paid billing/restore remains separate and unadvertised.

Identity verification: `make verify` passes (analyzer clean;505 tests pass,
five optional skips). Backend97 tests/module build, identity service four tests/
production compilation and disposable real-host OTP/JWKS/TypeScript+Dart socket
proof pass. Sendbyte delivery is contract-tested against the documented request;
real inbox delivery and native device acceptance remain open.

Single-server deployment correction: the root `regun-server/Dockerfile` now
packages the account process beside SpacetimeDB behind the existing port3000
proxy. Accounts use `https://regunserver.kiishi.space`; the combined ignored
release config retains Telling and that origin. Persistent publisher/signing
bootstrap, account-route allowlisting and process supervision are included.
The real root Docker image passes disposable startup/restart, public JWKS,
private-admin isolation and signing-key continuity checks; five service tests
and the original signing-state regression (inside Linux) pass. No hosted
redeployment or real email was performed. See sibling `deploy/ACCOUNTS.md`.

## 22 October 2026 — production Account settings

Settings now places Gameplay above Account. Removed email changes, standing
rename quotas/reset dates, legacy-record recovery, standalone re-verification
and the raw last-save timestamp. Username edits retain the server quota, shown
only when editing; deletion retains fresh-code confirmation within that action.
Email is fixed at the service and reducer boundary, including already pending
legacy email-change challenges. Keyboard-dismissal taps preserve the account
dialog, code and timer; explicit exits remain available during pending requests.
Email adapters always send the Regun display name with the configured mailbox.

Validation: analyzer clean;507 Flutter tests pass/five optional skips; focused
compact/large-text account checks and rendered Settings review pass. Backend97
tests/module build and nine service tests pass, alongside production compilation
and real-host OTP/TypeScript+Dart socket/reset/refresh checks. No live email,
hosted deployment or phone installation was performed in this pass.

## 22 October 2026 — planted screen transitions and Mummy walking

All active screen routes now use GamePageRoute:240ms entrance/180ms return,
fading through the existing dark game surface without horizontal motion, zoom
or interactive edge swipe. The global transition theme covers the root and
library-created Material routes; legacy navigation/router helpers agree.
Game/OS Reduced Motion cuts directly. Loadout/game replacement completion and
account local-play ownership boundaries remain intact.

The gray close-striking Mummy now uses an eight-pose, transparently generated
walk atlas referenced from its existing identity. Measured pelvis/ground
registration and reference height retain body scale; actual travel advances the
gait and facing changes retain phase. Walls, pauses and relocation do not run
the feet. Online snapshot presentation uses the same atlas and per-entity gait,
cleaned on removal/reconnection. Old attack/hurt/death art,90 movement speed,
.6-second strike cadence, collision and combat authority remain. See
art/source/enemy-animation/README.md and tool/register_mummy_walk.py.

Validation: make verify passes; analyzer clean,513 tests pass/five optional
skips. New checks cover stationary route geometry, edge drag, route results,
game/OS Reduced Motion and live Mummy turning/attack cadence. Runtime left/right
walk contact sheet inspected; art contracts pass with shared decoded art20.97MiB
under32MiB in that test. No native comfort/performance claim or phone installation
is implied; physical gait and transition review remain open.

Mummy gait correction after creator review: the first eight-pose candidate was
not accepted; leg spread/closure is not a walk. The replacement uses an explicit
contact/down/passing/up guide with swapped near/far support, visibly raised boots
in3/7 and a lowered pre-contact heel in8. Re-registered without changing body
scale or runtime combat. Runtime left/right clip and phase snapshots are in
build/test-previews/mummy-walk-corrected.mp4 and mummy-walk-motion/. Six focused
gait/art tests and analyzer pass. Shared decoded art remains20.97MiB in the
contract test; tests do not constitute creator motion acceptance.

Creator-requested phone installation: signed iOS release1.0.0+14 built in41.3s,
installed on the connected iPhone12 and launched successfully via devicectl. The
packaged Mummy walk atlas SHA-256 matches the corrected source asset. Combined
release configuration (including Telling) was used. Installation/launch does not
constitute physical gait, transition comfort or sustained performance approval.

### Boss geometry candidate (22 October 2026)

Creator rejected boss attack sprites and specifically the pre-attack arc hint.
`BossVfx` replaces boss texture stamps with deterministic chipped crescent faults,
floor fractures, faceted glass, poison seep and polygon iron links. The initial
pie-like radial tessellation was removed after rendered review. Sweep warning
now has one grounded footprint rather than stacked arc/sector/rail overlays.
Safe inner pockets, moving wave gaps and final-frame visibility are retained;
collision/timing/damage and Marshal's continuous laser remain unchanged. Native
boss actors/owned areas/impacts/weak-point art and online boss-owned hazards use
the candidate; ordinary enemy and ordnance art retain their existing renderer.
Online boss hazards bypass center-only culling so distant origins cannot hide
lanes/waves crossing view. No new texture assets or network dependencies.

Reviewed rendered material comparisons on both actual floors; see
`docs/BOSS_GEOMETRY_REVIEW.md` and `build/test-previews/boss-arcs-breach.png`,
`boss-geometry-breach.png`, `boss-geometry-foundry.png`. Analyzer passes. Full
suite passed516 tests with5 existing skips (2m29s); after final visual refinements,
all4 focused geometry/preview tests also pass. Pixel checks cover clear annular
pockets, ring escape gaps, planted warning footprints and late wave visibility.
This remains a creator-review candidate; no version bump/phone installation,
physical performance, motion comfort or visual approval is implied.

Creator-requested boss geometry phone delivery: signed release1.0.0+14 rebuilt
with the existing combined release configuration (including Telling), Xcode
build25.9s/170.6MB. CoreDevice confirmed in-place installation and launch on the
connected iPhone12. App data was not cleared. This supersedes the no-install
note for this candidate; physical readability/comfort/performance remain for
creator review.


Build15 distribution (creator requested): bumped pubspec to1.0.0+15, built the
220,422,097-byte Android APK with existing combined release configuration and
uploaded/distributed it to Firebase App Distribution's playtesters group. CLI
reported success; authenticated readback confirms release29sko3b9ktpk0/build15.
APK manifest is1.0.0/code15 and certificate matches the preceding tester build.
The matching signed App Store Connect IPA export succeeded; exported Info.plist
confirms1.0.0/build15/dev.kiishi.regun. Versioned artifact:
`build/ios/ipa/regun-1.0.0-15.ipa` (162,806,512bytes). No Apple upload or new phone
installation was requested. Hashes/metadata and tester URL are recorded in
`docs/validation/build15-distribution-2026-10-22.json`. Existing gameplay checks
from the boss-geometry pass remain the validation basis; this request changes
release identity only.

### Weapon power investigation and presentation corrections (22 October 2026)

Creator reports weak primary/delayed/AoE payoff and asks for a researched numerical
balance plan, bigger/slowing spore ground, quieter companion lightning and Rail
Lance sight. Added docs/WEAPON_POWER_BALANCE_PLAN.md with proposed values,
source research, delivery/FX-cap findings, compatibility and normal-build gates.
No combat damage/radius/slow changes were applied. Controlled real-runtime audit
records Shotgun4.32 at130 versus1.247 at330; Mortar4.5; full Spore capsule+patch2.5
against an unarmored stationary target. Standalone patch exposure at0/60/90/105
speed gives1.8/1.8/1.6/1.4, movement multiplier1. Saved evidence:
docs/validation/weapon-power-baseline-2026-10-22.json. This is not full-run proof.

Companion links now use a thin muted sage stroke with no pale core/forks/endpoint
flash; Arc/weapon chains and damage/cadence remain unchanged. Online rendering
understands an explicit companion role and the current server's.12s drone/.16s
weapon chain duration contract without requiring a server rollout. Rail now has
a steady dotted sight using the same assisted muzzle/heading and solid clipping
as firing; no sway/charge/release/mechanics change. Hide when idle, reload/empty,
entrance or blocked muzzle. Reviewed rendered floor comparisons in
build/test-previews/companion-link-quiet.png and rail-lance-sight.png.
Analyzer clean;102 focused combat tests pass, plus the final Rail render/cover
rerun after contrast adjustment. No build-number bump, installation or deployment
performed in this investigation. Physical brightness/sight and future numerical
balance acceptance remain for creator review.


## All-weapon power candidate — 23 October 2026

Read `docs/WEAPON_POWER_IMPLEMENTATION_REVIEW.md` for all21 decisions. Fresh runs
record `weaponPowerBalance:2`; Continue without a marker retains revision1 and
paid damage exactly. Do not use current enum values to silently upgrade legacy
runs. Pump1.7 per pellet; Spore1 direct/2.4 DPS, radius150,3s,12 targets per patch,
four patches/nonstacking. Field stride .75 ordinary/.85 elite, planted/boss and
committed leaps unchanged; strongest slow wins. Paid AoE/stream damage is independent
of cosmetic capacity. Bell6+2 at unchanged .55s echo; coherent stepped wave/quiet
outer resonance, unchanged weapon artwork. Four weapons retain base damage after
review (Belt/Frost/Longwatch/Cyclone); the review specifies the other numerical gains.
Server parity is prepared locally with preserved PvP damage and is not deployed.
Release identity remains1.0.0+15. Native balance, comfort and long-run performance
remain human acceptance gates; new-run power must not be inferred from legacy Continue.

## Remote power-up strength and offline preservation — 23 October 2026

The shared balance contract now includes 41 power-up strength controls (209 values
in total). Fresh runs capture them alongside base values; GameState reads immutable
strengths from that snapshot and preserves actual ranks/unlocks/fusion thresholds.
Existing combat caps still apply. Native and supported online bonus readers agree;
capability 3 is required for custom online strength. Continue embeds the original
snapshot, including old 168-value releases whose ID/hash remain unchanged.

Automatic checkpoint scheduling/lifecycle saves and RunStore recovery were not
replaced. Background refresh remains deduplicated, bounded and best effort, with
last-good cache/bundled fallback. Transport-construction failures are contained too.
No online account/configuration lookup is awaited by offline run entry.

## Dash and grenade reserve upgrades — 23 October 2026

Added Double Dash → Triple Dash and Grenade Reserve, two ranks each;43 offered
families. Stored charges refill sequentially, purchase adds only a new loaded slot,
and pause/entrance freeze recharge. Custom controls show3/4 bounded charge markers.
Admin exposes upgraded capacity totals (dash2–3, grenades3–4), validated by the
shared211-field API catalogue and pinned into new runs. Lower caps remove redundant
offers. Old snapshots retain hashes and Save/Continue retains exact charges/timers.
Server-authoritative online protocol4 includes reserve state in prediction acks;
older clients do not receive unsupported offers. See CHARGE_CAPACITY_UPGRADES.md.

## Boss recovery, grenade placement and supply cover — 23 October 2026

Boss deaths now award2 current HP beyond max and show the boss-name VANQUISHED
stamp. Capped healing never removes overflow; Continue preserves it. Grenades pass
over bodies, bounce on the floor and detonate on their1.4s fuse. Their stronger
140-unit/.32s response includes a130-unit outer non-damaging pressure band. Supply
landing adds a fixed grenade-strength blast, then the active/opened pod becomes
solid cover for movement/shots/grenades until breakdown. Player landings do no
friendly damage. Native/online contracts and the online capability gate agree.

Queen/legacy boss warnings are now floor siblings, along with arrival stamps,
shadows, deployment dust, remains, foot trails and grenade guides; the pod's body
retains depth ordering. Read docs/COMBAT_RECOVERY_AND_SUPPLY.md. No installation,
release identity change or deployment is performed by this pass. Physical feel,
cover usability, health balance and readability require creator review.

Validation for this pass: game562 passed/five optional skips, server112 passed and
module build, plus25 final focused online/recovery checks. Analyzer and whitespace
checks pass. Actual Queen floor-layer and victory-plate renders were inspected;
see build/test-previews/queen-ground-layers.png and boss-vanquished.png.

## Earned economy, goals and administration — 23 October 2026

The non-billing pass adds a six-finish compatible shop catalogue, exact displayed
quotes, purchase confirmation, cached metadata and server-confirmed cancellation
of an uncommitted purchase intent. Existing owners keep offline use, including
hidden items. Account/reset epochs and receipts remain enforced; late originals
cannot spend cancelled intent IDs. The private server catalogue has separate
staging/production immutable releases and an authenticated admin authoring path.
Combat balance, power/odds and active-run snapshots do not read economy metadata.

Collection Challenges now presents a Field Record, earned unlock progress and a
persistent pinned next goal; Results shows that goal and the centralized unchanged
Scrap breakdown. Additive schema3 career seconds/new-unlock milestones support
explicitly device-reported pacing samples without fabricated historical backfill.
Three new recolour finishes (Rust/Slate/Dusk) have real survivor previews and no
stat effect. They are not new drawn characters. Existing mastery/challenge gates
remain earned; no permanent stat tree or premium skip is introduced.

Admin → Scrap economy supports persisted drafts, review/reasons, base revision
conflicts, retry-safe publication, audit and restoring history as a reviewed new
release. Reports separate current balances, imported/earned/spent flows, confirmed
purchases and retry-inclusive request counts. Unlock medians include sample counts
and their cumulative/client-report limitations. See ECONOMY_IMPLEMENTATION.md and
REVIVE_POLICY.md. Revive rules are defined; no live revive purchase is enabled.
Billing, ads and Credits remain deferred. This pass does not deploy/rebuild the
already distributed build19; another coordinated server/app/admin release is
needed. Physical UI and commercial/pacing acceptance remain open.

## Results spacing and pause wallet placement — 23 October 2026

Pause keeps its existing controls/summary layout; only the wallet moves beside
PAUSED/TRAINING PAUSED, using compact symbols and amounts like Collection. It no
longer occupies a row inside the pause scroll body.

Results uses the available landscape width with a compact title/wallet header,
run statistics/earnings on the left, progression/build on the right and pinned
Restart/Menu actions. Long build/unlock lists use bounded pages with pixel arrows
rather than stretching the entire screen vertically. Small or enlarged-text
viewports retain a body-only scroll fallback; actions remain visible. Standard
844×390/932×430/desktop layouts require no vertical scroll. No run settlement,
rewards, restart confirmation or purchase rules changed.

Verification:16 focused layout/death/settlement/pause tests pass; analyzer clean.
Matrix includes568×320/portrait and1.5× text. Existing real-game pause/death renders
and new results-{width}-{scale}.png renders were inspected. This source change
has not been built or installed on the phone.

## Guided weapon access in Training — 23 October 2026

Training's Weapon catalogue and Pause → Weapon practice now share the same
browser. Each visit begins with **Your weapons**, using normal earned unlocks.
**Try locked weapons** exposes the remaining arsenal for unrestricted practice.
Selecting one labels it TRAINING ONLY, shows the actual career unlock requirement
and offers Pin unlock goal using the existing durable profile field. Carbine pins
`training`, matching its introduction requirement. Switching catalogue tabs keeps
the chosen group and assembled kit; browsing never silently changes an equipped
gun. A fresh visit starts with Your weapons again.

The goal panel sits with the selected weapon; it remains visible as context when
browsing the earned group while a locked gun is equipped for Training. Pinning
changes only the goal, never ownership, Scrap, challenge/mastery counters or normal
loadout preferences. Failed goal persistence shows an error. Trying a weapon does
not unlock it for normal runs. Training settlement still grants no rewards;
existing first-use introduction completion and its Carbine unlock remain intact.
Survivor/arena practice, protected health, boss/rush and fusion practice are kept.

Tests cover both actual entry points, every weapon's Training selection, normal
locks, pin persistence/failure, Carbine goal mapping, all-earned empty state,
selection/group retention, atlas release/budget, introductory flows and compact/
enlarged layouts. Real artwork was inspected in
build/test-previews/loadout-training-locked-goal.png. No server/admin changes,
release identity change, installation or deployment is performed by this pass.

## Training enemy pressure and clean Boss Rush — 23 October 2026

Training Pause → Survival practice now has Enemy pressure: Light / Normal / Horde.
Normal is the default for a fresh visit. Nearby ordinary-enemy targets are8/22/38,
with arena caps12/30/54, bounded refill batches1/2/3 and active-time intervals
.38/.16/.10s. This replaces Training's former four-enemy limit. Spawns use safe
offscreen edge candidates like normal survival (superseding the initial
340–500-unit player-centered ring after creator feedback). All three pressure
levels approach from beyond the viewport. Existing body/cover placement and
minimum300-unit separation remain; a padded viewport exclusion is enforced during
occupancy placement so arena-edge clamping cannot place arrivals on screen.
Blocked arrivals are skipped instead of using a visible spawn warning.
Pending arrivals count toward capacity. Distant offscreen Training enemies retire
without rewards so walking away cannot exhaust the arena budget. Lowering pressure
retires surplus farthest bodies without awarding kills. Normal refill was tested
after clearing a crowd and moving away, in both arenas.

Pause, picker and deployment/recovery freeze refill; long frames never build an
unbounded backlog. The pressure choice survives Restart/recovery/Rush within the
visit, but a new Training visit defaults Normal. Damage protection stays separate.
No normal-run spawn cadence, enemy stats, earned progression or rewards changed.

Individual boss selection preserves regular enemies and continues the selected
pressure. Boss Rush retires the prior bosses/regular enemies, cancels pending
arrival warnings, removes stray attacks, XP, mines, ground fire and in-flight
ordnance, and resets supply state before its boss-only sequence. It does not
award cleanup kills/XP or erase the current build. A retired actor cannot mount
later; ordinary mounting/spawning is rejected during Rush. Selecting an individual
boss exits Rush and resumes the saved pressure. Manual next-round and all-boss
practice tools remain available. The existing two-boss Rush ceiling is preserved.

Verification: analyzer clean;94 Training/director/crowd/entrance/UI/arsenal
regressions pass together. The whole suite previously passed590 tests with five
skips and exposed a fixed-build arsenal benchmark interrupted by new Training XP.
That benchmark now preserves its base/VIII build with a test-only high XP gate;
the anchor pull fixture is separated from ambient body occupancy. All65 arsenal
tests pass in the final94-test run. Physical pressure, movement space, comfort and
device performance remain creator playtest gates. No app build, version change,
server deployment or installation is performed by this pass.


### Training arrival correction —23October2026

Creator clarified that pressure means enemies approaching from offscreen like
normal survival, never popping up around the player. Training now shares normal
edge selection, with a140-unit candidate margin and100-unit excluded viewport
through body placement. Normal-run placement remains unchanged. Light/Normal/
Horde refill/caps, individual boss crowds and clean Boss Rush remain intact.
Density tests allow approach travel time; dedicated arrival regressions exercise
all three modes at center/four corners in both arenas. Physical feel remains for
creator review; no build/install is performed.

Final correction verification:94 Training/UI/crowd/director/arsenal tests pass
and analyzer is clean. Arrival checks cover Light/Normal/Horde at center and all
four corners in both arenas. Preserve a300-unit offscreen approach band when
retiring distant crowds, so incoming enemies are not recycled before entry.
The regression run also caught pending ordinary-enemy loads consulting a detached
component tree after leaving; all three legacy enemy loaders now cache their game
reference before awaiting initialization.


## Fence alignment and airdrop contact —23October2026

Creator reported the survivor standing on the south fence and asked to inspect
all edges; also reported a slightly floating airdrop. The rendered24-unit inside
perimeter previously occupied the same floor rectangle used for movement, while
its south face rises another32 units. `ArenaBounds.interior` now excludes that
visible rail/face, with shared `WallArt` dimensions. Player walking/dash additionally
keeps its actual grounded feet (38 units below center at100-unit draw size) four
units inside the south visible edge. The combat circle stays30; camera, outer
world, wall artwork, primary combat rules and Foundry pillars remain unchanged.

All four edges and four corners in Breach/Foundry are exercised with real large
movement steps, exact stopping assertions and inspected scene captures:
`build/test-previews/fence-breach.png` and `fence-foundry.png`. Top/side body/head
occlusion follows existing grounded sprite depth; feet stay within the fence.

Supply pod art already has tightly cropped frames and a bottom-center ground
anchor. Its broad shadow centered five units below the feet made it appear lifted.
Shared `SupplyPodArt.ground` now places tight chassis occlusion behind the base and
four dark contact patches directly under the front/rear feet. Native and online
presentation share the contact, planted only after landing and fading through
breakdown. Art, capture radius, collision footprint, landing damage/timing, rewards
and supply scheduling remain unchanged. Existing closed/open/landing/breakdown
captures were inspected. Analyzer is clean; the full suite passes595 tests with
five intentional skips. No build/install/version change; physical contact/
readability remains creator review.


## Solid-pod routing and breakdown boom —23October2026

Creator reported pursuers sticking against the airdrop and requested a grenade-like
boom when it breaks, matching landing impact. Native ordinary pursuit now uses a
six-node corner route around active/opened pod cover, retaining body clearance,
legal fence-side routes and a weak per-actor committed route until clear. Exact
face contact permits outward escape; large bodies aim for legal contact range
when a player is close to cover. Actual movement still goes through occupancy/
geometry with existing speed. Bosses, planted roles, force displacement and
committed leap/charge headings remain unchanged. The authoritative graph receives
the matching exact-contact and large-body target correction.

Both claimed and expired pod transitions into breaking share landing's friendly
impact:62-unit inner crush (ordinary lethal /3% maximum boss health),8 damage at
205-unit blast radius and130-unit outer pressure. Existing ember material/blast
and shell-break cues play with panel cleanup. Player health/ammo, capture/reward
and normal schedules remain unchanged. The persisted breaking phase prevents a
second blast after Continue; reset/Rush removal never calls the transition.
The matching server callback/impact helper is implemented without schema changes.

Verification: the full app suite passes604 tests with five optional skips. After
the final inclusive fence-side routing adjustment,36 focused routing/supply/
crowd/tactics tests pass together; analyzer is clean. The matching server passes
120 tests, typecheck and module build (`npm run verify`), including actual contact
routes and close-cover targets, claimed/expired damage/pressure and persistence.
Tests cover small/large body approaches from four sides, fence-constrained routes,
packs, committed attacks, actual player safety inside the blast, paused expiry
and breaking-phase restore. No app package build, phone installation or production
deployment is performed; physical navigation feel and blast fairness remain
creator review.

## Earned Solo revival (24 October 2026)

Implemented the creator's55-Scrap /five-active-minute rule across app, account
API/database, nginx route and admin. At least55 must have been banked before the
run and remain available at debit; one revive maximum. Current-run earnings wait
for the final decision. Training/co-op/Versus and legacy saves do not acquire an
allowance. The server policy defaults disabled; deployment/phone acceptance and
an explicit reviewed admin publication precede rollout. Billing remains deferred.

The death overlay uses existing pixel type, notice frame and ClickButton art,
with a compact Scrap balance next to the title, a quiet run summary, one recovery
panel and pinned End run/Revive actions. Normal844×390 and667×375 landscape renders
fit without scrolling. Large-text body content scrolls while actions stay visible.
Offline checking, uncertain spend, prepared return and Save & menu have distinct
states. No countdown, automatic purchase or repeated spending on reconnect.

Critical recovery writes replace both owner-scoped checkpoint copies inside one
serialized queue operation. Server receipts bind account/run/reset epoch; atomic
spend, status, cancellation tombstones and activation prevent duplicate debit.
Prepared recovery persists before activation/combat. Reopening it grants the same
recovery with full two-second protection, not a second purchase. Same build,
boss/enemy health and phase, half health/full magazine; grenades are unchanged.
Revived runs keep separate score/time personal bests, as clarified by the creator.
The revive prompt does not explain that distinction; final results use “Revived
best”. Ordinary rewards/unlocks retain their existing conditions, and the
one-revive cap remains independent of accessibility assistance.

See REVIVE_POLICY.md for trust boundaries, rollout and phone checks. Offline Solo
eligibility/earnings remain device-reported; receipts do not prove fair ranked
combat and this contract must not back cash value. Source changes do not deploy,
bump the current release, build a package or install on a phone.


## Original intro restored (24 October 2026)

Restored Flame → godKiishi → Menu at the creator's request. Existing native Rook
launch art stays. The original engine layers/creator bitmap and timing are reused,
with a cancellable owned timeline, paused background playback, still Reduced
Motion presentation and one-shot menu route replacement. Existing local startup
preparation remains before the intro; menu/update/account/music behavior is not
moved into it. See ROOK_BRANDING.md and startup/menu/update regression tests.

## Earned weapon Armory and account recovery — 24 October 2026

See [ARMORY_IMPLEMENTATION.md](ARMORY_IMPLEMENTATION.md) and
[ACCOUNT_SYNC_RECOVERY.md](ACCOUNT_SYNC_RECOVERY.md). Six permanent weapon unlocks
use earned Scrap at approved 8,000–15,000 defaults, with server debits/entitlements
and a reviewed admin release. Existing owners/Training/offline equipping are
preserved. Sales default off; this source pass does not deploy or install.
Refresh/upload journals and foreground retries address recoverable account-sync
failures without requiring a permanent Sync now button.

### Purchase-only policy correction

The creator withdrew grandfathering: previously gameplay-earned access to the six
shop weapons now requires Scrap purchase. Repeater is10,000. Version2 ownership
retains actual paid receipts, removes old free grants, blocks legacy checkpoint
bypasses and aligns API/admin support. The previous preservation statement applies
only to genuine purchases now. See ARMORY_IMPLEMENTATION.md for migration details.

## Upgrade offer rarity and repeat suppression — 24 October 2026

Fresh runs pin upgrade offer policy1: Double Dash and Grenade Reserve draw at
0.35 base weight initially and0.20 for the second rank, without the ordinary
owned-upgrade boost or guaranteed build-follow-up slot. Last hand's cards receive
an additional0.35 weight multiplier; they are discouraged rather than banned.
Normal owned build upgrades retain their first-slot support. Lucky Find, existing
eligibility, rank/charge caps, XP/fusions and free practice remain unchanged.

App and server share deterministic selector fixtures. Checkpointed policy/history
and RNG preserve Continue; old saves and existing server progress retain their
original selector. See [UPGRADE_OFFER_RANDOMIZATION.md](UPGRADE_OFFER_RANDOMIZATION.md).
No installation/deployment or physical balance acceptance is implied.

Verification: analyzer clean; full app suite644 passed /5 opt-in skipped. Final
policy/restore validation checks4 passed. Server TypeScript checks,137 tests and
SpacetimeDB build passed. The deterministic40,000-draw statistical check and shared
Dart/TypeScript offer fixtures passed. Source only; not deployed or installed.

## Upgrade rank implementation — 24 October 2026

Cross-project source implementation adds pinned rank policy1, per-family IV/VIII
late-growth weights, bounded empty-rank filtering, shared component previews and
read-only Collection/Training comparisons. Admin authoring and authenticated API
preview use the same versioned catalogue and projections. See
[UPGRADE_RANK_IMPLEMENTATION.md](UPGRADE_RANK_IMPLEMENTATION.md) for numerical
scope, rollout, verification and remaining physical review. Eight remains the
normal cap; low capacity limits, XP, rarity, fusion gates and prices are preserved.
This entry does not claim production deployment or phone installation.

## Early Solo boss variety — 24 October 2026

Implemented per-boss observed victory counts and a first-bag ordering that favours
less-beaten bosses, with random ties and existing all-eight/no-immediate-repeat
coverage. History/bags persist through checkpoints and cloud backup; Training is
excluded. Server validates and preserves the additive profile field; protected
admin records show the observed breakdown. Hosted co-op retains its shared
shuffle. See [BOSS_VARIETY.md](BOSS_VARIETY.md). Source only; device/deployment
review pending.

## Boss attacks clear minions — 24 October 2026

Native and module combat now clear minions through committed lunge corridors and
active boss strike geometry. Ordinary boss movement and warnings never clear
minions. Wall/body constraints, sweep safe pockets and owner cleanup remain;
collateral uses normal deaths without player rewards/procs. See
[BOSS_COLLATERAL.md](BOSS_COLLATERAL.md). No admin/ENV change; source is not deployed
or physically accepted by this entry.

## Rail Lance aiming commitment — 24 October 2026

Fixed charge increases0.45s →0.65s, with shorter recovery preserving existing
sustained firing timing and Quick Trigger limits. Damage/reload/penetration stay
unchanged. Charge sight and API/admin component previews agree; charge remains
non-editable in admin, with no new configuration mechanism. See
[WEAPON_DEVICE_REVIEW.md](WEAPON_DEVICE_REVIEW.md). Source validation passed;
physical feel/deployment remain pending.

## Rail Lance quick release — 24 October 2026

Aim-stick release now fires early while held aiming retains automatic0.65s
discharge. Normal damage/ammo and the existing firing cycle remain; a persisted
release cooldown prevents flick spam/double discharge and freezes during pause.
Actual pointer release/cancel, early fire, repeated fire, reload and save recovery
are covered by weapon tests. No API/admin configuration change is needed for this
native input behavior. Source only; device feel remains for review.

## Rail Lance power and lane control — 24 October 2026

Implemented all four approved buffs:25% more base damage, another25% at full
charge,14-unit collision diameter with matching thicker art, and stronger bounded
ordinary-enemy shove/stagger. Revision3 pins the new mechanics; revision1/2 saves
retain their previous balance. The shared catalogue now defaults to11.25 damage;
mobile/API/admin Heavy Load previews distinguish quick and charged shots. No new
admin controls or hosted weapons were added. See WEAPON_DEVICE_REVIEW.md for
rollout and physical review. Catalogue generation is not production publication.


## 2026-10-24 — three selected weapons across game/admin/API

Houndrack, Storm Orb and Ring Caster bring Solo/Training to 24. Complete behavior, art, audio, reload, bounded effects, save/restore and live numeric controls are implemented alongside admin component comparison and authenticated API preview. The shared catalog has 313 fields; historical run pinning and multiplayer admission are preserved. Read [THREE_WEAPONS_REVIEW.md](THREE_WEAPONS_REVIEW.md) and its validation evidence. Deployment/install/publication and physical balance/readability remain separate.


## 24 October2026 — weapon feedback, menu fit and Revolver identity

Current source implements a muzzle-launched slowly opening iron cutter, stronger
accelerating rockets with flat distance damage, and an orb that crosses enemies
with once-per-body bonus damage. Bounded propulsion/flight/zap/pass cues replace
the early audio. Mobile upgrade glyphs are larger, with compact offers and a
pinned reroll footer; wide admin headers put the artwork beside the copy.
Revolver owns one innate enemy ricochet without buying/granting a perk.
`weapons.revolver.ricochets` is an editable base stat, default1/integer0–3;
Ricochet upgrades add to it. Shared catalog314 fields; API/admin/rank/native/hosted
contracts and historical catalog compatibility are synchronized. See sibling
game `docs/WEAPON_FEEDBACK_REVIEW.md` for implementation and validation. No live
publication, installation or physical acceptance is implied.


## Airdrop-only reward proposal and existing cover correction — 24 October 2026

Sentry Gun and Aura Farm are planned only in
[AIRDROP_EXCLUSIVE_POWERUPS_PLAN.md](AIRDROP_EXCLUSIVE_POWERUPS_PLAN.md). The
sentry proposal includes an incoming countdown with movement-based placement,
followed by a committed landing warning; both families use finite I–III versions
and future shared mobile/admin/API/co-op contracts. No reward, art or catalogue
implementation has been made.

Separately, the requested upgrade-title spacing and existing airdrop crowd jam
are corrected in source. Native temporary-cover routing checks actual flanking
heading, preserves post-route separation and permits the alternate legal body
slide. Adjacent solids and changed destinations invalidate/rebuild routes.
Authoritative ordinary movement gains matching bounded body slides. New dense
pod/proposed-sentry-footprint cases and real mixed-enemy pursuit supplement old
isolated/straight-line tests. See AIRDROP_NAVIGATION_FIX.md for evidence and
scope. No installation, publication or live server deployment is implied.


## Combat visibility and smaller shared hurt footprint — 25 October 2026

Compact transparent boss name/health strips replace the large opaque plates;
paired identities/enrage/accessibility remain. Accepted-health-loss cues use a
.48s survivor response, stronger local brackets and .9s local/HUD loss readout,
with unchanged haptic/sound gating and steady camera. Damage uses a shared
26-unit player hurt radius; movement/cover clearance stays 30. Legacy combined
contact reaches replace their prior 30-unit player portion, while boss shapes
and hostile sweeps use the shared radius explicitly. Revenant rounds now sweep
instead of depending on frame-end collision. Native/hosted near-hit/miss fixtures
agree; legacy center-authored online areas no longer gain an extra player margin.
Read COMBAT_VISIBILITY_AND_HURTBOX.md. The creator's admin-edited shotgun values
are untouched; no catalogue generation/publication, installation or deployment
is implied. Phone visibility/comfort and difficulty remain for review.


## 25 October 2026 — airdrop support implementation candidate

Sentry Gun and Aura Farm now have temporary supply-only I–III contracts, distinct
authored mounted-gun/chassis/field art, bounded audio, native/checkpoint lifecycle,
authoritative co-op simulation and admin/API projections. Sentry commits to one
legal target and falls back after a continuous one-second reachability failure.
Both family flags remain Off in the prepared catalogue. Training Pause exposes
Sentry/Aura practice without normal enablement. This is local source work, not a
live deployment. See [AIRDROP_SUPPORT_IMPLEMENTATION.md](AIRDROP_SUPPORT_IMPLEMENTATION.md)
for exact passing checks, observed network failures and remaining hands-on gates.
Release identity preserves the creator's existing 1.0.0+22.


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
