import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/player_component.dart';

class RegunGame extends FlameGame with PanDetector {
  late PlayerComponent myPlayer;

  @override
  Color backgroundColor() => const Color(0xff222222);

  @override
  void onMount() {
    // debugMode = true;
    world.add(myPlayer = PlayerComponent(position: Vector2.zero()));
    super.onMount();
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    myPlayer.move(info.delta.global);
  }
}
