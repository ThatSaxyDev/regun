# Airdrop support art and sound

25 October 2026. Generated with the built-in imagegen tool for this feature.
`prompts.json` and `emitter-prompt.txt` retain the generation prompts. Original
transparent exports are base.png, carbine.png, burstRifle.png, aura.png and emitter.png. The rotating gun sprites
are dedicated turret designs, not copies of either survivor weapon.

`tool/import_support_art.py` packs cropped source alpha into bounded nearest-
neighbor gameplay textures and lazy manifest entries. Chassis/head composition,
mast/recoil/feed motion, descent and collapse are owned by SupportArt; no image
owns gameplay timing. card_* exports compose the same base/head pivots for menus.
Five decoded atlases together stay below 0.7 MiB; no combat/boss atlas is copied.

`tool/generate_support_audio.py` produces short bounded mounted mechanisms from
existing recorded CC0 weapon/supply WAVs and original activation/expiry tones.
Recorded-source provenance remains in art/source/audio/README.md. The support
manifest records exact derived files, peaks/RMS and hashes. Group gains, overlap
limiting, volume/mute and lifecycle remain in SoLoud. Native listening is a
hands-on acceptance item, not proven by the generation script.
