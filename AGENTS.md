# AGENTS.md

## Project Overview

**Regun** — a hyper-casual top-down shooter built with Flutter and the Flame game engine.

| Field | Value |
|---|---|
| **Name** | `regun` |
| **Version** | `1.0.0+2` |
| **Dart SDK** | `>=3.4.3 <4.0.0` |
| **Platforms** | Android, iOS, Linux, macOS, Windows, Web |
| **Engine** | Flame 1.18.0 |

## Architecture

```
lib/
├── main.dart                  # Entry point: SoLoud init, ProviderScope, MaterialApp
├── game.dart                  # RegunGame (FlameGame + collision + Riverpod)
├── components/
│   ├── enemies/               # EnemyComponent, Enemy2, Enemy3, ShadowBoss, projectiles
│   ├── game_utils/            # PlayerComponent, CoinComponent, EmptyComponent
│   ├── map/                   # MapComponent (Tiled via flame_tiled)
│   ├── movement/              # Joysticks (Movement/Weapon), Boost, GameJoystick
│   ├── ui/                    # BorderComponent
│   └── weapons/               # BulletComponent, MineComponent, ReloadComponent
├── views/
│   ├── base_view.dart         # Main game overlay: HUD, pause, game over, power-up picker
│   ├── flame_splash_view.dart # Splash screen
│   ├── loading_view.dart
│   └── menu_view.dart
├── navigation/
│   └── router.dart            # go_router: /game and /menu with fade transitions
├── notifiers/
│   └── game_notifier.dart     # GameState + GameNotifier (Riverpod Notifier)
├── theme/
│   └── palette.dart           # Palette color constants
├── utils/
│   ├── app_extensions.dart
│   ├── constants.dart         # FontFam, width()/height() helpers
│   ├── nav.dart
│   └── soloud_play.dart       # SoLoud audio wrapper (Riverpod Provider)
└── widgets/
    ├── click_button.dart
    └── home_animation.dart
```

### Key Patterns

- **State management**: Riverpod (`flutter_riverpod` + `flame_riverpod`). Game state lives in `GameNotifier` as a `Notifier<GameState>` with immutable `copyWith`. The HUD reads state via `ref.watch(gameNotifierProvider)`.
- **Game loop**: `RegunGame` extends `FlameGame` with `HasCollisionDetection`, `HasDecorator`, `HasTimeScale`, `RiverpodGameMixin`. Uses `CameraComponent.withFixedResolution(1500×700)`.
- **Spawning**: Enemies and coins use Flame's `SpawnComponent` with periodic factories. Enemy types are progressively added at level thresholds.
- **Power-ups**: On level-up (`xP == noOfCoinsToUpgrade`), game slows (`timeScale = 0.1`), two random `PowerUp`s are presented via a `FutureBuilder`.
- **Audio**: `flutter_soloud` (SoLoud engine), wrapped in `soloud_play.dart` as a Riverpod Provider. Older `FlameAudio` calls are commented out.
- **Routing**: `go_router` with two named routes (`/menu`, `/game`). Not actively wired in `main.dart` (uses direct widget `home:`).

## Development Guidelines

### Commands

| Action | Command |
|---|---|
| Analyze | `flutter analyze` or `make analyze` |
| Run (release) | `flutter run --release` |
| Build APK + AAB | `make buildAPK` |
| Build AAB only | `make build` |
| Clean + get deps | `make cleanAndGet` |
| Run build_runner (watch) | `make br` |
| Generate launcher icons | `make createLauncherIcons` |
| Generate splash screen | `make createSplashScreen` |
| iOS clean sweep + IPA | `make cleanSweepiOS` |
| Deploy (fastlane) | `make deploy` |
| Patrol integration test | `make patrolSendToBank` |

### Code Style

- Lints: `package:flutter_lints/flutter.yaml` (via `analysis_options.yaml`)
- Fonts: `PressStart2P` (400), `Orbitron` (400–800)
- Animations: `flutter_animate` for fade/slide transitions; `Lottie` for reload animation
- Icons: `phosphor_flutter`

### State: GameState Fields

The game state is a flat immutable struct managed by `GameNotifier`:

| Field | Type | Default |
|---|---|---|
| `score` | `int` | 0 |
| `gameplayState` | `GameplayState` | `playing` |
| `maxBullets` | `int` | 5 |
| `noOfBullets` | `int` | 5 |
| `health` | `int` | 3 |
| `xP` | `int` | 0 |
| `currentLevel` | `int` | 1 |
| `movementSpeed` | `double` | 300 |
| `sprintTimeDistance` | `int` | 150 |
| `bulletRange` | `int` | 420 |
| `bulletNumberRange` | `int` | 1 |
| `bulletSpeed` | `double` | 700 |
| `fastReload` / `fastReloadTime` | `bool` / `int` | false / 2500 |
| `sprintInvincibility` / `triggerSprintInvincibility` | `bool` | false |
| `bulletsPhaseThrough` | `bool` | false |
| `triggerSprintMine` / `sprintMineCount` | `bool` / `int` | false / 3 |
| `triggerEnemySpawn` | `bool` | false |

`GameplayState` enum: `playing`, `paused`, `gameOver`, `powerup`.

## Configuration

- **Dependencies** (`pubspec.yaml`): `flame`, `flame_audio`, `flame_riverpod`, `flutter_riverpod`, `go_router`, `flutter_animate`, `lottie`, `phosphor_flutter`, `flutter_soloud`, `logging`, `supabase_flutter`, `uuid`, `flame_tiled`, `flextras`, `loading_animation_widget`, `flame_splash_screen`
- **Dev dependencies**: `flutter_lints`, `flutter_launcher_icons`, `flutter_native_splash`
- **Assets**: `assets/images/`, `assets/audio/`, `assets/lottie/`, `assets/tiles/`
- **Supabase**: Initialized but commented out in `main.dart` (URL + anonKey present but disabled)

## Current implementation addendum (2026-10-19)

The overview above describes the original project. For the full functional-content implementation and current acceptance state, read `docs/REGUN_PROGRESS.md` (full-game implementation pass), `docs/REGUN_COMPLETE_GAME_PLAN.md`, and `docs/PLAYTEST_GUIDE.md` before changing systems. Four weapons, three survivors, two arenas, eight enemy roles, three bosses, thirty upgrade families, six fusions and twenty challenges are now live. `lib/data`, `lib/models`, `lib/services` and `lib/systems` hold their shared contracts; do not replace them with legacy prototypes. Flame resolves to 1.37.0 and Flame Tiled to 3.1.1 under Flutter 3.44.8. SoLoud is the audio path; unused Flame Audio and Supabase were removed.

Keep dash/reload with the aiming thumb and mirror the whole cluster for left-handed controls. Preserve normal shotgun reload timing and its original Lottie; other weapons have their own reload presentation. The 0.1× upgrade presentation is intentional. Keep player copy brief. Do not add generic Material switches to the custom pixel UI.

`make verify` runs analyzer/tests; `make soak` explicitly enables the long simulations. Physical performance/comfort/balance and platform interruption acceptance remain open. A headless soak or successful installation must not be presented as physical-device performance proof. Android APKs currently use local debug signing for private testing.

Crowd movement now combines soft intent (`EnemyTactics`) with body occupancy (`CrowdOccupancy`). Keep living enemies and pending spawn reservations separate; move enemies through `moveActor` / actor-based `moveTo` so fast attacks cannot cross other bodies. Normal enemies yield around bosses. The director counts arena, visible and pending enemies and throttles reinforcements against encounter limits; 120 remains an emergency cap, not a desired crowd size. Maintain challenging roles/attacks without filling all usable space. These limits still require physical difficulty/readability approval.


## Eight-boss candidate addendum (2026-10-19)

The five additions (Bellkeeper, Chain Magistrate, Mirror Saint, Kiln Sovereign, Last Marshal) bring the live roster to eight. Read the latest progress and Boss Rush playtest notes. ExpansionBoss subclasses own their moves; do not route new enum values into the legacy Queen branch. BossEncounterRuntime owns actor IDs and major-attack coordination; normal play remains solo encounters. Training Boss Rush randomizes the full roster with occasional distinct pairs, protected health and no normal profile rewards. Checkpoints write schema 2 (up to two actors) and still read schema 1. Expansion atlases use acquire/release leases; guard route disposal and restart during pending loads. Attack warning/damage geometry is shared. Preserve planted warning poses, short impact clips followed by living poses, and recovery/death cleanup. Build 1.0.0+7 remains a private device-review candidate; physical animation, fairness and performance acceptance are open.


## Combat presentation and Arc Caster correction (2026-10-20)

Build 1.0.0+8 replaces abstract attack circles/lines across bosses, ordinary enemies, hazards, explosions, burning ground and spawn warnings with shared material VFX. `AttackVfx` consumes `effects/combat_materials` (24 generated sprites); do not replace it with flat geometric stand-ins. Circle/segment collision contracts remain authoritative. Keep warnings planted and readable, impact poses aligned with every delayed release, floor effects below actors and viewport culling/texture/effect budgets intact. The Mirror Saint now intercepts/replays continued movement with glass eruptions and mirror crossfire; Magistrate chains reach through the predicted route and have tangible linked iron and anchors. Arc Caster starts with six charges, three damage, .75s cadence and two 85%-retention chain jumps at 240 range. Old Arc checkpoints migrate magazine/range/speed once via `weaponBalance`. Human readability, motion comfort, audio and balance approval remain open even after automated tests/installations.

Build 1.0.0+9 increases all eight bosses' open-arena reach/coverage/speed and body size. Keep the arena open. `BossKind.spriteSize` scales only child art and `bodyRadius` drives hitboxes/occupancy; never scale the root attack coordinate system. Annular sweeps preserve a rendered/colliding inside pocket. Bellkeeper warns at a fixed projected wave crossing, then releases its true moving wave; warnings must not track after commitment. Fast Shadow bolts use swept contact. Both phases of all eight bosses have a normal-health long-retreat regression, alongside pair/escape tests; physical difficulty remains for review.

## Deployment and training recovery (2026-10-20)

Build 1.0.0+10 adds Training → Pause → Take damage (custom Off/On selector). It defaults Off per visit and survives Restart/Rush within the visit. `PlayerEntrance` owns one simulation-clock deployment/recovery timeline: training death stays out of game-over/settlement, freezes combat, fades the fallen pose, eases the camera to center, deploys/lands the survivor, then refills health/ammo with two seconds of protection. Build and encounter persist. Fresh/restarted runs use the same landing; Continue cancels deployment and retains saved position. Pause/background must freeze the timeline; Reduced Motion conceals relocation and fades without pan/descent. Input/damage are gated throughout. Combat tests finish initial deployment before unrelated assertions; dedicated entrance tests exercise it. Boss bodies use arena ambient grading and contact shadows; material VFX are graded conservatively. Floor attacks use priority -10 so actors at negative world coordinates remain above them. Native pacing, blending and performance need hands-on approval.
