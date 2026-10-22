# Heavy weapons: identity, impact and player Guard correction

22 October2026. Creator device feedback supersedes the original endgame feel pass.
Release remains1.0.0+11. Signed143.2MB candidate installed in place and launched on
the creator's iPhone12, preserving app data. No server deployment or online weapon
admission change. Baseline client commit:314a633 (`more weapons`).

## Twin Verdict: brand → shatter

The original.8-second,3.5-damage pair looked too similar to a larger Revolver.
A first2.5-damage primary now brands for1.25 active seconds. The next alternating
barrel hit deals4.5 base damage and shatters into a short, physical iron crossburst.
An opening kill cocks the opposite barrel, so the next enemy can receive the
shatter; the gun's advantage remains visible against weak packs rather than only
high-health dummies. Brass receiver chamber marks and a paired target brand make
its readiness visible. Distinct cock/verdict sounds separate setup from payoff.

Crossburst: two220-unit forward rays at±.24rad,16-unit half-width plus body radius,
at most **two other owners**,1.8 secondary damage each at base (40% of accepted
paired hit). It excludes the direct owner, respects cover, spends no extra ammo,
and cannot prime, proc, chain or recurse. Each original shot/volley can trigger
once, even with piercing/ricochets/scatter. Misses, changing a still-living target,
reload and Continue break the old pairing; an opening kill's carry is consumed by
the opposite barrel, not repeated through a kill chain. Boss armour and existing
primary damage ceilings still apply. No damage/cadence change to other weapons.

## Bell: bright weapon pressure, not a ground warning

The creator explicitly requested brighter weapon effects and allowed constructing
art directly where it suits the scenario. EndgameVfx draws a jagged stepped pixel
compression front with warm-white/brass highlights, dark edge backing and short
irregular airborne wakes. A separate cooler bright echo follows the original
committed shot. This renders in the **weapon layer above the floor**. There is no
lingering floor paint, recycled stone AoE disk, full-screen bloom or camera shake.
Cover/arena bounds clip visibility. Reduced Motion holds the front and fades it.

Damage stays4.5 initial/1.5 echo at.55s,70°/400 base range, five nearest original
owners. Echo requires the original cone and clear cover, and cannot acquire new
victims. The brighter art does not expand its damage geometry. The new low
mechanical strike and quieter echo are separately cued and prewarmed.

## All six: local punch and mechanism timing

Only the last six use the new material contact response and updated recoil
profiles. Existing recorded CC0 sources are layered into distinct transient/body/
mechanism signatures instead of changing every gun's volume. Six short new cues
cover Twin cock/shatter, Anchor plant/crush, Faultline section release and Bell echo;
there are no extra continuous voices. Anchor jaw halves visibly clamp before its
existing crush. Faultline sections release distinct bounded stone/iron fractures.
Cyclone cycles three measured muzzle offsets/flash ports, has stronger local recoil
and24-unit pre-resistance primary impact motion; per-target response cooldown and
occupancy prevent pellet shove stacking. Flak has a thick casing silhouette and a
short grounded burst using the approved explosion material.

Older weapon WAVs were hash-compared before/after generation and remain byte-identical.
122 expansion cues pass format/DC/tail/peak checks; representative review-mix peak
is.6483. In-game group volume/mute, reload timing/cues, movement weights and dash
contracts remain. There are no new texture allocations;32MiB pair/selected-packet
budget remains covered. Speaker listening and physical comfort still need creator
review; build/install is not evidence of accepted native feel/performance.

## Flak hovering: reproduced precision failure

Flame's Vector2 uses Float32 storage. Near terminal range, a remaining step can be
smaller than the position's representable increment. The old test expected travel
to reach range within1e-8, so a shell could stop moving and wait for the3-second
fallback while its art remained on screen. The regression uses position(1200,50)
and remaining range.00002 to reproduce that condition.

A shell now resolves once within.5 unit of remaining range, on actual travel stall,
or after range/speed+.12 active seconds (hard3s ceiling). Body and solid contact
still resolve immediately. Spent guards prevent duplicate bursts. Four secondary
slots remain reserved before ammo; fragments are registered before primary impact
procs can compete for those slots, and ignore the direct owner. Decorative FX
saturation cannot cancel the paid impact.

## The unsettling ring in the photo

Player Guard called AttackVfx.armour, which rendered **six copies of an enemy
chain/shield fragment sprite around the survivor**. It was an active Guard/Scrap
Armour indicator, not a phone image-loading fault or a new enemy attached to the
player. The repeated jagged shapes produced the unwanted crawling/cluttered look.

Player Guard now draws one steady small pixel shield beside the feet, with dark
backing. No fragment wreath surrounds or covers the body. Guard absorption,
recharge, Warden and upgrade mechanics are unchanged; enemy armour art is separate.
The pixel regression verifies that enabling Guard changes only its16×16 foot-badge
region, rather than repainting fragments around the whole actor.

## Verification and creator checks

`make verify`: analyzer clean, **448 tests passed, five optional tests skipped**.
Added regressions cover bounded/cover-blocked Twin shatter, opening-kill carry and
no recursive kill chain; Flak sub-pixel terminal resolution/one burst; Guard's
localized pixels; Bell initial/echo rendering. Existing21-weapon, save/reload,
base/VIII, boss/survivor/arena and texture-cap coverage passes.

[Evidence](validation/heavy-weapon-feel-2026-10-22) includes logs, native install/
launch records, audio checks, base/VIII pack samples, the clean Guard frame and
Bell initial/echo screenshots. Existing endgame evidence remains separate.

Try Twin on weak packs and a shield/boss, then miss/reload/change target. Listen
for its cock→shatter distinction. Fire Flak near cover/arena edges and continue a
saved run; no shell should hover. Bell should read as a bright shot with a second
distinct wave, including Reduced Motion. Compare all six at base/VIII, low speaker
volume and repeated weapon swaps. Final balance, comfort, punch and listening
acceptance remain for hands-on review.
