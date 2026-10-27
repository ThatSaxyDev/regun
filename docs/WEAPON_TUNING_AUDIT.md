# Weapon tuning audit — 27 October 2026

## Result

All 24 weapons have editable base stats and a linked **Special behavior** section in the admin. This pass adds 93 behavior controls to the existing 33 effect controls: 126 effect controls, 461 fields across the whole balance catalogue. Defaults match the existing implementation; no production release or balance value was published.

The audit followed native combat, generated catalogue contracts, admin editing and preview, authenticated preview API, authoritative hosted combat, pinned run/room values, checkpoints and old catalogue migration. Current native implementation is authoritative for the newer solo weapons; historical design documents contain superseded numbers.

## Inventory

Base controls are damage, magazine/heat capacity, cadence, full reload, range and projectile speed. Revolver also has intrinsic ricochet count. Ring Caster intentionally has no projectile-speed setting: its committed delivery/expansion timings control movement instead. Continuous/ground attack compatibility fields are explained below. Special field IDs remain under `effects.<lowercase weapon>`, even when edited on the weapon page.

| Weapon | Special controls |
|---|---|
| Pump Shotgun | Base pellets; Pellet spacing; Close-damage distance; Far-damage distance; Close-distance damage; Far-distance damage |
| Carbine | Heading spread ±; Close-damage distance; Far-damage distance; Close-distance damage; Far-distance damage |
| Revolver | Ricochet damage retention; Ricochet seek range; Close-damage distance; Far-damage distance; Close-distance damage; Far-distance damage |
| Arc Caster | Innate chain jumps; Innate chain reach; Chain damage retention; Close-damage distance; Far-damage distance; Close-distance damage; Far-distance damage |
| Burst Rifle | Rounds per burst; Spacing within burst |
| Rail Lance | Full-charge time; Full-charge damage; Damage retained after piercing; Innate extra bodies pierced |
| Rivet Driver | Payload damage; Payload radius; Payload fuse |
| Cinder Hose | Flame cone half-angle; Lingering burn duration; Lingering burn tick; Damage per burn tick |
| Reaper Disc | Bodies hit per travel phase; Minimum return speed; Return speed above survivor speed |
| Scrap Mortar | Blast radius; Minimum lob duration; Additional lob duration at 620 units; Maximum lob duration |
| Belt-fed Repeater | Spin-up time; Time to full firing speed; Full-speed interval relative to base |
| Frost Shotgun | Base pellets; Pellet spacing; Freeze duration; Recovery after freeze; Immunity after thawing |
| Prism Cutter | Idle time before cooling; Heat units restored per second; Beam contact half-width |
| Spore Lobber | Damage per second; Patch radius; Patch lifetime; Tick interval; Targets per patch; Patch limit; Ordinary movement scale; Elite movement scale; Minimum lob duration; Additional lob duration at 620 units; Maximum lob duration |
| Longwatch Sniper | Initial aim sway; Maximum aim sway; Time to maximum sway; Sway fatigue recovered per second; Innate extra bodies pierced |
| Twin Verdict | Pair-hit window; Paired hit damage; Verdict fork damage relative to paired hit; Verdict fork reach |
| Flak Regent | Fragment damage relative to primary; Fragment reach; Fragment speed; Outer fragment angle |
| Anchor Engine | Crush radius; Minimum lob duration; Additional lob duration at 620 units; Maximum lob duration; Pull radius; Pull speed before resistance; Maximum pull per body; Delay before pull; Delay before crush |
| Faultline Driver | Lane contact half-width; Delay between lane sections |
| Cyclone Breacher | Base pellets; Pellet spacing; Close-damage distance; Far-damage distance; Close-distance damage; Far-distance damage |
| Mourning Bell | Cone half-angle; Echo delay; Echo damage relative to primary; Bodies struck per release |
| Houndrack | Guidance turn rate; Acquisition half-angle; Motor acceleration time; Secondary splash damage; Splash radius; Live rocket limit; Initial speed relative to full speed; Maximum rocket flight |
| Storm Orb | Arc damage per tick; Arc radius; Arc tick interval; Targets per pulse; Live orb limit; Pre-fire delay; Maximum flight lifetime; Body-crossing contact radius |
| Ring Caster | Capture radius; Starting radius; Expansion duration; Contraction duration; Capture hold; Collapse damage multiplier; Legacy edge target limit; Cutting edge thickness; Containment pull speed; Delivery distance relative to reach |

## Behavior and safety boundaries

- **Ring Caster:** schema-3 containment traps capture exposed bodies, lock, pull ordinary enemies and collapse once. Capture radius is independent of forward delivery reach. `ringTargets` applies only to old edge-ring checkpoints and sits under **Legacy ring settings**. It cannot limit current trap captures. Both old ring packets and new traps remain readable.
- **Houndrack:** launch-speed ratio, motor acceleration, guidance rate, acquisition half-angle, direct damage, splash, lifetime and live-rocket limit are distinct. Distance damage stays flat. Retarget/flight ownership and collision remain authoritative.
- **Storm Orb:** crossed-body damage is separate from nearby arc pulses. Radius, pulse interval, target count, lifetime, body width, windup and simultaneous orbs are separate controls.
- **Support:** Sentry mounts use the source weapon's damage, cadence, range, speed and configured burst count/spacing. They keep unlimited ammunition and support targeting rules. Aura and Sentry still reach tier VIII. Their published enabled flags are retained when explicitly rebasing a release; bundled disabled flags must not overwrite production settings.
- **Continuous/ground attacks:** Cinder Hose and Prism Cutter do not consume their legacy projectile-speed fields. Lobbed Mortar/Spore/Anchor flight uses flight timing rather than projectile speed; Faultline and Bell use committed ground/cone timing. These old base fields remain readable for historical contracts rather than being deleted. Flame/cone, beam width and ground-lane visuals follow the corresponding tuned geometry.
- **Cadence and damage** remain subject to existing per-weapon minimum intervals, build ceilings and proc budgets. For example, weapon speed settings cannot bypass projectile speed ceilings; primary ricochet damage remains capped at twice its initial damage; Rail Lance keeps its minimum sustained cycle. A setting below an existing floor can therefore have no further effect.
- **Fixed safety/identity rules:** actor/projectile/effect budgets, finite ammunition and reload commitment, cover/body collision, one-hit ownership ledgers, boss resistance, target ownership, fragment topology, fusion prerequisites, unlocks, art/atlas sizes, warning materials and network admission are not arbitrary balance fields. Do not remove these protections to make a numeric control appear stronger. Knockback/recoil resistance and art feel remain code-owned and would require a separate reviewed contract if exposed.

## Admin workflow and recovery

Weapon pages include the corresponding effect fields; the Effects tab edits the same values. Reset item restores both base and linked special fields in one undo step. Item change counts include both. All 24 weapons have component previews and authenticated API comparison, without presenting a made-up universal DPS figure.

Sentry/Aura tier editing now stages a starting value plus a growth adjustment, previews I–VIII, and applies the complete progression atomically. Existing tier ratios provide the reference, keeping authored early/late scaling. Individual tiers are under Advanced tier values. A failed proposal leaves the draft untouched and reports the actual problem.

Undo/redo, scoped reset, restore last valid and discard are reachable above the editor. Invalid drafts retain the last valid preview. Saved schema-2 drafts retain recovery history; older catalogues migrate history and last-valid frames with defaults only for newly introduced fields, archive the exact original and require rebase before publication. Corrupt storage can start fresh only after its original has been backed up successfully.

Phone uses a scrolling editor; wider displays use list/detail and available-width form columns. Tests cover small phone, landscape, tablet, desktop, larger text and keyboard insets. Physical interaction review remains separate from widget layout checks.

## Backward compatibility

1. Retain every previous catalogue identity, field set and canonical digest. Old published values and room snapshots are not rewritten or silently rehashed.
2. Missing new fields resolve through generated **immutable legacy fallbacks**, separate from future bundled defaults. Existing runs keep their pinned snapshot and original behavior. Do not change `legacyDefault` when adjusting a new bundled default.
3. New values are validated in native Dart, admin Dart and server TypeScript, including cross-field distance/timing constraints. Scalar-invalid fields do not produce unrelated relationship errors.
4. Checkpoint validators accept the run's pinned fuse, lob flight, freeze phases, sniper fatigue and committed attack timing/ledger limits. Continue restores stored damage and event ownership; it does not apply balance scaling a second time. Old packet schemas retain old defaults.
5. Hosted classic weapons and Burst Rifle read their server-pinned settings; Sentry source bursts agree across Dart and TypeScript. Adding authoring/preview controls does **not** admit the other weapons to hosted rooms. Existing negotiated online capabilities remain in place.
6. Preview endpoints remain authenticated and read-only. Publication still requires a complete validated current-catalogue candidate and the existing release revision/intent checks.

## Deployment

Deploy the server module and identity API together, then ship the matching admin and game builds. Keep the existing production release until clients have the new catalogue. In the admin, fetch the published release and explicitly rebase; verify retained production values (especially support enabled flags), adjust and review a candidate, compare API components, then publish through the normal workflow. Older clients can retain the previous compatible cached release when a newly published catalogue is unsupported.

No live values were changed as part of this audit. No database row migration or old-release rewrite is required. Local private iOS installation is a separate test operation; it does not publish a balance release.

## Verification

Regression coverage includes all declared behavior metadata and component exposure; retained catalogue hashes/defaults; authoritative shotgun/burst/spread/distance settings; precise relationship errors; tuned fuse/freeze/lob/sniper/committed-attack checkpoints; migration of an invalid 368-field draft with valid recovery history; item reset/undo across linked fields; authenticated all-weapon preview parity; and responsive editing/recovery matrices.

Run `flutter analyze` / `flutter test` in the game and admin, `npm --prefix spacetimedb run verify` and `npm --prefix identity run verify` in the server. Native balance, warning readability, listening and real device comfort still require hands-on approval.


### Completed local checks

- Game: analyzer clean;806 passing tests,5 skipped opt-in cases.
- Admin: analyzer clean;86 passing tests,17 final responsive/recovery checks after copy cleanup. iOS,macOS and web release builds passed.
- Server:199 passing tests,TypeScript check and SpacetimeDB module build passed.
- Identity API:38 passing tests,TypeScript check,production build and compiled smoke passed.
- Layout evidence: admin `build/previews/weapon-edit-{390x844,844x390,768x1024,1440x900}.png` and `support-edit-*.png`. These are widget render checks; they do not certify physical comfort.

Game iOS release build also passed (1.0.0+26). The updated admin was installed and launched on the paired iPhone.
