> **26 October creator correction:** normal gameplay now enables a shared
> reaction for every accepted power-up, fusion and support reward. No timing or
> comparison choices are part of the player build. The six detailed Rook clips
> are reused by recipe for other upgrades; other survivors use their own
> idle/brace/settle poses with the shared infusion. Earlier opt-in/six-only status
> below is historical. The creator explicitly requested this functional shared
> coverage before further unique art. Physical review remains open.

# Six upgrade infusion sequences

Creator approved the slower Heavy Load direction and requested proceeding with
its rhythm. This slice replaces the remaining five shared body clips with five
new authored Rook performances, eight frames in four facings each:

| Family | Body reaction | Incoming power |
|---|---|---|
| Heavy Load | Open, absorb, contain, grounded settle | Three brass/iron currents into chest |
| Fleet Foot | Lower into runner crouch, rise ready | Ground currents gather at legs/boots |
| Scrap Armour | Cross forearms, compress, square shoulders | Eight iron facets close into chest |
| Hot Shot | Cup hands, draw heat inward, close fists | Spiral of ember fragments |
| Ricochet | Palm/forearm deflection, contain at sternum | Angular inward paths with three bends |
| Sentry | Palm charge, chest acceptance, command gesture | Stepped compact signal packets |

Every first acquisition uses the accepted 1.1s rhythm, including a 220ms crest.
Later ranks use 800ms; short comparison is 750ms. Reduced Motion retains 180ms
with settled body frame and a static family-specific motif. No flying power,
body reaction, flash or focus shading runs in Reduced Motion.

**Watch `six-infusions-review.mp4` at normal speed.** Order is Heavy Load, Fleet
Foot, Scrap Armour, Hot Shot, Ricochet, Sentry; each section is 4.1 seconds.
Individual Breach and Foundry clips are also supplied. They include 0.8s live
lead-in, the freeze/infusion and live resume. The longer Sentry clips retain
actual delayed arrival/firing. Capture is 844×390 Flame canvas, 30fps cadence,
muted, with labels hidden and no Flutter picker/HUD overlay. It is not a phone
recording, phone FPS evidence or native audio/listening proof. The controlled
scenario targets expose actual opportunities; runtime does not invent targets,
guarantee procs or change support deployment/reward probabilities.

The review web build remains opt-in. Main gameplay still defaults to original
flow while the broader player gate remains open. The creator approved the Heavy
Load direction; five-player identification and creator physical-device acceptance
for the complete slice have not been recorded. Do not call all-family/all-survivor
coverage complete or manufacture player results.

Source masters/prompts/hashes: `art/source/upgrades/family_generation.json` and
`infusion_generation.json`; authored using built-in imagegen. Import with
`python3 tool/import_upgrade_art.py`; original pixels are retained unchanged.
The earlier equipment-fitting source is historical/rejected, not used here.

Only current offered/accepted recipes retain leases. Native prewarms offered
families during the picker, then retires alternatives after commit. Online uses
authoritative offers/receipts; loading cannot extend the server hold. Failed
loads use the existing steady body fallback. Tests cover switching recipe sets
while older loads are pending, plus disposal/failure/retry. The combined art
budget test deliberately retains all six recipes with the largest boss pair,
support/supply art and each equipped weapon: **31,898,496 bytes (30.42MiB)**,
under 32MiB. This is decoded art, not device performance.

Nine focused tests pass, including the full 24 baseline/prototype combinations,
held reload/grenade checkpoint safety, receipt/watermark control and texture
leases/budget. Analyzer is clean. Tests establish correctness, not visual approval.
All six real mechanic observations still occur on both floors; timings are in
`runtime.json`. Damage feedback keeps priority over temporary body infusion tint.
No numeric balance, API/admin catalogue, online admission, damage/reload timing,
recovery pulse or supply deployment schedule changed in this slice. Online keeps
the existing authoritative shared 1.1s/800ms hold and now selects the actual family
body packet/material. No server schema or admin publication is needed here.

Reproduce captures:

```sh
REGUN_UPGRADE_SEQUENCE_CLIPS=1 REGUN_UPGRADE_CLIPS=1 flutter test --no-pub --dart-define=REGUN_UPGRADE_HIDE_LABELS=true test/upgrade_feel_prototype_test.dart
```

Remaining: creator review of these five variants, four-facing in-game review per
family (these clips cover established different facings), broader five-player
product gate, device motion/audio/performance and all other family/survivor assets.
