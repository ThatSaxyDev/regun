# Online projectile presentation — after build10

Creator reported improved movement but lagging/desynchronized bullets. Root cause:
bullets use raw 20Hz row positions, while local muzzle cues are immediate and actors
have continuous presentation. Correct this without changing combat rules.

- Continuously render server rounds between snapshots, extrapolating at most80ms.
  Clip visual travel to remaining range and solid cover. Direction changes/ricochets
  reset straight-line prediction; authoritative deletion removes a visual immediately.
- Predict local primary-shot visuals from the existing gun contracts and predicted
  survivor position. Respect last-known ammo, full reload, cadence/ranks and finite
  pending-shot/projectile budgets. Do not predict hits, damage, pickups or rewards.
- Backend assigns shot serial and pellet index and supplies original muzzle points.
  Match these scoped by room/member generation, replacing ghosts once; never draw a
  second bullet on confirmation or resurrect a completed/rejected speculative flight.
  Match random spread to server direction with bounded correction. Gate speculation
  on a server capability flag; legacy servers still get smoothed authoritative rounds.
- Use newest validated aim when the authoritative gun fires, retaining server-owned
  position/time/ammo/collision and all input/epoch/auth checks.
- Cancel speculation on pause/focus/death/choice/reconnect/weapon changes or stale
  snapshots; keep grenade flight and material VFX unchanged. Current identity10.
- Verify20Hz/60fps travel, held fire, ammo/reload, multi-pellet identities, spread,
  late/denied confirmation, near muzzle hit/deletion, walls/range, ricochet, lifecycle,
  delayed native and hosted fresh-private-room cases. Record failures and physical
  review limits. Regenerate/install a normal build after native tests.


Implementation uses server `combat_input_v_2` with a monotonic presentation-only
burst number. The server supplies burst-local shot and pellet identifiers and keeps
last-shot correlation across rapid repress; client input cannot choose a successful
shot, firing time, origin, speed, damage or pellet count. Speculation stops on stale
snapshots250ms, expires unconfirmed flights600ms, caps six pending volleys/64 pellets,
and matches server50ms quantized cadence (including Quick Trigger). Full reload,
last-known ammo minus pending volleys and explicit reload-pending gates remain.
Secondary proc bullets never claim primary volley identities. Cosmetic body guesses
hide at contact, but a server-confirmed piercing round resumes after that contact;
no fake hit effect/damage is produced. Grenade presentation is unchanged.

Verification so far:82 backend tests and typecheck/build pass; isolated prediction
and projectile smokes pass (auth, stale burst, newest aim, held fire/release, next
burst and room privacy). Native local200ms nominal RTT +/-20ms/direction tests:
Carbine visual17ms/server287ms; Shotgun visual14ms/server259ms,9 matched pellets,
75 peer frames moving between row updates,zero duplicate visual keys. Native setup
initially failed because its QA name exceeded20 characters; shortened and capped
names before passing reruns. Reports retain safe measurements without tokens/codes.
Backendf82c200 pushed to main; hosted schema confirms the additive reducer. No tables
or existing client argument layouts changed. Hosted verification and installations
follow below. Current identity remains1.0.0+10; existing IPA is not yet regenerated.


Hosted outcome: actual native public-server Carbine test passed (24ms first visible
bullet,203ms confirmed shot,11 matched projectiles during held fire,34 peer frames
advancing between raw row updates,zero duplicate visual keys). Fire/reload/grenade,
menu stop,12-second direction reversals and same-guest reconnect/cleanup also passed.
Reports: validation/online-projectiles-{local,hosted}-2026-10-21.json .
Client analyzer clean;252 tests pass/five skipped. Model checks include20Hz/60fps
travel,80ms outage bounds, random heading correction, rapid bursts, multi-pellet
matching, ammo/reload/staleness limits, body/cover/range clipping, confirmed piercing,
ricochet changes and epoch cancellation.82 backend tests/build/typecheck plus local
prediction/projectile protocol smokes pass. These tests do not establish physical
motion comfort, independent-device WAN fairness, release frame pacing or native audio
approval. No rewound hits or client authority was added; late confirmed hits can
still follow visual shots. Saved user identities/solo profiles were not reset.

Delivery: normal debug apps installed/launched on both iPhone17 and iPhone18 Pro
simulators with Online enabled. Signed device release10 built and codesign verified,
but iPhone installation failed before connecting (CoreDevice control-channel timeout).
The creator was asked to unlock/connect the phone; no successful phone installation
is claimed. Existing IPA10 still predates this projectile correction. Local impairment
proxy/server stopped after tests. See validation/online-projectiles-delivery-2026-10-21.json.

Phone retry: after creator reconnected the iPhone, CoreDevice confirmed successful in-place installation and launch of the signed build10 projectile correction. No profile/guest reset; physical playtest remains for creator review.
