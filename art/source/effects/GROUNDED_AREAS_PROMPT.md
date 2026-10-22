# Grounded area materials — 22 October 2026

Built-in `image_gen.imagegen`, transparent background. Reference: packaged
`assets/art/effects/grounded_ordnance.png`. Full generation prompt:

Use case: stylized-concept. Game asset: transparent pixel-art material effects atlas for Regun, dark worn top-down ruin shooter. Reference image is existing grounded grenade/spore atlas; match its dusty low-saturation stone, charcoal, olive and tiny ember flecks. Create ONE 4 columns x 2 rows atlas, eight completely separated square cells, equal grid spacing, generous transparent gutters. Orthographic overhead floor decals, circular footprint (not tilted ovals), no scenery, characters, text, glow, clean vector outlines, neon or UI rings. Each isolated effect fits fully in its cell, centered, same scale, actual transparent background and alpha. Fine deliberate low-resolution pixel clusters, broken edges, floor shows through. Row1 left to right: 1 irregular circular pale dusty scuff boundary with fine charcoal cracks, empty transparent center, a hostile impact warning readable on dark stone; 2 low radial stone/dust impact with chunks at rim and planted center cracks, no tall spike; 3 irregular circular scorched ember warning, dusty rust and tiny subdued orange fissures, transparent center; 4 low burning rubble/embers with dark smoke around broken floor fragments. Row2 left to right: 5 muted olive poison seep with cracked earth boundary, transparent gaps, no bright green; 6 weathered fractured glass shards in dark dusty stone, modest pale glass glints; 7 dark iron shield-bash impact footprint with gouged stone and scattered iron chips, low dusty radial debris; 8 dark mauve ash/shadow fissure footprint with visible dusty edges, no luminous magic symbols. Purpose is real material on a worn arena floor, matching the approved grenade visual language.

Selected immutable source: `grounded_areas_master.png`. Packaged copy:
`assets/art/effects/grounded_areas.png`. Pixel bounds/source hash:
`grounded_areas_source.json`; atlas rectangles are metadata only, generated
alpha/pixels preserved. Decode256. The extra Rivet frame uses a metadata crop
of the first copper pin in the existing immutable Rivet Driver source.
