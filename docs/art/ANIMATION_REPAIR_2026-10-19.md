# Animation playback repair — 19 October 2026

**Install status:** the new release candidate was successfully installed on the paired iPhone (`dev.kiishi.regun`). No uninstall or profile reset was performed. Device launch, human gait judgment and physical frame-time measurement are not implied by installation.

## The reported problem

The creator identified a step/hold/step rhythm in running across the game, using the menu as a clear example. Source inspection found repeated-looking leg poses, slow/inconsistent movement pacing, and animation-phase resets when changing facing. Enraged bosses could also select an idle clip during movement.

## Rejected experiment

A segmented-leg runtime experiment produced visibly undersized legs and unnatural poses. That was a rendering/design mistake, not an intended character proportion. It was removed from gameplay and menu rendering and was never installed on the phone. Its source is preserved outside the asset/runtime paths under `art/source/rejected-leg-rig/`; this is not production art. Passing a mathematical stride test did not make its visual anatomy acceptable.

## Current candidate

- Three new **complete full-body** run atlases, each containing eight poses in four facings. No separately scaled leg pieces, cropped torso composition or inverse-kinematics leg renderer is used at runtime.
- Gameplay uses the `RegunArt.survivorRun` clip definition: eight poses at a uniform 12 poses/second. The phone recording showed the 15-pose/second candidate felt twitchy, so playback was reduced by 20% without altering the art or removing poses.
- Changing aim/facing during a run preserves normalized loop phase instead of restarting at frame zero.
- Moving normal enemy clips use an even 12-pose/second cadence. Stationary Nest breathing remains slower; warning, attack, death and recovery poses are still intentional states.
- Shadow pursuit and Demon/Queen approach continue to use walking clips while enraged. Movement no longer selects the enraged idle clip.
- Shotgun reload formula/Lottie/shell cues, deliberate upgrade slow motion, damage rules, dash physics, economy and controls are unchanged.
- Shared decoded art measures **29.13 MiB**, with 25 textures / 448 source frames. Smaller decode sizes for the old idle/action-support sheets offset the extra run textures. No per-enemy decoding or unbounded new effects were introduced.

The moving preview is `build/test-previews/full-body-run.mp4`, rendered through the real sprite animation ticker. It shows all three survivors/four facings. Full-body source poses preserve complete silhouettes; source pose/limb consistency and the perceived gait remain visual review items. This report does **not** claim that generated poses are a hand-cleaned animation pack or that playback tests prove perfect anatomy.

## Verification

- Analyzer clean.
- 64 normal tests pass; four opt-in checks skipped by default (two soaks, technical-guide rendering, motion capture).
- New regression verifies four-way facing changes preserve footfall phase and an entire 60 Hz playback sample advances each pose after exactly five render updates, without longer holds, skipped poses or loop restarts.
- Full 12-loadout integration, all bosses/fusions/checkpoint restoration, real contact-death/results/restart/Menu and normal reload timing remain green.
- Native iOS release app and Android release APK build successfully. Logs and candidate hashes are under `docs/validation/animation-*`.

No physical frame-time/thermal trace or human motion approval is implied by these checks. The native build is a candidate for comparing the actual movement with the previous installed build, not a claim that every source-art issue is resolved.

## Phone recording pacing follow-up

Reviewed `ScreenRecording_10-19-2026 11-18-03_1.mp4`. Only survivor run playback changed: eight poses at 12 poses/second (a 0.667-second loop), shared by all survivors/facings in the menu and gameplay. Movement speed, source images and enemy/action/reload timing were not changed. Targeted ticker tests pass, including facing continuity and uniform five-tick pose holds in a simulated 60 Hz loop. This is playback verification, not a measurement of the phone renderer. Physical approval of the slower cadence remains open.

Follow-up validation: analyzer clean; 64 tests passed, four opt-in checks skipped. iOS release rebuilt and installed successfully on the paired iPhone (`dev.kiishi.regun`), preserving the installed app data. Logs: `docs/validation/animation-pacing-*`.

## Enemy twitching follow-up

Reviewed `ScreenRecording_10-19-2026 11-30-47_1.mov`. Found a concrete metadata bug: the atlas inspector applied a centered death-frame pivot to column four in both enemy rows. Column four of the first row is a walking pose, so scorpions especially jumped sideways on every loop. Enemy walking poses now all use their measured upper-body centroid; the final-row death anchor remains unchanged. Regenerated metadata only: no source image, cadence, movement speed, collision, attack or reload changes. A regression independently measures decoded upper-body alpha centroids for all four walking poses of Scorpion, Mummy, Ranged, Runner and Shield, catching the formerly centered fourth frame. Art contract tests pass; decoded budget remains 29.13 MiB. Native visual approval remains open.

## Static home artwork

At the user’s request, the running home-screen character and its dedicated Flame game loop were removed. A static composition of the three survivors uses existing idle artwork with a shared ground shadow and restrained lighting. No new generated assets or gameplay animation changes. Phone-sized menu preview inspected; button touch check passes.

Combined candidate: analyzer clean, 65 tests pass (four opt-in skips), iOS release built. Initial Wi-Fi installation failed because the device disconnected immediately after connecting; retry also timed out (Network.NWError 60). After the user reconnected the phone, installation succeeded. The combined release with static home artwork and corrected enemy walking pivots is now installed (`dev.kiishi.regun`); app data was preserved. Installation evidence: `docs/validation/enemy-anchor-ios-install-connected-2026-10-19.txt`. Physical visual approval remains open.
