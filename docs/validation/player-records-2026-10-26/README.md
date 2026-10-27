# Player records — 26 October 2026

Actual Flutter fixture renders,844×390 logical pixels with iPhone safe insets: [Records](records.png), [Weapons](weapons.png), [Upgrades](upgrades.png). Data is invented test data. Compact identity, selected tabs, career/best-run sections, actual weapon thumbnails and existing upgrade glyphs replace the former sparse layout. Enlarged text stacks sections; each content area scrolls. Names and numeric values remain accessible. Cached results still refresh silently.

Read-only public API review observed15 directory entries; the first two had25/69 runs and5,008/14,965 kills but empty weapon/upgrade maps and no best-build history. No private data was queried. Empty UI now describes missing history rather than no equipment. Missing historical choices are never inferred from aggregate totals.

Known weapon/time/picks from incomplete continued-run summaries now settle into career usage. A once-only coverage marker recovers such existing summaries without re-counting complete ones. API projection applies equivalent bounded recovery from valid settled journal rows and retains valid counters when an optional best build is malformed. New native capture remains compatible with the existing API. Gateway recovery requires deployment; no database change or new flag. No production deployment was performed.

Analyzer clean. Full game run:799 passed/five skips/one known randomized training-pressure threshold failure. That unrelated test now pins the same spawn seed already used by adjacent coverage, retaining its assertions; the final22-test focused run (training, record layout/cache, usage migration, outbox and real scene settlement) passed. API38 tests, typecheck/build and compiled HTTP smoke passed. Tests prove capture/recovery/layout contracts, not physical-device comfort.

The regular1.0.0+26 release was signed, installed over the network and launched on the paired iPhone. Existing game data was retained. This confirms installation, not hands-on visual/data/audio acceptance.
