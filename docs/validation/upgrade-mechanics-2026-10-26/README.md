# Upgrade mechanics and infusion assignment candidate

26 October 2026. Normal gameplay, **not a comparison launcher**. Visual acceptance
remains open. Creator approval of the fire's direction is retained; no blanket
approval of these new effects or every survivor/kit is implied.

## What changed

- Real FreezeState now shows three body-clinging, fractured frost crusts. The
  existing .6s freeze/.2s recovery govern hold/thaw, and Reduced Motion omits falling
  fragments. Exposed Seam does not freeze anything on its own. Boss immunity stays.
- Actual Targeting Link marks receive four worn corners and a small focus seal
  outside the body. Face, attack pose and burn patches remain visible. Native and
  online use the same seal; the client never creates a mark from owned rank alone.
- Actual electrical chain paths retain their existing geometry and duration with a
  short target discharge. Upgrade/innate roles are distinct; the accepted quiet
  companion links remain quiet. Native chain visuals now require an accepted hit;
  no damage/proc/target changes accompany this visual correction.
- Positive accepted healing adds a short body-to-medical cue. Real Field Medic,
  Suture, Vitality, salvage and boss HP grants share it. Full health, failed rolls,
  blocked damage, ordinary kills and restore/reconnect do not invent a heal.
- Last Shell, Breach Loader and Measured Shot use compact weapon-local ready
  seams. One short consume accent accompanies the actual release. Final-round
  ammo, completed-reload charge, idle threshold, reload lock and compatibility
  remain authoritative; three perks share one bounded presentation.
- Actual native purchased ricochet/penetration contacts and conditional
  Executioner/Exposed Seam/Close Quarters bonus contacts receive bounded victim
  accents. They do not add damage, hits, force or crowd control. Death suppresses
  lingering status. Contact refresh is capped per body rather than per pellet.

Already visible mechanics retain their real behavior: magazine/refill HUD snap,
weapon firing/reload, projectile counts/spread/speed/range, reserve controls,
dash protection, attracted XP, material mines/grenades/shards, real companions,
sentry deployment/fire/battery and the accepted muted Aura Salad. Lucky Find has
an offer outcome, not a fictional combat proc. None of these receive an unrelated
aura merely to claim a new effect for every family.

## Deliberate reuse of the six infusion performances

`upgrade_animation_recipe.dart` now matches gestures to mechanics:

| Performance | Reward groups | Reason |
|---|---|---|
| Grounded open/absorb/brace | Raw damage, magazines, scatter/shards, ordnance force, first/final-round power | Weight and contained force entering the body |
| Crouch/rise ready | Mobility, reload speed, trigger speed, projectile speed | Quickness through legs and hands |
| Cross forearms/compress | Guard, secondary reserves/recharge | Retained defensive/reserve capacity |
| Cupped hands/draw inward | Fire, electricity, healing, Aura Salad | Accept energy into the body; amber fire, cool electrical, sage medicine |
| Palm/forearm deflection | Ricochet, penetration, range, precision/marking | Controlled redirection and deliberate aim |
| Palm charge/command | Sentry, drones, mine deployment, acquisition utilities | Direct autonomous equipment or gathered supplies |

The original six clips are reused; there is no new mass-produced survivor art.
Body recipe and effect color are separate: a healing/electrical charge can use
cupped hands without acquiring orange fire fragments. Rook retains authored
clips; other survivors retain their own identity and existing brace/settle path.
Freeze/absorb/impact and exactly one existing recovery pulse keep their timing.

## Evidence

Watch **player-review.mp4** at normal speed: Breach, Foundry, then four remapped
normal accepted choices (Field Medic, Static Charge, Last Shell, Sleight of Hand).
`reduced-motion.mp4` shows the steady alternative. Individual clips are provided
for inspection, not player-facing timing/animation choices.

844×390, 30fps game-render captures; **not physical-phone footage or measured FPS**.
The controlled fixture uses real enemy movement, hit/mark/burn/chain state, accepted
freeze and actual thaw, real HP recovery and accepted final-round release. Freeze
is invoked through its accepted state method to isolate the status; the existing
Frost Shotgun integration covers its combat source. Remapped selections use the
existing Training offer helper and normal accepted-choice/recovery path. No live
proc chance, spawn, targeting or damage was changed to obtain a clip.

Automated verification: full game suite 775 passed / five intentional skips; after
final optional authority metadata and lifecycle refinements, 58 focused tests
passed. The four new capture/lifecycle/remapping tests passed. Analyzer clean.
Backend typecheck, all 187 tests and module build passed. No new texture packet,
particle components or RNG rolls were introduced by this pass. Existing decoded
art ceiling stays 32MiB; this does not establish physical frame pacing.

## Authority, safety and explicit remaining work

Server source adds optional cumulative accepted HP recovery, accepted-release
perk flags, and chain role metadata. Clients watermark the first snapshot and
clear cosmetic tracking across disconnect/suspension. No client submits damage,
heal, mark or freeze outcomes. Older servers retain steady states without invented
transitions. Measured Shot and Frost Shotgun remain outside hosted admission.
Native contact accents are not yet serialized for all hosted contact branches.
**Server changes have not been published; live co-op verification remains open.**

Pause/picker/confirmation/background retain existing clocks. Continue settles
cosmetics via generation watermarks. Death/deployment settle transient healing and
shot cues. Existing damage feedback keeps priority. No stat, cadence, reload,
range/speed, hitbox, protection, shove, reward, catalogue or admin setting changed.

API `/admin/ranks/preview` and admin `rank_path.dart` already resolve pinned rank
components and explicitly distinguish previews from hosted admission. They need
no cosmetic settings or numerical publication for this client presentation pass.
Existing current/historical catalogues and staged work are preserved.

Every one of the 55 inventory identities has an explicit source disposition in
`docs/art/UPGRADE_COMBAT_VFX_COVERAGE.json`. This records changed/retained/unsupported
paths; it is not a completed physical or all-kit visual acceptance audit. Native
pre-acceptance burn/mark and weak-point proc eligibility differences remain a
separate mechanics investigation, unchanged here. Ignition/spread/extinction
accents, broad pack/boss/overlap/large-text/left-handed review, useful-frequency
balance evidence, live authority/reconnect and device performance remain open.

Delivery: normal signed `lib/main.dart` release **1.0.0+24** built and installed on
the paired iPhone, then launched successfully. No internal review launcher or
player-facing timing/animation options were installed. Earlier IPA exports do not
contain this revision. Installation does not grant visual/performance acceptance.
