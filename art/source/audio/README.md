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

## Recorded reload mechanisms — 20 October 2026

Additional source recordings (outside packaged assets):

- `handgun_reload_zer0sol.wav`: zer0_sol, [Handgun Reload Sound Effect](https://opengameart.org/content/handgun-reload-sound-effect), [original WAV](https://opengameart.org/sites/default/files/reload.wav). CC0. Magazine release, insertion and slide provide short latch/contact layers for the shotgun shell, revolver and Arc casing.
- `rifle_reload_springyspringo.wav`: SpringySpringo, [Gun reload sounds](https://opengameart.org/content/gun-reload-sounds), [original WAV](https://opengameart.org/sites/default/files/assaultriflereload1_0.wav). CC0, recorded airsoft mechanism. Split into magazine-out, magazine-in and bolt cues for Carbine; the first contact also supplies the Arc casing release.
- `shotgun_pump_springyspringo.wav`: same author, page and CC0 license, [original WAV](https://opengameart.org/sites/default/files/shotguncock_0.wav). Recorded airsoft pump, used for shotgun action and a lower-pitched Arc casing latch.

Original SHA-256:

```
091399145b174ac3b2e0df245b4712a13ce85df072e37256b0fc32658718be53  handgun_reload_zer0sol.wav
efb2d724d634eabe6ba8d3065686abca848bb7497d4d43a5e4aed5e5ea23016f  rifle_reload_springyspringo.wav
33e007321ba83301c861aef573f2c40b70bc62f8f24c0164877e6dd123e24371  shotgun_pump_springyspringo.wav
```

`python3 tool/generate_reload_audio.py` extracts individual contacts, lowers pitch slightly, restores short duration independently with atempo, filters subsonic/harsh upper frequencies, adds restrained low-mid body and bounds each cue's peak. All trim/filter/duration settings are in its `CUES` table; no voices, loops or provider-generated assets. Full `generate_weapon_audio.py` calls this generator after producing firing/impact cues. `--only arcCaster` remains a firing/impact-only correction and preserves the recorded reload assets.
