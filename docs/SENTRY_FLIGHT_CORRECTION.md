# Sentry flight correction — 25 October 2026

Freshly deployed sentries could visibly fire while every round vanished before reaching the enemy. This was reproduced in the native game with an empty firing path: Carbine lost15 rounds after about174 travel units despite650 range; three-round burst lost9 after about165 despite700 range. The target took zero damage.

## Cause and correction

`Vector2` stores positions in32-bit floats. The old native flight loop inferred a wall collision whenever the measured movement was over0.00001 units shorter than its requested step. Ordinary coordinate rounding exceeded that threshold. For example, a15.833333 requested step measured15.833313, causing a perfectly legal round to be deleted. Position/angle changes explain why shooting could later appear to recover.

Native rounds now stop for an actual swept cover contact, a body contact, exhausted range or an arena exit. Open-flight range advances using the double-precision planned distance. The existing swept body hit and short visible contact trace remain authoritative; no homing or guaranteed damage was introduced.

A second reproduced fault allowed firing beside a pod edge even though the projectile's five-unit cover clearance blocked every round. Target legality, predictive aim and muzzle checks now use that same clearance in native and hosted combat. An obstructed locked target follows the existing loss-of-shot timeout, then the sentry selects an eligible clear target. Aura and landing/expiry blast sight checks remain unchanged.

## Verification

The new native regression exercises24 complete fresh-drop scenarios across both mounts,30/60/120Hz, positive/negative coordinates and straight/diagonal headings. Every target is damaged within650ms of activation, including normal turning and flight time. Twelve additional scenarios exercise the actual scorpion/mummy update methods while walking. Both mounts sustain their intended firing rhythm. Additional native regressions verify pod-edge rejection, retargeting, real wall contact and exact range exhaustion. Co-op exercises real released rounds against the same pod-edge layout at all three update rates.

The prepared weapon damage, cadence, speed, range, battery life and unlimited-ammunition contract are unchanged. Normal walking speeds remain60/90 units per second for scorpion/mummy, versus950/1100 for default sentry rounds; no enemy slowdown was needed. Shared aim still predicts bounded movement and commits each released projectile to a straight trajectory. The existing per-target commitment remains.

Final validation: analyzer clean;752 game tests passed with five optional skips;177 server tests and the module build passed. Android APK, web and unsigned iOS release builds passed.

Machine evidence is in `docs/validation/sentry-flight-2026-10-25.json`. Physical feel and multiplayer presentation remain hands-on checks.
