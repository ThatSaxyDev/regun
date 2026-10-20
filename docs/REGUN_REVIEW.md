# Regun: initial game assessment

**Historical assessment.** Its proposed first-version scope and completion order are superseded by [REGUN_COMPLETE_GAME_PLAN.md](REGUN_COMPLETE_GAME_PLAN.md). Use that document for current product decisions and launch requirements.

Reviewed 19 October 2026. Mobile first: iOS validation, then Android. Upload deadlines are not a constraint on game quality.

## Current implementation status

The first functionality/performance pass is implemented. See [REGUN_PROGRESS.md](REGUN_PROGRESS.md) for completed fixes, measurements, verification, and remaining work. The assessment and issue table below record the original baseline; several findings are now fixed. The creator confirmed that upgrade slow motion was intentional, so that audit finding is withdrawn. The current status of every finding is recorded in REGUN_PROGRESS.md.

## Assessment

Regun has a usable foundation for an **endless twin-stick survival shooter with roguelite run upgrades**. Its promising identity is manual shotgun aim, reload management, movement, and dashing while a build becomes stronger. Preserve those decisions. The current implementation is a prototype with disconnected progression and incomplete encounters, rather than a finished survival game.

This review distinguishes code-confirmed behavior from proposed design. Native playtesting and performance evidence must be recorded separately; an analyzer pass does not establish that the game runs or feels good.

## What exists

- Landscape setup, splash, animated menu, start, pause, resume, restart, and game-over UI.
- Camera following the player over a Tiled arena; animated player and enemy sprites.
- Independent movement and aiming sticks. A nonzero aiming direction fires automatically every 0.35 seconds.
- Five-round starting magazine, three pellets per shot, manual and empty-magazine reload paths.
- Movement speed 300; dash adds movement at 1000 for an initial 150 milliseconds. No explicit dash cooldown.
- Three starting health; contact and projectile damage.
- A scorpion chaser, a mummy melee attacker, and a ranged enemy. Intended unlocks at player levels 3 and 5.
- Randomly spawned collectible coins provide both score and XP.
- Two random upgrade choices at a level-up. Ten upgrade types are in the active pool: health, movement, dash distance, magazine capacity, pellet count, range, projectile speed, reload speed, dash invulnerability, and piercing.
- Partial mine/shrapnel and boss implementations, excluded from normal progression.
- Sound effects through SoLoud. No implemented settings, saved personal best, run history, tutorial, or persistent progression.

Actual resolved engine version is Flame 1.37.0, despite the project overview mentioning 1.18.0. The caret dependency allows this. GameState uses copyWith but its fields are mutable; it is not enforced as an immutable value object.

## The main design problem

The implemented reward loop is currently:

**Collect randomly spawned coins → gain score and XP → select an upgrade → repeat.**

Killing enemies does not grant score or create XP drops. A player can progress by collecting without killing. Combat removes danger but is disconnected from the main reward system. Coins spawn across the arena rather than reliably where the player has fought, which also makes first-upgrade pacing difficult to control.

Recommended loop:

**Fight → collect drops from defeated enemies → choose a build upgrade → overcome escalating enemies and periodic bosses → die → see a useful result → retry.**

Keep endless survival as requested. Add elapsed-time milestones and bosses to give endless play structure. A win screen or fixed-duration run is not required for the first version.

## Code-confirmed issues to address

| Priority | Finding | Evidence and consequence |
|---|---|---|
| P1 | Empty magazine can fire an extra volley and become negative | lib/game.dart:174 calls reloadBullets without returning; execution reaches pellet creation and decreaseBullets. This violates the ammo invariant and permits a free volley on an empty magazine. The reload UI currently masks the negative count. |
| P1 | Restart does not fully isolate a new run | lib/game.dart resets individual fields; reloading, pending futures, dash state, joystick state, and timeScale are not comprehensively reset. A reload started in an old run can complete in the next run. |
| P1 | Choosing an upgrade leaves the world running | lib/views/base_view.dart calls slow rather than pausing. Enemies and their damage timers keep advancing at 0.1 speed. A player can be hurt while deciding. |
| P1 | Upgrade presentation has side effects during build | The upgrade Consumer changes game speed and removes coins; FutureBuilder receives a fresh random-selection future on rebuild. Provider updates can rebuild the picker and change choices. Offers need to be generated once per level-up and stored. |
| P1 | Enemy unlocking uses a timing window | GameNotifier sets triggerEnemySpawn for 20 ms; PlayerComponent checks it on coin pickup. Multiple pickups in that interval can add duplicate spawners. Use a single progression event with an explicit unlocked set. |
| P1 | Damage and invulnerability rules disagree | Player contact with a scorpion checks the upgrade trigger; ranged projectiles check whether dash is active, regardless of the upgrade; mummies reduce health directly and ignore both. Centralize damage, immunity, death, and feedback. |
| P1 | Health is unbounded below and death checks use equality | reduceHealth subtracts without clamping. Multiple damage sources can act during one collision/update cycle. Treat death as a guarded transition at health <= 0. |
| P2 | XP levels one collectible late | increaseXP tests the old XP before incrementing it. A threshold of seven requires an eighth pickup to level up. Increment then evaluate >= and define overflow behavior. |
| P2 | Enemy health is not used by bullets | Mummy and ranged components declare health but bullet collision immediately sets them dying. Centralize hit handling, damage, kill rewards, and one-time death effects. |
| P2 | Enemy projectiles kill other enemies | Enemy3Projectile and ShadowProjectile reuse friendly-bullet collision behavior. Decide deliberately whether friendly fire belongs in the design; currently it also depends on the player's piercing upgrade. |
| P2 | Boss code is not a complete encounter | Bosses are not spawned in the active loop. Player bullets do not handle boss damage. Shadow projectiles are not handled as player damage and are not excluded from the player's movement-blocking collision filter. The demon's damage path is commented out. |
| P2 | Unbounded component accumulation | The firing SpawnComponent adds an EmptyComponent every 0.35 seconds, even when not aiming; EmptyComponent never removes itself. Coins also have no lifetime/cap and enemies have no explicit population cap. Long runs need bounded lifetimes/counts and measured profiling. |
| P2 | Controls mix coordinate systems | Sticks are camera viewport children; reload and dash are game-root children with fixed screen positions. Arena bounds and spawning depend on screen size while the camera uses a fixed 1500×700 world view and the map has a fixed placement. Device size can change gameplay and control reachability. |
| P2 | Capped and one-time upgrades remain eligible | Piercing and invulnerability can be offered repeatedly with no new effect; pellet count and projectile speed also cap without filtering the pool. Each offer should have a meaningful effect or a clearly defined fallback. |
| P2 | Wall-clock futures bypass pause and run lifetime | Reload, dash, invulnerability, enemy death, and progression trigger timers use Future.delayed. Engine pause/timeScale does not pause these timers. Use simulation time for gameplay and cancel/guard work by run lifetime. |
| P2 | Audio failure is only partially handled | Startup catches initialization failure, but later UI/game events still load and play sounds unconditionally. Concurrent first plays can load the same asset repeatedly. Preload/cache in-flight loads and support silent operation. |
| P3 | Maintenance and presentation gaps | Unused/deprecated code, placeholder metadata, no tests, no asset attribution/license manifest, stale make targets, and no verified release automation. |

Flame already provides engine background pausing by default on mobile. The gap is coordinating the app's GameplayState, input, sound, and wall-clock timers with that behavior, then deliberately resuming through a pause overlay. Do not describe this as a complete absence of background support.

## Research and positioning

[20 Minutes Till Dawn](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/) is the closest reference I found for the proposed design: its developer-authored description combines directional aim and active firing with enemy XP, build upgrades, and survival. It also illustrates the value of upgrades that interact and change how the weapon behaves.

[Brotato's mobile listing](https://apps.apple.com/us/app/brotato/id6445884925) establishes another relevant mobile survival/bullet-heaven comparison. Its wave/shop structure is a reference for clear pacing and build readability, rather than a requirement to add a shop to Regun.

The user's Vampire Survivors comparison captures the escalating survival and power-growth fantasy. Regun's manual aim, reload pressure, and dash should be its own focus. Positioning recommendation: **a mobile twin-stick survival shooter where your shotgun build grows while you dodge an escalating horde.** This is a design recommendation, not evidence that the current build has validated market demand.

## A focused first complete version

- One polished arena and one character.
- Keep the shotgun as the starting identity, with recognizable pellet, piercing, and mobility build paths using existing upgrades.
- Three dependable enemy roles: chaser, close-range pressure, ranged zoning.
- One complete, telegraphed boss with health, player damage, enemy damage, death, and rewards; periodic appearances during endless play.
- Time-driven escalation independent of player XP, with a cap/budget for active enemies and projectiles.
- Enemy-linked XP drops and a small pickup magnet; first level-up early enough to teach the build loop.
- Hold the right stick to aim/fire; auto-reload on empty; optional reachable manual reload; dash with an explicit cooldown and readable ready state.
- Intentional slow-motion, stable upgrade offers with icons, concrete stat changes, and no ineffective choices. Consider three choices after the two-choice flow is reliable.
- A result screen with survival time, kills, level, build, and saved personal best; fast retry.
- Sound/haptic controls, an unobtrusive first-run controls explanation, readable damage feedback, safe areas, and tested landscape layouts.
- Offline play without an account. Monetization, cloud saves, leaderboards, extra arenas, large arsenals, and permanent power progression can follow a successful core game.

The point of scope discipline is to finish every promise in this version. Existing unfinished mine and demon code should not be exposed until their full loop is implemented and verified.

## Completion order and acceptance gates

### 1. Establish a reproducible native baseline

Resolve SDK/plugin compatibility; launch on the iOS simulator; obtain a signed release build on a physical iPhone; establish Android release builds separately. Retain existing Flutter/Flame architecture unless a measured problem justifies a change. No broad package-major migration is necessary just to modernize the project.

### 2. Make one run correct

Introduce one authoritative run reset, centralized damage/death, a bounded ammo/reload state machine, simulation-time cooldowns, stable upgrade offers, exact-once enemy unlocking, and clean pause/restart/menu transitions. Add regression tests for state transitions and cross-run timers.

Gate: repeated start → fight → upgrade → pause → resume → die → restart cycles without exceptions, stale input, negative ammo/health, changing upgrade cards, or inherited timers.

### 3. Complete the survival loop

Move rewards to enemy deaths, separate kills/XP/score, build a difficulty director, filter upgrade eligibility, complete one boss, and tune early/mid/late run pacing. Keep endless play.

Gate: the player understands why to fight; upgrades make a visible difference; several distinct builds are possible; difficulty grows even when the player avoids XP.

### 4. Finish mobile game feel and presentation

Unify controls in viewport coordinates, test thumb reach and simultaneous movement/aim, clarify action icons, integrate cooldown/reload indicators, refine enemy/projectile contrast, add restrained impact/haptic effects, and complete menu/tutorial/results/settings.

Gate: readable on small and large phones, both landscape directions, and safe-area devices; no obscured threats or unreachable actions. Multi-touch must be tested on real hardware, not inferred from mouse input.

### 5. Prove release quality

Profile a long high-density run on physical devices. Define a 60 fps target and a measured 30 fps fallback for lower-end Android if necessary. Test interruptions, audio failure/mute, offline cold start, background/resume, repeated restarts, and all upgrade caps. Verify bounded component growth and battery/thermal behavior. Confirm asset rights and credits. Produce native archives, icon, screenshots, support/privacy pages, accurate store metadata, and a small tester feedback loop.

Gate: no unresolved crash/state blockers; measured device evidence; complete store materials. TestFlight validation precedes the public iOS release; Android signing and device QA remain separate requirements.

## Store research retained for later

Upload timing is deliberately outside the completion plan. [Apple's review guidance](https://developer.apple.com/distribute/app-review/) and [TestFlight documentation](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) describe submission and external beta review; neither substitutes for gameplay validation. [Google's testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en) apply conditionally to newer personal developer accounts. Account eligibility has not been checked.

## Verification log

- Read all gameplay components, state management, HUD/menu/upgrade flows, platform configuration, asset declarations, and build commands.
- Initial flutter analyze: 0 errors, 11 warnings, 4 informational deprecation notices; exits nonzero because warnings remain.
- Initial iOS launch blocked by flutter_native_splash's invalid Swift Package Manager headers target.
- Project-local CocoaPods selection cleared that blocker after regenerating plugin metadata.
- Installed Xcode 27 requires deployment target 15+; app/pod configuration updated accordingly. This raises the minimum supported iOS version to 15.
- Next build exposed phosphor_flutter extending IconData, which is final in the installed SDK. Its two used icons were replaced with built-in equivalents and the unused dependency removed.
- Native build/playtest outcome is appended below when available. No claims about touch feel, frame rate, or release readiness follow from static inspection alone.

- After the compatibility changes, flutter run built and launched successfully on the iOS 27 simulator. No app exceptions were logged during startup. This is a debug startup check, not a signed-device release check.
- Four isolated state diagnostics reproduced the XP off-by-one, negative ammo, negative health, and active reload surviving refill/reset. These diagnostics intentionally assert the existing defective behavior; their passing does not mean those defects are fixed.
- Repeat analyzer result after changes: 0 errors, 11 warnings, 4 info notices. git diff --check passed.
- Hands-on simulator interaction is currently limited by the computer-control tool reporting a screen capture failure; touch feel and multi-touch remain unverified.
- An exploratory widget smoke harness loaded the game but timed out while waiting for all components to mount. That harness did not pass; it is not evidence of a successful playable run or a confirmed native gameplay defect. Native interaction and a reliable integration harness remain work to complete.
