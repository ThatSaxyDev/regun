# Weapon and combat feedback candidate — 19 October 2026

## Scope and authorization

The creator reported weak weapon identity, insufficient impact feedback from both sides, and poor firing sounds. They explicitly requested normalising the shotgun reload to the other weapons' presentation. This supersedes the previous requirement to keep its Lottie active. The original Lottie remains in the project as source/reference; it is no longer the runtime reload HUD.

This pass changes presentation, audio and muzzle placement. Weapon damage, cadence, magazines, projectile speed/range values, boss health, enemy health and difficulty rules were not buffed. Shotgun shell timing remains `900 + 700 × (missing shells − 1)` ms, with existing shell cue times and an added final pump sound 180 ms before completion.

## What changed

| Weapon | Firing identity | Reload identity | Sound direction |
|---|---|---|---|
| Pump Shotgun | Broad amber muzzle burst, strong short kick, compact pellet trails, spreading impact sparks | Shell insertions and closing pump, shared world/HUD renderer | Short pressure blast with a low body; shell contacts and pump mechanism |
| Carbine | Smaller fast muzzle crack, short recovery, slim tracers, tight impacts | Magazine travel and return | Dry short crack, bolt detail, small mechanical reload contacts |
| Revolver | Longer pointed flash, strongest kick and slower visual recovery, long tracer and heavy impact stroke | Cylinder opens, rotates and returns | Heavier report and longer decaying tail |
| Arc Caster | Pale green electrical muzzle fork, jagged energy projectile and electrical impact | Vent/core lift and recharge | Crackling discharge rather than a ballistic report |

Gun bodies are more legible at gameplay scale. Projectiles now originate at their displayed barrel position, rather than a universal 30-unit offset. Cosmetic recoil does not change aim, fire cadence or projectile direction. Ammo/reload HUDs identify the equipped weapon. Existing chain/fusion mechanics remain authoritative; electrical visuals do not introduce a hitscan beam.

Targets briefly flash at impact, with softer tinting under Reduced Motion. Boss bodies are included, not just ordinary enemies. Player health loss produces a brief body flash and edge brackets, without a camera shake or fullscreen opaque flash. Guard absorption has a different sound and does not trigger the red health-loss cue. Feedback resets on Restart.

Weapon impacts use bounded, fixed stroke bursts inside the existing 40-effect budget, with at most eight new primary-hit bursts per update. No per-spark component emitters were added. Boss ground impacts get a larger expanding/cracked stroke effect at activation, and boss melee impacts use that heavier language. Poison is visually distinct. Old duplicate generic gun-hit audio was removed from the primary damage path.

## Audio source and provider report

The `threejs-audio-generator` skill's SFX workflow is engine-independent; its browser playback examples were not used in Flutter. References read: skill `SKILL.md` and `references/audio-workflows.md` (planning, variation, mixing, integration and verification).

Both the normal credential probe and shell-profile fallback returned:

```text
ELEVENLABS_API_KEY=MISSING
```

No ElevenLabs generation was performed, no paid API call was made, and no externally generated or licensed sample pack is claimed. The fallback is an original, deterministic local synthesis kit produced by `tool/generate_weapon_audio.py`. It combines filtered noise transients, pressure/body layers, damped mechanical modes and short tails. It has no third-party recordings or voices. These are candidate sounds requiring listening approval, not studio-recorded weapon Foley.

### Asset/event matrix

All filenames are under `assets/audio/`. Exact durations, peaks, RMS, models and seeds are in [WEAPON_AUDIO_MANIFEST.csv](WEAPON_AUDIO_MANIFEST.csv).

| Event | Files | Count | Trigger |
|---|---|---:|---|
| Weapon fire | `shot_{shotgun,carbine,revolver,arcCaster}_{0,1,2}.wav` | 12 | Three deterministic variations per gun, rotating on successful shots |
| Weapon impact | `impact_{shotgun,carbine,revolver,arcCaster}.wav` | 4 | Successful primary projectile hit, throttled |
| Non-shotgun reload | `reload_{carbine,revolver,arcCaster}_{0,1,2}.wav` | 9 | Reload start, 42% and 82% of its clock |
| Shotgun reload | `reload_shotgun_shell.wav`, `reload_shotgun_pump.wav` | 2 | Shell cues; closing pump |
| Heavy/poison impact | `impact_boss.wav`, `impact_poison.wav` | 2 | Boss melee or ground attack activation |
| Player/guard hit | `hurt_player.wav`, `impact_guard.wav` | 2 | Accepted player-health damage or guard absorption; fatal damage retains the existing death cue |

Total: **31 mono PCM16 WAV files at 44.1 kHz**, approximately 755 KB. They are non-looping; no TTS, voice ID, ambience or music replacement is involved. The script writes weapon/impact files only. Existing music and UI sounds are untouched.

SoLoud remains the playback path. Equipped weapon sounds are warmed on game mount, shared loads are cached, impact events are throttled at 65 ms per asset, and shot/reload/impact levels have separate mix gains under the existing Sound control. Mute remains respected. No added audio loop can stack on restart; these are finite one-shots. Existing sounds are not retroactively stopped midway by a pause, but simulation-owned firing/reload/impact events stop advancing while paused.

## Verification and remaining review

- Targeted native-scene tests verify each weapon's projectile identity, firing/impact sound event, ammo consumption, successful hit, brief target flash and cleanup, player damage cue, and Restart reset.
- Existing reload tests retain the normal timing assertions and now check shell plus final pump cues.
- Generated WAVs were decoded/checked for valid format, non-silence, peak headroom and near-zero DC. No sound exceeds full scale; total asset bytes are recorded above.
- Inspected the rendered firing/reload comparison in `build/test-previews/weapon-identity.png`.
- Automated checks do not establish whether the new sound set is pleasant on an iPhone speaker, convincing as real weapon Foley, or comfortable during dense fights. That needs listening and playtesting.
- Existing generated weapon art still contains baked mechanical details; the moving parts are a visual approximation, not a fully separated production animation pack. Body/hand animation quality is not claimed fixed by this pass.
- Native frame times, final mix loudness, low-end Android audio, Bluetooth interruptions and final combat balance remain device acceptance work.

## Phone review

In Training, try each gun against the same enemies. Compare single shots and sustained fire, then full and partial reloads. Test near a boss so warning readability competes with effects. Repeat with Sound off, Reduced Motion on, and during a crowded fight. Confirm damage is readable without hiding the next threat. On a normal run, compare losing a heart with guard absorption and a fatal hit. Listen for overly sharp clicks, repetitive firing, muddy tails, reload cues arriving late, or impacts drowning out the gun.

Final candidate checks: analyzer clean, **79 tests pass**, four opt-in checks skipped; native iOS release builds. Evidence logs: `docs/validation/weapon-feedback-*`.
