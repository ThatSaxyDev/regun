import 'package:regun/navigation/game_page_route.dart';
import 'package:regun/services/account/account_controller.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/views/menu_view.dart';

class FlameSplashView extends StatefulWidget {
  const FlameSplashView({super.key});

  @override
  State<FlameSplashView> createState() => _FlameSplashViewState();
}

class _FlameSplashViewState extends State<FlameSplashView> {
  static const _mark = AssetImage('assets/art/branding/rook_mark.png');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openMenu());
  }

  Future<void> _openMenu() async {
    await LocalPreferences.shared.load();
    await AccountController.shared.initialize();
    if (!mounted) return;
    await precacheImage(_mark, context);
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(GamePageRoute<void>(builder: (_) => const MenuView()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff161B18),
      body: LayoutBuilder(
        builder: (_, constraints) => Center(
          child: Image(
            image: _mark,
            width: min(320, constraints.biggest.shortestSide),
            height: min(320, constraints.biggest.shortestSide),
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}
