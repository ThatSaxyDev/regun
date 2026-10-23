# Menu space synth and combat score

On 23 October 2026 the creator selected `regun-space-synth-score.mp3` for the menu before gameplay. `assets/audio/music_menu.mp3` is a byte-for-byte copy of `trailer/out/regun-space-synth-score.mp3`, preserving its stereo mix, authored opening/ending fades and full 44 seconds. The three action combat tracks retain their existing files and mix/trigger contracts.

| Context / file | Tempo | Arrangement | Length |
| --- | --- | --- | --- |
| `assets/audio/music_menu.mp3` | — | Regun — One More Run (Space Synth), approved stereo score | 44.00s |
| `assets/audio/music_breach.wav` | 138 BPM | Syncopated low-string ostinato, bass pulse, breakbeat pressure | 27.83s |
| `assets/audio/music_foundry.wav` | 146 BPM | Grinding power dyads, floor toms, heavier machinery rhythm | 26.30s |
| `assets/audio/music_boss.wav` | 156 BPM | Double-time pursuit, staggered accents, minor-second tension in the final build | 24.62s |

The three combat tracks are original deterministic instrumental compositions with no external samples, licensed melody, vocals or generation service. `tool/generate_action_music.py` owns their sixteen-bar arrangements. Combat starts with a full rhythm; tails wrap around the loop with a two-millisecond seam correction. The menu is the original melodic space-synth trailer composition authored by `trailer/scripts/generate_synth_score.py`; use the creator-selected MP3 as supplied, including its designed cues and fades. Regenerating combat music preserves the selected menu asset and manifest entry. The previous menu WAV is removed from packaged assets.

Regenerate with a Python environment containing NumPy and `ffmpeg` on PATH:

```
python3 tool/generate_action_music.py
python3 tool/preview_action_music.py
```

`tool/generate_audio.py` now leaves all music alone, preventing accidental restoration of the older score when regenerating legacy effects. Combat remains mono PCM16/44.1kHz WAV. The menu uses the supplied stereo 48kHz MP3 directly through the same SoLoud playback path; no re-encoding or extra runtime voice is introduced. Full track metadata, seeds and hashes are in `ACTION_MUSIC_MANIFEST.json`.

The existing SoLoud music group remains at preference × .25; defaults remain .6 music and .8 SFX. Menu, arena and boss entry/exit triggers, looping, pause/lifecycle behavior, mute/settings and restart cleanup are unchanged. No additional simultaneous music voices or runtime DSP have been introduced. Combat samples have a .76 peak ceiling and limited upper bandwidth, leaving space for weapon transients and enemy warnings.

## Verification and listening

`tool/preview_action_music.py` validates hashes, sixteen-bar combat lengths, the 44-second menu length, peak/RMS/DC and loop boundary continuity. Combat also checks immediate entrance/end energy; the approved menu retains its authored fades. MP3 preview measurements/reels use a mono 44.1kHz downmix, while the game plays the untouched stereo source. It creates `build/audio-review/action_music_preview.wav` (menu → Breach → Foundry → boss, eight seconds each) and `action_music_gameplay_mix.wav` (the same excerpts with Carbine, Revenants, boss and damage cues at runtime gains). Each excerpt crosses its real loop boundary. Recorded loop jumps are zero after PCM conversion; representative mixed peaks are .705/.692/.714 for the three combat contexts, below clipping. This establishes file/mix integrity, not subjective music quality or every possible overlap.

Review on phone speakers and headphones: menu anticipation, energy on entering combat, fatigue after several loops, boss escalation, and audible attack/damage cues. Check transitions, pause/background/resume and both music/SFX sliders. Physical listening/readability/comfort approval remains open.

Reference ledger: `threejs-audio-generator/SKILL.md` and `references/audio-workflows.md` guided loop preparation, event mapping, group separation and representative mix review. Provider probe output was `ELEVENLABS_API_KEY=MISSING` in both process and sourced shell profiles; no provider request or purchase was made. Original local composition is the production path for this pass.
