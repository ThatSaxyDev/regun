# Earned economy — app, API and admin

23 October 2026. Non-billing implementation. Preserve build19 and the existing
Telling configuration. Apple/Google billing, Credits top-ups and ads remain deferred. The24 October
earned Solo revive implementation defaults disabled pending a reviewed rollout. This pass is local source until the three repositories
are built/deployed. Existing unrelated trailer work is untouched.

## Items2–10

| Item | Implementation |
|---|---|
|2 · Account/offline rules|Email-attached account and server confirmation for new purchases. Owned permanent styles equip from the owner-scoped cache offline. No local purchase fallback. Another device needs one initial ownership sync.|
|3 · Progression|Challenges includes a Field Record, exact existing unlock progress, a suggested next goal and a persistent pinned goal. Results shows the next goal and the Scrap breakdown. Existing weapon/survivor/mastery gates, run XP, recipes and combat balance stay earned.|
|4 · Scrap economy|Centralized the unchanged Solo reward formula in ScrapReward. Original100/100/150 prices stay; three additional finishes cost175/175/225. Admin can review whole-Scrap prices25–5000. These are initial hypotheses, not measured affordability.|
|5 · Cosmetics|Six implemented finishes with actual survivor previews: Copper, Moss, Ivory, Rust, Slate and Dusk. They are color finishes, not newly drawn character skins. Challenge prestige rewards cannot be sold through this catalogue.|
|6 · Wallet/shop|Existing compact wallet placement remains. Shop shows descriptions, prices, availability, previews, current-balance feedback and refresh/offline status. Owned items remain equipable even when hidden from sale.|
|7 · Server authority|Independent immutable catalogue releases; exact catalogue/revision/epoch checks; atomic debit/grant/receipt. Safe cancellation tombstones block a delayed original request, or restore an already committed receipt. No automatic spend after refresh/reconnect.|
|8 · Admin|Toolbar → Scrap economy. Persisted per-origin/channel drafts, review/reason, staging/production, expected-base conflict protection, idempotent publication, audit and restore-history-as-draft. Restore publishes a new reviewed release.|
|9 · Reporting|Authenticated7/30/90-day earned/imported/spent flows, current balances, purchases by finish, request/failure counts. Newly observed unlock milestones include cumulative run count and active minutes; aggregated median/sample counts are explicitly device-reported.|
|10 · Revives|[Revive implementation](REVIVE_POLICY.md):55 pre-run banked Scrap, five active minutes, one normal Solo revive; online authenticated debit/receipt recovery, durable death decision, separate revived personal bests without death-prompt record copy, admin enable/disable. Defaults disabled.|

## Progression and earning

Scrap = collected salvage + floor(kills/10) +15 per boss +floor(seconds/60).
Training grants zero; settlement IDs prevent replay. A synthetic300-kill,
one-boss, ten-minute run yields55 plus salvage. At55 per run, the baseline
finishes represent roughly2,2,3,4,4,5 completed example runs. This is arithmetic,
not a real player average. The shop adds no necessary progression sink or stat
purchase. Current permanent unlocks remain accessible through play and Training
retains its existing access. No active/continued run changes its balance snapshot.

Career instrumentation starts with this app version: `careerSeconds` and
`unlockMilestones` are additive schema3 profile fields. Old unlocked achievements
are not assigned fabricated historical timestamps. A milestone records the first
new unlock's completed-run count and cumulative active seconds. Repeated
settlement cannot increment either again. Offline reports are not anti-cheat
proof and do not determine combat parameters, price or player-specific difficulty.

Mastery remains the existing earned challenge system (no-hit palettes, cycle,
fusion and roster goals). This pass makes progression visible; it does not claim
a new career rank tree, new mastery artwork, remote XP/offer authoring or a fully
validated pacing rebalance. Measure first sessions before changing gates/rates.

## Catalogue and purchase contract

- GET `/economy/v1/catalog`: public compatible production metadata only. A
  per-origin last-good catalogue can be read offline; purchases still require a
  fresh authenticated server comparison against the displayed quote.
- `/account` includes the same production catalogue. Retain the old default ID
  `scrap-cosmetics-1`; published releases use `scrap-cosmetics-rN`.
- The module and gateway both allow only six implemented cosmetic IDs, prices
  and availability. No combat keys, currency products, scripts or arbitrary IDs.
- A changed/hidden offer rejects the old catalogue. The client refreshes; the
  player chooses again. No silent acceptance of a higher price.
- Existing durable purchase operation IDs survive errors. `/purchase-status`
  never spends. `/purchase-cancel` atomically records a cancellation for an
  uncommitted operation; a committed operation is recovered instead of refunded.
- Hiding an item never revokes ownership. Reset preserves purchased styles;
  account deletion retains the existing deletion policy. Guest balances and
  existing shop ownership retain the explicitly audited legacy migration.
- Cosmetic earnings remain a device-reported cumulative grant. This is a
  deliberate offline trust tradeoff, not a suitable ledger for purchased value.

## Administration and metrics

`economy_release`, `economy_channel` and `economy_metric` are private. Existing
operator identity and administrator session checks protect both authoring and
reading reports. Publication requires a reason, a stable request ID and the
expected channel revision. Staging does not affect public production or spending;
it is a catalogue review channel, not a playable staging session.

Admin drafts survive navigation, app restart and rotation in SharedPreferences.
A pending publication freezes editing and retries the same durable request. A
failed draft write blocks initial publication. Review lists old/new prices and
visibility. History can restore values into a draft against the current baseline;
it never rewrites the past or bypasses review.

Metrics count authenticated request attempts, shop visits and purchase failures,
including retries. They are not unique-user conversion, impressions or revenue.
Successful purchases/earnings come from receipts; current balances are a separate
snapshot. Imported balances and progress resets are separate. Request aggregates
retain180 days without player identifiers. Account deletion removes its existing
receipts/profile, so reports are support/operational data, not financial books.
Unlock medians use cumulative observed milestones in synced profiles, across all
available history; they are not filtered by the transaction window. No samples
means no timing claim. There is no covert loss/spend-driven difficulty experiment.

## Deployment and review

Deploy gateway, nginx and module together using the current stable publisher,
secrets, sessions and persistent volume. Never delete data. New routes include
`/economy/v1/catalog`, `/shop-visit`, `/purchase-cancel` and authenticated
`/admin/economy*`. The game/admin need rebuilding for the screens and client
contracts; the server push preceding this task cannot include these new changes.

Review on device: sign in/cancel sign-in; offline new purchase; offline restart
and equip; change/disable a price between display and Buy; cancel a timed-out
intent; restart during purchase; switch accounts; reset preserving ownership;
compact landscape/notches/large text; career pins and new unlock after a loss.
Admin: phone keyboard, draft restart, production conflict, lost publication ACK,
rollback as new release and report empty states. No automated test establishes
commercial value, native comfort or physical balance.

## Verification

- Full game suite:570 passed, five existing optional skips. After final shop/copy
  and receipt-epoch changes, focused economy/purchase/profile/layout/render checks
  passed (10 tests); dedicated wallet/403/retry checks remain covered.
- Admin analyzer and full suite:34 passed. Final phone/desktop economy review and
  persistent-draft tests also pass. Actual font-loaded renders were inspected.
- Server:115 tests passed, typecheck clean and SpacetimeDB module build succeeded.
- Identity gateway:11 unit tests, compiled Node HTTP smoke and typecheck/build
  passed. Disposable real-host JWT/reducer/SQL smoke passed catalogue staging,
  production, conflict/idempotency, invalid combat field rejection, cancellation
  before a delayed spend and recovery of a committed purchase.
- Real nginx container regression passed catalogue, visit, purchase, receipt,
  cancellation and admin routing while retaining raw SQL/unknown-route denial.
- Whitespace checks pass in all three repositories. No production account,
  balance, catalogue, credentials or volume was changed by this verification.

Rendered evidence: build/test-previews/economy-career.png, economy-shop.png and
economy-finishes.png in the game; economy-320.png/economy-1200.png in the admin.
These are widget renders, not device performance or purchase acceptance.
