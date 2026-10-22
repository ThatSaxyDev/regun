# Ten survivors — implementation review

22 October 2026. Implements [the approved roster and power-up plan](TEN_SURVIVORS_AND_POWERUP_PLAN.md). Solo and Training now contain ten survivors, 41 offered upgrade families and eight fusions. Release identity remains **1.0.0+12**. This work does not admit the new survivors/upgrades to older online servers or deploy a server.

## Roster and unlocks

| Survivor | HP | Walking before weapon weight | Primary scalar | Live passive | Unlock |
|---|---:|---:|---:|---|---|
| Rook | 6 | 300 | 1 | Balanced baseline | Immediate |
| Scrapper | 6 | 345 | .85 | XP attraction +80; mines ×1.4, once acquired | 500 cumulative kills |
| Warden | 8 | 261 | 1 | One shared guard, 20s base recharge | Survive 8 minutes |
| Flint | 6 | 291 | .95 | Reload duration ×.88; completed ammo-restoring reload charges next release +20%, expires in 4s | 40 completed reloads |
| Vesper | 5 | 330 | .95 | Finished dash grants +18% primary for 1s; 4s activation gate | 6 minutes and 30 dashes in one run |
| Fuse | 6 | 285 | .90 | Grenade damage +20% of base; recharge −2s, final 10s floor | 120 grenade kills |
| Moth | 6 | 300 | .90 | One innate .35/tick ignition per second; player burn damage ×1.25 | Defeat 150 burning enemies |
| Coil | 5 | 300 | .95 | Every fifth successful release sends a separate 50% arc within 200; .8s gate; electrical secondary damage ×1.10 | Chain-hit 200 distinct enemy instances |
| Suture | 7 | 276 | .90 | 15 kills bank one missing HP heal; 12s shared kill-heal gate, no overheal/revive | Restore 40 missing HP |
| Harrow | 5 | 300 | Target dependent | Main weapon hits ×1.15 to bosses/elites, ×.90 to ordinary foes | 15 elites and 3 bosses |

All seven new unlocks settle idempotently from normal runs, including accessibility-assisted runs. Training never rewards progress. Old counters are not invented. Harrow can use already recorded elite/boss totals. Dash progress survives Continue. Existing three-survivor and six-fusion mastery requirements retain their original members; separate ten/eight mastery challenges are added.

The survivor catalog shows role, HP, base/equipped walking speed and the passive/tradeoff. Locked cards show actual progress. The assembled kit shows the selected survivor **holding** the selected gameplay weapon, at the same right-facing mount, rather than a detached gun thumbnail. Weapon changes lease their real atlas, and the original pixel plates, pinned tabs, Start/summary, scrolling, Reduced Motion and accessibility remain.

## Power-up changes

The 33-family baseline is recorded in the plan. Existing source IDs and I–III stored-stat behavior remain. New runs use `buildBalance:2`; Continue without this field retains revision1 for changed Medic, drone, bounce and chain-count formulas. New passive state/counters and delayed release contexts are validated and checkpointed.

- Bank Shot with a purchased rank: bounce multiplier `min(1.4, 1+.08e)`. Preserve the twice-original-projectile cap and cumulative distance.
- Accelerant: `130+35e` spread radius, six nearest visible victims maximum, one spread generation. Cinder and Moth are usable ignition sources. Spread inherits unmodified burn damage; survivor/Scouring modifiers resolve once per tick.
- Orbit Drone: shot damage `.8+.35e`, existing count/cadence/range.
- Field Medic: existing `.05e` kill chance, six-active-second healing gate; Suture uses twelve. Full HP does not bank Medic procs.
- Conductive Core now has a useful first purchase: normal chains get their base jump plus raw-rank extra hops. Revision1 retains the original count formula. Arc retains its two innate hops.
- Support offers need usable sources. An innate Coil arc enables Faraday Reserve; Core needs Arc or acquired Static Charge because it does not add hops to Coil's fixed innate discharge. Moth can enable Accelerant even with a blast weapon. Rank counts for fusion recipes still require purchases.
- High Velocity and Long Barrel stop offering zero-benefit ranks at actual weapon speed/range ceilings. Cyclone's spread tightens starting at III, after its II projectile-count cap. No additional projectile count is created.
- One owned eligible family is reserved in the first offer slot, with the other two distinct weighted draws. Normal rank/cap/ban/compatibility/fallback rules win. XP funding, supply offers, prompt grace, explicit cores, six special families and two fusion slots remain.

Here `e=min(r,3)+.30*max(r−3,0)`. Reload/dash retain their .20 scalar tail. Offers show real current/next values, including Scrapper/Fuse/Flint modifiers; Collection includes a starter-weapon example. ASCII separators preserve glyph coverage in the existing fonts.

| New family | Effect |
|---|---|
| Brace Loader | +4e% walking while reloading |
| Sure Foot | Recover `min(.40,.08e)` of the equipped weapon's walking penalty |
| Scouring Heat | Burn damage ×`1+.10e` to elites/bosses |
| Faraday Reserve | +.02e chain retention, .92 cap; also improves Coil's single innate arc from its .50 base |
| Blast Harness | Grenade/mine displacement ×`1+.10e`; existing target/mass/force gates still apply |
| Exposed Seam | Main hits on frozen targets ×`1+.06e`; offered with Frost |
| Measured Shot | After .8s without primary release, next release +.08e |
| Close Quarters | Main direct hits within 160 cumulative muzzle-path units +.06e |

Sure Foot intentionally differs from the proposal: there is no incoming player-slow system to resist, so the implementation gives it a useful existing-system role. It is not offered with zero-weight weapons. The new conditional release bonuses share a +60% bucket. Existing first/final-round multipliers, damage bands and weapon timing are preserved.

**Kiln Pact:** Hot Shot III + Scouring Heat II; a burning elite/boss death leaves one shared fire patch. Firebreak and Kiln never create two patches for the same death. Shared floor-effect budget applies.

**Ground Wire:** Static Charge III + Faraday Reserve II; every fourth successful electrical discharge gains one jump, at most once per second, within the existing chain budget. No recursive primary procs.

## Damage and lifecycle ownership

`SurvivorRuntime` owns active-time cooldowns, pending charge, triage, once-per-release hit ledger, distinct chain victims and run progress. Burst rounds share a release; pellets/piercing cannot count one release repeatedly. Continuous weapons contribute at most one qualifying Coil release per .5s. Delayed flight/committed-area contexts preserve identity through Continue. Pause, picker, deployment and background do not advance passive clocks.

Main Mortar/Anchor explosions carry weapon-release provenance without becoming primary-proc hits. This lets Moth/Coil/Harrow function with them without granting acquired Hot Shot, Static Charge, Shrapnel or other primary-only procs to every blast. Grenades/mines/drone/return/echo/fork/burn remain their existing secondary paths. Grenade kill attribution is distinct from burns that finish a previously hit enemy. Boss weakpoints use their owning boss's classification and transfer adjusted damage once.

Flint's charge is granted by actual reload completion, not pickup refill/restore/swap. Vesper is triggered by a naturally finished dash, not a cancelled input. Suture cannot rescue lethal damage and cannot stack Medic/Triage heals. Small state chips beside the feet expose Flint/Vesper/Coil without an aura or another control. Existing burn/arc/grenade/guard presentation is reused.

## Art and animation evidence

All new raster art was generated with built-in `image_gen`, following imagegen; no CLI/API fallback. Source masters, prompts, hashes and correction provenance are in [art/source/survivors](../art/source/survivors/generation.json), [left-run prompts](../art/source/survivors/left_generation.json) and [Fuse corrections](../art/source/survivors/corrections.json). The [importer](../tool/import_survivor_art.py) measures full-body alpha components and writes frame/pivot/floor metadata without repainting source pixels.

- Six survivors use a measured 56-frame run/idle/action packet plus a dedicated eight-pose left run. Fuse's first packet was rejected for missing/mixed rows; it has separate 32-frame locomotion and 24-frame idle/actions plus the left run.
- The left packets follow an authored knee/ankle pose guide. Broad contact and narrow passing are measured in **both** halves of every new left cycle. Vesper/Fuse/Suture's opposite-side source phases use explicit runtime `flipX` metadata so all eight displayed poses face left.
- Suture's generated rear idle supplies one planted pose; both breathing slots deliberately reference it. Locomotion is not duplicated to conceal a missing gait.
- Upper-body pivots and common row floor anchors keep swinging feet from dragging the body. Existing eight-pose/12Hz gait phase preservation and Scrapper's dedicated repair remain.
- All survivor packets now lease with their owner; the catalog leases portraits, gameplay leases the selected survivor, online leases the supported original three. Pending-load disposal and catalog selection are guarded. Only source metadata changes for the original three; their PNGs are unchanged.

[Rendered left gait strip](validation/survivor-expansion-2026-10-22/left-gaits.png), [all-direction movement loop](validation/survivor-expansion-2026-10-22/movement.gif), [Flint held-weapon loadout](validation/survivor-expansion-2026-10-22/loadout-flint.png), [Harrow loadout](validation/survivor-expansion-2026-10-22/loadout-harrow.png).

## Verification and remaining acceptance

Verification logs and a structured [summary](validation/survivor-expansion-2026-10-22/summary.json) are recorded in the validation directory. `make verify` passes with a clean analyzer and494 tests (five optional skips). The focused passive/art/combat suite passes20 checks, both30/60-minute developed-build simulations pass, and an iOS debug simulator build succeeds. Peak decoded art with each active survivor, largest boss pair, Cinder weapon and flame is26,567,168 bytes (25.34MiB), below32MiB. No physical installation or server rollout was performed. Automated coverage includes all210 kit initializations/Continue, actual all-kit mounted combat, all-boss kit/arena combinations, passive combat/source contracts, profile migration/settlement, dependency/cap offers, all-rank details, left gait pixels, all-direction playback and compact/large-text loadout flows.

Physical animation continuity, balance, motion comfort, touch comfort, speaker mix and sustained performance still require creator review. A simulator build, rendered strip or headless soak does not close those gates. In Training, compare every survivor with Shotgun plus its role pairing; try both arenas, base/III/VIII, two-fusion extremes and actual normal-health bosses. In particular review Measured Shot + first/final-release burst, Coil/Arc/Faraday, Suture/Medic/guard and Fuse/grenade cadence. Expanded online admission remains separately gated.

The existing soak deliberately heals its test survivor to sustain density; it tests caps/stability, not survivor balance. Distinct chain-owner tracking retires with removed actors, keeping the active ledger bounded across long runs.
