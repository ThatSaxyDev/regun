# Ariet continuous flight and escort aggression —1.0.0+28

Ariet now circles during navigation and quiet recovery instead of parking at a
stand-off point. Its normal spool creeps along the committed charge corridor; after
real braking, the first countershot still opens while the hull turns, then lateral
flight resumes after .18s. Moving phases retain cover steering. Flak/exhaust keep
planted, authoritative warning geometry. Recovery remains genuinely free of new fire.

Walkers pursue at up to209 world units/s (previous intent128), with stronger
acceleration and faster hull turns. Their escort-only turret turns at8rad/s, aiming
from the visible projected pivot. Bounded constant-velocity prediction leads a
moving target; emitted850-speed bullets remain straight and can be dodged by reversing.
Three-shot bursts retain .16s shot separation and damage/range, with a .14s opening
windup,1.1s individual cooldown and1.15s shared gate. Faster lane retry and shorter
post-heavy-attack inhibition remove the previous missed firing opportunities.

One escort can support ordinary charge/spool/brake/counter. Cargo and heavy attacks
still exclude escort fire, as does quiet cooling. Navigation's main-attack deadline
blocks new escort claims so support cannot perpetually starve the gunship. Shared
flanks, ready-turn alternation, current/predicted friendly lane checks, cover/body
occupancy,32-round cap,50HP/67.5% scale and owner cleanup remain.

New regressions measure actual flight velocity through60s in both phases (<20%
near stop, no stop >2.3s), straight-round interception and prediction caps, support
permissions/main deadline, and both real Walkers firing while native movement input
stays continuously held for12s. Existing actual render/rocket/hover, all24 weapon,
rear-damage, traffic/cover, pause, death/restart and32MiB checks remain.

Automated testing and game-layer capture do not establish physical fairness,
comfort or sustained phone performance. Ariet stays in Training for creator review.


## Focused verification and capture

**29 focused tests passed**, including accepted native escort health loss while
movement remained held, both shooters and at least12 rounds over12s. Analyzer clean.
[Actual game-layer recording](native.mp4), [review strip](review-strip.jpg),
[real flank positions](coordinated-flanks.png). These are rendered tests, not phone
footage. The moving-player regression uses actual joystick input and the real combat
pipeline; health is restored after accepted hits to avoid ending the measurement.

Continuous-flight verification: analyzer clean; full **915 passed /5 intentional skips**;
focused native/portable capture **29 passed**, including actual health loss during
continuous movement. Release identity remains **1.0.0+28**.

Final continuous-flight release built/signed (Xcode30.2s), installed (Apple
sequence8336) and launched successfully on the iPhone. Fresh app query confirms
**1.0.0/build28**. No version increment or distribution upload. Physical aggression,
fairness, comfort and performance remain for creator review in Training.
