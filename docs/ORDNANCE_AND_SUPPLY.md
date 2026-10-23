# Ordnance and supply revision — 21 October 2026

Release identity stays **1.0.0+7**. This is a private playtest candidate.

## Grenades

Grenades are a secondary weapon available with every primary. The third action beside Dash/Reload is now an independent miniature aim control: hold and drag in any direction, adjust range by drag distance, release to throw. This supersedes the original tap-only design at the creator's request. Movement and primary aim remain independent; running forward and throwing backward works. A quick tap throws in the current movement direction; standing still falls back to last weapon aim. Online keyboard G quick-throws.

The live dotted trajectory and compact ground brackets simulate the same flight, solids, bounce, fuse and present body contacts as the throw. It is a prediction using current positions; moving targets can change where contact happens. Full drag retains600-unit/s release; minimum aimed power40% gives shorter tosses without increasing maximum range or damage. Eight logical pixels of dead zone prevent accidental aiming. Drag outward then return to the center to cancel; release outside the button remains captured. Charges and fuse begin only when a throw is accepted. Pause, focus/background loss, disconnect/epoch change and pointer cancellation clear the gesture. Reduced Motion projects the guide on the floor. Mirroring, Control size, placement, two charge markers and recharge countdown remain; held states show Release/Cancel.

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

## 23 October follow-up

The contact-detonation and non-solid-pod behavior above is superseded by
[Combat recovery and supply cover](COMBAT_RECOVERY_AND_SUPPLY.md): grenades pass
over enemies, bounce and detonate on fuse; pressure extends beyond damage; supply
landings add a blast and active/opened pods become cover. No change to eight-second
capture/50-second current expiry or the separate primary weapon contracts.
