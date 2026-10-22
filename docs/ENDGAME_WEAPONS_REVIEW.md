# Six endgame weapons and walking weight

22 October2026. **Implemented:21 solo/Training weapons.** The requested pre-change
checkpoint is client `6f9f2b3` / sibling backend `810244b`. Signed release identity
remains1.0.0+11; the new142.8MB device candidate was installed in place and launched
on the creator's iPhone12. Existing app data was preserved. No server rollout,
expanded online admission, IPA export or push was performed.

## What to try

| Weapon | Advantage | Handling |
|---|---|---|
| Twin Verdict | A2.5 hit brands for1.25s; the opposite barrel hits for4.5 and sends a short iron crossburst into up to two other bodies. | One twin-bore pistol,12 rounds. Missing/reloading or changing a living target breaks the pair. An opening kill cocks the opposite barrel for the next enemy. One combo application per original shot, even with Scatter/Pierce/Ricochet. |
| Flak Regent | A2.4 slug breaks into four.45 forward fragments for nearby packs. |16 rounds. Complete four-projectile reservation precedes ammo use and survives shell flight. Secondary fragments ignore the direct owner and terminate at cover/range. |
| Anchor Engine | A planted magnetic cartridge gathers mobile bodies, then crushes for8. | Variable-distance hold/release,4 charges. Pull runs over the last.65s of its1.05s plant;55 displacement/body/device through occupancy. Strongest intent wins per step. Planted enemies stay planted. Two devices including flight/residue; total life below3s. |
| Faultline Driver | Three committed ground sections pierce a crowded lane for6/body. | Hold aim/release,5 charges. Sections at0/.10/.20s,42 half-width, cover-clipped720 base range, six owners and one hit/owner across all sections. |
| Cyclone Breacher | Rapid, heavy five-pellet close volleys. |8 rounds,.50s cadence. Scatter caps at nine, then tightens. Full-volley reservation. Damage falls from1× at210 to.60× at300; no freeze. |
| Mourning Bell |4.5 cone strike, then1.5 echo on enemies that stay. |6 charges,70°/400 range. Five nearest original owners. Echo at.55s requires the original committed cone and clear cover; it never acquires new targets. |

Training exposes all21 immediately. Normal unlocks preserve prior progress and use
33/36/40/44/48/52 settled boss victories for these six. Those thresholds and final
balance are provisional pending creator playtesting.

All six use the shared70% tactical reload with ammo remaining. Empty reloads take
the full2.6/3.0/3.4/3.2/3.0/3.0s respectively. Ammo is granted only on completion;
held aim cannot interrupt. Tactical clips skip the empty-only closing mechanism
and cue. Reduced Motion plants mechanism travel. Old shotgun presentation/timing,
independent grenades and mirrored aiming-thumb controls remain intact.

## Movement and saves

WeaponMobility applies0–7% once to the existing survivor/upgrade walking baseline.
Rook Carbine/Repeater/Anchor walk at300/282/279; every weapon keeps1450 dash.
MovementSpeed in a checkpoint stays the unweighted baseline. Training swaps retain
upgrades. Loadout details and kit summary display a brief Mobility penalty.

The sibling server uses the identical21-entry fixture after survivor/VIII speed.
Native online prediction already consumes authoritative snapshot speed and does
not multiply it a second time; older servers continue to supply their own speed.
Unsupported guns remain excluded from online lobbies. Backend parity is local only.

Committed Anchor fields, Faultline cursors/owner ledgers and Bell original marks/
echo resolution persist with finite bounds and phase validation. Pause freezes
all timers. Continue never restores a held trigger. Twin pairing clears on Continue
because ordinary in-flight bullet intent is not checkpointed; it cannot grant a
free paired hit after resume. Training swaps/restarts dispose old weapon state.

Developed-build validation exposed fast guns storing velocity above the existing
2000 save ceiling. Rapid Fire and Training weapon changes now clamp stored velocity
at2000, matching actual projectile limits and keeping those checkpoints readable.

## Art, audio and evidence

Six transparent three-part source packets are retained unchanged in
art/source/weapons/endgame, with prompts, hashes, alpha bounds and measured grip/
muzzle metadata in generation.json. Anchor jaws and Faultline ram silhouettes were
revised for readability. Source-part aspect ratios and receiver socket positions
are measured; no survivor/root scaling is used to align art. Shared grounded stone,
dust and iron sprites supply floor effects. Each selected packet decodes224×112
(98KiB) and is leased; shared art + largest boss pair + one new packet is
**31.84375MiB**, below32MiB.

Recorded CC0-derived firing/impact/reload cues use the existing source attribution.
Expansion audio validation covers116 cues; review-mix peak.4339 with bounded DC,
endpoints and loop seams. Bell uses a short low mechanical strike/echo. Speaker
listening remains a hands-on gate.

`make verify`: analyzer clean, **443 passed / five optional skips**. Backend
`npm run verify`: **91 tests passed**, typecheck and module build passed. Coverage
includes real firing/ammo/reloads, capacity rejection, fragment owner exclusion,
bounded overlapping pulls/planted bodies, lane and echo resume ledgers, movement
baseline/unchanged dash, base/VIII upgrades, all weapons against expansion bosses
across three survivors/two arenas, art leases and the32MiB budget. The skipped
long-run tests are explicitly opt-in; no claim of running them is made.

Review artifacts in [validation/endgame-2026-10-22](validation/endgame-2026-10-22):

- [All six on three survivors in four directions](validation/endgame-2026-10-22/survivor-mounts.png): rows follow the roster above; four facings per survivor left to right.
- [Reload sheet](validation/endgame-2026-10-22/reload-modes.png): rows follow the roster; left four columns are empty, right four tactical, phases.10/.42/.82/.94.
- [Twelve20-second base/VIII pack samples](validation/endgame-2026-10-22/pack-cycles.json): repeated firing/reload cycles with five stationary high-health targets and bounded effects/projectiles. This is a behavior/stress sample, not an equal-power or human difficulty verdict.
- Flutter/backend/audio logs and phone install/launch records.

The20–35% useful-power goal in the approved plan remains a tuning target. Ideal
pack samples favor different area shapes and rank-VIII builds can exceed it.
Physical sprite contacts, comfort, native audio, sustained frame pacing and final
balance still require the creator's hands-on review.


## Creator feel correction —22 October2026

This follow-up supersedes the first device candidate's Twin ability and its quiet
Bell floor effect. Read HEAVY_WEAPON_FEEL_REVIEW.md. The current native candidate
has448 passing tests/5 optional skips. Earlier443-test evidence above describes
the original six-weapon delivery and is retained separately.
