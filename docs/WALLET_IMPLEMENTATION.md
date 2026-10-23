# Visible wallet — first implementation slice

23 October 2026. Local source implementation; no device installation, API/admin deployment or billing was performed.

## Delivered

- Shared reactive Scrap/Credits display. Home uses SafeArea upper-right placement over the artwork side in landscape; narrow portrait layouts reserve a row. Collection and Loadout pin the wallet beside their page titles, with Back at the trailing edge. Narrow/large-text layouts wrap the title group without moving the wallet into scrolling content. Pause/Results show the wallet; active combat and upgrade choices do not show a shop.
- Actual banked Solo Scrap, separate current-run earnings, and separately labeled last-observed Online Scrap in wallet details. Online observations clear on account change. No cross-currency conversion or automatic summing.
- Credits shows an em dash and “Not available yet”, without a top-up or fake checkout. The old Collection acknowledgements tab is About.
- **Email gate:** guests earn/view Scrap normally but cannot spend it or make a purchase. Collection uses the existing email-code/account-attachment flow, then requires a separate Buy confirmation. The service checks the verified/attached account and unresolved conflicts independently of button labels. Previously owned styles remain equipable. All new purchases require an online server confirmation. Cached ownership remains usable offline; no cash-backed spending exists.
- New purchases go through `/purchase` and `account_purchase`: live verified account/session checks, server catalog, revision/reset epoch, atomic debit and ownership, durable idempotency receipt. No local/offline purchase fallback exists. A lost response keeps the operation ID for an explicit retry; it may already have committed remotely. Account snapshots/outbox remain authoritative over a stale preference mirror.
- Failed normal profile saving marks the wallet “Save needed” and offers Retry save. Refresh does not overwrite unsaved rewards with an older snapshot. A failed game-over settlement retains recovery data and prevents immediate leave/restart from discarding the failure. Retry saves the already-settled profile without issuing a second reward.

## Limits

The API now owns spendable Solo Scrap and purchased shop ownership in a private `scrap_wallet`. The first accepted profile imports legacy balance and shop skins once with a `wallet_legacy_grant` audit entry. Later profile saves cannot set wallet balance or add shop skins; new offline earnings use a monotonic `earnedScrapTotal`, with a labelled device-reported grant. This prevents stale saves refunding purchases; it does not prove offline combat was honest. The separate online total is never summed. Premium currency and real-money billing remain unavailable.

Confirmed ownership is cached in the atomic account file and preference mirror. Relaunching offline does not require token refresh or entitlement verification to equip it. Explicit progress reset preserves purchased shop skins, resets Scrap/earnings, and advances the epoch; account deletion removes the wallet and receipts. Another device must sync once to download ownership. The admin player record shows the wallet and latest 50 import/earn/purchase/reset records.

Retaining the previous checkpoint protects recovery when saving fails but is not a terminal settlement journal. Killing the process while all writes fail can recover the prior checkpoint rather than the exact final reward. A crash-proof settlement receipt/journal is still required before paid recovery or a unified server economy.

No XP costs, upgrade odds, combat power, paid revives or starting supplies changed. This slice preserves the new earned capacity upgrades.

## Manual review

1. As a guest, earn Scrap, finish a run and return Home. Check the upper-right balance and wallet explanation.
2. Collection → Style: an unowned priced item says Sign in. Canceling sign-in spends nothing. Complete email verification/attachment, then confirm Buy separately.
3. Check online purchase persistence, insufficient funds, timeout/retry and disabled repeat taps. Disconnect before buying: no local spend/grant may occur. Previously downloaded appearances remain equipable after an offline restart of the same profile. Explicit sign-out switches to the separate guest profile.
4. Check account switch/sign-out: no previous account's Scrap or Online total should remain displayed.
5. Check portrait/landscape, notches, 568px short landscape, large text and large balances. Loadout tabs/Start must stay usable; no wallet may cover aiming controls.
6. Results distinguishes this-run earnings from banked Scrap; reopening Results never grants twice. Save failure shows Retry save and does not clear the recovery checkpoint.
7. Credits must remain unavailable; no hidden purchase or recovery action is offered.

Rendered evidence lives in build/test-previews, including home-844.png, collection-alignment.png, contact-death-results.png and wallet.png. These are widget renders, not physical-device acceptance.

## Verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 555 passed, five existing optional skips.
- After the final scrollable purchase-message layout adjustment, `flutter test --no-pub test/menu_layout_test.dart test/wallet_test.dart`: nine passed.
- `git diff --check`: passed.
- Visual inspection: rendered Home and exact large wallet values; Home/Loadout/Collection/Pause/Results tests cover safe-area, compact and enlarged-text layouts. Native thumb comfort remains a hands-on check.

The scene integration test now injects an in-memory checkpoint store and explicitly completes settlement before dense restart simulation; disk persistence remains independently covered by RunStore tests. A new real-game regression exercises failed profile persistence, retained recovery data and once-only settlement retry.

Header placement follow-up: Collection/Loadout share MenuHeader; alignment and scroll-pinning assertions accompany compact/notched/large-text layout checks.

Collection/Loadout title headers use currency symbols and amounts only to conserve space. Currency names remain in semantics and wallet details; other wallet surfaces retain their labels.

## Backend purchase implementation — 23 October 2026

The app, identity gateway, SpacetimeDB module and admin display are implemented locally. They are not deployed by this task. Deploy the module and gateway together without deleting data or changing publisher/session secrets, then distribute the updated app/admin. Older app binaries retain their old local behavior and need replacement; a backend cannot rewrite their offline UI.

Verification includes the disposable real-host smoke (JWT auth, private tables, forged balance/ownership rejection, duplicate/stale/concurrent purchases, insufficient funds, reset retaining ownership and admin audit), app HTTP tests for offline denial and lost-response retry across restart, and admin compact/large-text receipt rendering. See final verification results in the task report. No physical device or production acceptance is claimed.

Final verification for the backend purchase slice: game `make verify` passed with556 tests and five optional skips; admin `make verify` passed with32 tests; server `npm run verify` passed109 tests and module build; identity `npm run verify` passed nine tests plus compiled HTTP smoke. The disposable live-host smoke also passed, including revoked-session purchase rejection and preservation of ownership on reset. All analyzers/typechecks passed. These are local automated results, not production or physical-device acceptance.

## Purchase403 diagnosis and receipt recovery — 23 October 2026

A public unauthenticated POST to `/purchase` returned nginx HTML403, whereas
`/account` returned the gateway's JSON401. The deployed proxy allowlist omitted
`purchase`, so the request never reached the account transaction. This was missed
by the previous real-host smoke because it called Node directly without nginx.

The nginx template now explicitly forwards `/purchase` and `/purchase-status`.
A real-nginx regression runs inside an existing local server image and verifies
both routes reach a stub gateway, with raw SQL and unknown paths still denied.
The disposable account-container smoke also checks both routes through ingress.

AccountApi preserves non-JSON error status instead of converting HTML403 into
an uncertain transport failure. Pending purchase operation IDs remain durable:
an error on a retry could follow a committed request with a lost acknowledgement.
The UI now distinguishes blocked/not-completed states from awaiting confirmation.
Sync checks the private owner-scoped receipt through `/purchase-status`; it never
submits a new purchase. A matching committed receipt restores ownership/balance;
no receipt leaves the existing intent available for explicit retry in Collection.
Receipt operation/item/catalog/reset-epoch and account checks prevent mismatches.

Verification:18 focused app/account/wallet tests passed; identity verification
(nine unit tests, compiled HTTP smoke) and disposable real-host receipt/auth tests
passed; real nginx routing proof passed. The final app analyzer is clean. These
are local results; the public route still needs the updated server redeployment,
and the app needs updating for improved status/reconciliation behavior. No user
balance, receipts, ownership, credentials or production state was modified.

## Earned catalogue and goals follow-up — 23 October 2026

See [the economy implementation](ECONOMY_IMPLEMENTATION.md) for items2–10 of the
non-billing pass: compatible live cosmetic prices/availability, six implemented
finishes, quoted confirmation, safe cancellation, career goals, earning breakdown
and admin catalogue/reporting. Owned items remain offline-usable even if removed
from sale. [Continue rules](REVIVE_POLICY.md) are defined but not enabled.
