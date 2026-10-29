# Ariet general jet mobility and charge counter — release1.0.0+28

The creator clarified that high mobility must apply generally, not only during
one attack. They also requested a spooled charge, actual stop, rapid gun lock and
fire while the airframe turns back toward the player. This pass retains all live
hover, flowing straight thrust, physical seeker art, four/six salvos and escort
traffic corrections. Keep Ariet in Training and retain release1.0.0+28.

## Delivered movement

- Normal speed220→360, acceleration500→1300, braking650→1800, hull yaw1.2→2.8rad/s.
  Normal repositioning uses this throughout; it does not depend on charging.
- Cannon and seeker attack phases now use lateral flight (250 normal/290 enraged
  plus bounded radial correction, capped360). The hull turns toward the visible
  player while independent roof bearings acquire at12rad/s. Seeker fan/count
  stays committed to the warned target; guidance remains delayed/bounded.
- Cannon aim locks its world target .22s before each shot. While the platform
  moves, the gun solves the bearing to that same committed point. Released shells
  remain straight; no post-release homing or late player retargeting was added.
- Ordinary rotary passes now have a1s visible thrust spool, committed820-speed
  charge, physical braking, then a36-round rotary counter. The guns can fire
  within.35s of stopping while the hull is still turning; they never wait for hull
  alignment. One accepted rotary hit remains the budget for that whole sequence.
  The overflight itself has no passive ram damage.
- The warned route includes the full braking corridor. Solids/bounds still resolve
  actual movement; an obstruction after commitment stops the pass and enters
  brake/counter rather than sliding through cover. The direction never homes.
- Cargo retains its slower420-speed release pass, opening18-round cover stream,
  quiet release timings, real pair, scale and health. It does not gain a stacked
  rapid counter under a landing. Other floor attacks retain planted footprints.
- Shared recovery still counts only genuinely quiet owned-ordnance time. Airborne
  occupancy/rendering, hover/flow, Reduced Motion and pause/disposal contracts stay.

## New verification

Full `make verify`: **904 passed, 5 intentional skips**. Analyzer clean.
Release identity remains **1.0.0+28**; all gameplay/art corrections are combined.


`test/ariet_jet_mobility_test.dart` verifies ordinary900+-unit closure in3s without
charging, prompt hull turn,780+ charge speed, committed path, real braking,
sub-.35s first fire with hull error>.6rad, actual once-only damage, lateral cannon
and seeker firing, pause freeze, post-commit obstruction and pre-commit braking
clearance. Existing actual-native selector test now observes brake/counter along
with every weapon family, and still exercises sprites, moving flame pixels,
four-or-more rockets, actual rear damage, all24 weapon paths, traffic and cleanup.

Physical jet feel, warning readability, fast target tracking, four/six-seeker
balance, motion comfort, audio and sustained performance remain for creator review.
No automated capture or successful installation establishes that acceptance.

## Combined native evidence

Final focused six-file run: **46 passed**, including refreshed native game-layer
recording after all agility/hover/thrust/missile changes.

[Combined recording](native.mp4) · [contact sheet](review-strip.png) ·
[grounded pair beneath carrier](airborne-pair.png) ·
[actual seeker volley](seeker-salvo.png) · [opaque rocket body proof](rocket-body.png).

The capture uses actual RegunGame components and includes controlled traffic/target
inspection between encounter and destruction sections. Flutter HUD is separate.
These are rendered tests, not physical device footage.

## Device installation

Release built/signed (Xcode30.3s); packaged Info.plist confirms1.0.0+28. Apple
devicectl installed the final combined bundle (installation sequence8320), then
successfully launched `dev.kiishi.regun`. A fresh device app query confirms
marketing version1.0.0/build28. No release number was incremented and no external
distribution upload was made. Hands-on visual/difficulty/performance approval is
still the creator's gate.

Artwork provenance remains in the [jet/smoke source notes](../../../art/source/bosses/ariet/README.md)
and existing Walker arsenal; no new art-generation pass was used for agility.
