# Ariet normal solo admission, ordnance and reinforcements —29 October2026

Creator explicitly authorized normal-run admission for testing. Release remains
**1.0.0+28**. This supersedes earlier Training-only restrictions for native Solo.
Online combat and Boss Rush pairs retain their existing roster; no unsupported
network Ariet is advertised or routed into a legacy boss implementation.

## Hit registration and timed shells

The previous `_passHit` rule allowed only one accepted rotary hit across an entire
36-round sequence. Later visible contacts therefore did not lower health even
after the player's ordinary protection ended. Replaced with a shared .5-active-
second gun-contact interval, set only after accepted damage. Normal player damage,
protection, Training Take damage and feedback remain authoritative. Later eligible
contacts in the same volley now register; overlapping bullets cannot stack instantly.

Heavy cannon shells commit a visible floor impact point on release, clipped to
cover and80–900 units from the muzzle. Travel is clipped to that point and the
shell bursts there, or earlier at actual swept body/cover contact. Fallback lifespan
expiry also detonates instead of deleting a heavy shell. Same2HP cover-tested
blast and70-radius material footprint; player-body edge inclusion remains26.
Above-actor core/flame/smoke and planted floor material use the existing atlases.
Ordinary machine-gun rounds remain non-explosive straight projectiles.

## Optional staggered reinforcements

One deterministic per-encounter support decision:25% none,45% one,30% up to two.
Enraged cargo passes stage **one** Walker each. A second is considered only after
at least20 active seconds and either≤25% boss health or32 seconds since the first
release. It may never occur if the fight ends or no legal route/site exists. No
simultaneous scheduled pair and no replenishing dead escorts beyond the total quota.

Candidate sites alternate side/approach, retain≥420 units from previous drop sites
and≥340 from living/pending escorts at release/activation checks. Clear planted
landing warning and physical fall/unfolding remain; unexpected timing does not mean
an invisible spawn. Capacity counts pending release and checkpointed history.
Unsafe releases abort without duplicating future actor IDs. Paused clocks do not
advance the later-reinforcement window.

Escorts remain55% size/50HP, now intent365 world units/s, max385 and acceleration1050.
Only escort rigs use64 standing height (was88),10% wider lateral stance,.18s diagonal
step transfer and12-unit foot lift (was26). At least two feet remain planted. Defaults
and full Walker mechanics remain unchanged. A regression compares actual displacement
to the previous rig and requires>12% more travel, lower stance and bounded foot lift;
this is simulation evidence, not physical-device motion approval.

## Normal lifecycle and persistence

BossKind.ariet participates in the native normal director's randomized bag: nine
active native bosses. It has its own factory, air rig, HUD/ordnance targets and
mechanical arrival/destruction; never a Queen/Expansion/portal fallback. It is solo,
with its owned escorts. Normal completion waits until the crash/wreck timeline ends,
then awards one victory/score/XP/core, health reward and per-boss history, and clears
the director. Training remains without normal profile rewards.

Checkpoint schema retains its existing outer compatibility and adds a validated
Ariet payload: ground pose, phase/destruction progress, active time/random/attack
cycle, quota/release history and pending drops, plus owned escort positions/HP.
Unreleased warning-only drops abort safely on Continue; released falling units
finish once; activated units are restored from their owned records. Living hostile
rounds/warnings are discarded and an alive boss resumes navigation with1.5s grace,
consistent with ordinary safe-resume semantics. Dying checkpoints finish once.
Owned escorts never become unknown standalone enemy records. Pending loads, restart
and late removal cannot resurrect an old owner or clear a replacement's pointer.

## Verification

Client analyzer clean; **926 passed /5 intentional skips**. New coverage includes
normal bag admission, pre-load autosave validity, owned-escort Continue, preserved
health/quota, transient-shot cleanup, dying Continue and exactly-once victory/core;
rotary repeat contact; ranged/body/cover shell detonation; all reinforcement variants,
separation/time limits; pending-drop pause/save no replay; faster grounded gait.
Legacy portal/pair/online fixtures explicitly use their supported rosters; existing
legacy boss coverage remains, with dedicated Ariet native coverage alongside it.

Final native recording/admission run: **3 passed**. [Combined encounter](native.mp4),
[review strip](review-strip.jpg), [actual normal-run scene with one escort](normal-one-escort.png),
[escort movement measurement](escort-metrics.json). These are staged test renders;
normal test health is raised to inspect lifecycle rather than measure balance.
Physical readability, aggression, fairness, FPS/thermal behaviour and listening
remain for creator review. Lodestar runtime construction remains gated by that review.

## Cloud profile compatibility

Backend patch **20ca419** accepts `ariet` in Solo victory history without adding it
to authoritative online encounters. Typecheck,209 tests and SpacetimeDB build pass.
Creator approved deployment; source pushed to main. Live rollout/verification is
pending authenticated Dokploy access: configured VPS SSH key is absent and the
opened dashboard requires sign-in. Source publication is not deployment proof.

Final device result: signed iOS build (Xcode30.4s), successful installation
sequence8368, launch confirmed and fresh device app query **1.0.0/build28**.
Client source remains uncommitted; backend compatibility20ca419 is pushed to main.
Live backend verification awaits Dokploy authentication, not further deployment
permission: creator already explicitly approved it. Existing SSH configuration
references missing id_ed25519_vps; fallback existing key did not connect. Chrome
Dokploy sign-in tab1031406723 (browser2) is kept for handoff. Resume there after
sign-in, deploy/verify20ca419 while preserving the existing state volume and online
policy, and update this evidence; do not equate the source push with live rollout.


## Main push and public API checks —29 October2026

Creator clarified that pushing the server to main is the required release action;
no manual Dokploy rollout/login is needed for this request. Git remote main is
confirmed at **20ca4190bbac9d1aae8ef03a4e06b1ff7d8f2c99**, with a clean backend checkout.
Public live checks: health200; features200 with valid schema1/onlinePlay:true and
no-store; OIDC discovery200 with issuer/JWKS metadata; unauthenticated account401;
private raw SQL403. [Results](api-check.json).

These prove public API availability and expected access controls, not the deployed
commit identity or a successful authenticated Ariet-history upload. The new history
validator is covered by the209 passing backend tests/build already recorded.
