# Regun — complete sprite and arena art overhaul

Production specification · 19 October 2026

**Implementation update:** the active roster, two arenas, weapons and items have now been replaced in the playable candidate. Read [art/ART_OVERHAUL_PROGRESS.md](art/ART_OVERHAUL_PROGRESS.md) for delivered scope, evidence and explicit remaining gates. The unchecked acceptance items below are the original review checklist, not an assertion that implementation has not started. Physical performance and final art acceptance remain open.

## 1. The brief

Replace the current gameplay sprites and map art with a coherent, original visual identity. The creator does not want a recolour of the current floor, or a better disguise for the gun baked into the old character. The replacement must include proper character/weapon separation, readable animation, distinctive enemies and bosses, and environments worth playing in.

**Creator clarification:** the current player sprite is explicitly rejected. Build a fresh player design from the ground up; do not reuse its body, head, silhouette, animation frames or baked weapon as the replacement. Rook, Scrapper and Warden remain gameplay roles, not requirements to preserve the old character appearance. The new Rook colour/outfit can change to suit the approved art direction. Retire the old player from gameplay, the starting screen and all previews once the replacement passes validation.

The current grid was useful because it made movement visible. Preserve that useful feedback through the environment, rather than preserving the grid's appearance. The creator should not need to draw sprites, assemble animation sheets, or learn Tiled to make this happen.

This document is a production plan, not a claim that new assets have already been generated or integrated. Gameplay code, installed builds and current art remain unchanged during this planning pass. The intended scope is both arenas and the entire active visual roster, including menu/loadout/collection representations of the replaced characters and weapons. This is not another wholesale UI redesign.

## 2. Proposed direction: a breached quarantine facility

**Look:** crisp, moderately detailed pixel art; grounded equipment; ruined sci-fi architecture reclaimed by an infestation. Charcoal metal, worn stone/concrete, oxidised copper and dirty olive materials. The player gets a fresh silhouette and outfit; a restrained rust-orange accent is a proposed palette option, not a requirement to resemble the old sprite. Small warm brass accents connect the world to the existing UI.

**Mood:** dangerous and tactile, with strong silhouettes and restrained colour. A survivor should look resourceful and vulnerable; a boss should look formidable before it attacks.

**Camera language:** retain the game's current overhead/three-quarter presentation. Floor geometry stays orthographic and characters are drawn with readable three-quarter volume. Do not turn this into an isometric game or change movement/collision to suit an illustration.

**Rendering language:** consistent pixel density, deliberate clusters, restrained outlines, coherent lighting from the upper-left. No photographic surfaces beneath pixel characters, soft painterly bosses alongside hard pixel mobs, or blurred scaling that makes source assets look inconsistent.

### The visual hierarchy

1. Player location and incoming damaging attacks.
2. Nearby enemies, boss tells, projectiles and usable escape space.
3. XP, mines, support drones and other useful objects.
4. Architecture, landmark props and floor details.

The world can be rich without every surface demanding attention. Compare ordinary gameplay and dense fused builds at actual phone size, not just large concept-sheet zoom.

### What a successful replacement feels like

- Rook, Scrapper and Warden are identifiable without reading names or relying solely on colour.
- A gun looks held, turns naturally, recoils and reloads without missing pieces of the body.
- Enemies read as members of the same world, with distinct attack silhouettes.
- Breach and Foundry look different immediately, not like the same tiles with different tint.
- Moving looks and feels clear even in an empty patch of floor.
- Screenshots of the game world and interface belong to the same product.

This is the recommended starting direction. It is a proposal, not an irreversible aesthetic commitment; the first playable art sample is where we judge it.

## 3. What the current code tells us

| Current implementation | Consequence for the replacement |
|---|---|
| Player frames contain a baked-in gun. The renderer clips part of that area and paints a separate aimed gun. | Replace the source body art with genuinely weapon-free frames. Remove the clipping workaround once the new renderer works. |
| Survivors share the old base body, with canvas accessories/colour blocks. | Give each survivor an authored silhouette and outfit. Cosmetic layers become intentional attachment points. |
| Normal enemies mix inherited sheets and canvas silhouettes; bosses mix inherited art and a canvas Queen. | Replace the full active roster, rather than creating a second mixed-style layer. |
| Tiled map is 141×141 cells, with 32-unit cells: 4512×4512 world units. Its tileset is 160×160 pixels with 25 tiles; floor layer opacity is 0.47. | The existing map is a simple repetitive base, not a large authored environment. A new tileset/layout can change its appearance completely. |
| Both arenas share that base map; Foundry adds a tint/grid and different rectangular props. | Give each arena its own authored ground, wall and prop kit; retire the floor tint/grid as its identity. |
| Collision/bounds are already separate systems; obstacle rectangles are currently defined in Dart. | Preserve their correctness first. Establish one authoritative layout before introducing new obstacle shapes or moving walls. |
| Camera, input, combat, reload, progression and saving already work independently of most visual assets. | Rebuild presentation without rewriting the survival game or quietly changing weapon balance. |

Primary integration points: `PlayerComponent`, `weapon_art.dart`, each enemy/boss visual, `MapComponent`, `ArenaScenery`, `ArenaGeometry`, sprite preloads, and character/menu/loadout/collection previews.

## 4. A playable art sample comes first

Before producing the full roster, create one representative scene in the actual Flame game:

- One newly drawn Rook with weapon-free movement/idle art.
- A proper separate shotgun, gripping hands and muzzle/reload feedback.
- One newly drawn scorpion and one larger enemy to establish relative scale.
- A small authored Breach section with ground variation, wall/corner, column, debris, shadow and a landmark.
- Representative XP, an incoming enemy projectile, one attack warning and one upgraded player effect.
- Actual movement, aiming, firing, reload, damage, dash and pause/death overlays at phone resolution.

Present a screenshot and a short moving demonstration from that playable scene. A painted mockup alone is not the approval standard: it could hide problems with pivots, animation, camera motion, floor repetition and combat readability.

**Pass only if:** the scene is a substantial visible improvement, aiming works in every direction, character scale is sensible, ground motion reads without a grid, and enemy threats remain clear.

If the style fails here, revise this small set. Do not generate dozens of mismatched sheets and try to unify them afterwards. This is a quality checkpoint, not a requirement for the creator to manage individual frames or tools.

## 5. Asset production workflow

I will handle concepts, generation, iteration, frame preparation, integration, export validation and the asset ledger. The creator's role is to judge how it looks and feels in play, rather than supply sprite-making skills.

### Step A — establish the art bible

Create an approved reference sheet with the three survivor silhouettes, representative enemy proportions, materials/palette, camera angle, weapon scale, floor/wall samples and effect colours. Record these rules in `docs/art/ART_BIBLE.md` and retain the source/reference images.

Use generated raster concept art and asset iterations through the available image-generation workflow. Ask for transparent backgrounds for isolated sprites. Floor/tileset requests are seamless/modular environment assets, not giant pictures of a whole arena.

### Step B — produce controllable assets

Create a clean neutral reference per character/enemy before animation variants. Keep body proportions, outfit features, light direction, canvas, ground contact and attachment points fixed across every iteration.

AI image generation can help create attractive designs and raster assets, but it does **not** reliably guarantee exact pixel clusters, seamless tiles, frame alignment or coherent animation in one request. Those outputs require inspection and iterative correction. Treat a generated contact sheet as a candidate, not a finished engine-ready animation.

Do not solve a failed detailed sprite by silently returning to a rectangle or a recoloured inherited sheet. A code-rendered warning ring or simple projectile is appropriate; a supposedly finished hero or boss needs real authored visual content.

### Step C — validate exports

Every accepted sheet must have exact frame dimensions/counts, genuine transparency, consistent feet/pivots, no clipped weapon/limb, no white fringe, stable silhouette and tested loops. Tiles must join without bright seams or obvious repeating marks. Inspect on the intended dark background and at actual game size.

Store source concepts, chosen generations, animation layouts and export metadata alongside a manifest with provenance, dimensions, frame timing and attachment points. Keep paths within the project; runtime assets must not depend on a personal Downloads folder or an image-generation cache.

### Step D — integrate, then judge again

Use an asset manifest/animation loader so each entity declares its visual states and attachments. Atlas packing and deterministic validation belong in the build workflow. Check packing size, padding and nearest-neighbour sampling; a good-looking loose PNG can still bleed into adjacent atlas frames in motion.

Only remove a legacy reference after its replacement has passed the relevant gameplay paths. Legacy art is a temporary development fallback, not the final result.

## 6. Sprite contract and animation rules

### Initial production specifications

These are initial targets to prove in the playable sample, not a promise that every entity fits the same box.

| Asset | Initial source frame | Required treatment |
|---|---|---|
| Survivors | 48×48 | Weapon-free body; fixed ground/pelvis and hand attachment points; outfit masks/layers for cosmetics. |
| Small/medium enemies | 32×32 or 48×48 | Consistent perceived pixel scale; generous attack-frame canvas where needed. |
| Large normal enemies | 64×64 | Distinct mass and telegraph silhouette without inflating the damage footprint. |
| Bosses | 96×96 to 128×128 | Model sheet, explicit ground footprint, attack-specific attachments and oversized attack-frame bounds where needed. |
| Held weapons | Around 32×16; larger sheets when mechanics require it | Defined grip, muzzle, casing/vent and reload anchors; separate from the body. |
| XP/items | 8×8 to 16×16 | Strong small-scale silhouette; avoid dependence on fine texture. |
| Terrain | 32×32 base modules, larger decorative composites | Common density with sprites; larger floor motifs to break repetition. |

World-space component size and combat footprint are separate from image canvas dimensions. Preserve current collision radii/health/damage unless a deliberate balance change is specified and tested. Do not make an enemy harder to hit merely because its new picture is larger or has transparent padding.

### Survivors: direction and state

- Four authored body-facing directions, with deliberate left/right mirroring only where the design is actually symmetric.
- Continuous 360° gun aim; body-facing direction follows aim during active aiming and movement otherwise.
- Movement includes sideways/backpedalling readability. Decide in the sample whether separate leg/torso layers or authored strafe frames provide the best result; do not accept obvious moonwalking as a completed animation.
- Initial loops: idle 4 frames; movement 6–8 frames per required direction; distinct dash/brace pose, hurt feedback and defeat pose.
- Firing has recoil/hand response, rather than rotating the entire character picture around its centre.
- Reload remains a weapon/hand action; the body can continue moving.
- Cosmetic attachments use named anchors/masks, not hard-coded patches covering arbitrary old pixels.

A full animated death must never postpone or block the results screen. Game-over correctness takes priority: use an immediate authored defeat pose first, and add a nonblocking presentation animation only if it can run independently of paused combat. Keep the new death/results regression passing.

### Layering the held weapon properly

Render far arm/weapon/near hand in the correct order for the aim direction, switching front/behind the torso when aiming north/south. Define left-facing flips around the grip, so barrels and hands remain attached. Use the muzzle anchor for muzzle flash/projectile presentation while preserving the logical firing origin and wall-collision rules.

For reload, use authored mechanical states plus animation transforms where appropriate: shells/pump for shotgun, magazine/bolt for carbine, cylinder for revolver, vent/cell for Arc Caster. Preserve the existing shotgun HUD Lottie and its normal reload timing/shell cue schedule. Replacement visual timing follows the existing reload progress, not a new independent timer.

## 7. Full roster replacement

### Survivors

| Survivor | Proposed silhouette | Must remain readable |
|---|---|---|
| Rook | Fresh survivor design: distinctive field gear, a new head/helmet treatment and a clearly readable body silhouette. Outfit and accent colour are established in the art sample. | Balanced gameplay baseline; original visual identity with no dependence on the rejected player sprite. |
| Scrapper | Olive workwear, asymmetric tool harness, lighter scavenger kit. | Pickup/explosive specialist; distinct body/accessories even without palette colour. |
| Warden | Heavier protective chest/shoulder mass, restrained pale-blue/steel accents. | Slower guard survivor; guard overlay does not hide attacks or the body. |

Use the same character assets in the starting screen, loadout/training selection and collection previews. Preserve the deliberately smaller starting-screen presentation; a new higher-resolution source must not enlarge the menu character again.

### Eight enemy roles

| Role | Art direction | Required readable animation |
|---|---|---|
| Scorpion | Low armoured vermin, clear claws/tail. | Scuttle, contact/hurt response, death. |
| Mummy | Quarantine-wrapped heavy infected worker. | Deliberate walk, wind-up, strike, recovery, death. |
| Revenant | Lean corrupted ranged attacker with an identifiable firing organ/device. | Walk, aim/wind-up, shot, recovery, hurt/death. |
| Skitter | Low, spring-loaded infestation runner. | Crouch/anticipation, lunge, skid/recovery, death. |
| Shield Warden | Armoured infected guardian with an obvious facing shield. | Guarded movement, attack, exposed recovery, death. |
| Burster | Distended pressure-sac carrier with a strong warning silhouette. | Walk, inflation/warning, burst; persistent readable danger mark. |
| Brood Nest | Rooted organic/mechanical brood structure. | Idle pulse, spawn, damaged state and destruction. |
| Sentinel | Stationary/slow corrupted targeting unit. | Target acquisition, marked strike, cooldown, destruction. |

Each elite uses a clear authored accent/armor addition or outline/marker, not only a small colour tint. Preserve enemy role names, attack timing, health and encounter eligibility during the visual migration.

### Three bosses

| Boss | Identity | Minimum authored states |
|---|---|---|
| Shadow | A torn quarantine enforcer/wraith, clear flowing mass and a distinctive weapon/attack hand. | Arrival, movement/idle, fan-shot anticipation/release, dash preparation/travel/recovery, close strike, phase transition, defeat. |
| Demon | A furnace-mutated brute with asymmetrical slag armour and a massive striking limb. | Arrival, heavy movement, cleave wind-up/release/recovery, slam, charge, phase transition, defeat. |
| Scorpion Queen | A genuinely detailed armoured brood matriarch; large claws, segmented tail and unmistakable stinger. | Arrival/idle/movement, tail aim/strike/recovery, brood release, poison release, phase transition, defeat. |

Animations consume the boss state machine's progress. Warning areas remain grounded and visible independently of the sprite. No charging picture through a blocked wall, hidden poison behind a tail, or bright phase effect that conceals an attack. Keep phase/damage/reward logic unchanged.

### Weapons, items and effects

Replace the four temporary weapon renderings with matching art and proper reload states. Replace inherited XP/pickup/projectile/mines imagery as part of the same language. Add a coherent companion drone and upgrade/fusion effects: controlled fire patches, readable arcs, trails, ricochet impacts and shards.

Maintain a strict distinction between hostile attacks and friendly effects using shape, motion and brightness as well as colour. Essential telegraphs remain precise code-driven shapes where that provides better fidelity to the actual collision area; detailed art must not make warnings inaccurate.

## 8. Better maps without relying on the grid

### Breach — quarantine concourse

Cracked concrete/stone interrupted by recessed steel utility panels, irregular repaired sections, faded directional markings, broken containment fixtures and sealed bulkheads. Sparse damaged columns create recognisable landmarks with open fighting space around them.

Use occasional large floor motifs and material changes to establish location: a containment seal, a drained channel, an old transit stripe or a broken service station. Avoid a tiled photograph of rubble or a uniform checkerboard of decorative noise.

### Foundry — abandoned processing floor

Worn steel slabs, grates, machine bases, inset channels, exposed service runs, restrained ember details and furnace/bulkhead silhouettes at boundaries. Its columns become real machine assemblies. Vents look like vents before they activate, but only the actual attack warning uses the strong hazardous treatment.

Do not fill the playable floor with painted molten holes that look impassable while behaving like ordinary safe ground. Any new blocking/hazardous region must be defined by the authoritative layout and tested.

### Movement readability replaces the visible grid

| Cue | Purpose | Constraint |
|---|---|---|
| Uneven cracks, panel seams and material joins | Nearby ground visibly travels under the player as the camera follows. | Low contrast; no continuous full-arena square grid. |
| Scattered decals and small debris | Local motion reference and texture variation. | Deterministic placement, bounded density; cannot disguise XP or projectiles. |
| Larger landmark props/material zones | Orientation and a sense of place over longer travel. | Keep readable escape lanes and boss fighting space. |
| Contact shadows | Ground characters and make relative motion easier to read. | Cheap, consistent light direction; not expensive full-screen dynamic lighting. |
| Subtle dust/foot contact cues | Reinforce movement and dashes. | Capped and reduced-motion aware; not the only cue. |

The camera's existing behaviour remains intact. Do not create parallax on the collision floor or add camera drift solely to fake movement. Ground movement should correspond to world movement.

## 9. Tiled: useful authoring data, not the art style

Retain Tiled for authored arena layout unless the sample exposes a concrete reason to replace it. It already loads through Flame; throwing it away is unnecessary to replace the art. I can create and maintain the `.tmx`/`.tsx` data and integration; the creator does not need to operate the editor.

Proposed layers:

| Layer | Contents | Runtime interpretation |
|---|---|---|
| Ground base | Seamless material modules and edge transitions. | Batched/cached terrain. |
| Ground variation | Larger damaged/repaired sections. | Static, deterministic placement. |
| Decals | Paint, stains, cracks and nonblocking debris. | Below entities; bounded visual density. |
| Obstacle definitions | Explicit footprint objects with stable IDs. | One collision source for player, enemies, shots and boss movement. |
| Prop bases / walls | Grounded architecture. | Render lower portion at ground level. |
| Prop foreground | Tall tops/overhangs where necessary. | Foot-based depth ordering; fade/outline when obscuring the player. |
| Hazard anchors | Foundry vent locations and allowed regions. | Existing hazard logic consumes layout coordinates. |
| Landmarks / spawn metadata | Orientation references and explicitly useful encounter regions. | Authoring data; do not silently add new spawn rules. |

**One source of truth:** migrate obstacle rectangles from the present hard-coded list into a validated arena-layout model populated by the map's object data. Both scenery and collision use that model. Never maintain an independently painted wall and an unrelated hard-coded collider.

During the first visual replacement, retain the current 4512×4512 bounds and obstacle footprints. That keeps camera, saves, spawning and boss spacing stable while the style is judged. Moving/adding obstacles is a subsequent explicit layout change. Existing checkpoints then need safe-position validation/relocation; do not strand a saved player inside a newly placed machine.

Rendering stays finite and edge-safe. New wall depth/foreground decorations must not reintroduce the original black-outside-map issue or invalidate the camera's visible-floor bounds.

## 10. Asset organisation and delivery

Planned source/delivery structure:

```text
art/source/                 # chosen concepts, references, frame layouts, metadata
assets/art/characters/      # Rook, Scrapper, Warden and cosmetic masks/attachments
assets/art/enemies/         # eight normal roles and elite treatment
assets/art/bosses/          # Shadow, Demon, Queen
assets/art/weapons/         # separate gun/reload sheets
assets/art/items/           # XP, mines, drone and world pickups
assets/art/effects/         # coherent raster effects where appropriate
assets/art/arenas/breach/   # ground, walls, props, decals
assets/art/arenas/foundry/  # a genuinely separate environment kit
assets/tiles/               # authored layouts and tileset references
lib/presentation/           # proposed loaders, animation/attachment/depth helpers
```

Paths are a proposed organisation; add them to Flutter asset declarations before runtime use. The final manifest records every runtime replacement, provenance/source reference, dimensions, animation states/frame timings, pivots, masks and consumers. No missing state may silently fall back to a different old character in the final build.

Retire unused inherited images from the packaged asset set only after a reference audit. Keep source history recoverable; no destructive cleanup of the current working tree. New art also needs provenance review; generation is not a legal guarantee. Do not imitate a specific game's sprites or represent inherited assets as newly original.

## 11. Performance and correctness budget

A prettier arena must not bring back the hitches we repaired.

- No Flutter widget per tile, decoration or enemy.
- Use terrain batching/caching/visible-region rendering; do not redraw the entire 141×141 layout as thousands of independent components every frame.
- Share atlases and prewarm active frames before first appearance. Measure first-use decode/upload stalls.
- Keep atlas sheets within device-supported limits and split by use rather than building a single enormous texture.
- Set the initial decoded-texture target around 32 MiB for the active arena/roster, then measure and adjust. This is a target, not an established benchmark. RGBA memory is roughly width × height × 4 before engine overhead; a 2048² atlas alone is about 16 MiB.
- Reuse cheap shadows and bounded effects. Avoid a real-time light/blur pass per enemy or per vent.
- Keep existing entity/effect caps and reduced-motion behaviour.
- Depth-sort by stable ground/foot anchors; avoid allocating and sorting unnecessary objects for every tiny decorative piece.
- Inspect transparent margins/overdraw, especially on large bosses and floor effects.
- Record native iPhone/Android frame times and memory for equivalent old/new dense scenarios. A reduced art budget is preferable to visually richer input lag.

No “60 FPS achieved” claim without a trace from a real phone. Compare a repeatable developed-build scenario as well as the small art sample.

## 12. Implementation phases and exit criteria

| Phase | Work | Exit condition |
|---|---|---|
| A — style/specification | Art bible, roster designs, palette, material rules, source-frame/pivot specification. | A clear direction that can be produced consistently; no gameplay changes. |
| B — playable art sample | Rook + shotgun + two enemy scales + an authored Breach section. | In-engine still/motion proof at phone size, genuine body/weapon separation, readable movement and threats. |
| C — full character/weapon set | All survivors, four guns/reloads, cosmetics, menu/loadout/collection consumers. | All twelve combinations aim/move/reload correctly; no clipping workaround; menu character stays appropriately sized. |
| D — ordinary enemies | Replace all eight roles and elite presentation. | Each role's warnings/attack/recovery/death are identifiable and synchronised with existing logic. |
| E — complete arenas | Both environment kits, authored layers/props, authoritative layout integration. | Distinct environments, no floor grid dependency, no edge gaps, collision/occlusion/save-position checks pass. |
| F — bosses and effects | Three full boss visual sets, projectiles/items/drone/fusion polish. | Every attack has readable anticipation/action/recovery; dense builds remain understandable. |
| G — retirement and validation | Remove runtime legacy art references, asset audit, full regression and native builds/device comparisons. | Entire active roster uses the new style; no missing animation/state, known gameplay regression or unmeasured performance claim. |

Boss designs are established in Phase A and one boss-scale placeholder is checked in the sample; their full animation sets follow the established production style. Environment props can develop alongside the roster after the sample passes. Do not let parallel asset creation drift into separate art styles.

Do not promise a fixed completion date before the playable sample establishes how many generation/cleanup iterations the style needs. Production quantity scales with the number of directions, states and frames; “three characters” is not three finished PNGs.

## 13. Acceptance checklist

### Visual

- [ ] All three survivors are recognisable by silhouette at actual phone size.
- [ ] Player body contains no baked gun; hands/grip remain attached at all aim angles.
- [ ] Movement, idle, firing, reload, hurt and dash states transition without missing or jumping frames.
- [ ] Every active normal enemy, elite and boss has coherent replacement art.
- [ ] Both arenas are visibly authored and distinct; repeated tile stamps and seams are not distracting.
- [ ] Ground movement remains obvious without an exposed grid.
- [ ] Near threats, hostile shots, XP and warning areas remain readable in dense combat.
- [ ] Characters/props have coherent scale, shadows, pixel density and depth.

### Gameplay preservation

- [ ] All twelve survivor/weapon combinations; mirrored/floating/custom controls.
- [ ] Shotgun normal reload, sound schedule and Lottie preserved; other guns retain their own mechanics.
- [ ] Same damage, cooldowns, enemy/boss phases, ranks, fusions and once-only rewards during visual migration.
- [ ] Death → visible results → Restart → death → Menu regression remains green, including working saves with no warning banner.
- [ ] Both arenas' four edges/corners, columns, fast shots and long dashes pass geometry checks.
- [ ] Boss warnings match damage footprints in every phase and near obstacles.
- [ ] Old checkpoints/profiles remain compatible, with safe relocation if layout footprints change.
- [ ] Menus/previews/equipped cosmetics use the replacement assets and preserve their intended scale.

### Technical

- [ ] Exact valid frame counts/sizes/metadata and genuine transparency.
- [ ] No atlas bleeding, clipped frames or unintended filtering blur.
- [ ] No per-entity asset loading or unbounded decoration/effect growth.
- [ ] Clean analyzer/regression suite and successful native release builds.
- [ ] Physical device motion, frame-time, memory and thermal comparison recorded.
- [ ] Every packaged asset has a source/provenance entry; retired references are removed deliberately.

## 14. What the creator needs to provide

No sprite sheets, drawing tools, Tiled setup or asset purchases are required to start this workflow. I can handle the production pipeline with the available tools and the existing codebase.

The meaningful creator input is visual/gameplay judgment: whether the playable sample has the right character, whether silhouettes and motion read clearly, and whether it looks good on the actual phone. Feedback can be as simple as “more worn military equipment, less horror” or “the floor is too busy.” If a later proprietary asset/tool is genuinely necessary, identify that concrete need then; do not assume an external commission or purchase in advance.

The next deliverable is the art bible and **one real playable art sample**, followed by full-roster production once that standard works. The finishing condition is a cohesive moving game with preserved functionality, not a folder of attractive but unintegrated generated pictures.
