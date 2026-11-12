# Regun controller experience

The desktop implementation is ready for playtesting. Start with native macOS, then validate desktop web on macOS, Windows, and Linux. Follow with native iOS and Android, including touch-to-controller handoff.

A player should be able to launch Regun with a controller, see that it is connected, choose a loadout, start Training, pause, change a setting, resume, and leave the run without reaching for a mouse. The same menu behavior should carry through Solo and Online.

## What prompted the work

| Area | Previous behavior | Player impact |
| --- | --- | --- |
| Connection | The app-level controller poller receives button and axis values, or an empty result. It clears input on backgrounding and has no player-facing connection state. The macOS and web readers select the first usable pad. | Plugging in or losing a pad is silent. The game has no explicit way to distinguish disconnect, app suspension, and a failed read. |
| Navigation | The controller asks Flutter to move focus spatially. If that fails, it advances to the next focus target. A/Cross can also advance focus when there is no activation action. Holding a direction gives one move per press. | An edge can jump somewhere unrelated. A/Cross can move selection unexpectedly. Long catalogs require repeated presses. |
| Menus and Back | Focus styling varies across controls. Some buttons, such as Pause → Resume, explicitly take focus. Loadout tiles draw their custom outline on mouse hover. B/Circle calls the navigator’s generic Back action, while gameplay overlays can live inside the same route. | Selection can be hard to see, and B/Circle can reach route-level leave logic from an in-game panel. |
| Sound | Shared buttons and home actions play `click.mp3` on activation. Their focus callbacks update visuals only. | Moving around menus has no audio feedback. |

[Controller dispatch](../lib/desktop/desktop_controller.dart) · [Run overlays](../lib/views/base_view.dart) · [Loadout tiles](../lib/views/loadout_view.dart) · [Shared buttons](../lib/widgets/click_button.dart)

## 1. Show connection changes everywhere

- Track connection status separately from controller input. Report a usable pad already present at launch, a newly connected pad, and a disconnected pad. Keep a stable active pad if a second controller connects. Clear its held inputs before handing control to another pad.
- Show **Controller connected** or **Controller disconnected** in a compact Regun notice above the navigator. Include the controller name when the platform provides it. Use a short, safe-area-aware notice with live-region semantics. It should appear during play, pause, loading, settings, and dialogs without stealing focus, blocking clicks, or covering combat HUD actions.
- Reconcile the current devices on foreground return. Treat backgrounding and temporary read failures as input suspension, and announce actual connection changes once. Require neutral sticks and released buttons before accepting gameplay input again.
- If the active pad drops during Solo or Training, clear movement, fire, and held grenade aim, then open Pause with **Resume** focused. In Online, send neutral input and keep the match running. A pad connected while using mouse or touch should display its notice immediately. A deliberate controller action switches prompts and input mode.
- Use native controller connection events on macOS and browser gamepad discovery on web. For web acceptance, record when the browser first exposes the pad and verify the notice from that point. On a fresh browser visit, check whether an additional interaction is required for discovery or audio. Keep mouse and keyboard usable throughout.

## 2. Make menu movement predictable

- Give each screen or panel an initial focus target, a visible focus outline, and a clear Back action. Restore focus to the control that opened a subpage or dialog. Scroll the focused item into view and skip unavailable actions.
- Use the D-pad or left stick for navigation. Choose one direction per diagonal input, step immediately, then repeat after a short hold delay. Start playtesting at about 320 ms before repeat and 120 ms between steps. At the edge of a grid, keep focus in place unless that screen defines a specific move to another section.
- **A/Cross** activates the focused action. In Loadout, focus browses and previews, while confirm equips. **B/Circle** dismisses a dialog, backs out of a submenu, or resumes from Pause. Leaving a run still goes through the existing confirmation. Keep the Pause binding available in combat and make its behavior explicit on the pause panel.
- Use the existing Flutter focus and action system. A full stepped brass outline indicates focus on buttons, tabs, cards, and toggles. Equipped markers and selected tabs retain their own visual state. Controller bindings are available in Controls and contextual combat prompts appear in the HUD.
- Give the topmost dialog or rebind prompt input priority. Consume the press that opens or closes it and require a fresh press for the next action. An upgrade confirmation, reconnect, or menu dismissal must never fire a shot or release a grenade.

## 3. Give menu movement its own sound

- Play a short, quiet click for each successful controller focus move. The 54 ms cue uses the first transient from Regun’s existing `click.mp3` selection sound. For adjustable controls, play the click when the value changes. Keep stationary edges, stick drift, and automatic focus restoration quiet.
- Use the existing confirm click where a control already plays it. Add a distinct, softer Back cue for a successful dismissal or return. Route playback through SoLoud and the existing SFX setting. Limit overlap during held-direction repeat and keep visual focus feedback available with SFX muted or before browser audio starts.

## Delivery and acceptance

| Pass | What to verify |
| --- | --- |
| **Shared input and notices** | Start with a pad connected, plug and unplug on Home, in combat, in a picker, and in a dialog. Test switching to mouse and back, reconnecting with a button held, and tab or app backgrounding. Confirm one notice per reported change and zero unintended shots or throws. |
| **Controller-only desktop loop** | Home → Loadout → switch Survivor, Weapon, and Arena tabs → Training → Pause → Settings → change a toggle and slider → Back → Resume → leave through confirmation. Repeat with a long scroll list, a disabled action, a rebind dialog, and a disconnect during grenade aim. Verify visible focus, correct scrolling, and one cue per successful move. |
| **Remaining screens** | Exercise Solo Continue, upgrade and fusion choices, results, restart, Online lobby and match menu, and update/account dialogs. Check that modal focus returns to its opener. Test keyboard and mouse regressions. For text entry, verify that the controller can reach and leave the field. |
| **Physical release review** | Use an Xbox controller and DualSense over USB and Bluetooth where supported. Start with the signed macOS release, then test desktop web in Safari and Chrome on macOS, Chrome and Edge on Windows, and Chromium and Firefox on Linux. Include web fullscreen, tab switching, first audio interaction, and SFX mute. Record the OS, browser, controller, connection type, and results for each combination. |

Add automated tests for connection transitions, directional repeat, focus and Back across routes and in-game panels, single audio cues, and input clearing. Hardware playtesting is the acceptance check for focus comfort, audible feedback, and connection timing.

## Local playtest

- Open [the signed macOS controller playtest](../build/controller-focus-playtest/macos/Build/Products/Release/Regun.app).
- Serve the desktop web release from `build/web`. Test the browser's first controller interaction and check the audible tick once sound is available.
- Start with a controller connected. Navigate Home → Training, switch a Loadout tab, start a run, then use Menu/Options → Settings. Try changing Sound with Left/Right, go back with B/Circle, and resume with B/Circle again. Disconnect while holding a grenade to check the notice, pause, and input clearing.

The signed macOS candidate opened at Home. A smoke test of the packaged web build in Chrome used a simulated browser gamepad to verify both connection notices and Home → Training loadout → Armory → Back. Analysis, 35 focused Flutter checks, and three Chrome widget checks passed. The full suite had 1,040 passes, six skips, and one weapon-catalogue failure reproduced on the untouched baseline. Physical controller feel, audio, and the desktop browser and OS matrix are still for playtesting.

## Mobile follow-up

Keep controller detection, menu actions, notices, and sound independent of the desktop layout. After desktop acceptance, add native controller readers to iOS and Android and connect them to the shared input layer. The mobile pass should keep the phone layout, hand combat control to the pad on deliberate input, and restore the player’s touch controls when they switch back or lose the pad. Test pairing, background and foreground transitions, disconnect during held actions, and controller navigation through the compact menus on real phones and tablets. Native Windows and Linux builds would likewise need their own input adapters if Regun ships standalone builds there.
