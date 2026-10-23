# Regun: earned run progression and visible wallets

23 October 2026. **Research-backed implementation proposal, not implemented behavior.** Covers the Flutter game, sibling `regun-server` and sibling `regun-admin`. Incorporates the creator's requirement for a well-margined top-right Home display of Scrap and the second currency, repeated where relevant. No production configuration, economy, balances or gameplay are changed by this document.

**Re-audited against all three working trees on 23 October 2026.** The status below distinguishes existing implementation and focused local verification from proposed work and historical deployment reports. This revision supersedes the initial audit in this plan.

## 1. Decision and scope

Combat strength during a run comes from playing: collecting XP, choosing upgrades, earning boss cores, creating fusions and completing tactical objectives. Buying something cannot improve offer odds, starting upgrades, rerolls, bans, fusion capacity, grenade inventory or access to controls/Training. A player who buys cosmetics and a player who buys nothing get the same progression rules for the same mode, loadout and gameplay release.

Paid solo continues remain an explicitly allowed future exception under the creator's direction. This pass reserves their integration boundary; it does not sell them or let a continue inject new upgrades, rerolls or charges. A future continue resumes the existing build and pinned rules, with separately designed recovery/record rules. Co-op teammate rescue is a different mechanic.

Deliver two coordinated foundations:

1. **An earned run-progression contract**, consistently executed by native solo and supported online modes and safely configurable through admin publication.
2. **A visible wallet contract**, showing real banked Scrap and the second currency without confusing either with run XP, cores or unbanked run earnings.

Career unlock redesign, permanent stat trees, cosmetic production, checkout, revive prices, subscriptions and a season pass are separate milestones. They must consume these foundations rather than alter them implicitly.

## 2. Research and what it actually supports

| Primary evidence | Design implication | Limit |
|---|---|---|
| Brotato's developer-authored Steam listing describes short runs, diverse builds, materials that provide experience and between-wave purchases. [R1] | Distinguish resources by purpose and make the run's decisions legible. | Regun is continuous manual-aim combat; importing a between-wave shop would change its identity. |
| 20 Minutes Till Dawn's official listing describes experience-funded build choices, over 50 upgrades and boss-earned Tomes. [R2] | Regular build decisions and separately earned boss milestones are strong genre references. | Neither its upgrade count nor advertised session length establishes Regun's correct XP curve. |
| Deep Rock Galactic: Survivor's official listing centers collecting, upgrading and assembling weapons while surviving. [R3] | Progress should be felt in the active run, with meaningful build direction. | Its auto-firing/mining loop differs from Regun's aim/reload/dash loop. |
| Unity's economy design guidance distinguishes resources, their sources and their sinks. [R4] | Specify where each resource enters, leaves and persists before adding monetization. | General vendor guidance, not proof of player preference or a numeric balance prescription. |
| Firebase's remote configuration guidance separates fetching from activation, offers next-startup activation and recommends bundled defaults. [R5] | Download in the background; activate only at a defined run boundary. | Architectural reference only. Keep Regun's existing delivery service; do not add Firebase. |
| SpacetimeDB documents transactional reducers, authenticated context and reproducible context RNG. [R6–R7] | The server creates offers and accepts choices atomically; clients submit intent. | Check the installed 2.12.0 API while implementing. Latest online docs are not proof that every newer API is available locally. |
| Apple recommends showing total purchase prices and supporting understandable purchasing flows. Google recommends backend purchase verification. [R8–R9] | Wallet UI must expose real state; future paid grants belong in a verified ledger. | This plan does not implement billing or resolve every regional storefront rule. |

These sources support the structure, resource separation and delivery principles. **All proposed Regun timings, admin bounds and rollout thresholds below are design hypotheses**, not researched industry averages. Exact competing-game reroll odds from community wikis were not used as authoritative specifications. No paid market report, physical playthrough or revenue dataset was available.

## 3. Current implementation audit

Audit reflects current source, generated catalogs, selected tests and repository state on 23 October. Latest recheck: game HEAD `1556153` (working-tree app version `1.0.0+17`; version change is uncommitted). Server HEAD `c99c48d`, including capacity support `0478d3f` and description metadata. Previous audit used game `48d22be` and server `bf1f005`; the plan itself was subsequently committed in `3fd0c2c`. Admin working-tree version: `0.2.0+2`; its branch `codex/admin-foundation` has no commits and its sources are untracked. Read the actual admin tree, not Git history, as the implementation baseline; preserve/export it before implementation. No staging, commit, deployment or installation was performed for this audit. Older documents contain superseded versions and counts.

| Area | Exists now | Work needed |
|---|---|---|
| XP | Dart `XPProgression.cost` and TypeScript `xpCost` both use `8 + 10n + 7n(n−1)/2`, n = current level − 1. | Make one versioned specification and cross-language fixtures; integrate pinned progression configuration. |
| Offers | Native uses up to three unique weighted choices, weapon/survivor eligibility and prerequisites, rank caps, six Special families, bans and an existing-family first-card rule under `buildBalance:2`. | Formalize eligibility/order/weights. Server's inspected offer generator lacks that first-card rule and the full native eligibility set. Treat parity as a release gate, not an assumed property. |
| Upgrade catalog | Native currently has 43 offered families and eight fusion recipes; server's inspected progression map contains 35 families and six recipes. Double Dash/Grenade Reserve have up to two ranks; the other 41 native families retain VIII ceilings, subject to eligibility. | Declare a supported subset by mode/capability. Do not advertise missing mechanics online or fix the mismatch by copying names alone. |
| Choices | Native has two rerolls and one ban per run. Source is partly represented by `supplyOffer`; fusion choices have a separate list. | Use a typed, checkpointed source and a single transactional choice model. Preserve current allowances in the baseline. |
| XP interruptions | Funded XP only; overflow retained; four active seconds of grace; another pickup triggers a further offer. | Preserve and test this behavior across clients. No instant chained picker screens. |
| Supply rewards | An earned objective creates an ordinary upgrade offer without spending XP or increasing level. | Keep as an explicit earned source with a unique receipt and retry-safe presentation. |
| Boss cores | Two banked cores, two fusion slots; III/II ingredients; surplus cores become five run Scrap. Current core opening deducts before selection. | Model a deducted/open core as a durable reservation so restore/cancel cannot lose it or issue it twice. |
| Upgrade response | Confirmation queues the existing recovery pulse; reroll/ban do not. | Preserve exactly once, including checkpoints and co-op resume. |
| Live values | Source/catalog audit confirms 211 fields: 126 weapon, 30 survivor, 12 effect, 41 power-up strength values and two capacity totals. All four game/server/admin catalog representations match exactly at ID `fdcdd8aecb83edca522ffd05280e24470901d237486fd3fa68fc8e17b2eca9ed`. Full snapshots and legacy 168/209-field hash compatibility already work. | Extend this existing pipeline for progression; do not rebuild base-balance delivery or power-up editing. XP/reward/offer policies are still compiled code. |
| Charge capacity | Earned Double Dash/Triple Dash and Grenade Reserve add one loaded slot per accepted rank; starts remain one dash/two grenades. Pinned admin upgraded totals are dash 2–3/default 3 and grenade 3–4/default 4. | Preserve sequential recharge, existing pending clock and rank suppression at lower caps. These are already implemented, not new monetization work. |
| Item descriptions | Admin/API catalog includes 78 game-authored item descriptions (21 weapons, 10 survivors, 43 power-ups, four effect groups). Description-only updates preserve numeric catalog identity and balance hashes. | Keep copy separate from numeric configuration and existing field tuning instructions; do not publish a new combat release merely to change display text. |
| Online choice flow | Server owns offers and co-op choices; a shared phase has a 15-second selection window. | Preserve mode-specific clocks and validate stale choice/reconnect/generation behavior. |
| Solo Scrap | `PlayerProfile.scrap` persists earned value; `earnedScrap` includes run Scrap, kills/10, 15/boss and seconds/60. Collection purchases mutate this local profile and save it. | Observable banked balance, durable spending result and explicit save-failure handling. |
| Online Scrap | Server `onlineAccount.scrap` already accumulates authoritative co-op rewards; canonical identity and once-only match result guard the credit. Client subscribes to `my_online_account` and shows per-result online Scrap. It is separate from `PlayerProfile.scrap`. | Define reconciliation/migration before displaying or spending a combined total; do not treat existing online rewards as nonexistent or already unified. |
| Wallet UI | Home has no wallet. Collection shows Scrap availability beside individual items. | Shared observable wallet display on Home and relevant screens. |
| Cloud trust | Owner-scoped local profile/outbox, revision/reset-epoch conflict handling, verified accounts and canonical online identities exist. Device reports are cumulative diagnostics, not wallet grants. | Reuse account ownership; preserve profile conflict rules. Neither cloud snapshots nor online cumulative Scrap is a purchased-currency ledger. |
| Admin operations | Numeric editing, local drafts/candidates, rebase, staging/production, expected-revision publication, rollback, audit, editable Help and Players are implemented. Saved secure sessions survive data-refresh outages; expiry/401/sign-out revoke them. | Add progression views/validation to these flows. Do not schedule login, publication or Players as greenfield work. |
| Deployment continuity | Current bootstrap validates the saved publisher through the internal websocket proof and preserves signing state. Server docs record recovered production storage and single-writer stop-first updates. | Extend additively; verify same-volume restart, preserved identities/releases and session reuse before rollout. Documentation is historical evidence, not a fresh production inspection. |

Existing assisted records include aim assistance. Do not repurpose `assisted` to mean purchased recovery; future continuation status must remain independent.

### Audit findings that change the delivery order

1. **Reuse remote balance now.** Upgrade strength is already editable and pinned through accepted upgrades/Continue; focused game/server tests pass. New work is progression semantics and its atomic activation alongside those snapshots.
2. **Separate three currency facts.** Local/cloud-profile Scrap, server-earned online Scrap and future purchased Credits have different authorities. A single header cannot make them interchangeable. Initially show spendable profile Scrap and expose available online-earned totals separately in wallet details, with no implied spendability or conversion. If no trusted online cache is available, display unknown/offline rather than zero. Do not rename online Scrap to Credits.
3. **Persist before celebrating a spend.** Collection currently subtracts Scrap/adds ownership before awaiting `saveProfile()` and does not branch on its boolean result. Solo settlement sets an in-memory `_settled` guard and clears the checkpoint even if profile save reports failure. These paths need a failure/rollback/retry design before a shared wallet advertises durable spending or recovery. This audit found source-level gaps; no storage-failure reproduction was run.
4. **Do not equate catalog breadth with online gameplay support.** Admin can configure 21 weapons/10 survivors/41 strengths plus two capacity totals, but inspected online weapon specifications admit five weapons; online progression defines 35 families and six recipes. Protocol 4 clients detect `charge_upgrades`; older attached clients cannot receive the new capacity families. Remote field presence cannot port missing mechanics. Decide and document the supported subset first.
5. **Preserve repaired operations.** Adding tables or release routes must not mint a new publisher, rotate stable secrets, replace recovered storage or use overlapping database writers. Additive module publication keeps `--delete-data=never`.
6. **Version the admin baseline.** Its complete working tree exists and tests pass, but has no committed checkpoint. A reviewed source snapshot/backup is a delivery prerequisite, not a reason to recreate the admin app or silently commit the user's tree.

### Existing online reward semantics

`spacetimedb/src/settlement.ts` already finalizes results transactionally. Its current award is `min(250, floor(score / 100))` only for eligible completed co-op participation (at least 30 seconds, at least three kills, no forfeit). Versus and interrupted matches do not award that Scrap. Canonical account mapping and result keys guard repeat finalization. This is a separate earning rule from solo's kill/boss/time formula and from transient `Progress.scrap` accrued during combat; do not assume every in-run Scrap amount is already credited to the persistent online account.

Before a unified wallet, decide whether to retain these mode-specific earnings or change them in a reasoned gameplay/economy release. Any migration must identify which result grants are represented in a balance and which have already been imported. Keep existing cumulative online totals intact; importing them on every login or adding local/cloud/device/online totals indiscriminately would create duplicate value.

### Baseline arithmetic

| Level reached | Total collected XP needed, before any grace delay | Next level cost |
|---|---:|---:|
| 2 | 8 | 18 |
| 3 | 26 | 35 |
| 5 | 120 | 90 |
| 8 | 511 | 225 |
| 10 | 1,020 | 350 |
| 12 | 1,793 | 503 |
| 20 | 8,645 | 1,395 |

Supply offers and fusion selections are additional decisions; they do not count as XP levels. Reaching a level takes the displayed total XP **and eligible pickup opportunities after grace**, so the table alone cannot predict wall-clock timing.

VIII ranks for the 41 standard families, up to two ranks for each capacity family, six Special slots and two fusion slots are ceilings, not promises to fill them in every attempt. Summing every family's rank ceiling is not a reasonable target for choices within one short run. Measure concentrated-build viability and late-run stagnation separately.

## 4. Player-facing run design

### 4.1 Resource boundaries

| Resource | Source | Spend / effect | End of run |
|---|---|---|---|
| Run XP | Valid combat pickup/reward | Pays next ordinary level offer | Reset; record summary only |
| Upgrade ranks | Accepted XP/supply choice | Current build, bounded by caps | Reset; discoveries/mastery may record use |
| Boss core | Rewarded boss defeat | One explicit eligible fusion reservation | Reset; not a wallet currency |
| Supply receipt | Completed supply objective | One ordinary upgrade offer | Must resolve once; not a purchasable token |
| Rerolls / bans | Equal run-start allowance | Changes current ordinary offer | Reset; never replenished by purchase or ad |
| Dash / grenade reserves | Start with one dash/two grenades; earn extra slots through the two capacity families | Up to three dashes/four grenades at default upgraded caps; one-at-a-time recharge | Existing inventory/checkpoint rules; extra capacity is earned, never sold |
| Run Scrap | Authored run rewards | Accrues toward settlement | Added once to banked Scrap |
| Banked Scrap / Credits | Persistent wallet grants | Between-run spending; future eligible recovery | Persist independently of build |

Lucky Find can continue changing offer weights **when earned in the build**. “Do not sell better odds” does not mean removing earned build mechanics. Survivor abilities, weapon restrictions and explicit game modes can also alter gameplay; purchase history cannot.

### 4.2 XP and pacing

First ship the current curve as progression baseline 1. Do not alter XP costs and enemy XP simultaneously in the first tuning experiment; that obscures the cause. Preserve role/elite/boss rewards until measured separately.

Instrument deployment-complete time as the start of combat pacing. Count active combat seconds separately from menu, picker, deployment, pause and network stalls. Preserve the intentional native 0.1× world presentation while a choice is open, with its existing input/damage gating. That presentation time must not advance grace, director pressure or grenade/reload clocks.

Provisional playtest questions, to be converted into targets after baseline observation:

- Does the first meaningful choice arrive within roughly 15–30 active seconds for an ordinary new player, without interrupting deployment/tutorial explanation?
- Can the opening minute establish a direction with roughly two or three accepted build choices, without a stream of menus?
- At the first boss request (currently around 180 active director seconds), is a level around 6–9 a useful starting hypothesis for testing rather than a requirement applied to every skill level?
- Can a deliberate fusion-oriented player reasonably reach an ingredient pair after the first boss and before the run feels settled, without a guaranteed recipe lottery?
- Do later upgrades become too scarce to sustain the build, or does survival pressure provide enough decisions between choices?

Observe distributions by weapon, survivor, arena, experience and input configuration. These ranges are not launch acceptance facts or a reason to increase spawn density. Population/readability limits remain intact. Use a curve preview and measured XP arrival traces before proposing a replacement curve.

### 4.3 Offer generation

Specify a versioned algorithm with this order:

1. Build the mode-supported family set from the pinned catalog.
2. Exclude incompatible weapons, unmet prerequisites, banned families, cap/no-benefit cases (including `rankLimit` for capacity families rather than a universal VIII ceiling) and new Special families beyond six slots. Existing Special families remain eligible for later ranks.
3. Add the existing fallback when fewer than three normal eligible families remain. Return fewer distinct cards when necessary; never duplicate an offer to fill space.
4. For algorithm version 2, retain native's first-card preference for an already-owned eligible family when one exists. Sample that card by its applicable weight, then fill the remaining cards without replacement.
5. Preserve baseline weights: Special weight `1 + effective Lucky Find rank × .35`; owned-family multiplier `1.5`. These are relative weights, not displayed individual percentages. The first-card rule changes the resulting probability distribution.
6. Save the generated offer and the advanced offer-RNG state atomically. Opening, rendering, reordering a list for display or restoring a checkpoint must not reroll it.

The first-card preference improves access to existing build ranks but can crowd discovery and ingredient acquisition. Measure it against a deliberate alternative in QA before changing production. Do not add pity or guaranteed fusion ingredients silently. If later approved, publish an explicit algorithm version applying equally within a mode/release.

Use stable family IDs and deterministic iteration order. Keep offer randomness separate from world/VFX randomness. For parity tests, inject the same random-number tape; do not require full Flame/server physics to be deterministic. If sharing a PRNG implementation later, specify fixed-width arithmetic precisely—Dart integer multiplication and JavaScript number multiplication cannot be assumed equivalent.

Reroll costs exactly one run reroll, increments the offer version and keeps the same source/reservation. Ban costs one ban, excludes that family for the run and generates the replacement offer. Baseline behavior may show an old card again on a reroll; do not describe reroll as guaranteeing all-new choices. No ad or wallet shortcut appears when these allowances reach zero.

### 4.4 Source and lifecycle contract

Use `OfferSource = xp | supply | fusion | training` with source-specific receipts. Training cannot settle normal rewards. Only one picker is live per player; earned pending receipts queue without duplicating.

| Trigger | Funding rule | When opened | On confirmation |
|---|---|---|---|
| XP pickup | Threshold already funded | Playing, no picker, grace elapsed | Apply one rank/fallback; resume with four active seconds grace |
| Supply capture | Unique earned supply receipt | Earliest eligible post-grace opportunity | Apply ordinary choice; do not touch XP, level or next cost |
| Fuse core | Core plus eligible III/II recipe and free slot | Explicit action, eligible state | Commit reserved core and fusion once; grace applies |
| Training action | Explicit practice command | Training only | Prepare practice build; no normal settlement |

An XP offer deducts its cost and advances level atomically at offer creation, matching current behavior; restoration resumes that exact paid-for offer. Supply receipts are not consumed twice on retry. Core opening reserves/deducts one core; an open fusion is checkpointed. If a future UI adds Cancel, return that reservation exactly once. Until then, do not add an implied cancellation path that loses the core.

Define source priority at a simulation boundary: keep the current picker; present an eligible pending earned supply before opening another pickup-triggered XP offer; explicit Fuse runs only when no picker is active. All sources share grace. An XP pickup received during grace increases XP but does not create a deferred automatic picker. A later accepted pickup after grace can open it.

Fallback remains the authored five run Scrap plus one HP within maximum health. It is not a paid substitute and does not create another level. Accepted fallback counts as an accepted ordinary choice for the existing recovery pulse unless a new gameplay release explicitly changes that rule.

An accepted XP, supply or fusion selection queues the existing recovery pulse once. Reroll, ban, stale request, navigation, timeout retry or an unsuccessful choice never creates an extra pulse. Preserve current hostile-bullet clearing, secondary damage, occupancy/cover and planted-actor rules.

### 4.5 Modes and accessible play

- **Solo:** local authority for gameplay; bundled/cached snapshot; no network gate. No selection deadline.
- **Co-op:** shared XP pickup intent remains server-authoritative; preserve per-player builds and existing supply entitlement rules. Keep the existing shared 15-second choice window as the initial mode policy; label the countdown and explain automatic selection. A reroll must not restart the room deadline. Choice acceptance and timeout compete atomically, so only one wins.
- **Disconnected co-op:** retain current bounded reconnect policy; no automatic extra reroll, replayed source receipt or fresh build on attachment. Specify whether disconnected members accrue XP separately from offer presentation, matching server behavior rather than inferring solo rules.
- **Versus:** this contract does not inject survivor-run progression into PvP. Keep its separate combat policy and explicitly supported modes.
- **Training:** all supported training tools, recipe explanations, controls and accessibility settings remain available independent of buying currency. Practice grants never become normal rewards.

Reduced Motion, Haptics, text scaling, handedness and aiming assistance are settings, not products or offer weights. Keep their effects visible in record metadata where relevant without labeling accessibility as purchased advantage.

## 5. Wallet visibility: a required part of the delivery

### 5.1 Identity and placement

Use **Scrap** for earned currency. Use **Credits** as the working name for the second/premium currency, with a stable internal ID independent of the visible name. This name is a proposal, not a shipped currency. Collection currently also has a **Credits** acknowledgements tab; rename that tab **About** when the currency name is adopted to avoid ambiguity.

On Home, show two compact cells at the **top right inside SafeArea**, visually separate from the Play navigation and clear of shelter artwork focal points. Starting layout tokens: 16 logical px from the safe content edge on phones, 24 on wider layouts, 8 px between cells, and at least 12 px separation from neighboring controls. These are prototype tokens to validate on real screens, not hard offsets from the physical screen/notch. Reserve layout space instead of laying balances over buttons.

Each cell has a distinct pixel icon, text label and amount. Use restrained brass for Scrap and a distinct muted cool accent for Credits; do not rely on color alone. Preserve the custom charcoal/pixel design, readable numeric type and approved shelter painting. Do not add a generic Material banking bar, constant shimmer or bright notification dot.

Illustrative layout only:

```text
Safe area                                        [SCRAP  1,240] [CREDITS  80]

REGUN
NO QUIET WAY OUT.

[ Play / Continue ]
...
```

Those example amounts are not seeded game balances. On narrow/large-text layouts the cells may occupy a dedicated right-aligned second header row or stack; never squeeze labels into unreadable text. Interactive cells use at least 48 logical px touch targets and keyboard/semantic labels. A balance cell opens wallet details/history; purchasing is a separate explicit action, not an automatic consequence of tapping the amount.

### 5.2 Where balances appear

| Surface | Display | Interaction |
|---|---|---|
| Home | Banked Scrap and Credits | Wallet details; later a separate store entry |
| Collection/Style and future shop | Both balances pinned above browsing | Item shows price, currency and affordability; confirm before spend |
| Loadout/preparation | Compact persistent wallet in header, below navigation if necessary | Informational/details; no suggestion of buying combat unlocks |
| Career/mastery when delivered | Same header wallet | Keep earned progress distinct from spendable value |
| Results | Run earnings breakdown, banked before → after and both wallet balances | Grant once; “Saved on device” versus accepted cloud/purchase state where needed |
| Pause | Banked wallet and clearly labeled current-run Scrap estimate | Details only; does not resume combat |
| Future recovery panel | Relevant available resources, exact cost and after-spend balance | Atomic recovery confirmation; no ambiguous conversion |
| Active combat / upgrade picker | Existing combat HUD; optional run Scrap readout only if useful | No shop or premium balance overlay over aiming/choices |
| Training | Compact menu wallet if inherited; no simulated grants to real balances | Practice never changes wallet |
| Settings/About | No repeated wallet unless navigation shell naturally includes it | Avoid clutter |

Wallet relevance does not require covering combat with two persistent premium numbers. The money is visible where players prepare, earn, spend or recover; the fight prioritizes health/ammo/XP/controls.

### 5.3 State, freshness and formatting

Create one observable account-scoped wallet provider with separate profile-spendable Scrap, online-earned Scrap and premium availability fields; format them into the appropriate surface rather than adding balances in widgets. Native `PlayerProfile` is mutable today and Home refreshes after navigation; merely reading `profile.scrap` once in a widget can leave a stale header after purchases or sync. All wallet surfaces subscribe to the same state and use confirmed/reconciled changes.

Define `loading`, `available`, `cachedOffline`, `pendingOperation`, `unavailable`, and `reconciling` states. A known zero displays **0**. An unknown balance displays **—**, with explanatory details, never a fabricated zero. Keep last-known amounts visible during a background refresh and put stale/sync detail in the wallet sheet. Do not block Play or steal focus during refresh.

Before the premium system exists, show the second cell as **Credits —** with “Not available yet” in details; no plus button, checkout or fake earn claim. Once a genuine wallet has been initialized and a zero is confirmed, it becomes **Credits 0**. This honors the requested two-wallet layout without implying that premium purchases already work.

Use locale grouping and an exact amount in details. If a very large balance needs compact formatting on a small device, keep full value available semantically and in details. No animated count should lag the actual spendable amount; Reduced Motion uses an immediate update. Account switch clears old-owner balances synchronously before loading the next account. Guests may earn and see Scrap, but spending requires verified email sign-in; premium purchase/account recovery design is a later dependency.

Run Scrap is provisional until a run settles and must not inflate the spendable banked amount while the player is still fighting. Results show “This run +55 Scrap” separately from wallet total. Reopening Results does not grant again. Continue-from-disk is not a new settlement.

### 5.4 Wallet ownership boundary

For this first slice, expose **existing spendable profile Scrap** through the provider and add a read-only/unavailable premium state. Include a separately labeled online-earned total in wallet details when the authenticated server/cache can supply it. Do not present online Scrap as spendable in Collection yet, introduce purchasable Credits, or migrate balances as part of a UI change. A later unified Scrap total requires the explicit reconciliation milestone below.

The later unified server wallet must use integer minor units/whole units with bounded amounts, account ownership, revision, ledger operation IDs and provenance. Extend the existing canonical account/online reward machinery; do not create a second identity system or credit the same authoritative match both through `onlineAccount` and a new wallet grant. Purchased/promotional Credits have separate grant origins even if the UI shows one amount. A client cannot upload `credits: 500` in a profile to grant paid value. Likewise, admin balance configuration cannot grant currency.

Decide earned-Scrap reconciliation explicitly before server spending: existing local Scrap and offline run reports are not proof of trusted combat. Preserve legacy value with a documented once-only migration policy, mark trust/origin, and do not sum competing cumulative snapshots. If offline earned Scrap can buy cash-equivalent products, local tampering can bypass revenue even without converting to Credits. This is a product tradeoff, not something a JSON signature fixes.

All new spending requires online authorization. Offline Solo/Training remain available. Spending earned Scrap requires an attached verified email account; guests cannot buy styles, recovery, or any other product. Existing earned/owned styles may still be equipped without a new purchase. All new purchases, including earned-Scrap spending, require online server authorization. A cached account cannot authorize a new offline purchase. Previously downloaded owned items remain usable offline, including after relaunch. Offline premium spending needs bounded reservation/reconciliation design before promising it. Never combine an optimistic local premium subtraction with a server-confirmed balance and accidentally subtract twice.

## 6. Shared contracts and snapshot boundaries

### 6.1 Extend the existing system

Use the current gateway, SpacetimeDB persistence, authentication and admin publication workflow. No additional configuration service or database. Preserve existing balance schema/catalogue and the `/balance/v1/current` path for supported clients while introducing a separately capability-gated progression contract. Do not rewrite old 168/209/211-field immutable releases or force all clients onto a new manifest route in one deployment. Canonical machine-readable definitions should live under proposed `regun-server/shared/progression/`; generate/verify Dart and TypeScript adapters plus the admin field catalog.

Three distinct domains:

- `CombatBalanceSnapshot`: existing base stats, effect scalars and supported numeric combat fields.
- `RunProgressionSnapshot`: XP costs/rewards, allowed offer policy, recipes, caps and objective rules for this supported implementation.
- `WalletSnapshot`: account-owned balances and operation state. Mutable through valid grants/spends; not part of the combat rules document.

For the progression-capable rollout, pin combat and progression together with a small **GameplayRelease manifest** referencing exact immutable documents/hashes and required capabilities. A manifest is the activation unit, preventing “new XP curve with old reward table” or “new recipe with missing effect.” Keep existing combat releases readable; a legacy run maps to a legacy progression implementation rather than the current one.

Proposed progression fields:

| Group | Initial remotely editable values | Initially fixed/versioned in code |
|---|---|---|
| XP curve | Bounded authored cost table/bands, with explicit tail model | Arithmetic semantics, integer validation, migration handler |
| XP rewards | Supported enemy/elite/boss IDs and reward amounts | Reward-once logic, pickup capacity/aggregation safety |
| Offer weighting | Existing-family weight and earned Lucky Find coefficient | Algorithm version, sample-without-replacement, eligibility predicates |
| Grace | Baseline four active seconds; publish only after reader/test coverage | No automatic overflow chaining, clock definition |
| Core/fusion | Display current caps/recipes; later numeric thresholds after compatibility support | Two cores/two slots in v1, effect implementation, no fallback boss upgrade |
| Supply | Inspect existing timing/reward policy; editable only after full runtime coverage | Unique receipt and non-XP source semantics |
| Charge capacity | Existing pinned numeric controls: dash total 2–3 and grenade total 3–4 | Starts 1/2; +1 loaded slot/rank, maximum two ranks, sequential recharge and existing hard caps |
| Rerolls/bans | Inspect baseline 2/1 | Fixed equal allowance in v1; no commerce override |
| Safety caps | Inspect limits and reasons | Projectile/effect/population ceilings and dependency validation |

Not every desirable field needs remote editing on day one. Use read-only metadata when the client lacks a pinned reader; never create an admin slider that appears effective but is ignored by one runtime. New family behavior, enemies, art or PRNG semantics require a binary/server release.

Example manifest shape (illustrative, not a deployed schema):

```json
{
  "schema": 1,
  "releaseId": "gameplay-42",
  "combat": {"revision": 31, "hash": "<sha256>"},
  "progression": {"revision": 4, "hash": "<sha256>"},
  "ruleset": "survival-v1",
  "requiredCapabilities": ["progression-v1", "offers-v2", "charge_upgrades"],
  "channel": "production"
}
```

All component documents validate together before cache replacement. A hash identifies content; it is not proof of trusted authorship or trusted solo play. Use authenticated publication and TLS, and existing server authority for online execution.

### 6.2 Activation table

| Event | Rules used |
|---|---|
| Fresh solo attempt | One complete compatible manifest already available locally at creation |
| Background refresh/publish | Store for future attempts; active rules do not change |
| Pause/resume/foreground | Existing run snapshot |
| Continue checkpoint | Entire saved compatible snapshot and versioned legacy rules |
| Training weapon swap | Same training visit snapshot, including newly selected weapon's values |
| Restart | New run ID and latest fully cached compatible release captured once; do not retain some old bases and refresh other parts |
| Future paid continue | Same run ID/build/rules; never interpreted as Restart |
| Online room start/rematch | Server-selected supported release, pinned for that match |
| Online attach/reconnect/round transition | Room release; client cannot select a different hash |
| Rollback | Publish a new monotonic manifest referencing known-good content for future runs |

Solo defaults/cached rules keep Start responsive when the service is absent. Online compatibility failures block only that unsupported online session. A match cannot silently fall back to a different ruleset for one participant.

Economy experiments cannot target enemy damage, XP cost, offer probabilities, spawn pressure or rewards by spend status or losing streak. For initial rollout, use staging/internal QA for gameplay variants and one public gameplay ruleset per mode/channel. If gameplay experiments are introduced later, they require explicit stable assignment, run-start pinning and record separation; never mutate a running attempt. Offer placement tests remain separate from gameplay configuration.

## 7. Server implementation

### 7.1 Storage and delivery

Reuse the existing private release/audit/channel machinery where its validation boundary fits; otherwise add typed private progression releases and one atomic manifest pointer. Do not duplicate admin sessions or expose an arbitrary configuration JSON store. Keep immutable documents so active rooms can retain their referenced payloads during rollback or retention cleanup.

Proposed endpoints alongside current balance delivery:

- Public `GET /gameplay/v1/current?channel=production&capabilities=...`: complete supported manifest plus documents or immutable references, ETag, bounded body/cache. Unsupported clients receive an explicit compatibility response; old balance clients retain the old supported path while maintained.
- Protected progression draft validation/preview/publication routes: existing admin authentication, body/rate limits, expected-base revision and request IDs.
- Future authenticated wallet summary/history/spend routes: independent from gameplay publication. Not implemented by this plan's first UI milestone.

Route names and table names are proposals. Return changes through the established gateway/subscriptions rather than inventing reducer return values. Existing `/admin/catalog`, `/admin/releases`, `/admin/publish`, `/admin/rollback`, `/admin/audit`, `/admin/guide` and `/admin/users` routes already serve their current functions; extend their typed contracts or add narrowly scoped progression routes rather than replacing them. The UI name is Players while the compatible route remains `/admin/users`. The current owner/admin implementation is single-owner; do not claim multi-role authorization already exists. Expand roles only with explicit server enforcement.

### 7.2 Authoritative progression actions

Online clients request a choice by active run/match generation, offer ID and choice ID. Authenticate sender/active connection and derive player, room, build, source and rules from server state. Validate membership, phase, positive/living eligibility, deadline, source funding/reservation, rank, bans, compatibility and current offer membership.

Retain the current transactional choice/reroll/ban reducers and phase/deadline checks. Extend them to bind the new progression rules/source receipts; do not implement a second mutation path. Apply the choice, consume its source once, advance offer version, update build and queue one recovery event in one reducer transaction. Reroll/ban do the same atomic check/decrement/replacement cycle. A stale request is rejected or returns the existing operation result without spending again. Use generation/epoch binding so delayed commands from a prior match cannot hit a new offer with the same numeric ID.

Do not accept client XP totals, ranks, recipe eligibility, adjusted odds, balance values or purchase tier. Supply and boss receipts come from authoritative reward events. Distinct death/kill IDs prevent duplicate drops/rewards. Retry acknowledgements and repeated subscriptions are not new events.

Retain supported capability sets per online mode: five supported weapons and the currently supported upgrade/recipe subset are not equivalent to the full native roster. Newly ported families need effect/proc/cap tests as well as eligibility rules. Shared fixtures compare only mutually supported semantics; unsupported content is reported, never silently replaced.

### 7.3 Privacy and diagnostic data

Offer tables/views are player/room scoped as necessary. Public catalog metadata may reveal weights and recipes, but never expose admin sessions, wallet rows, all players' private inventories or mutation credentials. Client-reported solo events remain labeled as such. A receipt hash or event log cannot prove offline damage simulation was honest.

Use bounded recent events for support plus aggregate metrics, not permanent per-frame combat logs. Follow existing account deletion and retention policies. Purchases will later require their own financial record-retention review.

## 8. Admin authoring experience

Add **Run progression** beside current combat editing, keeping **Wallet/economy** separate. Respect existing native iPhone/macOS layout and draft persistence. The authoring flow is:

1. Open an explicit baseline/release; see mode, supported clients and read-only invariants.
2. Edit permitted typed fields with units, limits and source explanations.
3. Inspect XP cost and cumulative-XP curves, then overlay recorded XP arrival traces. Label traces by source and sampling period.
4. Inspect representative builds: eligibility explanations, chance of continuation, ingredient reachability, caps/no-benefit cases and fallback frequency.
5. Review combat/progression manifest changes together, enter a reason and save a recoverable candidate.
6. Publish to staging with expected-base protection; validate it in a real developer game build or explicitly labeled simulator.
7. Promote the reviewed compatible manifest to production; keep audit and rollback available.

Current Staging is a release channel, **not a playable preview**. Production is already the default channel in the admin, and server-editable Help is implemented; update the bundled and editable guide schema/content alongside new controls without claiming local or server text edits are gameplay releases. The new plan adds a deterministic rules preview and an explicit developer-only playable staging path; neither should be implied to exist now.

### Required preview panels

- **Pacing:** per-level cost, cumulative XP, observed/assumed XP per minute, decisions by first/second boss and estimated rank concentration. Clearly distinguish measured traces from synthetic assumptions.
- **Offers:** selected weapon/survivor/mode/ranks/bans; eligible cards and exclusion reasons; weighted samples; fallback rate; first-card policy. Enumerate exact probabilities where tractable; label Monte Carlo estimates with sample count/seed and uncertainty.
- **Fusions:** supported recipes, thresholds, required choice count, prerequisite compatibility, core reservation and slot limit. Do not report “guaranteed by minute 4” from expected XP alone.
- **Compatibility:** unsupported readers/content, required client capabilities, legacy restore coverage and mixed-manifest validation.
- **Fairness:** a fixed explanation of unavailable commerce overrides; display whether changing a field affects XP, odds, damage or pressure. Do not allow user-specific difficulty assignments.
- **Release:** old/new values, absolute and percentage changes, all dependent component hashes, staging evidence and expected channel revision. Cross-field errors block publication.

Validation requires positive integer XP costs/rewards, a defined bounded tail, safe arithmetic, permitted IDs, no circular/impossible prerequisites, weights finite/positive, cap relationships, supported effects and guaranteed terminal fallback for reachable exhausted pools. Warn when a proposed strength produces a no-benefit upgrade because rounding/caps remove its effect. The preview must use the same contract semantics as runtime; it is not a separately invented spreadsheet formula.

The admin should answer “what will the player experience?” and “which clients can honor it?” before showing Publish. It cannot prove physical feel or profitability. No hidden arbitrary scripts, asset URLs or player-segment rules enter the payload.

## 9. Telemetry and success measures

Minimum event model: `run_started`, `deployment_completed`, `xp_pickup_accepted` (aggregate where possible), `offer_created`, `offer_rerolled`, `family_banned`, `choice_confirmed`, `core_earned`, `fusion_reserved`, `fusion_confirmed`, `supply_receipt_earned`, `run_ended`, `run_settled`, and `wallet_changed`. Use stable event IDs and bounded buffering/deduplication.

Attach run ID, mode, combat/progression release IDs, supported loadout IDs, active time, level, source/offer ID, manual/timeout selection and authority (`deviceReported` or `serverVerified`). Keep continuation and accessibility flags distinct. Do not log raw input streams, secrets or personal data merely to study progression.

Track first/second offer times; inter-choice gaps; level at boss request/defeat; picked ranks by family; fusion opportunity versus actual fusion; reroll/ban usage; fallback frequency; cap/no-effect offers; supply capture and reward delays; picker abandonment; checkpoint failures; and wallet staleness/settlement errors. Report distributions and cohort sample sizes, not just averages among survivors.

No revenue KPI is a release criterion for this foundational pass. Future conversion analysis must also check retained-player outcomes and fairness. Group by gameplay release before comparing spend cohorts, and do not infer that paying caused higher survival from a payer/non-payer correlation.

## 10. Save migration and failure handling

New checkpoints carry the complete progression snapshot (or a durable local content-addressed document), release identity, algorithm version, offer IDs/cards/source, RNG state, grace, core reservation, pending supply receipts and recovery-pulse pending state. Never require an internet lookup to Continue.

Keep the existing `xpCurve:3`, `buildBalance`, weapon balance and shotgun reload migration meanings intact. Preserve `dashReserve` and grenade capacity/charges/recharge checkpoints; old saves default to one dash/two grenades. Validate inventory capacity against saved build ranks and pinned capacity fields, never the latest publication. Existing 168/209-field snapshots retain default upgraded totals 3/4 without rewriting their original content/hash. Do not migrate a pinned active run to a newly published XP curve by repeatedly rescaling its bar. Missing progression snapshot maps once to the known legacy contract; a fresh run uses the new contract. If a future binary cannot interpret a checkpoint, preserve/export it and explain the incompatibility rather than silently discarding it or granting settlement twice.

Malformed download → last valid complete cache. Failed cache write → retain previous usable snapshot and retry later. Partial manifest → reject as a unit. Server restart → room snapshot and receipts remain authoritative. Repeated run settlement → return recorded result. Wallet refresh failure → show last known state; unknown balances remain unknown. Account switch → no old-owner checkpoint or wallet leakage.

Future paid recovery must have its own persisted pending-decision phase before final game-over settlement. This plan does not add checkout to the existing settled Results screen.

## 11. Delivery sequence

| Milestone | Game | Server | Admin | Exit evidence |
|---|---|---|---|---|
| **0. Preserve audited baseline** | Keep current committed game state and separate version-only changes | Retain persistent publisher/volume/secrets and additive schema | Back up/version the existing uncommitted admin tree; retain drafts and session behavior | Reproducible catalogs and recoverable source/data; no deploy implied |
| **A. Visible earned wallet** | Observable spendable profile Scrap; top-right cells; relevant screens; unavailable Credits; separate online-earned details; save failure/retry behavior | Reuse online account views/results; no fake premium authority or balance summing | Explain balance provenance; no currency minting | Guest earning/visibility with verified-email spending gate; account/profile changes, online/offline states, durable spend and settlement tests, responsive screenshots |
| **B. Contract and parity** | Extract pure eligibility/offer/progression adapters; current behavior fixture | Supported-subset adapter; versioned differences resolved or declared | Read-only progression inspector | Cross-language fixtures and exhaustive eligibility/source tests for supported content |
| **C. Immutable progression releases** | Composite snapshot capture, cache, Continue and Training integration | Typed release validation, manifest publication and room pinning | Typed editing, review, staging and rollback | Publish during run/reconnect tests; old saves and offline entry retained |
| **D. Measured pacing** | Baseline telemetry and playtest instrumentation | Trusted/observed aggregation separated | Curves, offer/fusion preview and measured traces | Baseline report and creator-reviewed new curve if needed; no numerical change solely to fill the editor |
| **E. Tuned earned run** | Approved XP/offer changes only at new-run boundaries | Matching authoritative rollout | Reasoned compatible promotion | Native comfort/build agency review; full checks; one public ruleset per mode |
| **F. Unified earned Scrap, before shared spending** | Explicit synced/pending/spendable states; receipts for any imported rewards | Preserve canonical online grants, migrate legacy profile value once, define offline reconciliation and idempotent spending | Show profile-reported versus authoritative earned amounts; support audit | Multi-device conflict, duplicate import, account deletion/reset and interrupted settlement acceptance |
| **G. Premium wallet dependency, later** | Genuine Credits state and future purchase UI | Verified ledger, refunds, existing account binding, atomic spend | Separate catalog/support controls | Billing/recovery acceptance under a dedicated plan before any cash sale |

After preserving the baseline, Milestone A is the first player-facing delivery. It does not require a premium ledger or immediate unification of solo/online earnings. Milestones B/C enable safe remote progression changes without waiting for every future pacing feature. Do not block Scrap visibility on building an entire monetization platform.

## 12. Verification and acceptance

Required automated coverage:

- Identical fixture costs/cumulative totals and offer outcomes from fixed RNG tapes across Dart/TypeScript for supported builds, including all thresholds/caps/prerequisites.
- Payment status cannot change run-start stats, rerolls/bans, offer RNG, eligible families, weights, XP awards or core/fusion capacity. Keep commerce inputs absent from these pure APIs.
- Exact threshold; large overflow; grace; XP received during picker; supply during grace; two cores; exhausted recipe pool; full Special slots; fallback; stale/repeated choices.
- Core reserved at open → crash/restore → confirm once; supply callback retry; reroll/ban cannot create confirmation pulses.
- Server connection/room/generation/deadline authentication; duplicate request; timeout/manual race; co-op all-ready and disconnected members; private subscriptions.
- Publish/rollback while paused, picking, reloading, in Training or reconnecting; running hashes stay fixed, new-run hashes change only as specified.
- Legacy snapshot fixtures, missing markers, invalid/oversized documents, unsupported capabilities, partial cache write and offline Start/Continue.
- Wallet zero versus unknown, stale refresh, account switch, results revisit, purchase confirmation callback duplication, insufficient-funds feedback and reactive updates.
- Header layout at 320/390 px, landscape, tablet and desktop; large text; long localized labels; very large balances; safe-area/notch; keyboard/focus/semantics; Reduced Motion.

Use existing project commands: game/admin `make verify`; server `npm run verify` plus identity verification and disposable local integration smoke where contracts change. Focused existing tests were run for this codebase audit (below); broader verification remains required when implementing runtime changes. Keep work in the current repositories and preserve concurrent edits.

Physical acceptance: inspect Home wallet margins over the actual shelter artwork; confirm touch/large-text comfort; play multiple ordinary builds through bosses; record first/late upgrade timing, fusion agency and menu interruption burden. Existing soak tests establish bounded simulation behavior, not human pacing, physical performance or monetization quality.

**Completion:** the player can see and understand banked currency where needed, combat power remains earned, native/server supported progression agrees, admin changes are reviewable and compatible, and no active/continued run silently changes rules after publication.

## 13. Implementation reader inventory

Game: `lib/systems/xp_progression.dart`, `lib/notifiers/game_notifier.dart`, `lib/systems/upgrade_details.dart`, `lib/data/weapon_power_balance.dart`, `lib/data/balance_catalog.dart`, `lib/models/live_balance.dart`, `lib/services/balance_repository.dart`, `lib/models/run_checkpoint.dart`, `lib/systems/run_random.dart`, `lib/systems/encounter_director.dart`, supply/reward readers in `lib/game.dart`, `lib/models/player_profile.dart`, `lib/services/local_preferences.dart`, `lib/services/account/`, `lib/views/menu_view.dart`, `lib/widgets/home_menu.dart`, `lib/widgets/menu_layout.dart`, `lib/views/collection_view.dart`, `lib/views/loadout_view.dart`, `lib/views/base_view.dart`.

Proposed new game units: `RunProgressionSnapshot`, `RunRules`, pure `OfferGenerator`, typed `UpgradeOffer`/source receipts, `GameplayRelease`, `WalletState`/provider and a shared `WalletBar`. Names can follow existing project conventions; avoid a wholesale game-loop rewrite.

Server: `spacetimedb/src/progression.ts`, `survival_actions.ts`, `survival_runtime.ts`, `index.ts`, `schema.ts`, `balance_contract.ts`, `settlement.ts`, `settlement_views.ts`, canonical account handling in `identity.ts`, existing shared balance catalogs, gateway `identity/src/admin.ts`/`http.ts`, persistent bootstrap `identity/src/deployment.ts`, and `deploy/start.sh`. Game online wallet readers also include `lib/multiplayer/online_session.dart` and `lib/widgets/online_combat_hud.dart`. Admin: `lib/models/balance.dart`, `lib/services/workspace.dart`, `lib/services/admin_connection.dart`, `lib/screens/workbench.dart`, `lib/screens/server_screens.dart`, shared catalog generation and release/help flows.

## 14. Re-audit verification record

Focused checks executed against the working trees on 23 October 2026; **44 tests passed**:

| Repository | Command | Result |
|---|---|---|
| Game | `flutter test --no-pub test/live_balance_test.dart test/home_menu_test.dart` | 11 passed; full snapshot/legacy hash, pinned accepted strengths/Continue, transport failure, Home layout/behavior |
| Admin | `flutter test --no-pub test/balance_test.dart test/admin_connection_test.dart test/server_screens_test.dart` | 16 passed; catalog/candidate handling, saved sessions/reconnect, Players and responsive screens |
| API/server module | From `spacetimedb`: `./node_modules/.bin/tsx --test tests/progression.test.ts tests/live_balance.test.ts tests/settlement.test.ts` | 16 passed; current progression, pinned overrides, repeat finalization/canonical reward behavior |
| API bootstrap | From `identity`: `./node_modules/.bin/tsx --test test/deployment.test.ts` | 1 passed; deployment state continuity contract |

The earlier 44-test audit covered the then-current 209-field catalog (41 native/33 online families). Those counts are historical and superseded by the repeat audit below; its test results remain evidence only for that earlier state.

This audit did **not** rerun analyzers/full suites, build release binaries, run disposable live SpacetimeDB/Docker restart smokes, inspect production credentials or contact production. The server continuity repair and production storage/settings described in `regun-server/docs/ADMIN_AND_LIVE_BALANCE.md` are documented prior evidence, not freshly reverified operational state. Before a deployment, rerun the relevant full checks and same-volume restart proof, preserve one replica and configured stop-first update/rollback order, and verify actual balance/account/privileged operations rather than `/health` alone.

No gameplay files, API implementation, admin implementation, schema or production configuration changed during this re-audit. Only this plan was updated. Current research links remain supporting design references; this pass was a local implementation audit and did not re-fetch them.

### Repeat audit after capacity and description changes

Rechecked game `1556153`, server `c99c48d` and the current uncommitted admin tree. **54 focused tests passed in this repeat check**:

- Game: `flutter test --no-pub test/charge_capacity_test.dart test/live_balance_test.dart` — 12 passed, including real checkpoint/pause behavior, capacity/admin bounds, legacy identity, sequential recharge and online prediction.
- Admin: `flutter test --no-pub test/balance_test.dart test/responsive_test.dart test/admin_connection_test.dart` — 24 passed, including all description sections, numeric identity independence, actual capacity editing and saved sessions.
- Server, from `spacetimedb`: `./node_modules/.bin/tsx --test tests/charge_capacity.test.ts tests/grenades.test.ts tests/live_balance.test.ts tests/progression.test.ts` — 18 passed, including authoritative reserve spending, gated/capped offers, grenade rules and legacy snapshots.

Exact JSON equality across game Dart, server TypeScript, shared server JSON and admin JSON confirms 211 numeric fields and 78 descriptions. Native supports 43 offered families/eight recipes; online defines 35 families/six recipes, with capacity families gated for older clients. Descriptions are display metadata, not part of numeric release identity. Do not treat the current `upgradeStrengths` map as a uniform scalar map: capacity families store integer upgraded totals, not multiplicative strength.

Wallet UI, premium ledger, hardcoded XP/offer parity gaps and separate profile/online Scrap remain outstanding. The capacity documentation records automatic server deployment, while already distributed +16 artifacts predate these changes; this check inspected local source and tests, not the live server or installed devices. Do not infer phone support from protocol/server code alone. Physical charge-control readability, balance and deployed binary compatibility remain acceptance gates.

## 15. First implementation slice — 23 October 2026

Implemented locally in the game app; API/admin have not been changed or deployed for this slice:

- Shared reactive wallet on Home (top right), Collection, Loadout, Pause and Results. Collection and Loadout keep it beside the page title in a shared pinned header; narrow/large-text layouts wrap the title group as needed. Credits is explicitly unavailable; Online Scrap remains a separate last-observed total in details, never added to Solo spendable value.
- **Creator clarification:** guests can earn/view Scrap, but cannot spend Scrap or make any purchase until email sign-in. The spend method enforces an attached verified account, not just a visible UI lock or non-guest profile ID. Collection opens the existing email flow and requires a fresh Buy confirmation after attachment/conflict resolution. Existing owned styles are still equipable.
- Cosmetic buying stages debit and ownership until durable profile saving succeeds; repeated taps cannot double-spend. Save errors expose retry state. The account's atomic profile/outbox is authoritative over its compatibility preference mirror on same-owner refresh.
- Failed game-over profile saving retains recovery data and prevents leaving/restarting from discarding the failure. Retry persists the already-settled profile rather than awarding again. This is not yet a crash-proof terminal reward journal: a process kill during a failed disk write may recover the prior checkpoint rather than the exact terminal state. A durable settlement journal remains part of unified-wallet work.
- Collection's acknowledgements tab is now About, avoiding the future currency name collision. No checkout, premium balance, paid revive, XP curve change or remote progression release is introduced.

Server-side spend authorization remains a requirement for the future unified/premium wallet; a local gate does not make client-reported balances authoritative. Core gameplay and earned in-run capacity upgrades remain independent of sign-in or purchasing. Verification: analyzer clean, 555 tests passed with five optional skips; final wallet/menu layout checks passed nine tests. See `docs/WALLET_IMPLEMENTATION.md` for delivered behavior and remaining limitations.

## Sources

- **R1:** [Brotato — official Steam listing](https://store.steampowered.com/app/1942280/Brotato/).
- **R2:** [20 Minutes Till Dawn — official Steam listing](https://store.steampowered.com/app/1966900/20_Minutes_Till_Dawn/).
- **R3:** [Deep Rock Galactic: Survivor — official Steam listing](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/).
- **R4:** [Unity: Building an in-game economy](https://unity.com/how-to/building-game-economy-guide-part-2).
- **R5:** [Firebase: Remote Config loading strategies](https://firebase.google.com/docs/remote-config/loading).
- **R6:** [SpacetimeDB: Functions and transactional reducers](https://spacetimedb.com/docs/functions).
- **R7:** [SpacetimeDB: Reducer context, identity and randomness](https://spacetimedb.com/docs/functions/reducers/reducer-context/).
- **R8:** [Apple: In-App Purchase design guidance](https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase).
- **R9:** [Google Play Billing: Security and backend verification](https://developer.android.com/google/play/billing/security).

Research cache: ignored `.firecrawl/runprog-*` files and earlier `.firecrawl/econ-*` primary extracts. Local context: `docs/XP_PROGRESSION.md`, `docs/REGUN_ADMIN_AND_LIVE_BALANCE_PLAN.md`, `docs/research/ECONOMY_RECOMMENDATION_2026-10-23.md`, sibling server `docs/ADMIN_AND_LIVE_BALANCE.md`, and sibling admin `docs/IMPLEMENTATION_STATUS.md`. Current source and newer implementation addenda take precedence over older planning counts.

## 16. Server-authorized purchases and offline ownership — 23 October 2026

This supersedes the app-only purchase path in section15. `/purchase` calls the transactional `account_purchase` reducer under the player's verified email JWT and live session. The private Solo Scrap wallet owns balance and shop ownership. Server catalog version/prices, cloud revision/reset epoch and a persisted operation UUID bind every new purchase; debit, ownership and receipt commit together. The app has no local purchase fallback. It saves operation IDs before requesting and only reconciles ownership after a valid response, with explicit retry for lost acknowledgements.

Legacy balance and already-owned shop skins migrate once from the first accepted profile, recorded as legacy grants rather than invented purchase receipts. Later cloud saves canonicalize wallet fields; new earned Solo Scrap syncs through a monotonic cumulative marker. These earnings remain device-reported, not server-simulated combat proof or cash-backed value. Online Scrap remains separate. No IAP or premium ledger has been implemented.

Cached confirmed ownership stays usable offline and survives app restart without account revalidation. Existing offline progression/play remain available. Purchased shop skins also survive explicit progress reset; account deletion removes wallet/receipts. Another device must sync once to acquire ownership. Admin player details display current Solo wallet and the latest50 labelled legacy/earned/purchase/reset records.

Implementation is local across app/API/admin. Production has not been deployed by this task; old mobile binaries must be replaced because their local purchase code cannot be disabled retroactively while offline. Preserve the existing single-instance persistent-volume and stable publisher deployment contracts.
