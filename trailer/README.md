# Regun cinematic teaser

44-second, 1920 × 1080, 30 fps asset-based trailer. All artwork, typography,
music and effects come from this game's existing assets. Sprite showcases are staged promotional animation. A six-second sequence uses
the actual beta gameplay excerpt from the landing page. The closing card invites
players to the iOS/Android beta through https://regun.kiishi.space/.

## Rebuild

Requires Node 22+, Python with Pillow, and dependencies installed via `npm ci`.
From the repository root:

```sh
cd trailer
npm ci
npm run assets
npx remotion render RegunTrailer out/regun-trailer-1080p.mp4 --codec=h264 --crf=18 --pixel-format=yuv420p
```

`npm run dev` opens the editable timeline. Generated assets, dependencies and
renders are ignored. Source artwork and runtime code are never modified.

## Cut

| Time | Scene |
| --- | --- |
| 0–6 s | Rook's shelter: The world fell. You're still here. |
| 6–12 s | Ten survivors |
| 12–19 s | 21 weapons; four featured guns with synchronized grid highlights |
| 19–25 s | 41 upgrades and build combinations |
| 25–31 s | Actual beta gameplay in the landing page frame |
| 31–37 s | Eight-boss lineup |
| 37–44 s | One more run / Join the beta / platform panels / website QR |

Music: one continuous upbeat `music_boss.wav` loop throughout, with only opening
and closing fades. Effects: shotgun, rail lance,
upgrade recovery pulse and ordnance blast, with trailer-specific volume envelopes.
Original game audio provenance remains in `art/source/audio/README.md` and
`docs/art/ACTION_MUSIC_REVIEW.md`.

Fonts: existing Orbitron and Press Start 2P. Atlas crops use the existing manifest
rectangles. Backgrounds: home_hideout_v2, breach_floor, foundry_floor. No new AI
image/audio assets or external footage were generated.

Beta layout and copy come from the sibling `regun-landing-page/dist/index.html`
and `styles.css`: square beta indicator, One more run, brass TestFlight panel,
outlined Android panel, and the evolving-beta note. `scripts/prepare_beta.mjs`
copies its existing gameplay excerpt and SVG platform marks, reads the canonical
URL and generates the QR code. It leaves the landing page untouched. The page
returned HTTP 200 on 22 October 2026.

Gameplay provenance: creator recording `ScreenRecording_10-20-2026 11-06-27_1.MP4`,
landing-page excerpt 00:54–01:12; this cut uses seconds 4–10 of that excerpt.
The recorded gameplay is silent; the continuous game score remains underneath.
