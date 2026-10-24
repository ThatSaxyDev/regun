# Propulsion and electrical weapon audio

24 October 2026. `tool/generate_frontier_audio.py` rebuilds only Houndrack/Storm Orb
launches and orb dissipation, plus four new flight/zap/pass cues. Full
`generate_expansion_audio.py` calls it last, so a full regeneration preserves this
revision. Existing CC0 cannon/pump/rifle recordings are layered with original
deterministic filtered propulsion air, low pressure and restrained electrical
synthesis. No new external recording/provider/voice is introduced. Attribution
and original source hashes remain in `art/source/audio/README.md`.

| Cue | Seconds | Native SFX gain | Limit |
|---|---|---|---|
| Houndrack launch variants | .28 | .62 | Actual weapon cadence |
| Rocket shared flight | .18 | .12 | 220ms |
| Storm Orb launch variants | .34 | .60 | Actual weapon cadence |
| Orb shared flight | .28 | .15 | 320ms |
| Successful arc | .12 | .28 | 120ms |
| Body crossing | .20 | .34 | 120ms |

Flight sound is a bounded shared one-shot stream; adding more rockets/orbs does
not add a continuous voice for each projectile. New events are prewarmed through
SoLoud and respect existing volume/mute. No firing/collision timing depends on
sound playback.

`python3 tool/preview_frontier_audio.py` checks 11 cues for PCM16 mono 44100Hz,
peak/DC/endpoints and hashes, then creates an 18-rocket plus passing/zapping orb
stress/listening mix. At native per-event gains and 0.8 SFX volume, its peak is
0.4240. `preview_expansion_audio.py` verifies 148 expansion cues and loops; its
existing review mix peak remains 0.6483. Metrics are copied with validation proof.
These numeric checks do not substitute for native listening/comfort review.

[Listen to the rocket/orb mix](../validation/weapon-feedback-2026-10-24/frontier-feedback.wav).
