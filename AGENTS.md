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

## Breach supply drops (2026-10-20)

Breach's four authored pillars/colliders and four decorative grates are removed; Foundry solids/vents remain. `SupplyDrops` owns one timed pod, 22–32s initial delay, 55–80s after cleanup, 1.8s warning/.65s fall, 220-unit capture radius (creator enlarged it), eight seconds inside, 45s expiry, three-second claimed linger and 1.3s breakdown. Leaving pauses capture, not expiry. Landing crush is separate at radius62 + enemy body: kills ordinary roles through normal rewards, base3% max-health damage to bosses; no direct player damage. Claimed and unclaimed pods both disappear. `offerSupplyUpgrade` is an explicitly earned non-XP offer: preserve XP/level/cost, unique choices/rank caps/bans and four-active-second prompt grace; keep `supplyOffer` source across checkpoints. All timers freeze during pause/picker/entrance. Snapshot phase/claimed state prevent replayed damage/rewards; validate optional supply data. Pod/dust art uses lazy acquire/release, including pending-load restart/disposal; never spend the boss-pair texture budget on inactive supply art. Boss Rush cancels drops/releases assets. Breach Training Pause has Call airdrop. Use material dust + graded iron and objective brass UI, not hostile generic circles or explosion stand-ins. See `docs/AIRDROP_DESIGN.md` and new playtest notes; native feel/comfort/balance remains open.

## Loadout preparation and shotgun assistance (2026-10-21)

Loadout/Training now use pinned Survivor, Weapon and Arena catalog tabs, a persistent assembled-kit preview and Start/summary. Only the active catalog scrolls; switching back brings its equipped item into view. Catalogs derive from the existing enum/data contracts, retain normal unlocks and training access, and keep selections across tabs. `SurvivorPortrait.maxArtSize` is an opt-in larger preview; default sizes remain bounded. Weapon thumbnails mount only after their atlas is ready.

The creator requested a real shotgun base damage/reload improvement: **1.2 damage per pellet** (previously 1.0), still three centered-spread pellets, and **3.2s full base reload** (previously 3.7s). `ShotgunReload` owns 800ms first-shell duration and 600ms additional intervals; preserve full-reload commitment, existing Lottie, five-shell duration cap for larger magazines, Fast Reload minima, cadence/range/speed/knockback and distance bands. This supersedes earlier instructions to keep the old base shotgun timing/damage. `shotgunReloadBalance:1` migrates old reload completion/pending cues once; keep the separate `weaponBalance:2` Arc migration marker. The sibling TypeScript server and shared fixtures must match. Physical balance remains for creator review.

## Secondary ordnance and supply urgency (2026-10-21)

Release remains 1.0.0+7. `GrenadeInventory` / `GrenadeFlight` own two-charge secondary ammunition, sequential 18-active-second recharge, .25s throw separation,600-unit release, wall/body swept flight, .18s arm and 1.4s fuse. One blast only even while removal is pending. Native pause/picker/entrance freeze both; checkpoints validate optional inventory/flight and read old saves. The third action is a TAP button on the aiming side, mirrored/resized/arranged with Dash/Reload and excluded from floating-stick capture. Preserve material grenade art, two markers, pressed/empty countdown states and Reduced Motion ground path. Three new utility families reachVIII using existing effectRank: Heavy Payload(+20%), Wide Burst(+8%), Ordnance Cycle(−1.5s,min10).33 offered families; two charges remain fixed. Backend owns authenticated room/generation/sequence/capacity checks, flight, recharge and hits; online G throws and capability-gates old servers. Enemy blast8 / radius 205; PvP player damage 3.2, no self/friendly fire. Primary ammunition/reload/procs remain separate.

Mines now radius 185, damage 3.5+effective Mine rank, existing Scrapper1.4 multiplier. Shared blasts intersect body edges, respect solid cover and use `blast.wav` (.65gain,120ms overlap gate). Recorded CC0 ordnance cues regenerate with `tool/generate_ordnance_audio.py`; preserve provenance/manifest. Revenant uses `enemies/ranged_remains` prone corpse with captured facing; do not restore the kneeling atlas frame or target-dependent corpse facing. Small sprite decodes preserve the 32MiB boss-pair art budget. Breach supply capture radius 260 and expiry 50s (creator rejected60); eight-second capture stays. Read `docs/ORDNANCE_AND_SUPPLY.md`; physical comfort/balance/audio acceptance remains open.

## Skitter fairness and warning readability (2026-10-21)

This supersedes the older620-range/.55s/240–680 leap values. Skitter commits only within480 units with clear cover sight, warns .75s, leaps180–520 units at unchanged1050 base speed and rests1.4s after landing. A living Skitter within700 units blocks another while warning/jumping or for its first .35s of recovery. Waiting enemies keep moving and can still be killed; dead attackers never hold the turn. Preserve committed heading/prediction, body/wall occupancy, swept contact, damage and cycle/elite scaling. Runner warning/jump art faces the committed heading. `AttackVfx.lungeWarning` uses denser54×26 material scuffs and brighter dark-backed claw marks, visible from commitment without flashing or added texture assets. Shared native/online presentation and server timing agree. Physical pack difficulty and warning readability remain for creator playtesting.

Skitter warning art follow-up: keep the accepted dense claw path but its softer dusty-stone finish (highlight190/174/146 at .66→.84 alpha, scuffs .54→.70, restrained7-unit backing). The creator rejected the earlier bright brass-like path as poorly blended with the arena. Preserve clear initial visibility without restoring that brightness.

## Independent grenade aiming (2026-10-21)

The creator reversed the tap-only requirement after playtesting. Grenade is now its own compact drag aim control: hold/drag/release independently of movement and primary aim, with a predicted trajectory/ground landing marker from the same flight simulation. Drag length scales release speed40–100% of600; max range, damage, two charges and18s sequential recharge stay unchanged. Quick taps use current movement direction, last primary aim only when still. An8px dead zone tolerates jitter; returning an outward drag to center cancels. Hold never spends ammo or starts fuse. Keep pointer capture outside bounds, ignore second touches, cancel on pause/background/focus/lifecycle/epoch changes, preserve mirrored floating-stick exclusions and Reduced Motion. Flame tap IDs and drag IDs use DIFFERENT counters: keep drag ownership separate and accumulate canvasDelta, never compare their IDs as one channel. Shared GrenadeAim models native/online intent; aim_grenade validates finite bounded direction/power, authenticates room/epoch/sequence and normalizes direction server-side; old throw_grenade stays compatible. Do not trust client position, flight endpoints or damage. Render preview from current body/cover state; moving targets can change contact.

## Resting aim and confirmed-upgrade recovery (2026-10-21)

`WeaponHeading` turns the gun toward movement after .65 active seconds without deliberate aim, at up to 8 rad/s on the shortest route. Explicit aim wins immediately, including while reloading. Stationary holds direction; pause/picker/entrance freeze native rest timing. Reduced Motion settles after the delay without sweep. Solo and online share the model; online reads fighter fireHeld and sends local resting aim through existing movement input. Keep grenade aim independent.

An accepted XP/supply/fusion choice queues one recovery force pulse on active resume. Radius 250, secondary damage 1, ordinary shove up to 145 units over .32s with existing mass resistance, cover/body/wall constraints. Bosses/nests/sentinels remain planted. No invulnerability, extra healing, attack cancellation or primary procs. The creator explicitly added ONE instantaneous clear of hostile bullets touching the radius; later/outside bullets, friendly rounds, grenades and floor/laser hazards remain. Native dedicated confirmation events and checkpointed pending flag prevent accidental pause/menu triggers or replay; server choose() marks a pending flag consumed once after shared co-op selection. Reroll/ban/stale choices never emit. Distinct cool pixel pressure rim and upgrade_pulse.wav (.35 gain, 120ms overlap gate), not ember ordnance VFX/audio. Preserve normal rewards and protection rules. Read docs/UPGRADE_RECOVERY_AND_REST_AIM.md; physical balance/comfort/audio acceptance remains open.


## Shelter ambience and passive update checking (2026-10-21)

Preserve the approved Rook shelter painting. HomeArtwork grades the surrounding ruins darker, keeps a warm working area and shares one authored 24-second irregular voltage envelope across the bulb and reflected light. Brownouts include visible dim holds and staggered recovery; do not restore regular sine-wave breathing or full-screen flashes. Sparse drifting dust spans the shelter; brief hot flecks originate at the damaged upper-right cable, with mug steam retained. Reduced Motion holds steady illumination/dust/steam and omits sparks. Repaint only the atmosphere over the cached image; no combat atlases or bitmap replacement.

A pending home update check must leave taps, focus and underlying semantics enabled. Only an actual update notice is modal. The passive checking label ignores pointers and owns transparent Material/explicit undecorated text styling so Flutter's diagnostic yellow underline cannot leak in. Preserve required-policy retry/offline behavior and home-route lifecycle scope. Native visual comfort remains for creator review.


## Public build 8 and shelter demo correction (2026-10-21)

Current release identity is now **1.0.0+8**, superseding +7 above. `lib/config/release_features.dart` owns the single `ReleaseFeatures.onlinePlay = false` release gate. Home Online stays visibly gray with Coming Soon and opens the dismissible custom stepped-metal notice; it must not navigate into OnlineView or connect a room. Set that constant true to restore the existing online flow on the next build; do not silently flip it before this candidate ships. Tests cover the release default, large-text/compact popup, dismissal and enabled callback.

Home ambience must visibly vary within any five-second demo. Irregular power contacts now produce more frequent dips/recoveries; dust and brief cable sparks remain sparse. Never cover the bulb with an opaque gray quadrilateral: use a feathered, rotated local attenuation gradient so painted pixels survive the dim state. Preserve the darker surrounding grade, Reduced Motion steady frame, cached painting and unchanged menu layout.

## Full dash protection and lighter warnings (2026-10-21)

Build identity stays1.0.0+10. Dash now protects against every damage source for its entire movement window; `damagePlayer` also gates active boost against component/notifier order. Phase Step adds70ms recovery plus15ms per later rank. Shared damage paths must preserve guard/HP/feedback on avoided hits. Pause freezes protection/dust; lingering attacks can hurt after landing. Native grounded dust uses existing bounded CombatEffect lifetime; Reduced Motion emits one puff. Skitter's lighter `effects/ground_motion` scrape path retains committed heading/.75s warning and fairness timings. Boss arcs use sparse clipped scuffs and lower material stamps; preserve full damage/safe-pocket geometry. Marshal uses `effects/marshal_aim` separated planted body/gun and shared `MarshalAim`/server `marshalMuzzle`; each committed volley/counter originates at its own barrel. Select facing from the committed segment, including delayed shots crossing the body. Online articulation requires muzzleProtocol2. Keep continuous beam clipping and existing attack width/duration. Small new atlases decode192/256; five expansion atlases now decode576 to retain the32MiB pair budget. See docs/art/COMBAT_READABILITY_REVIEW.md. Online server rollout and physical approval remain open.

## Scrapper speed (2026-10-21)

The creator finalized Scrapper at **+50% movement speed** (base450 vs Rook300/Warden270), retaining −15% direct damage, pickup reach and mine benefits. Description must match. survivorSpeedBalance1 migrates old stored Scrapper speed by+150 once without losing upgrades; speed resets use character.speed. Online prediction/server/fixtures match; competitive mode remains Rook. Physical balance remains for creator review.

Warden follow-up (2026-10-21): creator finalized **−13% movement speed**, base261, stated explicitly in the description. Keep two extra hearts and the guard. survivorSpeedBalance2 subtracts9 from older Warden stored speeds once while preserving upgrades; retain the version<1 Scrapper migration. Server/client prediction/fixtures agree. Scrapper450 and Rook300 remain.

## Scrapper final speed clarification and left run (2026-10-21)

The creator clarified **+15% speed**, base345, NOT the uninstalled +50% candidate. Description, server/prediction and fixtures must agree; retain−15% direct damage. survivorSpeedBalance3 adds45 to original Scrapper saves or subtracts105 from marker1/2 candidate saves once, preserving upgrades; keep Warden's prior−9 migration for marker<2. Scrapper's old west-facing row had wide strides in every frame: the dedicated full-body characters/scrapper_left_run atlas now supplies8 poses with narrow passing steps3/7. Both native and online use survivorRunFrame. Preserve12fps and facing-phase continuity, other facings and action/weapon timing. The new atlas decodes320 and original Scrapper run832 to retain32MiB boss-pair budget. No procedural leg rig. Native comfort/animation approval remains open.

## Build11 remote Online policy (2026-10-21)

Current version1.0.0+11. No compiled onlinePlay=true gate: Home reads public /features with schemaVersion1 / booleanonlinePlay from regunserver.kiishi.space. Runtime server REGUN_ONLINE_PLAY_ENABLED=true/false (defaultfalse, strict validation) controls policy plus nginx admission. Apply env by restarting/redeploying server, no phone rebuild. Keep no-store headers, fail-closed unknown/error/timeout behavior,4s coalesced checks, no persisted enabled value and passive Online-only checking state. Refresh on Home entry/return/foreground,30s visible Home and before opening Online; solo taps/semantics stay usable. Preserve authoritative auth/room checks. Do not claim rollout from local tests: actual production named volume/key continuity is still unverified, and server changes remain local pending that check. Read docs/ONLINE_REMOTE_TOGGLE.md.


## Burst Rifle tactical reload correction (2026-10-21)

The creator explicitly added Burst Rifle to the tactical-reload weapons after phone review. With ammo remaining, manual reload uses.70 of its2.0s base (1.4s before Sleight of Hand), seats the magazine at82% and skips bolt pose/audio. Empty reload remains2.0s with seating42%/bolt82%. Both finish completely before firing. `WeaponType.supportsTacticalReload` covers Carbine and Burst; restore their saved `reloadTactical` flags and existing durations, while older full-only Burst snapshots retain full timing/bolt cues. Keep shotgun/revolver/Arc reload contracts. This supersedes the earlier Carbine-alone rule only for Burst Rifle. Fifteen-weapon target is still active; current solo roster isfive and expanded online admission is pending.

## Fifteen-weapon native candidate (2026-10-21)

The solo roster now has fifteen primaries (four original plus eleven additions).
Read docs/ARSENAL_IMPLEMENTATION_PROGRESS.md and docs/FIFTEEN_WEAPON_PLAYTEST.md.
ArsenalSystem owns Rail/Rivet/Cinder/Disc/Mortar/Belt/Frost/Prism/Spore/Hammer modes;
keep BurstFireClock's separate rounds and accepted tactical/empty reload. Frost
fires three simultaneous pellets with a real .6s ordinary mobile-enemy freeze,
.2s recovery and 1.2s post-thaw immunity. Planted roles/bosses resist freeze.
Cinder's innate burn is separate from Hot Shot. Shared actor IDs, owner ledgers,
finite flight/payload/patch saves, secondary damage and proc/population limits
must remain authoritative. Selected weapon packets and hammer poses use leases;
preserve pending-load disposal and the 32 MiB boss-pair art budget. Hammer hand
sockets and hit sweep share measured pose geometry; do not rotate root actors.
Aim Assist uses shared alignment/range/clear-sight checks. Prism shows heat/vent,
large magazines use proportional markers, and Cinder/Prism own one sustain voice
per firing interval. Stop/pause/reload/restart/disposal cancel late loads too.
Training exposes all fifteen; normal unlocks use settled lifetime boss counts.
The online lobby still admits only its four supported originals; ten new native
modes are not authoritative online implementations. Keep capability gates until
those server/client contracts are implemented and reviewed. Identity remains
1.0.0+11. Physical motion, comfort, sound, balance and performance remain open.


## Weapon phone feedback correction (2026-10-21)

See docs/WEAPON_DEVICE_REVIEW.md. Live roster remains15; Longwatch Sniper replaces
Breach Hammer (legacy keys alias). Hold primary aim then release for Sniper and
near/far Mortar/Spore shots; cancellation/center return spends nothing. Preserve
Cinder's bounded advected flame stream, cover clipping and post-release tail; never
restore stationary painted stamps. Reaper outbound/return lifetimes must release
all reservations. Repeater70/.085s with audible spin-up; Prism18/cap24. Pump draw28×14, Frost draw
24×15 and Rail draw48 do not alter hitboxes. Training pause weapon changes preserve
the run/build and replace primary resources safely across pending loads/disposal.
Loadout portrait idle respects Reduced Motion. Original shotgun/reload contracts
remain. arsenalReviewBalance:1 migrates changed base resources once. Physical
review remains open; installation/automated tests are not physical acceptance.


## Combat material and final weapon review (2026-10-22)

Read docs/COMBAT_MATERIAL_AND_WEAPON_REVIEW.md. Reaper returns home to the live
gun every step; retain bounded return/catch cleanup. Belt100 base rounds ramps
.085→.040 over8 active firing seconds; release/reload cancels, pause freezes. Keep
sampled bounded muzzle offsets aligned with the flash, including mirrored guns.
Frost2.2/pellet versus Pump1.2; sniper primary armour-piercing rounds retain.40
frontal shield damage, two hits versus normal8HP. Rivet remains a crowd-demolition
gun:1.75 splash per charge/radius125, visible copper pins, dead-host.12s fuse,
existing two-per-host/eight-total/grouped-secondary rules. Every Spore capsule
ruptures: gameplay patch creation must not be discarded under decorative FX cap;
evict a cosmetic cue while keeping40 total/four-patch limit. arsenalReviewBalance2
migrates changed Belt resources once; its upgrade/save capacity limit is128.

Grounded areas atlas replaces repeated tall circular stamps. Floor warnings and
heavy impacts stay below actors; committed circle/sector/ring damage contracts
remain. The creator superseded the previous Skitter claw-strip warning: use the
shared fixed stone-notched route and landing footprint, like aimed weapon previews.
No travelling/flashing arrows. Solo HP loss adds a subtle multiplayer-style edge
vignette (.22/.11 Reduced Motion), preserving center clarity, pause/reset/gates.
Bursters walk on boots: four-facing burster_walk atlas, actual-distance native
gait, fixed feet; no float or procedural leg rig. Warning/death use original poses.
Shared arsenal decode640, walk384/oldBurster320 and area256 retain32MiB pair budget.
Current release1.0.0+11; new guns still online-gated. Physical review remains open.


## Universal tactical reload and sniper fatigue (2026-10-22)

Creator now explicitly requests both reload modes for ALL weapons, superseding
Carbine/Burst-only restrictions and earlier non-Carbine timing preservation. Read
docs/RELOAD_AND_SNIPER_FATIGUE.md. Manual with ammo uses.70 of existing/upgrade-adjusted
duration and skips final pump/bolt/locking pose/audio. Empty retains full baseline.
Keep full completion gating, missing-shell formula/five-shell cap, tactical shell
spacing420ms, normal shell spacing600ms, existing Fast Reload cues, pause clocks and
Continue's selected duration/consumed cues. Legacy staged plans still finish full.

SniperSway is a ballistic heading offset shared by assisted sight/muzzle/shot:
.18° initial envelope→.85° cap in6 active aiming seconds; rest recovers2s/s. Capture
the release direction BEFORE cancelling aim. Preserve fatigue/phase across Continue
without restoring input; old saves start rested. No camera sway/random release
spread or Aim Assist erasure. Damage/range/cadence/pierce remain. Release1.0.0+11.

The six-weapon proposal below was subsequently approved and implemented; see the
latest addendum and docs/ENDGAME_WEAPONS_REVIEW.md for the current21-weapon roster.
Local online reload parity is updated; no server rollout or expanded lobby admission
is implied. Physical feel/motion/audio acceptance remains for creator review.


## Endgame arsenal and walking weight (2026-10-22)

The creator approved implementation after checkpoint commits client6f9f2b3 /
backend810244b. **21** solo/Training weapons now include Twin Verdict, Flak Regent,
Anchor Engine, Faultline Driver, Cyclone Breacher and Mourning Bell. Append-only
IDs and provisional33/36/40/44/48/52 boss-victory unlocks preserve old progress.
Read docs/ENDGAME_WEAPONS_REVIEW.md and the approved SIX_WEAPONS_AND_WEIGHT_PLAN.md.
WeaponMobility applies0–7% walking penalties ONCE after the survivor/upgrade
baseline; never modify saved movementSpeed. Dash remains1450. Authoritative server
walking uses the same fixture; local prediction consumes server snapshot speed.
No new online weapon admission or server rollout is implied.

EndgameArsenal owns bounded committed fields/lanes/echoes. Reserve FOUR projectile
slots for each Flak shell before ammo; fragment fans are secondary and exclude the
direct owner. Anchor pull selects one intent/body/step, caps55 units/device through
moveTo occupancy and leaves bosses/zero-response bodies planted; two devices incl.
flights/residue. Faultline has three committed sections, six owners, one hit/owner.
Bell has five original owners and echoes only survivors still in its original
cover-respecting cone. Validate/save finite phases and ledgers, never held input.
Twin has one combo application per original shot, .8s alternating-barrel pairing;
miss/reload/Continue clears uncommitted combo state. Cyclone5 pellets grows to9,
then tightens, with deliberate .60 far floor beyond its210–300 falloff band.
All use70% tactical reloads without empty-only closing motion/audio. Fast-projectile
upgrades and Training swaps cap stored speed at2000 so developed saves remain valid.
Generated alpha masters/prompts/measured sockets live in art/source/weapons/endgame;
all six224×112 packets lease individually. Shared+largest boss pair+one packet is
31.84375MiB, under32. No procedural replacement of sprite mechanisms/material VFX.
Automated coverage443 passed/5 optional skips; backend91 passed. Physical feel,
audio, balance and sustained device performance remain creator review gates.


## Heavy-weapon feel and quiet player Guard (2026-10-22)

The creator rejected the six weapons' muted feel and explicitly permits authored
code/pixel geometry where it suits the art better than atlas images. The game's
palette, material, scale, readability and attack geometry remain authoritative;
not every effect must be a reused sprite. Read docs/HEAVY_WEAPON_FEEL_REVIEW.md.

Twin now brands for1.25s, then the opposite barrel hits1.8× (4.5 base) and creates
one220-unit iron crossburst, capped at two other owners/1.8 base damage each.
Secondary damage cannot proc/prime/recurse. An opening kill cocks the opposite
barrel for the next victim; a living target change/miss/reload/Continue clears the
old pairing. Keep original-shot ledgers, owner exclusion, cover and no extra ammo.
Brass chamber cues, a visible twin brand and recorded prime/verdict cues expose it.
Bell's creator-requested bright warm-white stepped pressure pulse/short pixel wake
belongs ABOVE the floor, with a distinct cooler bright echo, not dusty AoE paint.
Its damage/committed cone/5-owner rules stay unchanged. Faultline uses bounded
section fractures, Anchor jaws clamp with separate plant/crush audio, Cyclone cycles
three muzzle ports and stronger bounded impact motion, Flak uses grounded bursts.

Flak's sub-pixel range remainder can stop moving in Vector2 storage: resolve within
.5 unit, on actual stall, or range/speed+.12 active seconds (hard3s ceiling), exactly
once. Reserve fragments before primary procs, preserve direct-owner exclusion and
cover. Never leave a paid shell hovering for the old3-second fallback.

The unsettling ring from the creator's photo was player Guard calling enemy-style
AttackVfx.armour (six chain/shield stamps). Player Guard now uses one steady small
pixel shield beside the feet; do not restore debris/chain pieces around survivors.
Keep protection/guard recharge mechanics intact; enemy armour presentation is separate.
Audio layering changes only the six; older audio files remain byte-identical.
122 expansion cues verified, review mix peak.6483.448 Flutter tests passed/5 optional
skips; no new textures, weight/reload contracts and older weapon stats stay intact.
Physical feel/audio/comfort still require creator review.

## Weapon-proportionate enemy reaction (2026-10-22)

The creator requested real physical response across ALL21 weapons, proportionate
to their purpose/weight. WeaponReaction owns the explicit force/decay/brief stagger
profiles, independent of damage/procs/WeaponFeel drawing. This supersedes older
impact distances. Preserve .24s per-target force gating, >125% stronger replacement
without accumulation, and separate .65s hard-stagger recovery. Normal/mummy/elite
can briefly hold pursuit/ordinary attack clocks and pose; shields receive .35 force
and braking without a full hold; bosses/nests/sentinels remain planted. Every shove
uses actor occupancy/walls. Blasts push radially; declared secondary reactions stay
secondary for procs. Lingering burn/spore ticks do not shove. Freeze retains ice-hit
force; death clears pending physics/holds and unfreezes death art. Match admitted
backend weapon/ordnance responses and shared fixture without expanding online
admission. See docs/WEAPON_ENEMY_REACTIONS.md; physical balance remains for review.

## Training pause and shared settings (2026-10-22)

Training pause now pins Menu/Resume/Restart/Settings above its scrolling practice
list. Settings owns Controls; do not restore the duplicate pause Controls editor.
Weapon/Survival/Supply/Boss/Fusion sections default collapsed, with 180ms eased
reveal and immediate Reduced Motion/OS Disable Animations. Remove collapsed content
after exit to release art and exclude hidden input/semantics. Boss Practice unifies
random rush/next round and individual bosses. Weapon Practice uses the same leased
WeaponThumbnail as Loadout, all21 silhouettes, selected marker and magazine count.
Key thumbnail state by weapon and release pending acquisitions after disposal.
Only the first-run guided visit shows tutorial hints/Skip/Ready; ordinary or
completed-player Training visits must not mount them. Shared Settings/Controls
use grouped spacing, label/value above 48px tracks and adaptive choice rows. Keep
preference bounds/mirroring/arrangement unchanged. Online Menu is top-right with
roster space; its match menu opens the shared Settings without pausing the match
or enabling input. Read docs/TRAINING_MENU_REVIEW.md for review scope.

## Run summary and banner consistency (2026-10-22)

Normal pause shows only recorded survival/kills/bosses, health/ammo, level/XP,
reload time when active and the equipped kit. Keep navigation pinned and Training's
practice UI separate. Live Menu/Restart and system back require explicit
confirmation; cancellation leaves the game paused. Menu saves for Continue and
must stay in the run with a visible warning if saving fails. Restart only resets
after acceptance. Results navigation stays immediate. Online leave confirms and
warns about a versus forfeit without changing live-match pause semantics.

All dialog banners now use GameNotice/GameNoticeActions, extracted from the
creator-approved update banner: stepped charcoal surface, brass edge/inset line,
context heading, pixel title, paper body and shared spacing. Saved-run replacement,
reset, briefing, coming-soon and run confirmations must not revert to plain Material
dialogs. Compact save/online notifications use GameNoticeStrip. Preserve passive
update checking (never modal), required policy/retry/offline/store behavior and
optional Later. Cancel has initial focus; do not stack duplicate run dialogs.
See docs/PAUSE_AND_NOTICE_REVIEW.md. No gameplay stats or balance change here.

## Tablet presentation (2026-10-22)

`GameLayout` / `ArenaViewport` retain phones' 1500×700 framing and extend tablet world visibility to fill the available aspect without stretching sprites. At shortest side >=600 logical pixels, tablet text/HUD/controls use 1.25 presentation scaling; preserve raw persisted control preferences and compose user text scaling. Solo/online rendering and grenade power must use matching displayed geometry. Resize cancels held input and relays out controls. iPad is landscape-left/right, full screen (`UIRequiresFullScreen`); do not restore portrait or multitasking that bypasses the orientation lock. Native simulator evidence and physical acceptance limits live in `docs/TABLET_LAYOUT_REVIEW.md`. Enemy reaction timers advance before sprite hold selection; death clears freezes/stagger/displacement and resumes animation.

## Ten survivors, source-owned passives and41 upgrades (2026-10-22)

Solo/Training now have10 survivors (Flint,Vesper,Fuse,Moth,Coil,Suture,Harrow added),
41 offered upgrade families and8 fusions. Read TEN_SURVIVORS_IMPLEMENTATION_REVIEW.md
and the approved TEN_SURVIVORS_AND_POWERUP_PLAN.md in docs. SurvivorRuntime owns
active-time charges/gates/counters and saved release ledgers. Burst/fan/continuous
and delayed attack ownership must not repeat passive spending. Main Mortar/Anchor
blasts carry weaponHit/release provenance for innate passives but stay excluded
from acquired primary procs. Grenade/burn/secondary attribution remains distinct.
Flint needs real ammo-restoring reload completion; Vesper needs finished dash;
Suture cannot revive or stack kill heals. Original three stats/achievements stay.

New-run buildBalance2 changes bounce,spread,drone,Core and Medic gate; Continue
without it uses prior changed-formula balance. Sure Foot recovers walking weight;
there is no incoming player-slow system. Support/capped offers must produce real
benefit; Core needs Arc/Static, Faraday may use Coil. Preserve XP funding/grace,
explicit cores, six special families and two fusions. New online roster is gated.

All survivor art leases with its owner. Dedicated left packets use measured floor/
torso anchors and explicit flipX on opposite-side source phases. Keep both contact/
passing gait halves,12Hz phase continuity,original Scrapper fix and pending-load
lease guards. Loadout holds the selected real weapon at the gameplay mount; do not
restore a detached floating gun. Keep charcoal/brass pixel UI,brief player copy,
Reduced Motion and release identity1.0.0+12. Physical balance/animation/comfort and
sustained performance remain creator gates; no installation or rollout is implied.


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
