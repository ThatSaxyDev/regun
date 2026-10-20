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

## Reload correction — 20 October 2026

The former reloads combined high-pass noise and 760/1480/2600Hz ringing modes in essentially the same cue. Those synthetic contacts are replaced across all eleven reload assets by short extracts of CC0 recorded mechanisms. Source attribution/hashes are in `art/source/audio/README.md`; exact trims, pitch, tempo, filtering, peaks and durations live in `tool/generate_reload_audio.py`. Shotgun shell handling is softer, its final pump has two tangible action contacts, and the Carbine uses separate magazine removal, seating and bolt cues. Revolver and Arc use distinct contact extracts/casing treatments. These are processed recordings, not new ElevenLabs output. Both credential probes printed `ELEVENLABS_API_KEY=MISSING`.

Reference ledger: `threejs-audio-generator/SKILL.md` and `references/audio-workflows.md` informed asset preparation, event mapping and mix verification; Firecrawl search found the original CC0 sources. Flutter's existing SoLoud manager remains authoritative. No runtime audio package, firing/impact asset, music or UI sound changed.

| Family | Cues | Duration | Peak before runtime gain | Runtime SFX gain |
|---|---:|---|---|---|
| Shotgun | shell / pump | .20 / .26s | .38 / .60 | .32 |
| Carbine | out / seat / bolt | .25 / .23 / .25s | .46 / .50 / .56 | .32 |
| Revolver | open / load / close | .20 / .23 / .25s | .44 / .46 / .54 | .32 |
| Arc | release / insert / latch | .28 / .25 / .30s | .44 / .46 / .54 | .32 |

All one-shots are mono PCM16/44.1kHz. The reload group is reduced from .42 to .32 before the saved SFX preference; shot/impact gains stay unchanged. Shell count/timing, event phases, cancellation, pause/mute behavior, total reload duration and the original shotgun Lottie are preserved.

`python3 tool/preview_reload_audio.py` checks all eleven reload formats, clean endpoints, DC, peaks and upper-band energy (a 3kHz high-pass proxy). It writes `build/audio-review/reload_audio.csv` and a fourteen-second `reload_mix.wav` at production gain/.8 SFX volume, with all four weapons at their real base reload schedule. If the previous cues are in `build/audio-review/reload-before/`, it also writes `reload_before_after.wav`: old Shotgun/Carbine in seconds 0–7, replacements in seconds 7–14. No normalization is applied to either mix. New reload mix peak .1536; upper-band ratios range .021–.155, within the .20 guard. `preview_combat_audio.py` still verifies the 35 existing firing/impact/boss cues and its unchanged representative mix peak .707. These measurements do not establish perceived sound quality; listen on phone/headphones during actual reloads.
