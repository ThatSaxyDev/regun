# Ariet flight height, engine exhaust and escort traffic — release 1.0.0+28

Creator phone feedback: the gunship appeared on the Walkers' ground plane and
actors seemed to obstruct one another. The creator additionally requested visible
jet exhaust and smoke. Ariet remains in Training pending physical acceptance.

## Fix

The previous battle painter added the same height offset that the rig subtracted,
visually cancelling hover. Cargo also painted at floor coordinates, and the craft
used ordinary ground y ordering. Combat lowered128→34 after cargo release.

The complete assembly now retains160-unit flight height (112 projected units)
before and after dropping cargo. Its shadow stays on the floor; body/cargo/nozzles
project above it. The gunship draws in an overhead body layer above ground actors,
then returns to ground depth when the harmless crash lands. Cargo shares arrival
transforms and departs from its actual elevated attachment, with its own grounded
shadow path. Reduced Motion retains stable visible altitude without bobbing.

Visible hull/weapon sockets, authoritative compound target shape, broad-phase
actor centre, flashes, warning paths and projectile releases use the same airborne
plane. Navigation/cargo landing/exhaust warnings retain their ground coordinates.
The router uses an explicit ground proxy rather than the lifted weapon target.
All24 player weapon packets still hit the visible hull and preserve real gaps.

Ariet never reserves ground occupancy, including mounting/reservation calls.
Escorts can walk beneath its footprint. The ground Walkers retain swept body and
solid constraints, but ordinary escort navigation now slides and uses cover
routing plus a shared right-hand traffic rule. Opposing headings choose opposite
world tangents; per-ID handedness had sent both to the same side in the reproduced
head-on case. Ground bodies still cannot cross through one another.

Both articulated pod nozzles have a hot pixel jet and short drifting grey smoke.
The dedicated transparent four-sprite sheet is owned/decoded lazily with Ariet,
not a reused explosion or floor-dust effect. Thrust controls the plume; smoke uses
the fixed simulation clock, at most18 puffs and .95s lifetime. Pause freezes it;
engine shutdown stops emission and lets old smoke clear. Reduced Motion uses a
stationary modest jet/haze, no moving smoke particles and unchanged target geometry.
No engine audio loop or camera shake was added.

## Verification

Clean analyzer. Full `make verify`: **894 passed, 5 intentional skips**.
Current release identity: **1.0.0+28**, restored at the creator’s request.
The +31 references below record an earlier local-only installation attempt. The full native test includes the real Training
selector and all24 actual weapon packets against the lifted target.


- Actual render alpha-centroid check measures112 units of lift in the whole
  painted assembly, preventing a renderer cancellation from passing getter tests.
- Native two-way underpass succeeds even after explicitly calling Ariet's spawn
  reservation API. Its layer remains above both escort bodies.
- Real escort AI crosses swapped flank destinations within8s, without a head-on
  deadlock and with at least118 units of body separation throughout.
- Flight height persists across cargo release, real elevated release sockets are
  checked, destruction descends to zero and stops the engines.
- Smoke count/lifetime, simulation pause and Reduced Motion cleanup are checked.
- Existing complete encounter, rear coverage, guidance/interception, flak,
  all24 weapon packets, empty hull gaps, one-owner blast, Training recovery,
  disposal/restart and32MiB art-envelope checks remain in place.

Reproduce the native game-layer capture with:

```sh
REGUN_ARIET_FIGHT_CAPTURE=1 flutter test --no-pub test/ariet_native_encounter_test.dart
```

[Native game-layer recording](native.mp4) · [contact sheet](review-strip.png) ·
[raised carrier and grounded escort pair](airborne-pair.png) ·
[all-weapon target check](all-weapons.png).

The recording was refreshed after final plume-intensity tuning. It contains the
enraged encounter and destruction; underpass/head-on/target-inspection checks run
between recording sections. The Flutter HUD is separate from the captured game
layer. The custom still is a controlled overlap/traffic inspection.

These are rendered tests, not phone footage or sustained physical performance
proof. Physical depth readability, engine intensity, motion comfort, combat
readability and escort behavior still require creator playtesting.

## iOS packaging

Release bundle built/signed successfully (Xcode29.5s), packaged version1.0.0+31.
Device installation/launch is tracked after the build; compilation is not physical
playtest/performance proof.

Initial deployment could not start: Apple CoreDeviceError4016 reported no trusted
connectivity/services/power assertion, and device listing marked the iPhone
unavailable. Creator reconnection requested. Build+31 installation is not yet
confirmed; +30 was the previously confirmed phone build.

Artwork uses the built-in imagegen tool. Saved
[transparent jet/smoke master](../../../art/source/bosses/ariet/exhaust-v01.png),
[prompt](../../../art/source/bosses/ariet/exhaust-v01-prompt.txt) and
[provenance/rectangles](../../../art/source/bosses/ariet/exhaust-v01.json).
The runtime copy is `assets/art/workshop/ariet_exhaust_v01.png`.

## Creator release-number correction

Repository HEAD (`0a4fbb2`) records `version: 1.0.0+28`; the creator confirmed that
the release number must return to the last pushed identity. Automatic local
increments29–31 were not authorized as new release numbers. The+31 binary did
install and launch successfully once connectivity returned, and Apple's device
app query confirmed31. It is being replaced with the same gameplay fixes packaged
as **1.0.0+28**. Future increments require explicit creator authorization.

This metadata correction changes no gameplay; the894-test/analyzer verification
still applies to the retained implementation. No distribution upload is involved.
