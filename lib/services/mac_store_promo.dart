/// Whether this build should offer the Mac App Store download.
///
/// False everywhere except a browser running on a Mac, so no native build and
/// no non-Mac browser ever sees the prompt. The web implementation lives behind
/// a conditional import because it reads `navigator`.
library;

export 'mac_store_promo_stub.dart'
    if (dart.library.js_interop) 'mac_store_promo_web.dart';
