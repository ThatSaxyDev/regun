# Action score — release 1.0.0+7

The creator requested more action in the soundtrack, explicitly including the menu. All four old looping music assets are replaced; weapons, enemy cues and music/SFX controls keep their existing mix/trigger contracts.

| Context / file | Tempo | Arrangement | Length |
| --- | --- | --- | --- |
| `assets/audio/music_menu.wav` | 124 BPM | Dark low-string pulse, half-time backbeat, action-ready anticipation | 30.97s |
| `assets/audio/music_breach.wav` | 138 BPM | Syncopated low-string ostinato, bass pulse, breakbeat pressure | 27.83s |
| `assets/audio/music_foundry.wav` | 146 BPM | Grinding power dyads, floor toms, heavier machinery rhythm | 26.30s |
| `assets/audio/music_boss.wav` | 156 BPM | Double-time pursuit, staggered accents, minor-second tension in the final build | 24.62s |

These are original deterministic instrumental compositions, with no external samples, licensed melody, vocals, voice ID or generation prompt. `tool/generate_action_music.py` is the complete score/synthesis source: sixteen bars, phrase variations, two half-time bars, kick/snare/tom fills, detuned low-string power dyads and bass harmonics audible above the sub range. Combat starts with a full rhythm rather than waiting through an intro. The menu belongs to the same musical identity with a less dense half-time rhythm. There is no bright continuous lead arpeggio. Tails wrap around the loop; a two-millisecond seam correction avoids cutting them or fading out the entire track.

Regenerate with a Python environment containing NumPy and `ffmpeg` on PATH:

```
python3 tool/generate_action_music.py
python3 tool/preview_action_music.py
```

`tool/generate_audio.py` now leaves all music alone, preventing accidental restoration of the older score when regenerating legacy effects. All music remains mono PCM16/44.1kHz WAV at the existing SoLoud asset paths. Full track metadata, seeds and hashes are in `ACTION_MUSIC_MANIFEST.json`.

The existing SoLoud music group remains at preference × .25; defaults remain .6 music and .8 SFX. Menu, arena and boss entry/exit triggers, looping, pause/lifecycle behavior, mute/settings and restart cleanup are unchanged. No additional simultaneous music voices or runtime DSP have been introduced. Samples have a .76 peak ceiling and limited upper bandwidth, leaving space for weapon transients and enemy warnings.

## Verification and listening

`tool/preview_action_music.py` validates hashes, format, exact sixteen-bar length, peak/RMS/DC, waveform continuity and energy at both ends. It creates `build/audio-review/action_music_preview.wav` (menu → Breach → Foundry → boss, eight seconds each) and `action_music_gameplay_mix.wav` (the same excerpts with Carbine, Revenants, boss and damage cues at runtime gains). Each excerpt crosses its real loop boundary. Recorded loop jumps are zero after PCM conversion; representative mixed peaks are .705/.692/.714 for the three combat contexts, below clipping. This establishes file/mix integrity, not subjective music quality or every possible overlap.

Review on phone speakers and headphones: menu anticipation, energy on entering combat, fatigue after several loops, boss escalation, and audible attack/damage cues. Check transitions, pause/background/resume and both music/SFX sliders. Physical listening/readability/comfort approval remains open.

Reference ledger: `threejs-audio-generator/SKILL.md` and `references/audio-workflows.md` guided loop preparation, event mapping, group separation and representative mix review. Provider probe output was `ELEVENLABS_API_KEY=MISSING` in both process and sourced shell profiles; no provider request or purchase was made. Original local composition is the production path for this pass.
