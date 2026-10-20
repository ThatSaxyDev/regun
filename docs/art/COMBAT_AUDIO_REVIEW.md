# Combat audio correction — release 1.0.0+7

## Sources and production

The ElevenLabs credential probe (plain process and sourced zsh profiles) returned:

```
ELEVENLABS_API_KEY=MISSING
```

No provider request or generated-provider asset is claimed. Reference ledger: `threejs-audio-generator/SKILL.md` and its `references/audio-workflows.md` were read. This Flutter/SoLoud implementation uses their asset-production guidance, rather than browser audio APIs.

Recorded CC0 inputs, authors, URLs, license and original hashes are in `art/source/audio/README.md`. No voice, voice ID, prompt or speech model is involved. The processing instructions are executable in `tool/generate_weapon_audio.py` and `tool/generate_boss_audio.py`: isolate real firearm attacks, layer filtered explosive/contact recordings, add short pressure harmonics audible above sub-bass, restrain high-frequency noise and fade tails after DC correction. Three firing variants per weapon prevent an identical repeated transient.

## Audio matrix

All listed cues are one-shots, mono PCM16 at 44.1kHz, in `assets/audio/`.

| Category / filename | Count | Duration | Trigger / SFX gain before preference volume |
|---|---:|---|---|
| `shot_{shotgun,carbine,revolver,arcCaster}_{0,1,2}.wav` | 12 | .38/.18/.42/.30s | One cue per trigger round, including one for a three-pellet blast; .72 |
| `impact_{shotgun,carbine,revolver,arcCaster}.wav` | 4 | .30/.22/.30/.30s | Bounded primary-hit feedback; .25, Arc .45 |
| `impact_boss.wav` | 1 | .48s | Shared boss/hazard impact; .60 |
| `impact_poison.wav`, `impact_guard.wav`, `hurt_player.wav` | 3 | .32/.20/.24s | Poison, shield absorption, player damage; .25/.25/.50 |
| `boss_{bellkeeper,magistrate,saint,sovereign,marshal}_{warn,hit,break}.wav` | 15 | .65/.38/.80s | Committed warning, release and break events; .50 |
| Existing reload mechanisms | 11 | .18–.32s | Existing reload phases; .42; end fades cleaned |

Boss warning identities remain distinct, with fewer ringing upper modes; hit/break cues add physical pressure instead of a louder chime. Music, UI and movement assets retain their existing identities. SFX and music preference/mute controls, SoLoud initialization, prewarming and pause/lifecycle handling remain in place. Existing 65ms per-impact-asset and other event cooldowns prevent every shotgun pellet from stacking a new full-volume hit cue.

## Evidence and review

`python3 tool/preview_combat_audio.py` checks the 35 firing/impact/boss assets for format, peak headroom, DC offset and clean endpoints. It writes hashes/measurements to `build/audio-review/combat_audio.csv` and an 18-second listening reel to `build/audio-review/combat_mix.wav`: shotgun, rifle burst, revolver, Arc, then rifle against two simultaneous boss impacts at runtime gains. The reel includes SFX only, not music/UI. Its measured peak is .707; it is not normalized. This is a representative overlap check, not a guarantee for every possible voice combination. Weapon asset durations/peaks/RMS are also tracked in `WEAPON_AUDIO_MANIFEST.csv`.

Automated checks establish file integrity and representative mix headroom. They do not establish subjective sound quality or device-speaker performance. Listen on the iPhone and headphones for attack definition, bass/body, repeated rifle fatigue, shield/damage distinction and warnings during paired Boss Rush. Native listening and general music/ambience review remain open.
