import 'package:flutter/services.dart';

export 'desktop_display_native.dart'
    if (dart.library.js_interop) 'desktop_display_web.dart';

Future<void> quitDesktopApp() =>
    const MethodChannel('regun/display').invokeMethod<void>('quit');
