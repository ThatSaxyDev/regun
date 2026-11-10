/// A handle to the checkout tab the game opened.
///
/// Web only: the game needs to notice that the player closed the payment tab so
/// it can stop waiting instead of polling until the session expires. Non-web
/// builds never reach this code, but they still compile, so the stub returns
/// null and callers fall back to the platform launcher.
abstract class CheckoutTab {
  /// True once the player (or the page itself) closed the tab.
  bool get closed;

  /// Points the already-open tab at the hosted checkout. Opening first and
  /// navigating second keeps the call inside the tap gesture, which is what
  /// stops pop-up blockers from dropping it.
  void navigate(String url);

  void close();
}

CheckoutTab? openCheckoutTab() => null;
