# Fifteen-weapon implementation progress

21 October 2026. Target: **15 primaries = four original + eleven additions**. The complete solo roster is implemented for creator review. Historical stage-one evidence remains below. See the [phone playtest guide](FIFTEEN_WEAPON_PLAYTEST.md).

**Device feedback revision:** [WEAPON_DEVICE_REVIEW.md](WEAPON_DEVICE_REVIEW.md)
supersedes the first candidate’s Hammer, fire/ordnance art, lobber input and
changed capacities/cadence. Longwatch Sniper now fills slot15.

## First candidate state (historical)

There are **fifteen selectable solo weapons**: Shotgun, Carbine, Revolver,
Arc Caster, Burst Rifle, Rail Lance, Rivet Driver, Cinder Hose, Reaper Disc,
Scrap Mortar, Belt-fed Repeater, Frost Shotgun, Prism Cutter, Spore Lobber and
Breach Hammer. All are directly available in Training. Normal unlocks use
settled lifetime boss counts (3/5/7/9/12/15/18/21/24/27/30 for the additions).
Training never grants rewards or unlocks. Existing profile fields/saves remain.

`ArsenalSystem` owns finite charge, spool, heat, melee and durable transient
state; bullet modes retain swept contacts and owner deduplication. Frost is a
real movement/attack/contact hold with thaw immunity. Innate Cinder burn is
separate from Hot Shot. Disc return hits and blast/patch ticks use secondary
semantics. Offers/fusions filter incompatible projectile families. No new
primary action button is introduced. Grenade aiming remains independent.

Selected weapon art uses pending-load-safe leases. Ten original transparent
three-part packets and three twelve-pose hammer survivor sheets are preserved
under `art/source/weapons`, with prompts, measured frames/hand sockets and
hashes. Hammer rendering and contact sweep share hand/head geometry; left
facing mirrors the presentation while retaining the committed sweep direction.
The largest expansion boss pair plus hammer packet/action art stays below the
32 MiB decoded-art budget. This is an automated texture check, not native GPU
performance approval.

Aim Assist applies to the solo roster through the same range/alignment/cover
helper. Cinder/Prism sustained audio owns one cancellable loop each; firing
transients play once per sustained interval. Pause/reload/disposal and late
loads cannot keep the voice alive. Prism shows HEAT/VENTING; large magazines
use proportionate HUD markers. Burst retains its accepted 1.4s tactical/2s
empty reload; other previous weapon contracts remain.

The online lobby still admits its original four supported weapons. Burst's
shared server slice remains local; the ten later native modes are **not online
implementations**. This delivery does not deploy or expand hosted room support.

Validation: clean analyzer, **349 Flutter tests passed / five optional skips**;
final sprite/HUD adjustments pass the 22-test focused suite; **89 server tests**,
typecheck and build pass. The existing 30/60-minute developed-build headless
soaks pass. All 73 new audio cues pass format, peak, DC, ending/seam checks;
92 combat assets and 44 reloads pass the shared audio checks. The new review
reel peaks at .4348 at configured gains. See `validation/fifteen-weapons-2026-10-21`.
Signed release **1.0.0+11** (130.0MB) passed strict/deep signature verification, was installed in place on the creator's iPhone12 and launched successfully. App data was not cleared. Phone delivery is recorded in that folder's summary. Physical motion, sound,
fairness, comfort, balance and performance remain for creator testing.

## Current native packet tracker

All rows below have distinct source packets, mechanisms, cues, compatible offer
filters and normal unlocks. Physical acceptance and online admission remain open.

| Addition | Combat and durable state verified |
|---|---|
| Burst Rifle | Separate .0/.1/.2 releases, atomic volleys, tactical/empty reload and saved recovery |
| Rail Lance | Cancellable charge, bounded piercing with .65 retention and saved recovery |
| Rivet Driver | Per-host/global payload caps, timed/reload detonation, dead-host last position and payload saves |
| Cinder Hose | Finite fuel ticks, exposed cone contacts, separate one-second burn and bounded sustain voice |
| Reaper Disc | Swept outgoing/return legs, fixed return point and per-owner saved hit ledgers |
| Scrap Mortar | Strength-selected clipped landing point, visible finite flight and exactly-once secondary blast |
| Belt-fed Repeater | Spin-up/release decay, bounded cadence/spread, box/rotor mechanism and sustain cleanup |
| Frost Shotgun | Three pellets, ordinary-enemy freeze/recovery/immunity and saved statuses; bosses/planted roles resist |
| Prism Cutter | Nearest-body clipped beam, thermal units/cooling/vent, capped capacity and saved cooling fraction |
| Spore Lobber | Swept capsule, finite floor patches, strongest overlap tick, saved lifetime/phase |
| Breach Hammer | Wind-up/active/recovery, measured hands for 36 poses, shared shaft/head sweep and spent-swing recovery |

## Historical first-slice implementation

The following records describe the earlier five-weapon stage. They are retained
as historical evidence and are superseded by the current fifteen-weapon state.

Burst is a native candidate, not approval of all fifteen weapons or completion of the full shared runtime architecture. Its authoritative TypeScript timing/spec model is implemented and tested, but expanded online admission/prediction remains pending. Client online choices exclude it and the server rejects it in current lobby loadouts, protecting older clients. No server deployment was performed.

| Packet | Implementation status |
|---|---|
| Original Shotgun/Carbine/Revolver/Arc | Retained; full regression passes |
| Burst Rifle | Native gameplay/art/audio/unlock/save integration verified; online admission and physical motion/listening/balance pending |
| Rail Lance | Planned |
| Rivet Driver | Planned |
| Cinder Hose | Planned |
| Reaper Disc | Planned |
| Scrap Mortar | Planned |
| Belt-fed Repeater | Planned |
| Frost Shotgun | Planned; creator requires three simultaneous ice pellets with real ordinary-enemy freeze, replacing Harpoon and single-slug slowing |
| Prism Cutter | Planned |
| Spore Lobber | Planned |
| Breach Hammer | Planned; survivor action-pose packet remains to produce |

## First-slice implementation

- Explicit `WeaponArtSpec` body/mechanism references replace enum ordinal addressing. All original four frame mappings and rendering dimensions are retained. Burst has measured magazine/bolt sockets and a shared mirrored muzzle transform; every pellet in an upgraded Burst volley shares that muzzle.
- `BurstFireClock` releases real rounds at0/.10/.20 seconds, with .60-second base burst starts and a .30-second Quick Trigger floor. Individual rounds read current aim, spend ammo and emit their own sound/flash. Release/reset/reload cancels unissued intent; pause freezes recovery. Saturation delays a full volley without spending ammo or playing a firing cue.
- Within-frame release offsets initialize bullet travel and recoil correctly. A frame crossing reload completion cannot fire its new rounds before the actual remaining reload time. Cover checks prevent the new long muzzle from spawning through a solid.
- Original generated receiver/magazine/bolt RGBA is retained in the source master and packaged atlas, with measured crops and a small224px decode. Reload uses .42/.82 phase cues and a full2.0-second baseline; no new tactical reload exception or shotgun HUD/timing change.
- Three firing variations, impact and three recorded mechanism reload cues regenerate through the existing audio tools. No new recordings, music changes or SoLoud engine changes.
- Profile schema2 adds cumulative normal boss victories; LocalPreferences reads/backs up both schemas1/2. Current run boss count, including repeated kinds, settles once; Training cannot award progress. Existing challenge/unlock data survives. A validated optional burst-recovery checkpoint retains cooldown without replaying pending rounds.
- Burst uses the existing compatible projectile upgrades/fusions. Per-weapon capability manifests and non-projectile resource models for the later weapons are still future foundation work; this slice does not claim they are implemented.

## Evidence and limits

`make verify`: analyzer clean, **283 tests passed, five optional skips**. Baseline was267/five. The expanded weapon loop exercises the new gun against all existing survivor/arena/boss tests. Dedicated regressions cover timed releases, cancellation, changing aim, atomic saturation, reload/pause/restart, checkpoint validation and profile migration/backup/unlock behavior. Shared contract checks include barrel side offset.

Sibling server `npm run verify`: typecheck, **88 tests** and Spacetime build passed. Its four new tests cover native-matching subshot cadence, muzzle/aim, saturation/reload and maximum Quick Trigger. No hosted/network-play compatibility is implied.

`flutter build ios --release --no-codesign --no-pub`: succeeded, `build/ios/iphoneos/Runner.app`113.5MB. Current identity remains1.0.0+11. This unsigned app was not installed/exported/distributed. The build reports the existing flutter_secure_storage Swift Package Manager adoption warning; it does not prevent this build.

Audio preview checks:52 combat WAVs and14 reload WAVs validated, representative combat mix peak.745. Source/hash/prompt and static renderer review: [Burst Rifle source packet](../art/source/weapons/BURST_RIFLE.md). Shared decoded art reports30.30MiB; existing <=32MiB boss-pair checks pass. This is allocation/test evidence, not physical-device frame-time proof.

Durable commands/results are under [stage-one validation](validation/arsenal-stage1-2026-10-21/summary.json). Reviewed actual-renderer captures: `build/test-previews/burst-rifle-mechanism.png`, `rounds-burstRifle.png`, `refill-burstRifle.png`.

No long soak, physical listening, moving phone sprite approval, comfort/balance approval, server rollout or phone installation was performed in this pass. Next planned weapon is Rail Lance, while expanded protocol/runtime work remains open. Completion still requires every one of the eleven packets and the full fifteen-weapon acceptance matrix.


## Phone installation follow-up — 21 October2026

At the creator's request, rebuilt the latest source with configured device signing and release defines (`make buildIOS`). Verified signature, dev.kiishi.regun identity1.0.0/build11 and packaged Burst Rifle atlas. CoreDevice successfully installed the signed113.8MB app in place on the creator's connected iPhone12, then confirmed foreground launch. No uninstall, app-data clearing, IPA export or server deployment. Installation and launch evidence is in the stage-one validation folder. Burst is under Training → Weapon; ten further additions remain pending. Physical animation/listening/comfort/balance acceptance is still open. This delivery supersedes the earlier unsigned-build/no-install status above.


## Burst Rifle tactical reload follow-up — 21 October2026

Creator requested different loaded/empty reloads after trying the phone candidate. Manual reload with ammunition now takes1.4s (before existing reload upgrades), swaps/seats the magazine at82% and skips the bolt pose/cue. Empty reload remains2.0s with seating42% and bolt82%. Both commit fully before firing; saved tactical and older full-only reloads retain their own duration/cues. Shared `supportsTacticalReload` now includes Carbine and Burst only. Actual renderer contact sheet includes both tracks and Reduced Motion.

Analyzer clean;284 Flutter tests/five optional skips;89 server tests plus typecheck/build pass. Signed release1.0.0+11 rebuilt, verified, installed in place and launched on creator iPhone12; no app-data clearing or backend deployment. Evidence: validation/burst-tactical-reload-2026-10-21/summary.json. Phone motion/listening/balance remain for creator review.
