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
