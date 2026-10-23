# Visible wallet — first implementation slice

23 October 2026. Local source implementation; no device installation, API/admin deployment or billing was performed.

## Delivered

- Shared reactive Scrap/Credits display. Home uses SafeArea upper-right placement over the artwork side in landscape; narrow portrait layouts reserve a row. Collection pins the wallet. Loadout puts it at the top of its catalog scroll to preserve pinned controls on short screens. Pause/Results show the wallet; active combat and upgrade choices do not show a shop.
- Actual banked Solo Scrap, separate current-run earnings, and separately labeled last-observed Online Scrap in wallet details. Online observations clear on account change. No cross-currency conversion or automatic summing.
- Credits shows an em dash and “Not available yet”, without a top-up or fake checkout. The old Collection acknowledgements tab is About.
- **Email gate:** guests earn/view Scrap normally but cannot spend it or make a purchase. Collection uses the existing email-code/account-attachment flow, then requires a separate Buy confirmation. The service checks the verified/attached account and unresolved conflicts independently of button labels. Previously owned styles remain equipable. Cached verified accounts can spend earned Scrap offline; no cash-backed spending exists.
- Cosmetic debit and ownership are staged until durable saving succeeds. Repeated taps cannot double-spend. Failure leaves the original purchase balance/ownership unchanged and provides an inline message. Account snapshots/outbox remain authoritative over a stale preference mirror.
- Failed normal profile saving marks the wallet “Save needed” and offers Retry save. Refresh does not overwrite unsaved rewards with an older snapshot. A failed game-over settlement retains recovery data and prevents immediate leave/restart from discarding the failure. Retry saves the already-settled profile without issuing a second reward.

## Limits

This is an earned local-profile wallet and spending gate, not anti-cheat authority. The API's separate online totals remain intact. A future unified wallet must enforce verified account ownership, ledger grants/spends and reconciliation on the server. Premium currency and purchases remain unavailable.

Retaining the previous checkpoint protects recovery when saving fails but is not a terminal settlement journal. Killing the process while all writes fail can recover the prior checkpoint rather than the exact final reward. A crash-proof settlement receipt/journal is still required before paid recovery or a unified server economy.

No XP costs, upgrade odds, combat power, paid revives or starting supplies changed. This slice preserves the new earned capacity upgrades.

## Manual review

1. As a guest, earn Scrap, finish a run and return Home. Check the upper-right balance and wallet explanation.
2. Collection → Style: an unowned priced item says Sign in. Canceling sign-in spends nothing. Complete email verification/attachment, then confirm Buy separately.
3. Check purchase persistence, insufficient funds and disabled repeat taps. Owned appearances remain equipable after sign-out.
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
