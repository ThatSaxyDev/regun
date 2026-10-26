## Timing revision after creator feedback

The creator rejected the 420ms timing as too fast. Current review default is
**1.1 seconds** on first acquisition, **800ms** on later ranks, with a 750ms short
comparison and unchanged 180ms static Reduced Motion. Frame dwell is authored:
88ms ready, 110ms anticipation, 154ms open, 154ms receive, 220ms absorption crest,
154ms containment, 132ms grounded stance, 88ms settle. Native and co-op share the
pose mapping; the server owns the matching bounded 1.1s/800ms hold. Nothing in
combat advances during the longer cosmetic sequence.

Watch **heavy-load-breach-1100ms.mp4**, captured at actual playback speed, with
0.8s lead-in. The older clips below retain the rejected fast timing for comparison.
The playable review launcher now labels the full option **1100ms**. Five focused
mobile tests, four server confirmation tests and analyzer pass after this timing
change. Physical review and visual approval remain pending.

---

# Heavy Load infusion correction — creator review candidate

This replaces the rejected equipment-fitting direction with a power-absorption
performance: immediate world hold, converging stepped currents, authored body
anticipation/absorption/containment/settle, then normal active resume and the
existing recovery pulse. No camera movement or full-screen flash.

**Watch `heavy-load-breach.mp4` at normal speed.** Foundry and Reduced Motion
versions are included. The Breach/Foundry clips contain 0.8 seconds of live lead-in,
420ms confirmation and subsequent live combat, with labels hidden. These are
844×390 Flame-canvas captures at a 30fps capture cadence, muted, without Flutter
picker/HUD overlays. They are not physical-phone recordings or frame-rate evidence.
Reduced Motion keeps the body settled with static chest seams during its existing
180ms hold; no traveling current, body reaction or focus shading.

The first pass was inspected at phone scale and its incoming power strengthened
before these captures. This remains a **candidate**, not creator visual acceptance.
Only Heavy Load is presented here for direction approval. The shared 32-pose Rook
absorption packet (8 frames × 4 facings) replaces the previous shared fitting packet
in the opt-in six-family exploration. Different family performances, survivor
coverage and final family variants are not complete. The previous six-family
visual evidence is superseded; its mechanical audit remains historical evidence.

Production still defaults to the original flow pending the review gate. Play the
updated separate review build at http://127.0.0.1:8766 : Breach / 420ms → Pause →
Upgrade feel review → Heavy Load → accept its card. Watch the character, not stats.

Source and built-in imagegen prompt/hash: `art/source/upgrades/infusion_generation.json`.
Immutable master: `art/source/upgrades/rook_infusion_master.png`.
Import: `python3 tool/import_upgrade_art.py`. Existing fitting master is retained
as rejected-direction history, not loaded by the new candidate.

No numeric balance, API/admin catalogue, server timing, admission or recovery
behavior changed in this correction. Existing world/input/pause/save hold plumbing
is retained. Automated checks cover correctness, not approval of the performance.

Reproduce primary clips:

```sh
REGUN_UPGRADE_INFUSION=1 REGUN_UPGRADE_CLIPS=1 flutter test --no-pub --dart-define=REGUN_UPGRADE_HIDE_LABELS=true test/upgrade_feel_prototype_test.dart
```

Checks: analyzer clean; eight focused tests passed (runtime held-clock/restore,
controller/online watermark, art lease and decoded-art budget), plus two alternative
runtime tests covering short/Reduced Motion and hold safety. Web release build
passed. Decoded peak 29,277,056 bytes, under 32MiB; this is not device performance.
