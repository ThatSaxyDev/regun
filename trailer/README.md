# Regun cinematic teaser

36-second, 1920 × 1080, 30 fps asset-based trailer. All artwork, typography,
music and effects come from this game's existing assets. Sprite compositions
are staged promotional animation, not captured gameplay. No store availability,
release date or unreleased feature is advertised.

## Rebuild

Requires Node 22+, Python with Pillow, and dependencies installed via `npm ci`.
From the repository root:

```sh
python3 trailer/scripts/prepare_assets.py
cd trailer
npm ci
npx remotion render RegunTrailer out/regun-trailer-1080p.mp4 --codec=h264 --crf=18 --pixel-format=yuv420p
```

`npm run dev` opens the editable timeline. Generated assets, dependencies and
renders are ignored. Source artwork and runtime code are never modified.

## Cut

| Time | Scene |
| --- | --- |
| 0–6 s | Rook's shelter: The world fell. You're still here. |
| 6–12 s | Ten survivors |
| 12–19 s | 21 weapons; four featured guns |
| 19–25 s | 41 upgrades and build combinations |
| 25–31 s | Eight-boss lineup |
| 31–36 s | Regun / One more round |

Music: `music_menu.wav`, then `music_boss.wav`. Effects: shotgun, rail lance,
upgrade recovery pulse and ordnance blast, with trailer-specific volume envelopes.
Original game audio provenance remains in `art/source/audio/README.md` and
`docs/art/ACTION_MUSIC_REVIEW.md`.

Fonts: existing Orbitron and Press Start 2P. Atlas crops use the existing manifest
rectangles. Backgrounds: home_hideout_v2, breach_floor, foundry_floor. No new AI
image/audio assets or external footage were generated.
