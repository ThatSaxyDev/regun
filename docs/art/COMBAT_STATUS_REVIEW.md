# Burn and guard: first implementation candidate

26 October 2026. Candidate, **not visually accepted**. Normal-game entry point;
no additional player-facing demo controls.

## Current implementation

One independently leased 512px shared flame packet (524,288 decoded bytes) follows
real burn/cinder state. The creator rejected the first version: two flanking fire
clumps looked pasted around the enemy rather than burning on it. Version 2 removes
that front/rear composition. Three small, staggered flame licks catch at body-bound
torso/hip/leg patches, with restrained warmth applied to the actor's own alpha and
texture. Boss/online grading retains arena ambient treatment, and hit feedback
still takes precedence. No white glow or obscured head.

Eight distinct licks stretch, split, collapse and reform. Equal-sized source
windows preserve those height changes rather than stretching every frame's alpha
bounds into an equally tall icon. Bases stay planted. Reduced Motion holds fixed
poses and omits motes; concurrent burn/cinder still draws one composition.

Replacement art uses built-in image_gen with the mummy walk atlas as a style
reference. Source: `art/source/status/status_flame_master.png`; full prompt and
provenance: `art/source/status/generation.json`. Rejected v1 source/provenance are
retained separately. Importing copies source pixels unchanged and measures frame
windows; runtime only changes draw placement/size/paint.

Scrap Armour and Warden now use a body-scale faceted sage/iron ward rather than
the old tiny foot badge. Actual accepted absorption and recharge serials trigger
break/reassembly; generation changes initialize silently. Guard readiness remains
the existing gameplay boolean. No new collision, protection, damage or recharge
rules. Native and online use the same painters. Server serial additions are source
changes only: **hosted deployment has not been performed**. Old servers retain
steady ready-state rendering without invented break/recharge events.

Pending loads retire safely on restart/disposal. Failed decodes use a muted flame
fallback without retrying every frame. Persistent status draws do not spend the
transient combat-effect cap. Offscreen fire is culled; at most two motes per visible
burning actor, with no particle components or gameplay RNG.

## Captured evidence

Normal-speed, 844×390 game-render captures, not physical-phone footage:

- `build/combat-status-clips/breach-burn-v2.mp4`
- `build/combat-status-clips/foundry-burn-v2.mp4`

These show a real moving ordinary enemy burning to expiry, Warden's ready ward,
and an accepted shield absorption with unchanged HP. Recharged steady-state frames
are in each arena's `recharged-*.png` sequence. Clips were recaptured after the creator rejected the separate fire stickers;
these show the revised body patches and surface grade.
They are evidence for review, not visual or physical-performance acceptance.

All-survivor/all-weapon texture fixture, including the largest boss pair, all six
infusion packets, support/supply and this status packet: peak **32,422,784 bytes**
against the unchanged 33,554,432-byte ceiling. Texture accounting does not establish
native frame pacing or readability.

## Review still required

Phone motion/readability, packs and boss bodies, overlapping freeze/mark/warnings,
Reduced Motion comfort, survivor proportions, live co-op/reconnect and native
interruption/performance remain open. Ignition/spread accents and extinction ash
are not yet authored. The remaining coverage groups in the implementation plan
are planned work; this slice does not complete the 55-identity visual audit.

## Build and verification record

Normal `lib/main.dart` signed release **1.0.0+24** built and installed on the
creator's paired iPhone on 26 October. Installation is not physical acceptance.
The earlier exported IPA is not this candidate and must not be distributed as it.
Analyzer clean. Status lifecycle/capture tests pass; all-survivor texture budget
passes. Full suite produced 771 passes and five skips with one fusion-proc fixture
still counting the recovery-pulse visual. After allowing that existing visual to
retire before counting fusion effects, the full-run test passed separately. Other
legacy fixtures were likewise updated to finish the normal upgrade hold before
asserting active mechanics; no gameplay rules were changed for those fixtures.
Server typecheck, all 185 tests and module build pass. No hosted publish occurred.

## Version 2 revision after creator rejection

The creator rejected the original fire's art direction and detached appearance.
That version is not accepted. Version 2's body patches, surface grade and planted
short licks replace it in the normal signed iPhone build installed on 26 October.
Analyzer and all 83 focused arsenal/survivor/texture-budget tests pass, as do the
three status lifecycle/capture checks. Both arena motion captures were regenerated.
Decoded-art peak remains 32,422,784 bytes. Damage, duration, spread/recharge rules,
upgrade hold/pushback, and the shield presentation are unchanged by this revision.
Creator visual acceptance and physical crowded-combat comfort remain open.

## Brighter flame follow-up

The creator liked version 2's direction and requested a little more brightness and
visible flicker. The same body patches now use brighter warm flame values with
small, staggered luminance swells; the actor texture and arena do not flash. Flame
coverage, animation poses and all gameplay values are unchanged. Reduced Motion
uses a steady middle brightness, fixed pose and no motes. Paint/filter variants
are cached rather than allocated per burning actor per frame. This feedback is
approval of direction, not acceptance of the remaining coverage or phone comfort.

Brighter follow-up verification: analyzer clean, all three status lifecycle/capture
checks pass; regenerated normal-speed evidence is `breach-burn-brighter.mp4` and
`foundry-burn-brighter.mp4` in `build/combat-status-clips`. Normal signed release
1.0.0+24 rebuilt and installed on the paired iPhone. Physical visual acceptance
remains with the creator; no hosted server changes or gameplay balance changes.
