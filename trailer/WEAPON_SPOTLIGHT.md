# Weapon spotlight — creator gameplay cut

34.8 seconds, 1920×1080, 60 fps. Four creator-selected recordings play in full,
normal speed, without source trims, looping or reframing the gameplay. Orientation
is normalized and the full image is contained inside a bordered display.

| Time | Segment |
| --- | --- |
| 0–3.00s | Fully visible thumbnail/title, staggered art seating and supporting copy |
| 3.00–7.48s | Full Arc Caster recording, 09-41-35 |
| 7.48–13.05s | Full Rail Lance recording, 09-42-16 |
| 13.05–19.83s | Full Frost Shotgun recording, 09-43-32 |
| 19.83–27.80s | Full Rivet Driver recording, 09-44-13 |
| 27.80–34.80s | Animated beta invitation, platform panels and stable QR |

Text reveals through clipped baselines; weapon art slides into its display
position; mechanic rules extend under the labels; a moving outline travels to
the corresponding weapon in the 21-item grid. Playback progresses beneath each
recording. The original low-level gameplay audio sits beneath the synth score.
No base magazine stats are advertised alongside upgraded gameplay.

`src/weapon-recordings.ts` records exact source durations, hashes and editorial
mapping. `scripts/prepare_weapon_recordings.py` converts all four full clips to
landscape 60fps H264 without changing speed. Sequence lengths round upward to the
nearest output frame, so a short hold of at most one frame can follow a clip.
The original files remain untouched.

```sh
python3 trailer/scripts/prepare_weapon_recordings.py
cd trailer
npm run lint
npx remotion render WeaponSpotlight out/regun-weapon-spotlight-gameplay-1080p.mp4 --codec=h264 --crf=18 --pixel-format=yuv420p
npx remotion still WeaponSpotlight out/weapon-spotlight-thumbnail.jpg --frame=0
```

`RegunTrailer` remains the separate 44-second trailer; both compositions open on
visible artwork/text. The earlier asset-only spotlight exports are retained.
