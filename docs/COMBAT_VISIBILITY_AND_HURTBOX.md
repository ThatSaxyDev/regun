# Combat visibility and player hurt geometry

25 October 2026. Local implementation of the first playtest-feedback pass.
The creator's shotgun/admin adjustments are untouched: no catalogue regeneration,
source shotgun buff or balance publication is part of this change.

## See the fight

The solo/Training boss HUD replaces the opaque 380px title/health plate with one
compact horizontal name/4px health strip, max 300px per boss. It has no opaque
background, retains paired encounters and a restrained enrage marker, and gives
screen readers the full name, enrage state and percentage. Names ellipsise at
small widths rather than adding rows. Default strips are about 20px high; 2× text
paired strips stay within 36px on 568×320. Full introductions/story are not added.

Accepted health loss keeps the existing sound, optional single light haptic,
warm edge feedback and steady camera. The survivor hurt pose/tint/brackets last
.48s instead of .32s, with a single 70ms pale onset omitted in Reduced Motion.
Stronger warm brackets identify the actual survivor. A small stationary lost-HP
label above the survivor and existing heart loss readout persist for .9s instead
of .5s. No added freeze, control delay, camera kick or invulnerability. Armour
absorption/protected hits do not trigger health-loss feedback. Pause freezes it;
restart/recovery clear it. Online lost-HP and hurt durations match.

## One smaller hurt footprint

`PlayerHurtGeometry.radius` is 26 world units (previous main player circle 30),
centered on the same survivor root. The 100-unit art size, 30-unit movement/cover
clearance and grounded feet constraints stay unchanged. This is damage geometry,
not shrinking the whole survivor or allowing it through narrower gaps.

The Flame damage circle, boss line/ring/sweep checks and hostile projectile
sweeps use that radius. Older attacks authored a total center distance already
including the previous 30-unit player portion. `reach(oldReach)` replaces that
portion with 26: Mummy 40→36, Skitter 52→48, Shadow dash 80→76, Demon charge 85→81,
Shield strike 140→136, Burster 150→146, Shadow strike 270→266, Demon cleave 340→336.
Legacy ground-area center thresholds likewise lose four units, rather than
adding a second body allowance and making the attack larger.

Scorpion body contact uses an explicit circular distance check at its 25.5-unit
body plus the shared player radius, in both native and hosted simulation. The
old native rectangle callback no longer determines damage differently above and
beside the survivor.
A smaller hurt circle does not change its projectile target/body occupancy.
Revenant shots now sweep the full frame path at 7+26 radius; Shadow bolts sweep
at 9+26. Their frame-end Flame collision callbacks no longer provide a separate,
conflicting player-damage path. Cover still blocks hits. This prevents a fast
round skipping through a player between frames while preserving true grazes.

## Hosted parity

The server uses `PLAYER_HURT_RADIUS=26` for actual fighter targets and the same
combined-contact helper. Hostile rounds carry explicit authored radii (Revenant 7,
Shadow 9) instead of every round inheriting the generic five-unit projectile.
Normal primary/PvP projectile radii and weapon damage contracts remain unchanged.
Boss/ordinary hazards use a player-specific adapter: body-margin shapes get 26;
legacy center-authored shapes keep their original allowance semantics minus 4.
Legacy Shadow/Queen/Demon areas and Sentinel center thresholds now agree with
native instead of gaining an additional body radius online. Shield/Burster
hazard geometry removes the already-included player portion before applying26.
This alters damage contact, not AI commitment/warnings or minion collateral.

Shared fixture `player-hurt-geometry.json` checks the same constants/reaches in
Dart/TypeScript. Near-hit/miss regressions cover circle/line/ring inside pockets
and actual 400-unit projectile steps. Actual paired-boss/hit frames and small/
large-text strip tests cover presentation. Existing pause/guard/haptics/restart
checks remain. Dense supply routing keeps its coverage; the real 16-body fixture
places the gathering point far enough past cover for all non-overlapping bodies
to fit, rather than requiring a compressed crowd at the near edge.

## Review and rollout

See validation/combat-visibility-2026-10-25 for source checks, builds and rendered
frames. Matching server deployment is needed for hosted damage outcomes; builds
alone do not update a live server. No installation/deployment/publication is
performed here. Old Continue runs keep their numerical balance snapshots; this
binary's new common hurt geometry applies on resume, without changing saved HP,
weapons or replaying damage. Native comfort/readability and difficulty need phone
review. Prioritize actual crowded fights, narrow landscape, mute/Reduced Motion,
near-miss projectiles and warning edges before accepting the feel.
