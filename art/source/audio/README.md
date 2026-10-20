# Combat recording sources

These three small source files are retained outside Flutter's packaged assets for reproducible processing. All are CC0; no paid provider assets are used.

- `ak47.ogg`: preview recording from [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library), Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney; uploaded by bart. [Original preview](https://opengameart.org/sites/default/files/ak47.ogg). Three isolated transients are extracted from the first burst; the automatic burst is never played directly in-game.
- `cannon_01.ogg`, `shot_01.ogg`: rubberduck's [25 CC0 bang/firework SFX](https://opengameart.org/content/25-cc0-bang-firework-sfx), extracted from [original archive](https://opengameart.org/sites/default/files/25-CC0-bang-sfx.zip). These provide pressure and contact layers, not literal in-game cannon/firework events.

License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Source SHA-256:

```
5914c1b1367d0f0e811fe2e01c2af468ba4a23994bba1dbed4bf77adf4cd6beb  ak47.ogg
e87ca0ee6b53da1f21cd9086cb75f456495871618fdfed63388bd2208a872596  cannon_01.ogg
a846eefebbb08b6f6d31a7728318b8de349ea2971cea148d7afdb41d797fdcfc  shot_01.ogg
```

Regenerate with `python3 tool/generate_weapon_audio.py` and `python3 tool/generate_boss_audio.py`; ffmpeg must be installed. Deterministic synthetic layers add pressure, phone-audible harmonics and controlled electrical texture. Runtime files remain mono PCM16/44.1kHz WAV.
