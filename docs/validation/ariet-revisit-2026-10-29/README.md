# Ariet detonation, escort tactics and size revisit —29 October2026

Release stays **1.0.0+28**. Ariet remains Training-only; Walker remains in normal
solo rotation (BossKind.active / EncounterDirector), Training and capable co-op.
Ariet's two escorts belong to its Training candidate, not the normal spawn roster.

## Corrections

Previously rocket contact/interception drew only subdued floor effects; expiry
used a drifting/fading intact rocket. All exits now produce a planted finite
burst: floor scorch plus visible material core, short expanding flame tongues
and smoke on the ordnance layer above actor art. Contact retains its existing
blast damage/cover rules; shot interception and expiry self-destruction remain
harmless. No new texture decode or damage multiplier. One-shot rocket removal,
impact budget, pause and destruction cleanup remain.

Previous player-relative goals could both trail a moving survivor. The pair now
holds explicit pressure/intercept roles: a nearer actor uses a legal clear firing
perch, while the other targets ahead and to the side of the survivor's smoothed
movement. Roles hold4s and exchange when the relief is in range with sight; death
releases membership immediately. Reversal hysteresis avoids per-frame role swapping.
Heavy-attack exclusion releases the firing perch. Cover/lane/body checks and legal
curved approach remain; no actor pursues its partner as its target.

Both escorts now use **55%** scale, down from67.5%:18.5% smaller linearly, about33.6%
less area per equally posed silhouette. Body radius48.4, actor size, IK/feet,
projected muzzle and folded/deployment art share that scale. World intent310,
max324 and acceleration880 are independent of scale; shrinking cannot silently
slow pursuit. Health50, range/damage, three-round cadence, shared gate, major-attack
exclusion and owner cleanup remain. Full Walker is unchanged.

## Verification and evidence

Initial rocket/escort/scale capture: **36 passed**. The actual native encounter tests every rocket
exit (contact, wall, interception, expiry) for airborne ember pixels in both motion
settings, along with the real complete fight, all24 weapon paths, body/traffic,
rear damage, moving-player hits and disposal. The moving-player measurement requires
both shooters and a substantial portion of separate actual firing angles; pure tests
require a forward cutoff plus a distinct firing perch, role stability/exchange and
blocked-position release. Rig tests include55% actual IK/cargo envelope.

[Game-layer recording](native.mp4) includes the continuously moving survivor section
after55 seconds. [Review strip](review-strip.jpg).
Burst stills: [shot interception](burst-intercept.png), [player contact](burst-contact.png),
[cover contact](burst-wall.png), [expiry](burst-expiry.png).

Capture is staged native game-layer rendering with health restored after accepted
hits, not physical-phone footage or proof of tactical fairness/performance. Actual
aggression, visual readability, comfort and sustained performance need creator review.
Lodestar runtime construction stays gated behind that Ariet acceptance.


Actual final native moving-input measurement:12s /480 samples,380 samples with
>0.9rad separation (79.2%),30 escort rounds and10 accepted hits with health restored
after each accepted loss. Both actors exercised both tactical roles. These values
verify test behaviour, not human difficulty or physical-device performance.
[Machine-readable measurement](escort-metrics.json).

## Flight, distance, framing and cadence follow-up

Creator additionally rejected constant nose-to-player following and allowed wider
camera views for both machines. Ariet now holds a sampled flight focus for1.2s,
uses a520-unit stand-off target (was400), bounded190 radial correction and smooth
course changes capped1.6rad/s except urgent cover steering. The hull faces its
flight course; independent roof weapons retain fast all-direction targeting.
Charge/cargo commitment, real braking and brief planted floor attacks remain.

Rotary acquisition predicts from observed movement/turn rate, capped1.3s and360
units, then releases straight rounds. This prevents the wider firing platform from
making constant circling trivially safe; reversals after release remain dodgeable.
No projectile gains homing. Damage and volley counts remain. Counter spacing .06→.05s,
cannon .35→.30s and seeker .30→.28s modestly restore ranged pressure; warnings,
seeker guidance limits, shared capacity and true quiet recovery remain unchanged.

World zoom targets: Ariet .74, Walker .80, other bosses .88, ordinary play1.0.
The existing eased transition, pause/recovery/reveal ownership, camera bounds and
Reduced Motion handling remain. Only the world zoom changes; native assertions
check that HUD controls keep their positions/scales. New regression separates hull
course from rapid gun acquisition; normal-speed and fast orbiting targets still
receive actual damage, with all four weapon families and both phases retained.


Final combined verification: analyzer clean; **918 passed /5 intentional skips**.
Focused flight/framing/native Walker+Ariet run: **33 passed**. Same1.0.0+28.

Final wide-camera native recording: **1 passed**, preserving all complete-encounter
assertions and control/framing checks. Video/stills above updated to this final run.

Final combined release built/signed (Xcode28.0s), installed (Apple sequence8360)
and launched on the iPhone. Fresh device query confirms **1.0.0/build28**. No version
increment or distribution upload. Flight/cadence/tactical/size/framing feel remains
for creator physical review; Ariet stays Training-only and Lodestar remains a plan.
