> **26 October creator correction:** normal gameplay now enables a shared
> reaction for every accepted power-up, fusion and support reward. No timing or
> comparison choices are part of the player build. The six detailed Rook clips
> are reused by recipe for other upgrades; other survivors use their own
> idle/brace/settle poses with the shared infusion. Earlier opt-in/six-only status
> below is historical. The creator explicitly requested this functional shared
> coverage before further unique art. Physical review remains open.

> **Current six-family infusion slice:** [normal-speed clips and implementation notes](validation/upgrade-six-infusion-2026-10-25/README.md).
> All six now have separate Rook body performances and material paths using the
> creator-approved slower 1.1s rhythm. This is still a review candidate; broad
> all-family/survivor coverage and physical/player gates remain open.

> **Visual direction corrected after creator rejection:** the shared equipment-fitting
> sequence did not meet the requested power-infusion experience. See
> [the Heavy Load absorption candidate](validation/upgrade-infusion-2026-10-25/README.md).
> Earlier visual evidence below is historical, not accepted. The candidate now
> uses eight absorption frames per facing; full family/survivor coverage is pending.

# Upgrade feel: Rook review candidate

25 October 2026. **Player review pending. No visual, audio, comfort or balance acceptance is claimed.**

Mobile source identity is **1.0.0+24**, admin **0.2.0+2**, combat package **1.0.0**; the identity API has no package version. These come from the actual manifests, not the historical +23 planning note. Initial working trees were clean. No changes have been staged, no balance was published and shipping deployment pins remain untouched.

## What is available

A separate review entry point compares the original flow, a 300ms first-rank beat and a 420ms first-rank beat. Later ranks use 260ms; Reduced Motion uses a stationary pose for 180ms. Shipping `main.dart` keeps the original flow until the player gate. Prototype families: Heavy Load, Fleet Foot, Scrap Armour, Hot Shot, Ricochet and Sentry Gun supply deployment.

Run on a phone:

```sh
flutter run --release -t tool/upgrade_feel_review.dart --dart-define=REGUN_UPGRADE_FEEL_REVIEW=true -d DEVICE_ID
```

Choose a floor and timing. In Training, open Pause → Upgrade feel review and choose a family. The ordinary picker commits that practice choice. Play with movement/aim/dash/grenade touch controls; turn to each of the four facings before choosing. Compare with the original flow. Settings retain Reduced Motion, SFX volume/mute and Haptics. The review launcher does not persist new settings or change published balance. Review practice does not spend normal profile currency or alter unlock/admission rules.

For Scrap Armour, enable **Pause → Survival practice → Take damage → On** before judging absorption. Protected Training cannot demonstrate a blocked hit. Keep a real enemy in range and observe guard consumption/recharge; being undamaged while Take damage is Off is not evidence of guard strength.

Sentry practice is a real temporary deployment. Let it land and acquire a target. There is no invented instant turret, free shot, ammo or immunity. Placement can wait for legal space; the acceptance label therefore describes deployment when clear rather than promising an exact arrival in a blocked scene. At VIII, the real deployment remains VIII.

## Audit and evidence

- [Coverage inventory](validation/upgrade-feel-2026-10-25/coverage.json): all 43 offered families, eight fusions, two supports, Scrap Cache fallback and legacy Long Dash. Includes source references and actual hosted admission.
- [Component summary](validation/upgrade-feel-2026-10-25/component-summary.json): every family across all 24 weapons × ten survivors, 0→I, I→II, III→IV and VII→VIII, plus both capacity transitions. Full resolved input/output data is reproducible under `build/upgrade-feel-audit/resolved-components.json`.
- [Motion manifest](validation/upgrade-feel-2026-10-25/motion-manifest.json): actual runtime renders at 844×390 logical pixels /30fps, both floors, original/new six-family flows and Heavy Load 300ms/Reduced Motion alternatives. These are muted headless Flame-canvas renders; the Flutter picker/HUD layer is not recorded. They are not a physical phone recording or FPS measurement. Use the playable app to judge full-overlay overlap and touch reach.
- Runtime measurements, verification logs and decoded-art measurements are in [the evidence directory](validation/upgrade-feel-2026-10-25/).

Regenerate the audit with `python3 tool/audit_upgrade_feel.py` and `flutter test --no-pub test/upgrade_feel_baseline_test.dart`. Regenerate six-family captures with `REGUN_UPGRADE_CLIPS=1 flutter test --no-pub test/upgrade_feel_prototype_test.dart`; add `REGUN_UPGRADE_ALTERNATIVES=1` for the 300ms/Reduced Motion alternatives. The capture harness explicitly suppresses automatic Training reinforcements so the same authored ordinary targets can expose real mechanics; the player review app retains normal Training pressure. It supplies a later ordinary target for the delayed sentry opportunity. The runtime presentation never creates a target or guarantees a proc.

The audit distinguishes compatible components, capped steps and incompatible kits. It does **not** turn component projections into full DPS, useful-frequency measurements, live production values or perception findings. The full per-family time-to-opportunity/usefulness/balance investigation outside the six-family slice remains open. The plan also assumed distance-driven survivor gait; source inspection found phase-preserved12Hz cycles instead. That motion-coherence diagnosis remains visible in the audit rather than being silently treated as completed. No blanket buff, offer-weight change, catalogue regeneration, default reset or numerical publication was made.

## State and authority

Native commits publish a typed receipt with generation/actor/serial/offer/source/chosen ID, old/new rank, pinned balance identity and resolved components. Rejected/stale choices, rerolls, bans and ordinary pauses do not emit it. The old notification counter remains a compatibility signal; the game consumes the typed receipt once for its existing recovery flag. Recovery radius/damage/shove/projectile clearing/protection rules are unchanged.

The presentation owns its clock, holds world updates and clears input. It does not call zero-dt component updates during a hold: queued collisions or delayed actions can release even at zero dt. Reload HUD ticking is held too. Pause, focus/lifecycle interruption and background freeze the beat. Restart, death, training recovery and weapon change cancel presentation. Original selection remains 0.1×. The review entry point reuses the production GameApp audio/lifecycle wrapper. One existing restrained recorded mechanism cue is reused for confirmation with its existing volume/mute gain; a family audio mix remains for listening review. The native confirmation emits one preference-gated haptic.

A versioned optional receipt is saved **only while the cosmetic beat is unfinished**. It is bounded and validated. Continue shows a static readout, never replays the animation or applies a reward. The existing saved recovery flag remains independent and is consumed on active resume. Old checkpoints have no cosmetic receipt. First-use cues are not restored and consumed readouts do not reappear from normal snapshots.

First-use emphasis is bounded per prototype family, expires after 20 active seconds and observes actual accepted primary damage/burn, real traveled movement, guard absorption, purchased bounce continuation and physical sentry release. A later choice must not discard a still-pending sentry/burn cue. There is one short readout slot, not a stack of auras; it is separate from the combat-effect budget. Ricochet attribution waits until the purchased bounce budget is used rather than crediting Revolver's first innate bounce.

Server protocol8 is discovered through `upgrade_confirmation`; review clients request8 only with `REGUN_UPGRADE_FEEL_REVIEW=true`. Existing protocols1–7 remain admitted under their existing rules. The server stores bounded accepted receipts inside authenticated fighter progress. It starts a shared hold only after all choices/timeout resolution and only with unanimous protocol8 support. The server resumes everyone and consumes existing recovery flags; art/network acknowledgments cannot extend the hold. Dead actors cannot leave a choice pending forever. Versus has no supported reward path and gains no global freeze.

Accepted receipt generation records the request's input epoch. Phase changes bump that epoch, so client presentation watermarking uses room/match identity, actor and serial; it must not reset at every input epoch. Reconnect establishes a watermark and does not celebrate history. The local three-client smoke exercises early choices, real timeout/autoselection, shared held combat time, deferred recovery, scoped receipt identities and reconnect serial continuity. It uses an isolated custom test balance and proves neither native online rendering nor physical performance.

Hosted combat remains five weapons/three survivors/35 families/six fusions. The broader numerical catalogue is not combat admission. The API rank preview now reports `onlineSupported`, and admin explains unsupported hosted combinations without exposing new content or adding visual balance knobs. All 368 fields and 13 historical catalogue definitions remain intact. No admin publication steps are needed for this presentation candidate; matching protocol code would need the normal deployment process before hosted review.

## Art and unresolved acceptance

One generated Rook fitting packet provides 24 new full-body poses (six frames × four facings), with separate family props/material/attachments and actual-mechanic readouts. It does not recycle hurt/death, rotate a body bitmap or use another survivor's poses. This **shared fitting recipe is itself a prototype**, not six approved final body recipes. Feet, hand/weapon alignment and family recognition must be judged in motion. Weapon attachments follow the actual gun heading.

The built-in imagegen skill produced the packet. Its immutable master, prompt, provenance and SHA-256 are in `art/source/upgrades`; `tool/import_upgrade_art.py` uses the existing survivor alpha importer. Assets are lazy, owner-leased and prewarmed during selection; a failed/pending load uses a deliberate steady survivor pose. Confirm never awaits art. No other survivor/family/fusion packets were mass-produced.

Decoded-art peak is measured with Rook, the largest pair, every equipped weapon, supply art and all support atlases. This is only a decoded-texture measurement. Phone load spikes, allocations, frame pacing, audio overlap, touch comfort and crowded threat readability still require hands-on review.

## Required player gate

Use at least five players, preferably including those who reported the problem. Randomize original/new clips and hands-on runs; do not tell them which cue to seek. For each of the six families ask “What changed?”, “When did you notice it?” and “Did it feel useful/stronger?” Log eligible opportunities and procs that never occurred. At least four of five should identify the correct kind of benefit without Details, observing the next real eligible mechanic. Also record pacing and threat readability, muted/unmuted, Reduced Motion and touch controls. Require no accidental actions, misleading immunity reports or lost-threat complaints in the observed trials.

Record each player's responses, opportunities, timing preference, strength/pacing/threat scores and issues in `player-review.json`. Creator phone sign-off is still required. If players recognize only a celebration, revise the relevant recipe/mechanic/balance diagnosis. **Do not start the remaining survivor/family/fusion art or call this accepted until this gate passes.**
