import 'package:flutter/foundation.dart' show ValueNotifier;

/// Non-browser platforms never offer the Mac App Store download.
///
/// A native macOS build already *is* the app, iOS and Android are different
/// stores, and there is no Mac question to answer. Keeping this false rather
/// than branching at each call site means the prompt cannot leak into a native
/// build by forgetting a guard.
bool get macStorePromoAvailable => false;

/// Dismissal is deliberately in memory only. It must survive leaving the home
/// screen for a run and coming back, and it must NOT survive a page reload, so
/// a fresh visit to the site offers the app again. Browser storage would get
/// the second half wrong.
final ValueNotifier<bool> macStorePromoDismissed = ValueNotifier(false);

void dismissMacStorePromo() => macStorePromoDismissed.value = true;

/// Region-agnostic listing, so the App Store redirects to the visitor's own
/// storefront instead of pinning them to one country.
const String macAppStoreUrl = 'https://apps.apple.com/app/id6749497084';
