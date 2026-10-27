# Leaderboards and public player profiles

Research and implementation proposal · 26 October 2026

**Superseding product decision:** the creator requires all accounts and guests to appear automatically, including existing players. The current global directory has no opt-in, Join/Withdraw, arena or category gate. Historical privacy/enrollment and scoped-board proposals below are superseded by [the current implementation](LEADERBOARD_IMPLEMENTATION.md).

**Recommendation:** add **Leaderboards** directly beneath Online on Home. Open a full-screen score list; tapping a player opens their records, most-played weapons, most-picked upgrades and best-run build. Reuse Regun identity, SpacetimeDB, the existing HTTP gateway and Flutter admin. Deliver solo community records first, with their device-reported provenance made clear. Introduce authoritative competition as a separate board only when its gameplay path is ready.

This document is the planning baseline. The first implementation slice is tracked in [LEADERBOARD_IMPLEMENTATION.md](LEADERBOARD_IMPLEMENTATION.md); it is not a public deployment. The companion [clickable UI concept](design/leaderboard-concept.html) uses invented sample players and scores. Product defaults below are recommendations for review, not previously approved rules. Current source takes precedence over historical roster/build numbers in older plans.

## 1. What exists, and what is missing

Source audit: game `37b4e97`, server `cf0c54d`, admin `df24302`, plus their working trees on this date. Existing unrelated game changes, including `pubspec.yaml` and the Credits proposal, were left intact. No production database or private player records were queried; hosted capabilities and deployment parity still need staging/live verification.

| Surface | Current implementation | Consequence |
|---|---|---|
| Home | `lib/widgets/home_menu.dart`: Play/Continue, Online, Training/Collection/Settings, wallet, footer BEST. `lib/views/menu_view.dart` opens pages. | There is a natural navigation point; don't bury rankings in Collection or replace the approved shelter painting. |
| Solo settlement | `lib/game.dart::settleRun` calls `PlayerProfile.settle`, saves the profile, then clears the checkpoint. Training is excluded. | Capture an immutable run summary at this boundary, durably, before clearing the run. Never make successful local settlement depend on HTTP. |
| Career profile | `lib/models/player_profile.dart`: kills, elite/boss wins, career seconds, unlocks, cosmetic, normal/assisted/continued personal bests and settled run IDs. | Useful personal history, but no general per-weapon use or per-upgrade pick history. A preferred weapon is not a most-used weapon. |
| Continue / recovery | Normal checkpoint restoration and a separate `SoloRecovery.continued` revive classification. `assisted` is latched during a run. | Ordinary save-and-resume must not be confused with revive/second-chance continuation. Persist eligibility flags; toggling an option later cannot clean a run. |
| Device reporting | `lib/services/player_registry.dart`: eight aggregate fields, owner-scoped device secret, monotonic sequence, durable **latest** outbox; POST `/players/v1/report`. | Operational telemetry, explicitly not competitive authority. Its replaceable latest totals cannot transport every run reliably. Leave its v1 contract alone. |
| Identity/cloud | `lib/services/account/*`; server `identity.ts`, `identity_scope.ts`: verified email, username policy, canonical online identity, guest claims, cloud revision/epoch, deletion/reset. | Reuse stable account ownership. Email verification does not verify gameplay scores. Cloud profiles are device-originated too. |
| Online results | Server `settlement.ts`, `settlement_views.ts`, `schema.ts`: private `match_record`, `online_result`, `online_account`; result idempotency; owner-only views. | Good authoritative source boundary. Results explicitly contain `unrated:true`; last 30 results per identity and 2,000 terminal matches globally are retained. Not a durable competitive ledger. |
| Co-op scoring | `survival_runtime.ts::kill/after`: enemy score is awarded to each participating progress record; final-hit kills are individual. | Ranking these as independent solo skill scores would be misleading. Co-op should rank a team run, separated by team size. |
| Content parity | Game `loadout.dart`: 24 weapons, ten survivors, two solo arenas. Hosted `weapon_specs.ts` admits five weapons and three survivors. | Native catalog support is not hosted simulation support. Use capability-based modes/filters, not an assumed shared playable roster. |
| API | Node identity gateway `identity/src/http.ts`, `database.ts`, `admin.ts`, with bounded requests, tokens, rate limits and trusted database bridge. | Extend this gateway; no new Supabase, Firebase leaderboard database, or operator token in apps. Public reads need explicit route dispatch and response allowlists. |
| Admin | `regun-admin/lib/screens/server_screens.dart`: PlayersPanel/PlayerDetailPage. `workbench.dart` has Players navigation. `/admin/users` includes private email/devices/wallet. | Extend Players with competition and record review. **Never** expose its current response as a public profile. |
| Admin trust | `identity/src/admin.ts::session` currently returns owner role; authenticated reducers enforce mutations. | Moderation can initially use existing owner authorization. Additional roles require actual server enforcement, not hidden controls. |

Related context read: AGENTS in all three repositories; `REGUN_PROGRESS.md`, `REGUN_COMPLETE_GAME_PLAN.md`, `PLAYTEST_GUIDE.md`, cloud identity/run progression plans; server/admin implementation status and live-balance contracts; game/admin `.impeccable.md`. Older statements excluding online rankings are historical scope and are superseded by this requested proposal, not silently treated as an existing implementation.

## 2. Research and architectural decision

These are primary documentation sources consulted on 26 October 2026. Recommendations for Regun are our synthesis, not claims that these services must be adopted.

| Research finding | Regun decision | Source |
|---|---|---|
| Best-score, cumulative and latest-value statistics serve different purposes. | Use **maximum eligible run score** for ranking. Use sums for career counters, never a sum of best-score uploads. | [PlayFab player statistics](https://learn.microsoft.com/en-us/xbox/playfab/community/leaderboards/tournaments-leaderboards/using-player-statistics) |
| Ordered secondary columns resolve ties; versioned boards can retain read-only history. | Define an immutable ordering and rules era; archive old competition instead of mixing changing balance. | [PlayFab leaderboard overview](https://learn.microsoft.com/en-us/xbox/playfab/community/leaderboards/) |
| Leaderboard configuration distinguishes ordering, update strategies and scheduled resets. | Model these explicitly; do not hardcode a single global score field as the whole product. Start with few meaningful boards. | [Unity leaderboard configuration](https://docs.unity.com/ugs/manual/leaderboards/manual/configuration/unity-dashboard) |
| Server authority puts important gameplay validation on the server. | Signed uploads, plausibility checks and verified accounts do **not** make local solo simulation authoritative. Preserve separate provenance. | [Unity server authority](https://docs.unity.com/en-us/cloud-code/3.0.0/server-authority) |
| Platform leaderboards support best records, time windows and bounded retrieval; Android's tamper protection has platform limits. | Build cross-platform Regun-owned rankings and profiles first. Game Center/Play Games can become optional mirrors, not fragmented sources of truth. | [Google Play Games leaderboards](https://developer.android.com/games/pgs/leaderboards) |
| SpacetimeDB private tables and views support controlled disclosure; views require indexed access and cannot scan full tables. | Keep raw evidence private; serve sanitized materialized projections through the existing gateway, with indexed data access. | [SpacetimeDB access permissions](https://spacetimedb.com/docs/tables/access-permissions) |
| Reducers have authenticated sender and server context. | Derive actor, time and authoritative settlement on the server. Bind all account mutations to the authenticated principal. | [SpacetimeDB reducer context](https://spacetimedb.com/docs/functions/reducers/reducer-context) |

SpacetimeDB web docs are versioned and may differ from pinned runtime **2.12.0**. Verify index/range/SQL/migration behavior against that runtime in a disposable integration database; do not upgrade SDKs as an incidental leaderboard task.

### Options considered

| Option | Assessment |
|---|---|
| Sort current device/cloud `bestScore` | Fast demo, weak product: forgeable aggregates, no run evidence, loadout or time-window attribution. Reject as the production foundation. |
| Regun-owned per-run community records + moderation | Best first delivery for the actual offline solo game and full content roster. Clear provenance, auditable summaries, public profiles; remains vulnerable to a modified client. **Recommended v1.** |
| Server-simulated competition | Stronger score authority. Reuse online settlement for an explicit co-op competition, or build a dedicated hosted solo mode. Requires separate admission/rules/capacity work. **Recommended later competitive track.** |
| Client replay re-simulated on server | Current Flame/TypeScript physics, timing and supported content are not deterministic equivalents. Too large to claim as a quick verification layer. Research spike only. |
| Platform-only or new managed leaderboard vendor | Adds identity/storage/integration and still needs custom profiles/admin/provenance. Current infrastructure is sufficient; reconsider only after measured operational need. |

If a launch requirement becomes “cheat-resistant ranked solo,” server-simulated solo must precede that launch. Do not silently label the community board verified to meet the deadline.

## 3. Product scope and scoring rules

### First public delivery

- Home entry; browsable **Solo records** list; top 100 with pages of 25; My position/near-me; player profile; best-run details; admin review and removal/restoration.
- Default arena **The Breach**, explicit Foundry selector. Keep arena boards separate because layout/difficulty differs. Default Standard; an explicit Assisted records selector can expose aim-assisted records separately. Revived records remain personal at v1, with no public ranking.
- One best eligible run per account per board. Descending score; equal score prefers earlier **server acceptance** time, then stable public player ID. Use the same comparator for replacement, pagination, position and rebuilds. Equal-score later runs do not replace the earlier record.
- **All-time / current rules** at v1 means “since this rules era began,” not an assertion of comparable scores across every historical balance. Show an era label and keep archived eras selectable once present.
- No prizes, purchasable rank, paid promotion, win rating, friend graph, chat, countries or clans in this release. Do not rank by wallet balance, weapon ownership or money spent.

Browsing should work without signing in. Publishing a record and a public profile requires the existing verified account plus an explicit public-participation choice. That choice is localizable, persistent and retractable; sign-in alone does not publish existing history. Guests retain private local history and can sign in later to submit eligible newly captured records with explicit ownership adoption. No public guest hardware/device identifiers.

### Eligibility contract

An eligible v1 solo record has: instrumentation version supported; normal run, not Training/Boss Rush/debug; immutable owner adopted explicitly; supported catalog/rules era; terminal death/completion; no revive; selected assisted category; accepted complete run summary; public participation enabled; no moderation exclusion. Quit/abandon/crash checkpoints are not terminal scores. Resume preserves the same run ID and classification. Final score is the existing gameplay score—do not invent a parallel scoring formula in the first delivery.

Snapshot score, survival, kills and build **from the same run**. Never attach lifetime `bestSeconds` to an unrelated lifetime `bestScore`. Use active combat time, not wall-clock time; exclude pause/picker/deployment/held cinematics according to existing game clocks. Server-side plausibility recomputation must include versioned score sources (kills, elapsed time, pickups and cycle bonuses); if the summary lacks sufficient evidence, flag it rather than claim exact recomputation.

Numeric balance publication alone must not create dozens of boards. Introduce `competitionRulesId` mapping an approved immutable set of compatible catalog/release/mechanics hashes to an era. Old Continue runs keep their exact pinned rules and enter their compatible era or stay personal. A materially incompatible publication opens a new era; it cannot rewrite scores from an active one. Cosmetic-only releases may share an era.

### Follow-on boards

| Board | Required before enabling |
|---|---|
| This week | Server-issued start ticket with board/rules/account, server start timestamp and nonce. UTC Monday 00:00 boundaries; start within `[start,end)`, finalize within a proposed 24h close grace; late results remain current-era all-time only. Archive finalizes after grace. Ticket does not prove local gameplay. Unticketed/offline-start runs remain all-time community records. UI explains this briefly before participation. |
| Co-op teams | Explicit competition admission, team-size-specific boards, immutable roster/participant contributions and no-forfeit policy. Server completion evidence; no automatic conversion of current private unrated rooms. One team-run row; profile shows participation and individual contribution separately. |
| Ranked solo | Dedicated server-owned one-player survival, supported content contract, performance/cost tests, lifecycle/reconnect design and player acceptance. It must not make regular offline Play network-dependent. |
| Versus rating | Matchmaking, opponent integrity, rematch/farming controls, rating/season design and enough population. Private friend-match win counts remain unrated. |

Accessibility settings such as Reduced Motion, handedness, text size and Haptics never disqualify scores. Aim assist is already a distinct record policy; describe it neutrally. Cloud reset, sign-out or reinstall cannot clear a moderation restriction.

## 4. Home, leaderboard and profile UI

The [concept](design/leaderboard-concept.html) demonstrates navigation with sample data. It is a review artifact, not Flutter implementation or visual/device acceptance.

### Home placement

Place a compact full-width **LEADERBOARDS** plate between Online and the Training/Collection/Settings row. This keeps the label readable without squeezing a fourth text action into the utility row. Retain Play/Continue as primary, wallet at the safe top edge, BEST footer and the existing shelter painting/atmosphere. Reuse the charcoal/plum stepped iron plate, restrained brass and Orbitron body type. Small rank glyph is optional, never the only accessible label.

Normal detail can show `YOUR BEST 12,480` only when its scope is known; otherwise use `TOP RECORDS` or omit. Rank fetch must not gate taps, focus, semantics, Play or Continue. Never show an optimistic fake rank, spinner overlay or live-updating marquee. Use current page routing (`GamePageRoute`), not an unrelated router rewrite. Compact landscape and large text use the existing scroll/reflow path; reduce spacing before shrinking type or hit targets.

### Score list

1. Header: Back, **Leaderboards**, secondary My profile.
2. Short selector row: **Solo records**; arena; Standard/Assisted. Once available, All-time/This week uses a second compact row. Keep advanced filters in a panel on small screens.
3. Small context: `Community records · Current rules`. Info explains once: `Scores reported by players. Reviewed for unusual results.` Authoritative boards instead state `Server-run records`.
4. A readable ranked list. Each row shows rank, survivor portrait, username, score; second line weapon, survival time. Top three get restrained brass numerals rather than a large podium pushing everyone else off screen. Full row is tappable.
5. A bottom **You** strip shows exact rank and score, or `Finish a run to place`, `Sign in to post a score`, `Record pending review`, or `Outside top 100 · View nearby`. Do not fabricate an exact rank beyond a computed snapshot. Account-specific status is private.
6. Refresh/Load more has stable focus and scroll position. Back from a player restores filters, snapshot, scroll and selected row. New results do not reorder the list under a finger; offer Refresh instead.

On wide screens use list/detail beside each other when space permits; phones navigate list → profile → run. Landscape layout uses horizontal space rather than hiding filters. No auto-playing survivor animations or combat textures for a static row; reuse small existing portraits/weapon thumbnails with safe asset leases.

After a run, add a secondary **View leaderboard** action without delaying Restart/Home. Show `Queued to post`, `Under review` or an acknowledged position as appropriate; a local personal best is not confirmation of a public rank. If the run is personal-only, keep its normal result screen and offer the concise eligibility reason on request.

### Player profile

Top: username, equipped/record survivor art, **Records / Weapons / Upgrades** tabs. Overview shows best eligible score, longest eligible survival, runs, enemy kills and boss victories for the selected source/mode/era. A clearly separated career panel can show broader personal-reported history if shared; never blend it into verified competition totals.

**Weapons:** most played (default order: active equipped seconds, tie by runs, then stable ID), runs used, kills credited, best score with that weapon. Optional `Unlocked 12 / 24` and owned list require an explicit share preference and a known unlock source. Purchased availability is not mastery. Unsupported hosted weapons can still have solo records. `Preferred` is not used as historical evidence.

**Upgrades:** most picked by **runs selected**, not rank-VIII weight. Show accepted rank purchases as a separate number; e.g. `Heavy Load · 12 runs · 39 picks`. Include fusions and supply support in separate groups; do not present support tier as a family rank. These are pick statistics, not actual proc-activation counts.

**Best run:** same-run score/time/arena/survivor, weapon usage, final upgrade ranks/fusions/support, rules label and provenance. Power-up glyphs open concise descriptions from the correct retained catalog. Record snapshots do not change when a player equips a different loadout later.

Do not publish email, account UUID/canonical principal, device IDs, last-seen/device times, wallet, purchase receipts, sign-in method, checkpoints, room code or moderation notes. Profile URLs use a random public ID independent of auth identifiers. Username changes update public display and invalidate affected caches without changing rank/identity.

### Required UI states and accessibility

| State | Behavior / brief copy |
|---|---|
| First load | Stable row placeholders, Back enabled; no blocking home overlay. |
| Empty | `No records yet. Set the first score.` Optional Play action. |
| Offline, cached | `Saved results · Updated …`; cached browsing works, publication waits. |
| Offline, no cache | `Connect to load records.` Retry, Back, Play remain available. |
| Failed refresh | Retain last successful rows and show Retry. A failure is not an empty board. |
| Hidden/deleted player | `Player unavailable.` No leaked reason; back restores list. |
| Outdated/unsupported rules | `This run stays in your personal records.` Do not force-update offline Play. |
| Unknown historical usage | `Weapon tracking started …` / `Not recorded`; never replace unknown with zero. |
| Stats private | Records remain visible for published entries; optional detailed tabs say `Stats are private`. Full withdrawal removes both entry and profile. |

At least 48px interactive targets, text scaling without clipped score/name/filter controls, keyboard/controller focus, screen-reader row label (`Rank 4, RookFan, 12,480 points…`), tabular/aligned score digits, adequate measured contrast, noncolor selected/you markers. Long usernames truncate only in lists with full semantics/detail text. Respect Reduced Motion and do not keep the animated shelter painting mounted invisibly behind an opaque detail page. Treat phone landscape as the primary acceptance target: iPhone 12 at 844 × 390 logical pixels, compact landscape phones, tablet and desktop, safe insets and 1.5×/2× text. Do not rotate the game into portrait for leaderboard navigation.

## 5. Stats definitions and instrumentation

Introduce a typed `RunStatistics` accumulator owned by the run, not widget rebuilds. Snapshot it in the checkpoint; serialize a bounded immutable `RunSummary` at settlement. Use stable item IDs and explicit stat/catalog versions. Preserve unknown historical IDs in evidence; display a safe fallback for retired items.

| Metric | Definition / capture boundary |
|---|---|
| Runs played / completed | Count each terminal eligible run once. Starts/abandonments may be separate private telemetry, never silently included in completed-run denominators. |
| Weapon runs | One count per distinct weapon actually equipped for positive active combat time in a run, not each equip event. |
| Weapon time | Active seconds equipped; if switching exists, split time by equipped weapon. Sum matches run combat time within defined rounding tolerance. Pause/picker/entrance do not add time. |
| Weapon kills | One kill owner/source at death; primary/weapon-owned effects retain weapon provenance after a switch. Grenades, sentry, mines and upgrade effects have explicit source categories; don't credit whatever is currently equipped. |
| Damage | Optional later: accepted HP removed after mitigation, bounded by remaining HP, by source. Do not infer accuracy or damage from score. |
| Upgrade runs | A family counted once if an ordinary confirmed pick was accepted in that run. Deduplicate its accepted receipt/offer ID. |
| Upgrade picks | Increment per accepted rank selection, including explicit accepted timeout choice on server. No increment for rendering, reroll, ban, stale/rejected choice or checkpoint restore. |
| Final rank / highest rank | Snapshot versus max observed rank, distinct from number of picks and effective scalar rank. Recipe preparation or historical rank map alone cannot reconstruct pick history. |
| Fusion / support | Accepted fusion recipe once; support ID/tier receipt separately. Do not inflate ingredient pick counts when a fusion consumes/prepares ranks. |
| Boss victories | Count actual rewarded boss deaths by actor/type once; retain repeated same-type wins. Do not derive count from a set of unique boss names. |
| Most used | Weapon = equipped combat time; power-up = runs selected. Display these definitions briefly in detail. |

Candidate hooks: native `GameNotifier.applyPowerUp`, fusion/support confirmation, `RegunGame.settleRun`, weapon/effect death provenance, active clock/equip transitions; server `progression.ts::choose`, `survival_runtime.ts` and `settlement.ts::snapshotParticipant/settleMatch`. Count at the accepted mechanics boundary shared by automatic/manual choices, not cosmetic presentation callbacks. Update native/TypeScript fixtures together.

Summary includes `schema`, `runId`, owner binding, run lifecycle, `source`, active duration, score components and final score, arena/survivor, weapon usage, final build and accepted-choice counters, boss counters, aim-assist/revive/training/debug flags, pinned balance hash/catalog/mechanics versions, client build, tracking completeness and terminal reason. Cloud epoch is an ownership/replay guard, not the run identity or gameplay verification.

Older checkpoints are still playable. If they lack tracking, initialize partial coverage and mark it; don't count a preexisting build as newly picked upgrades. Such runs can stay personal until the board's required instrumentation is met. Do not backfill guessed favorite weapons from preferences, weapon ownership, challenges or fusion sets.

## 6. Data model and authority

Additive private tables, with indexed fields for actual query/rebuild patterns. Names are proposed contracts; exact SDK types/index syntax are a phase-0 spike.

| Table | Purpose / important keys |
|---|---|
| `public_player` | account-keyed owner mapping, random unique public ID, display metadata, participation and optional-stat visibility versions. No email/device data in projection. |
| `competition_rules` / `leaderboard_definition` | Immutable rules/compatibility set, source, mode, arena/category, ordering version, time window, status and close grace. Reviewed publication pointer separate from draft. |
| `run_record` | Immutable evidence keyed by globally stable source/run ID plus participant identity. Index account and board/time. Store hash, server receipt time, source, flags and evidence completeness. |
| `run_publication` | Mutable eligibility/review state, revision, reason code and private review linkage. Raw score evidence is never edited to fix a rank. |
| `player_mode_stats` | Rebuildable counts by account/source/mode/era; projection generation and tracking start. Avoid a single mixed-trust career total. |
| `player_item_stats` | Per weapon/family/fusion/support counters with explicit metric version; indexed account/scope/item keys. |
| `leaderboard_best` | Best accepted candidate per board/account with run pointer and comparator fields. Retain nonbest evidence for fallback after removal. |
| `leaderboard_snapshot` / `leaderboard_row` | Published generation, freshness, exact rank/count, sanitized rows, top pages and near-me lookup. Build bounded pages, atomically switch generation. |
| `leaderboard_moderation` | Append-only actor/action/reason/request ID/expected revision, evidence references, before/after state. |
| `competition_ticket` | Follow-on weekly/hosted admission: bound account/board/rules/nonce/expiry/status; single-use terminal binding. |

Keep authoritative online and reported solo evidence separated even if they share summary shape. A gateway signature proves ingestion from that gateway, not the truth of a phone's combat.

### Submission and aggregation transaction

1. Local gameplay settles and persists profile, summary and pending publication intent safely; a crash between writes is recoverable via a local settlement journal. Training never queues a publication.
2. Dedicated per-run outbox retries independently of gameplay. Capture owner before enqueue; no background reassignment to whoever signs in later. Set a visible bounded capacity (proposal: 100 pending summaries/5MiB); retain local bests and surface queue-full status instead of silently dropping every unposted best. Never reuse the latest-only PlayerRegistry outbox.
3. Gateway verifies session and enrollment, strict versioned schema, payload/rate limits and ownership. Server derives account/time/board/rules compatibility, validates flags and score plausibility. Client-supplied board labels, timestamps and eligibility booleans are not trusted authority.
4. One reducer transaction inserts unique evidence, applies eligible aggregate deltas once, updates best candidates and marks projection work. Same run ID and same body returns prior receipt. Same ID/different hash rejects. Idempotency survives sign-out, device retry, guest adoption, epoch changes and result-history pruning.
5. Projection rebuild publishes a complete generation; reads never see half-ranked data. If classification changes, rebuild/reverse contributions from evidence, including best-run fallbacks, not only delete one visible row.
6. Client records receipt state `accepted | pending_review | personal_only | rejected` plus a safe reason. Accepted does not imply server-simulated. Retry failures preserve intent; leaderboard outages do not block rewards or run clearing after durable local save.

Authenticate owner and reconcile an existing run/body hash **before** applying new-submission epoch, rules or enrollment checks. A previously accepted request with a lost response must return its old receipt after a reset/season change, without counting again or republishing withdrawn data. Only a genuinely new submission must satisfy current admission. Durable replay keys cannot be pruned with the current online result UI history.

Implement bounded processing outside combat ticks. Do not scan all profiles on every read or all run history in every settlement. Start with batched private-table range iteration and materialized page snapshots; establish tested row/time limits in phase 0. If 2.12 index/range constraints cannot meet them, add an external derived read index through an idempotent outbox, retaining SpacetimeDB evidence as authority. Redis is an optional later cache, not a phase-one dependency.

### Identity, privacy and lifecycle

- Local guest adoption requires explicit flow and one durable ownership assignment. Server online guest claim must also migrate new run attribution without duplicate entries/counters. Public participation still requires an account.
- Switching account, sign-out or epoch reset cancels in-flight UI application using generation/owner guards. It does not relabel queued runs. Anonymous cache is public-only; private queue/My-position status is owner-scoped.
- **Progress reset** resets existing personal progress, not immutable competitive history or anti-abuse decisions. Offer a separate withdraw-public-records action. State that distinction before reset; old epochs cannot submit stale new records.
- **Account deletion** removes public rows, profile/detail caches, item aggregates, owner evidence as policy requires and references in retained online result/match JSON. Existing identity cleanup only removes some result tables; new linked evidence and embedded participant identity need an explicit erasure/redaction sweep. Leave only nonidentifying audit/tombstone data needed for idempotency/abuse under an approved retention policy.
- **Withdraw participation** hides public projection immediately, invalidates caches and prevents new publication; re-enrollment must not republish past runs without a clear choice. Optional detail privacy never exposes raw private career data.
- **Rename** keeps identity/rank stable; same username policy and moderation apply everywhere. Never resolve public profiles by mutable username alone.

## 7. API contract

Use a dedicated `LeaderboardService` behind the existing Node gateway instead of adding more public behavior to the already broad AdminService. Existing `/players/v1/report`, admin responses and account contracts remain compatible. Add HTTP dispatch, CORS/proxy support, generated client DTOs and capability discovery together.

| Method / proposed path | Access and response |
|---|---|
| GET `/leaderboards/v1/config` | Public. Enabled boards, capabilities, current rules, filters, metric definitions, participation policy version. Unsupported source filters stay absent. |
| GET `/leaderboards/v1/boards/{boardId}/entries?limit=25&cursor=…` | Public sanitized rows, `generation`, `asOf`, `nextCursor`, exact participant count where computed. Maximum limit 50; public top-100 browse cap at v1. |
| GET `/leaderboards/v1/boards/{boardId}/me` | Authenticated, no-store. Owner status and exact position plus nearby rows from same generation; use it even outside top 100. |
| GET `/players/v1/public/{publicId}?scope=…` | Public allowlisted profile, visibility state and coverage. Bounded item arrays; details can have own cursor. Never reuse `/admin/users/{id}`. |
| GET `/players/v1/public/{publicId}/runs/{runId}` | Only that player's published eligible run detail, sanitized build/summary. Random IDs are not authorization. |
| POST `/leaderboards/v1/participation` | Verified account. Explicit enrollment/withdrawal and optional-detail settings, expected revision/policy version, idempotency key. |
| POST `/leaderboards/v1/runs` | Verified account, idempotent reported solo submission; no client route capable of creating server-authoritative results. |
| GET `/leaderboards/v1/submissions/{runId}` | Authenticated owner-only receipt reconciliation after a lost response. |
| POST `/leaderboards/v1/tickets` | Phase 2 weekly admission; account/rules/source checks, rate limits, server dates. |
| GET `/admin/leaderboards/*` | Existing owner auth; board health, entries/evidence, review queue, audit and dry-run rebuilds. |
| POST `/admin/leaderboards/*` | Owner auth and reducer authorization; expected revision plus operation ID; exclude/restore, eligibility suspension, archive/publish controls. No arbitrary score editing. |

Numbers that may exceed JavaScript safe precision (database IDs, timestamps, future big counters) use documented decimal strings; ranks/short bounded scores can use validated integers. Return stable error codes with brief localized client copy. Enforce content-length and nested collection/string/count limits, finite numeric checks, known IDs by pinned catalog, body hash consistency and owner binding in both gateway and reducer.

Use signed/versioned opaque cursors bound to board, filter and generation. Expired snapshot returns `snapshot_expired` so the client offers refresh; no duplicated/skipped entries from live offset pagination. Cache only public sanitized responses, with ETag and short initial TTL (proposal 30s); `/me`, receipts and admin remain private/no-store. Privacy/deletion/moderation must check a current visibility fence before serving cached records; purge affected pages/profiles promptly. Do not let a CDN retain deleted names until an unbounded stale TTL expires.

Do not rely solely on process-local rate-limit maps for a public endpoint. Add trusted proxy IP handling and shared/edge limits; enforce account/run admission limits in database too. No secrets in telemetry or error bodies. Return only approved rule/version/source metadata, never raw operator SQL or private match JSON.

## 8. Admin experience and operations

Keep the existing Players destination. Add a secondary **Leaderboards** workspace reachable from Workspace options and a competition section in each player detail. On desktop use board list + entries + evidence detail; on phone drill down with existing 48px controls and readable body typography. Use `ItemArtwork` for real weapon/upgrade identities.

Operators need:

- Board status/rules/source/era/season and preview of exactly what the public sees; distinguish draft, disabled, collecting, live, closing and archived.
- Review queue with source, received time, score/time, catalog/build, anomaly reason, duplicate evidence and related runs. Public-account verification and score-source status must be visually distinct.
- **Exclude record**, **restore record**, **suspend publication**, and **restore publication**, each with reason, confirmation of scope, expected revision and idempotent request ID. Keep raw evidence unchanged; show which next-best run will replace an excluded record.
- Inspect per-item counters/coverage, replay-safe aggregation status and snapshot freshness. Read-only legacy cloud/device stats remain labeled as such.
- Dry-run rebuild with old/new entry counts and best changes; publish only after integrity checks. No destructive “reset all scores” button or editing a score to a chosen number.
- Audit trail with operator/session, time, reason and before/after revisions. Initial permissions use existing owner auth; supporting distinct moderator/publisher roles is a later explicit backend feature.
- Kill switches for reads and submissions independently; a paused board does not disable offline Play, cloud backup or existing rewards.

No automatic permanent ban based on a theoretical score-per-second threshold. Balance changes and unusual builds produce legitimate outliers. Hard-invalid payloads reject; suspicious plausible runs quarantine for review. Client attestation may become an extra signal, never a substitute for gameplay authority.

## 9. Delivery plan and repository map

Each phase is a reviewable delivery; keep feature flags off until its end-to-end gate passes. Durations are deliberately not promised before the runtime/query and instrumentation spikes.

| Phase | Work and concrete output | Exit gate |
|---|---|---|
| 0 — contracts and feasibility | Review defaults, run source/flags/schema/metric definitions; validate 2.12 indexed ranking/snapshot strategy in disposable DB; inspect current hosted capabilities; clickable UI review; define public participation and deletion policy. | Approved contract fixtures, measured query spike, source/eligibility matrix and UI placement. No production mutation. |
| 1 — trustworthy recording | Typed native accumulator, checkpoint compatibility, kill-source attribution, accepted pick counters, immutable summary, local settlement journal and dedicated owner-bound outbox. Matching hosted summary hooks. | Crash/retry/Continue/guest/account isolation tests; no changed damage/scoring/reload/reward timing; unknown historical tracking shown honestly. |
| 2 — backend and admin foundation | Add tables/reducers, strict submission, idempotent projections, public DTOs, privacy/erasure, moderation/rebuild, snapshot pages/near-me and capability config. | Forged authoritative source rejected; duplicate runs count once; exclude/delete fallback correct; measured load and auth isolation. |
| 3 — game UI and solo beta | Home action, full list/profile/run views, enrollment/My profile, cache/empty/error/pending states, actual portraits/icons; admin mobile review tools. | Cross-repo integration and rendered UI/accessibility tests; creator phone placement/readability review; source label understood. |
| 4 — controlled public launch | Staging rehearsal on persistent data, additive migration and restore rehearsal, deploy server/API/admin first, capability-gated client rollout, opt-in solo community boards. | Operational monitoring, review coverage, deletion latency and rollback drills; no legacy bests auto-ranked. |
| 5 — timed/authoritative expansion | Weekly ticketed records; separately approved co-op competition with team-size boards; optional hosted solo spike. | Rules/season boundaries tested, no private-match farming, capacity/WAN/physical gameplay acceptance for new modes. |

Suggested file boundaries (new files are proposals, existing files are integration points):

| Repository | Changes |
|---|---|
| `regun/lib/models` | `run_statistics.dart`, `run_summary.dart`, `leaderboard.dart`, `public_player.dart`; checkpoint optional data validation; keep recoverable local profile separate from public DTOs. |
| `regun/lib/systems` | `run_statistics_recorder.dart`; source attribution adapter shared across primary/secondary/effects. |
| `regun/lib/services` | `leaderboards/leaderboard_api.dart`, repository/cache/controller; `run_submission_store.dart` with journal/outbox; account-generation integration. |
| `regun/lib/game.dart`, notifier, weapons/enemies | Initialize/advance/snapshot/finalize recording at current mechanics boundaries; never add HTTP to Flame update. |
| `regun/lib/views`, widgets | `leaderboard_view.dart`, `player_profile_view.dart`, `run_record_view.dart`, reusable row/coverage/build widgets; HomeMenu and MenuView entry. |
| `regun-server/spacetimedb/src` | Add schema tables, `leaderboards.ts`, `run_statistics.ts`, projection/moderation modules; integrate settlement/progression/identity deletion/claim. Keep schema exports/bindings consistent. |
| `regun-server/identity/src` | `leaderboards.ts` service/DTO validation, HTTP dispatch, bounded DB access, public cache and rate limits; extend admin authenticated API. |
| `regun-server/deploy`, tests | Proxy routes, independent flags, smoke scenarios, backup/migration/runbook, load tests. |
| `regun-admin/lib` | Typed leaderboard API/models; Players competition section; leaderboard/review/evidence screens; current auth/session/revision patterns and art. |

## 10. Acceptance and test matrix

| Area | Required evidence |
|---|---|
| Ranking | Best-overwrite semantics, exact ties, stable page/near-me ordering, nonbest exclusion, best exclusion→next best, restore, new generation, archived immutable board, simultaneous results. |
| Stats | Weapon switch/time split, delayed effect attribution, overkill/death once, grenade/sentry separation; rank picks vs runs picked; fusion/support distinction; no restore/reroll/ban duplication. |
| Durability | Kill during settlement/journal writes, lost POST response, duplicate/new-body retry, full queue, offline days, reinstall limits, storage failure and checkpoint repair. Local rewards remain once-only. |
| Identity | Guest adoption once, account switch during request, cross-account receipt read, invalid/revoked token, epoch reset, rename, withdrawal/re-enrollment and deletion including embedded match evidence. |
| Trust | Huge/NaN/negative/nested payloads, client-supplied authoritative label, forged time/catalog/category, old run/ticket replay, unsupported content, direct reducer abuse and admin calls without owner permission. |
| Privacy | Snapshot/profile/run DTO allowlist tests ensure no email/principal/device/wallet/room data; cached reads after withdrawal/deletion fail closed. |
| Rules/time | Continue with old pinned balance, compatible cosmetic publication, incompatible new era, UTC rollover/grace, unticketed offline run, unsupported old client. |
| Online | Shared team score vs individual kills; 1/2/3-player admission policy, departures/forfeits, rematch/reconnect once; old 30/2000 retention cannot erase new dedupe ledger. |
| UI | Top-list→player→best-run→back preservation; 24-weapon/retired art, large scores/names, partial/unknown stats, offline cache, empty/error/stale, pending review; 320/390/landscape/tablet/desktop, large text/semantics/Reduced Motion. |
| Operational | Additive migration on populated disposable data, backup/restore, projection rebuild hashes, stale-worker recovery, rules rollback and flag rollback, load under simultaneous combat and leaderboard traffic. |

Provisional performance targets to measure, not results: cached top-page API p95 <300ms, uncached profile/near-me p95 <750ms, accepted result visible within 30s under expected traffic, bounded summary <=32KiB, no per-frame network/JSON work, no unexplained combat-tick regression. Spike with 10k then 100k synthetic accounts and realistic run/item cardinality; agree expected concurrent readers/submissions before sizing production. Huge histories are processed in resumable batches, not one long reducer transaction.

Run game/admin `make verify`, server root/module/identity verification as applicable, dedicated API compiled-process smoke and disposable real SpacetimeDB transport tests. Existing clean suites do not establish leaderboard correctness. Physical phone checks must cover tap placement, long text, slow/offline navigation, heat/memory and screen-reader comfort; simulated/headless performance is not physical-device evidence.

## 11. Rollout, retention and recovery

1. Back up the existing persistent volume and rehearse restore. Add tables and strict contracts without deleting data or altering old balance snapshots.
2. Deploy API/module with all public leaderboard flags disabled; verify schema migration, private access and old client compatibility. Deploy admin and complete moderator workflow in staging.
3. Release instrumented clients; collect opt-in shadow submissions and compare local summaries against server receipts/projections. Historical device totals remain personal/operational.
4. Enable read-only beta to a test cohort, then opt-in submissions. Monitor pending/rejected proportions, outbox age, duplicates, ingest/projection lag, cache age, moderation backlog and combat tick latency. Logs use run/public references, never secrets or full player payloads.
5. Enable broadly only after actual privacy/moderation/rebuild/UI acceptance. Keep independent read/submit switches. API/schema changes deploy before clients; missing capability gives a local error/disabled remote feature without blocking Play.
6. Rollback disables publication, preserves journals/accepted evidence and returns a clear temporary-unavailable state; do not roll back to code that destroys new schema or replay guards. Continue storing compatible records until fixed or freeze writes deliberately.

Proposed retention for policy review: current best and supporting summary while published; other run evidence 90 days; flagged/moderation evidence 180 days; compact nonidentifying replay tombstones longer than any allowed submission retry. Item aggregates retain `trackingSince` and source; label totals “since tracking began.” If summaries expire, rebuild only from a validated aggregate checkpoint plus retained event tail, with deletion/reversal support; never promise a full lifetime rebuild from 90 days of evidence. Archive export/restore and retention job tests are launch requirements. Final durations, erasure exceptions and any policy copy need owner review before shipping.

## 12. Decisions for the implementation kickoff

Recommended defaults make phase 0 actionable without inventing existing approval:

1. Launch **solo community records**, with honest source labeling, all-time current-era arena-separated Standard/Assisted boards; keep revived records personal. Stronger ranked solo is a separate hosted project.
2. Keep the literal **Leaderboards** Home label and list→player→run flow in the concept. Include weapons/upgrades at launch; don't postpone them into a profile-shaped empty screen.
3. Publish only after verified account plus public opt-in. Show record-relevant build by default; optional career/unlock stats have explicit sharing controls.
4. No money/prizes tied to ranks; defer weekly/co-op competition until their time/authority/admission contracts pass.

**First engineering milestone:** one real solo run, safely recorded offline, submitted once after reconnect, visible in a staged board, opening a correctly attributed weapon/upgrade profile, then excluded/restored through the admin with ranks and stats rebuilt correctly. That demonstrates the whole foundation before expanding boards.

## Artifact verification for this planning pass

The concept was opened in the browser and the Home → score list → player → Weapons/Upgrades flow was exercised. Existing local artwork/fonts resolve; no remote assets or live player data are used. Review captures: [Home](design/leaderboard-home.png), [score list](design/leaderboard-list.png), [upgrade stats](design/leaderboard-player-upgrades.png). These show the browser concept at its preview viewport, not completed Flutter screens or a passed responsive/physical-device gate. No gameplay/API/admin production code was changed, so game test suites were not rerun for this documentation-only delivery.

Landscape correction: Regun is a landscape game. The earlier portrait phone mockups were an incorrect primary presentation and are superseded by **844 × 390 logical-pixel iPhone 12 landscape** captures: [Home](design/leaderboard-iphone12-landscape-home.png), [score list](design/leaderboard-iphone12-landscape-list.png). Reserve 48 logical pixels at both side edges for notch/safe-area clearance and a bottom home-indicator margin. Home keeps navigation left and shelter artwork right. The leaderboard scrolls its rows while navigation, filters and the You strip remain visible. The profile was also visually inspected at 844 × 390: it uses a compact identity column and independently scrolling detail content. A saved landscape profile capture is still outstanding. All game leaderboard screens must preserve landscape; do not rotate players into portrait. These are browser concept captures, not native iPhone/Safari or physical touch/comfort validation.
