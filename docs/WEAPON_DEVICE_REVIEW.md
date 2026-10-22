# Weapon device review corrections

21 October 2026. Release identity remains **1.0.0+11**. This supersedes the first
fifteen-weapon candidate's Hammer and affected balance/presentation notes.

| Request | Implemented behavior |
|---|---|
| Reaper Disc locks firing | Outbound blades turn at cover, range or bounded flight age; returning blades catch or expire. Subpixel boundary stalls cannot retain all three reservations. |
| Cinder fire must blow | A bounded stream emits moving flame tongues from the actual nozzle at 650 units/s. Each retains its emission position/heading, spreads, changes authored flame frames, and fades into smoke. Release stops emission while the tail drains. Cover clips movement and rendered forward extent. Damage cannot precede the growing flame front. |
| Mortar / Spore near and far aim | Hold primary aim, vary stick displacement to choose distance, release to launch once. Friendly trajectory/landing previews use current cover/body geometry. Returning to center or cancelling spends nothing. Strength is independent of aim sensitivity. |
| Grounded ordnance | Shared grenade/mortar blasts use sooty material, low dust and planted charcoal scorch. Spore rupture/patch use muted olive material rather than the bright poison tint. Existing damage and collision contracts remain. |
| Repeater | 70 base rounds, .085s cadence, audible .4s motor spin-up before bullets; existing spin-down/reload remain. |
| Shotgun pellets | Original Pump pellets enlarged from22×11 to28×14; Frost pellets24×15. Counts, damage, freeze, hitboxes and reload timing remain. |
| Prism Cutter | 18 base heat capacity; upgraded ceiling24. |
| Replace Hammer | **Longwatch Sniper**: hold to aim, release for one shot; 12 base damage, innate three penetrations (four bodies), five rounds, 1.10s cadence, 1200 range, 1900 speed, 2.8s reload. Weak ordinary bodies die in one shot; stronger roles/bosses retain their health rules. |
| Rail Lance | 48-unit drawn rounds, preserving ballistic/collision dimensions. |
| Training pause | WEAPON PRACTICE selects any of fifteen guns while paused. Keeps survivor, arena, position, health, level, upgrade ranks, encounter and grenades; replaces/refills primary resources and cancels old primary attacks/reload. |
| Loadout survivor | Subtle 2.2s idle lift (up to3px) and two authored idle poses in the catalog and assembled preview. Reduced Motion/system animation preference holds a still pose. |

## Art, runtime and compatibility

New transparent source masters, prompts, hashes and measured frame bounds are in
[device_revision_sources.json](../art/source/weapons/device_revision_sources.json).
`tool/import_device_revision_art.py` copies the generated pixels and records atlas
metadata. It does not paint or reconstruct generated art. Packaged textures are
`weapons/longwatch_sniper`, `effects/cinder_flame` and `effects/grounded_ordnance`.
Retired Hammer textures/audio are removed from the packaged roster. The common
arsenal atlas decodes at704px; the largest boss pair plus Cinder packet/flow stays
within the existing32MiB decoded-art budget. Flow caps at18 tongues; all timers
freeze with combat. Reduced Motion omits turbulence and flame-frame cycling.

Legacy `breachHammer` loadouts/profile unlock keys/arsenal snapshots alias to the
sniper. `arsenalReviewBalance:1` applies old magazine/range/speed corrections once.
No pending aim is restored as a shot. Carbine/Burst tactical reloads and original
Shotgun timing/Lottie remain intact. The new sniper has its own measured receiver,
magazine and bolt, plus recorded-source firing/impact/reload cues. Repeater motor
is original generated mechanism audio; `preview_expansion_audio.py` validates all
74 expansion cues, loop seams, peak/DC/endpoints and the native-gain review reel.

Aim Assist remains available in solo settings. It adjusts the released sniper
heading toward an eligible visible target; landing strength stays independent.
The expanded weapons remain excluded from hosted online kit selection until the
matching authoritative protocol/gameplay is implemented. No server deployment is
part of this correction.

## Review on phone

Use Training → Pause → WEAPON PRACTICE to compare every weapon in the same scene.
For Cinder, hold, turn while moving, release near cover and inspect the remaining
smoke/tail. For Mortar/Spore, compare a short drag, full drag, center cancellation,
release outside the control, pause/background and left-handed controls. Sniper must
never fire on initial hold or gesture cancellation. Line up weak targets to check
piercing, then test reload and upgraded damage. Reaper must remain usable after
repeated throws against walls. Compare Repeater spin-up to its first shot and test
Prism venting/capacity. Review both arenas and Reduced Motion.

Automated results, rendered frames and installation are recorded in
`docs/validation/weapon-device-review-2026-10-21/`. Physical art/motion, speaker
sound, control comfort, balance and sustained performance still require creator
playtesting.

Validation: analyzer clean,361 Flutter tests pass/five optional skips;89 backend
tests plus typecheck/build pass;74 expansion cues pass. Signed128.9MB iOS release
built and signature/bundle/version verified. Phone installation is pending: paired
iPhone was unavailable (CoreDevice4016 before transfer), so the previous installed
candidate remains. Reconnect/unlock to install this correction without clearing data.

Phone delivery retry: creator reconnected the iPhone; the signed correction build1.0.0+11 successfully installed in place and launched. Data was not cleared. The earlier unavailable-device installation note is superseded by this successful retry. Physical playtest approval remains open. Evidence: validation/weapon-device-review-2026-10-21/install-retry.json and launch.json.


22 October follow-up: the six endgame additions and0–7% walking weight are now
implemented; the catalog is21. See ENDGAME_WEAPONS_REVIEW.md for the latest signed
phone candidate,443 passing tests and playtest tasks. Earlier15-weapon
entries above document their own delivery stage.
