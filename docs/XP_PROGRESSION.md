# XP progression and upgrade interruptions — 20 October 2026

The creator rejected the tiny early requirements and ordinary upgrade screens appearing without the XP bar funding another level. This revision belongs to the 1.0.0+12 candidate alongside eight-rank upgrades and the magazine-refill correction.

## Research and Regun's curve

The [Vampire Survivors community wiki](https://vampire.survivors.wiki/w/Level_up) documents substantial additive per-level XP increments, with higher increments in later level bands. The [Brotato community wiki](https://brotato.wiki.spellsandguns.com/Experience) documents a squared per-level cost, distinct from cumulative lifetime XP. These are community references, not a universal balance prescription. Neither supports judging progression by a percentage alone while ignoring kill rewards and upgrade frequency.

Regun previously started at 7 XP and multiplied the next requirement by 1.2. Its enemies award 1–4 XP normally, 6–12 for elite roles, and 15–25 for bosses, so several early upgrades could require only a few kills. The new authored per-level cost is `25 + 25n + 5n(n−1)/2`, where `n = currentLevel−1`. Costs have increasingly large steps rather than the old tiny opening increments.

| Current run level | XP for next level |
|---|---:|
| 1 | 25 |
| 2 | 50 |
| 3 | 80 |
| 4 | 115 |
| 5 | 155 |
| 6 | 200 |
| 10 | 430 |
| 20 | 1355 |
| 30 | 2780 |

These are individual level costs. Upgrade-family rank I–VIII remains a separate choice when the run earns a level. Killing enemies still awards the same XP; raising all XP values alongside the costs would defeat the pacing change.

## One ordinary choice per earned level

The second screen had two sources: XP overflow could reopen the picker immediately after selection, and boss cores rolled ordinary upgrade cards even without enough XP. Ordinary choices now require funded XP. Choosing/fusing never automatically opens another screen. Earned overflow stays in the bar, with four active seconds of prompt protection; another XP pickup after that window can fund the next level. Waiting or pausing cannot create another choice by itself. Old checkpoints preserve XP-bar progress once when migrating to the new curve.

Boss cores now bank for an explicit **Fuse core** action in the HUD/pause menu when III/II ingredients are ready. That screen contains fusion recipes, not fallback ordinary upgrades. At most two cores are needed for the two fusion slots; surplus boss-core rewards become five scrap without an interruption. Training Fusion Practice still prepares and opens its selected recipe directly.

## Acceptance

Tests cover the cost sequence, exact first threshold, one offer/payment, preserved overflow, stale taps, pause, no automatic boss upgrades, explicit fusion and once-only old-save migration. The rank-VIII soaks check lifecycle/population bounds; their artificially prepared builds cannot establish how quickly a normal player reaches VIII. Physical review must measure first/second upgrade times, level at each boss and run-end level on both arenas. The new curve is deliberately much steeper; final difficulty and progression feel remain creator approval items.
