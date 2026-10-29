# Ariet live hover, straight flowing thrust and readable seeker salvos

Release identity remains **1.0.0+28**, per creator instruction. This pass retains
the full Training gunship and all earlier height/traffic fixes. No build-number
increment or roster/distribution admission is authorized.

## Creator corrections implemented

- A holding gunship now visibly station-keeps: bounded vertical lift around its
  160-unit base (+/-7) and lateral presentation sway (+/-4.5), on the simulation
  clock. This never changes the ground navigation path or planted floor warnings.
  Art, target centre, compound hull, cargo and muzzle sockets share that pose.
- Jet fire continuously flows while the hull holds still. A constant core plus
  staggered advected hot tongues replaces the single frozen plume. The painted
  nozzle/pod axis is authoritative; the old extra vertical projection offset
  that swung the flame off axis is removed. No brightness strobe/camera motion.
- Reduced Motion retains steady body height and no drifting smoke; the fire uses
  a smaller/slower texture flow so a running engine still reads as live. Pause,
  input-blocking presentations and background freeze all simulation clocks.
- The seeker sprite was missing because Ariet loaded Walker's parts but not its
  arsenal sheet. Only a small red engine stamp had drawn. Ariet now leases a512px
  arsenal decode once for itself/the pair; ready requires the rocket rect/image.
  Full-sized Walker retains its normal arsenal decode/default behavior.
- Live seekers draw a64-unit metal body, nose and fins with a small rear jet.
  Their collision radius/damage/guidance contract is unchanged. Expiry leaves a
  brief .4s coasting, fading rocket with grey burnout; it does no damage and is
  not an invisible target/explosion. Contact and interception keep their real
  impact cues. Fatal cleanup clears spent rockets as well as live rounds.
- At the creator's request, salvos now fire four rockets normally and six below
  half health, .3s apart through a committed fan. Count commits in the warning,
  active launch cells identify each release, and the32-owned-round cap remains.
  Shootability, .6s plus100-unit guidance delay, bounded1.8rad/s turn, 3.5s active
  life,1HP/90-radius blast, cover, shared quiet recovery and solo Training scope
  remain. No escort volley overlaps seeker fire.

## Verification contracts

The native test checks actual painted pixel changes with hull motion and smoke
removed, so a frozen flame cannot pass using bobbing or puff movement. It also
checks real opaque rocket nose/body/fins pixels rather than counting a red glow.
An actual four-or-more rocket volley is captured in the native world. Existing
all24 player-weapon paths, lift pixels, underpass/head-on traffic, rear damage,
interception, compound gaps, recovery, disposal and32MiB checks remain.

Portable tests check idle hover without ground drift, pause/Reduced Motion, nozzle
axis across24 headings and three pod tilts, four/six committed salvos and harmless
burnout lifetime/cleanup. All live effects retain bounded owner-held collections.

Reproduce native game-layer evidence:

```sh
REGUN_ARIET_FIGHT_CAPTURE=1 flutter test --no-pub test/ariet_native_encounter_test.dart
```

Automated rendered capture is not physical-phone footage or comfort/performance
acceptance. Creator review of continuous flight feel, flame flow, smoke, missile
readability, four/six-salvo difficulty and Reduced Motion remains open.

The subsequent general-agility pass retains these corrections and verifies the
combined implementation (full904 pass/5 intentional skips, analyzer clean). See
[latest movement evidence](../ariet-jet-agility-2026-10-28/README.md).
