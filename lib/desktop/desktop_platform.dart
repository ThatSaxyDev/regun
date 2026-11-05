import 'package:flutter/foundation.dart';

bool get nativeMacDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

bool get desktopInputAvailable => kIsWeb || nativeMacDesktop;
