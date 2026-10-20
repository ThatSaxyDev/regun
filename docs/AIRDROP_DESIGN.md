# Breach supply drops — release 1.0.0+7

The four permanent Breach pillars and their collision rectangles are removed from the Tiled source. The four decorative Breach grates are removed too. Foundry's six solid structures and vent anchors are unchanged.

Supply drops replace the static cluster with one optional moving objective over time. There is one live pod at most, rather than four predetermined locations. The first warning appears after 22–32 active seconds; after a pod disappears, the next arrives 55–80 seconds later. Position candidates are inside the current visible walkable area, at least 260 units from the player and 350 from the previous drop; invalid placement retries after three seconds. A committed landing location never tracks the player.

## Timeline and capture

- A 1.8s planted warning marks the small central landing pad. A .65s accelerating descent follows (a stationary fade with Reduced Motion).
- Impact plays the loudest new cue and kicks out arena-graded dust/grit sprites. A 62-unit crush radius plus each enemy's authoritative body radius determines overlap. Every ordinary role, including Shield Warden and Brood Nest, dies through its normal reward/death path. A boss receives base damage of 3% of maximum health, subject to its existing vulnerability rules. The player does not receive direct pod-impact damage. The larger capture field does not crush enemies.
- The **220-unit capture radius** was enlarged from the initial 145 after the creator's visual feedback. This gives room to dodge within the field. A stepped brass floor stencil and restrained interior fill brighten while the player is inside.
- Eight active seconds inside fill the segmented meter. Leaving pauses capture; the pod's 45s usable lifetime keeps ticking. The label, meter and expiry countdown remain readable; an edge tag helps find a drop after retreating offscreen. There is no button to collect it.
- Completion opens one AIRDROP upgrade choice using the existing unique/rank/bans/reroll rules. It consumes no XP and advances neither level nor the XP requirement. Prompt grace prevents an immediate follow-up screen; if another offer is busy, the completed objective waits while it remains inside its lifetime. No additional reward can come from that pod.
- A claimed pod stays open for three active seconds after the picker closes. An unclaimed pod times out after 45 seconds. Both separate into settling shell panels and fade through a 1.3s dusty breakdown, leaving no permanent debris or collision. Reduced Motion fades the whole pod in place.

Pause, upgrade choices, background suspension and the player's entrance/recovery freeze the objective clock. Checkpoints store scheduling RNG, countdown, planted position, phase, capture, expiry and claimed state. Restoring never reapplies an already completed landing or reward. Old checkpoints without supply data start with the normal first-drop delay. Invalid supply state participates in checkpoint validation/fallback.

Breach Training includes **Pause → Supply Practice → Call airdrop**. It exits Boss Rush/practice bosses and begins a fresh warning without waiting for the timer. Training still awards no normal profile progress. Boss Rush itself has no supply drops.

## Presentation and resource contracts

The original generated closed/open pod uses the existing weathered iron/olive/brass prop atlas as reference. The dedicated four-frame landing-dust atlas is monochrome-graded to stone ambient; it has no generic explosion sprite or glowing attack ring. Floor field/dust/shadow draw below actors; the pod uses ground depth. The overlay uses the game's stepped charcoal/brass plates and PressStart2P/Orbitron fonts. The circular perimeter is explicitly requested objective UI, separate from hostile attack graphics.

Assets: `assets/art/arenas/supply_pod.png` (two frames, 384px decode width), `assets/art/effects/landing_dust.png` (four frames, 256px decode width). Both use acquire/release leases only while needed; loading gates anticipation, and restart/disposal during pending decoding releases the lease safely. Boss Rush cancels the objective and releases its art. The base shared atlas footprint stays 29.80 MiB and existing 32 MiB boss-art checks pass. Effects use two world render components and one viewport locator, no unbounded particle objects or new hazards.

`tool/generate_supply_audio.py` creates 12 mono PCM16/44.1kHz WAVs: incoming, landing, claim, breakdown and eight short low servo/pressure charge steps. Landing layers the existing CC0 cannon pressure and shotgun mechanism with a low body; the softer charge cue rises only from 155 to 246Hz. No continuous audio handle can leak when leaving the field, pausing or disposing. SoLoud prewarms the cues; gains are .8 landing, .16 charge and .4 other supply cues, all under the user's SFX preference. Regenerate in a NumPy environment with ffmpeg; source licenses remain in `art/source/audio/README.md`. `docs/art/SUPPLY_AUDIO_MANIFEST.json` records durations/levels. The 48-asset combat validator and representative mixed reel pass at .745 peak.

Skills/reference ledger: animation and frontend-design informed planted anticipation, impact/breakdown choreography, Reduced Motion and the existing `.impeccable.md` context. The built-in image generation skill produced the two new atlases; manifest rectangles were measured from their alpha without editing the generated bitmap. The audio workflow guidance informed existing CC0 source reuse, bounded transient levels and group mixing. No provider key, paid audio request or external music download was used.

## Verification

Model regressions cover schedule, warning/descent/impact, interrupted capture, claimed/unclaimed disappearance, exactly-once reward/impact, invalid state and restore. Native-scene regressions cover all eight ordinary roles, a boss, nearby non-crushed actors, capture/picker persistence, pause/restart/Rush, pending art cancellation and rendered stages. Wall-specific weapon regressions now use Foundry because Breach intentionally has no columns. The creator still needs to review physical sound weight, visibility, motion comfort and risk/reward on the phone; simulations/installations do not prove native performance or subjective balance.
