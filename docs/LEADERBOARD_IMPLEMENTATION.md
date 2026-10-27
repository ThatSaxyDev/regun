# Leaderboards and player profiles

26 October 2026. Implemented across the game, sibling `regun-server` and sibling `regun-admin`. The creator's final direction is **automatic inclusion of all accounts and guests**, including existing players. No Join/Withdraw or sign-in prompt gates the public list. No server deployment was performed from this workspace.

## Current behavior

- Home → Leaderboards opens the score-ranked player list. Every undeleted account and every unlinked guest device appears, including players with no completed runs. Active players show “Playing”; tapping any row opens Records / Weapons / Upgrades.
- Existing cloud profiles and device reports supply existing scores, survival, run counts, kills and boss victories. New settled runs accumulate persistent weapon use, upgrade picks, fusions and support choices for guests and accounts. Older unrecorded weapon/upgrade history stays empty rather than being invented from the currently equipped kit.
- Guest names match the existing `Guest-xxxxxxxx` names. Linking a guest removes its separate public row; account cloud adoption remains governed by existing account synchronization. Cumulative totals are replacements, never summed across device reports. Fresh device stats replace cloud stats only at the matching progress epoch.
- Public UUIDs are HMAC-derived using the existing identity secret. Responses allowlist gameplay fields; emails, raw account/device IDs, device secrets, wallet and private profile contents are not public. Own-row lookup authenticates the account token or guest device secret.
- Foreground clients send a presence report every 30 seconds; backgrounding marks them inactive and a 90-second server lease handles disconnects. “Playing” means the app is active, including menus. Earlier clients still appear from their existing reports but lack precise background signaling.
- Public directory reads use three bulk private-table queries, with score sorting and 25-row pages (maximum 50). This includes players beyond the old detailed-receipt beta. These operations have not been load-tested at public scale; an indexed directory projection is the next scaling step.
- Landscape iPhone layout uses the existing pixel/brass/charcoal UI and artwork. No explanatory tracking banners. Records show actual scores and counts; Weapons sort by played seconds, Upgrades by runs selected. A best-run build appears only when its captured summary matches the player's displayed best score.
- Admin player details expose weapon/upgrade usage for guests and accounts. The separate account-only detailed run-evidence review retains exclude/restore with reason and revision checks. That moderation affects scoped run-evidence boards, **not the automatic career directory totals**.

## Detailed run evidence

New normal runs capture accepted picks, final ranks, fusions, support, weapon, active seconds, score, kills and bosses. Checkpoints preserve coverage and ownership; stale/rejected choices never add picks. UUID summaries and receipts live in the same owner-scoped profile commit as rewards. Retry acknowledgements are durable. Local career usage continues even when the receipt journal is full. Training does not settle profile rewards or public usage.

The separate signed-in run-evidence path automatically enrolls its internal account projection. Guest, revived and incomplete summaries are not posted to that legacy scoped receipt path; their career totals still appear in the automatic directory. Private evidence remains device-originated, not server-verified competition. Receipts have strict validation, idempotency, account/epoch ownership, pinned numeric rules and abuse review. Exclusion promotes the next scoped eligible run; account rename/deletion updates its projections.

Detailed evidence retains its beta limits: 1,000 internal participants, 500 receipts/account, and 100 local pending summaries. These limits do not hide players from the automatic directory. Before broader competitive release, implement indexed projections/load tests, authoritative gameplay scoring and stronger abuse review. Do not describe client-reported career totals as verified scores.

## Deployment

Deploy the additive module, identity gateway and nginx routes together, then admin/client. Existing persistent data must be retained. No new database, secret or mandatory flag is required; the identity gateway reuses its existing hash secret for stable public IDs.

- `REGUN_LEADERBOARDS_ENABLED` defaults true. Explicit false disables public leaderboard reads.
- `REGUN_LEADERBOARDS_SUBMISSIONS` defaults true. Explicit false pauses new detailed run receipts. Automatic career reports and directory stats still work.

No production deployment was performed. Existing players are read from existing account/cloud/device rows as soon as the updated gateway is deployed; new clients supply richer usage and presence. Account deletion hides the account and its linked devices. Offline gameplay remains available.

## Verification

Game analyzer and focused landscape, outbox, usage and registry checks; full game suite; admin analyzer/tests; server module and identity typecheck/tests/build; compiled HTTP smoke. The real-database detailed-receipt smoke uses a disposable loopback server, without modifying production.

Actual Flutter renders use 844×390 logical pixels with iPhone safe insets, including 1.5×/2× text. Test responses are invented fixtures. Installation and automated tests are not physical gameplay performance proof. See [validation evidence](validation/leaderboards-2026-10-26/README.md).

## Return visits (26 October)

The service keeps an in-memory public-list snapshot and at most32 public profiles. Returning to either screen paints the cached result immediately and refreshes without a loading indicator. First visits still load normally; a failed background refresh keeps the cached content. Explicit refresh errors remain visible. Disabled leaderboards clear the public cache;404 profiles are evicted. Viewer-specific own-row/auth state is not cached. App restart starts fresh. Numeric displays now use comma grouping.

## Player record presentation and history repair (26 October)

The player name/portrait now own a compact header. Records/Weapons/Upgrades use selected tabs, aligned career rows and a separate best-run build in landscape; enlarged text stacks the sections. Weapon rows reuse leased gameplay thumbnails, upgrade rows use their existing glyphs, and best-run support/fusions retain their real identities. No explanatory tracking banner is added. Empty breakdowns say “No weapon history” / “No upgrade history,” rather than implying the player owns or uses none.

Read-only live public checks found15 directory entries; the first two had25/69 settled runs and5,008/14,965 kills, yet both returned empty weapon/upgrade maps and no captured build. These observations establish missing breakdowns, not zero weapon use. No private account data was queried or changed.

Previously `RunStatistics.complete == false` caused `PlayerUsage.record` to discard the entire usage summary, including the known weapon and choices accepted after continuing an older checkpoint. Completeness still gates the separate run-evidence submission path, but no longer discards known career facts. Profile `publicUsage.coverage:2` marks the once-only recovery of incomplete settled journal summaries; already-counted complete runs are preserved. Only actual saved summaries and accepted counters are used. Unknown older history is not inferred from kills, currently equipped weapons, owned items or final upgrade ranks.

The identity gateway applies equivalent recovery while projecting existing cloud profiles. It requires matching settled IDs and validated summaries, skips complete summaries already represented by existing counters, and preserves valid usage when an optional best-build snapshot is invalid. The gateway change requires server deployment; the client repair handles new settlements and local profile migration. No database migration or new flag is required.
