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
