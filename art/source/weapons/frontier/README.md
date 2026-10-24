# Houndrack, Storm Orb and Ring Caster source packet

Generated 24 October 2026 with the built-in `image_gen` tool. The exact three
prompts are preserved in `prompts.json`; each used existing Regun weapon artwork
as the visual reference. No fallback image provider was used.

Each transparent master is the unmodified tool output, 1774 × 887 pixels. The
packaged weapon PNG is identical to its master. `generation.json` records output
paths, SHA-256 hashes, measured connected-component alpha bounds, draw sizes,
grip/muzzle coordinates and independently measured feed/latch sockets. Runtime
crops those parts; no bitmap redrawing, recoloring or compositing was used.

The selected weapon uses the existing acquired/released atlas path with a
224 × 112 decode (98 KiB). Rocket/orb effects use bounded pixel geometry. The revised Ring Caster uses
`cutter/master.png`, an additional generated iron annulus with exact prompt/hash
in `cutter/generation.json`. Its selected-only 256px decode uses one textured
annulus mesh in `frontier_vfx.dart`; the center remains transparent.

Real game renders are produced by `test/frontier_weapons_test.dart` in
`build/frontier-review`. Physical motion, blending and comfort remain for review.
