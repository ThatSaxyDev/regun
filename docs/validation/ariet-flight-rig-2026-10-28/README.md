# Ariet assembly and flight rig — 28 October 2026

Implemented slices A/B as a development-only Flutter workshop. Launch offline:

```sh
flutter run -t tool/ariet_workshop.dart
```

The entry point initializes local preferences/orientation only. It does not start
account, balance, update, presence or network services. Nothing is added to Home,
Loadout, Training boss selectors, BossKind, survival, Boss Rush, saves, co-op or
admin/API catalogs. Release identity/build28 and installed phone build are unchanged.

## What to inspect

- Hover: steady height/shadow without periodic breathing. Tap floor to move at
  held hull heading. Mounted guns remain inert.
- Accelerate: cruise220, acceleration500, braking650; stop, reverse and settle.
- Strafe: lateral and backward flight while hull heading holds.
- Turn: bounded1.2rad/s shortest-route turns, modest bank, connected articulated
  pods and independent cannon mount orientation. No late tracking/attack exists.
- Cargo: hull cutaway, two tightly folded67.5% current Walker rig studies and a
  side section. The candidate loaded hover rises to128 to clear tucked limbs;
  empty hover remains34. See source README for the proposed stow geometry.
- Scale: full rig and65/67.5/70% options beside Rook.50HP is proposed, not live HP.
- Pause/Step/Restart, both floors, Close view, Sockets and Reduced Motion. OS/user
  Reduced Motion cannot be disabled by the local inspection toggle. Backgrounding
  freezes all time and resume does not catch up hidden wall-clock time.

Ordinary flight uses the normal1500-unit camera width at phone scale even when
the control strip reduces its height; close inspection is explicitly1.65×. Text and
controls stay outside the art. Cargo explicitly fits its side section into the
reduced study viewport; normal flight keeps real camera-width scale. This is an isolated bounded stage over borrowed
Breach/Foundry textures, not an active arena/normal HUD run. ArenaGeometry resolver
regressions exercise real wall/cover motion separately. Navigation uses a210-unit
conservative circle enclosing mounted hardware, not the later compound hurt shape.

## Reproduce visual evidence

```sh
REGUN_ARIET_CAPTURE=1 flutter test --no-pub test/ariet_workshop_test.dart
```

Output in `build/ariet-workshop`: eight headings on BOTH floors, cargo cutaway,
scale comparison, actual phone UI capture, texture accounting and32-second15fps
clips. Clips use the same rig/controller/painter as the development route, not a
separate mocked presentation. Optional video export has a three-minute timeout.
Representative captures are retained here. Videos are rendered simulations, not
physical device footage or native frame-rate measurements.

## Verification and limits

Full `make verify`: analyzer clean,872 tests pass with5 intentional skips.
54 focused tests pass across Ariet rig/workshop and existing Walker
rig/combat/admission/collateral. Coverage includes30/60/120Hz, fixed-step turns,
stop/reverse, pause/step, wall/cover stops, Reduced Motion, scaled actual IK/feet/
muzzle/body queries, candidate bay/vertical clearance, phone and large-text UI,
background/resume, idempotent assets and pending-load disposal. Final presentation checks: analyzer clean and19 Ariet/Walker rig/workshop tests
pass after the carried-shadow and cargo-viewport refinements.

Ariet plus ONE Walker atlas owns9,087,624 decoded RGBA bytes. Shared world cache
including the leased Rook reference owns22,802,944, total31,890,568
(~30.41MiB), below32MiB. Floors are borrowed, no Walker atlas per escort. This measures decoded
art only, not total process/GPU memory or physical performance.

Art/silhouette, perspective, stow mechanism/swept folding clearance, motion comfort
and native performance remain creator review gates. The first study does NOT
implement gun release/recoil, a compound hittable hull, damage, tactical director,
three attacks, escort flight/unfolding/AI, arrival/destruction or admission. Next
is creator inspection of this rig, then slice C (hittable hull/one gun).

## Retained captures

- [Phone workshop](phone-workshop.png) and [phone cargo fit](phone-cargo.png).
- [Breach headings](breach-headings.png), [Foundry headings](foundry-headings.png).
- [Cargo cutaway / side section](cargo.png), [Walker scale comparison](scale.png).
- [Breach motion](breach.mp4), [Foundry motion](foundry.mp4).
- [Decoded art accounting](texture-budget.txt).

Final presentation checks additionally exercise the existing Walker art workshop;
its default ground shadows remain unchanged, while carried study units omit
ground-contact shadows. No physical installation, upload or deployment occurred.
