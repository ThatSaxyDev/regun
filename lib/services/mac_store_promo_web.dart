import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:web/web.dart' as web;

/// Region-agnostic listing, so the App Store redirects to the visitor's own
/// storefront instead of pinning them to one country.
const String macAppStoreUrl = 'https://apps.apple.com/app/id6749497084';

/// True only in a browser running on a Mac.
///
/// iPadOS Safari reports `Macintosh` in its user agent so that sites serve the
/// desktop layout, so the touch-point check is not optional: without it every
/// iPad would be offered a Mac download. Resolved once, at first use, because
/// the answer cannot change during a session.
final bool macStorePromoAvailable = _detectMac();

bool _detectMac() {
  final navigator = web.window.navigator;
  final isMac = RegExp(r'Macintosh|Mac OS X').hasMatch(navigator.userAgent);
  return isMac && navigator.maxTouchPoints <= 1;
}

/// Dismissal is deliberately in memory only. It must survive leaving the home
/// screen for a run and coming back, and it must NOT survive a page reload, so
/// a fresh visit to the site offers the app again. Browser storage would get
/// the second half wrong.
final ValueNotifier<bool> macStorePromoDismissed = ValueNotifier(false);

void dismissMacStorePromo() => macStorePromoDismissed.value = true;
