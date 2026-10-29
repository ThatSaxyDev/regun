# Ariet complete roof arsenal — 28 October 2026

Release candidate 1.0.0+30. Full Training runtime, with normal-game admission
explicitly deferred until creator testing. Supersedes build+29's rear blind spot.

Training → Start → Pause → Boss Practice → Ariet. Take damage is Off by default;
turn it On in Training Pause to evaluate actual health loss and recovery.

## Verification

Analyzer clean; full `make verify`: **892 passed, 5 intentional skips**.
Final focused Ariet run after the contextual-exhaust adjustment: **34 passed**,
including a60-second rendered native encounter recording. A prior overlapping
test invocation invalidated its shared unit-test asset directory; the isolated
full verification completed cleanly without changing packaged boss assets.

[Native encounter recording](native.mp4) · [contact sheet](review-strip.png) ·
[all-weapon hull still](native.png).

Reproduce the focused recording with:

```sh
REGUN_ARIET_FIGHT_CAPTURE=1 flutter test --no-pub test/ariet_combat_test.dart test/ariet_rig_test.dart test/ariet_workshop_test.dart test/ariet_roof_weapons_test.dart test/ariet_native_encounter_test.dart
```


- `test/ariet_roof_weapons_test.dart`: actual damage within4s at16 azimuths and
  six distances0/60/100/150/300/650; cannon rear hits and final aim commitment;
  full360-degree receiver/support/recoil envelope sweeps; both phases and both
  slow/fast orbit directions exercise all four families and actual damage;
  guidance delay/turn/expiry/interception, cover, flak capacity and volley bound.
- `test/ariet_native_encounter_test.dart`: real selector and game components,
  complete arsenal, two real50HP escorts, actual rear cannon health loss,
  interception by an actual BulletComponent, all24 player weapon packets,
  compound gap misses/one blast owner, Training recovery, destruction/replacement,
  pending-load restart and decoded-art budget.
- Existing rig/workshop tests preserve fixed tick equivalence, scaled actual IK,
  pending asset disposal, reduced-motion sockets and arena constraints.

The screenshot/video are game-layer test renders, not physical phone footage.
Flutter HUD is separate. All art leases retain the previous4,849,664-byte main+pair
owned decode total and32MiB combined test envelope. This is not process/GPU/FPS proof.

## Physical review still required

Rear/circling pressure, cannon commitment, flak gaps, seeker interception,
all-weapon feel, cargo readability, genuine recovery, cover, pause/background,
Reduced Motion, sound, sustained performance and comfort need creator review.
Ariet stays out of normal survival, random Rush, hosted play and normal saves.

## Release packaging and phone connection

Release iOS bundle built/signed successfully (Xcode28.6s). Packaged Info.plist
confirms `dev.kiishi.regun`, marketing version1.0.0, build30. Flutter wireless
installation/launch then failed; direct Apple devicectl retry reported
`The device disconnected immediately after connecting` (CoreDeviceError4000).
The connection recovered. A subsequent Apple device app query confirms Regun
`dev.kiishi.regun`, marketing version1.0.0, **installed build30** on the creator's
iPhone. Explicit process launch was denied because the device is locked
(FBSOpenApplicationErrorDomain7 / Locked). Unlock and open Regun normally; no
rebuild/reinstallation is required. Launch and physical gameplay were not observed
in this pass. The built bundle remains at `build/ios/iphoneos/Runner.app`.

After the creator unlocked the phone, Apple devicectl successfully launched
`dev.kiishi.regun` (exit0). Installed build30 is ready for Training review.
This confirms launch, not hands-on gameplay/performance acceptance.
