import 'package:flame_splash_screen/flame_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:regun/utils/nav.dart';
import 'package:regun/views/menu_view.dart';

class FlameSplashView extends StatelessWidget {
  const FlameSplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlameSplashScreen(
        showAfter: (BuildContext context) {
          return Image.asset(
            "assets/images/splash_image.png",
            height: 300.0,
            width: 300.0,
          );
        },
        theme: FlameSplashTheme.dark,
        onFinish: (context) => fadeTo(context: context, view: const MenuView()),
      ),
    );
  }
}
