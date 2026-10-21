# Ordnance and supply revision — 21 October 2026

Release identity stays **1.0.0+7**. This is a private playtest candidate.

## Grenades

Grenades are a secondary weapon available with every primary. Tap the third action button beside Dash/Reload on the aiming side; the entire cluster mirrors for left-handed controls and supports Control size/custom placement. It is not a joystick. Throw toward current aim, or the last aim when released. The button shows two charge markers, a pressed state and an empty-state recharge countdown. Online keyboard uses G.

Two charges; 250ms separation between throws. Each charge regenerates sequentially over 18 active seconds. Throwing the second does not reset the first timer. Pause, upgrade selection and deployment freeze native flight/recharge. Match countdown/break/choice freeze authoritative flight/recharge. New runs/rounds and Training recovery refill charges. Primary ammunition and reload are independent.

The casing leaves at 600 units/s, slows, arcs and bounces off solids/boundaries. Body contact can detonate after 180ms; otherwise the fuse is **1.4 seconds**. A blast occurs once, including while removal is pending. Reduced Motion keeps the casing on its ground path without lift/spin. Native checkpoints persist and validate inventory and active flights; old saves start with two charges.

Base enemy damage 8; blast radius 205 plus target body intersection, with solid cover blocking blast damage. PvP player damage is independently 3.2 HP, so one cannot eliminate a full-health survivor. Teammates and the thrower are excluded. Server membership, generation, sequence, charges, cooldown and projectile capacity are authoritative. The client checks reducer capability before exposing an enabled online throw.

Three utility upgrades (I–VIII) bring the catalogue to 33 offered families:

| Upgrade | Effect per effective rank |
| --- | --- |
| Heavy Payload | +20% grenade damage |
| Wide Burst | +8% grenade radius |
| Ordnance Cycle | −1.5 seconds per recharge (minimum 10s) |

VIII remains 4.5 effective ranks: 15.2 enemy damage, 278.8 radius and 11.25s recharge. Capacity stays two. Existing Fragmentation can add bounded secondary shards; blasts do not trigger primary hit chains/procs. Existing entity/effect/projectile limits remain.

## Mines and airdrops

Mines: radius 155→185; damage `2.5 + effective Mine rank`→`3.5 + effective Mine rank`, retaining Scrapper's 1.4 multiplier. Blast intersection includes enemy body radius and respects walls; all eligible enemies are considered. Trigger, arming, lifetime and population budgets stay unchanged. Mines and grenades share the recorded pressure/metal blast cue, bounded gain and overlap limiting.

Breach airdrops: capture radius **220→260**, expiry **45→50 seconds**. The proposed 60-second expiry was rejected to preserve urgency. Capture stays **8 seconds**. Leaving pauses capture while expiry continues. Claim, crush, reward and cleanup semantics stay unchanged. Native and authoritative circle/expiry contracts agree.

## Ranged remains

Revenant death now uses a separate prone, unlit corpse instead of the kneeling atlas frame. Corpse orientation is captured at death and never follows the survivor. The other legacy ordinary enemies also stop changing facing once dying. Online actor death already stops AI before targeting; presentation uses the same new remains and stored facing. Rewards and delayed-cast cleanup retain their existing single-death path.

## Validation and acceptance

Automated coverage includes real touch dispatch, two independent charges, duplicate rejection, save/restore, pause gates, contact/fuse flight, bounded upgrades, body-edge blast hits, frozen corpse facing, restart cleanup, shared art and boss-pair budgets. The live local SpacetimeDB smoke exercises sender/epoch/replay rejection, two charges/recharge, fuse removal and 3.2HP PvP damage alongside normal firing/reload/round/rematch behavior.

`tool/generate_ordnance_audio.py` generates and validates recorded CC0-derived mono PCM16/44100Hz cues. Source provenance is in `art/source/audio/README.md`; peaks/RMS/hashes in `docs/art/ORDNANCE_AUDIO_MANIFEST.json`. Small-sprite prompts and asset hashes are in `art/source/ordnance/README.md`.

Physical grenade reach, thumb comfort, audio strength, difficulty and visual readability still require hands-on play. Automated checks and installation do not establish that acceptance. Deploy the matching server `main` in Dokploy before testing online grenades against the public endpoint.
