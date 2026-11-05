import 'package:flutter/services.dart';

Future<bool> toggleDesktopFullscreen() async =>
    await const MethodChannel('regun/display')
        .invokeMethod<bool>('toggleFullscreen') ??
    false;
