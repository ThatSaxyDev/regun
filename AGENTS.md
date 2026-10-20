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


## Weapon impact (2026-10-20)

Build 1.0.0+11 strengthens presentation/impact feel for all four weapons without changing damage, firing/reload timing, range/speed or hitboxes. `WeaponFeel.round` is draw size only. Primary bullet hits trigger bounded `CombatEnemy.receiveBulletImpact`; `impactResponse` supplies resistance, `impactStride` briefly reduces movement intent, and `moveTo` applies decaying displacement through occupancy/wall constraints. Keep the .24-second per-target response cooldown and avoid pellet/secondary-proc stacking. Bosses/nests/sentinels stay planted. Shared hit-flash reset restores cached boss ambient grading instead of clearing it. Do not replace pixel electrical arcs/scuffs with generic clean lines/arrows. Physical punch/readability acceptance remains open.

## Eight-rank upgrades and magazine pickup (2026-10-20)

The final +12 candidate also replaces XP pacing: read `docs/XP_PROGRESSION.md`. `XPProgression.cost` owns the accelerated per-level curve (25,50,80,115,…). Ordinary offers must spend funded XP; never restore automatic boss fallback upgrades or immediate chained screens after a selection. Four active seconds of prompt grace preserve overflow until another pickup; saves retain that grace and migrate old XP-bar progress once with `xpCurve:2`. Cores bank for explicit Fuse core actions with real recipes, capped at two banked cores/two fusion slots; surplus cores become scrap. Keep Training Fusion Practice direct. Physical progression acceptance remains open. The creator explicitly deferred phone installation of +12.

Build 1.0.0+12 expands all thirty offered upgrade families to VIII. Existing I–III stats remain; later scalar gains use `GameState.effectRank` (30% per extra rank, reaching 4.5 effective ranks). Reload and dash cooldown use a tighter 20% tail. Stored stat upgrades have explicit smaller increments; Scattershot holds its III projectile count and tightens spread at IV–VIII. Keep rank/count and effective scalar rank distinct; fusion thresholds remain III/II. Rank-VIII guard recharge is 6.5 seconds, healing tops at 22.5%, fast shotgun reload at 850ms, Quickstep at .6s. Bounce damage is capped at twice initial projectile damage; projectile/chain/effect/population caps remain.

Extended Tube refills/cancels an active reload immediately and shows a non-blocking 320ms weapon/HUD snap (`quickRefillProgress`), with reduced-motion support. It is a pickup refill, not infinite instant reloads. Bigger shotgun magazines cap future reload duration at the original five-shell timing; partial/base shotgun timing is preserved. Pause freezes the cue; firing/reload/restart cancels it. HUD must listen to the inner run ProviderScope's notifier. Read the latest playtest/progress notes; native progression/balance acceptance remains open.

## Release identity and combat correction (2026-10-20)

The creator restored release identity to **1.0.0+7** while retaining all later gameplay changes; +8–+12 above are historical candidate labels, not the current version. Installation is authorized again. XP now opens quickly at 8,18,35,59,90,… (`8+10n+7n(n−1)/2`); migrate old bar fractions once with `xpCurve:3`. Retain funded offers, prompt grace and explicit fusion. Carbine rounds have bounded ±2° heading and small muzzle offsets, then travel straight. The shotgun retains **three** pellets with a centered round (the creator clarified that size/knockback, not count, was the problem); Scattershot I–III adds two each, IV–VIII tightens spread. Shotgun draw size is now 22×11 with a 34-unit/.12s pre-resistance shove, bounded by the existing target cooldown, occupancy and mass rules. Keep damage/cadence/reload contracts. Recorded CC0 audio sources live outside packaged assets in `art/source/audio`; regenerate combat WAVs using the weapon/boss scripts and validate with `tool/preview_combat_audio.py`. See `docs/art/COMBAT_AUDIO_REVIEW.md`; native listening remains open.

## SDK, native audio and Rook branding (2026-10-20)

The laptop SDK is now Flutter 3.47.7 / Dart 3.13.5; the project minimums reflect that upgrade. `flutter_soloud` is pinned to 5.2.1 and builds its engine with Dart hooks; do not restore awaits on synchronous `play()` handles. The iOS AppDelegate owns playback-session activation and foreground/interruption recovery, while `main.dart` starts/restarts the output device without resetting voices or loaded assets. Keep in-game volume/mute settings. Phone mixer capture confirms nonzero menu/all-weapon output and zero muted SFX; native launch/foreground session tests passed. See `docs/AUDIO_RUNTIME.md`; actual speaker/listening and full interruption acceptance remain hands-on gates.

Rook's head now replaces the arrow launcher and both native/Flutter startup artwork. Source/head master stays in `art/source/branding`, opaque launcher in `app_icon/launcher.png`, and transparent padded mark in `assets/art/branding/rook_mark.png`. Keep the Android adaptive foreground **3% inset** (launcher generator 0.14.4), unmasked opaque 1024px iOS export and Android 12 safe-circle padding. `FlameSplashView` now uses Rook, prepares preferences/image, and replaces its route with Menu without a forced branding timer; Reduced Motion skips the fade. Keep startup background #161B18 and preserve the web SoLoud loader when regenerating splash assets. Read `docs/ROOK_BRANDING.md`. Release identity remains 1.0.0+7.

## Damage readability (2026-10-20)

Accepted health loss emits one light haptic (respect Haptics), a 320ms survivor cue, a 500ms stepped edge fade and actual lost HP beside the heart. Keep the camera steady. Reduced Motion omits the pale flash and softens the edge shading; warm tint and loss readout remain. Shield absorption/protection/contact cooldown must not emit health-loss cues. Pause freezes it; restart/training recovery reset it. `DamageFeedback.healthLost` is the HUD notifier; dispose it only with the game, not on restart. Large-text HUD tests cover the loss readout. Physical haptic strength/readability require hands-on approval.

## Reload audio and sharper motion (2026-10-20)

Reload cues use recorded CC0 mechanism extracts via `tool/generate_reload_audio.py`; full weapon-audio regeneration calls it after firing/impact generation. Preserve source attribution/hashes in `art/source/audio/README.md` and validate with `tool/preview_reload_audio.py`. Reload SFX gain is .32; do not restore the generic high-noise/ringing synth clicks. Recoil recovery is .14/.07/.19/.18s (Shotgun/Carbine/Revolver/Arc); muzzle visibility has its own 45ms window. Reload parts use short eased moves with planted holds and existing audio phase boundaries; Reduced Motion keeps parts/body planted. Total reload timing, shell sound schedule, damage, cadence and shotgun HUD Lottie remain unchanged. Native listening/motion acceptance remains open.

## Forward chains, longer Skitter leaps and explosion grounding (2026-10-20)

Skitter commits at <620 range with a .55s warning, 240–680-unit lunge and 1050 base speed. Choose 60% direct / 40% <=200-unit prediction once before warning; heading never homes. Account for elite/cycle speed in duration, retain crowd/wall occupancy and swept player contact. Reduced Motion omits the small sprite lift. Magistrate uses five forward chains (seven enraged), all straight rays from its center into the player-facing fan. Preserve randomized lengths/spacing/order, committed warnings, gaps, clasps and shared iron VFX; do not restore the full-circle star or endpoint branches. Stage the whole volley with `canStageBossMove` or wait; never silently truncate it under hazard capacity. Explosion bursts reuse the ember atlas through `AttackVfx.explosion`, with arena grading, planted scorch/debris, fade and below-actor priority. Existing blast damage/geometry stays unchanged. `docs/REGUN_ARSENAL_AND_LOADOUT_PLAN.md` is a proposal only: four new weapons, power-ups (including Rupture) and loadout redesign are not implemented.

Marshal's gunfire is deliberately a **continuous laser**, explicitly requested by the creator; this is an exception to avoiding generic line stand-ins. `AttackMaterial.laser` renders one uninterrupted pixel core/energy envelope through the authoritative clipped line, starting at the gun via `shotOrigin` and extending through its aim point. Hold gun pose 10 during firing and between delayed shots. Measured Fire lasts .28s, brace counter .24s, one hit each. Reduced Motion omits traveling filaments. Skitter uses `AttackVfx.lungeWarning` matte claw-gouge/scuff cues, never the same sprite strip as Marshal gunfire.

## Tactical reload and ranged-shot readability (2026-10-20)

Release remains 1.0.0+7. The creator reversed staged firing after device play: Shotgun, Revolver and Arc Caster must complete the entire reload before firing, even with held aim. They have no tactical-duration multiplier. Carbine alone retains its .70-duration manual reload with ammo remaining and skips the final bolt cue; empty reloads retain baseline. Keep existing Fast Reload ranks, shotgun timing/original Lottie and magazine pickup refill. No per-round ammo grants, interruption/closing action or full-magazine-only perk restriction remains. `reloadTactical` checkpoints preserve Carbine timing; read old `reloadPlan` snapshots by finishing the full reload, removing the former .85 non-Carbine multiplier and preventing a saved closing shortcut. Revenant shots retain their directional iron/rose dart silhouette, unchanged collision/range/speed. Shared enemy cast WAV remains generated by `tool/generate_revenant_audio.py`; lower gain/overlap limiting and prewarming live in SoLoud. Native audio/readability/balance approval remains open.

## Action music (2026-10-20)

Menu and all combat music use original 16-bar action arrangements (124/138/146/156 BPM for menu/Breach/Foundry/boss). Regenerate with `tool/generate_action_music.py` (NumPy + ffmpeg); `tool/preview_action_music.py` verifies loop continuity, formats, hashes and representative gameplay headroom. `tool/generate_audio.py` intentionally leaves music untouched. Keep existing SoLoud group gains, mute/pause/lifecycle and menu/arena/boss triggers; no additional runtime music voices. Source/review and metadata live in `docs/art/ACTION_MUSIC_REVIEW.md` / `ACTION_MUSIC_MANIFEST.json`. Physical listening, fatigue and cue readability remain open.

## Weapon distance damage (2026-10-20)

`WeaponBallistics` owns bounded primary-shot damage by cumulative distance from the muzzle: Shotgun 1.20→.90 (120–380 units), Carbine 1.10→.95 (100–600), Revolver 1.12→.98 (110–750), Arc 1.08→.98 (100–520), smooth transitions and fixed bands independent of range upgrades. Sample first swept body contact, not the frame endpoint or current player position. Piercing/bounces do not compound falloff or refresh close range; keep the final twice-original-damage ricochet cap. Chains inherit adjusted hit damage once; secondary bullets/mines/drone/burn/explosions do not apply another proximity multiplier. Clip travel to remaining range. Preserve cadence/reload/spread/speed/hitboxes/knockback and proc budgets. See `docs/WEAPON_RANGE_BALANCE.md`; physical balance remains open.

## Control size and dash adjustment (2026-10-20)

The existing persisted `ControlLayout.size` now drives the whole cluster: stick diameter 88–112 logical px, Dash/Reload touch and visual size `56 * size / 96` (default unchanged at 56px). Label it “Control size”. Use `buttonSize` for both Flame transforms and geometry bounds/separation; retain mirrored aim-thumb clustering, custom-placement overlap fallback, fixed/floating input and preference compatibility. Player dash speed is 1450 (previously 1300), about 12% faster/farther at unchanged duration. Cooldown, Quickstep limits, protection timing and collision/wall constraints remain unchanged. Native comfort/feel still need player review.
