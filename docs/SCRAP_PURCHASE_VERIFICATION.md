# Regun Scrap purchase verification runbook

6 November 2026 · Planned tests. Public documentation was checked. Store accounts, merchant eligibility, live configuration and actual purchases remain unverified. See the [implementation plan](SCRAP_PURCHASE_PLAN.md) for the wallet contract and release gates and the [UI plan](SCRAP_PURCHASE_UI_PLAN.md) for desktop and touch acceptance.

The [economy-first decision](SCRAP_PURCHASE_PLAN.md#economy-first--6-november-2026) defines the shared balance, Home checkout and weapon eligibility. The six pack sizes and saved Apple prices are agreed.

## Distribution policy

| Channel | Purchase path and release gate |
|---|---|
| iOS and Mac App Store | Use StoreKit consumable IAP on both. Apple prohibits expiry of purchased currency. Guideline 3.1.3(b) permits access to web/other-platform consumables in multiplatform games when those items are also offered as IAP in the app. Show the equivalent Scrap offer on each Apple version before allowing use of web-purchased units there. Describe the shared wallet and exact offer mapping in review notes. [Apple guidelines §3.1](https://developer.apple.com/app-store/review/guidelines/#payments) |
| Google Play | Use Play Billing one-time consumable products. The currency stays within Regun. Show the same localized price as the Play purchase sheet. The general payments rules do not resolve Regun's specific shared web wallet approval. Confirm same-title cross-platform redemption for this product and the launch storefronts before enabling web grants in Play builds. [Play payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en) |
| Browser | Evaluate Bachs for web-only hosted checkout. Expose no web checkout button, QR code, price steering, webview, account-flow redirect or purchase link from native store builds in the initial release. Regional programs and storefront-specific exceptions are outside this plan. Hold Bachs sales until merchant eligibility and both native storefronts' shared-wallet treatment are confirmed. [Apple guidelines](https://developer.apple.com/app-store/review/guidelines/#payments), [Play payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en) |

## Running the Apple sandbox implementation

The client and gateway default to checkout disabled. Use a dedicated Regun
test account on the existing server. Deploy the matching module and gateway
through the existing operator pinning and nginx allowlist. Enroll the exact verified
Regun email addresses approved by the creator. Existing accounts may be enrolled.

| Setting | Value |
|---|---|
| `REGUN_APPLE_SCRAP_SANDBOX` | `1` on the identity gateway |
| `REGUN_APPLE_ROOT_CERT_FILES` | Comma-separated filesystem paths to Apple's DER root certificates |
| `REGUN_APPLE_SCRAP_TEST_EMAILS` | Comma-separated exact verified Regun emails approved for sandbox checkout |
| `REGUN_APPLE_SCRAP_TEST_ACCOUNTS` | Optional comma-separated exact Regun UUIDs |

Build both Apple targets with the existing identity endpoint and
`--dart-define=REGUN_APPLE_SCRAP_SANDBOX=true`. Use development-signed
sandbox installs or TestFlight. Keep this flag off in public builds.
The server checks the account allowlist and Apple-signed owner token on
every claim. A sandbox purchase updates the enrolled account's normal
wallet and ownership on the existing server. Sign into that same Regun
account on web to verify the gun. The creator may enroll their main account. It receives ordinary spendable Scrap under the same rules.
Real-money top-ups require the production verification and refund path.

The current adapter claims Apple-signed sandbox transactions and
reconciles unfinished transactions on account attachment, app resume and
**Check status**. Local fixtures and unsigned builds exercise the
implementation but do not establish real StoreKit sandbox delivery or signing.
Production verification, refund notifications and paid reset/deletion
handling remain release gates.

Local verification on 6 November 2026: 36 focused Flutter tests, 231
SpacetimeDB tests and module build, and 42 gateway tests plus compiled smoke
passed. Unsigned iOS and macOS release builds and a web release build compiled.
A disposable SpacetimeDB and gateway probe used a verifier fixture. Concurrent
claims made one wallet grant, an untrusted reducer caller was rejected, and the
10,000-Scrap Repeater spend projected the resulting ownership to a fresh account
fetch. A separate client regression covers stale wallet/weapon sync. These
checks do not prove Apple product visibility, Apple signature delivery,
TestFlight signing or real-device checkout. No sandbox endpoint was deployed
and no TestFlight build was uploaded in this pass.
[Apple root certificates](https://www.apple.com/certificateauthority/),
[Apple server verification library](https://github.com/apple/app-store-server-library-node)

## iOS and native macOS TestFlight

1. Verify that App Store Connect contains the iOS and native macOS versions under the intended app record and that bundle IDs/signing match. Confirm the Account Holder's Paid Apps Agreement is active. Confirm banking, tax, storefront availability and merchant details before sales. Register the approved consumable pack products for both platform versions, with localized name/description, exact pack quantity and price. If platform records are separate, verify configuration before picking SKU IDs. Product metadata can take up to an hour to propagate to sandbox. The first consumable must be submitted with an app version for review, but review approval is unnecessary for sandbox testing. [Configure IAP](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/), [Submit IAP](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)
2. Use an Xcode StoreKit configuration for quick local UI and interruption scenarios. Then test with real App Store Connect product data on development-signed iPhone and Mac builds. Test real sandbox signatures and server integration with Apple sandbox, since Xcode simulation serves a different purpose. [Apple sandbox guide](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox?changes=_1), [Apple testing overview](https://developer.apple.com/videos/play/wwdc2023/10142/)
3. Archive and upload **two platform builds** with matching bundle configuration and eligible build numbers. Confirm the native macOS build has the intended deployment target, App Sandbox and outbound network entitlement. Assign both builds to internal TestFlight testers first. Install via TestFlight on a physical iPhone and in the TestFlight app on a Mac. Record platform, build and OS from each binary. An iPhone build running on Apple silicon is a different test. Use external groups after the internal pass and applicable beta review. [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [iPhone apps on Apple silicon](https://developer.apple.com/help/app-store-connect/test-a-beta-version/test-iphone-and-ipad-apps-on-macs-with-apple-silicon/)
4. Both TestFlight installs use Apple's sandbox and test purchases are free. Start with standard TestFlight checkout on each. For iOS scenario controls, install using the normal Apple Account first, sign out of **Media & Purchases**, then sign in via **Settings → Developer → Sandbox Apple Account** as Apple documents. Re-signing into production Media & Purchases changes which account TestFlight uses for sandbox attribution. For **development-signed macOS**, Apple documents **App Store → Settings → Sandbox sign-in** after an initial purchase attempt. Apple's detailed TestFlight sandbox-account switching steps are iOS-specific. Record the actual macOS build, storefront, observed account controls and server-verified Sandbox environment, and run Mac-only controlled scenarios in development-signed sandbox if needed. The native Mac TestFlight purchase itself remains a release gate. [TestFlight IAP](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/), [Sandbox sign-in](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox?changes=_1), [Create a sandbox account](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account/)
5. Verify StoreKit signed transaction data or retrieve it through the App Store Server API. Validate app/product/environment and account token, then grant before finishing. Configure and exercise App Store Server Notifications V2 for test delivery and refund reconciliation. On each TestFlight binary, buy twice, interrupt after store success before the server response, restart, then confirm exactly one grant per transaction. Sign into the same Regun sandbox account on the other Apple platform to confirm wallet sync. Test cancel, pending where supported, unavailability, and refund/reversal with Apple sandbox tools. Record which environment exercised each case. [Apple IAP and server tooling](https://developer.apple.com/in-app-purchase/), [App Store Server Notifications](https://developer.apple.com/documentation/appstoreservernotifications)
6. For submission provide product metadata, review screenshot, test account/access instructions for email verification, wallet navigation, shared-wallet details and a functioning reviewer backend. Keep sandbox value confined to enrolled reviewer/test accounts. The [identity service](../../regun-server/identity/src/service.ts) already supports a configured Apple reviewer sign-in code. Verify reviewer access with its dedicated enrolled account and keep credentials out of the repo and evidence. [App Review sandbox setup](https://developer.apple.com/help/app-review/before-submitting-for-review/configure-in-app-purchases)

## Google Play internal testing

1. Verify the Play Console record for `dev.kiishi.regun`, merchant payments setup, product availability and service-account access. Establish release upload signing and Play App Signing for the AAB. Verify target SDK and the **resolved** Billing Library in the release build. As checked, Billing 7's extension ended on 1 November 2026. Use a supported version at upload and confirm the current deadline. [Billing deprecation table](https://developer.android.com/google/play/billing/deprecation-faq), [Target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
2. Configure each approved pack as a one-time consumable with an active purchase option. Publish a signed build to internal testing. Add tester Google accounts both to the track and **License testing**, send the opt-in URL, then install from Play using the intended account. Test-track access alone can charge real money. Verify the test instrument is shown before buying. If several accounts are present, check which downloaded the app. Use Play Billing Lab as needed for test scenarios. [Play Billing testing](https://developer.android.com/google/play/billing/test)
3. Disable client auto-consume. Send the purchase token to the gateway, verify product/package, state, test status and account binding with the Play Developer API, and persist the grant before server-side consumption. Consumption also acknowledges the consumable and allows repeat purchase. Exercise retries well within the short license-test acknowledgement window (roughly three minutes). The production acknowledgement window is three days from PURCHASED. PENDING grants zero and stays unconsumed. [Billing integration](https://developer.android.com/google/play/billing/integrate), [Play backend security](https://developer.android.com/google/play/billing/security)
4. Test always-approve, always-decline, slow approve and slow decline, kill/relaunch in each pending case, repeated consumable purchase, and refund/revoke in Play Console. Use authenticated Real-time Developer Notifications through Pub/Sub as a trigger to recheck the Developer API. Exercise voided purchase reconciliation and provider timeout during consumption. [RTDN reference](https://developer.android.com/google/play/billing/rtdn-reference), [Play backend security](https://developer.android.com/google/play/billing/security)

## Bachs browser sandbox

Bachs documents one-time hosted checkout, a separate sandbox, signed webhooks, refunds and disputes. Public docs do not establish that Regun's specific nontransferable game currency is approved or that Bachs assumes tax/merchant-of-record obligations. Confirm with Bachs in writing before activating live checkout. Record applicable countries, payment methods, currencies, fees, payout timing, KYB, refund/dispute obligations and who handles taxes and receipts. Prior use for ITE does not establish Regun eligibility. [Bachs documentation index](https://docs.bachs.io/llms.txt), [Merchant verification](https://docs.bachs.io/go-live), [Supported payment methods](https://docs.bachs.io/guides/payments/payment-method-support)

1. From the signed-in web game, request an owner-bound order from the Regun gateway. Create a Bachs hosted session server-side with the configured product and allowlisted HTTPS return URL. Keep sandbox/live keys, webhook secrets, and merchant state separate. Verify session-to-collection correlation against actual sandbox payloads. [Hosted checkout](https://docs.bachs.io/guides/checkout/checkout-sessions), [Sandbox](https://docs.bachs.io/integrate/sandbox)
2. Return to an authenticated status page. Fulfill on verified `collection.succeeded` and matching payment/order evidence. A success redirect or `checkout.completed` alone is insufficient. Verify `X-Bachs-Signature-V2` against the timestamp and raw body before parsing, allow key rotation, deduplicate deliveries and deduplicate the underlying collection. Reject mismatched amount, currency, merchant or order. [Collection succeeded](https://docs.bachs.io/guides/webhooks/events/collection-succeeded), [Checkout completed](https://docs.bachs.io/guides/webhooks/events/checkout-completed), [Webhook verification](https://docs.bachs.io/guides/webhooks/overview)
3. Exercise browser closed before redirect, redirect before webhook, no redirect, lost webhook/reconciliation, invalid signatures, rotated secrets, duplicate and reordered delivery, checkout expiry, wrong account/tab, failed/underpaid collection and late refunds. Test dispute open and resolution, partial refund where supported, and repeated refund events. Record where provider sandbox coverage ends and use controlled fixtures for gaps. [Bachs refunds](https://docs.bachs.io/guides/refunds), [Disputes](https://docs.bachs.io/guides/disputes/overview)

## Required player journeys

| Starting state | Pass condition |
|---|---|
| Signed-in player with zero boss wins | Open Home Scrap chip, buy a pack, leave immediately, and sign in again. Exactly one grant is visible. No item or run action occurs. Repeat after closing while payment is pending. |
| Eligible Solo death with zero Scrap at run start and death | Top up 500 Scrap, return to the same offer and confirm the existing 500-Scrap revive separately. Resume once. Verify cancel, pending payment, late grant after End run, process restart, and replay after a lost revive-debit response. An otherwise ineligible run still has no revive offer. |
| Repeater at 5/5 bosses with insufficient funds | Armory shows the shortfall. Buy enough Scrap, return to the same weapon, confirm 10,000-Scrap spend once and keep the remainder. Purchased funds can cover the whole price. Verify a still-insufficient top-up, changed quote, duplicate confirmation and funded wallet at 4/5 bosses. |

Verify all six pack quantities and actual StoreKit prices against the saved Apple drafts.

## Cross-platform ownership release gate

1. In iPhone TestFlight, use the verified Regun sandbox account with five boss
   wins. Buy Scrap, verify one grant, then confirm the 10,000-Scrap Repeater
   unlock. Capture the weapon spend receipt, confirmed balance and revision.
2. Sign into desktop web using a fresh browser profile with the same Regun
   account. With Bachs disabled, verify the same balance, **Owned** state and
   equip/start behavior without buying again. Repeat on native Mac TestFlight
   and in an Android build with checkout unavailable.
3. Repeat with a stale account snapshot, an already-open browser, sign-out and
   a different account. After an authoritative refresh, the same account sees
   the gun. Other accounts do not see it. A stale save cannot erase the unlock
   or restore spent Scrap.
4. Reverse the Apple device direction with a Mac purchase. Later, run the same
   end-to-end checks for a Bachs purchase and Armory spend after web checkout
   and platform policy pass. Keep all evidence within the matching environment.

## Shared acceptance matrix

| Scenario | Evidence to capture |
|---|---|
| Success, repeat and reinstall | Provider product/price, initial and final wallet, one grant per provider transaction, two distinct successful orders, recovered wallet on second device or clean reinstall. |
| Replays and failures | Same transaction submitted from two clients/accounts, forged SKU/owner/environment, duplicate webhook, refund-before-grant, API response lost after commit, app killed at every step, worker restart after grant before finalization. Zero duplicate or cross-account grants. |
| Migration and races | Old profile, guest attachment, concurrent earn/spend/top-up, reset mid-checkout, account deletion mid-checkout, stale version, full balance bound, online settlement retries, and rollback rehearsal. Reconcile opening plus journal to ending balance. |
| Refund and support | Full and partial where supported, unused versus spent units, duplicate and reversed dispute, production/sandbox segregation, help flow from receipt to operator. |
| Access and UI | Offline guest play, cached owned items, signed-out gating, disabled sales flags, localized price, loading/pending/error and accessibility across compact iOS/Android, native Mac keyboard navigation and browser. Verify platform builds cannot start the web provider checkout from their UI. |
| Deployment | Game `make verify`, server and identity `npm run verify`, admin `make verify`, release dependency/signing inspection, real nginx ingress and provider sandbox checks. Use the existing [nginx purchase proxy smoke](../../regun-server/deploy/tests/purchase_proxy_smoke.mjs) as a base for new ingress coverage. Reuse the [wallet](../../regun-server/spacetimedb/tests/wallet.test.ts), [settlement](../../regun-server/spacetimedb/tests/settlement.test.ts) and [revive](../../regun-server/spacetimedb/tests/solo_revive.test.ts) tests for compatibility checks. Confirm backup/restore, alerting for unfulfilled/unfinished purchases and flag rollback. |

For each run record the UTC timestamp, OS, binary/build and commit, storefront, provider environment, redacted intent/order identifiers, wallet before/after, journal delta, provider finalization state, and result. Capture screenshots with tester identities and payment details redacted. A passing fixture or a signed artifact alone leaves real TestFlight, Play and Bachs verification open.
