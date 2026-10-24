# Three selected weapons — implementation review

See [the subsequent creator-feedback corrections](WEAPON_FEEDBACK_REVIEW.md) for
the current ring launch, guidance/acceleration, passing orb, audio, Revolver and UI.
The seed table below records the first tranche.

24 October 2026. Houndrack, Storm Orb and Ring Caster extend the Solo/Training
roster from 21 to 24. This is the selected first tranche of the twelve-weapon
request; the remaining nine slots are open. Research and comparisons are in
[WEAPON_EXPANSION_RESEARCH.md](WEAPON_EXPANSION_RESEARCH.md).

## Playable identities

| Weapon | Input and purpose | Base seed |
|---|---|---|
| Houndrack | Hold primary aim for a stream of tiny rockets. Each rocket acquires one enemy within an 18° half-cone, corrects mildly (0.9 rad/s), and never reacquires. Bodies and cover intercept it. | 40 rounds, 0.11s cadence, 1.1 direct damage, 0.45 secondary splash within 48 units, 2.8s reload |
| Storm Orb | Fire a slow orb past enemies to arc repeatedly during its clear flight. Contact ends it; this rewards passage rather than immediate impact. | 6 rounds, 1.1s cadence, 3.8 impact damage, 1.2 arc damage every 0.2s to at most three nearby bodies, 2.8s reload |
| Ring Caster | Hold primary aim to expand a cutting ring around the moving survivor. Release to retract from its current radius. Its interior is empty: only a crossing edge cuts. | 4 charges, 4.5 outward damage, 1.25× return damage, 340 radius, 0.75s expansion, 0.8s maximum outer hold, 0.45s return, 3s reload |

These are tuning seeds, not human-approved balance. Normal access defaults to
56/60/64 earned boss victories; Training grants all three immediately. They do
not introduce new purchases or change the six existing Scrap-only weapons.

Rockets cap at 12 live; orbs cap at three and 2.4s lifetime. Ring keeps one paid
attack and eight unique bodies per phase. A target can be cut once outward and
once returning. Cover blocks secondary damage and cuts. Early release reduces
the ring's reach; a held input cannot keep it out forever. It grants no immunity
or bullet clearing. Empty last-charge reload waits for the ring to finish.

New flight, acquisition, hit-owner sets and ring phase are checkpointed and
validated. Continue does not invent a held input. Pause, selection and deployment
freeze simulation. Old checkpoints/catalogs remain accepted. Global shot/effect
budgets, occupied-body reactions, walls, audio overlap and Reduced Motion remain
in force. Rockets/orbs permit velocity upgrades; ring does not. Scattershot,
piercing and ricochet are intentionally unavailable on these three. Orb arcs and
rocket splash are secondary damage; the ring does not run acquired primary-hit
proc chains.

## Mobile, admin and API contract

The generated catalog has **24 weapons and 313 numeric fields**. Seventeen new
base fields expose damage, capacity, cadence, range, reload and projectile speed
where meaningful. Ring has no fictitious speed slider. Eighteen additional fields
control the actual behavior:

| Admin group | Editable behavior fields |
|---|---|
| `effects.houndrack` | `rocketTurnRate`, `rocketAcquireAngle`, `rocketAcceleration`, `rocketSplashDamage`, `rocketSplashRadius`, `rocketLimit` |
| `effects.stormorb` | `orbArcDamage`, `orbArcRadius`, `orbTick`, `orbTargets`, `orbLimit`, `orbLifetime` |
| `effects.ringcaster` | `ringExpand`, `ringRetract`, `ringHold`, `ringReturnScale`, `ringTargets`, `ringThickness` |

Guidance and splash allow zero to disable them. Ring thickness drives rendering
and collision. All fields have finite bounds; counts require integers. Shared
catalog generation updates mobile, admin and server together, retaining historical
catalog IDs and run-pinned balance. Publishing follows the existing authenticated
revision workflow and affects future runs; an active/continued run keeps its
original balance snapshot.

Admin's weapon panel compares baseline and draft component values, works at
320px and desktop widths, and offers **Check components with API**. Authenticated
`POST /admin/weapons/preview` validates the complete candidate values and returns
catalog identity plus deterministic components for one of the three weapons.
It does not publish. The admin compares those returned values with its own
projection and reports mismatches. The TypeScript and Dart component/rank
fixtures agree. These tables describe components, not a misleading universal DPS.

The API accepts the additive weapon names in profile/catalog contracts. Hosted
combat retains its existing admission gate: these three are currently
Solo/Training weapons. API integration does not silently enable unsupported
multiplayer simulation.

## Production assets

Each weapon has generated transparent body/feed/latch art, measured sockets,
its own firing/impact/reload cues, and game rendering/reactions. Ring has a
separate return cue. Built-in image generation prompts, original masters, alpha
bounds and hashes are in [the source packet](../art/source/weapons/frontier/README.md).
Selected art uses the existing lazy atlas lease, 224×112 decode (98 KiB), with
bounded authored pixel rocket/orb/cutter effects. No new boss texture burden.

The 22 new audio files derive from the existing recorded CC0 sources through
`generate_expansion_audio.py`; all preexisting expansion WAV hashes stayed
identical. The audio preview verifies 144 expansion cues; review mix peak 0.6483.
Attribution remains in `art/source/audio/README.md` and the expanded audio manifest.

## Verification and remaining review

Automated checks cover mild fixed-target guidance, interception, one direct
owner, zero splash, flight caps before ammunition spend, real live-profile edits,
orb target/tick/cover limits, ring pocket/crossings/early release, freeze/restore,
invalid saves, actual art/effects, upgrades, component parity and old catalogs.
The wider game checks exercise all weapon builds and boss-pair regressions.
Admin tests cover all 18 controls and small/large component layouts; API tests
cover authenticated previews, invalid/fractional values and no publication.

See [validation evidence](validation/three-weapons-2026-10-24/README.md) for exact
commands/results and representative renders. iOS/Android game and macOS/iOS
admin release builds are checked locally. No server deployment, admin publication
or phone installation is implied. Preserve the creator's existing 1.0.0+21 edit.

Physical balance, speaker listening, thumb comfort, ring readability, native
motion and performance remain creator playtest gates. Automated tests and build
success do not establish physical-device acceptance.
