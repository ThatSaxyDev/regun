# Regun art bible — breached quarantine facility

Implemented direction, 19 October 2026. This replaces the inherited red Flame soldier and purple plank/grid floor. This document describes the shipped candidate; the broader specification remains in `REGUN_ART_OVERHAUL_PLAN.md`.

## Characters and materials

Rook wears a bone-white field jacket, graphite respirator helmet, cyan visor, mustard scarf and copper harness. Scrapper has dark skin, goggles, an olive utility coat and a tool harness. Warden wears heavy slate/gunmetal armour with an amber visor and pale faceplate. Their bodies contain no baked gun; the renderer places an independent weapon and glove at the hand. No inherited body/head frames are used.

All three have four facings: east, south, west, north. Each facing has two idle poses; the current animation candidate adds an eight-pose full-body run loop in a separate `_run` atlas. Dash, braced firing, hurt and defeated poses remain in a separate action atlas. Running and firing can coexist. Aim chooses facing while active, movement otherwise. These are AI-assisted generated frames, not a commissioned hand-pixelled production pack. Check temporal consistency on the phone; some pose/outline cleanup can still improve them.

Graphite, dirty olive, worn copper, bone and restrained brass connect the world to the existing pixel UI. Friendly shots stay warm brass, hostile bolts red/orange or violet, poison olive-green, electrical energy pale cyan. Keep floor brightness below character brightness. No real-time per-enemy lighting is required.

## Weapons

The separate arsenal atlas contains four base guns and four moving mechanisms: shotgun pump, carbine magazine, revolver cylinder, arc cell. Mechanical motion follows reload progress. The shotgun retains its existing authored HUD Lottie and shell timing. Recoil and a brief muzzle flash remain procedural. These are not four copies of the shotgun animation.

## Infestation roster

Eight normal roles have new sheets: Scorpion, Mummy, Ranged, Runner, Shield, Burster, Nest and Sentinel. Walk/idle, warning, attack and defeated artwork support the existing behaviours; elites retain a visible badge and existing stat multiplier. Burster and Sentinel directional poses are selected by target direction, rather than cycling through orientations as walking frames.

Shadow is a cloaked respirator figure with a copper ribcage and cold energy; Demon is a furnace/boiler armoured brute; Queen is an armoured scorpion matriarch. Each has a 40-frame sheet with idle/walk, three warning/attack sequences, an enraged treatment and defeat sequence. Gameplay states select the matching animation. Existing warning circles/lanes and damage clocks stay authoritative; sprite glow must never imply an extra damaging footprint.

## Environments

Breach uses cracked olive concrete, broken containment seals, ruined copper-bound columns, flush grates and sparse debris. Foundry uses riveted blue-gray steel, boiler machinery, pipes, grates and vent anchors. Small material details and landmarks make movement visible without an exposed grid.

Both worlds remain 4512 × 4512. `assets/tiles/maptile.tmx` object groups are authoritative for solid footprints and Foundry vents. Breach has four columns at x ±560 / y ±230; Foundry has six boilers at x ±600 / y −700, 0, 700. These are deliberate layout changes from the older prototype. Save restoration constrains actors out of solids. Tall props sort against actors by foot height and fade when they obscure the player. Low debris/grates are nonblocking. Camera clamping remains tied to world bounds.

The floor is a visible-region texture renderer, not 19,881 independent tile components. Wall rims stay inside the floor. Landmarks, debris and all effects remain finite. Additional authored regional floor variation and bespoke boundary modules are worthwhile future art improvements; this candidate is not a complete modular wall/transition tile kit.

## Runtime contract

- Source PNGs in `assets/art/` retain original generated alpha and pixels.
- `tool/inspect_art.py` measures source rows, frame rectangles and pivots. It does not modify images. Generated sheet spacing is not assumed uniform.
- `assets/art/manifest.json` describes 25 shared textures and 448 cropped frames, including character actions and items.
- `RegunArt` decodes each texture once, caches frames and raw sprites, and normalizes body height/ground placement. No entity decodes its own source sheet.
- Measured shared decoded RGBA allocation is **29.13 MiB**, before renderer/engine overhead. The regression target is ≤32 MiB.
- Nearest filtering is retained. Source pixel density is more detailed than the old art; native visual judgment remains necessary.
- Legacy body/enemy/map images remain recoverable on disk but are excluded from Flutter's packaged asset list. Heart and splash remain inherited UI assets; icons and reload Lottie are separate.

## Production record

Built-in `image_gen.imagegen` created the raster art. No purchased pack or external artist attribution is implied. See `art/source/GENERATION_PROMPTS.md` for captured prompts and logging limitations, `docs/ASSET_MANIFEST.csv` for per-file SHA-256/source records, and `ART_OVERHAUL_PROGRESS.md` for verification and open gates.


See [ANIMATION_REPAIR_2026-10-19.md](ANIMATION_REPAIR_2026-10-19.md) for the current playback candidate and explicitly rejected segmented-leg experiment.
