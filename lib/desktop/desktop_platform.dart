import 'package:flutter/foundation.dart';

bool get nativeMacDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

bool get desktopInputAvailable => kIsWeb || nativeMacDesktop;

bool get nativeIosController =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
