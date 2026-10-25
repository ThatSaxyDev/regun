# Mummy presentation and Aura Salad correction — 25 October 2026

The mummy could remain on an arbitrary walking frame when body occupancy stopped its feet. Tiny collision corrections also changed its horizontal mirror repeatedly. Co-op held the wind-up frame throughout its melee phase instead of showing the actual strike.

## Mummy behavior

- Distance still drives walking frames. A quarter-second progress sample below three world units selects the existing alert sprite, with a restrained 1.8-second torso compression and planted feet. Reduced Motion keeps that stance steady.
- Living mummies face the player even while stationary or attacking. A 12-unit horizontal dead band and 150ms confirmation prevent collision jitter and near-vertical targets from rapidly mirroring the art. Legacy online snapshots without target intent use confirmed horizontal travel.
- Native and co-op strike poses now follow the existing damage attempt, showing the release for 140ms. The server sends optional target-facing and strike-age receipts. Old snapshots retain a phase-based fallback. Repeated network snapshots cannot advance presentation clocks.
- Movement, body occupancy, attack reach, cover checks, damage, and 600ms attack cadence are unchanged. Crowded mummies still respect other bodies; this correction does not allow them to attack through the crowd.

## Reproduction evidence

A deterministic 40-second Training simulation placed 24 mummies and 12 scorpions around a stationary protected survivor. In the final ten seconds, 17 mummies had zero travel. Before this fix the worst mummy mirrored 310 times; the same scene now records zero mirror changes. Travel is identical. Blocked mummies select their alert stance, while a separate close-range control continues to show both melee poses with protected health unchanged.

Regression coverage includes actual native actors, blocked facing after the player changes sides, real rendered co-op alert/strike frames, snapshot time freezing, Reduced Motion, and the full crowd reproduction. Ignored diagnostic evidence and the preview animation are under `build/diagnostics/` and `build/test-previews/mummy-alert.gif`.

## Aura Salad compatibility

The current name is **Aura Salad** in game rewards, Training practice, the admin art/catalogue, shared generated contracts, and API preview titles. Internal `aura` family IDs, `support:aura:*` reward IDs, and `support.aura.*` tuning keys remain stable. Existing enable switches, weights, saves and checkpoints therefore retain their identity.

The display-name change produces a new catalogue hash. The exact previous catalogue is retained for pinned snapshots and revision history; its historical labels and hashes must not be rewritten. Admin migration tests retain the enabled flag, custom weight, candidate history and original backup. Game tests restore a valid old-catalogue snapshot with its original hash and reward ID. No published tuning or enable flags were changed by this rename.

## Validation

- Game analyzer: clean. Full gameplay suite: 748 passed, five optional skips. Final display-name migration and focused presentation/support checks: 27 passed.
- Server: 176 tests passed and Spacetime module built.
- Identity/API: 23 tests and compiled smoke test passed.
- Admin: 61 tests passed, including old-draft migration and Aura Salad toggle wiring; web release built.
- Game release builds: Android APK, web and unsigned iOS app passed.
- Native visual comfort and real multiplayer presentation still require hands-on review. Automated rendering and crowd simulation are not physical-device acceptance.
