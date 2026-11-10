import 'package:web/web.dart' as web;

import 'checkout_window_stub.dart' show CheckoutTab;

// A conditional export takes the place of the file it names, so the shared
// interface must be re-exported here or the barrel would expose only
// `openCheckoutTab` on web and the type would vanish from callers.
export 'checkout_window_stub.dart' show CheckoutTab;

/// Web implementation of the checkout-tab handle.
///
/// `window.open` with a fixed target name reuses one tab, so tapping Buy twice
/// cannot stack checkouts. The returned proxy exposes `closed`, which is the
/// only reliable signal that the player walked away without paying.
CheckoutTab? openCheckoutTab() {
  final opened = web.window.open('about:blank', 'regun_checkout');
  if (opened == null) return null;
  try {
    opened.focus();
  } catch (_) {
    // Focus is best-effort.
  }
  return _WebCheckoutTab(opened);
}

class _WebCheckoutTab implements CheckoutTab {
  _WebCheckoutTab(this._window);

  final web.Window _window;

  @override
  bool get closed {
    try {
      return _window.closed;
    } catch (_) {
      // A cross-origin handle that cannot be read is treated as gone, so the
      // game stops waiting rather than polling indefinitely.
      return true;
    }
  }

  @override
  void navigate(String url) {
    try {
      _window.location.href = url;
    } catch (_) {}
  }

  @override
  void close() {
    try {
      _window.close();
    } catch (_) {}
  }
}
