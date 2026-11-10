/// Platform-neutral entry point for the checkout tab handle.
///
/// The web implementation needs `dart:js_interop`, so it is selected at compile
/// time; every other platform gets the stub and never imports browser code.
library;

export 'checkout_window_stub.dart'
    if (dart.library.js_interop) 'checkout_window_web.dart';
