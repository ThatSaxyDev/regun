# Regun Scrap purchase plan

6 November 2026 · Implementation plan and local checkpoint. This supersedes the product direction in the [Credits monetization plan](CREDITS_MONETIZATION_PLAN.md). Store configuration, deployments and sales are separate release steps. The [platform verification runbook](SCRAP_PURCHASE_VERIFICATION.md) defines the evidence required to ship. The [UI plan](SCRAP_PURCHASE_UI_PLAN.md) covers wallet placement, purchase states and the current macOS and desktop-web behavior.

## Start here

The active IAP plan has three documents. Read them together before changing any purchase surface.

| Document | Owns |
|---|---|
| This implementation plan | Product direction, wallet migration, server contract, idempotency, sequencing and launch decisions |
| [UI plan](SCRAP_PURCHASE_UI_PLAN.md) | Player-facing surfaces, purchase states, input and lifecycle behavior on mobile, native macOS and desktop web |
| [Verification runbook](SCRAP_PURCHASE_VERIFICATION.md) | Platform policy, sandbox setup, test cases and evidence required for release |

Use this plan for shared product and wallet decisions. Use the companion docs for UI details and platform verification. Resolve any conflict across the three before implementing the affected behavior. The [Credits proposal](CREDITS_MONETIZATION_PLAN.md) is historical. Older economy and desktop docs describe the existing baseline.

## Platform rollout and ownership contract

| Surface | First Apple release | Later checkout |
|---|---|---|
| iOS | Six Apple consumables, wallet, Armory and eligible Solo revive flows. | Same Apple adapter. |
| Native macOS | Ship in the same milestone as iOS. Test its own StoreKit product lookup, sandbox checkout, window focus and native TestFlight build. | Same Apple adapter and server verification. |
| Desktop web | Sign in, sync the wallet, use owned guns and spend existing Scrap under current rules. Show checkout unavailable if a top-up is needed. | Plug in Bachs hosted checkout behind a server capability once merchant and storefront gates pass. |
| Android | Sign in, sync ownership and spend existing Scrap under current rules. Hide cash purchase actions and keep an explicit unavailable state for a shortfall. | Add Play Billing once the Play Store record, signing and merchant setup exist. |

**One owner and one weapon record.** Regun's verified account ID owns the
wallet and weapon unlocks. Apple authenticates the cash transaction. Once
Regun verifies the grant, the existing Armory spend reducer debits that
account and commits ownership. A browser never needs an Apple receipt to
use the resulting weapon. The canonical ownership projection comes from
[weapon access](../../regun-server/spacetimedb/src/weapon_access.ts) and the
existing [account sync](../lib/services/account/account_controller.dart).
Preserve the same owner across platforms, project the authoritative weapon
set on every snapshot, refresh at sign-in and on explicit sync or return to
Armory, and discard stale responses from a previous session. A newly signed-in
browser with empty storage must receive the ownership. A different account
must never see or equip it. Test an older cached profile and an already-open
browser tab as well as a fresh sign-in.

**One catalog and checkout contract.** The six stable internal pack keys and
Scrap quantities are shared. Map each key to provider and platform product IDs
on the server. Catalog responses expose supported packs, channel availability
and sales state. The Apple client fetches StoreKit price strings. Web gets a
server-validated quote when Bachs is enabled. The Android and web clients can
sync wallet and ownership with checkout disabled. Client display, provider
checkout and the grant journal use the same immutable pack quantity. A
missing or mismatched provider product is unavailable individually.

**Apple scope.** The six App Store Connect drafts are the starting point for
both builds. Verify SKU visibility from both bundles under the existing
multi-platform app record before adding alternate IDs. If separate platform
mapping is required, map it to the same internal pack. Reuse the native
checkout adapter wherever it exposes the required signed transaction and
account token. Validate signed transaction evidence, owner binding and
environment in the gateway, commit once, then finish. Restrict Apple sandbox
grants to dedicated Regun test accounts on the existing server. iOS and native Mac both
need a passing sandbox run before release.
[Apple multi-platform records](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/),
[Apple IAP configuration](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)

**Bachs handoff.** Keep hosted checkout in a web-only adapter. The gateway
creates the signed-in player's order with a stable checkout reference, allowed
return URL and frozen pack/amount/currency. Verify signed provider notifications
and reconcile the actual collection before using the common grant path.
Browser return resumes order status. It never grants Scrap by itself. Configure
keys, webhook registration, merchant approval, regional availability and
refund handling in the later web milestone. Native store builds have no Bachs
entry point. Web ownership sync is part of the first release even with Bachs
checkout disabled.
[Bachs webhook guide](https://docs.bachs.io/guides/webhooks/overview)

## Economy first · 6 November 2026

Implementation has started locally. The six pack sizes and saved Apple price
points are approved for this pass. Guns are the primary value of the offer today.

- **Buy Scrap.** A verified player can buy Scrap from the Home wallet and leave
  without starting a run or choosing a weapon. Gameplay milestones never gate
  a top-up. A verified payment adds to the same balance as earned Scrap.
- **Unlock a weapon.** The existing gameplay milestone and full Scrap price
  both apply. The source of Scrap does not affect eligibility. There is no
  minimum earned contribution or cap on purchased Scrap used for an unlock.
  Keep internal source records for reconciliation and refunds.
- **Repeater acceptance.** A player can buy 15,000 Scrap before or after their
  fifth boss win. With fewer than five boss wins, the Repeater stays locked.
  At five wins, the player can confirm the 10,000 Scrap unlock using entirely
  purchased Scrap and keep the remaining 5,000. Also verify earned-only and
  mixed-source unlocks. The 15,000 pack is part of the agreed lineup.
- **Revive eligibility.** Remove the 500-Scrap starting-balance requirement
  in the client and server. An otherwise eligible downed player can top up
  from the revive offer. Check for 500 confirmed Scrap when the player
  explicitly confirms the revive. Keep the current price, five-active-minute
  threshold, once-per-run rule, account eligibility, and assisted records.
  Other gameplay and Scrap spend rules keep their current behavior.
- **Smallest pack.** The lineup starts at 500 Scrap. That
  matches the smallest existing revive bill and gives small shortfalls an
  option. The pricing status for each pack is below.
- **Economy review.** Measure actual earned and banked Scrap by the fifth
  boss win, revive spending and time to earn weapon shortfalls. The creator
  reports about 1,500 spent on three revives and a balance below 5,000. Keep
  any future balance changes separate from store implementation.
- **Offer UI.** Home wallet and an eligible revive offer can open checkout. The Armory shows boss progress,
  price, balance and any shortfall, with a way to top up from browsing. Buying
  Scrap never automatically buys the weapon.

### Agreed pack lineup

The six pack quantities and the saved Nigerian and US price ladder below are
approved. StoreKit provides the localized customer-facing price. The existing
500-Scrap revive and 8,000–15,000 Scrap weapon prices inform pack sizing.

### App Store Connect drafts · 6 November 2026

All six Apple consumable drafts use the product ID pattern
`dev.kiishi.regun.scrap.<quantity>`. Nigeria is the base storefront and the
drafts mirror the existing 500-pack selection of all 175 storefronts.
The review screenshots and submission remain pending.

| Scrap | Saved NGN price | Apple-generated USD price |
|---:|---:|---:|
| 500 | ₦750 | $0.99 |
| 1,000 | ₦1,350 | $0.99 |
| 2,500 | ₦3,000 | $1.99 |
| 5,000 | ₦5,500 | $2.99 |
| 10,000 | ₦10,500 | $5.99 |
| 15,000 | ₦15,000 | $9.99 |

The creator approved the Apple-generated US ladder as saved. It has two
known overlaps: 500 and 1,000 cost the same, and a 10,000 plus 5,000 pack
costs less than a 15,000 pack. Keep all six quantities and use store prices.

### Research and implications

Epic documents a standalone currency shop and both earned and purchased
V-Bucks. Pokémon GO documents buying a currency pack and then separately
confirming an item exchange. These establish precedents for the standalone and
return-to-spend flows. Regun applies the same two-transaction boundary to a
revive and adds its own recoverable run checkpoint.
[Epic currency shop](https://www.epicgames.com/help/c-34254770/c-39884448/a21722612?lang=en-US),
[Pokémon GO purchase and exchange](https://niantic.helpshift.com/hc/en/6-pokemon-go/faq/94-how-can-i-purchase-items-and-pokecoins/)

Use native consumable IAP on Apple and Google Play. Purchased currency must
remain available without expiry on Apple. On Play, a pending purchase grants
zero until payment is confirmed. In Regun, an expired or abandoned spend intent
does not expire its associated Scrap.
[Apple App Review Guidelines §3.1](https://developer.apple.com/app-store/review/guidelines/#payments),
[Play Billing integration](https://developer.android.com/google/play/billing/integrate)

## Implementation checkpoint

The first local slice starts from game `369beaf`, server `cfbc5ea` and admin
`c0c4228`. The wallet UI now has one currency chip and retains the separately
labelled historical Online observation during the migration. Pause and Results
use read-only wallet details with save recovery still available.

The private `scrap_journal` records before/after amounts for existing Solo
wallet mutations inside their reducers. Existing wallets get a lazy opening
entry on first use, while newly initialized wallets record their legacy import.
This slice preserves existing reset and deletion behavior for the earned wallet.
A full populated-data migration rehearsal, durable paid transaction records,
provider checkout and grant/finalization, admin commerce reporting and the Online
migration remain separate gates. The journal is a balance audit trail. Provider
deduplication still requires the unique transaction keys below.

Before changes, the server passed 228 tests and built, identity passed 42 tests
plus its compiled HTTP smoke, and admin passed analysis and 86 tests. The game
run reproduced the existing retained weapon catalogue mismatch in
`test/weapon_behavior_test.dart` (expected 0.6, actual 5.0).
The focused wallet, account and layout suite passed after the client changes.
The server suite passed 229 tests after adding the journal and built the module.
A focused disposable SpacetimeDB probe verified that replaying the same cosmetic
purchase leaves a single debit and a single journal entry. The broader gateway
smoke returns 503 where the device-ownership check expects 400, reproduced at
unchanged server commit `cfbc5ea` before its wallet scenarios.

### Apple implementation start

The saved US price ladder is approved along with the six pack quantities.
The focused baseline passed 18 game and 21 server tests. The new client and
server allow an otherwise eligible Solo revive offer with zero starting Scrap.
The server still checks 500 confirmed Scrap at debit and replays the same
run receipt. The downed UI shows the shortfall until the store is available.
Existing checkpoint and request shapes remain compatible. Admin copy reflects
the current-balance rule. Focused game, server and admin tests passed.
StoreKit checkout and Apple-signed sandbox claims are now wired locally.
The grant reducer atomically journals and credits the same account used by
the Armory and rejects transaction reuse across accounts. The client
recovers unfinished StoreKit transactions and only finishes after a
matching server receipt. Cash checkout is disabled by default. Follow
the verification runbook to enroll the dedicated account on the existing gateway and exercise
real iPhone and native Mac TestFlight purchases. Production refund
reconciliation and Bachs/Play checkout remain separate work.

## Product decision

- Scrap is the one player-facing currency. Players can earn it through play or buy a fixed pack with real money. Remove the Credits chip, wallet-detail copy, semantics and associated tests. Keep attribution in About. There is no Credits balance in the reviewed implementation to convert.
- Use one spendable account balance, with internal source records for earnings, imports, purchases and reversals. Keep guest/offline play and existing ownership. Guests can earn as today. Buying and spending require a verified, attached account and a server response. Show pending offline earnings separately from the confirmed spendable amount when they differ.
- Offer the six agreed repeatable, fixed-quantity packs. Display the exact Scrap quantity and the provider’s localized total. The approved Apple pack quantities and price ladder are recorded above. Keep top-up in the Home wallet and make it reachable from Armory browsing. Complete the top-up independently of any Scrap spend. Allow checkout from an eligible Solo revive offer before settlement. Keep checkout out of active combat, Training, Online rooms and settled results.
- Use the same balance and spend rules for earned and purchased Scrap. Preserve existing eligibility for Armory weapons, Solo recovery and cosmetics. Before live sales, review the effects of paid acceleration on weapon access, recovery, PvP access, ranking and earn times. Keep the 500-Scrap/five-active-minute Solo rule and run-scoped receipt. Check the confirmed balance at the revive debit. Preserve separate assisted records. Review current deployed policy before testing. Hold sales until the live economy review is complete. Keep earned progression intact in the meantime.
- No transfer, redemption, expiry, paid random rewards or cash-out. No automatic purchase, bundle of starting power or special paid stat modifier.

## What exists in source

Rechecked game HEAD `7fc9a2f` and admin HEAD `c0c4228` with working-tree changes present, server `cfbc5ea`, and web export `884fbfa`. Both the working game manifest and the static export metadata report `1.0.0+39`. These are source observations. Production service revisions, store records and merchant settings still need verification.

| Surface | Evidence and implementation implication |
|---|---|
| Wallet and account | [WalletBar](../lib/widgets/wallet_bar.dart), [AccountController](../lib/services/account/account_controller.dart), [LocalPreferences](../lib/services/local_preferences.dart) and [Wallet implementation](WALLET_IMPLEMENTATION.md). Shared wallet UI, verified email, owner-scoped caching and spend recovery already exist. Results distinguish run earnings. Keep these contracts and extend them with a dedicated top-up intent and status. |
| Solo bank and spending | [Server wallet](../../regun-server/spacetimedb/src/wallet.ts), [weapon purchase](../../regun-server/spacetimedb/src/weapon_purchase.ts), [Solo recovery](../../regun-server/spacetimedb/src/solo_revive.ts) and [armory catalog](../lib/models/economy/armory_catalog.dart). Private `scrap_wallet` owns the balance. Cosmetics, weapons and recovery already debit it. Preserve server pricing, atomic ownership/recovery, revision/epoch checks and existing idempotency. Both the [client recovery model](../lib/models/solo_recovery.dart) and the server use 500 Scrap and 300 seconds, as recorded in [Revive Policy](REVIVE_POLICY.md). The server defaults to disabled if no policy record exists. |
| Earnings and online | [Reward model](../lib/models/economy/scrap_reward.dart), [server wallet](../../regun-server/spacetimedb/src/wallet.ts), [online settlement](../../regun-server/spacetimedb/src/settlement.ts), [wallet display](../lib/widgets/wallet_bar.dart). Solo imports legacy balances once and accepts device-reported cumulative earnings. Online settlement increments separate match accounting, displayed as last observed in the wallet. The client caches that observation in `LocalPreferences` from [OnlineSession](../lib/multiplayer/online_session.dart). Settlement already keys results by match and canonical identity, but trims result history to the latest 30. Use a durable wallet journal key for financial deduplication and reconcile historical totals against `online_account` and guest-claim behavior. The retained results cannot reconstruct lifetime totals. |
| Reset and deletion | [Identity reducers](../../regun-server/spacetimedb/src/identity.ts) currently zero the bank on progress reset and delete account actions/wallet on account deletion. Both need an explicit commerce lifecycle before sales. |
| Backend and operations | [Identity service](../../regun-server/identity/src/service.ts), [server schema](../../regun-server/spacetimedb/src/schema.ts), [nginx](../../regun-server/deploy/nginx.conf), [admin economy](../../regun-admin/lib/screens/economy_page.dart). Extend the authenticated account gateway and private transactional database. Test ingress because it uses an explicit route allowlist. The admin [Economy report](../../regun-admin/lib/screens/economy_page.dart) displays earned, imported and spent Scrap. The [player detail](../../regun-admin/lib/screens/server_screens.dart) labels wallet actions and currently says reset clears Scrap. Extend reporting and reset wording alongside the ledger change. Keep provider refunds separate from in-game Scrap spending. |
| Distribution | iOS, native macOS and Android use `dev.kiishi.regun` in source. [iOS project](../ios/Runner.xcodeproj/project.pbxproj), [Mac app config](../macos/Runner/Configs/AppInfo.xcconfig), [Android Gradle](../android/app/build.gradle). Android release currently points to debug signing. No Flutter IAP dependency is declared. Web game source belongs here and ships as a static [web export](../../regun-web-release/index.html). The [landing site](../../regun-landing-page/README.md) is separate. Secrets and fulfillment belong in the gateway. |

## Code paths to preserve

- [Identity reducers](../../regun-server/spacetimedb/src/identity.ts) dispatch profile saves through `walletProfile` and existing spends through `purchaseCosmetic`, `purchaseWeapon` and `soloRevive`. Route their balance mutations through the shared journal transaction. Preserve the cloud profile balance projection and revision increment so a stale save or quote cannot overwrite a top-up. Reconcile provider grants independently of client quote revisions.
- [AccountController](../lib/services/account/account_controller.dart) already persists and recovers cosmetic/weapon spend state. Give provider top-ups a separate intent and recovery path so spending, canceling a spend, and syncing profile data cannot clear an unfinished payment. [AccountStorage](../lib/services/account/account_storage.dart) uses owner-scoped browser keys. Recover paid orders from the gateway even when browser storage was cleared.
- The gateway's existing [HTTP layer](../../regun-server/identity/src/http.ts) checks browser origins against an allowlist. Extend player commerce routes through that boundary and the nginx allowlist. Handle provider notification authentication independently of browser CORS and Regun sessions.

## Wallet migration and trust

Historical Online Scrap consolidation and gameplay reward changes are outside
the Scrap Store scope. Preserve existing account reset and deletion behavior
during development. Resolve the treatment of paid value on those paths before
enabling live sales. Any change to existing rules needs a separate decision.

1. Add a versioned wallet and append-only journal with opening balances and source provenance. Preserve confirmed Solo bank and all ownership exactly. Treat imported pre-commerce funds as legacy earned. Make backfill repeatable and verify totals and per-account samples against a backup. Freeze or serialize writers during cutover. Have every existing spend and earn path use the new mutation path before enabling sales.
2. Keep historical and future Online Scrap accounting on its current path. The store credits the existing spendable account wallet. Any Online balance consolidation belongs to a separate project.
3. Preserve honest offline earning. A monotonic device counter prevents stale writes from refunding spends but can be forged. Keep it separate from verified commerce data, limit suspicious deltas, and require a documented abuse policy before money goes live. Test replays, forged totals, old epochs, simultaneous devices and guest attachment. Any move to verified run claims or server-authoritative rewards needs its own design and offline acceptance criteria. Historical imports and offline claims must never create paid provenance or a provider receipt.
4. Proposed reset semantics preserve the full confirmed wallet and ownership while resetting progression and advancing the earn epoch. Test old clients, stale saves and a purchase settling mid-reset. Keep the owner binding of an already-paid transaction even if the profile epoch advances. For account deletion, agree on the treatment of unused paid funds and in-flight orders, clear gameplay identity, and retain only the access-controlled transaction fingerprints and records needed for replay prevention, refunds and applicable retention duties. Never attach a deleted account's order to a new account with the same email.
5. Agree a refund policy before sales. Track spend attribution deterministically for refunds and support, while exposing one amount. Proposal for review is to reverse unspent units from the refunded grant, record any spent shortfall and send it to support under an approved policy. Preserve unrelated earned funds. Define partial refund rounding, dispute reversals, repeated events and already-delivered ownership/recovery. Avoid silently negative player balances or automatic reversal of completed runs. Keep refund intake operating even when new sales are paused.

## Checkout, grant and reconciliation

- Use the Regun database as the wallet authority. Evaluate Flutter's first-party `in_app_purchase` on iOS, macOS and Android in a sandbox spike. Confirm supported StoreKit account token, signed evidence, cold-start stream, finishing behavior and resolved Play Billing version. Use a narrow native bridge if required for missing capabilities. [Flutter IAP package](https://pub.dev/packages/in_app_purchase)
- Create a durable purchase intent for the authenticated account before checkout. Snapshot provider, environment, allowed product, immutable quantity and owner. Bind through Apple `appAccountToken`, Google obfuscated account ID or a server-created Bachs checkout reference. Old or unbound evidence enters reconciliation. Switching Regun accounts during checkout must never transfer the grant.
- Gateway verifies provider evidence independently. Validate app/package or merchant, environment, product, owner binding, paid state, supported quantity and any revocation. Match web amount/currency against the order and verified provider records. Clients supply evidence only. Keep sandbox grants restricted to explicitly enrolled test accounts and retain their source in the journal.
- In one DB transaction, insert the globally unique provider/environment transaction key, grant exactly once, append a ledger record and update the wallet projection. Enforce integer bounds without truncating a paid grant. Persist a status receipt the original owner can recover. Provider event IDs dedupe deliveries independently of transaction IDs. Store finalization follows the durable grant. A background job handles Play consumption and server reconciliation. Apple finishes on the device after receipt confirmation, with unfinished-transaction replay after restart. Process late refunds and refund-before-grant in either order.
- Expose separate, authenticated intent, claim and status routes and verified provider notification ingress. After timeouts, check status or replay evidence. Never open a second checkout automatically. Subscribe early on startup and reconcile on sign-in/resume. Recover completed consumable value from the Regun wallet using the original account, including reinstall and second device. A finished or consumed store purchase cannot be treated as a new grant.
- Add admin lookup by order/transaction and owner, audit trail, pending age, finalization failures and reversals. Separate sandbox reporting. Keep credentials, raw tokens and receipt contents out of logs and normal admin views. Use per-platform sales flags that hide new checkout while leaving claims, receipts and reconciliation active. Back up and test ledger restore before production.

## Idempotency contract

| Operation | Unique key and retry behavior |
|---|---|
| Start checkout | Regun account + provider + environment + client-generated operation UUID. Same key and same pack return the original intent. Same key with different inputs is a conflict. For hosted checkout, persist the provider reference and use provider request idempotency if supported. If session creation times out and its outcome is unknown, reconcile the original reference before creating another session. |
| Grant Scrap | Provider + environment + verified Apple transaction ID, Play purchase token, or Bachs collection ID. Enforce uniqueness across Regun accounts. The first successful transaction writes the immutable receipt, journal delta and wallet update atomically. A same-owner retry returns that receipt without a new delta. A different owner gets a generic conflict without order details. |
| Receive notification | Provider + environment + verified event ID where available. Persist verified delivery before acknowledging it, then retry processing durably. Separate deliveries about the same purchase still converge on the same grant or reversal. |
| Finalize purchase | One finalization state per grant. Apple client retries finishing when the unfinished transaction reappears. Play worker retries consumption and checks provider state after an ambiguous response. Neither path grants Scrap again. |
| Apply reversal | Use the verified provider adjustment ID when stable. Otherwise reconcile to the provider's cumulative reversed quantity or amount under the original transaction key and apply only the unapplied delta. Keep a pre-grant reversal on record so a late success cannot restore refunded units. |
| Spend or earn | Preserve current spend operation receipts and revision/epoch checks. Give unified online awards a stable match/participant settlement key and retain the offline earn watermark. Top-up and spend are independent operations. |

Treat a timeout as an unknown outcome. After a crash before the database commit, replay can perform the grant. After a crash between commit and response, replay must return the original receipt. After a crash before provider finalization, replay must finish or consume the existing purchase. A receipt carries the original credited quantity, while the wallet endpoint returns the current balance after any later activity. Keep durable transaction fingerprints for the approved retention period across resets and deletion so old evidence cannot fund a different account.

Required regression: race the client claim and provider notification for one purchase, then kill the worker immediately after the wallet commit and before finalization. Restart and replay from the original account and a second account. Assert one grant row, one matching wallet delta, one logical finalization and zero credit to the second account. Then process a refund twice and repeat with refund arriving first. Run these assertions against the real transactional database as well as provider fixtures.

## Implementation order and exit gates

| Stage | Exit evidence |
|---|---|
| 1. Baseline and account contract | Record game/server/admin revisions and pre-existing failures. Verify clean-browser account sync and existing wallet/spend behavior. Rehearse migration on populated data and resolve paid reset/refund handling before sales. |
| 2. Shared wallet and purchase UI | Implement provider-neutral catalog, intent, claim, status, grant journal and switches for new checkout versus reconciliation. Build all screen states with fixtures. Match touch, Mac and browser input and sizing. Android/web checkout disabled. |
| 3. Apple checkout on iOS and native macOS | Both TestFlight binaries list all six products, show correct localized prices and prove standalone top-up, Armory top-up and eligible revive. Reconcile cancellations, pending payment, restart, retries and refunds. |
| 4. Cross-platform ownership and Apple release | Buy Scrap and unlock a gun on iPhone, then equip it on native Mac and desktop web with the same Regun account. Android smoke checks shared account state without cash checkout. Confirm saved storefront prices, submit screenshots and binaries, and verify rollback switches before sales. |
| 5. Web checkout | Confirm Bachs approval, regional/payment scope and storefront policy, then test signed hosted checkout on HTTPS staging. Verify web-to-native wallet/ownership sync under approved rules before enabling web sales. |
| 6. Play checkout | Start after Play Store readiness. Verify signed internal build with license testers, pending purchase, backend consumption, replay and voids. |

See the [verification runbook](SCRAP_PURCHASE_VERIFICATION.md) for platform instructions, official sources and the shared failure matrix.
