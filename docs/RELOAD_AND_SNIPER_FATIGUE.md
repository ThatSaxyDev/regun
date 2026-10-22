# Universal reload modes and sniper fatigue

22 October 2026. Implemented for the current **fifteen** solo/Training weapons.
Release remains1.0.0+11. The six additions and weapon-weight movement penalties
in [the expansion plan](SIX_WEAPONS_AND_WEIGHT_PLAN.md) remain proposals only.

## Reload contract

Every weapon now has both modes. Manual reload with ammunition remaining uses
**70%** of the applicable reload duration and omits the final pump/bolt/locking
motion and its closing cue. Empty reload uses the existing full duration and final
action, including automatic reload after the last shot. Manual reload on empty
also takes the full path. Both modes grant ammo only at completion; held aim never
interrupts them. Normal full-mag requests retain existing no-op behavior, with the
existing Rivet armed-payload reload exception preserved.

| Weapon | Empty base | Ammo-remaining tactical base |
|---|---:|---:|
| Pump Shotgun |3.20s |70% of missing-shell time: .56/.98/1.40/1.82s for1–4 missing shells |
| Carbine |1.80s |1.26s |
| Revolver |2.10s |1.47s |
| Arc Caster |2.40s |1.68s |
| Burst Rifle |2.00s |1.40s |
| Rail Lance |2.60s |1.82s |
| Rivet Driver |2.20s |1.54s |
| Cinder Hose |2.30s |1.61s |
| Reaper Disc |2.40s |1.68s |
| Scrap Mortar |2.80s |1.96s |
| Belt-fed Repeater |3.60s |2.52s |
| Frost Shotgun |2.60s |1.82s |
| Prism Cutter |1.80s |1.26s |
| Spore Lobber |2.70s |1.89s |
| Longwatch Sniper |2.80s |1.96s |

Apply existing Fast Reload first, then the .70 tactical multiplier. Pump's normal
800ms first-shell/600ms extra-shell timing and five-shell duration cap remain.
Tactical shell cues compress to420ms spacing and omit the final pump. Fast Reload
retains its existing single-shell cue policy. Other tactical mechanisms reseat at
82% and omit closing cue2; empty seating/closing remain42%/82%. Receiver-specific
cylinder, cassette, valve and bolt parts retain measured sockets. Full/partial
presentation captures cover all fifteen weapons; Reduced Motion keeps parts planted.

Continue preserves an in-progress reload's selected duration, consumed cues and
mode. Older full-only reloads finish as recorded rather than gaining a mid-reload
shortcut. The earlier staged-ammo experiment still migrates to full commitment;
its flags are not interpreted as new tactical reloads. `reloadPolicy:2` identifies
the new writer; no pending held fire is saved or replayed.

The sibling server model now matches for all supported originals/Burst, including
Fast Reload order. Client online audio respects the authoritative tactical flag;
no pump/bolt cue is invented for a top-up. This pass **does not deploy the server**
or admit unsupported expanded weapons to multiplayer. Existing hosted behavior
remains server-owned until that local update is separately rolled out.

## Sniper fatigue contract

`SniperSway` owns a simulation-clock heading error. It starts with a.18° envelope,
increases during six seconds of held ready aim, then plateaus at.85°. Two slow,
continuous oscillations keep it alive even at initial aim without random release
scatter. The sight, gun/muzzle and released projectile use the same assisted-then-
swayed direction. Aim Assist therefore cannot erase the fatigue error, and the
preview never promises a direction different from the shot. Damage, speed, range,
innate penetration, shield interaction and cadence are unchanged.

Lowering/cancelling aim hides the sight immediately and recovers two fatigue
seconds per active rest second; a fully fatigued rifle rests off in three seconds.
A brief release does not reset fatigue instantly. Reload/cooldown provide rest.
Pause/picker/deployment stop simulation time; pause also cancels captured input as
before. Restart/Training weapon disposal reset the model. Continue validates and
restores finite fatigue/phase but never an active held aim or queued release; older
saves start rested. Camera and movement remain steady. Reduced Motion gets no
extra HUD/camera animation; the small ballistic sight motion remains identical so
visual accessibility settings do not desynchronize the shot and its preview.

## Acceptance

Test one-shot-remaining manual refill and fully empty automatic refill for each
weapon, including held aim, pause/background, restart/Continue, Fast ReloadVIII
and magazine pickup cancellation. Compare late mechanism poses and listen for the
missing tactical closing cue. For Sniper: hold briefly, hold past six seconds,
release while visibly offset, lower briefly/re-aim, rest three seconds and compare
Aim Assist Off/On. Firing/cancellation semantics remain release-to-fire/cancel-free.

Automated evidence and device delivery are in
`docs/validation/reload-sway-2026-10-22/`. Physical comfort, sprite/audio timing and
whether the chosen sway envelope feels subtle still require creator playtesting.

Delivery: analyzer clean;391 Flutter tests pass/five optional skips;90 backend
tests plus typecheck/build pass. Signed133.5MB iOS release1.0.0+11 verified, installed
in place and launched on creator iPhone12. Saved data was not cleared. No IPA/server
deployment. The six new guns and weight modifiers remain planning-only.
