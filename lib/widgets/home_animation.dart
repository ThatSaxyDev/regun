import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:regun/components/ui/menu_anim.dart';

class MenuAnimation extends StatefulWidget {
  const MenuAnimation({super.key});

  @override
  State<MenuAnimation> createState() => _MenuAnimationState();
}

class _MenuAnimationState extends State<MenuAnimation> {
  late MenuAnimationFlame _menuAnimationFlame;

  @override
  void initState() {
    super.initState();
    _menuAnimationFlame = MenuAnimationFlame();
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget(game: _menuAnimationFlame);
  }
}

//!
class MenuAnimationFlame extends FlameGame {
  @override
  Color backgroundColor() => const Color.fromRGBO(20, 19, 23, 1);

  @override
  void onMount() {
    add(MenuComponent(
      position: Vector2(20, 20),
    ));
    super.onMount();
  }
}
