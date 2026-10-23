# Regun economy and progression recommendation

Research date: 23 October 2026. Proposal only; no gameplay, backend, billing or existing plan is changed by this document. Incorporates the creator's clarification that optional paid revives are acceptable and progression can be redesigned. That clarification supersedes the initial research assumption excluding all paid continues.

## Recommendation

Build a free core game with earned combat progression, cosmetic purchases, supporter bundles and one optional continue per eligible solo run. Rebuild the progression journey before building a large shop. Launch with earned Scrap and direct purchases; add a premium cosmetic/continue currency only when the catalog and repeat purchase demand justify it.

Two economic tracks are useful. Two spendable currencies are not required to establish them. A premium wallet is a purchase interface, not a source of demand or a fairness guarantee.

The proposed promise is: **Every combat tool is earned through play. Purchases offer appearance, support for the game and a capped second chance in ordinary solo survival. Competitive results are earned without purchased assistance.**

A paid revive improves that attempt's outcome. It cannot honestly be described as having zero gameplay advantage. Whether players call it pay to win depends on stakes, availability, progression and necessity. Keep the exception explicit, make equivalent revives earnable, and prevent continued runs from obtaining competitive status or exclusive mastery rewards.

## Research scope and limits

Compared survivor games, top-down/twin-stick roguelites and adjacent co-op/competitive games. Used publisher/developer posts, developer-authored platform listings, official product descriptions and official billing documentation. Community search results were useful for discovery but are not treated as authoritative mechanics specifications. Store reviews were not used to establish current rules.

Prices below are observed US App Store snapshots unless stated otherwise. Listings are incomplete catalogs, can vary by storefront, and do not prove sales, profitability, fairness, purchase conversion or retention. Historical announcements are labeled as historical. No device playthrough or commercial telemetry audit was performed. Regun pricing, cadence and timing proposals are hypotheses requiring testing.

### Comparable games

| Game / model | Verified evidence | Implication for Regun |
|---|---|---|
| **Vampire Survivors mobile** | Free listing with named DLC, including Moonspell $0.99 and Castlevania $3.99. Poncle's January 2023 developer post describes minimal, optional, player-controlled ad monetization. Contemporary reporting describes a once-per-run ad revive with partial health and an optional end-run gold reward. | Closest precedent for a generous core, lasting purchases and optional recovery. Its commercial results do not establish that the same mix can fund our servers. [1–3] |
| **20 Minutes Till Dawn, free mobile** | Listing sells named characters, Katana and Temple Map at $0.99; currency packs; Ad-Free Forever at $11.99. A separate Premium app also exists. | Direct purchases are established in an aimed survivor shooter. Do not confuse editions or infer that purchasable combat content meets our fairness boundary. [4–5] |
| **Brotato, free mobile versus Steam** | Mobile listing contains VIP, currency, No Ads, character bundles and Abyssal Terrors. Steam sells the base game and expansion content. | Same core game can support very different platform economies. Copying its mobile shop is a deliberate product choice, not a requirement of the genre. [6–7] |
| **Soul Knight** | App Store lists Gems, Fish Chips and named character purchases. Chillyroom's v8 PvP preview separately describes earnable Gems, Fish Chips, skins and kill effects. | Dual currency and earned premium rewards can coexist. They introduce many accounting and expectation rules; the currency split alone says nothing about power fairness. [8–9] |
| **Survivor!.io** | App Store lists gems, chapter packs, daily packs, a growth fund and monthly card. Habby's official store exposes further pass/pack offers. | Demonstrates a layered commercial catalog. The public product names do not verify every equipment or revive rule, nor establish a model we should copy. [10–11] |
| **Deep Rock Galactic: Survivor** | Official Supporter Pack description offers golden skins for all four classes and a menu badge. | A very relevant survivor-game example of selling identity and support without describing combat-stat benefits. It also has a paid base game, unlike our proposed free core. [12] |
| **Soulstone Survivors** | Official Corrupted Supporter Pack description offers skins for all 22 Void Hunters and support for continued development. | A substantial visual collection is a clearer paid product than a token recolor. Paid base-game economics again differ from free mobile. [13] |
| **Enter the Gungeon** | Steam offers the game as a premium purchase. | An excellent twin-stick game does not inherently need currency packs, energy or recurring monetization. Premium pricing is a valid fallback if free-to-play economics fail. [14] |
| **Deep Rock Galactic** (adjacent co-op) | Historical Season 01 FAQ describes a free performance pass and optional cosmetic DLC. It explains separating progression rewards from an overcrowded shop. | Useful progression design reference; do not assume paid-base-game cosmetic revenue translates to free Regun. [15] |
| **Brawl Stars** (adjacent mobile top-down combat) | Supercell's cosmetic rework post says Bling did not deliver the hoped-for engagement increase and may have devalued cosmetics; it describes accumulating unspent balances. | Strong warning that a generous currency and large catalog do not automatically produce demand. This is the developer's interpretation, not an independent causal study. [16] |
| **Helldivers 2** (adjacent co-op) | October 2026 official Warbond announcement includes weapons, stratagems and armor and requires Super Credits plus progression. | Premium content can include mechanics in co-op, but it creates balance questions. Do not use another game's acceptance as proof that Regun's paid weapons would be harmless. [17] |

The evidence supports several viable models, not one genre standard. For our stated goals, use Vampire Survivors' restrained placement philosophy and supporter/cosmetic product ideas from the Deep Rock/Soulstone examples. Avoid adopting an extensive progression shop merely because Survivor!.io has one.

## What Regun already provides

Current source, rather than the older four-weapon planning table, is the baseline. `PlayerProfile` already tracks earned Scrap, achievement-based survivor/weapon unlocks, boss victories, discoveries, cosmetic ownership, and separate assisted records. Current loadout catalogs have grown well beyond that old plan. Training permits experimentation.

`RegunGame.earnedScrap` currently pays run Scrap + floor(kills/10) + 15 × bosses + floor(seconds/60). For example, 300 kills, one boss and ten minutes gives **55 Scrap** before extra run Scrap. This is arithmetic, not an observed average. The three existing shop palettes cost 100, 100 and 150 Scrap. A large currency sale would overwhelm this tiny set of sinks.

Cloud identity/profile syncing is implemented, but its documentation explicitly says offline/client snapshots do not grant paid or ranked authority. Profile conflict resolution is not a purchase ledger. `assisted` currently includes aim assistance; continued status needs its own field so accessibility and purchases are not conflated.

The October 19 monetization plan remains historical input. Retain its purchase-validation and settlement concerns. Reconsider its paid weapon/character products under the creator's clarified preference for earned combat progression. Do not implement those products just because they appear in the old document.

## Progression to build before optimizing the shop

### 1. Run progression: combat power is earned here

Keep XP, upgrade choices, boss cores, fusions and tactical build decisions inside the run. Do not sell initial upgrades, better offer odds, additional fusion capacity, grenade charges or paid rerolls. Never withhold an accessible control or an important training tool behind payment.

Keep the live-balance snapshot stable throughout an active run. An economy experiment must not silently change combat difficulty for buyers, non-buyers or losing players.

### 2. Career progression: understandable goals and new playstyles

Add a career view that answers: what did I achieve, what can I unlock next, and what changed since the last run? Career XP/rank is a non-spendable progress measure, not another wallet. Separate it from run XP in copy and UI.

Use a small starter path followed by branching weapon and survivor goals. Proposed target: introduce an alternate weapon within the first one or two completed attempts, then let the player pin one next unlock. These are playtest targets, not a promise that every player must progress at the same speed. Do not force every player through the entire arsenal in one fixed sequence.

Retain existing achievement identity: e.g. grenade activity develops the ordnance survivor path; reload activity develops the reload specialist. Show incremental progress after a loss. Replace opaque or repetitive gates where telemetry and interviews reveal frustration. Account rank can provide a deterministic alternate earned unlock route for goals that are excessively skill-specific, without introducing paid skips.

Prefer horizontal unlocks: weapons and survivors with strengths, weaknesses and different builds. Start without a permanent damage/health tree. Permanent earned stat growth is possible in the genre, but it complicates encounter tuning, new-player co-op and ranked comparisons. If later added, isolate its rules and normalize competitive modes; never sell its currency or acceleration.

Do not make Scrap simultaneously fund a necessary stat tree and death recovery. That creates a survival tax: players who struggle spend their progress staying alive while successful players snowball.

### 3. Mastery: long-term goals money cannot replace

Give weapons/survivors a small number of visible mastery steps: meaningful use, a build-specific feat, and an uncontinued challenge. Reward distinctive finishes, titles, badges, shelter trophies or result poses. Avoid hundreds of trivial repetitions.

Keep the strongest prestige signals achievement-only. Paid looks should have equal artistic care but a different identity; a paid item must not imitate an earned no-hit/boss-mastery badge.

An optional weekly objective can give direction, but unfinished tasks should not reset a streak or erase earned value. Favor rotating suggestions over login obligations. Build a season only after there is a reliable production cadence.

## Currency and spending model

### Recommended first release

| Value | How acquired | Allowed use | Explicit boundary |
|---|---|---|---|
| **Run XP / cores** | Playing the current run | Build choices / fusions | Not sold or banked as paid value |
| **Career and mastery progress** | Playing and completing goals | Unlock tracks / earned recognition | Non-spendable; no paid acceleration |
| **Scrap** | Normal runs and authored rewards | Earned cosmetics, shelter decoration, an optional revive | Not sold initially; no required combat-stat spending |
| **Owned paid products** | Direct localized store purchase | Named cosmetic sets; a small continue-charge pack | Exact contents, durable ownership/ledger |
| **Continue charges** | A modest earned allowance or purchased pack | One eligible solo continuation | Inventory count, not a general currency |

This is one earned wallet plus owned items. It avoids forcing someone to buy Gems before buying the thing they actually want. A player without Scrap can buy a small continue pack if they choose; they should also be able to bank one before starting a run.

Avoid selling earned Scrap itself. Keeping it unpurchasable protects future design options and preserves the meaning of achievement-earned spending.

### If we later introduce a premium currency

Use one clear premium balance, provisionally Credits, for selected cosmetics and continues only. Give occasional small earned grants if desired; classify purchased and promotional grants separately in the ledger even when displaying one balance. Define spend priority and refunds. Do not permit premium-to-Scrap conversion, stat purchases, rank skips, player trading or cash-out.

Make exact-item purchase possible or make pack quantities match useful purchases. Show the full local checkout amount and leftovers. Existing purchases retain their promised contents. Apple's guidelines prohibit expiration of purchased currency. [18] No expiry mechanic should be used to drive spending.

Premium currency is justified when players regularly combine purchases across a substantial catalog, not because two numbers look like a professional economy. Existing direct products should not become unusable if a wallet is later added.

## Revives: a deliberate, limited gameplay exception

### Proposed rule

- At most **one economy-funded continue per ordinary solo run**, regardless of whether paid with Scrap, an earned charge, a purchased charge or, later, an optional ad. Restarting the app must not reset eligibility.
- Do not initially offer economy-funded continues in PvP, ranked/daily seeded challenges, uncontinued mastery trials or shared online rooms. Online continuation needs team rules, authority and disconnect handling first.
- Use the same recovery health, protection and safe placement for every payment source. Example for testing: partial health, a brief protection window and readable re-entry. Reuse deployment infrastructure where appropriate, but design recovery separately from Training's protected-health rules.
- Preserve the build and current boss state. Do not add damage, a boss reset or a premium-only recovery buff. Prevent an immediate unavoidable repeat death without erasing the challenge.
- Bank ordinary rewards earned before death. End Run remains clearly visible. Choosing it must not forfeit previously earned rewards.
- Label records as **Uncontinued** and **Continued** independently of aim assist. A continued run can earn ordinary Scrap, career progress and general unlock progress. Specific prestige/competitive achievements requiring no continue remain unavailable.
- Keep recovery from a crash or server failure separate and free. Do not sell fixes for technical failures.

### Placement and pricing

Offer a calm recovery panel at eligible death. Show existing Scrap/charge balance, exact recovery effect and End Run. If funds are insufficient, offer a small purchase as an optional secondary action. No auto-selected purchase, false countdown or repeated pop-up after dismissal. Freeze the recovery state while checkout is open; a delayed/pending transaction must not lose paid value.

Offer continue packs in the normal shop too, so death is not the only purchase moment. If the player buys a pack while a run becomes unrecoverable, preserve the purchased charges for later rather than silently consuming one.

First experiment: a three-charge pack around **US$0.99**, subject to store price availability and localization. This is a hypothesis, not a validated willingness-to-pay claim. Limit purchase quantity/visibility so the shop does not imply unlimited continues within a run.

Do not set a Scrap revive cost yet. Measure earned Scrap per ordinary active minute, balance distribution and cosmetic purchase cadence. A preliminary target could be a revive costing roughly one normal run's Scrap earnings; test whether that feels like meaningful optional spending or an unfair loss tax. Supply a small earned starter allowance so players understand recovery before buying it.

Continuing extends runs and therefore increases expected earned rewards. Record those extra earnings and progression advantages; do not pretend a one-continue cap removes them. Ensure unlocks remain reasonably achievable without continuation. If continued play becomes the practical best farming requirement, revise reward/encounter design before selling more charges. Avoid harsh post-purchase reward penalties; state all rules before purchase.

### Ads, if adopted

Start without an ad SDK if it delays validating the core loop. Later test an explicitly optional rewarded revive using the same cap and recovery as every other source. No forced interstitials between attempts. An unavailable/failed ad must not spend a charge or imply the player received a reward.

Ad and IAP economics can conflict: if ad recovery is unlimited in frequency across runs, some charge demand disappears. That may be acceptable if overall retention and net revenue improve. Measure it rather than secretly degrading the ad option. Do not sell Remove Ads until exact ad-removal benefits exist and are clearly described.

## What people should want to buy

| Product hypothesis | Why it could fit | First price hypothesis, not a forecast |
|---|---|---|
| Supporter / Founder's set | Authored survivor outfit, finish, profile identity and shelter object; fixed contents | $2.99–$4.99 |
| Themed cosmetic set | Several coherent, previewable items; equal combat silhouette/visibility | $2.99–$5.99 |
| Small continue pack | Optional recovery for a build the player wants to keep trying | Three for $0.99 |
| Larger visual collection | Meaningful art across multiple survivors/weapons | $5.99–$9.99, only if contents justify it |
| Cosmetic season, later | Free progress plus paid visual rewards without combat acceleration | Test only after content/retention capacity exists |

Regun's small top-down sprites constrain skin value. A recolor may be barely noticeable. Prioritize equipped-kit previews, a readable distinctive outfit, co-op lobby/result presentation and the shelter's visual identity. Paid effects must not obscure hostile warnings, change effective hitbox reading, hide the survivor or alter weapon timing/audio cues. Keep cosmetic rendering bounded.

Do not sell combat weapons, survivor abilities, gear rarity, energy, rerolls or stat boosts in the initial economy. Keep meaningful offline solo access. A later paid expansion can sell authored experiences, but combat-tool access and shared queues require explicit design review. An expansion must not become the mandatory best farming route or a stealth power pack.

Do not start with a subscription: recurring charges require reliable recurring value. Consider a non-renewing cosmetic collection/season before an auto-renewing membership. Avoid paid randomness and paid track-completion skips.

## Revenue optimization without designing frustration

Use context to improve relevance: an outfit for the survivor the player equips; a mastery celebration after an achievement; recovery at an eligible death. Start with visible shop access, a post-run cosmetic preview and the single recovery panel. Suppress repeat prompting after a decline. Do not interrupt the first tutorial with checkout.

Personalization should recommend content, not secretly charge desperate players more. Do not manipulate difficulty, reward rolls or death timing by spend propensity. Avoid sensitive-data targeting or treating loss streaks as permission for greater pressure. Publish clear product contents and stable pricing policies.

Optimize net contribution per retained player, not just revive acceptance. Instrument tutorial completion, first alternate unlock, next-goal selection, run returns, D1/D7/D30 retention, earned Scrap/minute, balance distribution, unlock time, cosmetic interest, purchase conversion, repeat purchase, refund and support rates. Separate platform, region, acquisition source and new/returning cohorts. Use benchmark reports for context, not as a substitute for our baseline. [21]

For revives, track eligible deaths → offer views → source chosen → completed recovery → useful additional play → eventual settlement → next-day return. Also track immediate re-deaths, continued reward share and declined-offer exits. A paid revive that extends play for only a few seconds is likely poor value even if it converts.

Run stable, randomized experiments with exposure recorded and enough sample to interpret the result. Change one major variable at a time. Retain an unchanged cohort. Check retention, complaints and refunds alongside revenue; early small samples and payer/non-payer comparisons cannot prove causality.

Illustration only: 10,000 monthly players × 2% buying × $5 monthly gross spend = **$1,000 gross monthly IAP revenue**. Those inputs are not benchmarks or a Regun forecast. Fees, taxes, refunds, server costs, content production and acquisition reduce contribution. A larger wallet catalog cannot repair an unsustainable acquisition/retention equation.

## Server, admin and mobile responsibilities

Build on the existing account and live-config work rather than trusting local profile balances with purchased value.

**Server:** canonical ownership; immutable currency/inventory ledger; unique purchase transaction mapping; platform verification; atomic grant/spend; refunds/revocation; account binding; per-run continue eligibility; and idempotent final settlement. Duplicate delivery/retry cannot mint extra charges. Google specifically recommends backend purchase verification, entitlement only for PURCHASED transactions and backend acknowledgement. [19]

**Admin:** versioned product catalog, economy definitions, grant reasons, earn rules and event schedules; preview/staging; expected-base publish/rollback; audit history and role checks. Allowlist product categories and reward types. Fairness invariants such as the continue cap and competitive prohibition remain enforced in code/server validation, not editable into paid damage by a shop configuration.

**Mobile:** bundled/cached compatible catalog; product availability and localized prices from platform billing; purchase/pending/restore UI; accurate previews; retry-safe calls; offline earned progression. Apple distinguishes consumables and non-consumables: spent charges do not restore as new purchases; unspent purchased inventory must be recoverable from our account ledger. [20]

Economy configuration and combat balance are separate versioned contracts. Snapshot rewards/continue terms at run creation or explicit offer creation, so an admin publish cannot change the value already shown. Catalog updates cannot replace native store pricing/product setup. Server configuration also cannot add unimplemented mechanics or missing art without a supported content-delivery path and client capability checks.

Solo offline play is less verifiable than server simulation. Preserve it, but classify reward authority. Never accept an uploaded local balance as proof of purchased currency. Allow existing earned legacy Scrap to remain valuable; prevent unsupported client snapshots from granting paid-only ownership or ranked status. If earned Scrap can buy the same paid cosmetics, fraud can bypass revenue even without converting to premium currency: make that tradeoff explicit before launch.

Offline purchased inventory requires a deliberate design: begin with online authorization to spend cash-backed charges, while ordinary offline play and earned recovery still work. If offline paid-charge spending is later promised, build bounded reservations and reconciliation; do not improvise local decrements and multi-device merges.

Current game-over immediately starts settlement. Add an explicit pending-recovery phase before final settlement, or an equally durable settlement-delta design. Do not append a continue button after a run has already been paid out and cleared. Save continue-used state, confirmation/spend ID, run/account binding and recovery phase. Recovery/restart/crash must not duplicate rewards or spend twice.

Billing compliance needs a final region/platform review at implementation. Apple rules have storefront-specific payment exceptions; this proposal uses standard store billing as the baseline and does not assume a universal external-checkout rule. [18]

## Implementation order and decision gates

1. **Progression discovery:** instrument current earn/unlock pacing; map first sessions; test a next-goal career screen. Preserve existing unlocks and balances. Define the continued/uncontinued reward policy.
2. **Earned economy:** launch improved mastery, cosmetic sinks and a small earned-revive allowance. Observe recovery usefulness, farming effects and inflation before charging.
3. **Commerce foundation:** store sandbox products, verified ledger, account restore/refunds, idempotent continue and settlement. Review weak network, pending payment, crash and account-switch paths.
4. **Small paid catalog:** supporter set, themed set and small continue pack. No large currency bank, auto-renewing subscription or multi-tier pass required.
5. **Measured iteration:** compare overall contribution and retained-player outcomes; decide whether optional reward ads, more visual collections or a premium wallet provide real value.

Physical-device reviews must cover continued-run recovery, controls, native checkout interruptions, art readability and audio. Automated simulation is not proof of commercial value, player comfort or fairness.

## Sources

1. [Vampire Survivors US App Store](https://apps.apple.com/us/app/vampire-survivors/id6444525702) — observed free app and DLC catalog.
2. [Poncle developer update, January 2023](https://store.steampowered.com/news/app/1794680/view/3637250052875666496) — primary historical monetization rationale.
3. [GamesIndustry.biz, mobile release reporting](https://www.gamesindustry.biz/vampire-survivors-dev-says-clones-forced-our-hand-on-mobile-port) — contemporary reported revive/gold placements; not a current play verification.
4. [20 Minutes Till Dawn free, US App Store](https://apps.apple.com/us/app/20-minutes-till-dawn/id1635123906) — observed character, weapon, map, currency and ad-free products.
5. [20 Minutes Till Dawn Premium, US App Store](https://apps.apple.com/us/app/20-minutes-till-dawn-premium/id1630887189) — separate edition.
6. [Brotato free mobile, US App Store](https://apps.apple.com/us/app/brotato/id6445884925) — mobile product catalog.
7. [Brotato on Steam](https://store.steampowered.com/app/1942280/Brotato/) — premium base game / content model.
8. [Soul Knight US App Store](https://apps.apple.com/us/app/soul-knight/id1184159988) — observed currency and character products.
9. [Chillyroom Soul Knight v8 PvP preview](https://soulknight.chillyroom.com/et/article/base/67) — developer description of earnable reward types.
10. [Survivor!.io US App Store](https://apps.apple.com/us/app/survivor-io/id1528941310) — observed commercial product families.
11. [Habby Survivor store](https://store.habby.com/game/3) — publisher web catalog snapshot.
12. [Deep Rock Galactic: Survivor Supporter Pack, Xbox](https://www.xbox.com/mk-MK/games/store/deep-rock-galactic-survivor-supporter-pack/9nk76606xfd0) — official cosmetic contents.
13. [Soulstone Survivors Supporter Pack, Steam](https://store.steampowered.com/app/3615530/Soulstone_Survivors_Supporter_Pack/) — official cosmetic contents.
14. [Enter the Gungeon, Steam](https://store.steampowered.com/app/311690/Enter_the_Gungeon/) — premium twin-stick reference.
15. [Deep Rock Galactic Season 01 FAQ](https://www.deeprockgalactic.com/season01-faq) — historical primary progression/design explanation; not asserted as a full current season audit.
16. [Supercell: Changes to Bling, Shop, and Cosmetics](https://supercell.com/en/games/brawlstars/blog/news/changes-to-bling-shop-and-cosmetics) — primary discussion of cosmetic inflation and perceived value.
17. [PlayStation Blog: Scope of Authority Warbond](https://blog.playstation.com/2026/10/13/helldivers-2-scope-of-authority-premium-warbond-launches-oct-20/) — official October 2026 paid-content example.
18. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — purchased-currency expiry, restoration and platform billing framework.
19. [Google Play Billing: security](https://developer.android.com/google/play/billing/security) — backend verification, pending states, acknowledgement and replay prevention.
20. [Apple In-App Purchase HIG](https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase) — product types, total prices and purchase UX.
21. [GameAnalytics 2026 Mobile & PC Benchmarks](https://www.gameanalytics.com/reports/2026-mobile-pc-gaming-benchmarks) — optional external benchmarking reference; no numerical retention targets inferred here.

Research cache is in ignored `.firecrawl/econ-*` files; it is evidence, not a shipped game dependency. Principal local audit inputs: `lib/models/player_profile.dart`, `lib/game.dart`, `lib/data/loadout.dart`, `lib/views/collection_view.dart`, `docs/CLOUD_IDENTITY_IMPLEMENTATION.md`, and the existing monetization/live-balance plans.
