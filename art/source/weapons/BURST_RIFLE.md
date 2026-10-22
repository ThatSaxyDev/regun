# Burst Rifle source packet — 21 October 2026

Generated with the built-in `image_gen.imagegen` tool using `assets/art/weapons/arsenal.png` as a style reference. Original RGBA is preserved unchanged in `burst_rifle_master.png` and the packaged `assets/art/weapons/burst_rifle.png`; neither was repainted or alpha-processed. SHA-256: `3c15bc6333209bc766661d2ae6e5d8f43ec4bd7c19821f317ec66110561e8ccc`.

## Verbatim prompt

Use case: stylized-concept. Asset type: production transparent modular weapon sprite packet for Regun top-down pixel shooter. The reference is STYLE ONLY; create a new compact three-round burst rifle, recognizable and distinct from the reference carbine, in graphite weathered iron, olive receiver panels, small worn copper fittings and a short squared muzzle. Exact orthographic side view pointing RIGHT, no perspective, no hands, no background, NO TEXT. Exactly THREE separated objects: upper half one complete rifle receiver/body with stock, grip, barrel and EMPTY magazine well (no magazine baked into body), bolt recess open; lower-left one separate short straight detachable magazine in the correct vertical orientation to slot into receiver, lower-right one separate small horizontal sliding bolt cover. Large transparent gutters, body occupies x10%-90% y10%-45%, magazine x20%-35% y65%-90%, bolt x65%-80% y70%-80%. Match reference's textured, hard edged pixel illustration: readable chunky silhouette, metal edge wear, modest source detail, no glow, no muzzle flash, no cast shadow, no additional shells/props, no drop shadow. Body and separated mechanisms must be mechanically coherent, with visible empty sockets ready for runtime assembly. True alpha transparency. This is one modular weapon art packet, not a showcase scene.

## Measured registration

The actual generated layout differs from the requested region percentages; use the measured rectangles, not those percentages. Source 1536×1024. Alpha threshold96 bounds:

| Part | Pixel bounds (left, top, right, bottom) |
|---|---|
| Receiver | 36,111,1498,581 |
| Magazine | 332,620,553,962 |
| Bolt cover | 935,723,1279,820 |

`assets/art/manifest.json` registers these as explicit frames0/1/2 at decodeWidth224. The global `inspect_art.py` was deliberately not rerun because it rebuilds its configured manifest and may overwrite newer entries/settings. Source pixels remain recoverable.

Receiver draw62×20, grip pivot(.43,.55), barrel height.347; local muzzle(35.34,−4.06). The hand mount adds8 along aim and6 below the actor. Mirroring transforms the side offset; all Burst Rifle pellets share one physical muzzle. Magazine draw7×10.83 at(7,2.5), bolt7.2×2 at(5,−5.4). Art is composed through the shared world/HUD renderer.

## Review

Rendered phase/handedness/angle/Reduced Motion contact sheet: `build/test-previews/burst-rifle-mechanism.png`. Actual gameplay/HUD: `build/test-previews/rounds-burstRifle.png` and `refill-burstRifle.png`. Static composition inspected; native moving alignment, weapon comfort and audio listening remain pending. This is generated game art, not a commissioned hand-pixelled pack. Other ten expansion weapon packets are not generated yet.


## Device-review reload correction

Creator requested distinct loaded/empty reloads. With ammunition remaining, manual reload now lasts1.4s, seats the magazine at82% and omits bolt motion/sound. Empty reload remains2.0s, seats at42% and cycles the bolt at82%. The same original sprite packet is used unchanged. The renderer contact sheet now adds tactical and reduced-motion tactical rows; normal and reduced-motion empty rows remain.
