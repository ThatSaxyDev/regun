# Regun Credits — research and delivery plan

26 October 2026. **Planning only; implementation, store setup, deployment and sales are not authorized by this document.**

The creator selected **cosmetics and optional Solo continues** as the initial Credits uses. Scrap stays earned-only; combat unlocks, mastery, XP, cores and power are not sold. This plan covers the game (`regun`), account gateway/database (`regun-server`) and operator app (`regun-admin`). Recommendations below are proposals, not accepted prices, shipped capabilities or proof of commercial viability.

## 1. Recommended direction

Build an iOS-first, account-bound Credits wallet and prove it in TestFlight before accepting real money. Start with one consumable top-up product, one separate premium cosmetic and an optional Credits payment method for the existing Solo recovery. Expand the catalogue only after delivery, refunds and device recovery work reliably.

Treat these as two distinct transactions:

1. **Top up:** Apple purchase → verified transaction → Credits grant.
2. **Spend:** explicit player confirmation → atomic Credits debit and cosmetic ownership or continue receipt.

A top-up never automatically buys the item or revives the player. If checkout finishes after the player leaves a death screen, their Credits remain available. Do not sell a parallel continue-charge inventory in this first version; Credits already supplies that inventory function.

## 2. What the audit establishes

| Layer | Existing source foundation | Credits work required |
|---|---|---|
| Game | Compact wallet, verified-email account flow, durable purchase intent/status recovery, owner-scoped cached cosmetics, checkpointed Scrap revive | Store product loading/checkout, premium wallet model, separate top-up journal, premium catalogue and currency-aware continue UI |
| Gateway | Authenticated account routes, account snapshots, purchase/status/cancel and admin routes | Apple transaction verification, account binding, notification ingress, reconciliation and commerce capabilities |
| Database | Private Scrap wallet, transactional purchase/ownership, operation receipts, run-scoped revive records | Separate premium wallet/ledger, globally deduplicated store transactions, grant provenance, refund adjustments and cross-currency continue exclusion |
| Admin | Reviewed immutable Scrap catalogue publishing, wallet history, reports and revive policy | Credits catalogue, transaction/support views, environment-specific controls and commerce reporting |
| Deployment | Explicit nginx allowlist, private database bridge and persistent volume | Explicit commerce/notification ingress, server secrets, migration/backup and restart/replay validation |

Primary audit anchors: `lib/widgets/wallet_bar.dart`, `lib/services/account/account_controller.dart`, `lib/services/account/account_storage.dart`; sibling server `spacetimedb/src/wallet.ts`, `schema.ts`, `identity.ts`, `solo_revive.ts`, `identity/src/service.ts`, `http.ts`, `economy.ts`, `admin.ts`, `deploy/nginx.conf`; sibling admin `lib/screens/economy_page.dart`, `revive_policy_page.dart`, `server_screens.dart`.

Important limits:

- Scrap initialization imports legacy profile value, and later earnings accept a monotonic device-reported total. Neither mechanism may grant Credits.
- Progress reset currently clears Scrap. Account deletion removes the Scrap wallet and account action records. Do not copy those lifecycles into paid accounting without a deliberate policy.
- Existing six finish IDs remain earned-Scrap products; do not silently move them behind Credits. Earned prestige rewards remain earned.
- Solo gameplay/time/checkpoints remain client simulated. A server-authoritative debit does not make local survival or a restored death save tamper-proof.
- Admin catalogue staging is currently a publication workflow, not automatic isolation of playable sandbox wallets.
- Local source is not proof of the deployed revision or an enabled revive policy. Inventory running game/admin/server versions before the pilot.

Existing checks run during this research: 25 game tests, 7 admin tests, 21 wallet/economy/weapon/revive module tests and 26 gateway unit tests passed. No new tests or application code were added. These are focused existing checks, not a full verification run, purchase acceptance or production audit.

Related contracts: [earned economy](ECONOMY_IMPLEMENTATION.md), [wallet](WALLET_IMPLEMENTATION.md), [Solo recovery](REVIVE_POLICY.md), [earned weapon ownership](ARMORY_IMPLEMENTATION.md), [earlier research](research/ECONOMY_RECOMMENDATION_2026-10-23.md). Preserve their implemented gameplay unless a separately approved decision changes it.

## 3. TestFlight and Apple setup

TestFlight apps use Apple's sandbox; purchases do not charge testers. Apple supports testing actual configured products and server interactions there. A public App Store launch is not required to start this testing. A Sandbox Apple Account provides additional test controls; ordinary TestFlight purchase attribution and signing into special sandbox controls are distinct flows. Follow Apple's current device instructions rather than asking every tester to sign out unnecessarily. [Apple sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)

Account Holder checklist before the pilot:

1. Confirm active developer membership and Paid Apps Agreement. Review Business for outstanding banking/tax requirements for eventual sales; do not assume existing TestFlight access establishes readiness.
2. Confirm the game's actual bundle ID and App Store Connect app record; register stable consumable product IDs under that app. Do not invent identifiers in advance of that check.
3. Supply product name, localization and price; allow for metadata propagation. Keep granted Credits per product immutable after it has been sold; use a new product ID for materially different contents.
4. Configure server credentials and separate sandbox/production notification destinations as required by the selected integration. Keep signing keys off clients and out of Git.
5. Prepare test accounts and cases for interrupted purchases, refunds and account changes. Provide reviewer access and clear purchase/recovery instructions for eventual release.

Apple requires its purchase mechanism for this proposed native digital-goods flow and prohibits expiry of purchased currency. Use Apple-localized product prices, with no hard-coded dollar checkout labels. StoreKit restoration alone must not be treated as our accounting record of remaining consumable Credits; account synchronization supplies the wallet and owned cosmetics. [App Review Guidelines §3.1.1](https://developer.apple.com/app-store/review/guidelines/), [product types/setup](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)

Production sale additionally needs the applicable app/IAP review and distribution setup. A successful sandbox purchase is not approval to sell.

## 4. Billing integration decision

| Option | Benefit | Responsibility/tradeoff |
|---|---|---|
| Flutter store integration + direct Apple server verification | Fits existing gateway and transactional database; one Regun spending authority | We own verification, notification processing, reconciliation, key operations and future Android integration |
| RevenueCat purchase handling + Regun ledger | Managed purchase infrastructure and operational tooling; future stores through one vendor | Vendor fees/availability, account alias rules, webhook verification and exact grant reconciliation still need review |
| RevenueCat Virtual Currency as wallet authority | Existing currency grants/balances and server spend APIs | Its wallet and Regun ownership/revive database cannot be assumed to commit atomically; requires a durable multi-step recovery design |

RevenueCat does support consumables and a currency service; it is not limited to subscriptions. Its documented currency mutations normally use a backend secret API, and sandbox access controls are not evidence that our production/test ownership is isolated. [Non-subscriptions](https://www.revenuecat.com/docs/platform-resources/non-subscriptions), [Virtual Currency](https://www.revenuecat.com/docs/offerings/virtual-currency)

**Recommendation to validate:** use Regun's database as the sole wallet/spending authority. Evaluate direct Apple verification first because iOS is the present scope and wallet+ownership+continue changes can commit together. Do not create two independently spendable balances. RevenueCat remains a valid verification alternative if its actual operating cost/support advantage wins the comparison.

Before choosing libraries, perform a bounded integration feasibility check: current Flutter/StoreKit support for account tokens, signed transaction evidence, pending/replayed transactions and deferred completion; Node verification library/runtime compatibility; sandbox refund and server-notification behavior. Record current dependency versions, vendor pricing/limits and maintenance costs in the decision record. Do not rely on client success callbacks or an entitlement boolean as a consumable balance. The feasibility check is a future implementation task, not work authorized by this research pass.

## 5. Product and price proposal

For sandbox testing, use this deliberately small model. USD values are hypotheses subject to store availability and later player research, not actual local prices or a revenue forecast.

| Offer | Pilot proposal | Reason |
|---|---|---|
| Small top-up | 100 Credits, around US$0.99 | One useful unit; no large commitment |
| First premium finish | 100 Credits | One small pack buys it exactly |
| Later larger cosmetic | 200 Credits | Straightforward multiple; requires separately approved art/value |
| Eligible Solo continue | 25 Credits | One pack funds four; no forced remainder |

Begin with only the small pack. No first-purchase bonus, expiry, subscription, loot box, personalized price, artificial sale timer or large-pack discount. If a second pack is useful, initially consider a simple multiple at roughly the same unit value rather than manufacturing pressure to buy more.

The premium cosmetic needs its own distinct ID, actual in-game preview, survivor/weapon applicability and finished art. It cannot be a renamed copy of an existing earned finish or an earned prestige reward. No damage, hitbox, enemy-warning, upgrade-odds or progression advantage. Do not commission a large art catalogue before the pilot item is reviewed.

Do not infer that 25 Credits and 500 Scrap are economically equivalent. Measure time-to-earn, player understanding, top-up reluctance and whether paid recovery becomes the practical farming route. Change future quotes transparently; keep prior receipts and promised product contents intact.

## 6. Solo continue policy

Retain current recovery unless explicitly revised: normal Solo only, after 300 active seconds, at most one economy-funded recovery per run, same build and boss state, half max health rounded up, current magazine refill and two seconds of protection. No grenade refill or premium-only advantage. Preserve revived record categories and normal reward rules.

- Scrap method keeps its 500 pre-run-banked requirement and existing online debit checks.
- Proposed Credits method uses confirmed current wallet funds, including a top-up at death. This is an intentional difference to review; do not silently remove Scrap's pre-run requirement.
- Both methods compete for **one shared account/run recovery receipt**. Racing requests in different currencies must never debit both or recover twice.
- The offer names the payment source and exact price. Never fall back from Scrap to Credits automatically. End run remains clearly available; no countdown.
- Insufficient Credits can lead to optional top-up. Keep the death checkpoint paused and durable, then require a fresh explicit continue confirmation after top-up. Pending Apple approval does not resume combat or count as paid.
- Once a recovery is committed, disabling sales/policy cannot prevent its completion. Paid value must be recovered or compensated if the technical recovery cannot be delivered.
- Refund a failed-to-deliver recovery through one server adjustment tied to its debit, only after preventing late activation. Uncertainty alone is not proof of failure; first reconcile the durable state. A completed recovery is not refundable through this technical compensation path.

Document the local-gameplay trust limit explicitly. Offline checkpoint copies can undermine strict single-use gameplay even when the server prevents a second debit. Do not market this as ranked authority; assess abuse exposure before selling Solo recovery. Keep fixes for crashes/server failures free.

## 7. Wallet, identity and transaction design

Recommended new private records, with names finalized during contract review:

| Record | Required purpose |
|---|---|
| Premium wallet | Account + verified environment, integer balance, revision and spending status |
| Store transaction | Unique store/bundle/environment/transaction identity, immutable product grant, account binding, verification and refund state |
| Ledger entry | Immutable signed amount, reason, source transaction/operation, account, environment and sequence |
| Grant allocation | Purchased/promotional origin and which grants funded each spend, enabling bounded refunds |
| Premium ownership | Owner/item/environment and its successful spend receipt; independent of profile uploads |
| Notification inbox | Verified event identity, durable processing/retry status and deduplication |
| Recovery receipt | One shared account/run identity, currency/price/quote, prepared/activated/closed/compensated state |

All amounts are bounded integers. Verify product, bundle, environment, transaction status and account association before a grant. Use an opaque stable server-issued UUID account token for Apple's account association; no email in store metadata. Never reassign a transaction simply because a different account submits it. Apple documents account tokens and server transaction/refund APIs. [Apple server API](https://developer.apple.com/documentation/appstoreserverapi), [account-token integration](https://developer.apple.com/videos/play/wwdc2025/249/)

The gateway performs external verification. Deterministic reducers receive only an authenticated, narrowly authorized commerce command and commit the transaction record, ledger entry and wallet update together. A player-accessible reducer cannot accept arbitrary verified=true, grant amounts or ownership. Keep commerce ingestion permission distinct from ordinary account operations and admin catalogue editing.

Deduplicate the store transaction globally across accounts within its verified namespace, not just by a client request UUID. Product quantity/grant mapping comes from trusted immutable configuration and verified quantity. Notifications and app submissions converge on the same record; either can arrive first. Repeated input returns the prior outcome. Retain sufficient deduplication evidence across deletion/recreation to block replay, under the reviewed retention policy.

The durable server grant precedes acknowledging/finishing the delivered store transaction. The selected SDK's automatic completion behavior must be checked. Lost replies, retry and reconnection must converge without another grant. Reconcile periodically and on explicit recovery; notifications alone are not a delivery guarantee.

## 8. Lifecycle, refund and environment rules

- **Sign-in:** existing Regun account required before top-up/spending. Guest play remains available. Switching accounts never transfers a pending purchase or displays the old wallet.
- **Offline:** cached owned cosmetics remain equipable. Balance may display with a last-synced label; new Credits spending/top-ups require service availability. Profile conflict resolution cannot overwrite premium records.
- **Reset:** preserve Credits and paid ownership while resetting gameplay progress; old run receipts stay terminal and cannot reactivate. Do not couple financial idempotency to the resettable gameplay epoch.
- **Deletion:** preserve the existing explicit deletion flow. Before sales, approve a clear policy for balance/ownership loss, minimal transaction retention, replay prevention and support. Separate retained commerce evidence from a usable deleted account; do not silently recreate it on notification delivery. Exact retention periods require policy review, not an invented number here.
- **Sandbox:** isolate wallets, ledger, ownership, receipts and reports. Verified Apple environment controls routing; a client flag cannot turn sandbox value into production value. No automatic launch-day conversion of test balances or test cosmetics. Test progress/record handling must also prevent a free sandbox continue from improving a production account's career records; use an isolated test profile or segregated run settlement.
- **Refunds:** verify and deduplicate refund/reversal events; never delete history. Allocate spending consistently (proposed promotional first, then oldest purchased grant). Reverse unused refunded value once. If refunded value was already spent, track a deficit separately and route to support/restricted premium spending; never deduct Scrap or automatically charge money. Any future offset/revocation policy must be disclosed and approved before sales. Do not undo a completed run or revoke independently earned ownership. Handle refund reversals with compensating entries.
- **Capacity:** reaching a wallet cap cannot silently discard a verified purchase. Design overflow escrow/recovery before allowing sales near the cap.

Apple manages the money refund; a Regun ledger adjustment is the corresponding game-side record, not an issuance of cash. Account for Apple consumption-information requests only under the applicable consent/data rules. Verify the exact notification set and missed-event recovery in the integration check.

## 9. API and game delivery contracts

Proposed route families (names are design candidates):

| Operation | Contract |
|---|---|
| Commerce capabilities/catalogue | Supported store/environment, immutable product IDs/grants, premium item prices and current policy revision; no checkout price fabricated by API |
| Wallet read | Authenticated owner/environment snapshot with revision, synchronization state and owned premium items |
| Submit/reconcile transaction | Authenticated evidence ingestion; validates original account binding; returns committed/pending/rejected outcome |
| Premium cosmetic spend/status | Quote revision + item + durable operation ID; atomic balance/ownership/receipt; status never spends |
| Existing Solo recovery extension | Currency-aware quote/debit, shared once-per-run record, status/close/activate/compensate transitions |
| Apple notification ingress | No player-session requirement; signed-payload verification, durable deduplication and retry semantics |
| Admin commerce | Authorized catalogue/policy publishing, read-only transaction investigation and separately restricted corrections |

Add every public route to the real nginx allowlist and test through ingress, not only Node. Maintain payload limits, rate limits and secret-safe logs. Successful notification acknowledgement must mean durable acceptance, not that a volatile callback started.

The game needs independent top-up and spending journals so neither overwrites an existing uncertain Scrap purchase. Scope pending state to account/environment/transaction. Handle product unavailable, cancelled, pending approval, verified but delivery pending, completed, refunded and service failure. Never grant based on the purchase sheet closing.

Wallet stays unavailable until an actual initialized snapshot is confirmed; unknown is not zero. Preserve the pixel UI, large text, accessible exact prices, existing wallet positions and owned-item previews. No shop overlay during active combat. Background/checkout keeps the death decision paused. A successful grant has a concise confirmation; no compulsory celebration or automatic purchase chain.

Legacy clients continue using Scrap. Gate new commerce capability and unsupported premium item IDs without blocking offline game entry. New API snapshots must not make old profile saves capable of deleting premium ownership.

## 10. Admin and operations

Provide three clearly separated surfaces:

1. **Catalogue/policy:** product-to-Credits mappings, premium cosmetics/quotes, sales visibility and continue policy. Reuse reviewed drafts, reason, expected revision, immutable releases and safe retry. Cash prices remain configured in App Store Connect. Sold product contents are not editable grants.
2. **Player support:** wallet/environment, ownership, linked store transaction, grant/spend/refund/compensation history and unresolved delivery. Read-only by default. Corrections require a dedicated permission, reason, idempotent operation and audit; no arbitrary balance overwrite button.
3. **Reports:** store purchases, verified grants, spend by use, refunds, pending-delivery age and reconciliation failures. Separate sandbox from production, gross store events from Credits spend, and operational estimates from actual Apple proceeds. Reconcile financial reporting with App Store Connect; Credits consumed is not revenue.

Use independent controls for new top-ups and new Credits spends. Disabling either must leave transaction ingestion, reconciliation, existing ownership and already-paid recovery available. Keep administrator secrets and store credentials server-side.

## 11. Milestones and acceptance

| Phase | Deliverable | Exit gate |
|---|---|---|
| A · Decision record | Scope/prices/art, recovery rules, refund/deletion policy, billing option and Apple readiness inventory | Creator approves product choices; all purchase responsibilities have an owner; no unresolved policy that could lose paid value |
| B · Server foundation | Versioned contracts, premium ledger, grant/spend/refund state machines and migrations | Forged grants rejected; concurrent/replayed requests preserve ledger invariants; backup/restore retains deduplication |
| C · Sandbox vertical slice | One Apple product through native checkout to durable wallet and admin history | Real TestFlight purchase credits once despite app kill/API timeout/account switch; sandbox never changes production |
| D · Premium cosmetic | One finished preview/item and atomic ownership purchase | Lost reply/reinstall/offline equip/hide/reset/account switch work; existing Scrap ownership is unchanged |
| E · Solo continue | Explicit Credits option and shared Scrap/Credits recovery receipt | Cross-currency race cannot double spend; late top-up never auto-revives; durable recovery or once-only compensation |
| F · Failure and operator review | Refund/reversal/reconciliation, support UI, ingress and rollout controls | End-to-end failures recover; operator can locate every transaction and stop new sales without stranding delivery |
| G · TestFlight pilot | Documented device walkthrough and a small tester group | Creator verifies price clarity, fairness, recovery and native comfort; all blocking accounting defects resolved |
| H · Production release | Reviewed store products/app, policy/support copy, current live deployment and monitored release | Separate launch approval; production verification, retention/backup and incident procedure complete |

Do not assign a calendar launch date before Apple readiness and the integration feasibility check are known. Recommended work order is A → B → C → D → E → F → G → H, with admin diagnostics present in C and expanded in F. Cosmetics and continues are both in scope; a narrow technical slice is not a decision to omit continues.

Minimum failure matrix:

- Kill app before checkout, after Apple success, after grant and before local confirmation.
- Duplicate app submissions, duplicate/out-of-order notifications and notification-first delivery.
- Wrong account/bundle/product/environment, replay on another account and deleted/recreated account.
- Server or notification outage, missed events, expired login, account switch and reinstall.
- Concurrent cosmetic spends, insufficient funds, changed quotes, hidden products and wallet-cap boundary.
- Cross-currency recovery race, End run versus delayed debit, reset versus activation, corrupt/missing death checkpoint and compensation versus late activation.
- Refunded unused/partly spent/fully spent grant, duplicate refund and refund reversal.
- Sandbox top-up/cosmetic/continue cannot affect production wallet, ownership or settled progress.
- Gate disable, deployment restart and restoration from backup retain receipts and pending delivery.
- Compact iPhone, large text, Reduced Motion, system purchase sheet cancellation and foreground/background transitions.

Blocking release criteria: unexplained ledger mismatch; lost/duplicate grant or debit; cross-account/environment leak; paid recovery stranded without recovery/compensation; missing refund handling; inaccessible End run; crash or interruption that loses purchased value. Automated tests cannot establish spending comfort, fairness, demand or physical performance.

## 12. Decisions still requiring creator review

The use cases are settled. Review the proposed **100-Credit pack / 100-Credit cosmetic / 25-Credit continue**, the actual premium cosmetic concept, retention/refund support policy, and the proposed direct-Apple/Regun-ledger approach. Keep the existing 300-second and one-continue eligibility unless explicitly changed. These are reviewable product/architecture choices; this document does not authorize implementation or accept agreements on the creator's behalf.

Research consulted on 26 October 2026: the Apple and RevenueCat primary sources linked above. Cached source material is in ignored `.firecrawl/credits-*`; it is research evidence, not a game dependency. No App Store Connect business state, production wallet, live policy or deployment was changed or inspected through an authenticated service in this pass.
