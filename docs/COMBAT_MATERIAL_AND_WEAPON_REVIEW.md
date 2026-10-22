# Combat materials and weapon review — 22 October 2026

Current private candidate: **1.0.0+11**, fifteen solo/Training weapons. This pass
implements the creator's latest phone feedback and supersedes the affected
21 October weapon and warning notes. Multiplayer expansion stays gated; no server
rollout is included.

## Clean sweep of area presentation

| Surface audited | Result |
|---|---|
| Shield bash, Burster warning | Shared planted dusty/scorched floor footprints, below all actors. Shield bash releases a short iron/stone impact. No floating overlapping eruption stamps. |
| Burster and grenade/launcher blasts | Retain the approved sooty ordnance blast/scorch material. Burster timing, self-damage and no-reward self-detonation remain. |
| Sentinel strikes, poison areas, Foundry vents | New shared floor material atlas: cracked stone, olive seep, ember rubble. Warnings remain visible from commitment; active timing/damage untouched. |
| Boss circles, arrivals and spawn warnings | Same shared footprint renderer with arena ambient grading. Glass/shadow/iron keep distinct subdued material details. Collision shapes remain authoritative. |
| Sweeps and waves | Existing committed sector/annular geometry and inside pockets preserved; perimeter/ribbon warnings use planted scuffs rather than tall chunks. Tangible chain/glass attacks remain. |
| Armour/weak-point plates | Authored worn iron sprites replace pristine polygon plates. |
| Burning ground and heavy impacts | Shared floor materials; heavy floor impacts render below actors. |
| Skitter leap warning | **Creator rejected the old claw-strip path.** Quiet, dark-backed stone notches now show the complete committed route, with a planted104-unit landing footprint (52-unit radius), matching aimed weapon preview language. Visible immediately, fixed after commitment, no flashing/travelling arrow. Shared native/online renderer. |
| Solo health loss | Soft warm radial edge tint, based on the multiplayer treatment at lower .22 peak opacity (.11 Reduced Motion), linear .5s decay and a clear center. Existing HP/haptic/survivor cues, protection gates, pause freeze and reset behavior remain. |

The new transparent atlas is `assets/art/effects/grounded_areas.png`; prompt,
master, measured rectangles and hash are in `art/source/effects/`. The built-in
image generator was used with the approved grenade/spore atlas as the reference.
No source pixels/alpha were repainted. Shared arsenal texture decode640, new
area atlas256. The largest expansion boss pair plus Cinder/flow remains <=32MiB
decoded art. Review captures show both real arena floors and actual enemy warnings.

## Weapon behavior

- **Reaper Disc:** return destination updates to the live gun every simulation
  step. Return speed is at least950 or survivor movement speed+500; four-second
  return ceiling and cover/catch cleanup prevent permanent firing reservations.
  Per-leg hit ledgers and three-blade cap remain.
- **Belt-fed Repeater:**100 base rounds. After the existing .4s audible spin-up,
  cadence ramps from .085 toward .040s over eight continuous firing seconds.
  The100-round base belt empties before the full ramp, at a substantially faster
  cadence than its opening shots. Release/reload/input cancellation reset the ramp;
  pause freezes it. Existing fire-rate upgrades retain a .030s floor. Each shot
  samples a barrel offset of±2 along /±4 across the muzzle and existing bounded
  heading variation; flash follows that same offset in either facing. Shots still
  travel straight. No damage increase. Extended Tube/save validation supports its
  increased magazine; `arsenalReviewBalance:2` migrates old60/70-round bases once.
- **Rivet Driver retained:** a crowd-demolition gun. Plant up to two visible
  copper charges on a target (eight total), then reload to detonate. Each charge
  carries1.75 secondary splash damage at125 radius, previously1.25/90. Overlapping
  charges group into one blast. Killing a host triggers its planted charges after
  .12s, so dead targets cannot waste the payoff; normal three-second failsafe and
  reload fuse remain. Secondary splash bypasses frontal shields and keeps normal
  cover/body-edge rules; it does not recursively plant charges or trigger primary
  procs. Direct damage/cadence/reload remain unchanged. Brief kit copy states the
  promise: “Plant charges. Reload for crowd blasts.”
- **Frost Shotgun:**2.2 base damage per pellet versus Pump1.2, three pellets each.
  This replaces Frost's old.8. Freeze, cadence, range, reload and count stay intact.
- **Longwatch Sniper:** frontal normal shield retention is.40 for its primary
  armour-piercing rounds:12×.40=4.8 damage against8 base HP, so two frontal hits.
  Ordinary guns retain.30; unshielded/recovery/flank behavior and elite/cycle HP
  scaling remain. Stronger scaled enemies need not die in exactly two shots.
- **Spore Lobber:** every paid impact is intended to rupture, whether it hits a
  body, cover or its ground landing. The missing ground patches were a bug: the
  old code discarded them when decorative FX were full. Gameplay patches now use
  their four-slot budget and evict one cosmetic cue if needed, keeping total effects
  bounded. Finite range/age/stall resolution ensures a capsule cannot linger without
  rupturing. Each rupture plays one impact cue; body hits no longer duplicate it.
  Persistent patch damage remains .8/s for2.5s, strongest overlapping tick only.

## Burster movement correction

Bursters are **walking**, not levitating. The former approach renderer selected
one fixed cardinal pose, so its boots never cycled. The new16-pose atlas supplies
four gait phases in four directions, preserving gas mask, worn suit, canisters and
amber belly. Native phase advances per14 units of actual movement; blocked/frozen
or paused bodies cannot cycle from elapsed wall time. Warning/detonation still use
planted original poses. Metadata anchors the authored feet to a common baseline;
no procedural leg rig or sprite lift. The online adapter uses the same facing/gait
sheet with its existing authoritative phase clock. New walk decode384 / old
warning/death packet320 keeps the shared memory budget intact.

## Phone review

Training → Pause → Weapon Practice switches guns in the same encounter. Check:

1. Walk/dash away after throwing several discs; all should steer toward the live gun.
2. Hold a full Repeater belt, then compare early/late cadence and release/restart.
3. Plant Rivets across a pack; reload, kill a charged host, and compare shield splash.
4. Compare Frost/Pump raw hits and sniper frontal shields without upgrades.
5. Fire Spore capsules at bodies, near/far floor and cover amid many effects.
6. Watch Burster boots in four directions, then its planted explosion wind-up.
7. Dodge the committed Skitter path/landing marker; turn after commitment, test
   packs, both arenas and Reduced Motion. Warning duration/damage unchanged.
8. Take real unprotected damage in solo (enable Training Take damage) and compare
   the subtle edge highlight. Guard/protection must not trigger health-loss cues.

Automated tests and a successful install do not establish physical motion,
readability, difficulty, comfort, speaker listening or sustained performance
acceptance. Evidence is in `docs/validation/combat-review-2026-10-22/`.

Art deliverables (built-in image generation): [area atlas](../assets/art/effects/grounded_areas.png), [area prompt](../art/source/effects/GROUNDED_AREAS_PROMPT.md), [Burster walk atlas](../assets/art/enemies/burster_walk.png), [walk prompt](../art/source/effects/BURSTER_WALK_PROMPT.md). Original alpha and source masters are retained.

Final validation/delivery: analyzer clean,372 Flutter tests pass/five optional
skips;89 server tests plus typecheck/build pass. Shared art30.06MiB and largest
boss-pair/Cinder-flow <=32MiB checks pass. Signed133.5MB iOS release1.0.0+11
verified, installed in place and launched on creator iPhone12. Initial connection
reset4000 recovered on retry. No app-data clearing, IPA export or server rollout.
Physical acceptance remains for creator review.
