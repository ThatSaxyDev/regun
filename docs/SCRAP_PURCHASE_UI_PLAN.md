# Scrap purchase UI plan for desktop and mobile

6 November 2026 · Planning only. This extends the [purchase plan](SCRAP_PURCHASE_PLAN.md) and [verification runbook](SCRAP_PURCHASE_VERIFICATION.md). It reflects desktop controls in `5af0c5c`, the committed startup and Mac presentation work in `7fc9a2f`, and static web build 39 in `884fbfa`. The desktop implementation and its open device checks are documented in the [desktop plan](REGUN_DESKTOP_PLAN.md).

## Surface changes

| Surface | Planned change |
|---|---|
| Home | Keep the single Scrap chip in the existing upper-right wallet slot on desktop landscape and the existing wallet row on compact layouts. Open wallet details from it. Use the existing pixel styling and give the chip a clear hover, keyboard-focus and controller-focus state. Remove the Credits cell. |
| Wallet details | Use a capped, scrollable dialog with a pinned action area. Show confirmed Scrap, any run earnings awaiting sync separately, and a **Buy Scrap** action when sales are available. Show an owner-scoped pending purchase and **Check status** when applicable. Preserve **Sign in** and **Retry save** for their existing purposes. Keep one total after the online migration decision and label legacy amounts separately during any transition. |
| Buy Scrap | Start with one pack. Show exact quantity and localized total before opening StoreKit, Play Billing or Bachs. Use an explicit purchase button and a Cancel/Back action. After email sign-in return to the pack screen and require a fresh confirmation. Show missing price or store unavailable states without enabling purchase. |
| Collection and Loadout | Keep the compact Scrap chip beside the header and preserve the desktop roster/armory/kit layout. Existing item confirms still quote Scrap. On an insufficient-funds result, optionally link to the wallet from the browsing flow. After purchase, return to the same tab and selection and require a fresh item confirmation with the latest quote. |
| Pause and Results | Keep the balance and this-run earnings readable in the existing desktop panels. Make the wallet view read-only from these surfaces. No purchase actions in Training, Online rooms, the active run, the upgrade picker, or the Solo recovery offer. |
| About | Keep attribution. Remove the Credits currency label, icon, placeholder copy and wallet accessibility labels across desktop and touch layouts. |

Use the existing [WalletBar](../lib/widgets/wallet_bar.dart), [MenuHeader](../lib/widgets/menu_layout.dart), [Home layout](../lib/widgets/home_menu.dart) and [account dialog](../lib/widgets/account_flow.dart) as anchors. Trace both compact and desktop branches in [Loadout](../lib/views/loadout_view.dart) and [Pause](../lib/views/base_view.dart), the shared header in [Collection](../lib/views/collection_view.dart), and the direct chip in [Results](../lib/widgets/run_results_panel.dart). The wallet needs an explicit browsing versus read-only presentation context because it is shared with Pause and Results. Keep the current layout placements and build a common purchase-state view over platform-specific checkout adapters.

## What the player sees during checkout

| State | UI behavior |
|---|---|
| Fetching price or starting checkout | Keep the amount visible. Disable repeat activation while the current request is in flight. Price must come from the provider or server quote for the active account and storefront. |
| Awaiting store approval or payment | Show “Payment pending” and let the player close the dialog. Retain the owner-bound intent. Keep a quiet status entry available from Home. |
| Store returned success, server grant unresolved | Show “Confirming purchase” with **Check status**. Reopening or retrying checks the existing order. |
| Granted | Show “+N Scrap” only after a verified grant. Refresh the single balance and return focus to the wallet or original browsing action. The grant message stays tied to that transaction, even when the current wallet has since changed. |
| Canceled, declined or unavailable | Return to the wallet with a short outcome and an explicit retry when the provider outcome is final. A timeout stays in confirmation until reconciled. |
| Account changed | Close or invalidate the old account’s panel and clear its display. An order that settles later belongs to the original account. |

Keep status announcements accessible, avoid repeated screen-reader announcements during polling and respect Reduced Motion. A dialog can close while reconciliation continues. Fetch products on demand so the menu and earned progression remain usable when a provider is slow.

## Native macOS

- Keep the current **960×540 minimum** and **1280×720 preferred** window. Verify the dialog at both sizes, on a 16:10 Retina display, in native fullscreen and when moving between displays. Long localized prices and enlarged text must wrap without clipping the balance or confirmation.
- Reuse the desktop brass cursor and visible Flutter focus. Tab and Shift+Tab stay within the dialog, Enter/Space activate the focused action, and Escape/Back closes the Regun dialog. Verify controller navigation and require a fresh confirm press before opening StoreKit. Let the system sheet own its own input. Restore focus after cancellation, window reactivation or return from StoreKit without replaying a held key, click or controller button.
- Use StoreKit on the native Mac App Store build. Exercise checkout on the actual Mac TestFlight binary with macOS signing, sandbox and network entitlements. Developer ID builds, if distributed, need a separate channel decision and should keep checkout unavailable until their payment path is approved. [Mac window implementation](../macos/Runner/MainFlutterWindow.swift), [Apple TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## Desktop web

- Start Bachs hosted checkout from the authenticated desktop game. Use a top-level navigation to the verified hosted checkout URL and preserve the intent before leaving. On return, reload the wallet and look up the original order through the authenticated gateway. Browser Back, refresh, multiple tabs and lost local storage must remain recoverable from the original account. The redirect itself changes no balance.
- Keep the browser’s explicit fullscreen control. Expect fullscreen to exit on navigation. Return to a usable windowed view and let the player re-enter fullscreen. Preserve the existing landscape-required screen in square or portrait windows. If checkout returns into that screen, reconcile after account initialization and show the result when the wallet is visible again.
- The current [web bootstrap](../web/platform_bootstrap.js) routes mobile browsers to download links before loading Flutter. Keep that page download-only. If someone opens a return URL on a mobile browser, show how to check their purchase in Regun without sending them back into checkout. Verify the approved cross-platform wallet policy before enabling web sales.
- The current [web shell](../web/index.html) and [Flutter splash](../lib/views/flame_splash_view.dart) handle startup and arena asset preparation. Keep purchase status independent of arena preload success, browser audio unlock and commerce availability. Use the game’s [buildWeb target](../makefile) for the next static export so art preparation and store-link generation remain in the build path. Resume reconciliation after the account initializes. If the browser serves an older cached client, it must still be safe to sync the wallet and recover any committed purchase.
- Run checkout and recovery on HTTPS staging for Safari, Chrome and Firefox on Mac and Chrome/Edge and Firefox on Windows. Cover resize, zoom, fullscreen exit, back navigation, returning after sign-out, stale service-worker assets and controller disconnect. Preserve hybrid touch behavior where the desktop game is available.

## UI exit checks

- Extend `wallet_test.dart`, `wallet_account_test.dart`, `home_menu_test.dart` and `menu_layout_test.dart` for one visible currency, the owner-scoped states, focus return, large amounts, long localized prices and compact/large-text layouts.
- Extend desktop and web-landscape tests for modal input isolation, held confirms, fullscreen return and wallet recovery after viewport changes. Verify no purchase activation from combat input or from a focused text field submitting an email code.
- Capture native Mac and desktop browser screenshots for Home, pack offer, pending and granted states. Run one end-to-end pass with mouse/trackpad and keyboard, one with a controller, and a touch regression on iOS and Android. Capture native purchase sheets separately with tester details redacted. Widget fixtures prove layout and state transitions. Real payment sandbox evidence follows the [verification runbook](SCRAP_PURCHASE_VERIFICATION.md).

The UI direction is ready to estimate and build once implementation is requested. Before enabling sales, approve pack size and pricing, spend scope, historical Online Scrap treatment and the reset/refund rules. Platform and merchant acceptance still need evidence.
