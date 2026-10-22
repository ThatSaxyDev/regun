# Tablet layout review — 22 October 2026

## Result

Tablets use the full landscape canvas. The original fixed 1500×700 world view forced a wide gameplay strip into a 4:3 screen, leaving large bars above and below. `ArenaViewport` now extends the visible arena to the tablet aspect ratio while retaining the original minimum view and undistorted sprite proportions. At 1376×1032, the world view is 1500×1125. Phones retain exactly 1500×700 framing.

`GameLayout` selects tablet presentation at 600 logical pixels on the shorter side. Tablet text, HUD surfaces and the touch cluster receive a restrained 1.25 scale. Accessibility text scaling composes with it. Both handedness modes, floating sticks, custom positions and grenade drag power use the displayed geometry. Saved control preferences remain in their original units. Solo and online share the framing policy.

The iPad native configuration supports both landscape directions and requires full screen. This deliberately disables iPad Split View/Slide Over: Flutter's orientation lock otherwise is not reliable on iPad. Phone orientation configuration is unchanged.

## Verification

- Booted iPad Pro 13-inch (M5), iOS 27.0 simulator. Native integration passes: landscape-left and landscape-right requests, full canvas viewport, simultaneous movement/aim/dash, training pause and weapon catalog, loadout and settings. Captured native renders are in `validation/tablet-layout-2026-10-22/`.
- Tablet layout matrix covers 1024×768 and 1366×1024, accessibility text at 1.5×, and a defensive portrait/window resize with held-input cancellation. Shipping iPad remains landscape.
- Phone regression matrix retains small/notched landscape layouts, larger text, native input and mirrored controls. Online input tests now cover phone/tablet, left/right handedness and fixed/floating sticks.
- iOS release build succeeded (143.2 MB); code signature verified. Phone installation remains pending because the paired iPhone reports unavailable. The updated normal app is running on the booted iPad simulator.
- `make verify`: analyzer clean; **471 tests passed, 5 optional skips**. Native iPad integration: **1 passed**.
- The full suite also caught two existing enemy-reaction cleanup errors: stale stagger paused an animation for an extra update, and frozen death retained its hold state. Timers now advance before animation selection; death clears reaction state and resumes its animation. Existing dedicated regressions verify both.

No weapon stats, sprite assets or collision geometry changed for tablet layout. Revealing more arena changes tablet situational visibility; physical tablet comfort, sustained performance and balance still require hands-on review. Simulator success does not establish hardware acceptance.
