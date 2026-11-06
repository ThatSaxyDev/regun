# Regun desktop plan

**Planning date** — 5 November 2026  
**Scope** — Native macOS and desktop web, with mouse and keyboard and controller support.  
**Status** — Local desktop review builds are available. Physical controller, 120 Hz pacing, and live Online acceptance are open.

## What desktop needs to deliver

A player can start a run, aim and fight, choose upgrades, pause, continue, and restart with their chosen device. Mouse aim stays aligned while the player moves, the camera follows, or the window resizes. A larger display improves clarity while keeping encounter visibility within a deliberate limit. The desktop review build covers the complete game on macOS and web. Training provides repeatable combat scenarios alongside full Solo and Online checks.

## Starting point

| Current implementation | Desktop work |
|---|---|
| Solo reads Flame touch joysticks directly, and parts of the loop treat a nonzero aim stick as fire intent. | Separate aim and fire. Audit all readers, including charged weapons and grenade fallback. [Player input](../lib/components/game_utils/player_component.dart) · [Solo game loop](../lib/game.dart) |
| Online already has WASD/arrows, Space, R, G, and F bindings and computes a separate camera transform in its painter. | Reuse familiar bindings and share player actions. Invert the transform that actually drew the arena. [Online arena](../lib/widgets/online_arena.dart) |
| A shortest side of 600 logical pixels triggers a tablet UI scale and aspect-dependent field of view. | Define a desktop layout policy with bounded visibility and a separate HUD scale. [Game layout](../lib/presentation/game_layout.dart) · [Arena viewport](../lib/presentation/arena_viewport.dart) |
| Web already loads SoLoud. Run checkpoints and account cache use native file APIs. Source assets total about 168 MiB on disk. | Prove browser persistence and measure actual compressed startup transfers and decoded memory separately. [Web bootstrap](../web/index.html) · [Run store](../lib/services/run_store.dart) · [Account storage](../lib/services/account/account_storage.dart) |

## Input and aiming

| Action | Mouse and keyboard | Controller |
|---|---|---|
| Move | WASD with normalized diagonals | Left stick with analog speed |
| Aim | Hover in the playable viewport | Right stick, retaining heading on release |
| Fire | Primary click or hold, interpreted by the weapon | Right trigger with separate press and release thresholds |
| Dash | Space | Left bumper (LB / L1) |
| Reload | R | West face button (X / Square) |
| Aim and throw grenade | Hold secondary click or G to preview, release to throw | Hold left trigger (LT / L2) to preview, aim with right stick, release to throw |
| Pause | Esc | Menu / Options |
| Menu navigation | Mouse, Tab / Shift+Tab, or arrow keys | D-pad or left stick |
| Confirm / back | Enter / Esc | South / east face buttons (A / Cross and B / Circle) |
| Select an upgrade | Click or press its displayed number | Move focus and confirm |

- Playtest these defaults using a mouse, Mac trackpad, Xbox controller, and DualSense. WASD keeps movement beside reload and grenade, while Space gives dash a dedicated thumb input. LB/L1 lets controller players dash while keeping both thumbs on the sticks. Check that LT/L2 grenade aiming stays comfortable while moving. G provides a grenade input for trackpad players. Use physical key positions for default movement and show labels appropriate to the keyboard layout. Keep incidental mouse movement and controller drift from changing prompts or focus. [Flutter focus](https://docs.flutter.dev/ui/interactivity/focus) · [W3C Gamepad specification](https://www.w3.org/TR/gamepad/)
- Use one set of actions across devices, with Solo and Online consuming them through their existing gameplay paths. Keep movement, aim, firing, and grenade charge distinct. Preserve charged-weapon behavior and keep the established touch gesture and reload rules. Use direct stick aim for the initial controller review. Assess assistance separately, including its effect on competitive play.
- Clear held actions and cancel grenade aiming on focus loss, pointer cancellation, disconnect, modal entry, and route change. Require a fresh press after return. Solo can pause and checkpoint. Online should neutralize local inputs while the server keeps running. A click to confirm an upgrade or regain focus must never also fire. [Browser page visibility](https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API)
- Start with a compact pixel crosshair with a dark outline and clear center, stable logical-pixel size, and adjustable size and contrast. Hide the system cursor only over active combat. Use peripheral marks for reload and charge feedback. Compare a short directional controller reticle against a projected point in Training. Keep grenade trajectory and landing markers separate. [Hades II input support](https://www.supergiantgames.com/faqs/hades-ii/)
- Derive the aim ray from the current screen-to-world transform and the player's weapon position. Recalculate even when a stationary pointer sits over a moving world. Verify the ray before weapon spread at the corners, map edges, and during boss camera moves. In Online, use the painted viewport and keep aim intent and authority within the existing transport model.

## Windowing and scale

- Desktop Solo and Training use a 1,080-unit world height and adapt from 16:10 through 2:1. The camera shows more of the arena and keeps actors at a smaller screen size. Gutters cover aspect ratios beyond that range. Online retains its existing framing pending competitive visibility review.
- Anchor the HUD to the playfield, cap menu and upgrade card widths, and expose UI scale independently of camera zoom. Provide clear keyboard and controller focus across the whole run loop. Show prompts for the active device and retain touch for hybrid browsers.
- Review 960×540 logical pixels, 16:10 MacBooks, 1440p, 4K/Retina, and 21:9. macOS opens at 1280×720 content points when the display can fit it and enforces a 960×540 content minimum. The desktop web shell measures its own viewport and shows a dedicated landscape-required screen when the viewport is square or portrait. Widening restores the mounted route. Active Solo play pauses and Online sends neutral inputs while the match continues. Verify browser zoom, resize, moving between displays, and fullscreen transitions. Restore the macOS window inside the available display. Use an explicit fullscreen action in the browser and retain a usable windowed mode. [Flame camera](https://github.com/flame-engine/flame/blob/main/doc/flame/camera.md) · [Web fullscreen](https://developer.mozilla.org/en-US/docs/Web/API/Element/requestFullscreen)

## Desktop settings and controls

- During mouse/keyboard or controller play, hide both on-screen sticks and the Dash, Reload, and Grenade buttons. Keep the crosshair or controller reticle, the combat HUD, and contextual prompts for the active device.
- Desktop text starts at 125% of the previous baseline, before the player’s UI scale setting. Solo time, kills, health and ammo use larger dedicated readouts. Give desktop Controls separate **Keyboard & Mouse** and **Controller** sections. Keyboard & Mouse covers bindings and crosshair size and contrast. Controller covers button bindings, stick dead zone, and aim sensitivity. Each section has its own reset to defaults. Players can configure either device regardless of which one currently drives the prompts.
- Allow primary and optional alternate keyboard/mouse bindings for gameplay actions, including a keyboard alternative for fire. Allow controller gameplay button and trigger remapping and a left/right stick swap. Use a visible menu navigation mapping during rebinding so players can always cancel or restore defaults. For conflicts in the same context, show the affected action and offer swap, replace, or cancel as applicable. Apply one action per press and update prompts immediately.
- Persist the two input profiles independently on the device. Include a live stick preview for tuning dead zones and aim response. Verify custom bindings across Training, Solo, and Online, plus browser refresh and macOS relaunch. Review the defaults with a fresh profile and the customizations without relying on a second input device.
- Keep stick placement, handedness, floating sticks, and touch control size in **Touch** settings. On desktop web, expose that section when touch controls are available and let players select touch mode on hybrid devices. Keep native macOS Controls focused on desktop input.
- Put fullscreen, UI scale, and the frame-rate cap under **Display**. Keep shared audio and accessibility settings available to every input method. Verify the full Settings flow with keyboard and controller, including rebinding, conflict resolution, cancel, and restoring defaults.

## GPU acceleration and rendering budget

Flame draws through Flutter's Canvas API, so its sprites, effects, and custom painting use Flutter's rendering backend. This covers graphics. Regun's Dart game loop still handles crowd movement, collisions, AI, projectile simulation, and input on the CPU. Profile the two costs separately. [Flame rendering](https://docs.flame-engine.org/latest/flame/rendering/rendering.html)

| Target | Starting path | Verification |
|---|---|---|
| macOS | Impeller with Metal. Flutter documents Impeller as the macOS default from 3.47, and the current runner has no explicit opt-out. | Confirm the backend in an actual build and take a Metal trace with Xcode Instruments during normal combat and a crowded boss encounter. Compare standard and Retina rendering. [Flutter Impeller](https://docs.flutter.dev/perf/impeller) |
| Web | JavaScript/CanvasKit as the compatibility baseline, then compare Wasm/Skwasm on supported browsers. Both can use GPU acceleration. Wasm build selection and threaded rendering are separate from GPU availability. | Record which renderer and graphics backend each browser actually uses. Check browser GPU diagnostics and frame traces. Test acceleration disabled or unavailable and define a clear lower-quality or unsupported path from the results. [Flutter web rendering](https://docs.flutter.dev/platform-integration/web) · [Flutter Wasm support](https://docs.flutter.dev/platform-integration/web/wasm) |

The project declares Flutter 3.47.7 as its minimum. Current web docs include behavior introduced in Flutter 3.50. Record the shipping SDK and verify renderer selection, fallback, and loader options against that version. If threaded Skwasm improves results, test cross-origin isolation on staging with SoLoud, asset hosting, sign-in, and Online before making it a hosting requirement. [Flutter web initialization](https://docs.flutter.dev/platform-integration/web/initialization)

Use a capture to decide what to optimize. Expensive transparent layers and effects can be GPU bottlenecks, especially at high device pixel ratios. Repeated canvas work, allocations, and simulation can be CPU bottlenecks. If rendering is limiting, test offscreen culling, batching sprites from the same atlas where blend and layer order allow, reducing cosmetic overdraw, and prewarming first-use assets. Consider a combat render-resolution option only if traces show a pixel-cost bottleneck. Keep the HUD and crosshair at display resolution and preserve warning geometry, actor visibility, and input alignment. [Flame SpriteBatch](https://docs.flame-engine.org/latest/flame/rendering/images.html) · [Flutter web profiling](https://docs.flutter.dev/perf/web-performance)

## Platform readiness

- **Mobile browsers** — Detect Android and iOS/iPadOS before loading Flutter or SoLoud. Show the matching store link. Use `make buildWeb` to fetch iOS and Android destinations from Telling as part of the web build. Serve the generated `mobile-store-links.json` with revalidation. Run `make refreshWebStoreLinks` and publish the updated manifest when destinations change. The landing page labels beta destinations and offers retry when a link is unavailable. Update Telling to the public listings before rollout. Native iOS and Android retain the established touch and settings paths.
- **Web** — Use HTTPS staging on the intended origin. Exercise controller discovery and hot-plug, SoLoud first-gesture audio unlock, mute, tab switching, account connectivity, Online, refresh/Continue, and failed storage. Preserve checkpoint schema and recovery semantics with browser storage. Measure compressed first-use payload and test cache behavior on rollout and rollback with older tabs open. [Web Audio autoplay](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay) · [Flutter web caching](https://docs.flutter.dev/platform-integration/web/faq)
- **macOS** — Verify a release build with native fullscreen, audio, saves, account credentials, and Online. Resolve the actual minimum OS and architectures from Flutter and plugin builds. Prototype Apple Game Controller extended-profile input alongside the web Gamepad API. Evaluate a package against the same checks as a native adapter. Test Xbox and DualSense wired and Bluetooth, including disconnect during movement or grenade aiming. Verify the signed bundle has App Sandbox, outbound networking, and the app’s signing identity for Keychain access. Declare Extended Gamepad support in the macOS Info.plist. The Release target enables Hardened Runtime. For direct distribution, build with Developer ID, verify the distribution entitlements and notarization, and test the download on a separate Mac. [Apple controller configuration](https://developer.apple.com/documentation/xcode/configuring-game-controllers) · [Apple packaging and notarization](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

## Measurement and acceptance

**Target up to 120 FPS on macOS and web**, with 60 FPS as the baseline. Prototype an Auto setting that follows the available refresh rate up to 120 FPS, plus a 60 FPS cap for players who prefer lower power use or steadier pacing. Verify the actual presentation rate on a 120 Hz display, including a ProMotion Mac and an external display. Browser frame callbacks generally follow display refresh, so measure what each supported browser delivers. [Browser animation frame timing](https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame)

Use the same cold start, first arena entry, normal run, crowded boss fight, and repeated restart/Continue scenarios across builds. Record build, OS, browser, hardware, GPU path, device pixel ratio, display refresh, presented frame intervals, and missed refreshes. Include four-arena readability checks, especially Floodworks. [Regun playtest guide](PLAYTEST_GUIDE.md)

| Measure | Proposed gate |
|---|---|
| Frame pacing at 120 Hz | Budget 8.33 ms per frame. On agreed high-refresh hardware, aim to hit at least 95% of refreshes in ordinary combat and 99% of frame intervals within two refreshes in the stress scene. Check sustained pacing after warm-up and record CPU and GPU costs separately. |
| Frame pacing at 60 Hz | Budget 16.67 ms per frame. On agreed baseline hardware, aim for p95 frame intervals ≤18 ms in ordinary combat and p99 <33 ms in the stress scene. |
| Gameplay timing | Replay equivalent input at 60 and 120 FPS and through a refresh change. Compare movement, firing cadence, reloads, dash, grenade fuse, collision outcomes, and encounter timing within defined tolerances. Keep Online server ticks and send cadence independent of render refresh. |
| Input | Apply aim and action state by the next game tick in steady play. Check click-to-flash and stick response on hardware. |
| Startup | Measure compressed bytes and cold/warm times to interactive menu and playable frame using a fixed network profile. Set budgets from the baseline. |
| Memory | After warming caches, check for sustained growth across repeated arena entries, boss switches, and restarts. Record decoded sizes, texture residency where available, and active audio voices. |
| Quality | Keep attack warnings and crosshair legible under load. Quality changes preserve simulation and authoritative geometry. |

## Delivery sequence

1. **Baseline and feasibility.** Capture private macOS and HTTPS web builds, prove persistence and audio, read controllers on both, and confirm GPU paths and initial bottlenecks.
2. **Desktop Training slice.** Review crosshair aim, framing, 60 and 120 Hz pacing, controller combat, reload under pressure, charged shots, grenades, and a boss camera transition on both targets.
3. **Complete the desktop loop.** Take mouse/keyboard and controller through loadout, Solo, upgrades, pause, Continue, results, and restart. Add remaps, prompts, focus traversal, and interruption handling. Run mobile touch regressions.
4. **Online parity.** Verify camera mapping, mixed-device co-op, reconnect, neutral inputs on blur, and server-authoritative weapon and grenade actions. Review visibility before opening competitive desktop play.
5. **Release review.** Cover Safari, Chrome, and Firefox on macOS, and Chrome/Edge and Firefox on Windows for web. Run clean installs and 20–30 minute sessions, fullscreen recovery, controller hot-plug, and rollback checks. Publish support from the tested matrix.


## Local review build

- **macOS** — Open `build/macos/Build/Products/Release/Regun.app`. The development-signed build contains arm64 and x86_64 slices and declares macOS 12.0 as its minimum. The launch trace confirms Impeller with Metal. The signed bundle passes strict signature verification. It is a local review build and has no notarization ticket.
- **Web** — Run `make buildWeb` with the Regun release config and serve `build/web`. Chromium smoke tests exercised loadout, Solo combat, Escape pause, Settings, results, and Save & leave followed by Continue. Chromium reported hardware WebGL through the Apple GPU. The browser build uses JavaScript/CanvasKit while the current secure storage dependency still blocks a clean Wasm build.
- **Mobile browsers** — Emulated iPhone, iPad with a desktop user agent, and Android used the Telling-generated destinations without loading Flutter or SoLoud. Telling currently returns beta destinations for both platforms.
- **Regression checks** — Analyzer clean. The full suite reported 1,018 passes, five skips, and one weapon catalogue failure reproduced on the original commit. Desktop aim, the 60/120 cap, touch controls, and browser save/resume were checked separately. Physical mobile play, a connected controller, sustained 120 FPS, and live Online remain review gates.


## Full-screen desktop presentation review

The desktop shelter menu uses larger title typography. Loadout lays out category navigation, the roster or armory, and the equipped kit across the window. Settings and Controls group related settings in separate columns on wider windows. Results use the full desktop frame.

Pause keeps the frozen arena visible across the window. The action rail sits on the left and the run summary sits on the right. Upgrades use the arena as the backdrop for a full-window selection screen with the reroll action next to the choices. Menus use a brass arrow and combat uses the aiming reticle. Native phone layouts keep their separate touch presentation.

The layout reference review looked at how Hades II builds its inventory and market around the game's setting, and how DOOM Eternal divides desktop navigation and information across the screen. [Hades II UI illustrator case study](https://www.corviday.net/supergiant) · [DOOM Eternal interface captures](https://interfaceingame.com/games/doom-eternal/)
