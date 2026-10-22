# Burster walk — 22 October 2026

Built-in `image_gen.imagegen`, genuine transparent background. Reference:
`assets/art/enemies/burster.png`, preserving the existing enemy identity.

Use case: stylized-concept. Production game sprite sheet for Regun, worn dark pixel-art top-down shooter. Reference image is the exact Burster enemy identity: heavy bloated gas-mask soldier, round cracked amber belly, worn olive suit, dark boots, copper canisters and hoses. Preserve this identity and proportions. Create transparent 4 columns x 4 rows atlas of 16 FULL BODY walking poses, identical scale and body center, feet baseline aligned in every cell, no cropping, generous transparent gutters. Row 1 walks toward camera/down. Row 2 walks away/up, showing backpack/canisters. Row 3 walks screen-right. Row 4 walks screen-left. EACH row is a four-frame COMPLETE walk gait in temporal order: left foot extended/right foot planted; feet passing close underneath hips; right foot extended/left foot planted; feet passing close underneath hips again. Visibly different alternating bent knees, forward/back boots and passing steps. This enemy WALKS on two boots, NEVER levitates or slides, no jump or float, no smeared legs. Belly and mask stay stable with tiny weight shifts, feet show real ground contact. 2D low-resolution game pixel clusters and dark tactile metal/fabric, muted olive and dirty amber, no neon, no scene, no ground plane or shadow drawn into sprites, no text, no labels. Actual transparent alpha outside all sprites. Keep all16 poses separated in an exact regular grid.

Packaged: `assets/art/enemies/burster_walk.png`; immutable master and measured
source/hash metadata are in this directory. Sprite rectangles retain equal cell
width, a shared height reference and measured foot baselines; source pixels and
alpha are unchanged. Native gait advances from actual movement distance.
